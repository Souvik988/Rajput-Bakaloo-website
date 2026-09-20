import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// WEB PORT: `dart:io`'s Platform members throw UnsupportedError on web
/// (the library only compiles there against stubs), so runtime platform
/// probes in security/infrastructure code go through these helpers instead.
/// On mobile they return exactly what Platform.isAndroid/isIOS return;
/// on web the kIsWeb short-circuit means the dart:io call is never reached.
bool isAndroidRuntime() => !kIsWeb && Platform.isAndroid;

bool isIOSRuntime() => !kIsWeb && Platform.isIOS;
