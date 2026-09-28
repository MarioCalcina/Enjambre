import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:enjambre/engine/file.dart' as torrent_file;
import 'package:enjambre/engine/torrent.dart';
import 'package:enjambre/utils/device.dart' as device;
import 'package:enjambre/utils/streaming_server.dart';
import 'package:enjambre/utils/subtitles.dart';
import 'package:enjambre/utils/subtitles_server.dart';
import 'package:enjambre/utils/torrent_utils.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/widgets/torrent_player/dialogs/player_loading.dart';
import 'package:enjambre/widgets/torrent_player/dialogs/track_selector.dart';
import 'package:enjambre/widgets/window_title_bar.dart';

const bufferSize = 2 * 1024 * 1024;

class TorrentPlayer extends StatefulWidget {
  final torrent_file.File file;
  final String filePath;
  final Torrent torrent;

  const TorrentPlayer({
    super.key,
    required this.filePath,
    required this.torrent,
    required this.file,
  });

  @override
  State<TorrentPlayer> createState() => TorrentPlayerState();
}

class StreamingPlayer extends Player {
  StreamingServer server;

  StreamingPlayer({required super.configuration, required this.server});

  @override
  Future<void> seek(Duration duration) {
    // Cancel previous request, which might block next seek command
    server.cancelRequest();
    return super.seek(duration);
  }
}

class TorrentPlayerState extends State<TorrentPlayer> {
  late final StreamingPlayer player;
  late final StreamingServer server;
  // Only created once the video file is ready, so it may still be null when
  // the player is disposed.
  SubtitlesServer? _subtitlesServer;
  // What startStreaming() changes on the torrent, so dispose() can wait for
  // it before undoing it.
  Future<void>? _startStreaming;
  bool _disposed = false;
  bool _isLoadingDialogVisible = false;
  final GlobalKey _videoComponentKey = GlobalKey();

  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(
    player,
    configuration: const VideoControllerConfiguration(),
  );

  @override
  void initState() {
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    super.initState();
    initPlayer();
  }

  @override
  void dispose() {
    // Stops initPlayer() as soon as it hits its next await.
    _disposed = true;
    unawaited(_stopStreaming(widget.torrent));
    player.stop();
    player.dispose();
    unawaited(server.stop());
    final subtitlesServer = _subtitlesServer;
    if (subtitlesServer != null) {
      unawaited(subtitlesServer.stop());
    }
    // leave immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void initPlayer() async {
    // Streaming server
    server = StreamingServer(
      filePath: widget.filePath,
      bufferSize: bufferSize,
      torrent: widget.torrent,
      torrentFile: widget.file,
    );

    player = StreamingPlayer(
        configuration: const PlayerConfiguration(bufferSize: bufferSize),
        server: server);

    try {
      await (player.platform as NativePlayer)
          .setProperty('network-timeout', '0');
      await (player.platform as NativePlayer).setProperty('cache', 'no');
      if (_disposed) return;

      player.stream.log.listen((log) {
        debugPrint('mpv: $log');
      });

      final startStreaming = widget.torrent.startStreaming(widget.file);
      _startStreaming = startStreaming;
      await startStreaming;
      if (_disposed) return;

      // Preload video file (wait for first piece)
      if (widget.torrent.progress != 1) {
        _showLoadingDialog((context) => PlayerLoadingDialog(
            title: AppLocalizations.of(context)!.loadingVideo,
            onCancel: _handleLoadingCancel));

        await waitForPieces(
          torrent: widget.torrent,
          file: widget.file,
          pieceCount: 1,
          onCancelled: () => _disposed,
        );

        if (_disposed || !mounted) return;

        _hideLoadingDialog();
      }

      // Start streaming server after video file is ready
      await server.start();
      if (_disposed) return;
      final serverAdress = await server.getAddress();
      if (_disposed) return;

      debugPrint('download subs');
      // Download subtitles
      if (widget.torrent.progress != 1) {
        _showLoadingDialog((context) => PlayerLoadingDialog(
            title: AppLocalizations.of(context)!.loadingSubtitles,
            onCancel: _handleLoadingCancel));

        await downloadSubtitles(widget.file, widget.torrent,
            onCancelled: () => _disposed);

        if (_disposed || !mounted) return;

        _hideLoadingDialog();
      }

      // Initialize subtitles server
      final subtitlesServer = SubtitlesServer(torrent: widget.torrent);
      _subtitlesServer = subtitlesServer;
      await subtitlesServer.start();
      if (_disposed) return;
      final subtitlesServerAdress = await subtitlesServer.getAddress();
      if (_disposed) return;

      debugPrint('open player');
      await player.open(Media(serverAdress));
      if (_disposed) return;

      final externalSubtitlesFiles =
          getExternalSubtitles(widget.file, widget.torrent);

      final externalSubtitles =
          externalSubtitlesFiles // TODO: support more formats
              .map((f) => ExternalSubtitle(
                  name: truncateFromLastSlash(f.name),
                  url: '$subtitlesServerAdress/${_encodePath(f.name)}'))
              .toList();

      // Load external subtitles to be able to select them
      for (final sub in externalSubtitles) {
        // TODO: Detect language from file name
        await player.setSubtitleTrack(
            SubtitleTrack.uri(sub.url, title: sub.name, language: 'en'));
        if (_disposed) return;
      }

      await player.setSubtitleTrack(SubtitleTrack.no());
      if (_disposed) return;

      await player.play();
    } on CancellationException {
      debugPrint('torrent_player: playback cancelled');
    } catch (e) {
      debugPrint('torrent_player: could not start playback: $e');
      if (_disposed || !mounted) return;
      _hideLoadingDialog();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Undoes what [Torrent.startStreaming] changed on the torrent.
  ///
  /// Waits for it to be done first: a reset sent while it is still running
  /// would be followed by its last requests, leaving the torrent downloading
  /// in sequential order.
  Future<void> _stopStreaming(Torrent torrent) async {
    final startStreaming = _startStreaming;
    if (startStreaming != null) {
      try {
        await startStreaming;
      } catch (_) {
        // Already reported by initPlayer(), the reset is needed all the same.
      }
    }

    try {
      await torrent.stopStreaming();
    } catch (e) {
      debugPrint('torrent_player: could not reset the streaming state: $e');
    }
  }

  /// Percent encodes each segment of a torrent file name, so that a file name
  /// containing '?' or '#' does not break the subtitles URL.
  String _encodePath(String fileName) =>
      fileName.split('/').map(Uri.encodeComponent).join('/');

  void _showLoadingDialog(WidgetBuilder builder) {
    if (_disposed || !mounted || _isLoadingDialogVisible) return;

    _isLoadingDialogVisible = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: builder,
    ).then((_) => _isLoadingDialogVisible = false));
  }

  void _hideLoadingDialog() {
    if (!_isLoadingDialogVisible || !mounted) return;

    _isLoadingDialogVisible = false;
    // The loading dialog is the top-most route of the root navigator, the one
    // showDialog() pushed it on.
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _handleLoadingCancel() {
    // Close the loading dialog, then leave the player screen.
    _hideLoadingDialog();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  onSubtitlesClick() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TrackSelectorDialog<SubtitleTrack>(
          title: AppLocalizations.of(context)!.subtitlesTitle,
          tracks: player.state.tracks.subtitle
              .where((s) => s.id != 'auto')
              .toList(),
          currentValue: player.state.track.subtitle.id,
          idOf: (sub) => sub.id,
          labelOf: (sub, localizations) => sub.id == 'no'
              ? localizations.noSubtitle
              : sub.title ?? localizations.unknownTrack,
          onSelected: (sub) async {
            await player.setSubtitleTrack(sub);
          },
        );
      },
    );
  }

  onAudioTrackClick() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TrackSelectorDialog<AudioTrack>(
          title: AppLocalizations.of(context)!.audioTracks,
          tracks: player.state.tracks.audio,
          currentValue: player.state.track.audio.id,
          idOf: (track) => track.id,
          labelOf: (track, localizations) {
            if (track.id == 'auto') return 'auto';
            if (track.id == 'no') return localizations.noAudio;
            return track.title ?? localizations.unknownTrack;
          },
          onSelected: (track) async {
            await player.setAudioTrack(track);
          },
        );
      },
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSubtitlesButton() {
    return MaterialDesktopCustomButton(
      icon: const Icon(Icons.subtitles),
      onPressed: onSubtitlesClick,
    );
  }

  Widget _buildAudioTrackButton() {
    return MaterialDesktopCustomButton(
      icon: const Icon(Icons.multitrack_audio),
      onPressed: onAudioTrackClick,
    );
  }

  List<Widget> _buildMobileBottomButtonBar() {
    return [
      const MaterialPositionIndicator(),
      const Spacer(),
      _buildSubtitlesButton(),
      _buildAudioTrackButton(),
    ];
  }

  List<Widget> _buildDesktopBottomButtonBar() {
    return [
      const MaterialDesktopSkipPreviousButton(),
      const MaterialDesktopPlayOrPauseButton(),
      const MaterialDesktopSkipNextButton(),
      const MaterialDesktopVolumeButton(),
      const MaterialDesktopPositionIndicator(),
      const Spacer(),
      _buildSubtitlesButton(),
      _buildAudioTrackButton(),
      const MaterialDesktopFullscreenButton(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: device.isDesktop()
              ? const WindowTitleBar(backgroundColor: Colors.black)
              : AppBar(toolbarHeight: 0),
          body: Stack(
            children: [
              device.isMobile()
                  ? MaterialVideoControlsTheme(
                      normal: MaterialVideoControlsThemeData(
                          seekBarThumbColor: Colors.yellow,
                          seekBarPositionColor: Colors.yellow,
                          padding: const EdgeInsets.only(bottom: 64),
                          topButtonBar: [_buildBackButton()],
                          bottomButtonBar: _buildMobileBottomButtonBar()),
                      fullscreen: MaterialVideoControlsThemeData(
                          seekBarThumbColor: Colors.yellow,
                          seekBarPositionColor: Colors.yellow,
                          padding: const EdgeInsets.only(bottom: 64),
                          topButtonBar: [_buildBackButton()],
                          bottomButtonBar: _buildMobileBottomButtonBar()),
                      child: Video(
                        key: _videoComponentKey,
                        controller: controller,
                        controls: MaterialVideoControls,
                      ),
                    )
                  : MaterialDesktopVideoControlsTheme(
                      normal: MaterialDesktopVideoControlsThemeData(
                        seekBarThumbColor: Colors.yellow,
                        seekBarPositionColor: Colors.yellow,
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildDesktopBottomButtonBar(),
                      ),
                      fullscreen: MaterialDesktopVideoControlsThemeData(
                        seekBarThumbColor: Colors.yellow,
                        seekBarPositionColor: Colors.yellow,
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildDesktopBottomButtonBar(),
                      ),
                      child: Video(
                        key: _videoComponentKey,
                        controller: controller,
                        controls: MaterialDesktopVideoControls,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
