import 'package:enjambre/utils/subtitles.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

List<String> subtitlesFor(String video, List<String> files) {
  final torrent = torrentFrom(files: files);
  final file = torrent.files.firstWhere((f) => f.name == video);

  return getExternalSubtitles(file, torrent).map((f) => f.name).toList();
}

void main() {
  group('getExternalSubtitles', () {
    test('finds the subtitles next to the video', () {
      expect(
          subtitlesFor('Movie/movie.mkv',
              ['Movie/movie.mkv', 'Movie/movie.en.srt', 'Movie/notes.txt']),
          ['Movie/movie.en.srt']);
    });

    test('leaves out other directories at the same depth', () {
      // One directory per season: the subtitles of season 2 must not be
      // downloaded before playing an episode of season 1.
      expect(
          subtitlesFor('Show/S01/e01.mkv', [
            'Show/S01/e01.mkv',
            'Show/S01/e01.srt',
            'Show/S02/e01.mkv',
            'Show/S02/e01.srt',
          ]),
          ['Show/S01/e01.srt']);
    });

    test('works for a single file torrent', () {
      expect(subtitlesFor('movie.mkv', ['movie.mkv', 'movie.srt']),
          ['movie.srt']);
    });
  });
}
