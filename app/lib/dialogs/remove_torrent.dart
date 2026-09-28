import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:provider/provider.dart';

class RemoveTorrentDialog extends StatelessWidget {
  final Torrent torrent;

  const RemoveTorrentDialog({
    super.key, required this.torrent,
  });

  void removeTorrent(BuildContext context, bool withData) async {
    // Read before closing the dialog, its context is gone afterwards.
    final torrentsModel = Provider.of<TorrentsModel>(context, listen: false);
    Navigator.pop(context);

    try {
      await torrent.remove(withData);
      // Refresh the list now, rather than on the next periodic refresh.
      await torrentsModel.fetchTorrents();
    } catch (e) {
      debugPrint('remove_torrent: could not remove the torrent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.removeTorrentTitle),
      actions: [
        TextButton(
          child: Text(localizations.deleteFilesAndTorrent),
          onPressed: () => removeTorrent(context, true),
        ),
        TextButton(
          child: Text(localizations.removeTorrentOnly),
          onPressed: () => removeTorrent(context, false),
        ),
      ],
    );
  }
}
