import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/engine/transmission/models/torrent.dart';
import 'package:enjambre/engine/transmission/transmission.dart';

/// One file of a torrent-get response.
Map<String, dynamic> fileJson(String name) => <String, dynamic>{
      'name': name,
      'length': 1024,
      'bytesCompleted': 256,
      'begin_piece': 0,
      'end_piece': 8,
    };

/// One entry of a torrent-get response.
///
/// [pieces] is the base64 bitfield transmission returns; null leaves the key
/// out, the way the torrents list asks for it. [doneDate] is in seconds, 0
/// when the torrent never completed.
Map<String, dynamic> torrentJson({
  int id = 1,
  int error = 0,
  String? pieces = 'wA==', // 11000000: only pieces 0 and 1 are available
  int pieceCount = 8,
  int doneDate = 0,
  List<String> files = const ['video.mkv'],
}) {
  return <String, dynamic>{
    'id': id,
    'name': 'a torrent',
    'percentDone': 0.25,
    'status': 4, // downloading
    'totalSize': 1024,
    'rateDownload': 10,
    'rateUpload': 5,
    'downloadedEver': 256,
    'uploadedEver': 128,
    'eta': 60,
    if (pieces != null) 'pieces': pieces,
    'pieceCount': pieceCount,
    'pieceSize': 128,
    'error': error,
    'errorString': error == 0 ? '' : 'something happened',
    'downloadDir': '/downloads',
    'isPrivate': false,
    'addedDate': 1700000000,
    'creator': '',
    'comment': '',
    'files': files.map(fileJson).toList(),
    'fileStats': files.map((_) => {'wanted': true}).toList(),
    'labels': <String>[],
    'peersConnected': 3,
    'magnetLink': 'magnet:?xt=urn:btih:abc',
    'sequential_download': false,
    'doneDate': doneDate,
  };
}

Torrent torrentFrom({
  int id = 1,
  int error = 0,
  String? pieces = 'wA==',
  int doneDate = 0,
  List<String> files = const ['video.mkv'],
}) =>
    createTransmissionTorrentFromJson(TransmissionTorrentModel.fromJson(
        torrentJson(
            id: id,
            error: error,
            pieces: pieces,
            doneDate: doneDate,
            files: files)));
