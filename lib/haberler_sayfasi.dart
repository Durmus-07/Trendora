import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HaberlerSayfasi extends StatefulWidget {
  const HaberlerSayfasi({super.key});

  @override
  State<HaberlerSayfasi> createState() => _HaberlerSayfasiState();
}

class _HaberlerSayfasiState extends State<HaberlerSayfasi> {
  static const String _backendUrl =
      'http://127.0.0.1:3000/news?limit=60';

  static const Duration _otomatikYenilemeSuresi =
      Duration(seconds: 30);

  final List<TrendoraHaber> _tumHaberler = [];

  final List<HaberKategori> _kategoriler = const [
    HaberKategori('Tümü', 'tumu', Icons.dynamic_feed_rounded),
    HaberKategori('Son Dakika', 'son_dakika', Icons.flash_on_rounded),
    HaberKategori('Türkiye', 'turkiye', Icons.flag_rounded),
    HaberKategori('Dünya', 'dunya', Icons.public_rounded),
    HaberKategori('Ekonomi', 'ekonomi', Icons.account_balance_rounded),
    HaberKategori('Borsa', 'borsa', Icons.show_chart_rounded),
    HaberKategori('Kripto', 'kripto', Icons.currency_bitcoin_rounded),
    HaberKategori('Yapay Zekâ', 'yapay_zeka', Icons.smart_toy_rounded),
    HaberKategori('Teknoloji', 'teknoloji', Icons.memory_rounded),
    HaberKategori('Spor', 'spor', Icons.sports_soccer_rounded),
    HaberKategori('Gündem', 'gundem', Icons.newspaper_rounded),
  ];

  Timer? _yenilemeZamanlayicisi;

  String _seciliKategori = 'tumu';
  bool _ilkYukleme = true;
  bool _yenileniyor = false;
  String? _hataMesaji;
  DateTime? _sonGuncelleme;
  int _calisanKaynakSayisi = 0;
  int _toplamKaynakSayisi = 0;

  List<TrendoraHaber> get _gorunenHaberler {
    if (_seciliKategori == 'tumu') {
      return List.unmodifiable(_tumHaberler);
    }

    if (_seciliKategori == 'son_dakika') {
      return _tumHaberler
          .where(_sonDakikaMi)
          .toList(growable: false);
    }

    return _tumHaberler
        .where(
          (haber) => _haberKategorisi(haber) == _seciliKategori,
        )
        .toList(growable: false);
  }

  bool _sonDakikaMi(TrendoraHaber haber) {
    final metin = _haberMetni(haber);

    return haber.isBreaking ||
        metin.contains('son dakika') ||
        metin.contains('flaş') ||
        metin.contains('acil gelişme');
  }

  String _haberKategorisi(TrendoraHaber haber) {
    final backendKategorisi = haber.category
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');

    const desteklenenKategoriler = {
      'turkiye',
      'dunya',
      'ekonomi',
      'borsa',
      'kripto',
      'yapay_zeka',
      'teknoloji',
      'spor',
      'gundem',
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

    _haberleriGetir();

    _yenilemeZamanlayicisi = Timer.periodic(
      _otomatikYenilemeSuresi,
      (_) => _haberleriGetir(arkaPlanda: true),
    );
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    super.dispose();
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
      final uri = Uri.parse(
        zorlaYenile ? '$_backendUrl&refresh=true' : _backendUrl,
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

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
          .where((haber) => haber.title.trim().isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _tumHaberler
          ..clear()
          ..addAll(yeniHaberler);

        _calisanKaynakSayisi =
            _intDegeri(decoded['workingSources']);
        _toplamKaynakSayisi =
            _intDegeri(decoded['totalSources']);

        _sonGuncelleme = DateTime.now();
        _ilkYukleme = false;
        _yenileniyor = false;
        _hataMesaji = null;
      });
    } on TimeoutException {
      _hatayiGoster(
        'Haber servisine ulaşılamadı. Backend açık mı ve telefon için '
        'adb reverse bağlantısı aktif mi kontrol et.',
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
    setState(() {
      _seciliKategori = kategori;
    });
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
              'Gerçek zamanlı çok kaynaklı akış',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Color(0xFFB9C3D5),
              ),
            ),
          ],
        ),
        actions: [
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

    final haberler = _gorunenHaberler;

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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                    itemCount: haberler.length,
                    itemBuilder: (context, index) {
                      return _haberKarti(
                        haberler[index],
                        index,
                      );
                    },
                  ),
          ),
        ),
      ],
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
                  '• 30 sn otomatik yenileme',
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

  Widget _haberKarti(TrendoraHaber haber, int index) {
    final sonDakika = haber.isBreaking;
    final imageUrl = haber.imageUrl.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
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
                errorBuilder: (_, __, ___) {
                  return _gorselYerTutucu(haber);
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return Container(
                    color: const Color(0xFFEFF2F6),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
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
    );
  }

  Widget _gorselYerTutucu(TrendoraHaber haber) {
    return Container(
      width: double.infinity,
      height: 138,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF172B4D),
            Color(0xFF294A74),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        haber.isBreaking
            ? Icons.flash_on_rounded
            : Icons.newspaper_rounded,
        size: 48,
        color: Colors.white.withOpacity(0.88),
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
              'Akış 30 saniyede bir otomatik yenileniyor.',
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
  });

  factory TrendoraHaber.fromJson(Map<String, dynamic> json) {
    final publishedAtText =
        json['publishedAt']?.toString() ?? '';

    return TrendoraHaber(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Başlıksız haber',
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      feedSource: json['feedSource']?.toString() ?? '',
      category: json['category']?.toString() ?? 'gundem',
      publishedAt:
          DateTime.tryParse(publishedAtText)?.toLocal() ??
              DateTime.now(),
      isBreaking: json['isBreaking'] == true,
      trendScore: _parseInt(json['trendScore']),
      confidenceScore:
          _parseInt(json['confidenceScore']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
