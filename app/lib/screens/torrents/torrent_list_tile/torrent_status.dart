import 'package:flutter/material.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/l10n/app_localizations.dart';

const defaultTextStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 12,
  overflow: TextOverflow.ellipsis,
);

TextStyle _coloredTextStyle(Color color) => TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: color,
      overflow: TextOverflow.ellipsis,
    );

class TorrentStatusText extends StatelessWidget {
  final Torrent torrent;
  final double percent;

  const TorrentStatusText(
      {super.key, required this.torrent, required this.percent});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Only an error that actually stops the torrent replaces its status. A
    // tracker warning does not: the swarm is still reachable through the other
    // trackers, DHT and the peers already connected. The message stays
    // readable in the details tab either way.
    if (torrent.errorType == TorrentErrorType.localError ||
        torrent.errorType == TorrentErrorType.trackerError) {
      final isLocal = torrent.errorType == TorrentErrorType.localError;

      return Tooltip(
        message: torrent.errorString,
        child: Text(isLocal ? localizations.error : localizations.trackerError,
            style: _coloredTextStyle(isLocal ? Colors.red : Colors.orange)),
      );
    }

    return switch (torrent.status) {
      TorrentStatus.stopped =>
        Text(localizations.paused, style: defaultTextStyle),
      TorrentStatus.queuedToCheck =>
        Text(localizations.queuedToCheck, style: defaultTextStyle),
      TorrentStatus.checking =>
        Text(localizations.checking, style: defaultTextStyle),
      TorrentStatus.queuedToDownload =>
        Text(localizations.queuedToDownload, style: defaultTextStyle),
      TorrentStatus.queuedToSeed =>
        Text(localizations.queuedToSeed, style: defaultTextStyle),
      TorrentStatus.downloading => Text('${percent.floor().toString()}%',
          style: _coloredTextStyle(Colors.lightGreen)),
      TorrentStatus.seeding =>
        Text(localizations.seeding, style: _coloredTextStyle(Colors.lightBlue)),
    };
  }
}
