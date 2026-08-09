import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text('ACLOSET AI',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                      color: const Color(0xFF241A0E))),
              const SizedBox(height: 40),
              Text(
                'Your personal\ndigital concierge.',
                style: GoogleFonts.notoSerif(
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: const Color(0xFF241A0E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Curated style and wardrobe management.',
                style: GoogleFonts.inter(
                    fontSize: 15, height: 1.6, color: const Color(0xFF4C4546)),
              ),
              const Spacer(),
              // Email field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAE5D1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Email Address',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 15, color: const Color(0xFF7E7576)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Continue with Email
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text('Continue with Email',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              // Divider
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFCFC4C5))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Or',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF7E7576))),
                ),
                const Expanded(child: Divider(color: Color(0xFFCFC4C5))),
              ]),
              const SizedBox(height: 16),
              // Apple button
              _socialButton(context, 'Continue with Apple', Icons.apple),
              const SizedBox(height: 12),
              // Google button
              _socialButton(context, 'Continue with Google', Icons.g_mobiledata),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.6,
                      color: const Color(0xFF7E7576)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(BuildContext context, String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
        icon: Icon(icon, color: Colors.black),
        label: Text(label,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCFC4C5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
        ),
      ),
    );
  }
}