
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

/// WEB implementation: the YouTube IFrame player embedded directly — the
/// same player API the mobile package drives through a WebView, without
/// the (web-absent) native WebView layer in between.
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
  late final String _viewId;
  late final web.HTMLIFrameElement _element;

  @override
  void initState() {
    super.initState();
    _viewId = 'bakaloo-youtube-${_nextId++}';
    _element = web.HTMLIFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..setAttribute('allow', 'autoplay; fullscreen; encrypted-media')
      ..src = 'https://www.youtube.com/embed/${widget.videoId}'
          '?autoplay=1&mute=0&controls=1&rel=0&playsinline=1';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _element,
    );
  }

  static int _nextId = 0;

  @override
  Widget build(BuildContext context) {
    // A Short is filmed vertical (9:16); a normal tutorial recording is
    // 16:9 — same framing the mobile player keeps.
    return AspectRatio(
      aspectRatio: widget.isShort ? 9 / 16 : 16 / 9,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
