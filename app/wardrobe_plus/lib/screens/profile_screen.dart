import 'package:flutter/material.dart';

import '../services/config.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../services/user_profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show Tabs;
import 'login_screen.dart';
import 'outfit_history_screen.dart';
import 'server_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const ProfileScreen({super.key, required this.onNavigate});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  DateTime? _since;
  int _items = 0;
  int _outfits = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await UserProfile.name();
    final email = await UserProfile.email();
    final since = await UserProfile.memberSince();
    final items = await DatabaseHelper.instance.getTotalItems();
    final outfits = await DatabaseHelper.instance.getTotalOutfitsLogged();
    if (!mounted) return;
    setState(() {
      _name = name ?? '';
      _email = email ?? '';
      _since = since;
      _items = items;
      _outfits = outfits;
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Sign out?', style: AppText.title(20)),
        content: Text('Your closet and outfit history stay saved on this phone. Sign in as $_email to see them again.',
            style: AppText.body(color: AppColors.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppText.body())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sign out', style: AppText.body(color: AppColors.error, weight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true) return;
    await UserProfile.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _howItWorks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How Wardrobe+ works', style: AppText.title(22)),
              const SizedBox(height: 16),
              _point('Adding clothes',
                  'The photo is sent to the server, which removes the background, identifies the type with an EfficientNet model (T-shirt, shirt, pants or dress) and finds the main colour. You can correct both before saving.'),
              _point('Choosing an outfit',
                  'Every possible top + pants or dress is scored: 35% colour harmony, 30% freshness and 35% fit for the occasion — whether the main piece suits it (a shirt for Office, a dress for Party) and whether its colours match the mood (muted for Office, bold for Party). The best one is shown with the reasons; Show Another switches to a different look.'),
              _point('Find a match',
                  'Open a top or pants and every piece of the other kind is ranked on colour (harmony plus light/dark contrast), style (how dressy each piece is — shirt + trousers or T-shirt + jeans match best) and freshness.'),
              _point('Freshness',
                  'The longer since a piece was last worn, the higher it scores (14+ days or never worn is the maximum). Anything worn in the last 2 days is skipped, and repeating an exact outfit from the last week loses points.'),
              _point('Your account', 'You sign in with your email and password; accounts are kept on the Wardrobe+ server (passwords are stored hashed). Each account\'s closet and history are stored on this phone.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.body(weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(body, style: AppText.body(size: 13, color: AppColors.inkSoft)),
        ]),
      );

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.isEmpty ? '?' : _name[0].toUpperCase();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const BrandBar(),
          Row(children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(32)),
              child: Text(initial, style: AppText.title(26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name.isEmpty ? 'You' : _name, style: AppText.title(22), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_email, style: AppText.body(size: 13, color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_since == null ? '' : 'Member since ${shortDate(_since!.toIso8601String())}',
                    style: AppText.body(size: 13, color: AppColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _stat('$_items', 'ITEMS IN CLOSET')),
            const SizedBox(width: 12),
            Expanded(child: _stat('$_outfits', 'OUTFITS WORN')),
          ]),
          const SizedBox(height: 28),
          Text('SETTINGS', style: AppText.label()),
          const SizedBox(height: 12),
          _menuItem(Icons.history, 'Outfit history', 'Everything you\'ve logged as worn', () => _push(const OutfitHistoryScreen())),
          _menuItem(Icons.checkroom_outlined, 'Manage closet', 'View, edit and delete your clothes', () => widget.onNavigate(Tabs.closet)),
          _menuItem(Icons.dns_outlined, 'Server address', AppConfig.baseUrl, () => _push(const ServerSettingsScreen())),
          _menuItem(Icons.help_outline, 'How suggestions work', 'What the AI does and how outfits are scored', _howItWorks),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow),
              child: Row(children: [
                const Icon(Icons.logout, size: 20, color: AppColors.error),
                const SizedBox(width: 12),
                Text('Sign out', style: AppText.body(size: 15, weight: FontWeight.w500, color: AppColors.error)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppText.title(22)),
          Text(label, style: AppText.label().copyWith(fontSize: 9, letterSpacing: 1.2)),
        ]),
      );

  Widget _menuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body(weight: FontWeight.w500)),
              Text(subtitle, style: AppText.body(size: 12, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}
