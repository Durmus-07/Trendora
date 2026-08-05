import 'package:flutter/material.dart';

const String trendoraBrandAsset =
    'assets/branding/trendora_brand_v1.png';

class TrendoraSplashIcerigi extends StatelessWidget {
  const TrendoraSplashIcerigi({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B132B),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(
                image: AssetImage(trendoraBrandAsset),
                width: 260,
                height: 230,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 8),
              Text(
                'Trendora',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSayfasi extends StatefulWidget {
  const OnboardingSayfasi({
    required this.onCompleted,
    super.key,
  });

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingSayfasi> createState() => _OnboardingSayfasiState();
}

class _OnboardingSayfasiState extends State<OnboardingSayfasi> {
  final PageController _controller = PageController();
  int _aktifSayfa = 0;
  bool _kaydediliyor = false;

  static const _sayfalar = <_OnboardingVerisi>[
    _OnboardingVerisi(
      baslik: 'Trendora’ya Hoş Geldin',
      aciklama:
          'Finans, haber, fırsat ve trendleri tek uygulamada keşfet.',
    ),
    _OnboardingVerisi(
      baslik: 'Akıllı Analiz Motoru',
      aciklama:
          'Dünyayı tarar, verileri karşılaştırır, önemli gelişmeleri '
          'belirler ve sana anlamlı sonuçlar sunar.',
      premiumBilgisi:
          'Premium üyeler, Trendora AI ile analizleri yapay zekâ '
          'desteğiyle daha detaylı inceleyebilir.',
    ),
    _OnboardingVerisi(
      baslik: 'Sana Özel Deneyim',
      aciklama:
          'İlgi alanlarını öğrenir; sana özel haberleri, fırsatları, '
          'analizleri ve önemli gelişmeleri önceliklendirir.',
    ),
    _OnboardingVerisi(
      baslik: 'Hazırsan Başlayalım',
      aciklama: 'Trendora seni bekliyor.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ilerle() async {
    if (_aktifSayfa < _sayfalar.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_kaydediliyor) return;
    setState(() => _kaydediliyor = true);
    try {
      await widget.onCompleted();
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _sayfalar.length,
                  onPageChanged: (index) {
                    setState(() => _aktifSayfa = index);
                  },
                  itemBuilder: (context, index) => _OnboardingIcerigi(
                    veri: _sayfalar[index],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _sayfalar.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _aktifSayfa ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _aktifSayfa
                          ? const Color(0xFF00E0FF)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _kaydediliyor ? null : _ilerle,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0077FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _aktifSayfa == _sayfalar.length - 1
                        ? 'Trendora’yı Keşfet'
                        : 'İleri',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingIcerigi extends StatelessWidget {
  const _OnboardingIcerigi({required this.veri});

  final _OnboardingVerisi veri;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage(trendoraBrandAsset),
                width: 270,
                height: 230,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                veri.baslik,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                veri.aciklama,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC7D2E8),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              if (veri.premiumBilgisi != null) ...[
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFD166),
                    border: Border.all(color: const Color(0x66FFD166)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD166),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          veri.premiumBilgisi!,
                          style: const TextStyle(
                            color: Color(0xFFE9EDF6),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingVerisi {
  const _OnboardingVerisi({
    required this.baslik,
    required this.aciklama,
    this.premiumBilgisi,
  });

  final String baslik;
  final String aciklama;
  final String? premiumBilgisi;
}
