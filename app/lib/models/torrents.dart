import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:enjambre/engine/engine.dart';
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/main.dart';
import 'package:enjambre/storage/shared_preferences.dart';
import 'package:enjambre/utils/localizations.dart';
import 'package:enjambre/utils/notifications.dart';

const refreshIntervalSeconds = 5;

enum Sort { addedDate, progress, size }

/// Torrents that completed since [previousDoneDates] was taken.
///
/// Transmission sets doneDate each time a torrent completes, so a doneDate
/// newer than the previous one means it completed in between. Comparing it
/// with the clock instead misses completions: doneDate only has a one second
/// resolution, and refreshes are not exactly [refreshIntervalSeconds] apart.
///
/// A torrent added since then counts when it is already complete, so a small
/// one downloaded between two refreshes is not missed.
List<Torrent> completedSince(
    Map<int, DateTime> previousDoneDates, List<Torrent> torrents) {
  return torrents.where((t) {
    final previous = previousDoneDates[t.id];
    return previous == null
        ? t.doneDate.millisecondsSinceEpoch > 0
        : t.doneDate.isAfter(previous);
  }).toList();
}

class Filters {
  Set<String> labels = {};

  Filters({required this.labels});

  bool get enabled {
    return labels.isNotEmpty;
  }

  Filters.copy(Filters other) : this(labels: Set.from(other.labels));

  addLabel(String label) {
    labels.add(label);
  }

  removeLabel(String label) {
    labels.remove(label);
  }
}

class TorrentsModel extends ChangeNotifier {
  // All loaded torrents
  List<Torrent> torrents = [];
  List<Torrent> displayedTorrents = []; // filtered & sorted
  // All torrents labels
  List<String> labels = [];
  String filterText = '';
  bool hasLoaded = false;
  Sort sort = Sort.addedDate;
  bool reverseSort = true;
  Filters filters = Filters(labels: {});
  late Timer _timer;
  // doneDate of each torrent at the last refresh, null before the first one.
  Map<int, DateTime>? _doneDates;

  TorrentsModel() {
    _init();
  }

  _init() async {
    await _loadSettings();
    fetchTorrents();
    // Indefinitely refresh
    _timer = Timer.periodic(const Duration(seconds: refreshIntervalSeconds),
        (timer) => fetchTorrents());
  }

  void stopTimer() {
    _timer.cancel();
  }

  _loadSettings() async {
    var sortName = await SharedPrefsStorage.getString('sort') ?? sort.name;
    sort =
        Sort.values.firstWhere((e) => e.name == sortName, orElse: () => sort);
    reverseSort =
        await SharedPrefsStorage.getBool('reverseSort') ?? reverseSort;
  }

  List<Torrent> _filterTorrentsName(List<Torrent> torrents) {
    return filterText.isNotEmpty
        ? extractAllSorted(
                query: filterText,
                choices: torrents.toList(),
                getter: (t) => t.name,
                cutoff: 60)
            .map((result) => torrents[result.index])
            .toList()
        : torrents;
  }

  List<Torrent> _filterTorrents(List<Torrent> torrents) {
    if (filters.labels.isEmpty) return torrents;

    return torrents.where((t) {
      return filters.labels.every((l) => t.labels!.contains(l));
    }).toList();
  }

  List<Torrent> _sortTorrents(List<Torrent> torrents) {
    List<Torrent> torrentsSorted = List.from(torrents);

    switch (sort) {
      case Sort.addedDate:
        torrentsSorted.sort((a, b) => a.addedDate.compareTo(b.addedDate));
      case Sort.progress:
        torrentsSorted.sort((a, b) => a.progress.compareTo(b.progress));
      case Sort.size:
        torrentsSorted.sort((a, b) => a.size.compareTo(b.size));
    }

    return reverseSort ? torrentsSorted.reversed.toList() : torrentsSorted;
  }

  Future<TorrentAddedResponse> addTorrent(
      String? filename, String? metainfo, String? downloadDir) async {
    return engine.addTorrent(filename, metainfo, downloadDir);
  }

  Future<void> fetchTorrents() async {
    torrents = await engine.fetchTorrents();

    final previousDoneDates = _doneDates;
    _doneDates = {for (final t in torrents) t.id: t.doneDate};

    // Nothing is notified on the first refresh: those torrents completed
    // before the app started.
    final justCompleted = previousDoneDates == null
        ? const <Torrent>[]
        : completedSince(previousDoneDates, torrents);

    if (justCompleted.isNotEmpty) {
      final localizations = await appLocalizations();

      for (final torrent in justCompleted) {
        showNotification(
            id: torrentNotificationId(torrent.id),
            title: localizations.downloadCompleted,
            body: torrent.name,
            notificationsDetailsType: NotificationsDetailsTypes
                .downloadsCompletedAndroidNotificationDetails);
      }
    }

    labels = torrents
        .fold<List<String>>(
            [],
            (previousValue, element) =>
                previousValue..addAll(element.labels ?? []))
        .toSet()
        .toList();

    // Remove filtered labels that does not exist anymore. Removing from the
    // set while iterating over it would throw a ConcurrentModificationError.
    filters.labels.removeWhere((label) => !labels.contains(label));

    if (!hasLoaded) {
      hasLoaded = true;
    }

    processDisplayedTorrents();
  }

  processDisplayedTorrents() {
    displayedTorrents =
        _filterTorrents(_filterTorrentsName(_sortTorrents(torrents)));
    notifyListeners();
  }

  setFilterText(String value) {
    filterText = value;
    processDisplayedTorrents();
  }

  setSort(Sort value, bool reverse) async {
    SharedPrefsStorage.setString('sort', value.name);
    SharedPrefsStorage.setBool('reverseSort', reverse);
    sort = value;
    reverseSort = reverse;
    processDisplayedTorrents();
  }

  setFilters(Filters updatedFilters) async {
    filters = updatedFilters;
    processDisplayedTorrents();
  }
}
