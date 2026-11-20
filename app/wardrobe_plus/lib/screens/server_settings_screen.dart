import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/config.dart';
import '../theme.dart';

/// Lets the user point the app at whichever Mac is running backend/start.sh.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});
  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _controller = TextEditingController(text: AppConfig.baseUrl);
  bool _testing = false;
  String? _status;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = AppConfig.normalize(_controller.text);
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final classes = await ApiClient.health(baseUrl: url);
      if (!mounted) return;
      setState(() {
        _ok = true;
        _status = 'Connected. The model recognises: ${classes.join(', ')}.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _status = e.serverUnreachable ? 'No answer from $url.' : e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    await AppConfig.setBaseUrl(_controller.text);
    _controller.text = AppConfig.baseUrl;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server set to ${AppConfig.baseUrl}')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0, title: Text('Server address', style: AppText.body(size: 16, weight: FontWeight.w600))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Photos are analysed and outfits are suggested by the Wardrobe+ server running on a Mac. '
              'On that Mac run backend/start.sh — it prints the address to type here. '
              'The phone and the Mac must be on the same Wi-Fi.',
              style: AppText.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: AppColors.sandLight, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                key: const Key('server-url-field'),
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'http://your-mac.local:5000',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tip: the ".local" name keeps working when the Mac\'s IP changes. If it doesn\'t connect (some hotspots block it), use the IP address instead.',
                style: AppText.body(size: 12, color: AppColors.muted)),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Icon(_ok ? Icons.check_circle : Icons.error_outline, size: 18, color: _ok ? Colors.green.shade700 : AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_status!, style: AppText.body(size: 13))),
              ]),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _testing ? null : _test,
                style: secondaryButton(),
                child: _testing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('Test connection', style: AppText.body(weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: primaryButton(),
                child: Text('Save', style: AppText.body(weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            TextButton(
              onPressed: () => _controller.text = AppConfig.defaultBaseUrl,
              child: Text('Reset to default', style: AppText.body(size: 13, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
