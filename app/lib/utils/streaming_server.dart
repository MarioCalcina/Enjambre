import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:async/async.dart';

import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/engine/file.dart' as torrent_file;
import 'package:enjambre/utils/torrent_utils.dart';

/// State of a single in-flight request.
///
/// Tracks whether bytes have already been written to the response, so error
/// handling never tries to set a status code on a response whose headers are
/// already on the wire.
class _StreamingRequest {
  final HttpRequest request;
  final CancelableCompleter<void> completer;
  bool started = false;

  _StreamingRequest(this.request, this.completer);

  HttpResponse get response => request.response;

  bool get isCanceled => completer.isCanceled;
}

/// Server to stream a file
class StreamingServer {
  HttpServer? _server;
  final Completer<HttpServer> _serverReadyCompleter = Completer<HttpServer>();
  bool _stopped = false;

  String filePath;
  final int bufferSize;
  final Torrent torrent;
  final torrent_file.File torrentFile;
  late File _file;

  CancelableOperation? _cancelableOperation;

  StreamingServer(
      {required this.filePath,
      required this.bufferSize,
      required this.torrent,
      required this.torrentFile}) {
    // A bind failure is reported through [getAddress]. Mark the future as
    // handled, so it is not reported as an unhandled async error when the
    // player is disposed before asking for the address.
    _serverReadyCompleter.future.ignore();
  }

  Future<void> start() async {
    _file = File(filePath);

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (e, stackTrace) {
      debugPrint('streaming_server: could not bind: $e');
      if (!_serverReadyCompleter.isCompleted) {
        _serverReadyCompleter.completeError(e, stackTrace);
      }
      return;
    }

    if (_stopped) {
      // stop() was called while binding.
      await server.close(force: true);
      return;
    }

    _server = server;
    _serverReadyCompleter.complete(server);
    debugPrint(
        'streaming_server: starting streaming server on ${_addressOf(server)}');

    unawaited(_acceptRequests(server));
  }

  Future<void> stop() async {
    debugPrint('streaming_server: stop');
    _stopped = true;
    await _cancelableOperation?.cancel();
    await _server?.close(force: true);
    _server = null;
  }

  void cancelRequest() {
    _cancelableOperation?.cancel();
  }

  Future<String> getAddress() async {
    final server = await _serverReadyCompleter.future;
    return _addressOf(server);
  }

  String _addressOf(HttpServer server) =>
      'http://${server.address.host}:${server.port}';

  Future<void> _acceptRequests(HttpServer server) async {
    try {
      await for (final HttpRequest request in server) {
        // A new request means the player seeked: cancel the previous one.
        debugPrint('streaming_server: cancel previous request...');
        await _cancelableOperation?.cancel();

        final completer = CancelableCompleter<void>();
        final streamingRequest = _StreamingRequest(request, completer);

        // Create new cancelable request
        _cancelableOperation = CancelableOperation.fromFuture(
          _handleRequest(streamingRequest),
          onCancel: () {
            debugPrint('Previous request cancelled.');
            completer.operation.cancel();
          },
        );
      }
    } catch (e) {
      debugPrint('streaming_server: stopped accepting requests: $e');
    }
  }

  Future<void> _handleRequest(_StreamingRequest streamingRequest) async {
    final response = streamingRequest.response;

    try {
      if (streamingRequest.request.method == 'GET') {
        await _handleGetRequest(streamingRequest);
      } else {
        response.statusCode = HttpStatus.methodNotAllowed;
      }
    } on CancellationException {
      debugPrint('streaming_server: Request cancelled');
    } catch (e) {
      debugPrint('streaming_server: Error processing request: $e');
      // A status code can only be set while nothing has been written yet.
      if (!streamingRequest.started) {
        response.statusCode = HttpStatus.internalServerError;
      }
    } finally {
      await _closeResponse(response);
      if (!streamingRequest.completer.isCompleted) {
        streamingRequest.completer.complete();
      }
    }
  }

  Future<void> _closeResponse(HttpResponse response) async {
    try {
      await response.close();
    } catch (e) {
      // The client is gone, or the response was already closed.
      debugPrint('streaming_server: could not close response: $e');
    }
  }

  Future<void> _handleGetRequest(_StreamingRequest streamingRequest) async {
    // Wait for at least first piece
    debugPrint('streaming_server: _handleGetRequest');
    await _waitForPieces(
        from: torrentFile.beginPiece,
        count: 1,
        streamingRequest: streamingRequest);
    final fileSize = torrentFile.length;
    final rangeHeader = streamingRequest.request.headers.value('range');

    streamingRequest.response.headers.set('Accept-Ranges', 'bytes');

    if (rangeHeader != null) {
      await _handleRangeRequest(streamingRequest, fileSize, rangeHeader);
    } else {
      await _sendFullFile(streamingRequest, fileSize);
    }
  }

  Future<void> _sendFullFile(
      _StreamingRequest streamingRequest, int fileSize) async {
    debugPrint('streaming_server: _sendFullFile');
    final response = streamingRequest.response;
    final mimeType = lookupMimeType(filePath) ?? ContentType.binary.mimeType;
    response.headers.contentType = ContentType.parse(mimeType);
    response.headers.contentLength = fileSize;

    if (fileSize == 0) return;

    await torrent.setSequentialDownloadFromPiece(torrentFile.beginPiece);
    await _pipeFileRangeInBlocks(
        _file, streamingRequest, 0, fileSize - 1, torrent.pieceSize);
  }

  Future<void> _handleRangeRequest(_StreamingRequest streamingRequest,
      int fileSize, String rangeHeader) async {
    debugPrint('streaming_server: _handleRangeRequest');
    final response = streamingRequest.response;
    // Only a single byte range is supported.
    final rangeRegex = RegExp(r'^bytes=(\d*)-(\d*)$');
    final match = rangeRegex.firstMatch(rangeHeader.trim());

    if (match == null) {
      response.statusCode = HttpStatus.badRequest;
      return;
    }

    final startStr = match.group(1) ?? '';
    final endStr = match.group(2) ?? '';

    if (startStr.isEmpty && endStr.isEmpty) {
      response.statusCode = HttpStatus.badRequest;
      return;
    }

    int start;
    int end;

    if (startStr.isEmpty) {
      // Suffix range: 'bytes=-500' means the last 500 bytes.
      final suffixLength = int.tryParse(endStr);
      if (suffixLength == null || suffixLength == 0 || fileSize == 0) {
        _sendRangeNotSatisfiable(response, fileSize);
        return;
      }
      start = math.max(0, fileSize - suffixLength);
      end = fileSize - 1;
    } else {
      final parsedStart = int.tryParse(startStr);
      if (parsedStart == null) {
        _sendRangeNotSatisfiable(response, fileSize);
        return;
      }
      start = parsedStart;
      // An absent or out of bounds last byte position is clamped to the end of
      // the file, as required by RFC 7233.
      end =
          endStr.isEmpty ? fileSize - 1 : (int.tryParse(endStr) ?? fileSize - 1);
      end = math.min(end, fileSize - 1);
    }

    if (start < 0 || start >= fileSize || start > end) {
      _sendRangeNotSatisfiable(response, fileSize);
      return;
    }

    final contentLength = end - start + 1;

    response.statusCode = HttpStatus.partialContent;
    final mimeType = lookupMimeType(filePath) ?? ContentType.binary.mimeType;
    response.headers.contentType = ContentType.parse(mimeType);
    response.headers.contentLength = contentLength;
    response.headers.set('Content-Range', 'bytes $start-$end/$fileSize');

    final piece = _pieceForOffset(start);

    debugPrint(
        'handleRangeRequest $start ${end + 1} $contentLength piece: $piece ${torrent.pieceSize}');

    await torrent.setSequentialDownloadFromPiece(piece);
    await _pipeFileRangeInBlocks(
        _file, streamingRequest, start, end, torrent.pieceSize);
  }

  void _sendRangeNotSatisfiable(HttpResponse response, int fileSize) {
    response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
    response.headers.set('Content-Range', 'bytes */$fileSize');
  }

  /// Index of the torrent piece holding [fileOffset], which is an offset
  /// inside the streamed file, not inside the torrent.
  int _pieceForOffset(int fileOffset) {
    final firstPiece = torrentFile.beginPiece;
    // The piece size is unknown until the metadata has been fetched.
    if (torrent.pieceSize <= 0) return firstPiece;

    final lastPiece = math.max(firstPiece, torrentFile.endPiece - 1);
    final piece = firstPiece + (fileOffset ~/ torrent.pieceSize);

    return math.min(math.max(piece, firstPiece), lastPiece);
  }

  List<int> _computeNeededPieces(int? from, int? count) {
    final List<int> neededPieces = [];
    // At least 2 pieces: a file does not necessarily start on a piece
    // boundary, so a block of pieceSize bytes can span two pieces.
    final neededPiecesCount = count ??
        (torrent.pieceSize > 0
            ? math.max(2, (bufferSize / torrent.pieceSize).ceil())
            : 2);
    final firstPiece = from ?? torrentFile.beginPiece;
    // endPiece is exclusive.
    final lastPiece = torrentFile.endPiece;
    for (int i = 0; i < neededPiecesCount && firstPiece + i < lastPiece; i++) {
      neededPieces.add(firstPiece + i);
    }

    return neededPieces;
  }

  Future<void> _waitForPieces(
      {int? from, int? count, _StreamingRequest? streamingRequest}) async {
    final neededPieces = _computeNeededPieces(from, count);
    debugPrint('streaming_server: neededPieces $neededPieces');

    await waitForPiecesList(
      torrent: torrent,
      neededPieces: neededPieces,
      onCancelled: streamingRequest != null
          ? () {
              if (streamingRequest.isCanceled || _stopped) {
                debugPrint('streaming_server: cancel throw');
                return true;
              }
              return false;
            }
          : null,
    );
  }

  Future<void> _pipeFileRangeInBlocks(
      File file,
      _StreamingRequest streamingRequest,
      int start,
      int end,
      int blockSize) async {
    debugPrint(
        'streaming_server: _pipeFileRangeInBlocks start: $start end: $end');

    final response = streamingRequest.response;
    int currentStart = start;

    while (currentStart <= end) {
      if (streamingRequest.isCanceled || _stopped) {
        debugPrint('streaming_server: _pipeFileRangeInBlocks isCanceled !!!');
        throw CancellationException();
      }

      int currentEnd = currentStart + blockSize - 1;
      if (currentEnd > end) {
        currentEnd = end;
      }

      final piece = _pieceForOffset(currentStart);
      await _waitForPieces(from: piece, streamingRequest: streamingRequest);
      debugPrint(
          'streaming_server: reading piece: $piece start: $start end: $end');
      final readStream = file.openRead(currentStart, currentEnd + 1);

      await for (final chunk in readStream) {
        if (streamingRequest.isCanceled || _stopped) {
          throw CancellationException();
        }
        streamingRequest.started = true;
        response.add(chunk);
        await response.flush();
      }

      currentStart = currentEnd + 1;
    }
  }
}
