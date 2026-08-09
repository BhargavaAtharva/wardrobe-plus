import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});
  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  String _selectedOccasion = 'Casual';
  final List<String> _occasions = ['Casual', 'Party', 'Office', 'Travel'];

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
                onTap: () => setState(() => _selectedOccasion = o),
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
            // Outfit card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 240,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4DFCB),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: const Center(child: Icon(Icons.checkroom, size: 72, color: Color(0xFF241A0E))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('White Linen Weekend Breeze',
                                style: GoogleFonts.notoSerif(fontSize: 20, fontWeight: FontWeight.w400, color: const Color(0xFF241A0E))),
                            const Spacer(),
                            const Icon(Icons.favorite_border, size: 20, color: Color(0xFF7E7576)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('98% Match · 3 Items',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7E7576))),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {},
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}