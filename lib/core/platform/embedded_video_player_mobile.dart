import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Mobile implementation — the original youtube_player_flutter setup from
/// tutorial_player_screen.dart, unchanged.
class EmbeddedVideoPlayer extends StatefulWidget {
  const EmbeddedVideoPlayer({
    required this.videoId,
    this.isShort = false,
    super.key,
  });

  final String videoId;
  final bool isShort;

  @override
  State<EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<EmbeddedVideoPlayer> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      // A Short is filmed vertical (9:16) — forcing it into the default
      // 16:9 box is what made it render as a tiny letterboxed sliver
      // surrounded by black, both inline and in fullscreen. A normal
      // tutorial recording stays 16:9.
      aspectRatio: widget.isShort ? 9 / 16 : 16 / 9,
      // Package defaults, kept explicit. With the aspect ratio now correct
      // for both shapes, rotating to landscape fullscreen (or pillarboxing
      // a Short if rotated) is handled correctly by the underlying player.
      autoFullScreen: true,
      enableFullScreenOnVerticalDrag: true,
    );
  }
}
