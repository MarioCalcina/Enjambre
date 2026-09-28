import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:enjambre/engine/file.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/main.dart';

class CancellationException implements Exception {}

/// Thrown when the torrent cannot be read anymore, e.g. it has been removed
/// while waiting for its pieces.
class TorrentUnavailableException implements Exception {
  final Object cause;

  TorrentUnavailableException(this.cause);

  @override
  String toString() => 'TorrentUnavailableException: $cause';
}

/// Number of consecutive refresh failures before giving up.
const _maxConsecutiveErrors = 5;

/// Waits for a specified list of pieces to be downloaded.
///
/// [torrent] - The torrent containing the pieces
/// [neededPieces] - List of piece indices to wait for
/// [onCancelled] - Optional callback to check if operation should be cancelled
Future<void> waitForPiecesList({
  required Torrent torrent,
  required List<int> neededPieces,
  bool Function()? onCancelled,
}) async {
  final waitForPiecesCompleter = Completer();
  Timer? timer;
  var consecutiveErrors = 0;

  Future<void> testPiecesComplete() async {
    if (waitForPiecesCompleter.isCompleted) {
      timer?.cancel();
      return;
    }

    if (onCancelled != null && onCancelled()) {
      timer?.cancel();
      waitForPiecesCompleter.completeError(CancellationException());
      return;
    }

    try {
      // Refresh torrent data
      final Torrent t = await engine.fetchTorrent(torrent.id);
      consecutiveErrors = 0;

      if (t.hasLoadedPieces(neededPieces)) {
        timer?.cancel();
        if (!waitForPiecesCompleter.isCompleted) {
          waitForPiecesCompleter.complete();
        }
      }
    } catch (e) {
      // Without this, an error thrown from the timer callback would be
      // swallowed and the completer would never complete.
      consecutiveErrors++;
      debugPrint('torrent_utils: could not refresh torrent ${torrent.id}: $e');

      if (consecutiveErrors >= _maxConsecutiveErrors) {
        timer?.cancel();
        if (!waitForPiecesCompleter.isCompleted) {
          waitForPiecesCompleter.completeError(TorrentUnavailableException(e));
        }
      }
    }
  }

  await testPiecesComplete();

  if (!waitForPiecesCompleter.isCompleted) {
    timer = Timer.periodic(
        const Duration(seconds: 1), (_) => testPiecesComplete());
  }

  return waitForPiecesCompleter.future;
}

/// Waits for a specified number of pieces to be downloaded for a given file.
///
/// [torrent] - The torrent containing the file
/// [file] - The file to wait for
/// [pieceCount] - Number of pieces to wait for (starting from file.beginPiece)
/// [onCancelled] - Optional callback to check if operation should be cancelled
Future<void> waitForPieces({
  required Torrent torrent,
  required File file,
  required int pieceCount,
  bool Function()? onCancelled,
}) async {
  List<int> neededPieces = [];
  final endPiece = (file.beginPiece + pieceCount).clamp(0, file.endPiece);
  for (int i = file.beginPiece; i < endPiece; i++) {
    neededPieces.add(i);
  }

  await waitForPiecesList(
    torrent: torrent,
    neededPieces: neededPieces,
    onCancelled: onCancelled,
  );
}
