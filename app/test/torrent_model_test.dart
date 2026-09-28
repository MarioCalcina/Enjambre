import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/engine/transmission/models/torrent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('TransmissionTorrentModel.fromJson', () {
    test('decodes the piece bitfield when it was requested', () {
      final torrent = TransmissionTorrentModel.fromJson(torrentJson());

      expect(torrent.pieces.length, 8);
      expect(torrent.pieces.sublist(0, 2), [true, true]);
      expect(torrent.pieces.sublist(2), everyElement(isFalse));
    });

    test('accepts a torrent without the piece bitfield', () {
      // The torrents list does not ask for it: decoding one bitfield per
      // torrent on every refresh costs more than the rest of the refresh.
      final torrent =
          TransmissionTorrentModel.fromJson(torrentJson(pieces: null));

      expect(torrent.pieces, isEmpty);
    });
  });

  group('error severity', () {
    test('maps the transmission error codes', () {
      expect(torrentFrom(error: 0).errorType, TorrentErrorType.none);
      expect(torrentFrom(error: 1).errorType, TorrentErrorType.trackerWarning);
      expect(torrentFrom(error: 2).errorType, TorrentErrorType.trackerError);
      expect(torrentFrom(error: 3).errorType, TorrentErrorType.localError);
    });

    test('a code we do not know is not treated as an error', () {
      expect(torrentFrom(error: 99).errorType, TorrentErrorType.none);
    });
  });

  group('hasLoadedPieces', () {
    test('true when every piece asked for is available', () {
      expect(torrentFrom().hasLoadedPieces([0, 1]), isTrue);
    });

    test('false when one of them is missing', () {
      expect(torrentFrom().hasLoadedPieces([0, 2]), isFalse);
    });

    test('false for an index outside the bitfield', () {
      // The streaming server computes piece indices from byte offsets, and a
      // stale one must not take the player down with a range error.
      expect(torrentFrom().hasLoadedPieces([99]), isFalse);
      expect(torrentFrom().hasLoadedPieces([-1]), isFalse);
    });

    test('false when the bitfield was not fetched', () {
      expect(torrentFrom(pieces: null).hasLoadedPieces([0]), isFalse);
    });
  });
}
