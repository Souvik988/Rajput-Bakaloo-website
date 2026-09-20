import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

/// WEB implementation: the destination site is composed inside an <iframe>
/// platform view. Unrestricted JavaScript (the web analogue of the mobile
/// WebView's JavaScriptMode.unrestricted) and fullscreen permission are
/// granted so admin-configured game/event pages behave as they do in the
/// native WebView.
class EmbeddedBrowser {
  EmbeddedBrowser() {
    _viewId = 'bakaloo-embedded-browser-${_nextId++}';
    _element = web.HTMLIFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..setAttribute('allow', 'fullscreen');
    _element.addEventListener(
      'load',
      ((web.Event _) => onLoaded?.call()).toJS,
    );
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _element,
    );
  }

  static int _nextId = 0;

  late final String _viewId;
  late final web.HTMLIFrameElement _element;

  /// Fired when the current page finished loading.
  void Function()? onLoaded;

  Widget buildView() => HtmlElementView(viewType: _viewId);

  Future<void> load(Uri url) async {
    _element.src = url.toString();
  }
}
