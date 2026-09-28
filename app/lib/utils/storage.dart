import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Returns true when a torrent can really be written in [dirPath].
///
/// Transmission reports a write failure only once a torrent is added, as an
/// error string on the torrent itself, which is far too late and reads as
/// "the download does not start". The directory is probed up front instead.
///
/// The probe mirrors what a multi file torrent does - create a directory, then
/// write inside it - because on Android shared storage the two are not
/// equivalent: writing a file can be allowed while creating a directory is
/// not.
Future<bool> isDirectoryWritable(String dirPath) async {
  if (dirPath.isEmpty) return false;

  final probeDir = Directory(p.join(dirPath, '.enjambre-write-test'));

  try {
    await probeDir.create(recursive: true);

    final probeFile = File(p.join(probeDir.path, 'probe'));
    await probeFile.writeAsString('enjambre', flush: true);

    // Read it back: a write can be accepted and silently dropped.
    return await probeFile.readAsString() == 'enjambre';
  } catch (e) {
    debugPrint('storage: cannot write in $dirPath: $e');
    return false;
  } finally {
    // A leftover probe directory is not worth failing the check for.
    try {
      await probeDir.delete(recursive: true);
    } catch (e) {
      debugPrint('storage: could not remove the probe: $e');
    }
  }
}
