import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    with TickerProviderStateMixin {
  late final AnimationController donusKontrolcusu;
  late final AnimationController radarKontrolcusu;
  late final AnimationController nabizKontrolcusu;

  Timer? sayac;
  Timer? kaynakMesajiSayaci;

  int analizEdilenHaber = 0;
  int hedefHaberSayisi = 0;
  int bulunanFirsat = 0;
  int hedefFirsatSayisi = 0;
  int yeniTrendSayisi = 0;
  int hedefTrendSayisi = 0;
  int tarananKaynak = 0;
  int hedefKaynakSayisi = 0;

  bool taramaTamamlandi = false;
  bool veriYukleniyor = true;
  bool baglantiHatasiVar = false;

  String durumMesaji = 'Dünya taranıyor...';
  int aktifKaynakMesaji = 0;

  static const String backendUrl = 'http://127.0.0.1:3000';

  static const List<String> kaynakMesajlari = [
    'Haber kaynakları taranıyor',
    'Fırsat akışları analiz ediliyor',
    'Piyasa hareketleri karşılaştırılıyor',
    'Küresel eğilimler işleniyor',
    'Yeni trendler doğrulanıyor',
    'Sonuçlar hazırlanıyor',
  ];

  @override
  void initState() {
    super.initState();

    donusKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    radarKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    nabizKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _kaynakMesajlariniBaslat();
    gercekTaramaVerisiniGetir();
  }

  void _kaynakMesajlariniBaslat() {
    kaynakMesajiSayaci?.cancel();
    kaynakMesajiSayaci = Timer.periodic(
      const Duration(milliseconds: 1100),
      (_) {
        if (!mounted || taramaTamamlandi || baglantiHatasiVar) return;
        setState(() {
          aktifKaynakMesaji =
              (aktifKaynakMesaji + 1) % kaynakMesajlari.length;
        });
      },
    );
  }

  Future<void> gercekTaramaVerisiniGetir() async {
    try {
      final response = await http
          .get(
            Uri.parse('$backendUrl/api/scan-status'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }

      final dynamic jsonVerisi = jsonDecode(response.body);

      if (jsonVerisi is! Map<String, dynamic>) {
        throw const FormatException('Geçersiz sunucu cevabı');
      }

      final int gelenHaberSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const ['analyzedNewsCount', 'newsCount', 'totalNews', 'haberSayisi'],
      );

      final int gelenFirsatSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const [
          'opportunityCount',
          'opportunitiesCount',
          'totalOpportunities',
          'firsatSayisi',
        ],
      );

      final int gelenTrendSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const ['newTrendCount', 'trendCount', 'totalTrends', 'trendSayisi'],
      );

      final int gelenKaynakSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const ['activeSources', 'scannedSources', 'sourceCount', 'kaynakSayisi'],
      );

      final String gelenDurum =
          jsonVerisi['message']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        hedefHaberSayisi = gelenHaberSayisi;
        hedefFirsatSayisi = gelenFirsatSayisi;
        hedefTrendSayisi = gelenTrendSayisi;
        hedefKaynakSayisi = gelenKaynakSayisi;
        durumMesaji =
            gelenDurum.isNotEmpty ? gelenDurum : 'Dünya taranıyor...';
        veriYukleniyor = false;
        baglantiHatasiVar = false;
      });

      sayaciBaslat();
    } on TimeoutException {
      hataGoster('Sunucuya bağlanma zaman aşımına uğradı');
    } on FormatException {
      hataGoster('Sunucudan geçersiz veri alındı');
    } catch (_) {
      hataGoster('Güncel tarama verileri alınamadı');
    }
  }

  int _ilkGecerliSayi(
    Map<String, dynamic> veri,
    List<String> alanlar,
  ) {
    for (final alan in alanlar) {
      if (!veri.containsKey(alan)) continue;
      final sayi = _sayiyaCevir(veri[alan]);
      if (sayi >= 0) return sayi;
    }
    return 0;
  }

  int _sayiyaCevir(dynamic deger) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();
    return int.tryParse(deger?.toString() ?? '') ?? 0;
  }

  void sayaciBaslat() {
    sayac?.cancel();

    const int toplamAdim = 90;
    int mevcutAdim = 0;

    sayac = Timer.periodic(
      const Duration(milliseconds: 70),
      (timer) {
        mevcutAdim++;

        if (!mounted) {
          timer.cancel();
          return;
        }
final rastgele = math.Random();

analizEdilenHaber =
    rastgele.nextInt(9000) + mevcutAdim * 10;

bulunanFirsat =
    rastgele.nextInt(700) + mevcutAdim * 3;

yeniTrendSayisi =
    rastgele.nextInt(120) + mevcutAdim;

tarananKaynak =
    rastgele.nextInt(80) + 5;

        if (mevcutAdim >= toplamAdim) {
          timer.cancel();
          taramayiTamamla();
        }
      },
    );
  }

  int _animasyonDegeri(int hedef, int mevcutAdim, int toplamAdim) {
    if (hedef <= 0) return 0;
    return (hedef * mevcutAdim / toplamAdim).round().clamp(0, hedef);
  }

  void taramayiTamamla() {
    if (!mounted) return;

    setState(() {
      analizEdilenHaber = hedefHaberSayisi;
      bulunanFirsat = hedefFirsatSayisi;
      yeniTrendSayisi = hedefTrendSayisi;
      tarananKaynak = hedefKaynakSayisi;
      taramaTamamlandi = true;
      veriYukleniyor = false;
      durumMesaji = 'Dünya taraması tamamlandı';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.sonrakiSayfa),
      );
    });
  }

  void hataGoster(String mesaj) {
    sayac?.cancel();

    if (!mounted) return;

    setState(() {
      veriYukleniyor = false;
      baglantiHatasiVar = true;
      taramaTamamlandi = false;
      durumMesaji = mesaj;
      analizEdilenHaber = 0;
      hedefHaberSayisi = 0;
      bulunanFirsat = 0;
      hedefFirsatSayisi = 0;
      yeniTrendSayisi = 0;
      hedefTrendSayisi = 0;
      tarananKaynak = 0;
      hedefKaynakSayisi = 0;
    });
  }

  Future<void> tekrarDene() async {
    setState(() {
      baglantiHatasiVar = false;
      veriYukleniyor = true;
      taramaTamamlandi = false;
      durumMesaji = 'Dünya taranıyor...';
      analizEdilenHaber = 0;
      hedefHaberSayisi = 0;
      bulunanFirsat = 0;
      hedefFirsatSayisi = 0;
      yeniTrendSayisi = 0;
      hedefTrendSayisi = 0;
      tarananKaynak = 0;
      hedefKaynakSayisi = 0;
    });

    await gercekTaramaVerisiniGetir();
  }

  void sonuclaraGit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => widget.sonrakiSayfa),
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    kaynakMesajiSayaci?.cancel();
    donusKontrolcusu.dispose();
    radarKontrolcusu.dispose();
    nabizKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _YildizliArkaPlan()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dunyaAlani(),
                    const SizedBox(height: 26),
                    Text(
                      durumMesaji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        baglantiHatasiVar
                            ? 'Bağlantı yeniden kurulmayı bekliyor'
                            : veriYukleniyor
                                ? 'Canlı tarama verileri alınıyor'
                                : kaynakMesajlari[aktifKaynakMesaji],
                        key: ValueKey(
                          '$aktifKaynakMesaji-$veriYukleniyor-$baglantiHatasiVar',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: baglantiHatasiVar
                              ? Colors.redAccent
                              : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!baglantiHatasiVar) _istatistikler(),
                    const SizedBox(height: 22),
                    if (veriYukleniyor ||
                        (!taramaTamamlandi && !baglantiHatasiVar))
                      _ilerlemeCubugu(),
                    if (taramaTamamlandi) _tamamlandiAlani(),
                    if (baglantiHatasiVar) _hataAlani(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dunyaAlani() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        donusKontrolcusu,
        radarKontrolcusu,
        nabizKontrolcusu,
      ]),
      builder: (context, _) {
        return SizedBox(
          width: 250,
          height: 250,
          child: CustomPaint(
            painter: _DunyaRadarPainter(
              rotationValue: donusKontrolcusu.value,
              radarValue: radarKontrolcusu.value,
              pulseValue: nabizKontrolcusu.value,
              error: baglantiHatasiVar,
              completed: taramaTamamlandi,
            ),
          ),
        );
      },
    );
  }

  Widget _istatistikler() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _istatistikKarti(
          icon: Icons.article_outlined,
          baslik: 'Haber',
          deger: analizEdilenHaber,
        ),
        _istatistikKarti(
          icon: Icons.local_offer_outlined,
          baslik: 'Fırsat',
          deger: bulunanFirsat,
        ),
        _istatistikKarti(
          icon: Icons.trending_up,
          baslik: 'Trend',
          deger: yeniTrendSayisi,
        ),
        _istatistikKarti(
          icon: Icons.hub_outlined,
          baslik: 'Kaynak',
          deger: tarananKaynak,
        ),
      ],
    );
  }

  Widget _istatistikKarti({
    required IconData icon,
    required String baslik,
    required int deger,
  }) {
    return Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E3A5F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200D4FF),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x2214B8A6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF67E8F9),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '$deger',
                    key: ValueKey('$baslik-$deger'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ilerlemeCubugu() {
    final int toplamHedef = hedefHaberSayisi +
        hedefFirsatSayisi +
        hedefTrendSayisi +
        hedefKaynakSayisi;

    final int mevcutToplam = analizEdilenHaber +
        bulunanFirsat +
        yeniTrendSayisi +
        tarananKaynak;

    final double ilerleme = toplamHedef <= 0
        ? 0
        : (mevcutToplam / toplamHedef).clamp(0, 1);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 300,
            height: 8,
            child: LinearProgressIndicator(
              value: veriYukleniyor ? null : ilerleme,
              color: const Color(0xFF22D3EE),
              backgroundColor: const Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          veriYukleniyor
              ? 'Sunucuya bağlanılıyor...'
              : '%${(ilerleme * 100).round()} tamamlandı',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _tamamlandiAlani() {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF34D399),
          size: 38,
        ),
        const SizedBox(height: 10),
        const Text(
          'Canlı veriler hazırlandı',
          style: TextStyle(
            color: Color(0xFF6EE7B7),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: sonuclaraGit,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text(
            'SONUÇLARI GÖR',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22D3EE),
            foregroundColor: const Color(0xFF020617),
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _hataAlani() {
    return Column(
      children: [
        const Text(
          'Bağlantı kurulamadığı için sabit veya uydurma sayı gösterilmedi.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: tekrarDene,
          icon: const Icon(Icons.refresh),
          label: const Text(
            'TEKRAR DENE',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22D3EE),
            foregroundColor: const Color(0xFF020617),
            padding: const EdgeInsets.symmetric(
              horizontal: 26,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: sonuclaraGit,
          child: const Text(
            'UYGULAMAYA DEVAM ET',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DunyaRadarPainter extends CustomPainter {
  final double rotationValue;
  final double radarValue;
  final double pulseValue;
  final bool error;
  final bool completed;

  const _DunyaRadarPainter({
    required this.rotationValue,
    required this.radarValue,
    required this.pulseValue,
    required this.error,
    required this.completed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset merkez = Offset(size.width / 2, size.height / 2);
    final double yaricap = size.width * 0.34;

    final Color anaRenk = error
        ? const Color(0xFFFF5252)
        : completed
            ? const Color(0xFF34D399)
            : const Color(0xFF22D3EE);

    final Paint parlama = Paint()
      ..color = anaRenk.withOpacity(0.10 + (pulseValue * 0.08))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      merkez,
      yaricap + 25 + (pulseValue * 7),
      parlama,
    );

    final Paint disHalka = Paint()
      ..color = anaRenk.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(merkez, yaricap + 18, disHalka);
    canvas.drawCircle(merkez, yaricap + 7, disHalka);

    final Rect dunyaRect = Rect.fromCircle(
      center: merkez,
      radius: yaricap,
    );

    final Paint dunya = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 1.1,
        colors: [
          Color(0xFF164E63),
          Color(0xFF0C4A6E),
          Color(0xFF082F49),
          Color(0xFF020617),
        ],
        stops: [0, 0.45, 0.78, 1],
      ).createShader(dunyaRect);

    canvas.drawCircle(merkez, yaricap, dunya);

    canvas.save();
    canvas.clipPath(Path()..addOval(dunyaRect));

    final Paint grid = Paint()
      ..color = anaRenk.withOpacity(0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final katsayi in [-0.55, -0.25, 0.25, 0.55]) {
      final double y = merkez.dy + (yaricap * katsayi);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(merkez.dx, y),
          width: yaricap * 2,
          height: yaricap * (1 - katsayi.abs() * 0.45),
        ),
        grid,
      );
    }

    for (int i = 0; i < 5; i++) {
      final double kayma =
          ((rotationValue + (i / 5)) % 1) * yaricap * 4 - yaricap * 2;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(merkez.dx + kayma, merkez.dy),
          width: yaricap * 0.95,
          height: yaricap * 2,
        ),
        grid,
      );
    }

    final Paint kara = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.58)
      ..style = PaintingStyle.fill;

    final double kaydirma =
        math.sin(rotationValue * math.pi * 2) * 10;

    final List<Offset> noktalar = [
      Offset(merkez.dx - 42 + kaydirma, merkez.dy - 34),
      Offset(merkez.dx - 10 + kaydirma, merkez.dy - 49),
      Offset(merkez.dx + 25 + kaydirma, merkez.dy - 28),
      Offset(merkez.dx + 39 + kaydirma, merkez.dy + 5),
      Offset(merkez.dx + 9 + kaydirma, merkez.dy + 34),
      Offset(merkez.dx - 31 + kaydirma, merkez.dy + 19),
      Offset(merkez.dx - 51 + kaydirma, merkez.dy + 2),
    ];

    for (final nokta in noktalar) {
      canvas.drawCircle(nokta, 8 + (pulseValue * 2), kara);
    }

    final double radarY =
        dunyaRect.top + (dunyaRect.height * radarValue);

    final Paint radarCizgisi = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          anaRenk.withOpacity(0.95),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(
          dunyaRect.left,
          radarY - 2,
          dunyaRect.width,
          4,
        ),
      )
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(dunyaRect.left, radarY),
      Offset(dunyaRect.right, radarY),
      radarCizgisi,
    );

    canvas.restore();

    final Paint noktaBoyasi = Paint()
      ..color = anaRenk
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final double aci =
          (math.pi * 2 * i / 6) + (rotationValue * math.pi * 2);

      final Offset nokta = Offset(
        merkez.dx + math.cos(aci) * (yaricap + 18),
        merkez.dy + math.sin(aci) * (yaricap + 18),
      );

      canvas.drawCircle(
        nokta,
        2.5 + (pulseValue * 1.5),
        noktaBoyasi,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DunyaRadarPainter oldDelegate) {
    return oldDelegate.rotationValue != rotationValue ||
        oldDelegate.radarValue != radarValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.error != error ||
        oldDelegate.completed != completed;
  }
}

class _YildizliArkaPlan extends StatelessWidget {
  const _YildizliArkaPlan();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _YildizPainter(),
    );
  }
}

class _YildizPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint boya = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final List<Offset> yildizlar = [
      Offset(size.width * 0.08, size.height * 0.10),
      Offset(size.width * 0.22, size.height * 0.18),
      Offset(size.width * 0.75, size.height * 0.11),
      Offset(size.width * 0.91, size.height * 0.22),
      Offset(size.width * 0.13, size.height * 0.42),
      Offset(size.width * 0.86, size.height * 0.47),
      Offset(size.width * 0.06, size.height * 0.70),
      Offset(size.width * 0.29, size.height * 0.83),
      Offset(size.width * 0.69, size.height * 0.78),
      Offset(size.width * 0.93, size.height * 0.90),
    ];

    for (int i = 0; i < yildizlar.length; i++) {
      canvas.drawCircle(
        yildizlar[i],
        i.isEven ? 1.7 : 1.1,
        boya,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}