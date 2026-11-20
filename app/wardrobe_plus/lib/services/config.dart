import 'package:shared_preferences/shared_preferences.dart';

/// Where the Flask backend is running.
///
/// The address is saved on the phone and can be changed in
/// Profile → Server address, so a new Wi-Fi network no longer needs a code
/// change. Prefer the Mac's ".local" name (printed by backend/start.sh): it
/// stays the same when the Mac's IP changes.
class AppConfig {
  static const _prefsKey = 'server_url';

  /// Override at build time: flutter run --dart-define=SERVER_URL=http://my-mac.local:5000
  static const defaultBaseUrl =
      String.fromEnvironment('SERVER_URL', defaultValue: 'http://Atharvas-MacBook-Air-2.local:5000');

  static String _baseUrl = defaultBaseUrl;
  static String get baseUrl => _baseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _baseUrl);
  }

  /// Accepts "my-mac.local", "192.168.1.5:5000" or a full URL.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return defaultBaseUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final withPort = uri.hasPort ? uri : uri.replace(port: 5000);
    return withPort.toString().replaceAll(RegExp(r'/+$'), '');
  }
}
