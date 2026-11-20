import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'database_helper.dart';

/// The signed-in account.
///
/// Accounts (email + password) live on the Wardrobe+ server, which returns a
/// sign-in token. Each account's closet and outfit history are stored on this
/// phone in their own database file, so different accounts never see each
/// other's clothes. Closets are not synced between phones.
class UserProfile {
  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static const _sinceKey = 'auth_created_at';
  static const _lastEmailKey = 'last_email';
  static const _legacyClaimedKey = 'legacy_closet_claimed';
  static const _onboardingKey = 'onboarding_done';

  /// Database id for an account: its email made file-name safe
  /// (demo@wardrobeplus.app -> demo_wardrobeplus_app).
  static String idFor(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

  static Future<String?> name() async => (await SharedPreferences.getInstance()).getString(_nameKey);
  static Future<String?> email() async => (await SharedPreferences.getInstance()).getString(_emailKey);
  static Future<String?> lastEmail() async => (await SharedPreferences.getInstance()).getString(_lastEmailKey);

  static Future<DateTime?> memberSince() async {
    final value = (await SharedPreferences.getInstance()).getString(_sinceKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Signs in with the server. Throws ApiException with a readable message.
  static Future<void> signIn(String email, String password) async =>
      completeSignIn(await ApiClient.login(email.trim(), password));

  /// Creates an account on the server and signs in to it (empty closet).
  static Future<void> register(String name, String email, String password) async =>
      completeSignIn(await ApiClient.register(name.trim(), email.trim(), password));

  /// Stores the server's sign-in response and opens that account's closet.
  static Future<void> completeSignIn(Map<String, dynamic> response) async {
    final user = Map<String, dynamic>.from(response['user'] as Map);
    final email = user['email'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, response['token'] as String);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_nameKey, user['name'] as String? ?? email.split('@').first);
    await prefs.setString(_lastEmailKey, email);
    if (user['created_at'] != null) await prefs.setString(_sinceKey, user['created_at'] as String);
    ApiClient.token = response['token'] as String;
    await _activate(idFor(email), prefs);
  }

  /// On app start: reopen the signed-in account (works offline; the server
  /// rejects the token later if it's no longer valid).
  static Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey);
    if (token == null || email == null) return false;
    ApiClient.token = token;
    await _activate(idFor(email), prefs);
    return true;
  }

  static Future<void> _activate(String id, SharedPreferences prefs) async {
    // Before accounts there was one shared closet on the phone. It goes to the
    // first account that signs in after the update; other accounts start empty.
    if (!(prefs.getBool(_legacyClaimedKey) ?? false)) {
      await DatabaseHelper.claimLegacyDatabase(id);
      await prefs.setBool(_legacyClaimedKey, true);
    }
    await DatabaseHelper.useProfile(id);
  }

  static Future<bool> onboardingDone() async =>
      (await SharedPreferences.getInstance()).getBool(_onboardingKey) ?? false;

  static Future<void> setOnboardingDone() async =>
      (await SharedPreferences.getInstance()).setBool(_onboardingKey, true);

  /// Signs out on this phone (and ends the session on the server if reachable).
  /// The account's closet stays on the phone for next time.
  static Future<void> signOut({bool tellServer = true}) async {
    if (tellServer) await ApiClient.logout();
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _emailKey, _nameKey, _sinceKey]) {
      await prefs.remove(key);
    }
    ApiClient.token = null;
    await DatabaseHelper.close();
  }
}
