import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'closet_screen.dart';
import 'add_clothing_screen.dart';
import 'outfit_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboard(),
    const ClosetScreen(),
    const AddClothingScreen(),
    const OutfitScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F4),
          border: Border(top: BorderSide(color: Color(0xFFEBD7C3), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: const Color(0xFFFFF8F4),
          selectedItemColor: Colors.black,
          unselectedItemColor: const Color(0xFF7E7576),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.checkroom_outlined), activeIcon: Icon(Icons.checkroom), label: 'Closet'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 32), activeIcon: Icon(Icons.add_circle, size: 32), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'Outfits'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ACLOSET AI',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: const Color(0xFF241A0E))),
                const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF241A0E)),
              ],
            ),
            const SizedBox(height: 32),
            Text("Today's Curations",
                style: GoogleFonts.notoSerif(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF241A0E))),
            const SizedBox(height: 20),
            // Featured outfit card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4DFCB),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: const Center(
                      child: Icon(Icons.checkroom, size: 72, color: Color(0xFF241A0E)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4DFCB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('MINIMALIST CHIC',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      color: const Color(0xFF241A0E))),
                            ),
                            const Spacer(),
                            const Icon(Icons.favorite_border, size: 20, color: Color(0xFF7E7576)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('The Editorial Edit',
                            style: GoogleFonts.notoSerif(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF241A0E))),
                        const SizedBox(height: 6),
                        Text('Perfect for your upcoming meetings. Structured elegance meets comfort.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.5,
                                color: const Color(0xFF4C4546))),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            child: Text('Wear This',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Recently Added
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recently Added',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF241A0E))),
                Text('VIEW ALL',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: const Color(0xFF7E7576))),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _recentItem('Linen Blazer', 'Acne Studios'),
                  _recentItem('Minimalist Sneaker', 'Common Projects'),
                  _recentItem('Silk Dress', 'Theory'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Closet Insights
            Text('Closet Insights',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF241A0E))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _insightCard('142', 'TOTAL ITEMS', Icons.checkroom_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _insightCard('85%', 'WEAR RATE', Icons.eco_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _insightCard('\$2.4k', 'VALUE', Icons.trending_up)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _recentItem(String name, String brand) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4DFCB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Center(child: Icon(Icons.checkroom, color: Color(0xFF241A0E))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF241A0E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(brand,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF7E7576)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF241A0E)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.notoSerif(fontSize: 20, fontWeight: FontWeight.w400, color: const Color(0xFF241A0E))),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: const Color(0xFF7E7576))),
        ],
      ),
    );
  }
}