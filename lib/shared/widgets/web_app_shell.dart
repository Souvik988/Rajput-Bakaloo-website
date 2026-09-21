import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Application-shell constraint for wide desktop browsers.
///
/// WEB PORT: this app is a phone design (390×844 reference). On a desktop
/// browser we keep the app mobile-first — the phone screen floats as a
/// rounded card on a branded backdrop — instead of stretching phone widgets
/// across a 1920px window (which makes ScreenUtil scale text and layout far
/// past what the fixed-height components budget for).
///
/// The backdrop uses the brand palette (violet `#7C3AED`, green `#0C831F`)
/// as large pre-blurred radial glows over a violet-black base: the soft
/// "blurry brand color" look, painted with plain gradients so it costs the
/// compositor nothing (no ImageFilter passes) and scrolling inside the app
/// never re-paints it (RepaintBoundary below).
///
/// The constraint only rewrites the surface Size; routing, overlays,
/// dialogs, snackbars and the ProviderScope all stay exactly as they were —
/// MaterialApp still fills the shell card, so the Navigator and its overlay
/// are constrained with it. Mobile and tablet browsers are completely
/// unaffected (the shell is a pass-through there).
class WebAppShell extends StatelessWidget {
  const WebAppShell({required this.child, super.key});

  final Widget child;

  /// The app's exact design width — rendering the shell at 1.0× scale keeps
  /// every fixed-height widget (category tabs, nav bar) inside its budget.
  static const double _shellWidth = 390;

  /// Vertical breathing room around the floating phone card.
  static const int _shellVerticalMargin = 24;

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
        final double shellHeight =
            (mediaQuery.size.height - _shellVerticalMargin * 2)
                .clamp(320.0, mediaQuery.size.height);
        final Size shellSize = Size(_shellWidth, shellHeight);
        final BorderRadius cardRadius = BorderRadius.circular(20);

        return Container(
          // Violet-black base, subtly graded so the backdrop feels deep
          // rather than flat.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF16101F), Color(0xFF0C0B12)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Brand glow — violet, upper-left.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.55, -0.65),
                    radius: 0.85,
                    colors: <Color>[Color(0x597C3AED), Color(0x007C3AED)],
                  ),
                ),
              ),
              // Brand glow — green, lower-right.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.65, 0.75),
                    radius: 0.75,
                    colors: <Color>[Color(0x400C831F), Color(0x000C831F)],
                  ),
                ),
              ),
              // Brand glow — faint violet echo, lower-left, for balance.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.7, 0.85),
                    radius: 0.5,
                    colors: <Color>[Color(0x2E7C3AED), Color(0x007C3AED)],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: _shellWidth,
                  height: shellHeight,
                  decoration: BoxDecoration(
                    borderRadius: cardRadius,
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 48,
                        offset: Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Color(0x3D000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: cardRadius,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(size: shellSize),
                      child: RepaintBoundary(child: child),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
