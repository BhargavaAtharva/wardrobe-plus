import 'package:flutter/material.dart';

import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'clothing_detail_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});
  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _filter; // null = all types
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
      if (_filter != null && !items.any((i) => i['type'] == _filter)) _filter = null;
    });
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothingDetailScreen(itemId: item['id'] as int)));
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final item in _items) {
      final type = item['type'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final types = [...Catalog.types.where(counts.containsKey), ...counts.keys.where((t) => !Catalog.types.contains(t))];
    final visible = _filter == null ? _items : _items.where((i) => i['type'] == _filter).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: BrandBar()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('My Closet', style: AppText.title(28)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _filter == null ? plural(_items.length, 'item') : '${visible.length} of ${plural(_items.length, 'item')}',
              style: AppText.body(size: 13, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 16),
          if (types.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  ),
                  ...types.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SelectChip(
                          label: '${Catalog.typeLabel(t)} · ${counts[t]}',
                          selected: _filter == t,
                          onTap: () => setState(() => _filter = t),
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : RefreshIndicator(
                    color: Colors.black,
                    onRefresh: _loadItems,
                    child: _items.isEmpty
                        ? ListView(children: const [
                            EmptyState(
                              icon: Icons.checkroom_outlined,
                              title: 'Your closet is empty',
                              subtitle: 'Add clothes using the + button',
                            ),
                          ])
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (context, index) => _tile(visible[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _open(item),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ItemImage(
                stored: item['imagePath'] as String?,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                iconSize: 40,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Catalog.typeLabel(item['type'] as String?), style: AppText.body(size: 13, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    ColorDot(item['color'] as String?, size: 10),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${Catalog.colorLabel(item['color'] as String?)} · '
                        '${item['lastWorn'] == null ? 'never worn' : 'worn ${wornAgo(item['lastWorn']).toLowerCase()}'}',
                        style: AppText.body(size: 11, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
