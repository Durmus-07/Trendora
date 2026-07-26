import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class PremiumSayfasi extends StatefulWidget {
  const PremiumSayfasi({super.key});

  @override
  State<PremiumSayfasi> createState() => _PremiumSayfasiState();
}

class _PremiumSayfasiState extends State<PremiumSayfasi>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _parlamaController;
  late final AnimationController _arkaPlanController;
  late final Animation<double> _parlamaAnimasyonu;

  Timer? _kaydirmaTimer;
  bool _kullaniciDokunuyor = false;

  @override
  void initState() {
    super.initState();

    _parlamaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _arkaPlanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _parlamaAnimasyonu = Tween<double>(
      begin: 0.35,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _parlamaController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otomatikKaydirmayiBaslat();
    });
  }

  void _otomatikKaydirmayiBaslat() {
    _kaydirmaTimer?.cancel();

    _kaydirmaTimer = Timer.periodic(
  const Duration(milliseconds: 16),
  (_) {
        if (!mounted ||
            !_scrollController.hasClients ||
            _kullaniciDokunuyor) {
          return;
        }

        final maksimum = _scrollController.position.maxScrollExtent;
        final mevcut = _scrollController.offset;

        if (maksimum <= 0) return;

        if (mevcut >= maksimum - 8) {
          Future.delayed(const Duration(seconds: 3), () {
            if (!mounted || !_scrollController.hasClients) return;

            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOutCubic,
            );
          });
          return;
        }

        _scrollController.jumpTo(
          (mevcut + 0.75).clamp(0, maksimum),
        );
      },
    );
  }

  @override
  void dispose() {
    _kaydirmaTimer?.cancel();
    _scrollController.dispose();
    _parlamaController.dispose();
    _arkaPlanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final koyuTema = tema.brightness == Brightness.dark;

    final arkaPlan = koyuTema
        ? const Color(0xFF07111F)
        : const Color(0xFFF4F7FB);

    final kartRengi = koyuTema
        ? const Color(0xFF101D2F).withOpacity(0.92)
        : Colors.white.withOpacity(0.94);

    final anaYazi = koyuTema
        ? const Color(0xFFF4F7FC)
        : const Color(0xFF152238);

    final ikincilYazi = koyuTema
        ? const Color(0xFFB8C4D6)
        : const Color(0xFF5D6879);

    return Scaffold(
      backgroundColor: arkaPlan,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _arkaPlanController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _PremiumArkaPlanPainter(
                    ilerleme: _arkaPlanController.value,
                    koyuTema: koyuTema,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _UstBaslik(
                  koyuTema: koyuTema,
                  onGeri: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14,
                          sigmaY: 14,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kartRengi,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: koyuTema
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  koyuTema ? 0.32 : 0.08,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _PremiumRozeti(
                                koyuTema: koyuTema,
                                parlama: _parlamaAnimasyonu,
                              ),
                              Expanded(
                                child: Listener(
                                  onPointerDown: (_) {
                                    _kullaniciDokunuyor = true;
                                  },
                                  onPointerUp: (_) {
                                    _kullaniciDokunuyor = false;
                                  },
                                  onPointerCancel: (_) {
                                    _kullaniciDokunuyor = false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      10,
                                      22,
                                      36,
                                    ),
                                    child: _PremiumMetni(
                                      anaYazi: anaYazi,
                                      ikincilYazi: ikincilYazi,
                                      koyuTema: koyuTema,
                                      parlama: _parlamaAnimasyonu,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UstBaslik extends StatelessWidget {
  final bool koyuTema;
  final VoidCallback onGeri;

  const _UstBaslik({
    required this.koyuTema,
    required this.onGeri,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onGeri,
            style: IconButton.styleFrom(
              backgroundColor: koyuTema
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.85),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: koyuTema ? Colors.white : const Color(0xFF172237),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trendora Premium',
              style: TextStyle(
                color: koyuTema
                    ? Colors.white
                    : const Color(0xFF172237),
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Icon(
            Icons.workspace_premium_rounded,
            color: koyuTema
                ? const Color(0xFFFFD36A)
                : const Color(0xFFE19B18),
          ),
        ],
      ),
    );
  }
}

class _PremiumRozeti extends StatelessWidget {
  final bool koyuTema;
  final Animation<double> parlama;

  const _PremiumRozeti({
    required this.koyuTema,
    required this.parlama,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
      child: AnimatedBuilder(
        animation: parlama,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFC44D).withOpacity(
                    0.82 + (parlama.value * 0.12),
                  ),
                  const Color(0xFFFF8F3D).withOpacity(
                    0.78 + (parlama.value * 0.12),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA63D).withOpacity(
                    0.16 + (parlama.value * 0.22),
                  ),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'ÇOK YAKINDA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumMetni extends StatelessWidget {
  final Color anaYazi;
  final Color ikincilYazi;
  final bool koyuTema;
  final Animation<double> parlama;

  const _PremiumMetni({
    required this.anaYazi,
    required this.ikincilYazi,
    required this.koyuTema,
    required this.parlama,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Baslik(
          'Dünyadaki veriyi değil,\nanlamını gör.',
          renk: anaYazi,
        ),
        const SizedBox(height: 20),
        _Paragraf(
          'Her gün milyonlarca haber, fiyat değişimi, kampanya, piyasa hareketi ve yeni eğilim ortaya çıkıyor.',
          renk: ikincilYazi,
        ),
        _Paragraf(
          'Sorun bilgiye ulaşamamak değil. Asıl sorun, önemli olanı zamanında fark edememek.',
          renk: anaYazi,
          kalin: true,
        ),
        const SizedBox(height: 10),
        _VurguKarti(
          ikon: Icons.public_rounded,
          baslik: 'Trendora dünyayı senin için tarar',
          aciklama:
              'Dağınık verileri bir araya getirir, karşılaştırır, filtreler ve karar vermeni kolaylaştıran anlaşılır sonuçlara dönüştürür.',
          koyuTema: koyuTema,
        ),
        _VurguKarti(
          ikon: Icons.query_stats_rounded,
          baslik: 'Sadece ne olduğunu değil, neden olduğunu gösterir',
          aciklama:
              'Bir fırsat gerçekten avantajlı mı, bir trend neden yükseliyor, hangi gelişme daha fazla önem taşıyor? Trendora cevabı görünür hale getirir.',
          koyuTema: koyuTema,
        ),
        _VurguKarti(
          ikon: Icons.schedule_rounded,
          baslik: 'Saatlerce araştırmak yerine sonucu gör',
          aciklama:
              'Onlarca kaynak arasında kaybolmadan, ihtiyacın olan bilgiyi daha hızlı ve daha düzenli biçimde takip et.',
          koyuTema: koyuTema,
        ),
        const SizedBox(height: 20),
        _Baslik(
          'Premium neyi değiştirecek?',
          renk: anaYazi,
          boyut: 25,
        ),
        const SizedBox(height: 14),
        _OzellikSatiri(
          ikon: Icons.bolt_rounded,
          metin: 'Daha erken fırsat ve gelişme bildirimleri',
          renk: anaYazi,
        ),
        _OzellikSatiri(
          ikon: Icons.analytics_rounded,
          metin: 'Daha gelişmiş trend ve piyasa analizleri',
          renk: anaYazi,
        ),
        _OzellikSatiri(
          ikon: Icons.candlestick_chart_rounded,
          metin: 'Profesyonel grafikler ve teknik göstergeler',
          renk: anaYazi,
        ),
        _OzellikSatiri(
          ikon: Icons.travel_explore_rounded,
          metin: 'Daha geniş veri kaynağı ve derin tarama',
          renk: anaYazi,
        ),
        _OzellikSatiri(
          ikon: Icons.tune_rounded,
          metin: 'Gelişmiş filtreler ve kişiselleştirilmiş takip',
          renk: anaYazi,
        ),
        _OzellikSatiri(
          ikon: Icons.new_releases_rounded,
          metin: 'Yeni özelliklere öncelikli erişim',
          renk: anaYazi,
        ),
        const SizedBox(height: 28),
        _AlintiKarti(
          koyuTema: koyuTema,
          metin:
              'Doğru bilgi değerlidir.\nDoğru zamanda gelen bilgi ise fark yaratır.',
        ),
        const SizedBox(height: 28),
        _Baslik(
          'Neden Premium kullanmalıyım?',
          renk: anaYazi,
          boyut: 27,
        ),
        const SizedBox(height: 16),
        _Paragraf(
          'Çünkü zaman geri gelmez.',
          renk: anaYazi,
          kalin: true,
          ortali: true,
        ),
        _Paragraf(
          'Kaçırılan fırsatlar her zaman yeniden karşıya çıkmaz.',
          renk: ikincilYazi,
          ortali: true,
        ),
        _Paragraf(
          'Ve çoğu zaman iyi bir kararın değeri, o kararı vermek için kullandığın araçtan çok daha büyüktür.',
          renk: ikincilYazi,
          ortali: true,
        ),
        const SizedBox(height: 14),
        _Paragraf(
          'Trendora Premium; daha az araman, daha hızlı fark etmen ve daha güçlü kararlar vermen için geliştiriliyor.',
          renk: anaYazi,
          kalin: true,
          ortali: true,
        ),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: parlama,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 22,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7A5CFF).withOpacity(
                      0.76 + parlama.value * 0.14,
                    ),
                    const Color(0xFF2778FF).withOpacity(
                      0.76 + parlama.value * 0.14,
                    ),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C67FF).withOpacity(
                      0.14 + parlama.value * 0.18,
                    ),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'TRENDORA PREMIUM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Geleceği tahmin etmek için değil,\ndeğişimi herkesten önce fark etmek için.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'ÇOK YAKINDA',
                    style: TextStyle(
                      color: Color(0xFFFFE29A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Trendora • Veriyi gör. Anlamı yakala.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ikincilYazi,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  final Color renk;
  final double boyut;

  const _Baslik(
    this.metin, {
    required this.renk,
    this.boyut = 29,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: renk,
        fontSize: boyut,
        height: 1.18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
      ),
    );
  }
}

class _Paragraf extends StatelessWidget {
  final String metin;
  final Color renk;
  final bool kalin;
  final bool ortali;

  const _Paragraf(
    this.metin, {
    required this.renk,
    this.kalin = false,
    this.ortali = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        metin,
        textAlign: ortali ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: renk,
          fontSize: 16.3,
          height: 1.62,
          fontWeight: kalin ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _VurguKarti extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String aciklama;
  final bool koyuTema;

  const _VurguKarti({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.koyuTema,
  });

  @override
  Widget build(BuildContext context) {
    final anaYazi =
        koyuTema ? Colors.white : const Color(0xFF172237);
    final ikincil =
        koyuTema ? const Color(0xFFB8C4D6) : const Color(0xFF667184);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: koyuTema
            ? Colors.white.withOpacity(0.055)
            : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: koyuTema
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF5C67FF).withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF6670FF),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: anaYazi,
                    fontSize: 16.2,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  aciklama,
                  style: TextStyle(
                    color: ikincil,
                    fontSize: 14.3,
                    height: 1.52,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OzellikSatiri extends StatelessWidget {
  final IconData ikon;
  final String metin;
  final Color renk;

  const _OzellikSatiri({
    required this.ikon,
    required this.metin,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFC44D),
                  Color(0xFFFF9343),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ikon,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(
                color: renk,
                fontSize: 15.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlintiKarti extends StatelessWidget {
  final bool koyuTema;
  final String metin;

  const _AlintiKarti({
    required this.koyuTema,
    required this.metin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: koyuTema
            ? const Color(0xFF16243A)
            : const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF6172FF).withOpacity(0.16),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.format_quote_rounded,
            color: Color(0xFF6670FF),
            size: 35,
          ),
          const SizedBox(height: 8),
          Text(
            metin,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: koyuTema
                  ? Colors.white
                  : const Color(0xFF22304A),
              fontSize: 18.5,
              height: 1.48,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumArkaPlanPainter extends CustomPainter {
  final double ilerleme;
  final bool koyuTema;

  _PremiumArkaPlanPainter({
    required this.ilerleme,
    required this.koyuTema,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final zemin = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: koyuTema
            ? const [
                Color(0xFF06101C),
                Color(0xFF0A1730),
                Color(0xFF171235),
              ]
            : const [
                Color(0xFFF4F7FB),
                Color(0xFFEAF0FF),
                Color(0xFFF8F2FF),
              ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      zemin,
    );

    final noktalar = Paint()
      ..color = (koyuTema ? Colors.white : const Color(0xFF52628A))
          .withOpacity(koyuTema ? 0.08 : 0.05)
      ..strokeWidth = 1.2;

    const aralik = 34.0;
    final kayma = ilerleme * aralik;

    for (double x = -aralik; x < size.width + aralik; x += aralik) {
      for (double y = -aralik; y < size.height + aralik; y += aralik) {
        canvas.drawCircle(
          Offset(x + kayma, y + kayma),
          1.15,
          noktalar,
        );
      }
    }

    final halka = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF6975FF).withOpacity(
        koyuTema ? 0.12 : 0.08,
      );

    final merkez = Offset(
      size.width * 0.80,
      size.height * 0.22,
    );

    for (int i = 0; i < 4; i++) {
      final yaricap =
          65 + (i * 42) + ((ilerleme * 26) % 26);
      canvas.drawCircle(merkez, yaricap, halka);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumArkaPlanPainter oldDelegate) {
    return oldDelegate.ilerleme != ilerleme ||
        oldDelegate.koyuTema != koyuTema;
  }
}
