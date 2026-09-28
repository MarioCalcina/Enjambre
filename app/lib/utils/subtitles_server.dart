import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:path/path.dart' as p;

class SubtitlesServer {
  final Torrent torrent;
  HttpServer? _server;
  final Completer<HttpServer> _serverReadyCompleter = Completer<HttpServer>();
  bool _stopped = false;

  SubtitlesServer({required this.torrent}) {
    // A bind failure is reported through [getAddress]. Mark the future as
    // handled, so it is not reported as an unhandled async error when nobody
    // asks for the address.
    _serverReadyCompleter.future.ignore();
  }

  Future<void> start() async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (e, stackTrace) {
      debugPrint('subtitles_server: could not bind: $e');
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

    unawaited(_acceptRequests(server));
  }

  Future<void> stop() async {
    _stopped = true;
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> getAddress() async {
    final server = await _serverReadyCompleter.future;
    return 'http://${server.address.host}:${server.port}';
  }

  Future<void> _acceptRequests(HttpServer server) async {
    try {
      await for (final HttpRequest request in server) {
        await handleRequest(request);
      }
    } catch (e) {
      debugPrint('subtitles_server: stopped accepting requests: $e');
    }
  }

  Future<void> handleRequest(HttpRequest request) async {
    // Decoded, without the leading slash: 'directory/subtitle.srt'
    final requestedPath = request.uri.pathSegments.join('/');
    var started = false;

    try {
      final file = _resolveSubtitleFile(requestedPath);

      if (file == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404: Not Found');
      } else {
        started = await serveFile(request.response, requestedPath, file);
      }
    } catch (e) {
      debugPrint('Error serving file: $e');
      if (!started) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('500: Internal Server Error');
      }
    }

    try {
      await request.response.close();
    } catch (e) {
      debugPrint('subtitles_server: could not close response: $e');
    }
  }

  /// Resolves a requested path to a file on disk, or null when it is not a
  /// subtitle file of this torrent.
  ///
  /// Only files listed in the torrent are served: a request cannot escape the
  /// torrent directory through '..' segments or an absolute path.
  File? _resolveSubtitleFile(String requestedPath) {
    if (!requestedPath.endsWith('.srt')) return null;

    final isTorrentFile = torrent.files.any((f) => f.name == requestedPath);
    if (!isTorrentFile) return null;

    final location = p.normalize(torrent.location);
    final filePath = p.normalize(p.join(location, requestedPath));

    // Defense in depth, in case a torrent contains a crafted file name.
    if (!p.isWithin(location, filePath)) return null;

    return File(filePath);
  }

  /// Returns true if bytes have been written to the response.
  Future<bool> serveFile(
      HttpResponse response, String requestedPath, File file) async {
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      response.write('404: Not Found');
      return false;
    }

    final mimeType = lookupMimeType(requestedPath) ?? ContentType.binary.mimeType;
    response.headers.contentType = ContentType.parse(mimeType);
    await response.addStream(file.openRead());

    return true;
  }
}
