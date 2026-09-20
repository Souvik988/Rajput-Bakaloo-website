import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// App-wide ScreenUtil bootstrap.
///
/// WEB PORT: ScreenUtilInit derives its scale from the raw FlutterView
/// (MediaQueryData.fromView), which on a desktop browser is the whole
/// window — so even inside the centered application shell the phone
/// design would scale by windowWidth/390 (≈3.7× at 1440px) and overflow
/// the shell. On web this scaler feeds ScreenUtil the *layout* size
/// (shell-constrained when the desktop shell is active, the plain window
/// size on phone/tablet browsers) instead of the view size. Everything
/// else — design size resolution, minTextAdapt, splitScreenMode — behaves
/// exactly as the original ScreenUtilInit usage in app.dart.
///
/// Mobile is a pass-through: the real ScreenUtilInit with identical
/// parameters, byte-for-byte behavior.
class AppScreenScaler extends StatelessWidget {
  const AppScreenScaler({
    required this.designSize,
    required this.builder,
    super.key,
  });

  final Size designSize;
  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return ScreenUtilInit(
        designSize: designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: builder,
      );
    }

    final MediaQueryData mq = MediaQuery.of(context);
    ScreenUtil.configure(
      data: mq,
      designSize: designSize,
      splitScreenMode: true,
      minTextAdapt: true,
    );
    return builder(context, null);
  }
}
