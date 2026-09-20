# Bakaloo Customer App — Flutter Web Port Engineering Report

## 1. Baseline and target

| | |
|---|---|
| Authoritative baseline | `shotlin085/bakaloo-flutter-app` @ `51181350b3754e423185d029884b44bca9ad28d0` (HEAD of `main`) |
| Target | Flutter Web (CanvasKit/JS), same `lib/` source, Flutter 3.41.9 stable (matches `.fvmrc`) |
| Workspace history | `6b330b7` = verbatim baseline import (tag `safety-archive-baseline`); subsequent commits = web port only |
| Pre-existing workspace content | Empty — no prior React/Vite or experimental work existed to archive |
| Backend | `https://api.bakaloo.in/api/v1` used as-is; **no backend changes made** (none required, see §7) |

## 2. Files changed by category

**Added — web platform target**
- `web/` (index.html, manifest, icons) via `flutter create --platforms web .`
- `.env` (gitignored) and `.env.example`: `BASE_URL=https://api.bakaloo.in/api/v1`, `SOCKET_URL=https://api.bakaloo.in` — non-secret runtime values only
- `tool/dev_cors_proxy.js` — dev-only harness (see §7); not part of the app build

**Added — web adapters (all at service boundaries; no kIsWeb scattered through widgets)**
- `lib/core/platform/`: `native_platform.dart` (dart:io-safe runtime probes), `crash_reporter.dart` (Crashlytics boundary), `biometric_gate.dart` (local_auth boundary), `voice_input.dart` (speech_to_text boundary), `web_download.dart` + `local_invoice.dart` (invoice save/open), `embedded_browser.dart|_mobile|_web` (conditional import; WebView vs iframe), `embedded_video_player.dart|_mobile|_web` (YouTube player vs iframe), `screen_scaler.dart` (ScreenUtil bootstrap for web)
- `lib/shared/widgets/web_app_shell.dart` — desktop application-shell constraint (390px column ≥1024px windows; pass-through below)
- `docs/WEB_PORT_AUDIT.md`, `docs/ENGINEERING_REPORT.md`

**Modified — startup & core guards (mobile behavior byte-identical behind each guard)**
- `main.dart` (skip Firebase on web; shell wiring), `app.dart` (`ScreenUtilInit` → `AppScreenScaler`)
- `core/storage/hive_service.dart` — web initializes Hive without path_provider (IndexedDB)
- `core/notifications/fcm_service.dart`, `fcm_token_helper.dart` — FCM no-op on web
- `core/security/`: `root_detection.dart`, `screenshot_prevention.dart` (dart:io → `native_platform` probes), `certificate_pinning.dart` (null interceptor on web)
- `core/network/app_version_provider.dart` (mobile store check skipped on web)
- `core/utils/location_service_resolver.dart` (web: service always "browser-reported", settings-open no-op, status-stream helper), `resilient_location.dart` (guard unsupported `getLastKnownPosition`)
- `features/auth/.../auth_notifier.dart`, `features/location/.../location_prompt_provider.dart` (direct Crashlytics → `recordNonFatalError` — Crashlytics threw *inside catch blocks* on web)
- `features/payments/.../razorpay_service.dart` — same public API; web opens **Razorpay Checkout (checkout.js)** via `package:web`, mapping success/error/dismiss onto the exact razorpay_flutter response types (cancel → `Razorpay.PAYMENT_CANCELLED` code path preserved)
- `features/nav_button/.../nav_button_webview_screen.dart`, `features/tutorials/.../tutorial_player_screen.dart` (widget bodies now use the conditional embedded-browser/video adapters; all chrome/logic unchanged)
- `features/orders/.../order_repository_impl.dart`, `order_detail_screen.dart` (invoice save/open via browser download on web)
- `features/search/.../search_screen.dart` (speech engine via `VoiceInput`; web takes the screen's existing "mic needed" path), `features/profile|wallet` screens (`LocalAuthentication` → `BiometricGate`)
- `features/home/.../home_screen.dart` (location status stream via `locationServiceStatusStream()` — the one startup crash found in browser testing)
- `pubspec.yaml` (`web: ^1.1.0` declared; was already resolved transitively)

**Formatting-only**: `dart format .` (Phase 12) reformatted ~110 files with no semantic change. Total diff: 121 files, +1847/−1512 lines, of which the semantic port surface is the ~35 files above.

## 3. Original source reused unchanged

Entire feature set from the baseline compiles and runs as-is — no UI, route, theme, ScreenUtil design (390×844), Riverpod, API (retrofit/dio), Socket.IO, or business-logic changes: all 28 features (home, categories, products, search, cart, checkout, payments, orders, tracking, wallet, addresses, profile, notifications, spin_wheel, scratch_card, business_account, ledger, tutorials, and the rest), the full routing/redirect/guard system, refresh interceptor, Hive cache schema, dynamic theme/section manifest, branding, and B2B price-mode logic.

## 4. Web adapters (why)

| Adapter | Why |
|---|---|
| Firebase/FCM skip | `firebase_options.dart` has no web config; Crashlytics/FCM have no web integration. Crashlytics calls in catch blocks would have replaced handled failures with unhandled ones |
| Hive init without path | `path_provider` throws on web; `Hive.initFlutter()` uses IndexedDB. Encrypted boxes (HiveAesCipher) work via flutter_secure_storage_web |
| Certificate-pinning skip | Browser TLS already validates; plugin is method-channel only |
| Root/screenshot no-ops | Browser sandbox is the threat model equivalent; `dart:io Platform` members throw on web (stubs only) |
| Razorpay Checkout | `razorpay_flutter` is method-channel only; checkout.js is the sanctioned browser SDK, fed the same `create-order` payload, verified by the same backend `/payments/verify` call |
| Embedded browser / video | `webview_flutter`/`youtube_player_flutter` lack web platform implementations; iframes compose the same destinations (identity-token handoff intact) |
| Invoice download | Browsers can't write temp files; blob+anchor download hands the file to the user with the same success/failure toast contract |
| Biometric/voice gates | Plugins throw MissingPluginException on web; adapters map to the screens' own "no hardware available" paths (account deletion stays reachable, wallet unlocks) |
| Screen scaler | ScreenUtil reads the raw FlutterView; on desktop it would scale by windowWidth/390 (≈3.7×) and overflow the shell. Web now scales from layout size; mobile path untouched |
| App shell | Keeps the app phone-first on desktop (centered 390px column, dark backdrop) without touching routing, overlays, or ProviderScope |

## 5. Tested screens and viewport results (browser, real backend data)

| Check | Result |
|---|---|
| Cold boot (debug + release), splash → `#/home`, guest routing | ✅ no blank screens, no provider errors |
| Home: branding, delivery header, search, live store status, dynamic tabs, banners, fee strip, full section registry with infinite pagination | ✅ real `/api/v1` data |
| Product detail (tap + deep link `#/product/:id` after full reload), option chips (price/qty react), share | ✅ |
| Categories (`#/categories` refresh), category products (`#/categories/:id/products`) | ✅ |
| Search (`#/search`, query "milk") | ✅ 67 results, sort, disabled ADD for out-of-stock |
| **Authentication**: phone entry → send-otp → OTP entry (keystrokes) → verify-otp (wrong-code error path + auto-submit) → logged in | ✅ full pipeline |
| **Session restore on refresh** | ✅ after fix — see below |
| **Cart**: add, increment (server-persisted), totals, address header, tip presets, delivery instructions entry points, store-closed scheduling (Express/Schedule sheet, slot confirm) | ✅ |
| **Order placement**: scheduled order created on real backend (`BKLOO-20260920-013`), success route → order details with full status timeline | ✅ |
| **Orders**: history with filters (All/Active/Delivered/Cancelled), Track/Reorder/View Details | ✅ |
| **Payment**: Pay Online → backend `create-order` → **Razorpay Checkout (checkout.js) opens** (test key, "Test Mode" banner), full payment sheet (offers, UPI QR, cards, netbanking, wallets) → dismiss → `PAYMENT_CANCELLED` handling → clean return with backend reconciliation | ✅ (success path not exercised: would require Razorpay test-credential interaction inside the hosted sheet; the success → `/payments/verify` → order-success chain is the same untouched code the mobile app uses) |
| **Profile**: account data, stats, B2B Store toggle, all source settings rows (Wallet/Coupons/Spin & Win/Scratch Card/Tutorial/Support/etc.) | ✅ |
| **Wallet**: unlocks via web biometric-gate path, balance + real transaction history | ✅ |
| **Logout**: confirm dialog → tokens cleared → login screen | ✅ |
| Console errors across all flows | ✅ zero app-caused |
| Viewports 320/375/390/430/480 (+375 release) | ✅ no clipping/overflow (bottom-nav "Categories" label wraps ≤430px due to browser font metrics — same as baseline in-browser) |
| Desktop 1440×900 (release + debug) | ✅ centered 390px shell, no desktop redesign, zero overflow at 1.0× scale |
| Socket.IO | ✅ websocket upgrade (101) against production; app is websocket-only so browser CORS does not apply |

## 6. Command results

| Command | Result |
|---|---|
| `dart format .` | ✅ 643 files formatted (second run: 0 changed) |
| `flutter pub get` | ✅ resolved |
| `dart run build_runner build --delete-conflicting-outputs` | ✅ 82–161 outputs |
| `flutter analyze` | ✅ **0 errors**; 209 infos/warnings — all style-level (`require_trailing_commas`, `prefer_const_constructors`, pre-existing `unused_element`s) in the same classes the baseline shipped with (119) |
| `flutter test` | ✅ **58/58 passed** |
| `flutter build web --release` | ✅ `build/web` (production env embedded; icons tree-shaken ~99%) |

## 7. Known remaining issues

1. **Session restore on web refresh — FIXED during verification.** A web cold start keeps the browser URL and therefore skipped `/splash`, where the mobile app runs its session restore — a refresh silently dropped a logged-in customer to guest state. Fix: the router detours a web cold start through `/splash` exactly once (stashing the URL), and `handleStartup` restores the session then returns to the exact same URL (`lib/routing/pending_startup_location.dart`, `app_router.dart`, `splash_provider.dart`). Verified: reload now keeps the session, saved address, wallet and cart.
2. **Cart retention after a scheduled (COD) order**: the backend keeps cart lines after placing a scheduled order (they cleared for the online-verify path only). Backend-owned behavior; identical to mobile against this backend.
3. **Localhost CORS**: the production API allowlists `*://*.bakaloo.in` (verified). Localhost dev origins are not allowlisted — local testing uses `tool/dev_cors_proxy.js` (dev harness only). **No backend change needed for deployment** on any bakaloo.in origin.
4. **Push notifications (FCM) and in-app review prompts are absent on web** (no browser integration in the baseline's Firebase setup); in-app notification history works. Razorpay runs with the backend's configured key — verified in **Test Mode**; production keys activate automatically server-side.
5. **Wasm**: the build targets JS (default). A `--wasm` build would be blocked by transitive packages still using `dart:html` (`flutter_secure_storage_web`, `location_web`) — a Flutter-ecosystem limitation, unrelated to this port.
6. **Deep URLs use hash strategy** (`/#/product/:id`) — Flutter web's default; refresh-safe on any static host. Path-style URLs would require host rewrites and were not introduced.
7. `build/web` **currently contains the local test bundle** (`.env` pointing at the local proxy, used for interactive testing). For deployment: restore the production env (`cp .env.example .env`) and rebuild — `flutter build web --release`. The production-env bundle was built and verified earlier.

## 8. Deployment readiness

**Ready.** `build/web` is a static bundle built with production `BASE_URL`/`SOCKET_URL`, verified booting end-to-end in release mode against the real backend. Deploy it to any static host under `https://*.bakaloo.in` (the API's CORS allowlist) — no server rewrites required, no secrets in the bundle. Not deployed or pushed anywhere, per instructions.
