import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WEB PORT: on mobile the app always cold-starts at `/splash`, which runs
/// the one-time session restore (`SplashController.handleStartup`). On web a
/// cold start can land on ANY deep URL (browser refresh keeps the current
/// route), which would skip the restore entirely and silently drop a logged
/// in customer to guest state.
///
/// The router's redirect stashes the pre-splash URL here (once per app run)
/// and sends the app through `/splash`; after the session restore completes,
/// `handleStartup` reads and clears this to return the customer to the exact
/// URL they refreshed on.
class PendingStartupLocation extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String location) {
    state = location;
  }

  String? take() {
    final current = state;
    state = null;
    return current;
  }
}

final pendingStartupLocationProvider =
    NotifierProvider<PendingStartupLocation, String?>(
  PendingStartupLocation.new,
);

/// One-shot guard so the web cold-start splash detour (see
/// [pendingStartupLocationProvider]) happens at most once per app run and
/// can never loop.
class StartupRestoreRedirectDone extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() {
    state = true;
  }
}

final startupRestoreRedirectDoneProvider =
    NotifierProvider<StartupRestoreRedirectDone, bool>(
  StartupRestoreRedirectDone.new,
);
