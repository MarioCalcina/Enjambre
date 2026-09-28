import 'package:flutter/foundation.dart';
import 'package:enjambre/main.dart';

/// Run all migrations for app updates.
/// This should be called on app startup after engine initialization.
Future<void> runMigrations() async {
  await resetStreamingState();
}

/// Undo on startup what streaming changed on the torrents.
///
/// Playing a file switches its torrent to sequential download and raises the
/// priority of the file being played. Transmission stores both in its resume
/// file, so a session that ended while streaming - the app was killed, the
/// device ran out of battery - leaves every torrent it touched downloading in
/// sequential order, far slower than the default rarest-first order.
Future<void> resetStreamingState() async {
  try {
    final torrents = await engine.fetchTorrents();

    for (final torrent in torrents) {
      await torrent.resetStreamingState();
    }

    debugPrint('Streaming state reset for ${torrents.length} torrents');
  } catch (e) {
    debugPrint('Error resetting streaming state: $e');
  }
}
