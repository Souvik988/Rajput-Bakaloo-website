import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

export 'package:local_auth/local_auth.dart'
    show AuthenticationOptions, BiometricType;

/// Local-authentication (biometric/device-credential) boundary.
///
/// WEB PORT: local_auth has no browser implementation — every call throws
/// MissingPluginException, which would (a) permanently block account
/// deletion in profile_screen (its catch-all treats plugin errors as
/// "not authenticated") and (b) keep the wallet balance sheet locked. The
/// web adapter reports "no biometric hardware available", the exact state
/// a device without biometrics reports on mobile, where every call site
/// already has a defined, unlocked path. Mobile delegates to local_auth
/// unchanged.
class BiometricGate {
  const BiometricGate();

  static final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get canCheckBiometrics async {
    if (kIsWeb) {
      return false;
    }
    return _localAuth.canCheckBiometrics;
  }

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) {
      return false;
    }
    return _localAuth.isDeviceSupported();
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return const <BiometricType>[];
    }
    return _localAuth.getAvailableBiometrics();
  }

  Future<bool> authenticate({
    required String localizedReason,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    if (kIsWeb) {
      // Matches local_auth on a device with no screen lock: there is
      // nothing to verify against, so the action proceeds.
      return true;
    }
    return _localAuth.authenticate(
      localizedReason: localizedReason,
      options: options,
    );
  }
}
