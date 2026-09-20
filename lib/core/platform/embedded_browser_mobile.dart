import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Mobile implementation: the real embedded WebView (unrestricted JS), the
/// exact setup NavButtonWebviewScreen used before the web port.
class EmbeddedBrowser {
  EmbeddedBrowser() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => onLoaded?.call(),
        ),
      );
  }

  late final WebViewController _controller;

  /// Fired when the current page finished loading.
  void Function()? onLoaded;

  Widget buildView() => WebViewWidget(controller: _controller);

  Future<void> load(Uri url) => _controller.loadRequest(url);
}
