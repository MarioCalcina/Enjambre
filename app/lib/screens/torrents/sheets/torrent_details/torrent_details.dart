import 'package:flutter/material.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:enjambre/screens/torrents/sheets/torrent_details/tabs/details.dart';
import 'package:enjambre/screens/torrents/sheets/torrent_details/tabs/files.dart';
import 'package:enjambre/screens/torrents/sheets/torrent_details/tabs/tags.dart';
import 'package:provider/provider.dart';

class TorrentDetailsModalSheet extends StatelessWidget {
  final int id;
  final int initialTab;
  final bool showOnlyPlayableFiles;

  const TorrentDetailsModalSheet({
    super.key,
    required this.id,
    this.initialTab = 0,
    this.showOnlyPlayableFiles = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TorrentsModel>(builder: (context, torrentsModel, child) {
      var torrent =
          torrentsModel.torrents.firstWhere((element) => element.id == id);
      return TorrentDetailsModalSheetContent(
        torrent: torrent,
        initialTab: initialTab,
        showOnlyPlayableFiles: showOnlyPlayableFiles,
      );
    });
  }
}

class TorrentDetailsModalSheetContent extends StatelessWidget {
  final Torrent torrent;
  final int initialTab;
  final bool showOnlyPlayableFiles;

  const TorrentDetailsModalSheetContent({
    super.key,
    required this.torrent,
    this.initialTab = 0,
    this.showOnlyPlayableFiles = false,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3, // Number of tabs
      initialIndex: initialTab,
      child: Expanded(
        child: Material(
          child: Column(children: [
            TabBar(
              tabs: [
                Tab(text: localizations.files),
                Tab(text: localizations.tags),
                Tab(text: localizations.details),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FilesTab(
                    torrent: torrent,
                    location: torrent.location,
                    showOnlyPlayable: showOnlyPlayableFiles,
                  ),
                  TagsTab(torrent: torrent),
                  DetailsTab(torrent: torrent)
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
