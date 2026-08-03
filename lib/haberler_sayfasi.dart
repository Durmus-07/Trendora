import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/api_config.dart';
import 'core/news/news_clustering_service.dart';
import 'core/news/news_intelligence_service.dart';
import 'core/news/news_preview_image_service.dart';
import 'haber_detay_sayfasi.dart';
import 'haber_olay_detay_sayfasi.dart';

typedef HaberSayfasiIstegi = Future<http.Response> Function(Uri uri);

class HaberlerSayfasi extends StatefulWidget {
  const HaberlerSayfasi({super.key})
    : _initialNews = null,
      _networkEnabled = true,
      _previewEnrichmentEnabled = true,
      _testIstegi = null;

  const HaberlerSayfasi.test({super.key, required List<TrendoraHaber> news})
    : _initialNews = news,
      _networkEnabled = false,
      _previewEnrichmentEnabled = false,
      _testIstegi = null;

  const HaberlerSayfasi.paginationTest({
    super.key,
    required HaberSayfasiIstegi request,
  }) : _initialNews = null,
       _networkEnabled = true,
       _previewEnrichmentEnabled = false,
       _testIstegi = request;

  final List<TrendoraHaber>? _initialNews;
  final bool _networkEnabled;
  final bool _previewEnrichmentEnabled;
  final HaberSayfasiIstegi? _testIstegi;

  @override
  State<HaberlerSayfasi> createState() => _HaberlerSayfasiState();
}

class _HaberlerSayfasiState extends State<HaberlerSayfasi>
    with WidgetsBindingObserver {
  static const String _backendBaseUrl = ApiConfig.news;

  static const Duration _otomatikYenilemeSuresi = Duration(minutes: 2);

  final List<TrendoraHaber> _tumHaberler = [];
  final List<NewsEventCluster> _haberKumeleri = [];
  final List<_HaberAkisOgesi> _akisOgeleri = [];

  final List<HaberKategori> _kategoriler = const [
    HaberKategori('Son Dakika', 'son_dakika', Icons.flash_on_rounded),
    HaberKategori('Genel', 'genel', Icons.dynamic_feed_rounded),
    HaberKategori('Gündem', 'gundem', Icons.local_fire_department_rounded),
    HaberKategori('Dünya', 'dunya', Icons.public_rounded),
    HaberKategori('Ekonomi', 'ekonomi', Icons.account_balance_rounded),
    HaberKategori('Teknoloji', 'teknoloji', Icons.memory_rounded),
    HaberKategori('Spor', 'spor', Icons.sports_soccer_rounded),
  ];

  Timer? _yenilemeZamanlayicisi;
  final ScrollController _kaydirmaDenetleyicisi = ScrollController();

  static const int _sayfaBoyutu = 30;
  static const int _kategoriOnbellegiHaberSiniri = 120;

  String _seciliKategori = 'genel';
  int _akisSurumu = 0;
  int _mevcutSayfa = 1;
  int _toplamSayfa = 1;
  bool _dahaFazlaHaberVar = true;
  bool _ilkYukleme = true;
  bool _yenileniyor = false;
  bool _sonrakiSayfaYukleniyor = false;
  bool _sayfalamaTetiklemesiBekliyor = false;

  final Set<String> _bildirimKategorileri = {'son_dakika'};
  String? _hataMesaji;
  String? _sayfalamaHatasi;
  DateTime? _sonGuncelleme;
  int _calisanKaynakSayisi = 0;
  int _toplamKaynakSayisi = 0;
  int _yeniHaberSayisi = 0;
  bool _uygulamaAktif = true;
  String? _veriSurumu;
  final Map<String, _KategoriAkisDurumu> _kategoriOnbellegi = {};

  List<TrendoraHaber> _gorunenHaberleriFiltrele(
    Iterable<TrendoraHaber> haberler,
  ) {
    Iterable<TrendoraHaber> filtrelenmis = haberler;

    if (_seciliKategori == 'son_dakika') {
      filtrelenmis = filtrelenmis.where(_sonDakikaMi);
    } else if (_seciliKategori == 'gundem') {
      filtrelenmis = filtrelenmis.where(_gundemHaberiMi);
    } else if (_seciliKategori != 'genel') {
      filtrelenmis = filtrelenmis.where(
        (haber) => _haberKategorisi(haber) == _seciliKategori,
      );
    }

    return filtrelenmis.toList(growable: false);
  }

  bool _sonDakikaMi(TrendoraHaber haber) {
    final metin = _haberMetni(haber);
    final haberYasi = DateTime.now().difference(haber.publishedAt);

    if (haberYasi.isNegative) {
      return false;
    }

    final sonDakikaIfadesiVar =
        haber.isBreaking ||
        metin.contains('son dakika') ||
        metin.contains('flaş') ||
        metin.contains('acil gelişme') ||
        metin.contains('sıcak gelişme');

    return sonDakikaIfadesiVar && haberYasi <= const Duration(hours: 24);
  }

  bool _gelismeHaberiMi(TrendoraHaber haber) {
    if (!_sonDakikaMi(haber)) return false;
    final yas = DateTime.now().difference(haber.publishedAt);
    return yas >= const Duration(hours: 6);
  }

  bool _gundemHaberiMi(TrendoraHaber haber) {
    if (_sonDakikaMi(haber)) {
      return false;
    }

    final haberYasi = DateTime.now().difference(haber.publishedAt);

    if (haberYasi.isNegative) {
      return false;
    }

    final kategori = _haberKategorisi(haber);
    final metin = _haberMetni(haber);

    final gundemKelimesiVar = _kelimeVar(metin, const [
      'gündem',
      'açıklama yaptı',
      'yeni karar',
      'duyuruldu',
      'belli oldu',
      'yürürlüğe girdi',
      'meclis',
      'bakanlık',
      'cumhurbaşkanı',
      'deprem',
      'yangın',
      'operasyon',
      'seçim',
      'mahkeme',
      'zam',
      'yasak',
      'kritik gelişme',
    ]);

    return kategori == 'gundem' || gundemKelimesiVar;
  }

  String _haberKategorisi(TrendoraHaber haber) {
    final backendKategorisi = haber.category.trim().toLowerCase().replaceAll(
      ' ',
      '_',
    );

    const desteklenenKategoriler = {
      'ekonomi',
      'teknoloji',
      'spor',
      'gundem',
      'dunya',
    };

    if (desteklenenKategoriler.contains(backendKategorisi)) {
      return backendKategorisi;
    }

    final metin = _haberMetni(haber);

    if (_kelimeVar(metin, const [
      'futbol',
      'basketbol',
      'voleybol',
      'spor',
      'maç',
      'lig',
      'şampiyon',
      'galatasaray',
      'fenerbahçe',
      'beşiktaş',
      'trabzonspor',
      'uefa',
      'fifa',
    ])) {
      return 'spor';
    }

    if (_kelimeVar(metin, const [
      'bitcoin',
      'ethereum',
      'kripto',
      'blockchain',
      'altcoin',
      'btc',
      'eth',
      'coin',
    ])) {
      return 'kripto';
    }

    if (_kelimeVar(metin, const [
      'borsa',
      'bist',
      'hisse',
      'endeks',
      'nasdaq',
      'dow jones',
      's&p 500',
      'wall street',
    ])) {
      return 'borsa';
    }

    if (_kelimeVar(metin, const [
      'yapay zekâ',
      'yapay zeka',
      'artificial intelligence',
      'openai',
      'chatgpt',
      'gemini',
      'claude',
      'makine öğrenmesi',
    ])) {
      return 'yapay_zeka';
    }

    if (_kelimeVar(metin, const [
      'teknoloji',
      'yazılım',
      'uygulama',
      'telefon',
      'android',
      'iphone',
      'apple',
      'google',
      'microsoft',
      'siber',
      'çip',
      'robot',
    ])) {
      return 'teknoloji';
    }

    if (_kelimeVar(metin, const [
      'ekonomi',
      'enflasyon',
      'faiz',
      'dolar',
      'euro',
      'altın',
      'merkez bankası',
      'ihracat',
      'ithalat',
      'bütçe',
      'vergi',
    ])) {
      return 'ekonomi';
    }

    if (_kelimeVar(metin, const [
      'abd',
      'amerika',
      'avrupa',
      'iran',
      'israil',
      'rusya',
      'ukrayna',
      'çin',
      'almanya',
      'fransa',
      'ingiltere',
      'dünya',
      'uluslararası',
      'nato',
      'birleşmiş milletler',
    ])) {
      return 'dunya';
    }

    if (_kelimeVar(metin, const [
      'türkiye',
      'ankara',
      'istanbul',
      'izmir',
      'meclis',
      'bakanlık',
      'cumhurbaşkanı',
      'valilik',
      'belediye',
      'yargıtay',
    ])) {
      return 'turkiye';
    }

    return 'gundem';
  }

  String _haberMetni(TrendoraHaber haber) {
    return '${haber.title} ${haber.description} ${haber.source} '
            '${haber.feedSource} ${haber.category}'
        .toLowerCase();
  }

  bool _kelimeVar(String metin, List<String> kelimeler) {
    return kelimeler.any(metin.contains);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kaydirmaDenetleyicisi.addListener(_sonsuzKaydirmayiKontrolEt);

    final initialNews = widget._initialNews;
    if (initialNews != null) {
      _haberDegerlendirmeleriniHazirla(initialNews);
      _tumHaberler.addAll(initialNews);
      _haberKumeleriniGuncelle();
      _ilkYukleme = false;
      _dahaFazlaHaberVar = false;
      _toplamSayfa = 1;
      _sonGuncelleme = DateTime.now();
      _yeniHaberSayisi = initialNews.length;
    }

    if (widget._networkEnabled) {
      _haberleriGetir(sayfa: 1);
      _otomatikYenilemeyiBaslat();
    }
  }

  void _otomatikYenilemeyiBaslat() {
    if (!widget._networkEnabled) return;

    _yenilemeZamanlayicisi?.cancel();
    _yenilemeZamanlayicisi = Timer.periodic(_otomatikYenilemeSuresi, (_) {
      if (!mounted ||
          !_uygulamaAktif ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _haberleriGetir(arkaPlanda: true, sayfa: 1);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _uygulamaAktif = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _yenilemeZamanlayicisi?.cancel();
    _kaydirmaDenetleyicisi.removeListener(_sonsuzKaydirmayiKontrolEt);
    _kaydirmaDenetleyicisi.dispose();
    super.dispose();
  }

  void _sonsuzKaydirmayiKontrolEt() {
    if (!_kaydirmaDenetleyicisi.hasClients ||
        _kaydirmaDenetleyicisi.positions.length != 1 ||
        _kaydirmaDenetleyicisi.position.extentAfter > 900) {
      return;
    }

    _sonrakiSayfayiPlanla();
  }

  void _sonrakiSayfayiPlanla() {
    if (_sayfalamaTetiklemesiBekliyor ||
        _yenileniyor ||
        _sonrakiSayfaYukleniyor ||
        _sayfalamaHatasi != null ||
        !_dahaFazlaHaberVar) {
      return;
    }

    _sayfalamaTetiklemesiBekliyor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sayfalamaTetiklemesiBekliyor = false;
      if (mounted) {
        _sonrakiSayfayiYukle();
      }
    });
  }

  Future<void> _sonrakiSayfayiYukle() async {
    final sonrakiSayfa = _mevcutSayfa + 1;
    final sayfaSinirinda = _toplamSayfa > 0 && sonrakiSayfa > _toplamSayfa;

    if (!widget._networkEnabled ||
        _yenileniyor ||
        _sonrakiSayfaYukleniyor ||
        !_dahaFazlaHaberVar ||
        sayfaSinirinda) {
      return;
    }

    await _haberleriGetir(sayfa: sonrakiSayfa, listeyeEkle: true);
  }

  Future<void> _haberleriGetir({
    bool arkaPlanda = false,
    bool zorlaYenile = false,
    bool listeyeEkle = false,
    int sayfa = 1,
  }) async {
    if (_yenileniyor || _sonrakiSayfaYukleniyor) return;

    final istekAkisSurumu = _akisSurumu;
    final istekKategorisi = _seciliKategori;

    if (mounted && arkaPlanda && !listeyeEkle) {
      _yenileniyor = true;
    } else if (mounted) {
      setState(() {
        if (listeyeEkle) {
          _sonrakiSayfaYukleniyor = true;
          _sayfalamaHatasi = null;
        } else {
          _yenileniyor = true;
          _hataMesaji = null;
        }

        if (!arkaPlanda && !listeyeEkle && _tumHaberler.isEmpty) {
          _ilkYukleme = true;
        }
      });
    }

    try {
      final backendKategori = istekKategorisi == 'genel'
          ? 'tumu'
          : istekKategorisi;

      final queryParameters = <String, String>{
        'period': 'all',
        'category': backendKategori,
        'page': '$sayfa',
        'offset': '${(sayfa - 1) * _sayfaBoyutu}',
        'limit': '$_sayfaBoyutu',
        if (zorlaYenile && sayfa == 1) 'refresh': 'true',
      };

      final uri = Uri.parse(
        _backendBaseUrl,
      ).replace(queryParameters: queryParameters);

      final testIstegi = widget._testIstegi;
      final response =
          await (testIstegi != null
                  ? testIstegi(uri)
                  : http.get(
                      uri,
                      headers: const {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                      },
                    ))
              .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        throw Exception('Backend ${response.statusCode} koduyla cevap verdi.');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Geçersiz haber cevabı.');
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['error']?.toString() ?? 'Haber servisi başarısız oldu.',
        );
      }

      final rawNews = decoded['news'] ?? decoded['items'] ?? decoded['data'];

      if (rawNews is! List) {
        throw const FormatException('Haber listesi bulunamadı.');
      }

      final gelenVeriSurumu = decoded['updatedAt']?.toString().trim();
      if (arkaPlanda &&
          sayfa == 1 &&
          gelenVeriSurumu != null &&
          gelenVeriSurumu.isNotEmpty &&
          gelenVeriSurumu == _veriSurumu) {
        _yenileniyor = false;
        return;
      }

      final yeniHaberler = rawNews
          .whereType<Map>()
          .map(
            (item) => TrendoraHaber.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((haber) => haber.title.trim().isNotEmpty)
          .toList(growable: false);

      _haberDegerlendirmeleriniHazirla(yeniHaberler);

      if (!mounted ||
          istekAkisSurumu != _akisSurumu ||
          istekKategorisi != _seciliKategori) {
        return;
      }

      final mevcutAnahtarlar = _tumHaberler.map(_haberAnahtari).toSet();
      final sayfalamaEkleri = listeyeEkle
          ? yeniHaberler
                .where(
                  (haber) => !mevcutAnahtarlar.contains(_haberAnahtari(haber)),
                )
                .toList(growable: false)
          : const <TrendoraHaber>[];
      final siraliHaberler = <TrendoraHaber>[];
      final eklenenAnahtarlar = <String>{};

      void benzersizEkle(Iterable<TrendoraHaber> haberler) {
        for (final haber in haberler) {
          if (eklenenAnahtarlar.add(_haberAnahtari(haber))) {
            siraliHaberler.add(haber);
          }
        }
      }

      if (listeyeEkle) {
        benzersizEkle(_tumHaberler);
        benzersizEkle(yeniHaberler);
      } else if (arkaPlanda) {
        benzersizEkle(yeniHaberler);
        benzersizEkle(_tumHaberler);
      } else {
        benzersizEkle(yeniHaberler);
      }

      final yeniKumeler = listeyeEkle && _haberKumeleri.isNotEmpty
          ? _haberKumelerineEkle(sayfalamaEkleri, oncekiKumeler: _haberKumeleri)
          : _haberKumeleriniOlustur(
              siraliHaberler,
              oncekiKumeler: _haberKumeleri,
            );
      final yeniAkisOgeleri = _akisOgeleriniOlustur(
        haberler: siraliHaberler,
        kumeler: yeniKumeler,
      );

      setState(() {
        _tumHaberler
          ..clear()
          ..addAll(siraliHaberler);
        _haberKumeleri
          ..clear()
          ..addAll(yeniKumeler);
        _akisOgeleri
          ..clear()
          ..addAll(yeniAkisOgeleri);

        if (!arkaPlanda || listeyeEkle) {
          _mevcutSayfa = sayfa;
        }

        final backendToplamSayfa = _intDegeri(
          decoded['totalPages'] ?? decoded['pages'],
        );
        final toplamHaber = _intDegeri(
          decoded['total'] ?? decoded['totalNews'],
        );
        final yanitOfseti = _intDegeri(decoded['offset']);
        final yanitLimiti = _intDegeri(decoded['limit']) > 0
            ? _intDegeri(decoded['limit'])
            : _sayfaBoyutu;
        final donenHaberSayisi = _intDegeri(decoded['count']) > 0
            ? _intDegeri(decoded['count'])
            : yeniHaberler.length;
        final backendDevamBilgisi = decoded['hasMore'];

        if (backendToplamSayfa > 0) {
          _toplamSayfa = backendToplamSayfa;
        } else if (toplamHaber > 0) {
          _toplamSayfa = (toplamHaber / _sayfaBoyutu).ceil();
        } else {
          _toplamSayfa = backendDevamBilgisi == true ? sayfa + 1 : sayfa;
        }

        if (backendDevamBilgisi is bool) {
          _dahaFazlaHaberVar = backendDevamBilgisi;
        } else if (toplamHaber > 0) {
          _dahaFazlaHaberVar = yanitOfseti + donenHaberSayisi < toplamHaber;
        } else {
          _dahaFazlaHaberVar = donenHaberSayisi >= yanitLimiti;
        }

        _sonGuncelleme = DateTime.now();
        if (gelenVeriSurumu != null && gelenVeriSurumu.isNotEmpty) {
          _veriSurumu = gelenVeriSurumu;
        }
        _hataMesaji = null;

        _calisanKaynakSayisi = _intDegeri(decoded['workingSources']);
        _toplamKaynakSayisi = _intDegeri(decoded['totalSources']);
        if (!listeyeEkle) {
          _yeniHaberSayisi = yeniHaberler
              .where(
                (haber) => !mevcutAnahtarlar.contains(_haberAnahtari(haber)),
              )
              .length;
        }

        _ilkYukleme = false;
        _yenileniyor = false;
        _sonrakiSayfaYukleniyor = false;
      });
    } on TimeoutException {
      if (istekAkisSurumu != _akisSurumu) return;
      _hatayiGoster(
        'Haber servisine ulaşılamadı. İnternet bağlantısını kontrol et.',
        sayfalama: listeyeEkle,
      );
    } on FormatException {
      if (istekAkisSurumu != _akisSurumu) return;
      _hatayiGoster(
        'Haber servisinden geçersiz veri geldi.',
        sayfalama: listeyeEkle,
      );
    } catch (_) {
      if (istekAkisSurumu != _akisSurumu) return;
      _hatayiGoster(
        'Haberler alınamadı. Backend ve internet bağlantısını kontrol et.',
        sayfalama: listeyeEkle,
      );
    }
  }

  String _haberAnahtari(TrendoraHaber haber) {
    if (haber.id.trim().isNotEmpty) return haber.id.trim();
    if (haber.url.trim().isNotEmpty) return haber.url.trim();
    return '${haber.title}|${haber.publishedAt.toIso8601String()}';
  }

  NewsIntelligenceResult _haberDegerlendirmesiniHazirla(TrendoraHaber haber) {
    return NewsIntelligenceService.shared.evaluate(
      newsId: _haberAnahtari(haber),
      title: haber.title,
      summary: haber.description,
      articleText: haber.content,
      category: _haberKategorisi(haber),
      source: haber.source,
      feedSource: haber.feedSource,
      publishedAt: haber.hasValidPublishedAt ? haber.publishedAt : null,
      isBreaking: haber.isBreaking,
      sourceCount: haber.sourceCount,
      confirmingSourceCount: haber.confirmingSources.isEmpty
          ? (haber.sourceCount - 1).clamp(0, 998)
          : (haber.confirmingSources.length - 1).clamp(0, 998),
    );
  }

  void _haberDegerlendirmeleriniHazirla(Iterable<TrendoraHaber> haberler) {
    for (final haber in haberler) {
      _haberDegerlendirmesiniHazirla(haber);
    }
  }

  void _haberKumeleriniGuncelle() {
    final kumeler = _haberKumeleriniOlustur(
      _tumHaberler,
      oncekiKumeler: _haberKumeleri,
    );
    final akisOgeleri = _akisOgeleriniOlustur(
      haberler: _tumHaberler,
      kumeler: kumeler,
    );
    _haberKumeleri
      ..clear()
      ..addAll(kumeler);
    _akisOgeleri
      ..clear()
      ..addAll(akisOgeleri);
  }

  List<NewsEventCluster> _haberKumeleriniOlustur(
    Iterable<TrendoraHaber> haberler, {
    required List<NewsEventCluster> oncekiKumeler,
  }) {
    return NewsClusteringService.shared
        .cluster(
          categoryKey: _seciliKategori,
          candidates: _haberKumeAdaylariniOlustur(haberler),
          previousClusters: oncekiKumeler,
        )
        .where((kume) => kume.items.any((item) => item.isFeedItem))
        .toList(growable: false);
  }

  List<NewsEventCluster> _haberKumelerineEkle(
    Iterable<TrendoraHaber> haberler, {
    required List<NewsEventCluster> oncekiKumeler,
  }) {
    return NewsClusteringService.shared
        .appendToClusters(
          categoryKey: _seciliKategori,
          previousClusters: oncekiKumeler,
          candidates: _haberKumeAdaylariniOlustur(haberler),
        )
        .where((kume) => kume.items.any((item) => item.isFeedItem))
        .toList(growable: false);
  }

  List<NewsClusterCandidate> _haberKumeAdaylariniOlustur(
    Iterable<TrendoraHaber> haberler,
  ) {
    final adaylar = <NewsClusterCandidate>[];
    for (final haber in _gorunenHaberleriFiltrele(haberler)) {
      adaylar.add(_haberKumeAdayi(haber));
      for (final ilgili in haber.relatedStories.take(12)) {
        if (ilgili.title.trim().isEmpty) continue;
        adaylar.add(
          NewsClusterCandidate(
            newsId: _ilgiliHaberAnahtari(ilgili),
            title: ilgili.title,
            originalTitle: ilgili.originalTitle,
            summary: '',
            source: ilgili.source,
            feedSource: haber.feedSource,
            category: _haberKategorisi(haber),
            publishedAt: ilgili.hasValidPublishedAt ? ilgili.publishedAt : null,
            url: ilgili.url,
            imageUrl: '',
            isFeedItem: false,
          ),
        );
      }
    }
    return adaylar;
  }

  NewsClusterCandidate _haberKumeAdayi(TrendoraHaber haber) {
    final intelligence =
        NewsIntelligenceService.shared.cachedFor(_haberAnahtari(haber)) ??
        _haberDegerlendirmesiniHazirla(haber);
    final articleText = haber.content.trim() == haber.description.trim()
        ? ''
        : haber.content;
    return NewsClusterCandidate(
      newsId: _haberAnahtari(haber),
      title: haber.title,
      originalTitle: haber.originalTitle,
      summary: haber.description,
      articleText: articleText,
      source: haber.source,
      feedSource: haber.feedSource,
      category: _haberKategorisi(haber),
      publishedAt: haber.hasValidPublishedAt ? haber.publishedAt : null,
      url: haber.url,
      imageUrl: haber.imageUrl,
      trendoraScore: intelligence.trendoraScore,
      sourceScore: intelligence.source.score,
    );
  }

  List<_HaberAkisOgesi> _akisOgeleriniOlustur({
    required Iterable<TrendoraHaber> haberler,
    required Iterable<NewsEventCluster> kumeler,
  }) {
    final haberlerById = {
      for (final haber in haberler) _haberAnahtari(haber): haber,
    };
    final sonuc = <_HaberAkisOgesi>[];
    for (final kume in kumeler) {
      TrendoraHaber? temsilci = haberlerById[kume.representative.stableId];
      if (temsilci == null) {
        for (final item in kume.items.where((item) => item.isFeedItem)) {
          temsilci = haberlerById[item.stableId];
          if (temsilci != null) break;
        }
      }
      if (temsilci != null) {
        sonuc.add(_HaberAkisOgesi(haber: temsilci, kume: kume));
      }
    }
    return sonuc;
  }

  String _ilgiliHaberAnahtari(TrendoraRelatedStory haber) {
    if (haber.id.trim().isNotEmpty) return haber.id.trim();
    if (haber.url.trim().isNotEmpty) return haber.url.trim();
    return '${haber.title}|${haber.publishedAt.toIso8601String()}';
  }

  int _intDegeri(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _hatayiGoster(String mesaj, {bool sayfalama = false}) {
    if (!mounted) return;

    setState(() {
      if (sayfalama) {
        _sayfalamaHatasi = mesaj;
      } else {
        _hataMesaji = mesaj;
      }
      _ilkYukleme = false;
      _yenileniyor = false;
      _sonrakiSayfaYukleniyor = false;
    });
  }

  String _sonGuncellemeMetni() {
    final tarih = _sonGuncelleme;

    if (tarih == null) {
      return 'Henüz güncellenmedi';
    }

    final saat = tarih.hour.toString().padLeft(2, '0');
    final dakika = tarih.minute.toString().padLeft(2, '0');
    final saniye = tarih.second.toString().padLeft(2, '0');

    return 'Son güncelleme $saat:$dakika:$saniye';
  }

  String _gecenSureMetni(DateTime tarih) {
    final fark = DateTime.now().difference(tarih);

    if (fark.isNegative) {
      return 'Az önce';
    }

    if (fark.inSeconds < 60) {
      return 'Az önce';
    }

    if (fark.inMinutes < 60) {
      return '${fark.inMinutes} dk önce';
    }

    if (fark.inHours < 24) {
      return '${fark.inHours} sa önce';
    }

    if (fark.inDays < 7) {
      return '${fark.inDays} gün önce';
    }

    final gun = tarih.day.toString().padLeft(2, '0');
    final ay = tarih.month.toString().padLeft(2, '0');

    return '$gun.$ay.${tarih.year}';
  }

  void _kategoriSec(String kategori) {
    if (_seciliKategori == kategori) return;

    final onbellektekiAkis = _kategoriOnbellegi.remove(kategori);
    _mevcutKategoriyiOnbellegeAl();
    if (onbellektekiAkis != null) {
      _haberDegerlendirmeleriniHazirla(onbellektekiAkis.haberler);
    }

    setState(() {
      _akisSurumu += 1;
      _seciliKategori = kategori;
      _tumHaberler.clear();
      _haberKumeleri.clear();
      _akisOgeleri.clear();
      _yenileniyor = false;
      _sonrakiSayfaYukleniyor = false;
      _sayfalamaTetiklemesiBekliyor = false;
      _hataMesaji = null;
      _sayfalamaHatasi = null;

      if (onbellektekiAkis != null) {
        _tumHaberler.addAll(onbellektekiAkis.haberler);
        _haberKumeleri.addAll(onbellektekiAkis.haberKumeleri);
        _akisOgeleri.addAll(
          _akisOgeleriniOlustur(
            haberler: onbellektekiAkis.haberler,
            kumeler: onbellektekiAkis.haberKumeleri,
          ),
        );
        _mevcutSayfa = onbellektekiAkis.mevcutSayfa;
        _toplamSayfa = onbellektekiAkis.toplamSayfa;
        _dahaFazlaHaberVar = onbellektekiAkis.dahaFazlaHaberVar;
        _sonGuncelleme = onbellektekiAkis.sonGuncelleme;
        _calisanKaynakSayisi = onbellektekiAkis.calisanKaynakSayisi;
        _toplamKaynakSayisi = onbellektekiAkis.toplamKaynakSayisi;
        _yeniHaberSayisi = onbellektekiAkis.yeniHaberSayisi;
        _ilkYukleme = false;
      } else {
        _mevcutSayfa = 1;
        _toplamSayfa = 1;
        _dahaFazlaHaberVar = true;
        _sonGuncelleme = null;
        _calisanKaynakSayisi = 0;
        _toplamKaynakSayisi = 0;
        _yeniHaberSayisi = 0;
        _ilkYukleme = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_kaydirmaDenetleyicisi.hasClients ||
          _kaydirmaDenetleyicisi.positions.length != 1) {
        return;
      }
      final hedefKonum = onbellektekiAkis?.kaydirmaKonumu ?? 0;
      final guvenliKonum = hedefKonum.clamp(
        0.0,
        _kaydirmaDenetleyicisi.position.maxScrollExtent,
      );
      _kaydirmaDenetleyicisi.jumpTo(guvenliKonum);
    });

    if (onbellektekiAkis == null) {
      _haberleriGetir(sayfa: 1, zorlaYenile: kategori == 'son_dakika');
    }
  }

  void _mevcutKategoriyiOnbellegeAl() {
    if (_tumHaberler.isEmpty) return;

    final haberler = _tumHaberler
        .take(_kategoriOnbellegiHaberSiniri)
        .toList(growable: false);
    final haberKumeleri = _haberKumeleriniOlustur(
      haberler,
      oncekiKumeler: _haberKumeleri,
    );
    final onbellektekiSayfa = (haberler.length / _sayfaBoyutu).ceil();
    final kaydirmaKonumu =
        _kaydirmaDenetleyicisi.hasClients &&
            _kaydirmaDenetleyicisi.positions.length == 1
        ? _kaydirmaDenetleyicisi.position.pixels
        : 0.0;

    _kategoriOnbellegi.clear();
    _kategoriOnbellegi[_seciliKategori] = _KategoriAkisDurumu(
      haberler: haberler,
      haberKumeleri: List.unmodifiable(haberKumeleri),
      mevcutSayfa: onbellektekiSayfa.clamp(1, _mevcutSayfa),
      toplamSayfa: _toplamSayfa,
      dahaFazlaHaberVar: _dahaFazlaHaberVar,
      sonGuncelleme: _sonGuncelleme,
      calisanKaynakSayisi: _calisanKaynakSayisi,
      toplamKaynakSayisi: _toplamKaynakSayisi,
      yeniHaberSayisi: _yeniHaberSayisi,
      kaydirmaKonumu: kaydirmaKonumu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF091426),
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRENDORA',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              'Haber Merkezi',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: Color(0xFFB9C3D5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirim tercihleri',
            onPressed: _bildirimTercihleriniAc,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_bildirimKategorileri.isNotEmpty)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC857),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Haberleri yenile',
            onPressed: _yenileniyor
                ? null
                : () => _haberleriGetir(zorlaYenile: true, sayfa: 1),
            icon: _yenileniyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(child: _sayfaGovdesi(theme)),
    );
  }

  Widget _sayfaGovdesi(ThemeData theme) {
    if (_ilkYukleme && _tumHaberler.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hataMesaji != null && _tumHaberler.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _haberleriGetir(zorlaYenile: true, sayfa: 1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: _hataAlani(),
            ),
          ],
        ),
      );
    }

    final akisOgeleri = _akisOgeleri;

    return Column(
      children: [
        _durumPaneli(theme),
        _kategoriCubugu(),
        Expanded(
          child: TweenAnimationBuilder<double>(
            key: ValueKey<String>('kategori-gecisi-$_seciliKategori'),
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: child,
              ),
            ),
            child: RefreshIndicator(
              key: ValueKey<String>(_seciliKategori),
              onRefresh: () => _haberleriGetir(zorlaYenile: true, sayfa: 1),
              child: akisOgeleri.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.48,
                          child: _bosKategoriAlani(),
                        ),
                      ],
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>(
                        'haber-merkezi-listesi',
                      ),
                      controller: _kaydirmaDenetleyicisi,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: akisOgeleri.length + 1,
                      itemBuilder: (context, index) {
                        if (index == akisOgeleri.length) {
                          return _listeSonuAlani();
                        }

                        final onYuklemeEsigi = akisOgeleri.length > 5
                            ? akisOgeleri.length - 5
                            : 0;
                        if (index == onYuklemeEsigi) {
                          _sonrakiSayfayiPlanla();
                        }

                        final akisOgesi = akisOgeleri[index];
                        return _haberKarti(
                          akisOgesi.haber,
                          index,
                          akisOgesi.kume,
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listeSonuAlani() {
    if (_sonrakiSayfaYukleniyor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_sayfalamaHatasi != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _sonrakiSayfayiYukle,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Daha fazla haber için tekrar dene'),
          ),
        ),
      );
    }

    if (!_dahaFazlaHaberVar && _tumHaberler.length > _sayfaBoyutu) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Güncel akışın sonuna geldin',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8A94A6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox(height: 12);
  }

  Future<void> _bildirimTercihleriniAc() async {
    final geciciSecimler = Set<String>.from(_bildirimKategorileri);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF172B4D),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bildirim Tercihleri',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bildirim almak istediğin haber alanlarını seç.',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _kategoriler.map((kategori) {
                          final secili = geciciSecimler.contains(
                            kategori.value,
                          );

                          return CheckboxListTile(
                            value: secili,
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF172B4D),
                            secondary: Icon(
                              kategori.icon,
                              color: const Color(0xFF42526B),
                            ),
                            title: Text(
                              kategori.label,
                              style: const TextStyle(
                                color: Color(0xFF26354D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onChanged: (value) {
                              modalSetState(() {
                                if (value == true) {
                                  geciciSecimler.add(kategori.value);
                                } else {
                                  geciciSecimler.remove(kategori.value);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _bildirimKategorileri
                              ..clear()
                              ..addAll(geciciSecimler);
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Tercihleri Kaydet'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF172B4D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bu ekran kategori tercihlerini hazırlar. Gerçek push bildirimleri Firebase bağlantısı eklendiğinde gönderilecektir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _durumPaneli(ThemeData theme) {
    final tarananKaynakSayisi = _calisanKaynakSayisi > 0
        ? _calisanKaynakSayisi
        : _toplamKaynakSayisi;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1930), Color(0xFF18385E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFC857)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Akış güncel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 7,
                  children: [
                    _durumBilgisi(
                      Icons.schedule_rounded,
                      _sonGuncellemeMetni().replaceFirst('Son güncelleme ', ''),
                    ),
                    if (tarananKaynakSayisi > 0)
                      _durumBilgisi(
                        Icons.travel_explore_rounded,
                        '$tarananKaynakSayisi kaynak tarandı',
                      ),
                    if (_yeniHaberSayisi > 0)
                      _durumBilgisi(
                        Icons.fiber_new_rounded,
                        '$_yeniHaberSayisi yeni haber',
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _durumBilgisi(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFB9CBE2)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD5DEEA),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _kategoriCubugu() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _kategoriler.length,

        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kategori = _kategoriler[index];
          final secili = kategori.value == _seciliKategori;

          return Semantics(
            selected: secili,
            button: true,
            child: InkWell(
              onTap: () => _kategoriSec(kategori.value),
              borderRadius: BorderRadius.circular(15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: secili ? const Color(0xFF122B4B) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: secili
                        ? const Color(0xFF122B4B)
                        : const Color(0xFFE1E6ED),
                  ),
                  boxShadow: secili
                      ? const [
                          BoxShadow(
                            color: Color(0x29122B4B),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      kategori.icon,
                      size: 17,
                      color: secili
                          ? const Color(0xFFFFC857)
                          : const Color(0xFF5D6B7E),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      kategori.label,
                      style: TextStyle(
                        color: secili ? Colors.white : const Color(0xFF344054),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _haberDetayAc(TrendoraHaber haber) async {
    _yenilemeZamanlayicisi?.cancel();
    _yenilemeZamanlayicisi = null;

    final articleText = haber.content.trim() == haber.description.trim()
        ? ''
        : haber.content;
    final kume = _haberinKumesi(haber);
    final kumeKaynakSayisi = kume?.uniqueSourceCount ?? 1;
    final kaynakSayisi = haber.sourceCount > kumeKaynakSayisi
        ? haber.sourceCount
        : kumeKaynakSayisi;
    final dogrulayanKaynakSayisi = (kaynakSayisi - 1).clamp(0, 998);
    final intelligence = NewsIntelligenceService.shared.evaluate(
      newsId: _haberAnahtari(haber),
      title: haber.title,
      summary: haber.description,
      articleText: haber.content,
      category: _haberKategorisi(haber),
      source: haber.source,
      feedSource: haber.feedSource,
      publishedAt: haber.hasValidPublishedAt ? haber.publishedAt : null,
      isBreaking: haber.isBreaking,
      sourceCount: kaynakSayisi,
      confirmingSourceCount: dogrulayanKaynakSayisi,
    );

    await Navigator.of(context).push<void>(
      _premiumSayfaRotasi(
        (_) => HaberDetaySayfasi(
          title: haber.title,
          imageUrl: haber.imageUrl,
          source: haber.source.isEmpty ? haber.feedSource : haber.source,
          publishedAt: haber.publishedAt,
          hasValidPublishedAt: haber.hasValidPublishedAt,
          summary: haber.description,
          articleText: articleText,
          url: haber.url,
          id: _haberAnahtari(haber),
          category: _haberKategorisi(haber),
          feedSource: haber.feedSource,
          isBreaking: haber.isBreaking,
          relatedNews: _ilgiliHaberleri(haber),
          intelligence: intelligence,
        ),
      ),
    );

    if (mounted) {
      _otomatikYenilemeyiBaslat();
    }
  }

  Future<void> _haberOlayiniAc(NewsEventCluster kume) async {
    _yenilemeZamanlayicisi?.cancel();
    _yenilemeZamanlayicisi = null;

    await Navigator.of(context).push<void>(
      _premiumSayfaRotasi((_) => HaberOlayDetaySayfasi(cluster: kume)),
    );

    if (mounted) {
      _otomatikYenilemeyiBaslat();
    }
  }

  Route<void> _premiumSayfaRotasi(WidgetBuilder builder) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 210),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  List<RelatedNewsItem> _ilgiliHaberleri(TrendoraHaber haber) {
    final anaAday = _haberKumeAdayi(haber);
    final adaylar = <String, NewsClusterCandidate>{};
    final kume = _haberinKumesi(haber);

    if (kume != null) {
      for (final aday in kume.items) {
        if (aday.stableId != anaAday.stableId) {
          adaylar[aday.stableId] = aday;
        }
      }
    }

    if (adaylar.length < 3) {
      final siralanmis = <({NewsClusterCandidate aday, int puan})>[];
      for (final digerHaber in _tumHaberler.take(
        _kategoriOnbellegiHaberSiniri,
      )) {
        if (_haberAnahtari(digerHaber) == anaAday.stableId) continue;
        final aday = _haberKumeAdayi(digerHaber);
        if (adaylar.containsKey(aday.stableId)) continue;
        final puan = _kumeBenzerlikPuani(anaAday, aday);
        if (puan > 0) siralanmis.add((aday: aday, puan: puan));
      }
      siralanmis.sort((a, b) {
        final puanFarki = b.puan.compareTo(a.puan);
        if (puanFarki != 0) return puanFarki;
        final aTarih =
            a.aday.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTarih =
            b.aday.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTarih.compareTo(aTarih);
      });
      for (final sonuc in siralanmis) {
        adaylar[sonuc.aday.stableId] = sonuc.aday;
        if (adaylar.length >= 3) break;
      }
    }

    return adaylar.values
        .take(3)
        .map((aday) {
          return RelatedNewsItem(
            id: aday.stableId,
            title: aday.title,
            imageUrl: aday.imageUrl,
            source: aday.sourceLabel,
            publishedAt: aday.publishedAt ?? DateTime.now(),
            hasValidPublishedAt: aday.publishedAt != null,
            summary: aday.summary,
            articleText: aday.articleText,
            url: aday.url,
            category: aday.category,
            feedSource: aday.feedSource,
          );
        })
        .toList(growable: false);
  }

  NewsEventCluster? _haberinKumesi(TrendoraHaber haber) {
    final haberId = _haberAnahtari(haber);
    for (final kume in _haberKumeleri) {
      if (kume.contains(haberId)) return kume;
    }
    return null;
  }

  int _kumeBenzerlikPuani(
    NewsClusterCandidate anaHaber,
    NewsClusterCandidate aday,
  ) {
    final clustering = NewsClusteringService.shared;
    final similarity = clustering.compare(anaHaber, aday);
    final anaSinyaller = clustering.extractSignals(anaHaber);
    final adaySinyaller = clustering.extractSignals(aday);
    final ortakVarliklar = anaSinyaller.entities.intersection(
      adaySinyaller.entities,
    );
    final ortakOlaylar = anaSinyaller.eventTypes.intersection(
      adaySinyaller.eventTypes,
    );

    if (similarity.strength == NewsClusterMatchStrength.weak &&
        ortakVarliklar.isEmpty &&
        ortakOlaylar.isEmpty) {
      return 0;
    }

    return (similarity.score * 100).round() +
        ortakVarliklar.length * 18 +
        ortakOlaylar.length * 14 +
        (anaHaber.category == aday.category ? 5 : 0);
  }

  Widget _haberKarti(TrendoraHaber haber, int index, NewsEventCluster kume) {
    final sonDakika = _sonDakikaMi(haber);
    final gelisme = _gelismeHaberiMi(haber);
    final tip = _haberKartTipi(index);
    final intelligence =
        NewsIntelligenceService.shared.cachedFor(_haberAnahtari(haber)) ??
        _haberDegerlendirmesiniHazirla(haber);
    final borderRadius = tip == _HaberKartTipi.hero ? 28.0 : 22.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('haber-kumesi-${kume.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: 210 + (index.clamp(0, 5) * 25)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label:
            '${haber.title}. ${haber.source.isEmpty ? haber.feedSource : haber.source}. '
            '${_haberOkumaSuresi(haber)} dakika okuma. '
            'Güven seviyesi ${intelligence.confidence.label}.',
        child: InkWell(
          onTap: () => _haberDetayAc(haber),
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            key: ValueKey<String>('haber-karti-${_haberAnahtari(haber)}'),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: sonDakika
                    ? const Color(0xFFFFC6BE)
                    : tip == _HaberKartTipi.hero
                    ? const Color(0xFFC9D8F2)
                    : const Color(0xFFE2E7EF),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF091426).withValues(
                    alpha: tip == _HaberKartTipi.hero ? 0.13 : 0.075,
                  ),
                  blurRadius: tip == _HaberKartTipi.hero ? 28 : 18,
                  offset: Offset(0, tip == _HaberKartTipi.hero ? 12 : 7),
                ),
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey<String>(
                'haber-kart-tipi-${tip.name}-${_haberAnahtari(haber)}',
              ),
              child: switch (tip) {
                _HaberKartTipi.hero => _heroHaberKarti(
                  haber,
                  sonDakika,
                  gelisme,
                  intelligence,
                  kume,
                ),
                _HaberKartTipi.large => _buyukHaberKarti(
                  haber,
                  sonDakika,
                  gelisme,
                  intelligence,
                  kume,
                ),
                _HaberKartTipi.standard => _yatayHaberKarti(
                  haber,
                  sonDakika,
                  gelisme,
                  intelligence,
                  kume,
                  compact: false,
                ),
                _HaberKartTipi.compact => _yatayHaberKarti(
                  haber,
                  sonDakika,
                  gelisme,
                  intelligence,
                  kume,
                  compact: true,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  _HaberKartTipi _haberKartTipi(int index) {
    if (index == 0) return _HaberKartTipi.hero;
    return switch (index % 4) {
      1 => _HaberKartTipi.large,
      2 => _HaberKartTipi.standard,
      _ => _HaberKartTipi.compact,
    };
  }

  Widget _heroHaberKarti(
    TrendoraHaber haber,
    bool sonDakika,
    bool gelisme,
    NewsIntelligenceResult intelligence,
    NewsEventCluster kume,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10.2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _haberGorseli(haber),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x08000000), Color(0xB8091426)],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              const Positioned(left: 16, top: 16, child: _HeroLabel()),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Text(
                  haber.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 19),
          child: _haberMetinAlani(
            haber,
            sonDakika,
            gelisme,
            intelligence: intelligence,
            kume: kume,
            tip: _HaberKartTipi.hero,
            basligiGoster: false,
          ),
        ),
      ],
    );
  }

  Widget _buyukHaberKarti(
    TrendoraHaber haber,
    bool sonDakika,
    bool gelisme,
    NewsIntelligenceResult intelligence,
    NewsEventCluster kume,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _haberGorseli(haber),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x6607101F)],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          child: _haberMetinAlani(
            haber,
            sonDakika,
            gelisme,
            intelligence: intelligence,
            kume: kume,
            tip: _HaberKartTipi.large,
          ),
        ),
      ],
    );
  }

  Widget _yatayHaberKarti(
    TrendoraHaber haber,
    bool sonDakika,
    bool gelisme,
    NewsIntelligenceResult intelligence,
    NewsEventCluster kume, {
    required bool compact,
  }) {
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 14 : 17),
            child: SizedBox(
              width: compact ? 82 : 118,
              height: compact ? 102 : 142,
              child: _haberGorseli(haber),
            ),
          ),
          SizedBox(width: compact ? 11 : 14),
          Expanded(
            child: _haberMetinAlani(
              haber,
              sonDakika,
              gelisme,
              intelligence: intelligence,
              kume: kume,
              tip: compact ? _HaberKartTipi.compact : _HaberKartTipi.standard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _haberMetinAlani(
    TrendoraHaber haber,
    bool sonDakika,
    bool gelisme, {
    required NewsIntelligenceResult intelligence,
    required NewsEventCluster kume,
    required _HaberKartTipi tip,
    bool basligiGoster = true,
  }) {
    final rozetler = _haberRozetleri(haber, sonDakika, gelisme, intelligence);
    final genis = tip == _HaberKartTipi.hero || tip == _HaberKartTipi.large;
    final compact = tip == _HaberKartTipi.compact;
    final source = haber.source.isEmpty ? haber.feedSource : haber.source;
    final dogrulayanKaynakSayisi = haber.sourceCount > kume.uniqueSourceCount
        ? haber.sourceCount
        : kume.uniqueSourceCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final rozet in rozetler.take(compact ? 1 : 2))
              _etiket(rozet.label, rozet.foreground, rozet.background),
          ],
        ),
        if (basligiGoster) ...[
          SizedBox(height: genis ? 12 : 9),
          Text(
            haber.title,
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF101828),
              fontSize: genis
                  ? 19.5
                  : compact
                  ? 14.5
                  : 16,
              height: genis ? 1.22 : 1.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
        if (genis && haber.description.trim().isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            haber.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        SizedBox(height: genis ? 15 : 11),
        Row(
          children: [
            _kaynakMonogrami(source, size: compact ? 24 : 28),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  haber.hasValidPublishedAt
                      ? _gecenSureMetni(haber.publishedAt)
                      : 'Tarih bilinmiyor',
                  style: const TextStyle(
                    color: Color(0xFF7C8798),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_haberOkumaSuresi(haber)} dk okuma',
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: compact ? 9 : 11),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _premiumBilgiRozeti(
              Icons.auto_graph_rounded,
              'Önem ${intelligence.trendoraScore}',
            ),
            _premiumBilgiRozeti(
              Icons.verified_user_outlined,
              'Güven ${intelligence.confidence.label}',
            ),
            if (haber.trendScore >= 60)
              _premiumBilgiRozeti(Icons.trending_up_rounded, 'Trend'),
            if (dogrulayanKaynakSayisi > 1 && !compact)
              _premiumBilgiRozeti(
                Icons.fact_check_outlined,
                '$dogrulayanKaynakSayisi güvenilir kaynak doğruladı',
              ),
          ],
        ),
        if (kume.uniqueSourceCount > 1 && !compact) ...[
          const SizedBox(height: 8),
          _olayKaynakBilgisi(kume),
        ],
      ],
    );
  }

  int _haberOkumaSuresi(TrendoraHaber haber) {
    final text = haber.content.trim().isEmpty
        ? haber.description.trim()
        : haber.content.trim();
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (wordCount / 190).ceil().clamp(1, 99);
  }

  Widget _kaynakMonogrami(String source, {double size = 28}) {
    final normalized = source.trim();
    final letters = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final label = letters.isEmpty ? 'T' : letters;

    return Semantics(
      image: true,
      label: '${normalized.isEmpty ? 'Trendora' : normalized} kaynak işareti',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF17365E), Color(0xFF315B91)],
          ),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _premiumBilgiRozeti(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FA),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF315B91)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _olayKaynakBilgisi(NewsEventCluster kume) {
    return Semantics(
      button: true,
      label: '${kume.uniqueSourceCount} farklı kaynaktaki gelişmeleri aç',
      child: GestureDetector(
        key: ValueKey<String>('olay-kaynak-${kume.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _haberOlayiniAc(kume),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hub_outlined,
                size: 15,
                color: Color(0xFF315B91),
              ),
              const SizedBox(width: 6),
              Text(
                '${kume.uniqueSourceCount} farklı kaynak',
                style: const TextStyle(
                  color: Color(0xFF315B91),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF315B91),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_HaberRozeti> _haberRozetleri(
    TrendoraHaber haber,
    bool sonDakika,
    bool gelisme,
    NewsIntelligenceResult? intelligence,
  ) {
    final rozetler = <_HaberRozeti>[];

    void ekle(_HaberRozeti rozet) {
      if (rozetler.length < 2 &&
          !rozetler.any((item) => item.label == rozet.label)) {
        rozetler.add(rozet);
      }
    }

    if (sonDakika) {
      ekle(
        _HaberRozeti(
          gelisme ? 'GELİŞME' : 'SON DAKİKA',
          gelisme ? const Color(0xFF9A4B00) : const Color(0xFFB42318),
          gelisme ? const Color(0xFFFFF0D6) : const Color(0xFFFFE8E6),
        ),
      );
    }
    if ((intelligence?.importanceScore ?? 0) >=
        NewsIntelligenceService.highScoreThreshold) {
      ekle(const _HaberRozeti('ÖNEMLİ', Color(0xFF9F1239), Color(0xFFFFE4E6)));
    }
    if ((intelligence?.financialRelevanceScore ?? 0) >=
        NewsIntelligenceService.highScoreThreshold) {
      ekle(
        const _HaberRozeti(
          'FİNANS ODAKLI',
          Color(0xFF075985),
          Color(0xFFE0F2FE),
        ),
      );
    }
    if (intelligence?.source.level == NewsSourceLevel.official) {
      ekle(
        const _HaberRozeti(
          'RESMÎ KAYNAK',
          Color(0xFF166534),
          Color(0xFFDCFCE7),
        ),
      );
    }

    if (rozetler.isEmpty && haber.trendScore >= 60) {
      ekle(const _HaberRozeti('TREND', Color(0xFFC2410C), Color(0xFFFFEBDD)));
    }
    if (rozetler.length < 2 && !sonDakika) {
      ekle(
        _HaberRozeti(
          _kategoriBasligi(_haberKategorisi(haber)),
          const Color(0xFF24476B),
          const Color(0xFFEAF2FA),
        ),
      );
    }

    return rozetler;
  }

  Widget _haberGorseli(TrendoraHaber haber) {
    final imageUrl = haber.imageUrl.trim();
    if (imageUrl.isNotEmpty) return _agdanHaberGorseli(haber, imageUrl);
    if (!widget._previewEnrichmentEnabled || haber.url.trim().isEmpty) {
      return _gorselYerTutucu(haber);
    }

    return FutureBuilder<String?>(
      key: ValueKey<String>('haber-onizleme-${_haberAnahtari(haber)}'),
      future: NewsPreviewImageService.shared.resolvePreview(haber.url),
      builder: (context, snapshot) {
        final previewUrl = snapshot.data?.trim() ?? '';
        if (previewUrl.isEmpty) return _gorselYerTutucu(haber);
        return _agdanHaberGorseli(haber, previewUrl);
      },
    );
  }

  Widget _agdanHaberGorseli(TrendoraHaber haber, String imageUrl) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => _gorselYerTutucu(haber),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _gorselYerTutucu(haber);
      },
    );
  }

  Widget _gorselYerTutucu(TrendoraHaber haber) {
    final kategori = _haberKategorisi(haber);
    final (renkler, ikon) = switch (kategori) {
      'ekonomi' => (
        const [Color(0xFF0B3954), Color(0xFF087E8B)],
        Icons.account_balance_rounded,
      ),
      'borsa' => (
        const [Color(0xFF123524), Color(0xFF2F855A)],
        Icons.candlestick_chart_rounded,
      ),
      'kripto' => (
        const [Color(0xFF2E1A47), Color(0xFF6B46C1)],
        Icons.currency_bitcoin_rounded,
      ),
      'dunya' => (
        const [Color(0xFF102A43), Color(0xFF2878A7)],
        Icons.public_rounded,
      ),
      'teknoloji' || 'yapay_zeka' => (
        const [Color(0xFF1F2454), Color(0xFF635BFF)],
        Icons.memory_rounded,
      ),
      'spor' => (
        const [Color(0xFF173B2C), Color(0xFF32936F)],
        Icons.emoji_events_rounded,
      ),
      _ => (
        const [Color(0xFF172B4D), Color(0xFF294A74)],
        haber.isBreaking ? Icons.flash_on_rounded : Icons.newspaper_rounded,
      ),
    };

    return Semantics(
      image: true,
      label: '${_kategoriBasligi(kategori)} haberi için Trendora görseli',
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: renkler,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 100;
            final iconSize = compact ? 32.0 : 43.0;
            final haloSize = compact ? 66.0 : 86.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: -24,
                  top: -30,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: haloSize,
                  height: haloSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Icon(
                  ikon,
                  size: iconSize,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                if (!compact)
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Text(
                      'TRENDORA • ${_kategoriBasligi(kategori)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.75,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _etiket(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _kategoriBasligi(String value) {
    for (final kategori in _kategoriler) {
      if (kategori.value == value) {
        return kategori.label.toUpperCase();
      }
    }

    return value.replaceAll('_', ' ').toUpperCase();
  }

  Widget _bosKategoriAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 62, color: Color(0xFF9BA7B7)),
            const SizedBox(height: 14),
            const Text(
              'Bu kategoride henüz haber yok.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF344054),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Akış 2 dakikada bir otomatik yenileniyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7B8798), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hataAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 68,
              color: Color(0xFF9BA7B7),
            ),
            const SizedBox(height: 17),
            const Text(
              'Haber akışına ulaşılamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _hataMesaji ?? 'Bilinmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _yenileniyor
                  ? null
                  : () => _haberleriGetir(zorlaYenile: true, sayfa: 1),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class HaberKategori {
  final String label;
  final String value;
  final IconData icon;

  const HaberKategori(this.label, this.value, this.icon);
}

class _HaberRozeti {
  const _HaberRozeti(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

enum _HaberKartTipi { hero, large, standard, compact }

class _HeroLabel extends StatelessWidget {
  const _HeroLabel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Günün öne çıkan haberi',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1F37).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: Color(0xFFFFD166),
            ),
            SizedBox(width: 6),
            Text(
              'GÜNÜN ÖNE ÇIKANI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HaberAkisOgesi {
  const _HaberAkisOgesi({required this.haber, required this.kume});

  final TrendoraHaber haber;
  final NewsEventCluster kume;
}

class _KategoriAkisDurumu {
  const _KategoriAkisDurumu({
    required this.haberler,
    required this.haberKumeleri,
    required this.mevcutSayfa,
    required this.toplamSayfa,
    required this.dahaFazlaHaberVar,
    required this.sonGuncelleme,
    required this.calisanKaynakSayisi,
    required this.toplamKaynakSayisi,
    required this.yeniHaberSayisi,
    required this.kaydirmaKonumu,
  });

  final List<TrendoraHaber> haberler;
  final List<NewsEventCluster> haberKumeleri;
  final int mevcutSayfa;
  final int toplamSayfa;
  final bool dahaFazlaHaberVar;
  final DateTime? sonGuncelleme;
  final int calisanKaynakSayisi;
  final int toplamKaynakSayisi;
  final int yeniHaberSayisi;
  final double kaydirmaKonumu;
}

class TrendoraHaber {
  final String id;
  final String title;
  final String originalTitle;
  final String description;
  final String content;
  final String url;
  final String imageUrl;
  final String source;
  final String feedSource;
  final String category;
  final DateTime publishedAt;
  final bool hasValidPublishedAt;
  final bool isBreaking;
  final int trendScore;
  final int confidenceScore;
  final int sourceCount;
  final List<String> confirmingSources;
  final List<TrendoraRelatedStory> relatedStories;

  const TrendoraHaber({
    required this.id,
    required this.title,
    this.originalTitle = '',
    required this.description,
    required this.content,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.feedSource,
    required this.category,
    required this.publishedAt,
    this.hasValidPublishedAt = true,
    required this.isBreaking,
    required this.trendScore,
    required this.confidenceScore,
    this.sourceCount = 1,
    this.confirmingSources = const [],
    this.relatedStories = const [],
  });

  factory TrendoraHaber.fromJson(Map<String, dynamic> json) {
    final publishedAtText = json['publishedAt']?.toString() ?? '';
    final parsedPublishedAt = DateTime.tryParse(publishedAtText);

    return TrendoraHaber(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Başlıksız haber',
      originalTitle: _firstText(json, const [
        'originalTitle',
        'original_title',
      ]),
      description: _firstText(json, const ['description', 'summary']),
      content: _firstText(json, const [
        'content',
        'articleText',
        'fullText',
        'full_text',
        'body',
      ]),
      url: json['url']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      feedSource: json['feedSource']?.toString() ?? '',
      category: json['category']?.toString() ?? 'gundem',
      publishedAt: parsedPublishedAt?.toLocal() ?? DateTime.now(),
      hasValidPublishedAt: parsedPublishedAt != null,
      isBreaking: json['isBreaking'] == true,
      trendScore: _parseInt(json['trendScore']),
      confidenceScore: _parseInt(json['confidenceScore']),
      sourceCount: _parseInt(json['sourceCount']).clamp(1, 999),
      confirmingSources: _stringList(json['confirmingSources']),
      relatedStories: _relatedStories(
        json['relatedStories'] ?? json['similarNews'],
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return List.unmodifiable(
      value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty),
    );
  }

  static List<TrendoraRelatedStory> _relatedStories(dynamic value) {
    if (value is! List) return const [];
    return List.unmodifiable(
      value.whereType<Map>().map(
        (item) =>
            TrendoraRelatedStory.fromJson(Map<String, dynamic>.from(item)),
      ),
    );
  }
}

class TrendoraRelatedStory {
  const TrendoraRelatedStory({
    this.id = '',
    required this.title,
    this.originalTitle = '',
    required this.source,
    required this.url,
    required this.publishedAt,
    this.hasValidPublishedAt = true,
  });

  final String id;
  final String title;
  final String originalTitle;
  final String source;
  final String url;
  final DateTime publishedAt;
  final bool hasValidPublishedAt;

  factory TrendoraRelatedStory.fromJson(Map<String, dynamic> json) {
    final publishedAtText = json['publishedAt']?.toString() ?? '';
    final parsedPublishedAt = DateTime.tryParse(publishedAtText);
    return TrendoraRelatedStory(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      originalTitle:
          json['originalTitle']?.toString() ??
          json['original_title']?.toString() ??
          '',
      source: json['source']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      publishedAt: parsedPublishedAt?.toLocal() ?? DateTime.now(),
      hasValidPublishedAt: parsedPublishedAt != null,
    );
  }
}
