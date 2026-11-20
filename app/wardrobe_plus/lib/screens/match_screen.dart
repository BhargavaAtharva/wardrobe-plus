import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'clothing_detail_screen.dart';

/// "Find a match": pick a top and see which pants go best with it (or the
/// other way round), ranked by the backend on colour, style, freshness and,
/// optionally, the occasion.
class MatchScreen extends StatefulWidget {
  final Map<String, dynamic> anchor;
  const MatchScreen({super.key, required this.anchor});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  String? _occasion; // null = any occasion
  bool _loading = true;
  ApiException? _error;
  String? _notice;
  List<Map<String, dynamic>> _matches = [];
  int _selected = 0;
  bool _loggedToday = false;

  bool get _anchorIsTop => widget.anchor['type'] != 'Pants';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final result = await ApiClient.match(
        anchorId: widget.anchor['id'] as int,
        items: await db.itemsForServer(),
        history: await db.historyForServer(),
        occasion: _occasion,
      );
      if (!mounted) return;
      if (result['error'] != null) {
        setState(() {
          _matches = [];
          _notice = result['message'] as String?;
        });
        return;
      }
      final matches = (result['matches'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _matches = matches;
        _selected = 0;
      });
      _refreshLogged();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> get _pairIds => [widget.anchor['id'] as int, _matches[_selected]['item']['id'] as int];

  Future<void> _refreshLogged() async {
    if (_matches.isEmpty) return;
    final logged = await DatabaseHelper.instance.isLoggedToday(_pairIds);
    if (mounted) setState(() => _loggedToday = logged);
  }

  Future<void> _wearToday() async {
    await DatabaseHelper.instance.logOutfit(_pairIds, _occasion ?? 'Casual');
    if (!mounted) return;
    setState(() => _loggedToday = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged as today\'s outfit')));
  }

  void _select(int index) {
    setState(() => _selected = index);
    _refreshLogged();
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothingDetailScreen(itemId: item['id'] as int)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final anchorLabel =
        '${Catalog.colorLabel(widget.anchor['color'] as String?).toLowerCase()} ${Catalog.typeLabel(widget.anchor['type'] as String?).toLowerCase()}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Find a match', style: AppText.body(size: 16, weight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text(_anchorIsTop ? 'Best pants for your $anchorLabel' : 'Best tops for your $anchorLabel',
              style: AppText.title(26).copyWith(height: 1.15)),
          const SizedBox(height: 6),
          Text('Ranked on colour, style and how recently you\'ve worn each piece.',
              style: AppText.body(size: 13, color: AppColors.muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [null, ...Catalog.occasions]
                .map((o) => SelectChip(
                      label: o ?? 'Any occasion',
                      selected: _occasion == o,
                      onTap: () {
                        if (_loading || _occasion == o) return;
                        setState(() => _occasion = o);
                        _load();
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Colors.black))),
          if (!_loading && _error != null)
            ErrorCard(message: _error!.message, onRetry: _load, showServerSettings: _error!.serverUnreachable),
          if (!_loading && _notice != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(20)),
              child: Text(_notice!, style: AppText.body()),
            ),
          if (!_loading && _matches.isNotEmpty) ..._results(),
        ],
      ),
    );
  }

  List<Widget> _results() {
    final best = _matches[_selected];
    final item = (best['item'] as Map).cast<String, dynamic>();
    final breakdown = Map<String, dynamic>.from(best['breakdown'] as Map);
    final reasons = List<String>.from(best['reasons'] as List);
    final top = _anchorIsTop ? widget.anchor : item;
    final bottom = _anchorIsTop ? item : widget.anchor;

    return [
      // The pair, top above bottom like it's worn
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _pairImage(top, highlight: !_anchorIsTop)),
              const SizedBox(width: 12),
              Expanded(child: _pairImage(bottom, highlight: _anchorIsTop)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 8),
              Text('${best['match_score']}% match', style: AppText.title(22)),
              const Spacer(),
              if (_selected == 0) const TagChip('Best match'),
            ]),
            const SizedBox(height: 12),
            _bar('Colour', breakdown['color'] as int),
            _bar('Style', breakdown['style'] as int),
            _bar('Freshness', breakdown['freshness'] as int),
            if (breakdown['occasion'] != null) _bar('Fits ${_occasion!.toLowerCase()}', breakdown['occasion'] as int),
            if ((breakdown['repeat_penalty'] as int) > 0)
              Text('−${breakdown['repeat_penalty']} for repeating a recent pair', style: AppText.body(size: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('•  ', style: AppText.body(size: 13)),
                    Expanded(child: Text(r, style: AppText.body(size: 13))),
                  ]),
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('match-wear-today'),
                onPressed: _loggedToday ? null : _wearToday,
                style: primaryButton(),
                child: Text(_loggedToday ? 'Logged for today ✓' : 'Wear This Today',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Text('ALL ${_anchorIsTop ? 'PANTS' : 'TOPS'} RANKED', style: AppText.label()),
      const SizedBox(height: 12),
      for (var i = 0; i < _matches.length; i++) _rankRow(i),
    ];
  }

  Widget _pairImage(Map<String, dynamic> item, {required bool highlight}) {
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 0.85,
          child: ItemImage(stored: item['imagePath'] as String?, width: double.infinity, borderRadius: BorderRadius.circular(18), iconSize: 40),
        ),
        const SizedBox(height: 8),
        Row(children: [
          ColorDot(item['color'] as String?, size: 10),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${Catalog.colorLabel(item['color'] as String?)} ${Catalog.typeLabel(item['type'] as String?).toLowerCase()}',
              style: AppText.body(size: 12, weight: highlight ? FontWeight.w600 : FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _rankRow(int index) {
    final m = _matches[index];
    final item = (m['item'] as Map).cast<String, dynamic>();
    final selected = index == _selected;
    return GestureDetector(
      onTap: () => _select(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.black : Colors.transparent, width: 1.5),
          boxShadow: cardShadow,
        ),
        child: Row(children: [
          SizedBox(width: 22, child: Text('${index + 1}', style: AppText.body(size: 13, color: AppColors.muted))),
          ItemImage(stored: item['imagePath'] as String?, width: 54, height: 54, borderRadius: BorderRadius.circular(12), iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${Catalog.colorLabel(item['color'] as String?)} ${Catalog.typeLabel(item['type'] as String?).toLowerCase()}',
                  style: AppText.body(size: 13, weight: FontWeight.w600)),
              Text(m['recently_worn'] == true ? 'Worn in the last 2 days' : (m['reasons'] as List).first as String,
                  style: AppText.body(size: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${m['match_score']}%', style: AppText.body(size: 14, weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _bar(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: AppText.body(size: 12, color: AppColors.inkSoft))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: value / 100, minHeight: 6, backgroundColor: AppColors.sand, color: Colors.black),
          ),
        ),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right, style: AppText.body(size: 12))),
      ]),
    );
  }
}
