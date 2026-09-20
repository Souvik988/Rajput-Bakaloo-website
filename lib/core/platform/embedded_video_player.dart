/// Platform-boundary for embedded YouTube video playback (tutorials).
///
/// WEB PORT split point: mobile uses youtube_player_flutter (WebView-backed
/// IFrame Player API); web embeds youtube.com directly in an <iframe>
/// platform view. Both keep the vertical-Short vs 16:9 tutorial aspect
/// ratios the source screen established.

library;

export 'embedded_video_player_mobile.dart' if (dart.library.html) 'embedded_video_player_web.dart';

