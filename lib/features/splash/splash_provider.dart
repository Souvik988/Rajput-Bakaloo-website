import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/security/root_detection.dart';
import 'package:bakaloo_flutter_app/core/session/session_ready_gate.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/routing/pending_startup_location.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

part 'splash_provider.g.dart';

@Riverpod(keepAlive: true)
class SplashController extends _$SplashController {
  @override
  void build() {}

  Future<void> handleStartup(BuildContext context) async {
    final blocked = await RootDetection.blockIfCompromised(context);
    if (blocked) {
      return;
    }

    // Everything below decides the real AuthState. Notification taps wait
    // on SessionReadyGate before navigating, so this MUST flip to "ready"
    // no matter which branch below returns (or throws) — otherwise a
    // notification tap during startup would wait forever.
    try {
      // Minimum time the splash logo stays visible so it doesn't just flash
      // by — NOT a loading wait. Session restore below reads from local
      // storage/cache and is typically faster than this on its own; keeping
      // this short (rather than the old fixed 2200ms) means the delay is
      // barely noticeable instead of adding real dead time to every launch.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final secureStorage = ref.read(secureStorageProvider);
      final accessToken = await secureStorage.getAccessToken();
      final refreshToken = await secureStorage.getRefreshToken();

      // WEB PORT: a web cold start is detoured through /splash from a deep
      // URL so this restore runs (see app_router.dart's redirect). Return
      // the customer to the URL they actually refreshed on instead of
      // always landing on /home. Null on mobile and on a direct /splash
      // start — matching the original behavior there.
      final pendingStartupLocation =
          ref.read(pendingStartupLocationProvider.notifier).take();
      // WEB PORT: the one-shot splash detour must never fire on THIS
      // navigation. When the browser opens the bare root URL ("/"),
      // go_router boots straight to initialLocation (/splash) without
      // evaluating "/", so the detour's first pass never ran and its guard
      // is still false — letting it fire here would bounce this very
      // restore back to the splash forever (the reported "stuck on splash").
      ref.read(startupRestoreRedirectDoneProvider.notifier).markDone();
      final postRestoreDestination = pendingStartupLocation ?? RouteNames.home;

      if (!context.mounted) {
        return;
      }

      if (accessToken == null || refreshToken == null) {
        context.go(postRestoreDestination);
        return;
      }

      if (!JwtDecoder.isExpired(accessToken)) {
        await ref
            .read(authNotifierProvider.notifier)
            .restoreSession(accessToken);
        if (context.mounted) {
          context.go(postRestoreDestination);
        }
        return;
      }

      await ref.read(authNotifierProvider.notifier).refreshSession(
            refreshToken,
          );

      if (!context.mounted) {
        return;
      }

      context.go(postRestoreDestination);
    } finally {
      ref.read(sessionReadyGateProvider).markReady();
    }
  }
}
