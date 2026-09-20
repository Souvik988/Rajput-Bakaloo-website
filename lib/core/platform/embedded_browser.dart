/// Platform-boundary for the one screen that embeds an external website
/// (the admin-configurable WEBVIEW nav-button destination).
///
/// WEB PORT split point: mobile uses webview_flutter (native WebView);
/// web composes the destination inside an <iframe> platform view. Both
/// implementations expose the identical EmbeddedBrowser surface, so
/// NavButtonWebviewScreen's identity-token handoff, loading state and
/// chrome are shared.

library;

export 'embedded_browser_mobile.dart'
    if (dart.library.html) 'embedded_browser_web.dart';
