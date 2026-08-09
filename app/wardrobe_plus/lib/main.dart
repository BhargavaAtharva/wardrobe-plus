import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WardrobePlusApp());
}

class WardrobePlusApp extends StatelessWidget {
  const WardrobePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACloset AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF5D5F5B),
          surface: Color(0xFFFFF8F4),
          background: Color(0xFFFFF8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F4),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.notoSerif(
            fontSize: 42,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.02 * 42,
            height: 1.1,
            color: const Color(0xFF241A0E),
          ),
          headlineMedium: GoogleFonts.notoSerif(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: const Color(0xFF241A0E),
          ),
          titleSmall: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: 0.01 * 18,
            color: const Color(0xFF241A0E),
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: const Color(0xFF241A0E),
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0.1 * 12,
            color: const Color(0xFF241A0E),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}