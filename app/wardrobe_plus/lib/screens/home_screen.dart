import 'package:flutter/material.dart';

import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../services/user_profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_clothing_screen.dart';
import 'closet_screen.dart';
import 'clothing_detail_screen.dart';
import 'outfit_history_screen.dart';
import 'outfit_screen.dart';
import 'profile_screen.dart';

/// Tab indexes for the bottom navigation.
class Tabs {
  static const home = 0, closet = 1, add = 2, outfits = 3, profile = 4;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = Tabs.home;

  void _goTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // Each tab is rebuilt when selected, so it always shows fresh data.
    final screens = [
      HomeDashboard(onNavigate: _goTo),
      const ClosetScreen(),
      AddClothingScreen(onAdded: () => _goTo(Tabs.closet)),
      const OutfitScreen(),
      ProfileScreen(onNavigate: _goTo),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _goTo,
          backgroundColor: AppColors.background,
          selectedItemColor: Colors.black,
          unselectedItemColor: AppColors.muted,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.checkroom_outlined), activeIcon: Icon(Icons.checkroom), label: 'Closet'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 32), activeIcon: Icon(Icons.add_circle, size: 32), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'Outfits'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const HomeDashboard({super.key, required this.onNavigate});
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  bool _loaded = false;
  String _name = '';
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _forgotten = [];
  List<Map<String, dynamic>> _todayItems = [];
  String? _todayOccasion;
  int _totalItems = 0;
  int _outfitsLogged = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final name = await UserProfile.name();
    final recent = await db.getRecentItems(limit: 8);
    final forgotten = await db.getNotWornInAWhile();
    final total = await db.getTotalItems();
    final outfits = await db.getTotalOutfitsLogged();
    final today = await db.getLatestOutfitToday();
    final todayItems = <Map<String, dynamic>>[];
    if (today != null) {
      for (final id in DatabaseHelper.parseIds(today['itemIds'])) {
        final item = await db.getItem(id);
        if (item != null) todayItems.add(item);
      }
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _name = name ?? '';
      _recent = recent;
      _forgotten = forgotten;
      _totalItems = total;
      _outfitsLogged = outfits;
      _todayItems = todayItems;
      _todayOccasion = today?['occasion'] as String?;
    });
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothingDetailScreen(itemId: item['id'] as int)));
    _load();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return _name.isEmpty ? part : '$part, $_name';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: Colors.black));
    return SafeArea(
      child: RefreshIndicator(
        color: Colors.black,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const BrandBar(),
            Text(_greeting, style: AppText.title(28)),
            const SizedBox(height: 20),
            _todayCard(),
            const SizedBox(height: 32),
            _sectionHeader('Recently Added', action: _recent.isEmpty ? null : 'VIEW ALL', onAction: () => widget.onNavigate(Tabs.closet)),
            const SizedBox(height: 16),
            if (_recent.isEmpty)
              _hintCard('Your closet is empty. Photograph your first piece to get started.', 'Add clothing', () => widget.onNavigate(Tabs.add))
            else
              _itemRow(_recent, (item) => Catalog.colorLabel(item['color'] as String?)),
            if (_forgotten.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionHeader('Haven\'t Worn in a While'),
              const SizedBox(height: 4),
              Text('Not worn for 2+ weeks. Outfit suggestions bring these back first.',
                  style: AppText.body(size: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              _itemRow(_forgotten, (item) {
                final days = daysSince(item['lastWorn']);
                return days == null ? 'Never worn' : '$days days';
              }),
            ],
            const SizedBox(height: 32),
            _sectionHeader('Closet Insights'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _insight('$_totalItems', 'ITEMS', Icons.checkroom_outlined, () => widget.onNavigate(Tabs.closet))),
                const SizedBox(width: 12),
                Expanded(child: _insight('$_outfitsLogged', 'OUTFITS WORN', Icons.history, _openHistory)),
                const SizedBox(width: 12),
                Expanded(child: _insight('${_forgotten.length}', 'NOT WORN 14D+', Icons.hourglass_bottom, null)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openHistory() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const OutfitHistoryScreen()));
    _load();
  }

  Widget _todayCard() {
    final picked = _todayItems.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
            child: Text(picked ? 'TODAY · ${(_todayOccasion ?? 'Casual').toUpperCase()}' : 'TODAY',
                style: AppText.label().copyWith(fontSize: 10, color: AppColors.ink, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 12),
          Text(picked ? 'Today\'s outfit' : 'Your daily look', style: AppText.title(22)),
          const SizedBox(height: 12),
          if (picked)
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _todayItems.map((i) => ItemCard(item: i, onTap: () => _openItem(i))).toList(),
              ),
            )
          else
            Text(
              _totalItems == 0
                  ? 'Add a few clothes and we\'ll put together an outfit for you.'
                  : 'Pick an occasion and get an outfit that favours pieces you haven\'t worn lately.',
              style: AppText.body(size: 13, color: AppColors.inkSoft),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => widget.onNavigate(_totalItems == 0 ? Tabs.add : Tabs.outfits),
              style: picked ? secondaryButton() : primaryButton(),
              child: Text(
                _totalItems == 0 ? 'Add clothing' : (picked ? 'Generate another look' : 'Get today\'s outfit'),
                style: AppText.body(size: 14, weight: FontWeight.w600, color: picked ? Colors.black : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.body(size: 16, weight: FontWeight.w600)),
        if (action != null)
          GestureDetector(onTap: onAction, child: Text(action, style: AppText.label().copyWith(letterSpacing: 1.5))),
      ],
    );
  }

  Widget _itemRow(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) caption) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, i) => ItemCard(item: items[i], caption: caption(items[i]), onTap: () => _openItem(items[i])),
      ),
    );
  }

  Widget _hintCard(String text, String button, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppText.body(size: 13, color: AppColors.inkSoft)),
          TextButton(onPressed: onTap, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: Text(button, style: AppText.body(size: 13, weight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _insight(String value, String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.ink),
            const SizedBox(height: 8),
            Text(value, style: AppText.title(20)),
            const SizedBox(height: 2),
            Text(label, style: AppText.label().copyWith(fontSize: 9, letterSpacing: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
