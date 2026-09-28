import 'package:enjambre/models/torrents.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

DateTime seconds(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000);

void main() {
  group('completedSince', () {
    test('a torrent whose doneDate moved on has completed', () {
      final completed = completedSince(
          {1: seconds(0)}, [torrentFrom(id: 1, doneDate: 1700000000)]);

      expect(completed.map((t) => t.id), [1]);
    });

    test('a torrent that was already complete is not reported again', () {
      final completed = completedSince({1: seconds(1700000000)},
          [torrentFrom(id: 1, doneDate: 1700000000)]);

      expect(completed, isEmpty);
    });

    test('a torrent still downloading has not completed', () {
      final completed =
          completedSince({1: seconds(0)}, [torrentFrom(id: 1, doneDate: 0)]);

      expect(completed, isEmpty);
    });

    test('a torrent added and completed between two refreshes is reported',
        () {
      final completed = completedSince({}, [
        torrentFrom(id: 1, doneDate: 1700000000),
        torrentFrom(id: 2, doneDate: 0),
      ]);

      expect(completed.map((t) => t.id), [1]);
    });

    test('every torrent completed at once is reported', () {
      final completed = completedSince({1: seconds(0), 2: seconds(0)}, [
        torrentFrom(id: 1, doneDate: 1700000000),
        torrentFrom(id: 2, doneDate: 1700000001),
      ]);

      expect(completed.map((t) => t.id), [1, 2]);
    });
  });
}
