import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/user_profile.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'server_settings_screen.dart';

/// Sign in (or create an account) with email and password. Accounts are kept
/// on the Wardrobe+ server; each account has its own closet on this phone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password]) {
      c.addListener(() => setState(() {}));
    }
    UserProfile.lastEmail().then((e) {
      if (e != null && mounted && _email.text.isEmpty) _email.text = e;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _email.text.contains('@') &&
      _password.text.length >= (_creating ? 6 : 1) &&
      (!_creating || _name.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        await UserProfile.register(_name.text, _email.text, _password.text);
      } else {
        await UserProfile.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {Key? key, TextInputType? type, bool obscure = false, Widget? suffix, TextCapitalization caps = TextCapitalization.none}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.sandLight, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        key: key,
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        autocorrect: false,
        textCapitalization: caps,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body(size: 15, color: AppColors.muted),
          border: InputBorder.none,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 40),
            Text('ACLOSET AI', style: AppText.brand()),
            const SizedBox(height: 32),
            Text(_creating ? 'Create your\naccount.' : 'Welcome\nback.', style: AppText.title(38).copyWith(height: 1.1)),
            const SizedBox(height: 12),
            Text(
              _creating ? 'Your closet starts empty — add clothes and get outfit ideas.' : 'Sign in to open your closet.',
              style: AppText.body(size: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 32),
            if (_creating)
              _field(_name, 'Your name', key: const Key('name-field'), caps: TextCapitalization.words),
            _field(_email, 'Email address', key: const Key('email-field'), type: TextInputType.emailAddress),
            _field(
              _password,
              _creating ? 'Password (at least 6 characters)' : 'Password',
              key: const Key('password-field'),
              obscure: !_showPassword,
              suffix: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.muted),
              ),
            ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(14)),
                child: Text(_error!.message, style: AppText.body(size: 13, color: AppColors.errorText)),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                key: const Key('submit-auth'),
                onPressed: _canSubmit ? _submit : null,
                style: primaryButton(),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_creating ? 'Create account' : 'Sign in',
                        style: AppText.body(size: 16, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: const Key('toggle-auth-mode'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _creating = !_creating;
                          _error = null;
                        }),
                child: Text(_creating ? 'Already have an account? Sign in' : 'New here? Create an account',
                    style: AppText.body(size: 14, weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
                icon: const Icon(Icons.dns_outlined, size: 16, color: AppColors.muted),
                label: Text('Server address', style: AppText.body(size: 12, color: AppColors.muted)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
