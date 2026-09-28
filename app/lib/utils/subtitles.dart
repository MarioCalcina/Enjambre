import 'dart:async';

import 'package:enjambre/engine/file.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/utils/torrent_utils.dart';
import 'package:path/path.dart' as p;

String truncateFromLastSlash(String text) {
  int lastSlashIndex = text.lastIndexOf('/');
  if (lastSlashIndex != -1) {
    return text.substring(lastSlashIndex + 1);
  } else {
    return text;
  }
}

/// Subtitle files in the same directory of the torrent as [file].
///
/// Other directories are left out even at the same depth: in a pack with one
/// directory per season, the subtitles of every season would otherwise be
/// downloaded before playback starts.
List<File> getExternalSubtitles(File file, Torrent torrent) {
  // Torrent file names always use '/', whatever the platform.
  final directory = p.posix.dirname(file.name);

  return torrent.files
      .where((f) =>
          f.name.endsWith('.srt') && p.posix.dirname(f.name) == directory)
      .toList();
}

downloadSubtitles(File file, Torrent torrent,
    {bool Function()? onCancelled}) async {
  final List<File> subtitles = getExternalSubtitles(file, torrent);
  for (var sub in subtitles) {
    if (onCancelled != null && onCancelled()) return;
    await torrent.setSequentialDownloadFromPiece(sub.beginPiece);
    await _waitForFileComplete(
        torrent: torrent, fileName: sub.name, onCancelled: onCancelled);
  }
}

Future<void> _waitForFileComplete(
    {required Torrent torrent,
    required String fileName,
    bool Function()? onCancelled}) async {
  final file = torrent.files.firstWhere((f) => f.name == fileName);
  final pieceCount = file.endPiece - file.beginPiece;
  await waitForPieces(
      torrent: torrent,
      file: file,
      pieceCount: pieceCount,
      onCancelled: onCancelled);
}

class ExternalSubtitle {
  final String url;
  final String name;

  ExternalSubtitle({required this.url, required this.name});
}
