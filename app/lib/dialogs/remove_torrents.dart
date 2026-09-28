import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/main.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:provider/provider.dart';

class RemoveTorrentsDialog extends StatelessWidget {
  final List<Torrent> torrents;

  const RemoveTorrentsDialog({
    super.key,
    required this.torrents,
  });

  void removeTorrents(BuildContext context, bool withData) async {
    // Read before closing the dialog, its context is gone afterwards.
    final torrentsModel = Provider.of<TorrentsModel>(context, listen: false);
    Navigator.pop(context);

    try {
      final torrentIds = torrents.map((t) => t.id).toList();
      await engine.removeTorrents(torrentIds, withData);
      // Refresh the list now, rather than on the next periodic refresh.
      await torrentsModel.fetchTorrents();
    } catch (e) {
      debugPrint('remove_torrents: could not remove the torrents: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.removeTorrentsTitle(torrents.length)),
      content: Text(localizations.removeTorrentsConfirm(torrents.length)),
      actions: [
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(localizations.deleteFilesAndTorrents),
          onPressed: () => removeTorrents(context, true),
        ),
        TextButton(
          child: Text(localizations.removeTorrentsOnly),
          onPressed: () => removeTorrents(context, false),
        ),
      ],
    );
  }
}
