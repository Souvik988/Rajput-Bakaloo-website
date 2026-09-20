import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Application-shell constraint for wide desktop browsers.
///
/// WEB PORT: this app is a phone design (390×844 reference). On a desktop
/// browser we keep the app mobile-first — a centered 480px column on a
/// neutral backdrop — instead of stretching phone widgets across a 1920px
/// window (which makes ScreenUtil scale text and layout far past what the
/// fixed-height components budget for).
///
/// The constraint only rewrites the surface Size; routing, overlays,
/// dialogs, snackbars and the ProviderScope all stay exactly as they were —
/// MaterialApp still fills the shell column, so the Navigator and its
/// overlay are constrained with it. Mobile and tablet browsers are
/// completely unaffected (the shell is a pass-through there).
class WebAppShell extends StatelessWidget {
  const WebAppShell({required this.child, super.key});

  final Widget child;

  static const double _shellWidth = 480;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        if (width < 1024) {
          // Phone and tablet browsers keep the native full-bleed layout.
          return child;
        }

        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final Size shellSize = Size(
          _shellWidth,
          mediaQuery.size.height,
        );

        return Container(
          color: const Color(0xFF111114),
          alignment: Alignment.center,
          child: SizedBox(
            width: _shellWidth,
            child: MediaQuery(
              data: mediaQuery.copyWith(size: shellSize),
              child: ClipRect(child: child),
            ),
          ),
        );
      },
    );
  }
}
