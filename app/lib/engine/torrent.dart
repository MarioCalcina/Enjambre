import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:path/path.dart';
import 'package:enjambre/engine/file.dart';
import 'package:enjambre/utils/device.dart';
import 'package:enjambre/utils/subtitles.dart';

/// What kind of message a torrent carries in its error string.
///
/// Mirrors tr_stat::Error. A tracker warning is routine on public torrents -
/// one dead tracker out of a dozen - and says nothing about whether the
/// download can proceed, so it must not be shown the same way as a local
/// error, which does stop it.
enum TorrentErrorType { none, trackerWarning, trackerError, localError }

// Torrent statuses
enum TorrentStatus {
  stopped,
  queuedToCheck,
  checking,
  queuedToDownload,
  downloading,
  queuedToSeed,
  seeding
}

class TorrentBase {
  final int id;
  final List<String>? labels;

  TorrentBase({required this.id, required this.labels});
}

// Torrent abstraction
abstract class Torrent extends TorrentBase {
  final String name;
  final double progress;
  final TorrentStatus status;
  final int size;
  final int rateDownload;
  final int rateUpload;
  final int downloadedEver;
  final int uploadedEver;
  final int eta;
  final int pieceCount;
  final List<bool> pieces;
  final int pieceSize;
  final String errorString;
  final TorrentErrorType errorType;
  final String location;
  final bool isPrivate;
  final int addedDate;
  final String creator;
  final String comment;
  final List<File> files;
  final int peersConnected;
  final String magnetLink;
  final bool sequentialDownload;
  final DateTime doneDate;

  Torrent(
      {required super.id,
      required super.labels,
      required this.name,
      required this.progress,
      required this.status,
      required this.size,
      required this.rateDownload,
      required this.rateUpload,
      required this.downloadedEver,
      required this.uploadedEver,
      required this.eta,
      required this.pieces,
      required this.pieceSize,
      required this.errorString,
      required this.errorType,
      required this.pieceCount,
      required this.location,
      required this.isPrivate,
      required this.addedDate,
      required this.comment,
      required this.creator,
      required this.files,
      required this.peersConnected,
      required this.magnetLink,
      required this.sequentialDownload,
      required this.doneDate});

  // Start the torrent
  Future<void> start();

  // Pause the torrent
  Future<void> stop();

  // Remove the torrent
  Future<void> remove(bool withData);

  // Update torrent data
  Future update(TorrentBase torrent);

  Future toggleFileWanted(int fileIndex, bool wanted);

  Future toggleAllFilesWanted(bool wanted);

  Future setSequentialDownload(bool sequential);

  Future setSequentialDownloadFromPiece(int sequentialDownloadFromPiece);

  Future setFilesPriority(
      {List<int>? priorityHigh,
      List<int>? priorityLow,
      List<int>? priorityNormal});

  /// Undoes everything streaming changes on the torrent: sequential download
  /// order and file priorities.
  ///
  /// Both are stored in transmission's resume file, so a torrent left in
  /// sequential mode keeps downloading its pieces in order across restarts,
  /// which is much slower than the default rarest-first order.
  Future<void> resetStreamingState();

  Future<void> startStreaming(File file) async {
    debugPrint('starting streaming ${file.name}');
    // File already completed
    if (file.bytesCompleted == file.length) {
      // Do nothing if file is already completed.
      return;
    }

    // Be sure torrent is active
    await start();

    final fileIndex = files.indexWhere((f) => f.name == file.name);

    // File indices for streaming file and detected associated subtitles
    final List<int> highPriorityFileIndices = [fileIndex];

    // Want subtitles and set them to high priority
    final externalSubtitles = getExternalSubtitles(file, this);
    for (final (index, file) in files.indexed) {
      if (externalSubtitles.firstWhereOrNull((f) => f.name == file.name) !=
          null) {
        await toggleFileWanted(index, true);
        highPriorityFileIndices.add(index);
      }
    }

    await toggleFileWanted(fileIndex, true);

    // Set high priority for streaming file and subtitles
    await setFilesPriority(priorityHigh: highPriorityFileIndices);

    await setSequentialDownload(true);
  }

  Future<void> stopStreaming() async {
    debugPrint('stopping streaming');
    await resetStreamingState();
  }

  bool hasLoadedPieces(List<int> piecesToTest) {
    // Guard against out of bounds indices: a stale piece index must not crash
    // the streaming server.
    return piecesToTest
        .every((p) => p >= 0 && p < pieces.length && pieces[p]);
  }

  Future openFolder(BuildContext context) async {
    if (!isDesktop()) return;

    OpenResult result;
    String folderPath;

    if (files.length == 1) {
      folderPath = location;
    } else {
      var folderName = split(files.first.name).first;
      folderPath = join(location, folderName);
    }

    result = await OpenFile.open(
      folderPath,
    );

    if (result.type != ResultType.done) {
      final folderExists = await Directory(folderPath).exists();

      if (context.mounted) {
        final localizations = AppLocalizations.of(context)!;
        var errorMessage = switch (result.type) {
          ResultType.noAppToOpen => localizations.noAppToOpen,
          ResultType.fileNotFound => localizations.notFound,
          ResultType.permissionDenied => localizations.permissionDenied,
          // It seems fileNotFound is not returned on linux
          ResultType.error => folderExists
              ? localizations.unknownError
              : localizations.folderNotFound,
          _ => localizations.unknownError
        };

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizations.errorOpeningLocation(errorMessage)),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }
}
