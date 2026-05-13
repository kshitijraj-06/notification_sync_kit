import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server endpoint URL and Bearer token across app restarts.
///
/// Call [init] once before reading or writing, then use [endpoint] and [token]
/// as simple getters. Changes made via [setEndpoint] or [setToken] are written
/// to [SharedPreferences] immediately.
class NotificationConfig {
  static const String _endpointKey = 'nsk_endpoint';
  static const String _tokenKey = 'nsk_bearer_token';

  SharedPreferences? _prefs;

  /// Loads stored values from [SharedPreferences]. Must be called before any
  /// other method.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// The currently stored endpoint URL, or an empty string if not yet set.
  String get endpoint => _prefs!.getString(_endpointKey) ?? '';

  /// The currently stored Bearer token, or an empty string if not yet set.
  String get token => _prefs!.getString(_tokenKey) ?? '';

  /// Returns `true` if both an endpoint and a token have been saved.
  bool get isConfigured => endpoint.isNotEmpty && token.isNotEmpty;

  /// Persists [value] as the endpoint URL.
  Future<void> setEndpoint(String value) async {
    await _prefs!.setString(_endpointKey, value.trim());
  }

  /// Persists [value] as the Bearer token.
  Future<void> setToken(String value) async {
    await _prefs!.setString(_tokenKey, value.trim());
  }
}
