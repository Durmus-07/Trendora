import 'dart:async';

import 'package:flutter/material.dart';

class DunyaTaramaSayfasi extends StatefulWidget {
  final Widget sonrakiSayfa;

  const DunyaTaramaSayfasi({
    super.key,
    required this.sonrakiSayfa,
  });

  @override
  State<DunyaTaramaSayfasi> createState() => _DunyaTaramaSayfasiState();
}

class _DunyaTaramaSayfasiState extends State<DunyaTaramaSayfasi>
    with SingleTickerProviderStateMixin {
  late AnimationController donusKontrolcusu;

  int analizEdilenHaber = 0;
  bool taramaTamamlandi = false;

  Timer? sayac;

  @override
  void initState() {
    super.initState();

    donusKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    taramayiBaslat();
  }

  void taramayiBaslat() {
    const hedefHaberSayisi = 18462;
    const toplamAdim = 50;

    sayac = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          analizEdilenHaber =
              (hedefHaberSayisi * timer.tick / toplamAdim).round();
        });

        if (timer.tick >= toplamAdim) {
  timer.cancel();
  donusKontrolcusu.stop();

  setState(() {
    analizEdilenHaber = hedefHaberSayisi;
    taramaTamamlandi = true;
  });

  Future.delayed(const Duration(seconds: 2), () {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.sonrakiSayfa,
      ),
    );
  });
}
      },
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    donusKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: donusKontrolcusu,
                  child: const Icon(
                    Icons.public,
                    size: 150,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 35),
                Text(
                  taramaTamamlandi
                      ? 'Dünya taraması tamamlandı'
                      : 'Dünya taranıyor...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$analizEdilenHaber haber analiz edildi',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 30),
                if (!taramaTamamlandi)
                  const SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      color: Colors.amber,
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  ),
                if (taramaTamamlandi) ...[
                  const Text(
                    '4 yeni trend tespit edildi',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 35,
                        vertical: 15,
                      ),
                    ),
                    child: const Text(
                      'SONUÇLARI GÖR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}