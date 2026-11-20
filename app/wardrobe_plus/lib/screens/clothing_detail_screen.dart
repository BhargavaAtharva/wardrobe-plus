import 'package:flutter/material.dart';

import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'match_screen.dart';

/// One item: photo, tags, wear stats, and edit/delete.
class ClothingDetailScreen extends StatefulWidget {
  final int itemId;
  const ClothingDetailScreen({super.key, required this.itemId});
  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen> {
  Map<String, dynamic>? _item;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await DatabaseHelper.instance.getItem(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _loaded = true;
    });
  }

  Future<void> _edit() async {
    final item = _item!;
    String type = item['type'] as String;
    String color = (item['color'] as String?) ?? 'unknown';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit item', style: AppText.title(22)),
                const SizedBox(height: 6),
                Text('Correct the AI if it got the type or colour wrong.', style: AppText.body(size: 13, color: AppColors.muted)),
                const SizedBox(height: 20),
                Text('TYPE', style: AppText.label()),
                const SizedBox(height: 10),
                TypeSelector(selected: type, onChanged: (t) => setSheet(() => type = t)),
                const SizedBox(height: 20),
                Text('COLOUR', style: AppText.label()),
                const SizedBox(height: 10),
                ColorSelector(selected: color, onChanged: (c) => setSheet(() => color = c)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('save-edit'),
                    onPressed: () => Navigator.pop(context, true),
                    style: primaryButton(),
                    child: Text('Save', style: AppText.body(weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      await DatabaseHelper.instance.updateItem(widget.itemId, type: type, color: color);
      _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Delete this item?', style: AppText.title(20)),
        content: Text('It will be removed from your closet. Past outfits stay in your history.',
            style: AppText.body(size: 14, color: AppColors.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppText.body())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppText.body(color: AppColors.error, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteItem(widget.itemId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (item != null) IconButton(key: const Key('edit-item'), onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          if (item != null) IconButton(key: const Key('delete-item'), onPressed: _delete, icon: const Icon(Icons.delete_outline, color: AppColors.error)),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : item == null
              ? const EmptyState(icon: Icons.help_outline, title: 'Item not found', subtitle: 'It may have been deleted.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    AspectRatio(
                      aspectRatio: 0.85,
                      child: ItemImage(
                        stored: item['imagePath'] as String?,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(28),
                        iconSize: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(Catalog.typeLabel(item['type'] as String?), style: AppText.title(30)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      TagChip(Catalog.colorLabel(item['color'] as String?), colorDot: item['color'] as String?),
                      if (item['confidence'] != null)
                        TagChip('AI ${(item['confidence'] as num).toStringAsFixed(0)}% sure'),
                    ]),
                    if (Catalog.matchable(item['type'] as String?)) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          key: const Key('find-match'),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(anchor: item)));
                            _load();
                          },
                          icon: const Icon(Icons.join_inner, size: 18),
                          label: Text(
                            item['type'] == 'Pants' ? 'Find a top that goes with these' : 'Find pants that go with this',
                            style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white),
                          ),
                          style: primaryButton(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(child: _stat('${item['wearCount'] ?? 0}', 'TIMES WORN')),
                      const SizedBox(width: 12),
                      Expanded(child: _stat(wornAgo(item['lastWorn']), 'LAST WORN')),
                      const SizedBox(width: 12),
                      Expanded(child: _stat(shortDate(item['dateAdded']), 'ADDED')),
                    ]),
                    const SizedBox(height: 16),
                    if ((daysSince(item['lastWorn']) ?? daysSince(item['dateAdded']) ?? 0) >= 14)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('You haven\'t worn this in a while, so outfit suggestions will favour it.',
                                style: AppText.body(size: 13)),
                          ),
                        ]),
                      ),
                  ],
                ),
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.body(size: 15, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: AppText.label().copyWith(fontSize: 9, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}
