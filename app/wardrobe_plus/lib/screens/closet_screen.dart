import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/database_helper.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});
  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getAllItems();
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ACLOSET AI',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: const Color(0xFF241A0E))),
                const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF241A0E)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Closet',
                    style: GoogleFonts.notoSerif(fontSize: 28, fontWeight: FontWeight.w400, color: const Color(0xFF241A0E))),
                GestureDetector(
                  onTap: _loadItems,
                  child: const Icon(Icons.refresh, color: Color(0xFF7E7576)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('${_items.length} items',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7E7576))),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.checkroom_outlined, size: 48, color: Color(0xFFCFC4C5)),
                        const SizedBox(height: 16),
                        Text('Your closet is empty',
                            style: GoogleFonts.notoSerif(fontSize: 20, color: const Color(0xFF4C4546))),
                        const SizedBox(height: 8),
                        Text('Add clothes using the + button',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7E7576))),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF4DFCB),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: item['imagePath'] != null && File(item['imagePath']).existsSync()
                                    ? ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                        child: Image.file(File(item['imagePath']), fit: BoxFit.cover, width: double.infinity),
                                      )
                                    : const Center(child: Icon(Icons.checkroom, size: 40, color: Color(0xFF241A0E))),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['type'] ?? 'Unknown',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF241A0E))),
                                  Text('${item['confidence']?.toStringAsFixed(1) ?? ''}% match',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7E7576))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}