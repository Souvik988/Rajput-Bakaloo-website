import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/nav_button/domain/entities/nav_button_entity.dart';

class NavButtonRemoteDataSource {
  const NavButtonRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<NavButtonEntity?> getNavButton() async {
    final response = await _apiClient.getNavButton();
    final raw = response.data;
    if (raw is! Map) return null;
    return _parseButton(Map<String, dynamic>.from(raw));
  }

  /// Every active PROFILE_MENU button for this viewer (Business
  /// Transaction, Games, and any others configured in the dashboard),
  /// already ordered by sort_order — unlike getNavButton() above, this can
  /// return several. A single unparseable row is dropped rather than
  /// failing the whole list, same "never let one bad row break the menu"
  /// convention as getNavButton().
  Future<List<NavButtonEntity>> getProfileMenuButtons() async {
    final response = await _apiClient.getNavButtonProfileMenu();
    final raw = response.data;
    if (raw is! List) return const <NavButtonEntity>[];

    final buttons = <NavButtonEntity>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final button = _parseButton(Map<String, dynamic>.from(item));
      if (button != null) buttons.add(button);
    }
    return buttons;
  }

  /// Shared parse for a single nav_buttons row, used by both getNavButton()
  /// (single) and getProfileMenuButtons() (list). A row this client
  /// doesn't understand (a newer destination_type added server-side after
  /// this build shipped, or malformed data) returns null rather than
  /// crashing the whole bottom nav / menu list over one bad row.
  NavButtonEntity? _parseButton(Map<String, dynamic> json) {
    final destinationType =
        navButtonDestinationTypeFromJson(json['destination_type'] as String?);
    final destinationValue = json['destination_value'] as String?;
    if (destinationType == null ||
        destinationValue == null ||
        destinationValue.isEmpty) {
      return null;
    }

    final iconType = (json['icon_type'] as String?) == 'CUSTOM'
        ? NavButtonIconType.custom
        : NavButtonIconType.preset;
    final customIconActiveUrl = json['custom_icon_active_url'] as String?;
    // A CUSTOM row with no active image is malformed (the backend
    // requires one) — fall back to a PRESET star rather than rendering
    // nothing at all.
    if (iconType == NavButtonIconType.custom &&
        (customIconActiveUrl == null || customIconActiveUrl.isEmpty)) {
      return NavButtonEntity(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        iconType: NavButtonIconType.preset,
        iconKey: 'star',
        destinationType: destinationType,
        destinationValue: destinationValue,
        passIdentity: json['pass_identity'] as bool? ?? false,
      );
    }

    return NavButtonEntity(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      iconType: iconType,
      iconKey: json['icon_key'] as String? ?? 'star',
      accentColor: json['accent_color'] as String?,
      customIconActiveUrl: customIconActiveUrl,
      customIconInactiveUrl: json['custom_icon_inactive_url'] as String?,
      destinationType: destinationType,
      destinationValue: destinationValue,
      passIdentity: json['pass_identity'] as bool? ?? false,
    );
  }

  /// Mints the short-lived identity-handoff token for a WEBVIEW button with
  /// pass_identity=true. Fetched fresh right before opening the WebView
  /// (never cached — it expires in ~10 minutes) so a customer who opens
  /// the button a while after cold-starting the app still gets a live
  /// token, not one already expired.
  Future<String?> getWebviewToken() async {
    final response = await _apiClient.postNavButtonWebviewToken();
    final raw = response.data;
    if (raw is! Map) return null;
    return raw['token'] as String?;
  }
}
