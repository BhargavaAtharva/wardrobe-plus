import 'package:flutter/material.dart';

import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'clothing_detail_screen.dart';

/// Everything logged with "Wear This Today", newest first.
class OutfitHistoryScreen extends StatefulWidget {
  const OutfitHistoryScreen({super.key});
  @override
  State<OutfitHistoryScreen> createState() => _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends State<OutfitHistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<int, Map<String, dynamic>> _items = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final logs = await db.getOutfitLogs();
    final items = {for (final i in await db.getAllItems()) i['id'] as int: i};
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _items = items;
      _loaded = true;
    });
  }

  Future<void> _delete(Map<String, dynamic> log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Remove this outfit?', style: AppText.title(20)),
        content: Text('Last-worn dates and wear counts will be updated.', style: AppText.body(color: AppColors.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppText.body())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove', style: AppText.body(color: AppColors.error, weight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteOutfitLog(log['id'] as int);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Group by calendar day
    final groups = <String, List<Map<String, dynamic>>>{};
    final headings = <String, String>{};
    for (final log in _logs) {
      final date = parseDate(log['date']) ?? DateTime.now();
      final key = '${date.year}-${date.month}-${date.day}';
      groups.putIfAbsent(key, () => []).add(log);
      headings[key] = dayHeading(date);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Outfit History', style: AppText.body(size: 16, weight: FontWeight.w600)),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _logs.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No outfits logged yet',
                  subtitle: 'Tap "Wear This Today" on a suggested outfit and it will show up here.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Text('${plural(_logs.length, 'outfit')} worn', style: AppText.body(size: 13, color: AppColors.muted)),
                    for (final entry in groups.entries) ...[
                      const SizedBox(height: 20),
                      Text(headings[entry.key]!.toUpperCase(), style: AppText.label()),
                      const SizedBox(height: 10),
                      ...entry.value.map(_logCard),
                    ],
                  ],
                ),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final ids = DatabaseHelper.parseIds(log['itemIds']);
    final pieces = ids.map((id) => _items[id]).toList();
    final names = pieces
        .map((i) => i == null ? 'deleted item' : '${Catalog.colorLabel(i['color'] as String?).toLowerCase()} ${Catalog.typeLabel(i['type'] as String?).toLowerCase()}')
        .join(' + ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Row(
        children: [
          ...pieces.map((item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: item == null
                      ? null
                      : () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ClothingDetailScreen(itemId: item['id'] as int)));
                          _load();
                        },
                  child: ItemImage(
                    stored: item?['imagePath'] as String?,
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(12),
                    iconSize: 22,
                  ),
                ),
              )),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log['occasion'] as String? ?? 'Casual', style: AppText.body(size: 13, weight: FontWeight.w600)),
              Text(names, style: AppText.body(size: 12, color: AppColors.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(
            onPressed: () => _delete(log),
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
