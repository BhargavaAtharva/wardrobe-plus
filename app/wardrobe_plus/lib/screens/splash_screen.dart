import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_profile.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final onboardingDone = await UserProfile.onboardingDone();
    final signedIn = await UserProfile.restore(); // opens this profile's closet
    if (!mounted) return;
    final Widget next = !onboardingDone
        ? const OnboardingScreen()
        : signedIn
            ? const HomeScreen()
            : const LoginScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.checkroom,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ACloset AI',
              style: GoogleFonts.notoSerif(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF241A0E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YOUR SMART WARDROBE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4C4546),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}