import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/nav_button/data/nav_button_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/nav_button/domain/entities/nav_button_entity.dart';

part 'nav_button_provider.g.dart';

final navButtonRemoteDataSourceProvider =
    Provider<NavButtonRemoteDataSource>((Ref ref) {
  return NavButtonRemoteDataSource(ref.watch(apiClientProvider));
});

/// The single resolved 5th-nav-button for the current viewer, or null —
/// re-resolved (audience/segment can change) whenever this rebuilds, e.g.
/// after login/logout invalidates it the same way price-mode-sensitive
/// providers already do. No local Hive cache: the payload is tiny and a
/// stale cached button (wrong segment, expired schedule) would show the
/// wrong 5th tab until the next cache TTL — better to just ask fresh.
@riverpod
Future<NavButtonEntity?> navButton(Ref ref) async {
  try {
    return await ref.read(navButtonRemoteDataSourceProvider).getNavButton();
  } catch (_) {
    // Never let a failed fetch break the bottom nav — fall back to the
    // plain 4-tab bar, same as every other "optional decoration" provider
    // in this app (banners, birthday prompt, etc.).
    return null;
  }
}

/// Every active PROFILE_MENU button for the current viewer (Business
/// Transaction, Games, and any others configured in the dashboard) —
/// same "never break the screen over a failed optional fetch" convention
/// as [navButton] above, and likewise no local cache (tiny payload, and a
/// stale cached list could show a button whose audience/segment no longer
/// matches this viewer).
@riverpod
Future<List<NavButtonEntity>> navButtonProfileMenu(Ref ref) async {
  try {
    return await ref
        .read(navButtonRemoteDataSourceProvider)
        .getProfileMenuButtons();
  } catch (_) {
    return const <NavButtonEntity>[];
  }
}
