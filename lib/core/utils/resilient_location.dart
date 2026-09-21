import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Attempts to get the device's current position with a resilient, tiered
/// fallback instead of one unguarded `getCurrentPosition()` call.
///
/// Reported bug: right after a customer turns location on from Settings
/// and comes back to the app, a single medium/high-accuracy attempt
/// regularly failed (or, worse, hung indefinitely when no `timeLimit` was
/// set at all) — the OS's location subsystem hasn't warmed back up yet, so
/// GPS-grade accuracy often isn't available in time, especially indoors.
///
/// Order of attempts:
///   1. The OS's cached last-known position — near-instant, no GPS
///      engagement, and accurate enough for a delivery address (the
///      customer still confirms/adjusts the pin afterward anyway).
///   2. A fast, low-accuracy fix (network/cell-tower based) — usually only
///      a few seconds even on a cold start.
///   3. A longer medium-accuracy fix, only if the fast attempt failed.
///   4. One final cached-position re-check, in case the OS picked up
///      *something* in the background across attempts 2-3 even though
///      neither returned a fix directly.
///
/// If every attempt fails, rethrows the error from the medium-accuracy
/// attempt (step 3) with its original stack trace, so callers can catch
/// and report it exactly as they would a plain `getCurrentPosition()`
/// call — no call site needs to change its existing catch-block logic.
Future<Position> getResilientCurrentPosition() async {
  // WEB PORT: the browser geolocation provider can be cold on the first
  // request after a page load, and geolocator_web surfaces every failure
  // (including transient ones) as a generic error. There is no OS
  // last-known-position cache or "warm-up" tier to lean on here, so the
  // web path retries the live fix across accuracy/timeout tiers with a
  // short pause between attempts — the same resilience the mobile tiers
  // provide, expressed in terms a browser understands.
  if (kIsWeb) {
    Object? lastError;
    StackTrace? lastStack;
    const attempts = <(Duration, LocationAccuracy)>[
      (Duration(seconds: 8), LocationAccuracy.low),
      (Duration(seconds: 12), LocationAccuracy.medium),
      (Duration(seconds: 15), LocationAccuracy.high),
    ];
    for (final (index, (timeLimit, accuracy)) in attempts.indexed) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: timeLimit,
          ),
        );
      } catch (error, stack) {
        lastError = error;
        lastStack = stack;
        if (index < attempts.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  // WEB PORT: geolocator_web throws "unsupported" for the cached-position
  // probe instead of returning null — caught below; the mobile path uses
  // it as the near-instant first tier exactly as before.
  final Position? cached = await Geolocator.getLastKnownPosition().catchError(
    (Object _) => null,
  );
  if (cached != null) {
    return cached;
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (err, stack) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      Error.throwWithStackTrace(err, stack);
    }
  }
}
