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
  static const String backendUrl =
      'https://trendora-icj9.onrender.com';

  late final AnimationController donusKontrolcusu;
  late final AnimationController radarKontrolcusu;
  late final AnimationController nabizKontrolcusu;
  late final AnimationController girisKontrolcusu;

  Timer? sayac;
  Timer? durumMesajiSayaci;
  Timer? logSayaci;
  Timer? otomatikGecisSayaci;

  DateTime? taramaBaslangici;
  DateTime? sonGuncellemeZamani;

  int analizEdilenHaber = 0;
  int hedefHaberSayisi = 0;

  int bulunanFirsat = 0;
  int hedefFirsatSayisi = 0;

  int yeniTrendSayisi = 0;
  int hedefTrendSayisi = 0;

  int tarananKaynak = 0;
  int hedefKaynakSayisi = 0;

  int aktifKaynakSayisi = 0;
  int basarisizKaynakSayisi = 0;

  double taramaSuresiSaniye = 0;

  bool taramaTamamlandi = false;
  bool veriYukleniyor = true;
  bool baglantiHatasiVar = false;
  bool sayfaDegistiriliyor = false;

  String durumMesaji = 'Dünya taranıyor...';
  String hataDetayi = '';
  int aktifDurumMesaji = 0;
  int aktifLogSirasi = 0;

  final List<_TaramaLogu> gorunenLoglar = [];

  _ModulDurumu haberModulu = const _ModulDurumu(
    baslik: 'Haber Merkezi',
    aciklama: 'Kaynaklar bekleniyor',
    icon: Icons.article_outlined,
    durum: _ModulDurumTuru.bekliyor,
    sayi: 0,
  );

  _ModulDurumu firsatModulu = const _ModulDurumu(
    baslik: 'Fırsatlar',
    aciklama: 'Akışlar bekleniyor',
    icon: Icons.local_offer_outlined,
    durum: _ModulDurumTuru.bekliyor,
    sayi: 0,
  );

  _ModulDurumu trendModulu = const _ModulDurumu(
    baslik: 'Trend Analizi',
    aciklama: 'Motor bekleniyor',
    icon: Icons.trending_up_rounded,
    durum: _ModulDurumTuru.bekliyor,
    sayi: 0,
  );

  static const List<String> durumMesajlari = [
    'Haber kaynakları taranıyor',
    'Fırsat akışları doğrulanıyor',
    'Piyasa hareketleri karşılaştırılıyor',
    'Küresel eğilimler işleniyor',
    'Kaynak güvenilirliği kontrol ediliyor',
    'Sonuçlar hazırlanıyor',
  ];

  static const List<String> logMesajlari = [
    'Canlı sunucu bağlantısı kuruluyor',
    'Haber önbelleği okunuyor',
    'Fırsat veritabanı kontrol ediliyor',
    'Trend motoru durumu alınıyor',
    'Aktif kaynaklar doğrulanıyor',
    'Veriler kullanıcı ekranına hazırlanıyor',
  ];

  @override
  void initState() {
    super.initState();

    taramaBaslangici = DateTime.now();

    donusKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    radarKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    nabizKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    girisKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _durumMesajlariniBaslat();
    _logAkisiniBaslat();
    gercekTaramaVerisiniGetir();
  }

  void _durumMesajlariniBaslat() {
    durumMesajiSayaci?.cancel();

    durumMesajiSayaci = Timer.periodic(
      const Duration(milliseconds: 1250),
      (_) {
        if (!mounted || taramaTamamlandi || baglantiHatasiVar) return;

        setState(() {
          aktifDurumMesaji =
              (aktifDurumMesaji + 1) % durumMesajlari.length;
        });
      },
    );
  }

  void _logAkisiniBaslat() {
    logSayaci?.cancel();
    gorunenLoglar.clear();

    _yeniLogEkle(logMesajlari.first);

    logSayaci = Timer.periodic(
      const Duration(milliseconds: 1050),
      (_) {
        if (!mounted || taramaTamamlandi || baglantiHatasiVar) return;

        aktifLogSirasi =
            (aktifLogSirasi + 1).clamp(0, logMesajlari.length - 1);

        _yeniLogEkle(logMesajlari[aktifLogSirasi]);

        if (aktifLogSirasi >= logMesajlari.length - 1) {
          aktifLogSirasi = 1;
        }
      },
    );
  }

  void _yeniLogEkle(String mesaj) {
    if (!mounted) return;

    setState(() {
      gorunenLoglar.add(
        _TaramaLogu(
          zaman: DateTime.now(),
          mesaj: mesaj,
        ),
      );

      if (gorunenLoglar.length > 4) {
        gorunenLoglar.removeAt(0);
      }
    });
  }

  Future<void> gercekTaramaVerisiniGetir() async {
    taramaBaslangici = DateTime.now();

    try {
      final response = await http
          .get(
            Uri.parse('$backendUrl/api/scan-status'),
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }

      final dynamic jsonVerisi = jsonDecode(response.body);

      if (jsonVerisi is! Map<String, dynamic>) {
        throw const FormatException('Geçersiz sunucu cevabı');
      }

      final int gelenHaberSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const [
          'analyzedNewsCount',
          'newsCount',
          'totalNews',
          'haberSayisi',
        ],
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
        const [
          'newTrendCount',
          'trendCount',
          'totalTrends',
          'trendSayisi',
        ],
      );

      final int gelenKaynakSayisi = _ilkGecerliSayi(
        jsonVerisi,
        const [
          'scannedSources',
          'sourceCount',
          'kaynakSayisi',
          'activeSources',
        ],
      );

      final int gelenAktifKaynak = _ilkGecerliSayi(
        jsonVerisi,
        const ['activeSources'],
      );

      final int gelenBasarisizKaynak = _ilkGecerliSayi(
        jsonVerisi,
        const ['failedSources'],
      );

      final String gelenDurum =
          jsonVerisi['message']?.toString().trim() ?? '';

      final Map<String, dynamic> moduller =
          _mapOlarakAl(jsonVerisi['modules']);

      final Map<String, dynamic> haberVerisi =
          _mapOlarakAl(moduller['news']);

      final Map<String, dynamic> firsatVerisi =
          _mapOlarakAl(moduller['opportunities']);

      final Map<String, dynamic> trendVerisi =
          _mapOlarakAl(moduller['trends']);

      final DateTime? guncellemeZamani = _enYeniTarih([
        jsonVerisi['updatedAt'],
        haberVerisi['updatedAt'],
        firsatVerisi['updatedAt'],
        trendVerisi['updatedAt'],
      ]);

      final double gelenSure =
          _doubleDeger(jsonVerisi['durationMs']) / 1000;

      if (!mounted) return;

      setState(() {
        hedefHaberSayisi = gelenHaberSayisi;
        hedefFirsatSayisi = gelenFirsatSayisi;
        hedefTrendSayisi = gelenTrendSayisi;
        hedefKaynakSayisi = gelenKaynakSayisi;

        aktifKaynakSayisi = gelenAktifKaynak;
        basarisizKaynakSayisi = gelenBasarisizKaynak;

        sonGuncellemeZamani = guncellemeZamani ?? DateTime.now();
        taramaSuresiSaniye = gelenSure > 0
            ? gelenSure
            : DateTime.now()
                    .difference(taramaBaslangici!)
                    .inMilliseconds /
                1000;

        durumMesaji = gelenDurum.isNotEmpty
            ? gelenDurum
            : 'Dünya taranıyor...';

        haberModulu = _modulDurumuOlustur(
          baslik: 'Haber Merkezi',
          aciklamaTamamlandi: 'Haber akışı hazır',
          aciklamaBekliyor: 'Haber verileri hazırlanıyor',
          icon: Icons.article_outlined,
          varsayilanSayi: gelenHaberSayisi,
          veri: haberVerisi,
        );

        firsatModulu = _modulDurumuOlustur(
          baslik: 'Fırsatlar',
          aciklamaTamamlandi: 'Fırsatlar doğrulandı',
          aciklamaBekliyor: 'Fırsat akışları hazırlanıyor',
          icon: Icons.local_offer_outlined,
          varsayilanSayi: gelenFirsatSayisi,
          veri: firsatVerisi,
        );

        trendModulu = _modulDurumuOlustur(
          baslik: 'Trend Analizi',
          aciklamaTamamlandi: 'Trend motoru hazır',
          aciklamaBekliyor: 'Trend motoru analiz yapıyor',
          icon: Icons.trending_up_rounded,
          varsayilanSayi: gelenTrendSayisi,
          veri: trendVerisi,
        );

        veriYukleniyor = false;
        baglantiHatasiVar = false;
        hataDetayi = '';
      });

      _yeniLogEkle('Canlı veriler başarıyla alındı');
      sayaciBaslat();
    } on TimeoutException {
      hataGoster(
        'Sunucuya bağlanma zaman aşımına uğradı',
        'Render sunucusu uyanıyor olabilir. Birkaç saniye sonra tekrar deneyin.',
      );
    } on FormatException {
      hataGoster(
        'Sunucudan geçersiz veri alındı',
        'Sunucu cevabı beklenen JSON biçiminde değildi.',
      );
    } catch (error) {
      hataGoster(
        'Güncel tarama verileri alınamadı',
        error.toString(),
      );
    }
  }

  _ModulDurumu _modulDurumuOlustur({
    required String baslik,
    required String aciklamaTamamlandi,
    required String aciklamaBekliyor,
    required IconData icon,
    required int varsayilanSayi,
    required Map<String, dynamic> veri,
  }) {
    final String durum =
        veri['status']?.toString().trim().toLowerCase() ?? '';

    final int sayi = _ilkGecerliSayi(
      veri,
      const ['count', 'total', 'trendCount', 'newsCount'],
      varsayilan: varsayilanSayi,
    );

    final _ModulDurumTuru durumTuru;

    switch (durum) {
      case 'completed':
      case 'ready':
      case 'active':
        durumTuru = _ModulDurumTuru.tamamlandi;
        break;
      case 'partial':
        durumTuru = _ModulDurumTuru.kismi;
        break;
      case 'failed':
      case 'error':
        durumTuru = _ModulDurumTuru.hata;
        break;
      default:
        durumTuru = _ModulDurumTuru.calisiyor;
    }

    return _ModulDurumu(
      baslik: baslik,
      aciklama: durumTuru == _ModulDurumTuru.tamamlandi
          ? aciklamaTamamlandi
          : aciklamaBekliyor,
      icon: icon,
      durum: durumTuru,
      sayi: sayi,
    );
  }

  Map<String, dynamic> _mapOlarakAl(dynamic deger) {
    if (deger is Map<String, dynamic>) return deger;

    if (deger is Map) {
      return deger.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }

  int _ilkGecerliSayi(
    Map<String, dynamic> veri,
    List<String> alanlar, {
    int varsayilan = 0,
  }) {
    for (final alan in alanlar) {
      if (!veri.containsKey(alan)) continue;

      final int? sayi = _nullableSayiyaCevir(veri[alan]);

      if (sayi != null && sayi >= 0) {
        return sayi;
      }
    }

    return varsayilan;
  }

  int? _nullableSayiyaCevir(dynamic deger) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();

    final String metin = deger?.toString().trim() ?? '';

    if (metin.isEmpty) return null;

    return int.tryParse(metin);
  }

  double _doubleDeger(dynamic deger) {
    if (deger is num) return deger.toDouble();
    return double.tryParse(deger?.toString() ?? '') ?? 0;
  }

  DateTime? _enYeniTarih(List<dynamic> degerler) {
    DateTime? enYeni;

    for (final deger in degerler) {
      final String metin = deger?.toString().trim() ?? '';

      if (metin.isEmpty) continue;

      final DateTime? tarih = DateTime.tryParse(metin)?.toLocal();

      if (tarih == null) continue;

      if (enYeni == null || tarih.isAfter(enYeni)) {
        enYeni = tarih;
      }
    }

    return enYeni;
  }

  void sayaciBaslat() {
    sayac?.cancel();

    const int toplamAdim = 100;
    int mevcutAdim = 0;

    sayac = Timer.periodic(
      const Duration(milliseconds: 48),
      (timer) {
        mevcutAdim++;

        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          analizEdilenHaber = _animasyonDegeri(
            hedefHaberSayisi,
            mevcutAdim,
            toplamAdim,
          );

          bulunanFirsat = _animasyonDegeri(
            hedefFirsatSayisi,
            mevcutAdim,
            toplamAdim,
          );

          yeniTrendSayisi = _animasyonDegeri(
            hedefTrendSayisi,
            mevcutAdim,
            toplamAdim,
          );

          tarananKaynak = _animasyonDegeri(
            hedefKaynakSayisi,
            mevcutAdim,
            toplamAdim,
          );
        });

        if (mevcutAdim == 35) {
          _yeniLogEkle('Haber kaynakları tamamlandı');
        }

        if (mevcutAdim == 60) {
          _yeniLogEkle('Trend analizi doğrulandı');
        }

        if (mevcutAdim == 80) {
          _yeniLogEkle('Fırsat akışları hazırlandı');
        }

        if (mevcutAdim >= toplamAdim) {
          timer.cancel();
          taramayiTamamla();
        }
      },
    );
  }

  int _animasyonDegeri(
    int hedef,
    int mevcutAdim,
    int toplamAdim,
  ) {
    if (hedef <= 0) return 0;

    final double oran = mevcutAdim / toplamAdim;
    final double yumusatilmisOran =
        Curves.easeOutCubic.transform(oran.clamp(0, 1));

    return (hedef * yumusatilmisOran)
        .round()
        .clamp(0, hedef);
  }

  void taramayiTamamla() {
    if (!mounted || taramaTamamlandi) return;

    logSayaci?.cancel();
    durumMesajiSayaci?.cancel();

    setState(() {
      analizEdilenHaber = hedefHaberSayisi;
      bulunanFirsat = hedefFirsatSayisi;
      yeniTrendSayisi = hedefTrendSayisi;
      tarananKaynak = hedefKaynakSayisi;

      taramaTamamlandi = true;
      veriYukleniyor = false;
      durumMesaji = 'Dünya taraması tamamlandı';

      haberModulu = haberModulu.tamamlandiKopyasi();
      firsatModulu = firsatModulu.tamamlandiKopyasi();
      trendModulu = trendModulu.tamamlandiKopyasi();
    });

    _yeniLogEkle('Tüm sonuçlar kullanıma hazır');

    otomatikGecisSayaci?.cancel();
    otomatikGecisSayaci = Timer(
      const Duration(seconds: 3),
      sonuclaraGit,
    );
  }

  void hataGoster(
    String mesaj,
    String detay,
  ) {
    sayac?.cancel();
    logSayaci?.cancel();

    if (!mounted) return;

    setState(() {
      veriYukleniyor = false;
      baglantiHatasiVar = true;
      taramaTamamlandi = false;
      durumMesaji = mesaj;
      hataDetayi = detay;

      analizEdilenHaber = 0;
      hedefHaberSayisi = 0;

      bulunanFirsat = 0;
      hedefFirsatSayisi = 0;

      yeniTrendSayisi = 0;
      hedefTrendSayisi = 0;

      tarananKaynak = 0;
      hedefKaynakSayisi = 0;

      aktifKaynakSayisi = 0;
      basarisizKaynakSayisi = 0;
    });
  }

  Future<void> tekrarDene() async {
    otomatikGecisSayaci?.cancel();

    setState(() {
      baglantiHatasiVar = false;
      veriYukleniyor = true;
      taramaTamamlandi = false;
      sayfaDegistiriliyor = false;
      durumMesaji = 'Dünya taranıyor...';
      hataDetayi = '';

      analizEdilenHaber = 0;
      hedefHaberSayisi = 0;

      bulunanFirsat = 0;
      hedefFirsatSayisi = 0;

      yeniTrendSayisi = 0;
      hedefTrendSayisi = 0;

      tarananKaynak = 0;
      hedefKaynakSayisi = 0;

      aktifKaynakSayisi = 0;
      basarisizKaynakSayisi = 0;

      haberModulu = const _ModulDurumu(
        baslik: 'Haber Merkezi',
        aciklama: 'Kaynaklar bekleniyor',
        icon: Icons.article_outlined,
        durum: _ModulDurumTuru.bekliyor,
        sayi: 0,
      );

      firsatModulu = const _ModulDurumu(
        baslik: 'Fırsatlar',
        aciklama: 'Akışlar bekleniyor',
        icon: Icons.local_offer_outlined,
        durum: _ModulDurumTuru.bekliyor,
        sayi: 0,
      );

      trendModulu = const _ModulDurumu(
        baslik: 'Trend Analizi',
        aciklama: 'Motor bekleniyor',
        icon: Icons.trending_up_rounded,
        durum: _ModulDurumTuru.bekliyor,
        sayi: 0,
      );
    });

    aktifLogSirasi = 0;
    _durumMesajlariniBaslat();
    _logAkisiniBaslat();

    await gercekTaramaVerisiniGetir();
  }

  void sonuclaraGit() {
    if (!mounted || sayfaDegistiriliyor) return;

    sayfaDegistiriliyor = true;
    otomatikGecisSayaci?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.sonrakiSayfa,
      ),
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    durumMesajiSayaci?.cancel();
    logSayaci?.cancel();
    otomatikGecisSayaci?.cancel();

    donusKontrolcusu.dispose();
    radarKontrolcusu.dispose();
    nabizKontrolcusu.dispose();
    girisKontrolcusu.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ekranGenisligi =
        MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: _YildizliArkaPlan(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: donusKontrolcusu,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _VeriAkisiPainter(
                        progress: donusKontrolcusu.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: girisKontrolcusu,
                curve: Curves.easeOut,
              ),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: ekranGenisligi < 380 ? 14 : 20,
                    vertical: 22,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 620,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ustBaslik(),
                        const SizedBox(height: 14),
                        _dunyaAlani(),
                        const SizedBox(height: 18),
                        _anaDurumAlani(),
                        const SizedBox(height: 20),
                        if (!baglantiHatasiVar) ...[
                          _istatistikler(),
                          const SizedBox(height: 14),
                          _modulKartlari(),
                          const SizedBox(height: 14),
                          _taramaBilgiKarti(),
                          const SizedBox(height: 14),
                          _canliLogPaneli(),
                          const SizedBox(height: 18),
                          _ilerlemeAlani(),
                        ],
                        if (taramaTamamlandi) ...[
                          const SizedBox(height: 16),
                          _tamamlandiAlani(),
                        ],
                        if (baglantiHatasiVar) ...[
                          const SizedBox(height: 18),
                          _hataAlani(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ustBaslik() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: baglantiHatasiVar
                ? const Color(0xFFFB7185)
                : taramaTamamlandi
                    ? const Color(0xFF34D399)
                    : const Color(0xFF22D3EE),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (
                  baglantiHatasiVar
                      ? const Color(0xFFFB7185)
                      : taramaTamamlandi
                          ? const Color(0xFF34D399)
                          : const Color(0xFF22D3EE)
                ).withOpacity(0.55),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          baglantiHatasiVar
              ? 'TRENDORA BAĞLANTI DURUMU'
              : 'TRENDORA GLOBAL SCAN',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }

  Widget _anaDurumAlani() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            durumMesaji,
            key: ValueKey(durumMesaji),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 9),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            baglantiHatasiVar
                ? 'Canlı veri bağlantısı yeniden kurulmayı bekliyor'
                : taramaTamamlandi
                    ? 'Veriler doğrulandı ve kullanıma hazırlandı'
                    : veriYukleniyor
                        ? 'Sunucudan canlı tarama verileri alınıyor'
                        : durumMesajlari[aktifDurumMesaji],
            key: ValueKey(
              '$aktifDurumMesaji-'
              '$veriYukleniyor-'
              '$baglantiHatasiVar-'
              '$taramaTamamlandi',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: baglantiHatasiVar
                  ? const Color(0xFFFDA4AF)
                  : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
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
          width: 238,
          height: 238,
          child: CustomPaint(
            painter: _DunyaRadarPainter(
              rotationValue: donusKontrolcusu.value,
              radarValue: radarKontrolcusu.value,
              pulseValue: nabizKontrolcusu.value,
              error: baglantiHatasiVar,
              completed: taramaTamamlandi,
              progress: _ilerlemeOrani,
            ),
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xB3020617),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _anaRenk.withOpacity(0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _anaRenk.withOpacity(0.16),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Center(
                  child: veriYukleniyor
                      ? SizedBox(
                          width: 27,
                          height: 27,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: _anaRenk,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '%${(_ilerlemeOrani * 100).round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              taramaTamamlandi
                                  ? 'HAZIR'
                                  : 'TARAMA',
                              style: TextStyle(
                                color: _anaRenk,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _istatistikler() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double kartGenisligi =
            (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _istatistikKarti(
              genislik: kartGenisligi,
              icon: Icons.article_outlined,
              baslik: 'Haber',
              deger: analizEdilenHaber,
              altMetin: 'Canlı içerik',
            ),
            _istatistikKarti(
              genislik: kartGenisligi,
              icon: Icons.local_offer_outlined,
              baslik: 'Fırsat',
              deger: bulunanFirsat,
              altMetin: 'Doğrulanan kayıt',
            ),
            _istatistikKarti(
              genislik: kartGenisligi,
              icon: Icons.trending_up_rounded,
              baslik: 'Trend',
              deger: yeniTrendSayisi,
              altMetin: 'Analiz sonucu',
            ),
            _istatistikKarti(
              genislik: kartGenisligi,
              icon: Icons.hub_outlined,
              baslik: 'Kaynak',
              deger: tarananKaynak,
              altMetin: hedefKaynakSayisi > 0
                  ? '$aktifKaynakSayisi aktif'
                  : 'Kaynak ağı',
            ),
          ],
        );
      },
    );
  }

  Widget _istatistikKarti({
    required double genislik,
    required IconData icon,
    required String baslik,
    required int deger,
    required String altMetin,
  }) {
    return Container(
      width: genislik,
      padding: const EdgeInsets.fromLTRB(13, 13, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xC90F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1E3A5F),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1800D4FF),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0x2214B8A6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF67E8F9),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    _sayiBicimlendir(deger),
                    key: ValueKey('$baslik-$deger'),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  altMetin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
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

  Widget _modulKartlari() {
    return Column(
      children: [
        _modulKarti(haberModulu),
        const SizedBox(height: 8),
        _modulKarti(firsatModulu),
        const SizedBox(height: 8),
        _modulKarti(trendModulu),
      ],
    );
  }

  Widget _modulKarti(_ModulDurumu modul) {
    final Color renk = modul.renk;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB80B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: renk.withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: renk.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              modul.icon,
              color: renk,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        modul.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (modul.sayi > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        _sayiBicimlendir(modul.sayi),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  modul.aciklama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: const Color(0x73FFFFFF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          _durumRozeti(modul),
        ],
      ),
    );
  }

  Widget _durumRozeti(_ModulDurumu modul) {
    final Color renk = modul.renk;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renk.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (modul.durum == _ModulDurumTuru.calisiyor)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: renk,
              ),
            )
          else
            Icon(
              modul.iconDurumu,
              color: renk,
              size: 13,
            ),
          const SizedBox(width: 5),
          Text(
            modul.durumMetni,
            style: TextStyle(
              color: renk,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taramaBilgiKarti() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xB80B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bilgiSatiri(
              icon: Icons.schedule_rounded,
              baslik: 'Son tarama',
              deger: _saatBicimlendir(
                sonGuncellemeZamani,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: Colors.white10,
          ),
          Expanded(
            child: _bilgiSatiri(
              icon: Icons.speed_rounded,
              baslik: 'Yanıt süresi',
              deger: taramaSuresiSaniye > 0
                  ? '${taramaSuresiSaniye.toStringAsFixed(2)} sn'
                  : 'Hesaplanıyor',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: Colors.white10,
          ),
          Expanded(
            child: _bilgiSatiri(
              icon: Icons.verified_outlined,
              baslik: 'Kaynak durumu',
              deger: basarisizKaynakSayisi > 0
                  ? '$aktifKaynakSayisi aktif'
                  : 'Kararlı',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bilgiSatiri({
    required IconData icon,
    required String baslik,
    required String deger,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF67E8F9),
          size: 17,
        ),
        const SizedBox(height: 5),
        Text(
          deger,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          baslik,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _canliLogPaneli() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xA308111F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF143148),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                color: Color(0xFF67E8F9),
                size: 16,
              ),
              SizedBox(width: 7),
              Text(
                'CANLI TARAMA AKIŞI',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ...gorunenLoglar.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _saatBicimlendir(log.zaman),
                    style: const TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.mesaj,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _ilerlemeAlani() {
    final int yuzde = (_ilerlemeOrani * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Text(
              veriYukleniyor
                  ? 'Sunucu bağlantısı'
                  : taramaTamamlandi
                      ? 'Tarama tamamlandı'
                      : 'Küresel tarama ilerlemesi',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              veriYukleniyor ? 'Bağlanıyor' : '%$yuzde',
              style: TextStyle(
                color: _anaRenk,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            width: double.infinity,
            height: 8,
            child: LinearProgressIndicator(
              value: veriYukleniyor ? null : _ilerlemeOrani,
              color: _anaRenk,
              backgroundColor: const Color(0xFF1E293B),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          veriYukleniyor
              ? 'Canlı sunucu uyandırılıyor ve önbellekler okunuyor'
              : hedefKaynakSayisi > 0
                  ? '$tarananKaynak / $hedefKaynakSayisi kaynak işlendi'
                  : 'Haber, fırsat ve trend verileri hazırlanıyor',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _tamamlandiAlani() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 450),
      scale: taramaTamamlandi ? 1 : 0.9,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: const Color(0x1634D399),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x4434D399),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34D399),
                  size: 21,
                ),
                SizedBox(width: 8),
                Text(
                  'Canlı veriler hazırlandı',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sonuclaraGit,
              icon: const Icon(
                Icons.arrow_forward_rounded,
              ),
              label: const Text(
                'SONUÇLARI GÖR',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF020617),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hataAlani() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x15FB7185),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x42FB7185),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFFB7185),
            size: 38,
          ),
          const SizedBox(height: 11),
          const Text(
            'Canlı veri bağlantısı kurulamadı',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hataDetayi.isEmpty
                ? 'Sabit veya uydurma sayı gösterilmedi.'
                : hataDetayi,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: tekrarDene,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'TEKRAR DENE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF020617),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: sonuclaraGit,
            child: const Text(
              'UYGULAMAYA DEVAM ET',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _ilerlemeOrani {
    if (taramaTamamlandi) return 1;

    final int toplamHedef =
        hedefHaberSayisi +
        hedefFirsatSayisi +
        hedefTrendSayisi +
        hedefKaynakSayisi;

    final int mevcutToplam =
        analizEdilenHaber +
        bulunanFirsat +
        yeniTrendSayisi +
        tarananKaynak;

    if (toplamHedef <= 0) return 0;

    return (mevcutToplam / toplamHedef).clamp(0, 1);
  }

  Color get _anaRenk {
    if (baglantiHatasiVar) {
      return const Color(0xFFFB7185);
    }

    if (taramaTamamlandi) {
      return const Color(0xFF34D399);
    }

    return const Color(0xFF22D3EE);
  }

  String _sayiBicimlendir(int sayi) {
    final String ham = sayi.toString();
    final StringBuffer sonuc = StringBuffer();

    for (int i = 0; i < ham.length; i++) {
      final int kalan = ham.length - i;

      sonuc.write(ham[i]);

      if (kalan > 1 && kalan % 3 == 1) {
        sonuc.write('.');
      }
    }

    return sonuc.toString();
  }

  String _saatBicimlendir(DateTime? tarih) {
    if (tarih == null) return '--:--:--';

    final DateTime yerel = tarih.toLocal();

    String ikiHane(int deger) =>
        deger.toString().padLeft(2, '0');

    return '${ikiHane(yerel.hour)}:'
        '${ikiHane(yerel.minute)}:'
        '${ikiHane(yerel.second)}';
  }
}

enum _ModulDurumTuru {
  bekliyor,
  calisiyor,
  tamamlandi,
  kismi,
  hata,
}

class _ModulDurumu {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final _ModulDurumTuru durum;
  final int sayi;

  const _ModulDurumu({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.durum,
    required this.sayi,
  });

  Color get renk {
    switch (durum) {
      case _ModulDurumTuru.tamamlandi:
        return const Color(0xFF34D399);
      case _ModulDurumTuru.kismi:
        return const Color(0xFFFBBF24);
      case _ModulDurumTuru.hata:
        return const Color(0xFFFB7185);
      case _ModulDurumTuru.calisiyor:
        return const Color(0xFF22D3EE);
      case _ModulDurumTuru.bekliyor:
        return const Color(0xFF94A3B8);
    }
  }

  IconData get iconDurumu {
    switch (durum) {
      case _ModulDurumTuru.tamamlandi:
        return Icons.check_circle_rounded;
      case _ModulDurumTuru.kismi:
        return Icons.warning_amber_rounded;
      case _ModulDurumTuru.hata:
        return Icons.error_rounded;
      case _ModulDurumTuru.bekliyor:
        return Icons.schedule_rounded;
      case _ModulDurumTuru.calisiyor:
        return Icons.sync_rounded;
    }
  }

  String get durumMetni {
    switch (durum) {
      case _ModulDurumTuru.tamamlandi:
        return 'HAZIR';
      case _ModulDurumTuru.kismi:
        return 'KISMİ';
      case _ModulDurumTuru.hata:
        return 'HATA';
      case _ModulDurumTuru.calisiyor:
        return 'ÇALIŞIYOR';
      case _ModulDurumTuru.bekliyor:
        return 'BEKLİYOR';
    }
  }

  _ModulDurumu tamamlandiKopyasi() {
    if (durum == _ModulDurumTuru.hata) return this;

    return _ModulDurumu(
      baslik: baslik,
      aciklama: aciklama,
      icon: icon,
      durum: _ModulDurumTuru.tamamlandi,
      sayi: sayi,
    );
  }
}

class _TaramaLogu {
  final DateTime zaman;
  final String mesaj;

  const _TaramaLogu({
    required this.zaman,
    required this.mesaj,
  });
}

class _DunyaRadarPainter extends CustomPainter {
  final double rotationValue;
  final double radarValue;
  final double pulseValue;
  final bool error;
  final bool completed;
  final double progress;

  const _DunyaRadarPainter({
    required this.rotationValue,
    required this.radarValue,
    required this.pulseValue,
    required this.error,
    required this.completed,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset merkez =
        Offset(size.width / 2, size.height / 2);

    final double yaricap = size.width * 0.335;

    final Color anaRenk = error
        ? const Color(0xFFFB7185)
        : completed
            ? const Color(0xFF34D399)
            : const Color(0xFF22D3EE);

    final Paint parlama = Paint()
      ..color = anaRenk.withOpacity(
        0.08 + (pulseValue * 0.08),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      merkez,
      yaricap + 27 + (pulseValue * 7),
      parlama,
    );

    final Paint disHalka = Paint()
      ..color = anaRenk.withOpacity(0.30)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      merkez,
      yaricap + 18,
      disHalka,
    );

    canvas.drawCircle(
      merkez,
      yaricap + 7,
      disHalka,
    );

    final Rect ilerlemeRect = Rect.fromCircle(
      center: merkez,
      radius: yaricap + 23,
    );

    final Paint ilerlemeBoyasi = Paint()
      ..color = anaRenk
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      ilerlemeRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      ilerlemeBoyasi,
    );

    final Rect dunyaRect = Rect.fromCircle(
      center: merkez,
      radius: yaricap,
    );

    final Paint dunya = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 1.1,
        colors: [
          Color(0xFF155E75),
          Color(0xFF0C4A6E),
          Color(0xFF082F49),
          Color(0xFF020617),
        ],
        stops: [0, 0.43, 0.78, 1],
      ).createShader(dunyaRect);

    canvas.drawCircle(
      merkez,
      yaricap,
      dunya,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(dunyaRect),
    );

    final Paint grid = Paint()
      ..color = anaRenk.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final double katsayi
        in <double>[-0.55, -0.25, 0.25, 0.55]) {
      final double y =
          merkez.dy + (yaricap * katsayi);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(merkez.dx, y),
          width: yaricap * 2,
          height: yaricap *
              (1 - katsayi.abs() * 0.45),
        ),
        grid,
      );
    }

    for (int i = 0; i < 5; i++) {
      final double kayma =
          ((rotationValue + (i / 5)) % 1) *
                  yaricap *
                  4 -
              yaricap * 2;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            merkez.dx + kayma,
            merkez.dy,
          ),
          width: yaricap * 0.95,
          height: yaricap * 2,
        ),
        grid,
      );
    }

    final Paint kara = Paint()
      ..color =
          const Color(0xFF14B8A6).withOpacity(0.58)
      ..style = PaintingStyle.fill;

    final double kaydirma =
        math.sin(rotationValue * math.pi * 2) * 9;

    final List<Offset> noktalar = [
      Offset(
        merkez.dx - 42 + kaydirma,
        merkez.dy - 34,
      ),
      Offset(
        merkez.dx - 10 + kaydirma,
        merkez.dy - 49,
      ),
      Offset(
        merkez.dx + 25 + kaydirma,
        merkez.dy - 28,
      ),
      Offset(
        merkez.dx + 39 + kaydirma,
        merkez.dy + 5,
      ),
      Offset(
        merkez.dx + 9 + kaydirma,
        merkez.dy + 34,
      ),
      Offset(
        merkez.dx - 31 + kaydirma,
        merkez.dy + 19,
      ),
      Offset(
        merkez.dx - 51 + kaydirma,
        merkez.dy + 2,
      ),
    ];

    for (final nokta in noktalar) {
      canvas.drawCircle(
        nokta,
        7.5 + (pulseValue * 1.7),
        kara,
      );
    }

    final List<Offset> sinyalNoktalari = [
      Offset(merkez.dx - 29, merkez.dy - 20),
      Offset(merkez.dx + 23, merkez.dy - 35),
      Offset(merkez.dx + 37, merkez.dy + 16),
      Offset(merkez.dx - 12, merkez.dy + 39),
    ];

    for (int i = 0; i < sinyalNoktalari.length; i++) {
      final double gecikme =
          ((pulseValue + (i * 0.17)) % 1);

      final Paint sinyal = Paint()
        ..color = anaRenk.withOpacity(
          0.35 + (gecikme * 0.55),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        sinyalNoktalari[i],
        2.2 + (gecikme * 2.2),
        sinyal,
      );
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

    for (int i = 0; i < 7; i++) {
      final double aci =
          (math.pi * 2 * i / 7) +
              (rotationValue * math.pi * 2);

      final Offset nokta = Offset(
        merkez.dx +
            math.cos(aci) * (yaricap + 18),
        merkez.dy +
            math.sin(aci) * (yaricap + 18),
      );

      canvas.drawCircle(
        nokta,
        2.2 + (pulseValue * 1.35),
        noktaBoyasi,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _DunyaRadarPainter oldDelegate,
  ) {
    return oldDelegate.rotationValue != rotationValue ||
        oldDelegate.radarValue != radarValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.error != error ||
        oldDelegate.completed != completed ||
        oldDelegate.progress != progress;
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
      ..color = Colors.white.withOpacity(0.16)
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
      Offset(size.width * 0.48, size.height * 0.07),
      Offset(size.width * 0.56, size.height * 0.91),
      Offset(size.width * 0.38, size.height * 0.32),
      Offset(size.width * 0.74, size.height * 0.59),
    ];

    for (int i = 0; i < yildizlar.length; i++) {
      canvas.drawCircle(
        yildizlar[i],
        i.isEven ? 1.55 : 1,
        boya,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class _VeriAkisiPainter extends CustomPainter {
  final double progress;

  const _VeriAkisiPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint boya = Paint()
      ..color =
          const Color(0xFF22D3EE).withOpacity(0.045)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 9; i++) {
      final double y =
          ((progress + (i / 9)) % 1) * size.height;

      final double baslangic =
          (i.isEven ? 0.05 : 0.55) * size.width;

      final double bitis =
          (i.isEven ? 0.45 : 0.95) * size.width;

      canvas.drawLine(
        Offset(baslangic, y),
        Offset(bitis, y),
        boya,
      );

      canvas.drawCircle(
        Offset(
          baslangic +
              ((bitis - baslangic) *
                  ((progress * 2 + i / 9) % 1)),
          y,
        ),
        1.5,
        Paint()
          ..color = const Color(0xFF67E8F9)
              .withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _VeriAkisiPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}