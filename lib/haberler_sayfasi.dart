import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/api_config.dart';

class HaberlerSayfasi extends StatefulWidget {
  const HaberlerSayfasi({super.key});

  @override
  State<HaberlerSayfasi> createState() => _HaberlerSayfasiState();
}

class _HaberlerSayfasiState extends State<HaberlerSayfasi> {
  static const String _backendBaseUrl = ApiConfig.news;

  static const Duration _otomatikYenilemeSuresi =
      Duration(minutes: 5);

  final List<TrendoraHaber> _tumHaberler = [];

  final List<HaberKategori> _kategoriler = const [
    HaberKategori('Genel', 'genel', Icons.dynamic_feed_rounded),
    HaberKategori('Son Dakika', 'son_dakika', Icons.flash_on_rounded),
    HaberKategori('Gündem', 'gundem', Icons.local_fire_department_rounded),
    HaberKategori('Teknoloji', 'teknoloji', Icons.memory_rounded),
    HaberKategori('Dünya', 'dunya', Icons.public_rounded),
    HaberKategori('Ekonomi', 'ekonomi', Icons.account_balance_rounded),
    HaberKategori('Spor', 'spor', Icons.sports_soccer_rounded),
  ];
  Timer? _yenilemeZamanlayicisi;
  final ScrollController _kaydirmaDenetleyicisi = ScrollController();

  static const int _sayfaBoyutu = 20;
  int _aktifSayfa = 0;

  String _seciliKategori = 'genel';
  bool _ilkYukleme = true;
  bool _yenileniyor = false;
  String? _hataMesaji;
  DateTime? _sonGuncelleme;
  int _calisanKaynakSayisi = 0;
  int _toplamKaynakSayisi = 0;

  static const String _bildirimTercihleriAnahtari =
      'haber_bildirim_kategorileri';

  final Set<String> _bildirimKategorileri = <String>{};
  bool _bildirimTercihleriYuklendi = false;

  List<TrendoraHaber> get _gorunenHaberler {
    Iterable<TrendoraHaber> sonuc = _tumHaberler;

    switch (_seciliKategori) {
      case 'son_dakika':
        sonuc = sonuc.where(_sonDakikaMi);
        break;
      case 'gundem':
        sonuc = sonuc.where(
          (haber) =>
              _haberKategorisi(haber) == 'gundem' &&
              !_sonDakikaMi(haber),
        );
        break;
      case 'teknoloji':
        sonuc = sonuc.where(
          (haber) => _haberKategorisi(haber) == 'teknoloji',
        );
        break;
      case 'dunya':
        sonuc = sonuc.where(_dunyaHaberiMi);
        break;
      case 'ekonomi':
        sonuc = sonuc.where(
          (haber) => _haberKategorisi(haber) == 'ekonomi',
        );
        break;
      case 'spor':
        sonuc = sonuc.where(
          (haber) => _haberKategorisi(haber) == 'spor',
        );
        break;
      case 'genel':
      default:
        break;
    }

    final benzersiz = <String, TrendoraHaber>{};

    for (final haber in sonuc) {
      final anahtar = _haberGrupAnahtari(haber);
      final mevcut = benzersiz[anahtar];

      if (mevcut == null ||
          _haberOnemPuani(haber) > _haberOnemPuani(mevcut)) {
        benzersiz[anahtar] = haber;
      }
    }

    final liste = benzersiz.values.toList(growable: false)
      ..sort((a, b) {
        final onem = _haberOnemPuani(b).compareTo(
          _haberOnemPuani(a),
        );

        if (onem != 0) {
          return onem;
        }

        return b.publishedAt.compareTo(a.publishedAt);
      });

    return liste;
  }

  bool _sonDakikaMi(TrendoraHaber haber) {
    final haberYasi = DateTime.now().difference(haber.publishedAt);

    if (haberYasi.isNegative ||
        haberYasi > const Duration(hours: 2)) {
      return false;
    }

    return haber.isBreaking;
  }

  bool _dunyaHaberiMi(TrendoraHaber haber) {
    if (_haberKategorisi(haber) == 'dunya') {
      return true;
    }

    final region = haber.region
        .trim()
        .toLowerCase()
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i');

    if (const {
      'world',
      'global',
      'international',
      'dunya',
      'uluslararasi',
      'abroad',
      'foreign',
    }.contains(region)) {
      return true;
    }

    final metin = _haberMetni(haber);

    return _kelimeVar(
      metin,
      const [
        'abd',
        'amerika',
        'avrupa',
        'avrupa birliği',
        'iran',
        'israil',
        'filistin',
        'gazze',
        'rusya',
        'ukrayna',
        'çin',
        'japonya',
        'hindistan',
        'almanya',
        'fransa',
        'ingiltere',
        'italya',
        'ispanya',
        'nato',
        'birleşmiş milletler',
        'uluslararası',
        'dünya gündemi',
      ],
    );
  }

  String _haberKategorisi(TrendoraHaber haber) {
    final kategori = haber.category
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i');

    switch (kategori) {
      case 'teknoloji':
      case 'technology':
      case 'tech':
        return 'teknoloji';
      case 'ekonomi':
      case 'finance':
      case 'business':
        return 'ekonomi';
      case 'dunya':
      case 'world':
        return 'dunya';
      case 'spor':
      case 'sports':
        return 'spor';
      case 'gundem':
      default:
        return 'gundem';
    }
  }

  int _haberOnemPuani(TrendoraHaber haber) {
    final yas = DateTime.now().difference(haber.publishedAt);
    int tazelikPuani;

    if (yas.isNegative) {
      tazelikPuani = 0;
    } else if (yas.inMinutes <= 30) {
      tazelikPuani = 30;
    } else if (yas.inHours <= 2) {
      tazelikPuani = 25;
    } else if (yas.inHours <= 6) {
      tazelikPuani = 20;
    } else if (yas.inHours <= 24) {
      tazelikPuani = 14;
    } else if (yas.inDays <= 3) {
      tazelikPuani = 8;
    } else {
      tazelikPuani = 2;
    }

    final kaynakPuani = math.min(haber.sourceCount * 4, 20);

    return (haber.importanceScore.clamp(0, 100) * 0.34).round() +
        (haber.trendScore.clamp(0, 100) * 0.22).round() +
        (haber.confidenceScore.clamp(0, 100) * 0.14).round() +
        kaynakPuani +
        tazelikPuani +
        (haber.isTrending ? 8 : 0) +
        (haber.isBreaking ? 18 : 0);
  }

  String _haberGrupAnahtari(TrendoraHaber haber) {
    final metin = haber.title
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const gereksiz = {
      'son', 'dakika', 'haber', 'haberi', 'yeni', 'icin', 'ile',
      'bir', 'gore', 'olarak', 'oldu', 'dedi', 'acikladi', 'iste',
      'tum', 'detaylar',
    };

    final kelimeler = metin
        .split(' ')
        .where((kelime) => kelime.length > 2 && !gereksiz.contains(kelime))
        .take(9)
        .toList();

    return kelimeler.isEmpty ? metin : kelimeler.join(' ');
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

    _bildirimTercihleriniYukle();
    _haberleriGetir();

    _yenilemeZamanlayicisi = Timer.periodic(
      _otomatikYenilemeSuresi,
      (_) => _haberleriGetir(arkaPlanda: true),
    );
  }

  Future<void> _bildirimTercihleriniYukle() async {
    final tercihler = await SharedPreferences.getInstance();
    final kayitliKategoriler =
        tercihler.getStringList(_bildirimTercihleriAnahtari) ??
            const <String>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _bildirimKategorileri
        ..clear()
        ..addAll(kayitliKategoriler);
      _bildirimTercihleriYuklendi = true;
    });
  }

  Future<void> _bildirimTercihleriniAc() async {
    final geciciSecimler = Set<String>.from(_bildirimKategorileri);

    final sonuc = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DEE8),
                        borderRadius: BorderRadius.circular(20),
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
                            'Haber bildirimleri',
                            style: TextStyle(
                              color: Color(0xFF172B4D),
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
                        'İleride bildirim almak istediğin alanları seç.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _kategoriler
                              .where(
                                (kategori) => kategori.value != 'genel',
                              )
                              .map(
                                (kategori) => CheckboxListTile(
                                  value: geciciSecimler.contains(
                                    kategori.value,
                                  ),
                                  onChanged: (secildi) {
                                    modalSetState(() {
                                      if (secildi == true) {
                                        geciciSecimler.add(kategori.value);
                                      } else {
                                        geciciSecimler.remove(kategori.value);
                                      }
                                    });
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: const Color(0xFF172B4D),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  secondary: Icon(
                                    kategori.icon,
                                    color: const Color(0xFF52627A),
                                  ),
                                  title: Text(
                                    kategori.label,
                                    style: const TextStyle(
                                      color: Color(0xFF172B4D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            modalSetState(geciciSecimler.clear);
                          },
                          child: const Text('Temizle'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              Set<String>.from(geciciSecimler),
                            );
                          },
                          icon: const Icon(Icons.save_rounded, size: 19),
                          label: const Text('Kaydet'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF172B4D),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (sonuc == null) {
      return;
    }

    final tercihler = await SharedPreferences.getInstance();
    await tercihler.setStringList(
      _bildirimTercihleriAnahtari,
      sonuc.toList(growable: false),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _bildirimKategorileri
        ..clear()
        ..addAll(sonuc);
      _bildirimTercihleriYuklendi = true;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sonuc.isEmpty
                ? 'Haber bildirim tercihleri kapatıldı.'
                : '${sonuc.length} haber alanı kaydedildi.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _bildirimButonu() {
    final secimVar = _bildirimKategorileri.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Bildirim tercihleri',
          onPressed: _bildirimTercihleriYuklendi
              ? _bildirimTercihleriniAc
              : null,
          icon: Icon(
            secimVar
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          ),
        ),
        if (secimVar)
          const Positioned(
            right: 9,
            top: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFFC857),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    _kaydirmaDenetleyicisi.dispose();
    super.dispose();
  }

  void _sayfalamayiSifirla() {
    _aktifSayfa = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_kaydirmaDenetleyicisi.hasClients) {
        return;
      }

      _kaydirmaDenetleyicisi.jumpTo(0);
    });
  }

  void _oncekiSayfa() {
    if (_aktifSayfa <= 0) {
      return;
    }

    setState(() {
      _aktifSayfa--;
    });

    _sayfaBasinaGit();
  }

  void _sonrakiSayfa(int toplamSayfa) {
    if (_aktifSayfa >= toplamSayfa - 1) {
      return;
    }

    setState(() {
      _aktifSayfa++;
    });

    _sayfaBasinaGit();
  }

  void _sayfaBasinaGit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_kaydirmaDenetleyicisi.hasClients) {
        return;
      }

      _kaydirmaDenetleyicisi.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _haberleriGetir({
    bool arkaPlanda = false,
    bool zorlaYenile = false,
  }) async {
    if (_yenileniyor) return;

    if (mounted) {
      setState(() {
        _yenileniyor = true;

        if (!arkaPlanda && _tumHaberler.isEmpty) {
          _ilkYukleme = true;
        }

        _hataMesaji = null;
      });
    }

    try {
      const limit = 700;

      final queryParameters = <String, String>{
        'period': 'all',
        'category': 'tumu',
        'limit': '$limit',
        if (zorlaYenile) 'refresh': 'true',
      };

      final uri = Uri.parse(_backendBaseUrl).replace(
        queryParameters: queryParameters,
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Backend ${response.statusCode} koduyla cevap verdi.',
        );
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

      final rawNews = decoded['news'];

      if (rawNews is! List) {
        throw const FormatException('Haber listesi bulunamadı.');
      }

      final yeniHaberler = rawNews
          .whereType<Map>()
          .map(
            (item) => TrendoraHaber.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (haber) =>
                haber.title.trim().isNotEmpty &&
                haber.publishedAt.year >= 2000,
          )
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        if (yeniHaberler.isNotEmpty) {
          final benzersiz = <String, TrendoraHaber>{};

          for (final haber in yeniHaberler) {
            final anahtar = haber.id.trim().isNotEmpty
                ? haber.id.trim()
                : haber.url.trim().isNotEmpty
                    ? haber.url.trim()
                    : '${haber.title}|${haber.publishedAt.toIso8601String()}';

            benzersiz[anahtar] = haber;
          }

          final siraliHaberler = benzersiz.values.toList()
            ..sort(
              (a, b) => b.publishedAt.compareTo(a.publishedAt),
            );

          _tumHaberler
            ..clear()
            ..addAll(siraliHaberler);

          _sonGuncelleme = DateTime.now();
          _hataMesaji = null;
        }

        _calisanKaynakSayisi =
            _intDegeri(decoded['workingSources']);

        _toplamKaynakSayisi =
            _intDegeri(decoded['totalSources']);

        _ilkYukleme = false;
        _yenileniyor = false;
      });
    } on TimeoutException {
      _hatayiGoster(
        'Haber servisine ulaşılamadı. İnternet bağlantısını ve '
        'Render servisinin açık olduğunu kontrol et.',
      );
    } on FormatException {
      _hatayiGoster(
        'Haber servisinden geçersiz veri geldi.',
      );
    } catch (error) {
      _hatayiGoster(
        'Haberler alınamadı. Backend ve internet bağlantısını kontrol et.',
      );
    }
  }


  int _intDegeri(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _hatayiGoster(String mesaj) {
    if (!mounted) return;

    setState(() {
      _hataMesaji = mesaj;
      _ilkYukleme = false;
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

    setState(() {
      _seciliKategori = kategori;
      _aktifSayfa = 0;
    });

    _sayfaBasinaGit();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A1325),
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Haber Merkezi',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 21,
              ),
            ),
            Text(
              'Akıllı, çok kaynaklı ve önem sıralı akış',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Color(0xFFB9C3D5),
              ),
            ),
          ],
        ),
        actions: [
          _bildirimButonu(),
          IconButton(
            tooltip: 'Haberleri yenile',
            onPressed: _yenileniyor
                ? null
                : () => _haberleriGetir(zorlaYenile: true),
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
      body: SafeArea(
        child: _sayfaGovdesi(theme),
      ),
    );
  }

  Widget _sayfaGovdesi(ThemeData theme) {
    if (_ilkYukleme && _tumHaberler.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hataMesaji != null && _tumHaberler.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _haberleriGetir(zorlaYenile: true),
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

    final tumSonuclar = _gorunenHaberler;
    final toplamSayfa = tumSonuclar.isEmpty
        ? 1
        : (tumSonuclar.length / _sayfaBoyutu).ceil();

    if (_aktifSayfa >= toplamSayfa) {
      _aktifSayfa = toplamSayfa - 1;
    }

    final baslangic = _aktifSayfa * _sayfaBoyutu;
    final bitis = math.min(
      baslangic + _sayfaBoyutu,
      tumSonuclar.length,
    );

    final haberler = baslangic < tumSonuclar.length
        ? tumSonuclar.sublist(baslangic, bitis)
        : const <TrendoraHaber>[];

    return Column(
      children: [
        _durumPaneli(theme),
        _kategoriCubugu(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _haberleriGetir(zorlaYenile: true),
            child: haberler.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height:
                            MediaQuery.of(context).size.height * 0.48,
                        child: _bosKategoriAlani(),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _kaydirmaDenetleyicisi,
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 280,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                    itemCount: haberler.length + 1,
                    itemBuilder: (context, index) {
                      if (index == haberler.length) {
                        return _sayfalamaCubugu(
                          toplamSayfa: toplamSayfa,
                          toplamHaber: tumSonuclar.length,
                        );
                      }

                      return _haberKarti(
                        haberler[index],
                        baslangic + index,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _sayfalamaCubugu({
    required int toplamSayfa,
    required int toplamHaber,
  }) {
    final ilkSayfa = math.max(0, _aktifSayfa - 1);
    final sonSayfa = math.min(toplamSayfa - 1, ilkSayfa + 2);
    final sayfalar = <int>[
      for (int i = ilkSayfa; i <= sonSayfa; i++) i,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      child: Column(
        children: [
          Text(
            '$toplamHaber haber • ${_aktifSayfa + 1}/$toplamSayfa sayfa',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Önceki sayfa',
                onPressed: _aktifSayfa > 0 ? _oncekiSayfa : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              for (final sayfa in sayfalar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FilledButton(
                      onPressed: sayfa == _aktifSayfa
                          ? null
                          : () {
                              setState(() {
                                _aktifSayfa = sayfa;
                              });
                              _sayfaBasinaGit();
                            },
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        disabledBackgroundColor:
                            const Color(0xFF172B4D),
                        disabledForegroundColor: Colors.white,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF172B4D),
                        side: const BorderSide(
                          color: Color(0xFFD7DEE8),
                        ),
                      ),
                      child: Text('${sayfa + 1}'),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Sonraki sayfa',
                onPressed: _aktifSayfa < toplamSayfa - 1
                    ? () => _sonrakiSayfa(toplamSayfa)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durumPaneli(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF101B31),
            Color(0xFF172B4D),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFFC857),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sonGuncellemeMetni(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_calisanKaynakSayisi / $_toplamKaynakSayisi kaynak aktif '
                  '• 5 dk otomatik yenileme',
                  style: const TextStyle(
                    color: Color(0xFFB9C3D5),
                    fontSize: 12,
                  ),
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

  Widget _kategoriCubugu() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _kategoriler.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kategori = _kategoriler[index];
          final secili = kategori.value == _seciliKategori;

          return ChoiceChip(
            selected: secili,
            onSelected: (_) => _kategoriSec(kategori.value),
            avatar: Icon(
              kategori.icon,
              size: 17,
              color: secili
                  ? Colors.white
                  : const Color(0xFF42526B),
            ),
            label: Text(kategori.label),
            labelStyle: TextStyle(
              color: secili
                  ? Colors.white
                  : const Color(0xFF26354D),
              fontWeight: secili
                  ? FontWeight.w700
                  : FontWeight.w600,
            ),
            selectedColor: const Color(0xFF172B4D),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: secili
                  ? const Color(0xFF172B4D)
                  : const Color(0xFFDDE3EC),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          );
        },
      ),
    );
  }


  Future<void> _haberKaynakAc(TrendoraHaber haber) async {
  final uri = Uri.tryParse(haber.url);

  if (uri == null) return;

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}
  Widget _haberKarti(TrendoraHaber haber, int index) {
    final sonDakika = _sonDakikaMi(haber);
    final imageUrl = haber.imageUrl.trim();
  
    return InkWell(
  onTap: () => _haberKaynakAc(haber),
  borderRadius: BorderRadius.circular(19),
  child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: sonDakika
              ? const Color(0xFFFFC7C7)
              : const Color(0xFFE5E9F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 8.5,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 720,
                cacheHeight: 390,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) {
                  return _gorselYerTutucu(haber);
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return Container(
                    color: const Color(0xFFEFF2F6),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF9AA6B2),
                      size: 30,
                    ),
                  );
                },
              ),
            )
          else
            _gorselYerTutucu(haber),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (sonDakika) ...[
                      _etiket(
                        'SON DAKİKA',
                        const Color(0xFFB42318),
                        const Color(0xFFFFE8E6),
                      ),
                      const SizedBox(width: 7),
                    ],
                    _etiket(
                      _kategoriBasligi(_haberKategorisi(haber)),
                      const Color(0xFF24476B),
                      const Color(0xFFE9F1FA),
                    ),
                    if (haber.sourceCount > 1) ...[
                      const SizedBox(width: 7),
                      _etiket(
                        '${haber.sourceCount} KAYNAK',
                        const Color(0xFF166534),
                        const Color(0xFFDCFCE7),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _gecenSureMetni(haber.publishedAt),
                      style: const TextStyle(
                        color: Color(0xFF7B8798),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  haber.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (haber.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    haber.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5D6878),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (haber.sourceCount > 1) ...[
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Icon(
                        Icons.hub_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${haber.sourceCount} farklı kaynak doğruladı',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 17,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        haber.source.isEmpty
                            ? haber.feedSource
                            : haber.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _skorKutusu(
                      icon: Icons.local_fire_department_rounded,
                      value: haber.trendScore,
                      tooltip: 'Trend skoru',
                    ),
                    const SizedBox(width: 7),
                    _skorKutusu(
                      icon: Icons.shield_rounded,
                      value: haber.confidenceScore,
                      tooltip: 'Güven skoru',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ), 
); 
}
  

  Widget _gorselYerTutucu(TrendoraHaber haber) {
    final kaynak = haber.source.trim().isNotEmpty
        ? haber.source.trim()
        : haber.feedSource.trim();

    return Container(
      width: double.infinity,
      height: 138,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF172B4D),
            Color(0xFF1677C8),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            haber.isBreaking
                ? Icons.flash_on_rounded
                : Icons.newspaper_rounded,
            size: 42,
            color: Colors.white,
          ),
          if (kaynak.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                kaynak,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _etiket(
    String text,
    Color foreground,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
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

  Widget _skorKutusu({
    required IconData icon,
    required int value,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: const Color(0xFF4B5B72),
            ),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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

    return value
        .replaceAll('_', ' ')
        .toUpperCase();
  }

  Widget _bosKategoriAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_rounded,
              size: 62,
              color: Color(0xFF9BA7B7),
            ),
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
              'Akış 5 dakikada bir otomatik yenileniyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B8798),
                fontSize: 13,
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
                  : () => _haberleriGetir(zorlaYenile: true),
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

  const HaberKategori(
    this.label,
    this.value,
    this.icon,
  );
}
class TrendoraHaber {
  final String id;
  final String title;
  final String description;
  final String url;
  final String imageUrl;
  final String source;
  final String feedSource;
  final String category;
  final DateTime publishedAt;
  final bool isBreaking;
  final int trendScore;
  final int confidenceScore;
  final int sourceCount;
  final int importanceScore;
  final bool isTrending;
  final String region;
  final List<String> confirmingSources;

  const TrendoraHaber({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.feedSource,
    required this.category,
    required this.publishedAt,
    required this.isBreaking,
    required this.trendScore,
    required this.confidenceScore,
    required this.sourceCount,
    required this.importanceScore,
    required this.isTrending,
    required this.region,
    required this.confirmingSources,
  });

  factory TrendoraHaber.fromJson(Map<String, dynamic> json) {
    final publishedAt = _parsePublishedAt(json);

    return TrendoraHaber(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Başlıksız haber',
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      feedSource: json['feedSource']?.toString() ?? '',
      category: json['category']?.toString() ?? 'gundem',
      publishedAt: publishedAt,
      isBreaking: json['isBreaking'] == true,
      trendScore: _parseInt(json['trendScore']),
      confidenceScore:
          _parseInt(json['confidenceScore']),
      sourceCount: _parseInt(json['sourceCount']).clamp(1, 999).toInt(),
      importanceScore: _parseInt(json['importanceScore']),
      isTrending: json['isTrending'] == true,
      region: json['region']?.toString() ?? 'tr',
      confirmingSources: (json['confirmingSources'] is List)
          ? (json['confirmingSources'] as List)
              .map((item) => item.toString())
              .toList(growable: false)
          : const [],
    );
  }

  static DateTime _parsePublishedAt(Map<String, dynamic> json) {
    final values = [
      json['publishedAt'],
      json['published_at'],
      json['pubDate'],
      json['isoDate'],
      json['date'],
      json['createdAt'],
    ];

    for (final value in values) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) continue;

      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();

      final epoch = int.tryParse(raw);
      if (epoch != null) {
        final milliseconds = epoch > 9999999999 ? epoch : epoch * 1000;
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        ).toLocal();
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}