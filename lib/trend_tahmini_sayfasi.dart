import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';

class TrendTahminiSayfasi extends StatefulWidget {
  const TrendTahminiSayfasi({super.key});

  @override
  State<TrendTahminiSayfasi> createState() =>
      _TrendTahminiSayfasiState();
}

class _TrendTahminiSayfasiState extends State<TrendTahminiSayfasi> {
  final List<TrendVerisi> _trendler = [];

  Timer? _yenilemeZamanlayicisi;

  bool _yukleniyor = true;
  bool _yenileniyor = false;

  String? _hataMesaji;
  DateTime? _sonGuncelleme;

  final List<TrendKaynagi> _kaynaklar = const [
    TrendKaynagi(
      baslik: 'Arsa ve Arazi',
      arama: 'arsa arazi yatırımı Türkiye',
      kategori: 'Emlak',
      icon: Icons.landscape_outlined,
    ),
    TrendKaynagi(
      baslik: 'Otomobil',
      arama: 'otomobil ikinci el araç Türkiye',
      kategori: 'Araç',
      icon: Icons.directions_car_outlined,
    ),
    TrendKaynagi(
      baslik: 'Teknoloji Ürünleri',
      arama: 'telefon bilgisayar teknoloji ürünleri Türkiye',
      kategori: 'Ürün',
      icon: Icons.devices_outlined,
    ),
    TrendKaynagi(
      baslik: 'Borsa İstanbul',
      arama: 'Borsa İstanbul BIST hisseleri',
      kategori: 'Finans',
      icon: Icons.show_chart,
    ),
    TrendKaynagi(
      baslik: 'Kripto Para',
      arama: 'Bitcoin kripto para Türkiye',
      kategori: 'Finans',
      icon: Icons.currency_bitcoin,
    ),
    TrendKaynagi(
      baslik: 'Kırsal Yaşam',
      arama: 'köye göç kırsal yaşam Türkiye',
      kategori: 'Yaşam',
      icon: Icons.cottage_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _trendleriGetir();

    _yenilemeZamanlayicisi = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _trendleriGetir(arkaPlanda: true),
    );
  }

  Future<void> _trendleriGetir({
    bool arkaPlanda = false,
  }) async {
    if (_yenileniyor) return;

    if (mounted) {
      setState(() {
        _yenileniyor = true;
        _hataMesaji = null;

        if (!arkaPlanda && _trendler.isEmpty) {
          _yukleniyor = true;
        }
      });
    }

    try {
      final sonuclar = await Future.wait(
        _kaynaklar.map(_trendKaynaginiGetir),
      );

      sonuclar.sort(
        (a, b) => b.trendSkoru.compareTo(a.trendSkoru),
      );

      if (!mounted) return;

      setState(() {
        _trendler
          ..clear()
          ..addAll(sonuclar);

        _sonGuncelleme = DateTime.now();
        _yukleniyor = false;
        _yenileniyor = false;
        _hataMesaji = null;
      });
    } on TimeoutException {
      _hataGoster(
        'Trend kaynakları zaman aşımına uğradı. '
        'İnternet bağlantını kontrol et.',
      );
    } catch (e) {
      _hataGoster(
        'Trend verileri alınamadı. '
        'İnternet bağlantını kontrol edip tekrar dene.',
      );
    }
  }

  Future<TrendVerisi> _trendKaynaginiGetir(
    TrendKaynagi kaynak,
  ) async {
    final sorgu = Uri.encodeQueryComponent(
      '${kaynak.arama} when:30d',
    );

    final url = Uri.parse(
      'https://news.google.com/rss/search'
      '?q=$sorgu'
      '&hl=tr'
      '&gl=TR'
      '&ceid=TR:tr',
    );

    final response = await http.get(
      url,
      headers: const {
        'User-Agent': 'Trendora/1.0',
      },
    ).timeout(
      const Duration(seconds: 20),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Haber kaynağı ${response.statusCode} kodu döndürdü.',
      );
    }

    final feed = RssFeed.parse(response.body);
    final haberler = feed.items ?? [];

    final simdi = DateTime.now();

    final sonYediGun = haberler.where((haber) {
      final tarih = haber.pubDate;

      if (tarih == null) return false;

      return simdi.difference(tarih).inDays <= 7;
    }).length;

    final sonOtuzGun = haberler.where((haber) {
      final tarih = haber.pubDate;

      if (tarih == null) return false;

      return simdi.difference(tarih).inDays <= 30;
    }).length;

    final sonHaberler = haberler.take(5).toList();

    final trendSkoru = _trendSkoruHesapla(
      sonYediGun: sonYediGun,
      sonOtuzGun: sonOtuzGun,
      haberSayisi: haberler.length,
    );

    return TrendVerisi(
      baslik: kaynak.baslik,
      kategori: kaynak.kategori,
      icon: kaynak.icon,
      trendSkoru: trendSkoru,
      sonYediGunHaberSayisi: sonYediGun,
      sonOtuzGunHaberSayisi: sonOtuzGun,
      haberler: sonHaberler,
      analiz: _analizOlustur(
        baslik: kaynak.baslik,
        sonYediGun: sonYediGun,
        sonOtuzGun: sonOtuzGun,
        trendSkoru: trendSkoru,
      ),
    );
  }

  int _trendSkoruHesapla({
    required int sonYediGun,
    required int sonOtuzGun,
    required int haberSayisi,
  }) {
    if (haberSayisi == 0) return 0;

    final sonHaftaAgirligi = sonYediGun * 5;
    final sonAyAgirligi = sonOtuzGun * 2;

    final hamSkor = sonHaftaAgirligi + sonAyAgirligi;

    return hamSkor.clamp(0, 100);
  }

  String _analizOlustur({
    required String baslik,
    required int sonYediGun,
    required int sonOtuzGun,
    required int trendSkoru,
  }) {
    if (sonOtuzGun == 0) {
      return '$baslik için son 30 günde yeterli güncel haber '
          'sinyali bulunamadı.';
    }

    final haftalikOran = sonYediGun / sonOtuzGun;

    if (trendSkoru >= 80 && haftalikOran >= 0.35) {
      return '$baslik konusu son günlerde güçlü biçimde '
          'gündeme geliyor. Haber yoğunluğu ve güncellik '
          'sinyalleri yüksek.';
    }

    if (trendSkoru >= 50) {
      return '$baslik konusunda düzenli bir ilgi bulunuyor. '
          'Son haftadaki gelişmeler trendin devam ettiğini '
          'gösteriyor.';
    }

    if (sonYediGun > 0) {
      return '$baslik konusunda yeni gelişmeler var ancak '
          'güçlü bir yükseliş sinyali için daha fazla veriye '
          'ihtiyaç bulunuyor.';
    }

    return '$baslik konusu son 30 günde haberlerde yer aldı '
        'ancak son haftadaki hareketlilik düşük.';
  }

  void _hataGoster(String mesaj) {
    if (!mounted) return;

    setState(() {
      _hataMesaji = mesaj;
      _yukleniyor = false;
      _yenileniyor = false;
    });
  }

  String _sonGuncellemeMetni() {
    final tarih = _sonGuncelleme;

    if (tarih == null) {
      return 'Henüz güncellenmedi';
    }

    final saat = tarih.hour.toString().padLeft(2, '0');
    final dakika = tarih.minute.toString().padLeft(2, '0');

    return 'Son güncelleme: $saat:$dakika';
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trend Merkezi'),
        actions: [
          IconButton(
            tooltip: 'Trendleri yenile',
            onPressed: _yenileniyor ? null : _trendleriGetir,
            icon: _yenileniyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _sayfaGovdesi(),
    );
  }

  Widget _sayfaGovdesi() {
    if (_yukleniyor && _trendler.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hataMesaji != null && _trendler.isEmpty) {
      return RefreshIndicator(
        onRefresh: _trendleriGetir,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _hataAlani(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _trendleriGetir,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ustBilgiKarti(),
          const SizedBox(height: 16),
          ..._trendler.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _trendKarti(
                    sira: entry.key + 1,
                    trend: entry.value,
                  ),
                ),
              ),
          _uyariKarti(),
        ],
      ),
    );
  }

  Widget _ustBilgiKarti() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_graph,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Türkiye’de yükselen gündem sinyalleri',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Trendora; son 7 ve 30 gündeki güncel haber '
              'yoğunluğunu karşılaştırarak konuları sıralar.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.update,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  _sonGuncellemeMetni(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendKarti({
    required int sira,
    required TrendVerisi trend,
  }) {
    final renk = _skorRengi(trend.trendSkoru);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(
            '$sira',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Icon(trend.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trend.baslik,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${trend.trendSkoru}/100',
                    style: TextStyle(
                      color: renk,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: trend.trendSkoru / 100,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${trend.kategori} • '
                'Son 7 gün: ${trend.sonYediGunHaberSayisi} sinyal',
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Trendora Analizi',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(trend.analiz),
                const SizedBox(height: 16),
                _istatistikSatiri(
                  'Son 7 gün',
                  '${trend.sonYediGunHaberSayisi} güncel haber',
                ),
                _istatistikSatiri(
                  'Son 30 gün',
                  '${trend.sonOtuzGunHaberSayisi} güncel haber',
                ),
                _istatistikSatiri(
                  'Veri kaynağı',
                  'Google Haberler RSS',
                ),
                const SizedBox(height: 18),
                Text(
                  'Son gelişmeler',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (trend.haberler.isEmpty)
                  const Text(
                    'Gösterilecek güncel haber bulunamadı.',
                  )
                else
                  ...trend.haberler.map(
                    (haber) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.article_outlined,
                      ),
                      title: Text(
                        haber.title ?? 'Başlıksız haber',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: haber.pubDate == null
                          ? null
                          : Text(
                              _tarihMetni(haber.pubDate!),
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

  Widget _istatistikSatiri(
    String baslik,
    String deger,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(baslik),
          ),
          Text(
            deger,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uyariKarti() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bu ekrandaki skor, güncel haber yoğunluğu ve '
                'haberlerin zamanına göre hesaplanan bir ilgi '
                'göstergesidir. Satış adedi veya yatırım '
                'tavsiyesi değildir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hataAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _hataMesaji ?? 'Bilinmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _yenileniyor
                  ? null
                  : _trendleriGetir,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Color _skorRengi(int skor) {
    if (skor >= 80) {
      return Colors.green;
    }

    if (skor >= 50) {
      return Colors.orange;
    }

    return Colors.red;
  }

  String _tarihMetni(DateTime tarih) {
    final gun = tarih.day.toString().padLeft(2, '0');
    final ay = tarih.month.toString().padLeft(2, '0');
    final yil = tarih.year;
    final saat = tarih.hour.toString().padLeft(2, '0');
    final dakika = tarih.minute.toString().padLeft(2, '0');

    return '$gun.$ay.$yil • $saat:$dakika';
  }
}

class TrendKaynagi {
  final String baslik;
  final String arama;
  final String kategori;
  final IconData icon;

  const TrendKaynagi({
    required this.baslik,
    required this.arama,
    required this.kategori,
    required this.icon,
  });
}

class TrendVerisi {
  final String baslik;
  final String kategori;
  final IconData icon;
  final int trendSkoru;
  final int sonYediGunHaberSayisi;
  final int sonOtuzGunHaberSayisi;
  final String analiz;
  final List<RssItem> haberler;

  const TrendVerisi({
    required this.baslik,
    required this.kategori,
    required this.icon,
    required this.trendSkoru,
    required this.sonYediGunHaberSayisi,
    required this.sonOtuzGunHaberSayisi,
    required this.analiz,
    required this.haberler,
  });
}