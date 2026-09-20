import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Non-fatal crash reporting boundary.
///
/// WEB PORT: Firebase Crashlytics has no web integration in this app and
/// Firebase is intentionally left uninitialized on the web — reading
/// `FirebaseCrashlytics.instance` there throws, and doing so from inside a
/// catch block would replace a handled failure with a fresh unhandled one.
/// Mobile keeps Crashlytics verbatim; web logs locally instead.
Future<void> recordNonFatalError(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal = false,
}) async {
  if (kIsWeb) {
    debugPrint('Non-fatal error${reason == null ? '' : ' ($reason)'}: $error');
    return;
  }
  await FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    reason: reason,
    fatal: fatal,
  );
}
