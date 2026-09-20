# Bakaloo Flutter Web Port — Phase 1/3 Audit

Baseline: `shotlin085/bakaloo-flutter-app` @ `51181350b3754e423185d029884b44bca9ad28d0` (HEAD of main).
Workspace before port: **empty** — no prior React/experimental work existed to archive. The entire
baseline was imported and tagged `safety-archive-baseline`.

Toolchain: Flutter 3.41.9 stable (matches `.fvmrc` pin), Dart 3.11.5.

## 1. Repository findings

| Item | Verdict |
|---|---|
| `lib/`, `assets/`, `android/`, `ios/`, `test/`, `pubspec.*` | Retained unchanged (authoritative source) |
| `.kiro/` (AI spec files) | Retained (harmless, part of baseline) |
| `scripts/` (mobile emulator helpers) | Retained (unused by web) |
| `.env` | Not committed upstream; created locally with non-secret values only |
| React/Vite files, custom menus, mock data | **None found** — baseline is a clean Flutter app |

## 2. Web compilation status (empirical)

`flutter build web --debug` **compiles cleanly** on Flutter 3.41.9. This toolchain resolves
`dart:io` imports against web stubs — code *compiles* but every `dart:io` member
(`Platform.isAndroid`, `File()`, …) **throws `UnsupportedError` at runtime** on web.
Consequence: all web adaptations are runtime `kIsWeb` guards inside single files at service
boundaries; no conditional-import fragmentation is needed or used.

## 3. Native usage inventory and web verdicts

| Usage site | API | Web verdict |
|---|---|---|
| `core/constants/api_constants.dart` | `kIsWeb` localhost normalize | shared unchanged (already web-aware) |
| `core/security/root_detection.dart` | `flutter_jailbreak_detection`, `dart:io Platform`, MethodChannel | requires web adapter → no-op (not compromised) via `defaultTargetPlatform` |
| `core/security/screenshot_prevention.dart` | MethodChannel + `dart:io` | requires web adapter → early no-op (kIsWeb existed; Platform → defaultTargetPlatform) |
| `core/security/certificate_pinning.dart` | `http_certificate_pinning` (dio interceptor) | requires web adapter → null interceptor on web (browser TLS validates) |
| `core/storage/hive_service.dart` | `path_provider` before `Hive.initFlutter` | requires web adapter → `Hive.initFlutter()` without path (IndexedDB) |
| `core/storage/secure_storage_service.dart`, `encryption_helper.dart` | `flutter_secure_storage` v9 | supported on web (WebCrypto-backed) — shared unchanged |
| `core/network/app_version_provider.dart` | `dart:io Platform.isIOS` | requires web adapter → return `none` on web (store checks are mobile-only) |
| `core/utils/location_service_resolver.dart` | `location` pkg `requestService()`, `dart:io`, `openLocationSettings` | requires web adapter → service always "on" in browser; settings-open no-op |
| `core/utils/resilient_location.dart` | `Geolocator.getLastKnownPosition` | requires guard (web impl throws "unsupported") |
| `core/network/…`, geolocator (8 feature files) | `geolocator` | supported on web (`geolocator_web` endorsed) |
| `core/maps/ola/ola_maps_service.dart` | backend-proxied geocoding | supported on web (plain dio) — shared unchanged |
| `core/socket/socket_service.dart` | `socket_io_client` websocket transport | supported on web (package ships web transports) |
| `core/notifications/*` + `main.dart` | Firebase core/messaging/crashlytics | requires web adapter → skip Firebase init on web; FCM no-op |
| `core/analytics/analytics_service.dart` | `FirebaseAnalytics` | safe on web (all calls already inside `_safeLog` try/catch) |
| `features/payments/.../razorpay_service.dart` (+ topup) | `razorpay_flutter` | requires web adapter → Razorpay Checkout (checkout.js) behind same public API |
| `features/nav_button/.../nav_button_webview_screen.dart` | `webview_flutter` | requires web adapter → iframe-based embedded browser behind same widget contract |
| `features/tutorials/.../tutorial_player_screen.dart` | `youtube_player_flutter` (webview-based) | requires web adapter → YouTube iframe embed |
| `features/search/.../search_screen.dart` | `speech_to_text` | requires web adapter → initialize()=false → existing "mic needed" toast path |
| `features/profile`, wallet screens | `local_auth` | requires web adapter → device "not supported" ⇒ screens use their existing no-biometrics path |
| `features/orders/.../order_repository_impl.dart` | `path_provider` + `File` | requires web adapter → blob + anchor download |
| `features/orders/.../order_detail_screen.dart` | `open_file` | requires web adapter → file already saved by browser download |
| `features/profile/.../profile_screen.dart` | `in_app_review` | safe on web (fully try/caught, existing fallback toast) |
| `features/tracking/...` | `wakelock_plus` | supported on web (Wake Lock API) |
| `share_plus`, `url_launcher`, `connectivity_plus`, `package_info_plus`, `shared_preferences` | — | supported on web — shared unchanged |
| `features/addresses`/`location` providers | `FirebaseCrashlytics` in catch blocks | requires web adapter (`CrashReporter` no-op) — direct Crashlytics use would throw inside catch handlers on web |
| `features/profile/...upload_avatar` | `dart:io File` signatures | compiles; unreachable from UI (no picker in source) — left unchanged |
| `features/auth/.../auth_notifier.dart` | `getFcmTokenAwaitingApns(FirebaseMessaging.instance)` | requires web adapter → helper returns null on web before touching Firebase |

## 4. Backend CORS (proven against production API)

- `OPTIONS` preflight from `*://*.bakaloo.in` → 204 with full `access-control-*` headers ✓
- `GET` from `https://bakaloo.in` → ACAO reflected ✓
- `localhost:*` / `null` origins → no CORS headers (preflight falls through to 404) ✗

**Verdict: no backend defect for production deployment** (bakaloo.in + subdomains allowlisted).
Local verification uses a dev-only CORS proxy; no backend changes made or needed.

## 5. Responsive posture (Phase 5 plan)

- `App._resolveDesignSize` already keys on `shortestSide < 600` (phone) vs tablet cap 1.3×.
- Desktop browsers (width ≥ 1024) get a new application-shell constraint
  (`shared/widgets/web_app_shell.dart`): centered 480 px column + `MediaQuery` override so
  ScreenUtil sees a phone-sized surface. Mobile/tablet browsers render exactly as before.
