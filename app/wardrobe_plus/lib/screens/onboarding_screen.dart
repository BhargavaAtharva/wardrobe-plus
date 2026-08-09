import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _current = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'tag1': 'OUTERWEAR',
      'tag2': 'CHARCOAL',
      'tag3': 'MINIMALIST',
      'title': 'AI-Powered\nOrganization.',
      'body': 'Our ML model automatically identifies type, color, and style, removing backgrounds for a clean look.',
      'button': 'Continue',
    },
    {
      'tag1': 'CASUAL',
      'tag2': 'SUMMER',
      'tag3': 'RELAXED',
      'title': 'Capture\nYour Style.',
      'body': 'Simply take a photo of your clothes to start building your digital wardrobe.',
      'button': 'Continue',
    },
    {
      'tag1': 'CURATED',
      'tag2': 'DAILY',
      'tag3': 'SMART',
      'title': 'Smart\nSuggestions.',
      'body': 'Receive personalized outfit ideas tailored to your wardrobe and the occasion.',
      'button': 'Get Started',
    },
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ACLOSET AI',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                          color: const Color(0xFF241A0E))),
                  GestureDetector(
                    onTap: _finish,
                    child: Text('Skip',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF7E7576))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        // AI tags row
                        Row(
                          children: [
                            _tag(p['tag1']),
                            const SizedBox(width: 8),
                            _tag(p['tag2']),
                            const SizedBox(width: 8),
                            _tag(p['tag3']),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Illustration placeholder
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4DFCB),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                            child: Icon(Icons.checkroom, size: 64, color: Color(0xFF241A0E)),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          p['title'],
                          style: GoogleFonts.notoSerif(
                            fontSize: 38,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                            letterSpacing: -0.5,
                            color: const Color(0xFF241A0E),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p['body'],
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: const Color(0xFF4C4546),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) =>
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _current == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _current == i ? Colors.black : const Color(0xFFCFC4C5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_current < _pages.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finish();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_pages[_current]['button'],
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4DFCB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: const Color(0xFF241A0E))),
    );
  }
}