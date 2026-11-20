import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'clothing_detail_screen.dart';
import 'match_screen.dart';

/// Today's outfit. The backend scores every valid combination on colour
/// harmony, freshness (days since worn) and occasion fit, and explains why.
class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});
  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  String _occasion = 'Casual';
  bool _loading = false;
  bool _closetEmpty = false;
  Map<String, dynamic>? _suggestion;
  String? _notice; // e.g. "add a pair of pants" — not an error
  ApiException? _error;
  bool _loggedToday = false;
  bool _logging = false;

  /// Outfits already shown this session, per occasion, so "Show another" moves on.
  final Map<String, List<String>> _shown = {};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate({bool another = false}) async {
    if (!another) _shown[_occasion] = [];
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final items = await db.getAllItems();
      if (items.isEmpty) {
        setState(() {
          _closetEmpty = true;
          _suggestion = null;
        });
        return;
      }
      _closetEmpty = false;
      final result = await ApiClient.suggest(
        occasion: _occasion,
        items: await db.itemsForServer(),
        history: await db.historyForServer(),
        excludeKeys: _shown[_occasion] ?? [],
      );
      if (!mounted) return;
      if (result['error'] != null) {
        setState(() {
          _suggestion = null;
          _notice = result['message'] as String?;
        });
        return;
      }
      final ids = _ids(result);
      final logged = await db.isLoggedToday(ids);
      if (!mounted) return;
      _shown.putIfAbsent(_occasion, () => []).add(result['key'] as String);
      if (result['cycled'] == true && another) {
        _shown[_occasion] = [result['key'] as String];
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That\'s every combination for this occasion — starting from the best again.')));
      }
      setState(() {
        _suggestion = result;
        _loggedToday = logged;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> _ids(Map<String, dynamic> suggestion) =>
      (suggestion['suggestion'] as List).map<int>((i) => i['id'] as int).toList();

  Future<void> _wearToday() async {
    setState(() => _logging = true);
    await DatabaseHelper.instance.logOutfit(_ids(_suggestion!), _occasion);
    if (!mounted) return;
    setState(() {
      _logging = false;
      _loggedToday = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged as today\'s outfit')));
  }

  /// Pick a top or pants, then see what goes best with it.
  Future<void> _pickPiece() async {
    final pieces = (await DatabaseHelper.instance.getAllItems())
        .where((i) => Catalog.matchable(i['type'] as String?))
        .toList();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text('Pick a top or pants', style: AppText.title(22)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('We\'ll rank everything that goes with it.', style: AppText.body(size: 13, color: AppColors.muted)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: pieces.isEmpty
                  ? const EmptyState(icon: Icons.checkroom_outlined, title: 'No tops or pants yet', subtitle: 'Add some with the + button.')
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
                      itemCount: pieces.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => Navigator.pop(context, pieces[i]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: ItemImage(
                              stored: pieces[i]['imagePath'] as String?,
                              width: double.infinity,
                              borderRadius: BorderRadius.circular(14),
                              iconSize: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            ColorDot(pieces[i]['color'] as String?, size: 9),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(Catalog.typeLabel(pieces[i]['type'] as String?),
                                  style: AppText.body(size: 11, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ]),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(anchor: picked)));
    _generate();
  }

  Future<void> _openItem(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothingDetailScreen(itemId: id)));
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const BrandBar(),
          Text('Outfit\nGenerator', style: AppText.title(34).copyWith(height: 1.1)),
          const SizedBox(height: 24),
          Text('SELECT OCCASION', style: AppText.label()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Catalog.occasions
                .map((o) => SelectChip(
                      label: o,
                      selected: _occasion == o,
                      onTap: () {
                        if (_loading) return;
                        setState(() => _occasion = o);
                        _generate();
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('start-from-piece'),
              onPressed: _pickPiece,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.join_inner, size: 16, color: AppColors.ink),
              label: Text('Or start from a piece you choose', style: AppText.body(size: 13, weight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Colors.black))),
          if (!_loading && _closetEmpty)
            const EmptyState(icon: Icons.checkroom_outlined, title: 'Your closet is empty', subtitle: 'Add some clothes with the + button first.'),
          if (!_loading && _error != null)
            ErrorCard(message: _error!.message, onRetry: _generate, showServerSettings: _error!.serverUnreachable),
          if (!_loading && _notice != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(20)),
              child: Text(_notice!, style: AppText.body()),
            ),
          if (!_loading && _suggestion != null) ..._suggestionView(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _suggestionView() {
    final s = _suggestion!;
    final items = (s['suggestion'] as List).cast<Map<String, dynamic>>();
    final breakdown = Map<String, dynamic>.from(s['breakdown'] as Map);
    final reasons = List<String>.from(s['reasons'] as List);
    return [
      ...items.map((item) => GestureDetector(
            onTap: () => _openItem(item['id'] as int),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
              child: Row(children: [
                ItemImage(
                  stored: item['imagePath'] as String?,
                  width: 90,
                  height: 90,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Catalog.typeLabel(item['type'] as String?), style: AppText.body(size: 15, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(children: [
                      ColorDot(item['color'] as String?, size: 10),
                      const SizedBox(width: 6),
                      Text(Catalog.colorLabel(item['color'] as String?), style: AppText.body(size: 12, color: AppColors.muted)),
                    ]),
                    Text(item['lastWorn'] == null ? 'Never worn' : 'Last worn ${wornAgo(item['lastWorn']).toLowerCase()}',
                        style: AppText.body(size: 12, color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
                const SizedBox(width: 8),
              ]),
            ),
          )),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 8),
              Text('${s['match_score']}% match', style: AppText.title(22)),
            ]),
            const SizedBox(height: 14),
            _bar('Colour harmony', breakdown['color'] as int),
            _bar('Freshness', breakdown['freshness'] as int),
            _bar('Fits ${_occasion.toLowerCase()}', breakdown['occasion'] as int),
            if ((breakdown['repeat_penalty'] as int) > 0)
              Text('−${breakdown['repeat_penalty']} for repeating a recent outfit',
                  style: AppText.body(size: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('•  ', style: AppText.body(size: 13)),
                    Expanded(child: Text(r, style: AppText.body(size: 13))),
                  ]),
                )),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          key: const Key('wear-today'),
          onPressed: _loggedToday || _logging ? null : _wearToday,
          style: secondaryButton(),
          child: Text(_loggedToday ? 'Logged for today ✓' : 'Wear This Today',
              style: AppText.body(size: 14, weight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          key: const Key('show-another'),
          onPressed: () => _generate(another: true),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(
            (s['options_left'] as int) > 0 ? 'Show Another Look' : 'Start Over',
            style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white),
          ),
          style: primaryButton(),
        ),
      ),
    ];
  }

  Widget _bar(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: AppText.body(size: 12, color: AppColors.inkSoft))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              backgroundColor: Colors.white,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right, style: AppText.body(size: 12))),
      ]),
    );
  }
}
