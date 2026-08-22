import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:io';
import '../services/database_helper.dart';
import '../services/config.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});
  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  String _selectedOccasion = 'Casual';
  final List<String> _occasions = ['Casual', 'Office', 'Party', 'Travel'];
  bool _loading = false;
  Map<String, dynamic>? _suggestion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateOutfit();
  }

  Future<void> _generateOutfit() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestion = null;
    });

    try {
      // Get all items from database
      final items = await DatabaseHelper.instance.getAllItems();

      if (items.isEmpty) {
        setState(() {
          _error = 'Your closet is empty. Add some clothes first!';
          _loading = false;
        });
        return;
      }

      // Call suggest endpoint
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/suggest'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'items': items,
          'occasion': _selectedOccasion,
          'weather': {'temp': 28, 'description': 'sunny'},
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      setState(() => _suggestion = data);
    } catch (e) {
      setState(() => _error = 'Could not connect to server.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ACLOSET AI',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: const Color(0xFF241A0E))),
                const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF241A0E)),
              ],
            ),
            const SizedBox(height: 32),
            Text('Outfit\nGenerator',
                style: GoogleFonts.notoSerif(fontSize: 34, fontWeight: FontWeight.w400, height: 1.1, color: const Color(0xFF241A0E))),
            const SizedBox(height: 24),
            Text('SELECT OCCASION',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: const Color(0xFF7E7576))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _occasions.map((o) => GestureDetector(
                onTap: () {
                  setState(() => _selectedOccasion = o);
                  _generateOutfit();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedOccasion == o ? Colors.black : const Color(0xFFF4DFCB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedOccasion == o ? Colors.white : const Color(0xFF241A0E))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 28),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: Colors.black)),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4DFCB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_error!,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF241A0E))),
              ),

            if (_suggestion != null && !_loading) ...[
              // Outfit items
              ...(_suggestion!['suggestion'] as List).map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                ),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                      child: item['imagePath'] != null && File(item['imagePath']).existsSync()
                          ? Image.file(File(item['imagePath']), width: 90, height: 90, fit: BoxFit.cover)
                          : Container(
                              width: 90,
                              height: 90,
                              color: const Color(0xFFF4DFCB),
                              child: const Icon(Icons.checkroom, color: Color(0xFF241A0E)),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['type'] ?? '',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF241A0E))),
                        if (item['color'] != null)
                          Text(item['color'],
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7E7576))),
                      ],
                    ),
                  ],
                ),
              )).toList(),

              const SizedBox(height: 16),

              // Reason and score
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4DFCB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF241A0E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_suggestion!['reason']} · ${_suggestion!['match_score']}% match',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF241A0E)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Generate new button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _generateOutfit,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text('Generate New Look',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}