import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            // Profile header
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4DFCB),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(Icons.person, size: 32, color: Color(0xFF241A0E)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elena Rossi',
                        style: GoogleFonts.notoSerif(fontSize: 22, fontWeight: FontWeight.w400, color: const Color(0xFF241A0E))),
                    Text('Member since 2023',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7E7576))),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCFC4C5)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Edit Profile',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF241A0E))),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Gold banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACloset Gold',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        Text('Unlock unlimited outfit generations and exclusive collections.',
                            style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('SETTINGS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: const Color(0xFF7E7576))),
            const SizedBox(height: 12),
            _menuItem(Icons.tune, 'Style Preferences', 'Update sizes, favorite brands, and color palettes.'),
            _menuItem(Icons.checkroom_outlined, 'Manage Closet', 'Organize your uploaded garments and categories.'),
            _menuItem(Icons.lock_outline, 'Security & Privacy', 'Password, 2FA, and data visibility settings.'),
            _menuItem(Icons.help_outline, 'Help & Support', 'FAQs, contact stylist, and app feedback.'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: Color(0xFFBA1A1A)),
                    const SizedBox(width: 12),
                    Text('Sign Out',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFFBA1A1A))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF241A0E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF241A0E))),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: const Color(0xFF7E7576))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF7E7576)),
        ],
      ),
    );
  }
}
