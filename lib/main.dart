import 'package:flutter/material.dart';
import 'dunya_tarama_sayfasi.dart';
import 'haberler_sayfasi.dart';
import 'firsatlar_sayfasi.dart';
import 'ayarlar_sayfasi.dart';
import 'trend_tahmini_sayfasi.dart';
import 'trendora_ai_sayfasi.dart';
void main() {
  runApp(const TrendoraApp());
}

class TrendoraApp extends StatelessWidget {
  const TrendoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trendora',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
      ),
      home: const AcilisSayfasi(),
    );
  }
}

class AcilisSayfasi extends StatelessWidget {
  const AcilisSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.amber,
                  size: 90,
                ),
                const SizedBox(height: 24),
                const Text(
                  'TRENDORA',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Dünyayı Tara\nYapay Zekâ Analiz Etsin\nTrendi Önceden Yakala',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 19,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DunyaTaramaSayfasi(
  sonrakiSayfa: AnaMenu(),
),
    ),
  );
},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text(
                      'BAŞLAT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'TRENDORA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(18),
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children:  [
          MenuKarti(
  icon: Icons.newspaper,
  title: 'Haberler',
  description: 'Gündemi takip et',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HaberlerSayfasi(),
      ),
    );
  },
),
          MenuKarti(
  icon: Icons.trending_up,
  title: 'Trend Tahmini',
  description: 'Yükselen konuları keşfet',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TrendTahminiSayfasi(),
      ),
    );
  },
),
          MenuKarti(
  icon: Icons.local_offer,
  title: 'Fırsatlar',
  description: 'İndirim ve ilanları bul',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FirsatlarSayfasi(),
      ),
    );
  },
),
          MenuKarti(
  icon: Icons.smart_toy,
  title: 'Yapay Zekâ',
  description: 'Trendora AI ile konuş',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendoraAiSayfasi(),
      ),
    );
  },
),
          MenuKarti(
            icon: Icons.workspace_premium,
            title: 'Premium',
            description: 'Tüm özellikleri aç',
          ),
          MenuKarti(
  icon: Icons.settings,
  title: 'Ayarlar',
  description: 'Uygulamayı kişiselleştir',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AyarlarSayfasi(),
      ),
    );
  },
),
        ],
      ),
    );
  }
}

class MenuKarti extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
final VoidCallback? onTap;
  const MenuKarti({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
  onTap: onTap,
  child: Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.amber,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
   ), // Card
); // InkWell
  }
}