import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

import 'package:bakaloo_flutter_app/core/security/native_platform.dart';

class RootDetection {
  RootDetection._();

  static const MethodChannel _channel = MethodChannel('bakaloo/security');

  static Future<bool> blockIfCompromised(BuildContext context) async {
    final compromised = await _isCompromised();
    if (!compromised) {
      return false;
    }

    if (!context.mounted) {
      return true;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Security Warning'),
          content: const Text(
            'Bakaloo cannot run on rooted/jailbroken devices.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return true;
  }

  static Future<bool> _isCompromised() async {
    // WEB PORT: the browser sandbox is neither rooted nor jailbroken in the
    // sense this check guards against, and the plugin below has no web
    // implementation. Fall through to "not compromised" — mobile behavior
    // is unchanged because isAndroidRuntime() is true exactly where
    // Platform.isAndroid was.
    if (kIsWeb) {
      return false;
    }
    try {
      final rooted = await FlutterJailbreakDetection.jailbroken;
      return rooted;
    } catch (_) {
      if (isAndroidRuntime()) {
        try {
          return await _channel.invokeMethod<bool>('isDeviceCompromised') ??
              false;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }
}
