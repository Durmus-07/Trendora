import 'package:flutter/material.dart';
import 'package:trendora_app/premium_sayfasi.dart';
import 'ayarlar_sayfasi.dart';
import 'dunya_tarama_sayfasi.dart';
import 'firsatlar_sayfasi.dart';
import 'haberler_sayfasi.dart';
import 'theme/trendora_theme.dart';
import 'trend_tahmini_sayfasi.dart';

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
      theme: TrendoraTheme.dark,
      home: const AcilisSayfasi(),
    );
  }
}

class AcilisSayfasi extends StatelessWidget {
  const AcilisSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PremiumArkaPlan()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _MarkaRozeti(),
                  ),
                  const Spacer(),
                  const _AcilisHero(),
                  const Spacer(),
                  _CanliDurumSatiri(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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
                      icon: const Icon(Icons.radar_rounded),
                      label: const Text('DÜNYAYI TARAMAYA BAŞLA'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Haberler, fırsatlar ve yükselen eğilimler tek merkezde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TrendoraColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  void _sayfayaGit(BuildContext context, Widget sayfa) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => sayfa,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<double> fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0.035, 0.025),
            end: Offset.zero,
          ).animate(fade);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size ekran = MediaQuery.sizeOf(context);
    final bool darEkran = ekran.width < 370;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: _PremiumArkaPlan(sade: true),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AnaMenuArkaPlanPainter(),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    10,
                    darEkran ? 15 : 19,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _PremiumUstBar(
                      onAyarlar: () {
                        _sayfayaGit(
                          context,
                          const AyarlarSayfasi(),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    10,
                    darEkran ? 15 : 19,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _AnaMenuHero(),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    18,
                    darEkran ? 15 : 19,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _BolumBasligi(
                      baslik: 'KEŞFET',
                      aciklama: 'Trendora merkezlerinden birini seç',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    11,
                    darEkran ? 15 : 19,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _PremiumAnaKart(
                      etiket: 'TRENDORA ANALİZ MOTORU',
                      baslik: 'Trend Analiz Merkezi',
                      aciklama:
                          'Yükselen eğilimleri, teknik göstergeleri ve kaynak destekli analizleri tek merkezde incele.',
                      icon: Icons.auto_graph_rounded,
                      accent: TrendoraColors.primary,
                      ikincilRenk: TrendoraColors.secondary,
                      bilgi: 'Canlı analiz',
                      onTap: () {
                        _sayfayaGit(
                          context,
                          const TrendTahminiSayfasi(),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    12,
                    darEkran ? 15 : 19,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: _PremiumKucukKart(
                            baslik: 'Haber\nMerkezi',
                            aciklama: 'Gündemi anlık takip et',
                            icon: Icons.newspaper_rounded,
                            accent: TrendoraColors.secondary,
                            onTap: () {
                              _sayfayaGit(
                                context,
                                const HaberlerSayfasi(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumKucukKart(
                            baslik: 'Fırsatlar\nMerkezi',
                            aciklama: 'İndirimleri keşfet',
                            icon: Icons.local_offer_rounded,
                            accent: TrendoraColors.success,
                            onTap: () {
                              _sayfayaGit(
                                context,
                                const FirsatlarSayfasi(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    18,
                    darEkran ? 15 : 19,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _BolumBasligi(
                      baslik: 'TRENDORA',
                      aciklama: 'Hesap ve uygulama seçenekleri',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    darEkran ? 15 : 19,
                    11,
                    darEkran ? 15 : 19,
                    28,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _PremiumYatayKart(
  baslik: 'Premium',
  aciklama: 'Gelişmiş özellikler yakında',
  icon: Icons.workspace_premium_rounded,
  accent: TrendoraColors.accent,
  kilitli: true,
  onTap: () {
    _sayfayaGit(
      context,
      const PremiumSayfasi(),
    );
  },
),
                        const SizedBox(height: 10),
                        _PremiumYatayKart(
                          baslik: 'Ayarlar',
                          aciklama: 'Uygulama tercihlerini yönet',
                          icon: Icons.tune_rounded,
                          accent: const Color(0xFF91A4C2),
                          onTap: () {
                            _sayfayaGit(
                              context,
                              const AyarlarSayfasi(),
                            );
                          },
                        ),
                      ],
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

class _PremiumUstBar extends StatelessWidget {
  final VoidCallback onAyarlar;

  const _PremiumUstBar({
    required this.onAyarlar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TrendoraColors.primary,
                TrendoraColors.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: TrendoraColors.primary.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.radar_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRENDORA',
                style: TextStyle(
                  color: TrendoraColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Akıllı trend platformu',
                style: TextStyle(
                  color: TrendoraColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAyarlar,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: TrendoraColors.textSecondary,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnaMenuHero extends StatelessWidget {
  const _AnaMenuHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 17, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172B49),
            Color(0xFF101D32),
            Color(0xFF0B1628),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF264465),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x34000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TrendoraColors.primary.withValues(alpha: 0.20),
                    TrendoraColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1729),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: TrendoraColors.primary.withValues(alpha: 0.34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TrendoraColors.primary.withValues(alpha: 0.16),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: TrendoraColors.secondary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CanliNokta(),
                        SizedBox(width: 8),
                        Text(
                          'SİSTEM AKTİF',
                          style: TextStyle(
                            color: TrendoraColors.success,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Trendora motoru hazır',
                      style: TextStyle(
                        color: TrendoraColors.textPrimary,
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Haberler, fırsatlar ve analiz merkezleri kullanıma hazır.',
                      style: TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 12.3,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CanliNokta extends StatelessWidget {
  const _CanliNokta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: TrendoraColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TrendoraColors.success,
            blurRadius: 9,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _BolumBasligi extends StatelessWidget {
  final String baslik;
  final String aciklama;

  const _BolumBasligi({
    required this.baslik,
    required this.aciklama,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  color: TrendoraColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                aciklama,
                style: const TextStyle(
                  color: TrendoraColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 31,
          height: 1,
          color: TrendoraColors.primary.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _PremiumAnaKart extends StatelessWidget {
  final String etiket;
  final String baslik;
  final String aciklama;
  final String bilgi;
  final IconData icon;
  final Color accent;
  final Color ikincilRenk;
  final VoidCallback onTap;

  const _PremiumAnaKart({
    required this.etiket,
    required this.baslik,
    required this.aciklama,
    required this.bilgi,
    required this.icon,
    required this.accent,
    required this.ikincilRenk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF182D4B),
                Color(0xFF0E1C31),
              ],
            ),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: accent.withValues(alpha: 0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -16,
                child: Icon(
                  icon,
                  color: accent.withValues(alpha: 0.075),
                  size: 118,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent,
                              ikincilRenk,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.27),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _CanliNokta(),
                            const SizedBox(width: 7),
                            Text(
                              bilgi,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    etiket,
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    baslik,
                    style: const TextStyle(
                      color: TrendoraColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(right: 38),
                    child: Text(
                      aciklama,
                      style: const TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'ANALİZİ AÇ',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumKucukKart extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _PremiumKucukKart({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF152843),
                  Color(0xFF0D192C),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 22,
                  offset: Offset(0, 11),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: accent.withValues(alpha: 0.85),
                      size: 19,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  baslik,
                  style: const TextStyle(
                    color: TrendoraColors.textPrimary,
                    fontSize: 16,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  aciklama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TrendoraColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
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

class _PremiumYatayKart extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool kilitli;

  const _PremiumYatayKart({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.accent,
    this.onTap,
    this.kilitli = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: const Color(0xC40E1A2D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        color: TrendoraColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      aciklama,
                      style: const TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (kilitli)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'YAKINDA',
                    style: TextStyle(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TrendoraColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnaMenuArkaPlanPainter extends CustomPainter {
  const _AnaMenuArkaPlanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint cizgi = Paint()
      ..color = TrendoraColors.secondary.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;

    const double aralik = 38;

    for (double x = -size.height; x < size.width; x += aralik) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        cizgi,
      );
    }

    final Paint nokta = Paint()
      ..color = TrendoraColors.primary.withValues(alpha: 0.08);

    for (double y = 90; y < size.height; y += 120) {
      for (double x = 28; x < size.width; x += 105) {
        canvas.drawCircle(
          Offset(x, y),
          1.2,
          nokta,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnaMenuArkaPlanPainter oldDelegate) => false;
}

class _AcilisHero extends StatelessWidget {
  const _AcilisHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                TrendoraColors.primary,
                TrendoraColors.secondary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: TrendoraColors.primary.withValues(alpha: 0.34),
                blurRadius: 42,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.radar_rounded,
            color: Colors.white,
            size: 54,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'TRENDORA',
          style: TextStyle(
            color: TrendoraColors.textPrimary,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 5.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Dünyadaki fırsatları, haberleri ve yükselen eğilimleri tek bakışta keşfet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 16,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}


class _MarkaRozeti extends StatelessWidget {
  const _MarkaRozeti();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: TrendoraColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: TrendoraColors.accent,
            size: 16,
          ),
          SizedBox(width: 7),
          Text(
            'AKILLI TREND PLATFORMU',
            style: TextStyle(
              color: TrendoraColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _CanliDurumSatiri() {
  return const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _DurumNoktasi(metin: 'Haberler'),
      SizedBox(width: 16),
      _DurumNoktasi(metin: 'Fırsatlar'),
      SizedBox(width: 16),
      _DurumNoktasi(metin: 'Trendler'),
    ],
  );
}

class _DurumNoktasi extends StatelessWidget {
  final String metin;

  const _DurumNoktasi({required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: TrendoraColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          metin,
          style: const TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PremiumArkaPlan extends StatelessWidget {
  final bool sade;

  const _PremiumArkaPlan({this.sade = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07101F),
            Color(0xFF0A1426),
            Color(0xFF07101F),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: sade ? -120 : -70,
            right: -100,
            child: _IsikHalesi(
              boyut: sade ? 260 : 330,
              renk: TrendoraColors.primary,
            ),
          ),
          Positioned(
            bottom: sade ? -150 : -90,
            left: -120,
            child: _IsikHalesi(
              boyut: sade ? 280 : 360,
              renk: TrendoraColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IsikHalesi extends StatelessWidget {
  final double boyut;
  final Color renk;

  const _IsikHalesi({required this.boyut, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            renk.withValues(alpha: 0.16),
            renk.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _MenuOgesi {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback? onTap;

  const _MenuOgesi({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    this.onTap,
  });
}
