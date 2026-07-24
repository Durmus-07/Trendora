import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'profesyonel_grafik_sayfasi.dart';

class TrendTahminiSayfasi extends StatefulWidget {
  const TrendTahminiSayfasi({super.key});

  @override
  State<TrendTahminiSayfasi> createState() => _TrendTahminiSayfasiState();
}

class _TrendTahminiSayfasiState extends State<TrendTahminiSayfasi>
    with SingleTickerProviderStateMixin {
  static const _backend = 'https://trendora-icj9.onrender.com';
  static final List<TrendAnalizi> _trendOnbellegi = <TrendAnalizi>[];
  static final Map<String, TrendAnalizi> _analizOnbellegi = <String, TrendAnalizi>{};
  static DateTime? _onbellekZamani;
  static const Duration _onbellekSuresi = Duration(minutes: 20);

  final _trendler = <TrendAnalizi>[];
  final _soruKontrolcusu = TextEditingController();
  final _soruOdakNoktasi = FocusNode();

  late final AnimationController _animasyonKontrolcusu;
  Timer? _yenilemeZamanlayicisi;

  bool _yukleniyor = true;
  bool _yenileniyor = false;
  bool _soruAnalizEdiliyor = false;
  String? _hataMesaji;
  DateTime? _sonGuncelleme;
  String _seciliKategori = 'Tümü';

  final _kategoriler = const [
    'Tümü', 'Finans', 'Emlak', 'Araç', 'Ürün', 'Seyahat', 'İş', 'Genel',
  ];

  List<TrendAnalizi> get _gorunenTrendler {
    if (_seciliKategori == 'Tümü') return _trendler;
    return _trendler
        .where((e) => e.uygulamaKategorisi == _seciliKategori)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _animasyonKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final onbellekGecerli = _trendOnbellegi.isNotEmpty &&
        _onbellekZamani != null &&
        DateTime.now().difference(_onbellekZamani!) < _onbellekSuresi;
    if (onbellekGecerli) {
      _trendler.addAll(_trendOnbellegi);
      _sonGuncelleme = _onbellekZamani;
      _yukleniyor = false;
      _trendleriGetir(arkaPlanda: true);
    } else {
      _trendleriGetir();
    }
    _yenilemeZamanlayicisi = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _trendleriGetir(arkaPlanda: true),
    );
  }

  Future<void> _trendleriGetir({bool arkaPlanda = false}) async {
    if (_yenileniyor) return;

    setState(() {
      _yenileniyor = true;
      _hataMesaji = null;
      if (!arkaPlanda && _trendler.isEmpty) _yukleniyor = true;
    });

    try {
      final response = await _getWithWarmup(
        Uri.parse('$_backend/api/trends'),
      );

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 ||
          body is! Map<String, dynamic> ||
          body['success'] != true) {
        throw Exception(
          body is Map<String, dynamic>
              ? body['message']?.toString() ?? 'Trend verisi alınamadı.'
              : 'Trend verisi alınamadı.',
        );
      }

      final raw = body['trends'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => TrendAnalizi.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <TrendAnalizi>[];

      list.sort((a, b) => b.confidence.compareTo(a.confidence));

      if (!mounted) return;
      setState(() {
        _trendler
          ..clear()
          ..addAll(list);
        _sonGuncelleme =
            DateTime.tryParse(body['updatedAt']?.toString() ?? '') ??
                DateTime.now();
        _yukleniyor = false;
        _yenileniyor = false;
        _trendOnbellegi
          ..clear()
          ..addAll(list);
        _onbellekZamani = _sonGuncelleme;
      });
    } on TimeoutException {
      _hataGoster(
        'Trend motoru zaman aşımına uğradı. Render ilk açılışta '
        'biraz geç yanıt verebilir; tekrar dene.',
      );
    } catch (e) {
      _hataGoster(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _soruyuAnalizEt() async {
    final soru = _soruKontrolcusu.text.trim();
    if (_soruAnalizEdiliyor) return;
    if (soru.length < 3) {
      _mesajGoster('Analiz etmek istediğin konuyu biraz daha açık yaz.');
      return;
    }

    FocusScope.of(context).unfocus();
    final onbellekAnahtari = _normalizeQuery(soru);
    final onbellekteki = _analizOnbellegi[onbellekAnahtari];
    if (onbellekteki != null) {
      _soruKontrolcusu.clear();
      _analizDetayiniGoster(onbellekteki);
      return;
    }

    setState(() => _soruAnalizEdiliyor = true);

    try {
      final response = await http.post(
        Uri.parse('$_backend/api/trends/analyze'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'query': soru}),
      ).timeout(const Duration(seconds: 70));

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 ||
          body is! Map<String, dynamic> ||
          body['success'] != true) {
        throw Exception(
          body is Map<String, dynamic>
              ? body['message']?.toString() ?? 'Analiz oluşturulamadı.'
              : 'Analiz oluşturulamadı.',
        );
      }

      final raw = body['analysis'];
      if (raw is! Map) throw Exception('Analiz verisi eksik geldi.');

      final sonuc =
          TrendAnalizi.fromJson(Map<String, dynamic>.from(raw));
      _analizOnbellegi[onbellekAnahtari] = sonuc;

      if (!mounted) return;
      setState(() {
        _trendler.removeWhere(
          (e) => e.query.toLowerCase() ==
              sonuc.query.toLowerCase(),
        );
        _trendler.insert(0, sonuc);
        _seciliKategori = 'Tümü';
        _soruAnalizEdiliyor = false;
        _sonGuncelleme =
            DateTime.tryParse(body['updatedAt']?.toString() ?? '') ??
                DateTime.now();
      });

      _soruKontrolcusu.clear();
      _analizDetayiniGoster(sonuc);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _soruAnalizEdiliyor = false);
      _mesajGoster('Analiz zaman aşımına uğradı. Tekrar deneyebilirsin.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _soruAnalizEdiliyor = false);
      _mesajGoster(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _analizDetayiniGoster(TrendAnalizi trend) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF091827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF21435F)),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF35536D),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _ikonKutusu(trend.icon, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trend.answerTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _skorRozeti(trend.confidence),
                ],
              ),
              const SizedBox(height: 18),
              _trendoraKarariKarti(trend),
              if (trend.domain == 'finance' &&
                  (trend.dailyPrice.available || trend.yearlyPrice.available)) ...[
                const SizedBox(height: 12),
                _canliFiyatOzetiKarti(trend),
              ],
              if (trend.domain == 'finance') ...[
                const SizedBox(height: 12),
                _profesyonelGrafikKarti(trend),
              ],
              const SizedBox(height: 12),
              _dogrudanCevapKarti(trend),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _miniIstatistikKarti(
                      baslik: 'Trend puanı',
                      deger: '${trend.confidence}',
                      aciklama: _guvenMetni(trend.confidence),
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniIstatistikKarti(
                      baslik: 'Güven',
                      deger: '%${trend.confidence}',
                      aciklama: trend.confidenceLabel,
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ],
              ),
              if (trend.statistics.hasAny) ...[
                const SizedBox(height: 18),
                _istatistikOzetiKarti(trend.statistics),
              ],
              if (trend.domain == 'finance') ...[
                if (trend.dailyPrice.available) ...[
                  const SizedBox(height: 18),
                  _gunlukFiyatHareketiKarti(trend),
                ],
                if (trend.yearlyPrice.available) ...[
                  const SizedBox(height: 12),
                  _elliIkiHaftaFiyatAraligiKarti(trend),
                ],
                if (trend.dailyPrice.available || trend.yearlyPrice.available) ...[
                  const SizedBox(height: 12),
                  _noktaAnaliziKarti(trend),
                ],
              ] else if (trend.estimatedRange.available) ...[
                const SizedBox(height: 18),
                _fiyatAraligiKarti(trend.estimatedRange),
              ],
              if (trend.scenarios.isNotEmpty) ...[
                const SizedBox(height: 22),
                _detayBasligi(Icons.account_tree_outlined, 'Olasılık senaryoları'),
                const SizedBox(height: 10),
                ...trend.scenarios.map(_senaryoKarti),
              ],
              if (trend.signals.isNotEmpty) ...[
                const SizedBox(height: 22),
                _detayBasligi(Icons.sensors_rounded, 'Ölçülen sinyaller'),
                const SizedBox(height: 10),
                ...trend.signals.map(_sinyalKarti),
              ],
              if (trend.keyFactors.isNotEmpty) ...[
                const SizedBox(height: 22),
                _maddeListesi(
                  Icons.tune_rounded,
                  'Belirleyici faktörler',
                  trend.keyFactors,
                ),
              ],
              if (trend.missingInformation.isNotEmpty) ...[
                const SizedBox(height: 18),
                _maddeListesi(
                  Icons.help_outline_rounded,
                  'Eksik veya sınırlı veriler',
                  trend.missingInformation,
                ),
              ],
              if (trend.nextChecks.isNotEmpty) ...[
                const SizedBox(height: 18),
                _maddeListesi(
                  Icons.fact_check_outlined,
                  'Karardan önce kontrol et',
                  trend.nextChecks,
                ),
              ],
              const SizedBox(height: 22),
              _detayBasligi(Icons.link_rounded, 'İncelenen kaynaklar'),
              const SizedBox(height: 8),
              if (trend.sources.isEmpty)
                const Text(
                  'Gösterilebilecek doğrudan kaynak bağlantısı bulunamadı.',
                  style: TextStyle(color: Color(0xFF91A9BC)),
                )
              else
                ...trend.sources.map(_kaynakSatiri),
              const SizedBox(height: 18),
              _uyariKarti(metin: trend.disclaimer),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(child: _sayfaGovdesi()),
    );
  }

  Widget _sayfaGovdesi() {
    if (_yukleniyor && _trendler.isEmpty) return _yukleniyorAlani();

    if (_hataMesaji != null && _trendler.isEmpty) {
      return RefreshIndicator(
        onRefresh: _trendleriGetir,
        color: const Color(0xFF6EE7F9),
        backgroundColor: const Color(0xFF10243B),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.82,
              child: _hataAlani(),
            ),
          ],
        ),
      );
    }

    final gorunenler = _gorunenTrendler;

    return RefreshIndicator(
      onRefresh: _trendleriGetir,
      color: const Color(0xFF6EE7F9),
      backgroundColor: const Color(0xFF10243B),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          _ustBaslik(),
          const SizedBox(height: 16),
          _anaAnalizKarti(),
          const SizedBox(height: 15),
          _soruKarti(),
          const SizedBox(height: 18),
          _kategoriCubugu(),
          const SizedBox(height: 22),
          _bolumBasligi(
            _seciliKategori == 'Tümü'
                ? 'Güncel analizler'
                : '$_seciliKategori analizleri',
            '${gorunenler.length} başlık Trendora motoruyla değerlendirildi',
          ),
          const SizedBox(height: 13),
          if (gorunenler.isEmpty)
            _bosKategoriKarti()
          else
            ...gorunenler.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: _trendKarti(entry.key + 1, entry.value),
                  ),
                ),
          const SizedBox(height: 5),
          _kapsamKarti(),
          const SizedBox(height: 12),
          _uyariKarti(),
        ],
      ),
    );
  }

  Widget _ustBaslik() {
    return Row(
      children: [
        _kareButon(
          Icons.arrow_back_ios_new_rounded,
          () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 11),
        _ikonKutusu(Icons.public_rounded, 46),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trend Merkezi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Olasılık ve karar destek analizi',
                style: TextStyle(
                  color: Color(0xFF8FA9C1),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        _kareButon(
          _yenileniyor ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
          _yenileniyor ? null : () => _trendleriGetir(),
        ),
      ],
    );
  }

  Widget _anaAnalizKarti() {
    final enGuclu = _trendler.isEmpty ? null : _trendler.first;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF0B1F33), Color(0xFF112844)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1C4265)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -45,
            child: AnimatedBuilder(
              animation: _animasyonKontrolcusu,
              builder: (_, child) => Transform.rotate(
                angle: _animasyonKontrolcusu.value * 6.28,
                child: child,
              ),
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4FD1C5).withOpacity(0.12),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _canliNokta(),
                    const SizedBox(width: 9),
                    const Text(
                      'CANLI ANALİZ',
                      style: TextStyle(
                        color: Color(0xFF7DE3D7),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFF7592AC),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _sonGuncellemeMetni(),
                      style: const TextStyle(
                        color: Color(0xFF9CB5CB),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                const Text(
                  'Trendora motoru hazır',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Kaynaklar, riskler, senaryolar ve güven puanları '
                  'tek bir karar destek analizinde birleştiriliyor.',
                  style: TextStyle(
                    color: Color(0xFFA7BED2),
                    height: 1.48,
                    fontSize: 13.5,
                  ),
                ),
                if (enGuclu != null) ...[
                  const SizedBox(height: 21),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _analizDetayiniGoster(enGuclu),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071726).withOpacity(0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF244661)),
                      ),
                      child: Row(
                        children: [
                          _ikonKutusu(enGuclu.icon, 49),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'En yüksek güvenli analiz',
                                  style: TextStyle(
                                    color: Color(0xFF7694AE),
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  enGuclu.answerTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _skorRozeti(enGuclu.confidence),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soruKarti() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2439), Color(0xFF0B1B2D)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E4564)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF6EE7F9)),
              SizedBox(width: 9),
              Text(
                'Bir konuyu Trendora’ya sor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Hisse, altın, araç, arsa, konut, ürün veya iş fikri yaz. '
            'Trendora senaryo, olasılık, güven puanı ve risk analizi oluştursun.',
            style: TextStyle(
              color: Color(0xFF91A9BC),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _soruKontrolcusu,
            focusNode: _soruOdakNoktasi,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _soruyuAnalizEt(),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Örn. Tüpraş hissesinin gidişatı nasıl?',
              hintStyle: const TextStyle(color: Color(0xFF68839A)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7AA8C8),
              ),
              suffixIcon: _soruAnalizEdiliyor
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6EE7F9),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _soruyuAnalizEt,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF6EE7F9),
                      ),
                    ),
              filled: true,
              fillColor: const Color(0xFF071827),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF1D405D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF1D405D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF42D9D1),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kategoriCubugu() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kategoriler.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final kategori = _kategoriler[index];
          final secili = kategori == _seciliKategori;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _seciliKategori = kategori),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                gradient: secili
                    ? const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF2563EB)],
                      )
                    : null,
                color: secili ? null : const Color(0xFF102238),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: secili ? Colors.transparent : const Color(0xFF1A3855),
                ),
              ),
              child: Text(
                kategori,
                style: TextStyle(
                  color: secili ? Colors.white : const Color(0xFFA7BDD0),
                  fontWeight: secili ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trendKarti(int sira, TrendAnalizi trend) {
    final renk = _skorRengi(trend.confidence);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _analizDetayiniGoster(trend),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2034),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1A3855)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [renk.withOpacity(0.34), renk.withOpacity(0.09)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: renk.withOpacity(0.34)),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(trend.icon, color: Colors.white, size: 27)),
                  Positioned(
                    right: 5,
                    top: 4,
                    child: Text(
                      '$sira',
                      style: const TextStyle(
                        color: Color(0xFFBFD7EA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trend.answerTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _etiket(trend.uygulamaKategorisi, Icons.grid_view_rounded),
                      _etiket(trend.confidenceLabel, Icons.verified_outlined),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    trend.directAnswer.isNotEmpty
                        ? trend.directAnswer
                        : trend.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF91A9BC),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: trend.confidence / 100,
                            minHeight: 7,
                            backgroundColor: const Color(0xFF1B334A),
                            valueColor: AlwaysStoppedAnimation<Color>(renk),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      _skorRozeti(trend.confidence),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6F8DA6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendoraKarariKarti(TrendAnalizi trend) {
    final stats = trend.statistics;
    final risk = stats.riskScore ?? (100 - trend.confidence).clamp(0, 100).toInt();
    final strength = stats.trendStrength ?? trend.confidence;
    final positive = trend.scenarios.isEmpty
        ? strength >= 60
        : trend.scenarios.first.name.toLowerCase().contains('olum') ||
            trend.scenarios.first.name.toLowerCase().contains('yüks');
    final negative = trend.scenarios.isNotEmpty &&
        (trend.scenarios.first.name.toLowerCase().contains('olumsuz') ||
            trend.scenarios.first.name.toLowerCase().contains('düş'));
    final decision = negative
        ? 'Temkinli'
        : positive
            ? 'Olumlu'
            : 'Nötr';
    final color = negative
        ? const Color(0xFFFF8A80)
        : positive
            ? const Color(0xFF72E6B1)
            : const Color(0xFFFFD166);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.17), const Color(0xFF0B1F33)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: color, size: 21),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TRENDORA KARARI',
                  style: TextStyle(
                    color: Color(0xFF9FB9CD),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.05,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  decision,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _ilkCumle(trend.directAnswer.isNotEmpty
                ? trend.directAnswer
                : trend.summary),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.42,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kararEtiketi('Güven', '%${trend.confidence}', Icons.verified_outlined),
              _kararEtiketi('Risk', _seviyeMetni(risk), Icons.shield_outlined),
              _kararEtiketi('Trend', _seviyeMetni(strength), Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kararEtiketi(String baslik, String deger, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1928),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B3A52)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7DD3FC)),
          const SizedBox(width: 6),
          Text('$baslik: ', style: const TextStyle(color: Color(0xFF7893AA), fontSize: 11)),
          Text(deger, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _canliFiyatOzetiKarti(TrendAnalizi trend) {
    final current = trend.dailyPrice.current ??
        trend.dailyPrice.close ??
        trend.dailyPrice.vwap ??
        trend.dailyPrice.average ??
        trend.dailyPrice.open ??
        trend.yearlyPrice.average52w;
    final currency = trend.dailyPrice.currency ??
        trend.yearlyPrice.currency ??
        trend.estimatedRange.currency ??
        'TRY';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panelDekorasyon(const Color(0xFF285D75)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FİYAT ÖZETİ',
            style: TextStyle(
              color: Color(0xFF6EE7F9),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _paraMetni(current, currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          if (trend.yearlyPrice.available) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _ozetFiyat('52H düşük', trend.yearlyPrice.low52w, currency)),
                const SizedBox(width: 8),
                Expanded(child: _ozetFiyat('52H ortalama', trend.yearlyPrice.average52w, currency)),
                const SizedBox(width: 8),
                Expanded(child: _ozetFiyat('52H yüksek', trend.yearlyPrice.high52w, currency)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ozetFiyat(String baslik, double? deger, String? para) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: const TextStyle(color: Color(0xFF7893AA), fontSize: 10)),
        const SizedBox(height: 3),
        Text(
          _paraMetni(deger, para),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String _ilkCumle(String text) {
    final cleaned = _temizMetin(text).trim();
    if (cleaned.isEmpty) return 'Bu başlık için veri temelli görünüm oluşturuldu.';
    final match = RegExp(r'^(.{1,180}?[.!?])(?:\s|$)').firstMatch(cleaned);
    if (match != null) return match.group(1)!.trim();
    return cleaned.length <= 180 ? cleaned : '${cleaned.substring(0, 177).trim()}...';
  }

  String _seviyeMetni(int value) {
    if (value >= 75) return 'Yüksek';
    if (value >= 45) return 'Orta';
    return 'Düşük';
  }

  Widget _profesyonelGrafikKarti(TrendAnalizi trend) {
    final current = trend.dailyPrice.current ??
        trend.dailyPrice.close ??
        trend.dailyPrice.vwap ??
        trend.dailyPrice.average ??
        trend.dailyPrice.open ??
        trend.yearlyPrice.average52w;
    final currency = trend.dailyPrice.currency ??
        trend.yearlyPrice.currency ??
        trend.estimatedRange.currency ??
        'TRY';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfesyonelGrafikSayfasi(
              baslik: trend.answerTitle,
              sorgu: trend.query,
              guncelFiyat: current,
              elliIkiHaftaDusuk: trend.yearlyPrice.low52w,
              elliIkiHaftaYuksek: trend.yearlyPrice.high52w,
              paraBirimi: currency,
              guvenPuani: trend.confidence,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF12354A), Color(0xFF0B1F33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2B7184)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.candlestick_chart_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profesyonel Grafik',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Mum, RSI, MACD, EMA, SMA, Bollinger, hacim ve çizim araçları',
                    style: TextStyle(
                      color: Color(0xFF9CB5C8),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_full_rounded,
              color: Color(0xFF6EE7F9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dogrudanCevapKarti(TrendAnalizi trend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF0B1F33)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E4564)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ANALİZ DETAYI',
            style: TextStyle(
              color: Color(0xFF6EE7F9),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _temizMetin(trend.directAnswer.isNotEmpty ? trend.directAnswer : trend.summary),
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trend.summary.isNotEmpty &&
              trend.summary != trend.directAnswer) ...[
            const SizedBox(height: 12),
            Text(
              _temizMetin(trend.summary),
              style: const TextStyle(
                color: Color(0xFFA9C0D3),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _istatistikOzetiKarti(TrendIstatistikleri stats) {
    final items = <({String title, int? value, IconData icon})>[
      (title: 'Trend gücü', value: stats.trendStrength, icon: Icons.trending_up_rounded),
      (title: 'Veri güveni', value: stats.dataConfidence, icon: Icons.verified_outlined),
      (title: 'Risk', value: stats.riskScore, icon: Icons.warning_amber_rounded),
      (title: 'Haber etkisi', value: stats.newsImpact, icon: Icons.newspaper_rounded),
      (title: 'Piyasa ilgisi', value: stats.marketInterest, icon: Icons.people_alt_outlined),
    ].where((e) => e.value != null).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(Icons.insights_rounded, 'Trendora Skorları'),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    width: 145,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1928),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1A344A)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 18, color: const Color(0xFF7DD3FC)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF7893AA),
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _seviyeMetni(item.value!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: item.value! / 100,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFF1B334A),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6EE7F9)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _gunlukFiyatHareketiKarti(TrendAnalizi trend) {
    final price = trend.dailyPrice;
    final currency = price.currency ?? trend.estimatedRange.currency ?? 'TRY';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(Icons.candlestick_chart_rounded, 'Canlı Günlük Fiyat'),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _aralikDegeri('Anlık', price.current ?? price.close, currency, vurgulu: true)),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('Açılış', price.open, currency)),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('Kapanış', price.close, currency)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _aralikDegeri('Gün içi düşük', price.low, currency)),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('Gün içi yüksek', price.high, currency)),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('VWAP', price.vwap ?? price.average, currency)),
            ],
          ),
          if (price.changePercent != null || price.volume != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (price.changePercent != null)
                  _kararEtiketi(
                    'Günlük değişim',
                    '%${price.changePercent!.toStringAsFixed(2).replaceAll('.', ',')}',
                    price.changePercent! >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),
                if (price.volume != null)
                  _kararEtiketi(
                    'Hacim',
                    _sayiKisalt(price.volume!),
                    Icons.bar_chart_rounded,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'VWAP, işlem hacmiyle ağırlıklandırılmış gün içi ortalama fiyattır. Piyasa açıkken anlık fiyat; piyasa kapalıyken son kapanış gösterilir.',
            style: TextStyle(
              color: Color(0xFF8CA6BA),
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  String _sayiKisalt(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} Mr';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Mn';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} B';
    }
    return value.toStringAsFixed(0);
  }

  Widget _elliIkiHaftaFiyatAraligiKarti(TrendAnalizi trend) {
    final price = trend.yearlyPrice;
    final currency = price.currency ?? trend.estimatedRange.currency ?? 'TRY';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(Icons.timeline_rounded, '52 Haftalık Fiyat Aralığı'),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _aralikDegeri('52 hafta düşük', price.low52w, currency)),
              const SizedBox(width: 8),
              Expanded(
                child: _aralikDegeri(
                  '52 hafta ortalama',
                  price.average52w,
                  currency,
                  vurgulu: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('52 hafta yüksek', price.high52w, currency)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu bölüm yalnızca 52 haftalık düşük, ortalama ve yüksek değerleri gösterir; günlük fiyatlarla karıştırılmaz.',
            style: const TextStyle(
              color: Color(0xFF8CA6BA),
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noktaAnaliziKarti(TrendAnalizi trend) {
    final current = trend.dailyPrice.current ??
        trend.dailyPrice.close ??
        trend.dailyPrice.vwap ??
        trend.dailyPrice.average ??
        trend.dailyPrice.open;
    final range = trend.yearlyPrice.low52w != null &&
            trend.yearlyPrice.high52w != null
        ? (trend.yearlyPrice.low52w!, trend.yearlyPrice.high52w!)
        : null;
    final analysis = _buildPointAnalysis(
      current: current,
      week52: range,
      confidence: trend.confidence,
      scenarios: trend.scenarios,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDekorasyon(const Color(0xFF2B7184)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(Icons.my_location_rounded, 'Trendora Nokta Analizi'),
          const SizedBox(height: 11),
          Text(
            analysis,
            style: const TextStyle(
              color: Color(0xFFD8E8F3),
              height: 1.5,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu değerlendirme yatırım tavsiyesi değildir; fiyat konumu, veri güveni ve senaryo dağılımının istatistiksel yorumudur.',
            style: TextStyle(
              color: Color(0xFF7893AA),
              height: 1.4,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiyatAraligiKarti(TahminiAralik range) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(Icons.price_check_rounded, range.label),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _aralikDegeri('Alt bant', range.low, range.currency)),
              const SizedBox(width: 8),
              Expanded(
                child: _aralikDegeri(
                  'Orta değer',
                  range.mid,
                  range.currency,
                  vurgulu: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _aralikDegeri('Üst bant', range.high, range.currency)),
            ],
          ),
          if (range.basis.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              range.basis,
              style: const TextStyle(
                color: Color(0xFF8CA6BA),
                height: 1.4,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _senaryoKarti(TrendSenaryosu s) {
    final renk = _senaryoRengi(s.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: _panelDekorasyon(renk.withOpacity(0.35)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: renk.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '%${s.probability}',
              style: TextStyle(
                color: renk,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  s.description,
                  style: const TextStyle(
                    color: Color(0xFF91A9BC),
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: s.probability / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF1B334A),
                    valueColor: AlwaysStoppedAnimation<Color>(renk),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sinyalKarti(TrendSinyali s) {
    final renk = _sinyalRengi(s.type);
    final icon = s.type == 'positive'
        ? Icons.trending_up_rounded
        : s.type == 'negative'
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: _panelDekorasyon(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: renk.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: renk, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${_seviyeMetni(s.weight)} • %${s.weight}',
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                if (s.detail.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    s.detail,
                    style: const TextStyle(
                      color: Color(0xFF91A9BC),
                      height: 1.4,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _maddeListesi(IconData icon, String baslik, List<String> maddeler) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detayBasligi(icon, baslik),
          const SizedBox(height: 10),
          ...maddeler.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: Color(0xFF6EE7F9)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      m,
                      style: const TextStyle(
                        color: Color(0xFFA9C0D3),
                        height: 1.42,
                        fontSize: 12,
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

  Widget _kaynakSatiri(TrendKaynagi kaynak) {
    return Container(
      margin: const EdgeInsets.only(top: 9),
      decoration: _panelDekorasyon(),
      child: ListTile(
        onTap: () => _kaynagiAc(kaynak),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF15314A),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.article_outlined,
            color: Color(0xFF7DD3FC),
            size: 19,
          ),
        ),
        title: Text(
          _temizMetin(kaynak.title),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFDCECF7),
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            _temizMetin(kaynak.publisher),
            if (kaynak.publishedAt != null) _tarihMetni(kaynak.publishedAt!),
          ].where((e) => e.isNotEmpty).join(' • '),
          style: const TextStyle(color: Color(0xFF6F8BA3), fontSize: 10.5),
        ),
        trailing: const Icon(
          Icons.open_in_new_rounded,
          color: Color(0xFF6EE7F9),
          size: 19,
        ),
      ),
    );
  }

  Future<void> _kaynagiAc(TrendKaynagi kaynak) async {
    final uri = Uri.tryParse(kaynak.url);
    if (uri == null || !uri.hasScheme) {
      _mesajGoster('Kaynak bağlantısı geçerli değil.');
      return;
    }
    final acildi =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi) _mesajGoster('Kaynak açılamadı.');
  }

  Widget _miniIstatistikKarti({
    required String baslik,
    required String deger,
    required String aciklama,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _panelDekorasyon(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF7DD3FC)),
          const SizedBox(height: 9),
          Text(
            baslik,
            style: const TextStyle(color: Color(0xFF7F9AAF), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            deger,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            aciklama,
            style: const TextStyle(color: Color(0xFF6F8AA1), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _detayBasligi(IconData icon, String baslik) => Row(
        children: [
          Icon(icon, color: const Color(0xFF6EE7F9), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              baslik,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );

  Widget _etiket(String metin, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF132C43),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF1C4260)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8FB5D0), size: 13),
            const SizedBox(width: 4),
            Text(
              metin,
              style: const TextStyle(
                color: Color(0xFF9EB9CD),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _skorRozeti(int skor) {
    final renk = _skorRengi(skor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withOpacity(0.32)),
      ),
      child: Text(
        '$skor',
        style: TextStyle(
          color: renk,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _aralikDegeri(
    String baslik,
    double? deger,
    String? para, {
    bool vurgulu = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: vurgulu ? const Color(0xFF153B4F) : const Color(0xFF0A1928),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: vurgulu ? const Color(0xFF2B7184) : const Color(0xFF1A344A),
        ),
      ),
      child: Column(
        children: [
          Text(
            baslik,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7893AA), fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Text(
            _paraMetni(deger, para),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: vurgulu ? const Color(0xFF6EE7F9) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kapsamKarti() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDekorasyon(),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.dataset_outlined, color: Color(0xFF7DD3FC)),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'Bu ekran artık telefonda Google Haberler RSS saymaz. '
                'Sorular doğrudan Trendora backend motoruna gider; canlı web '
                'araştırması, senaryo olasılıkları, güven puanı, riskler, '
                'eksik veriler ve kaynaklar birlikte gösterilir.',
                style: TextStyle(
                  color: Color(0xFF8CA6BA),
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _uyariKarti({String? metin}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171E2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3C465A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24)),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                metin?.trim().isNotEmpty == true
                    ? metin!
                    : 'Bu ekran yatırım, kredi, satın alma veya satış emri '
                        'vermez. Sonuçlar olasılık analizidir; kesinlik ya da '
                        'kazanç garantisi içermez.',
                style: const TextStyle(
                  color: Color(0xFFC7CFDB),
                  height: 1.45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bolumBasligi(String baslik, String altBaslik) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            altBaslik,
            style: const TextStyle(color: Color(0xFF7993AB), fontSize: 12.5),
          ),
        ],
      );

  Widget _ikonKutusu(IconData icon, double boyut) => Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14B8A6), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white),
      );

  Widget _kareButon(IconData icon, VoidCallback? onPressed) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF10243B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF1C3958)),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(icon, color: const Color(0xFFB7D4EE), size: 21),
        ),
      );

  Widget _canliNokta() => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFF4ADE80),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.65),
              blurRadius: 8,
            ),
          ],
        ),
      );

  Widget _bosKategoriKarti() => Container(
        padding: const EdgeInsets.all(24),
        decoration: _panelDekorasyon(),
        child: const Column(
          children: [
            Icon(Icons.search_off_outlined, color: Color(0xFF7D9AB1), size: 44),
            SizedBox(height: 12),
            Text(
              'Bu kategoride gösterilecek analiz bulunamadı.',
              style: TextStyle(color: Color(0xFFA3B8C9)),
            ),
          ],
        ),
      );

  Widget _yukleniyorAlani() => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: _panelDekorasyon(),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF6EE7F9)),
              SizedBox(height: 18),
              Text(
                'Trendora motoru çalışıyor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Kaynaklar, sinyaller ve olasılıklar karşılaştırılıyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8EA7BA)),
              ),
            ],
          ),
        ),
      );

  Widget _hataAlani() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: Color(0xFF8AA7BC),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _hataMesaji ?? 'Bilinmeyen bir hata oluştu.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB6CAD9)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _yenileniyor ? null : _trendleriGetir,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );

  BoxDecoration _panelDekorasyon([Color? border]) => BoxDecoration(
        color: const Color(0xFF0E2135),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border ?? const Color(0xFF193A57)),
      );

  Color _skorRengi(int skor) {
    if (skor >= 75) return const Color(0xFF34D399);
    if (skor >= 50) return const Color(0xFF38BDF8);
    return const Color(0xFFA78BFA);
  }

  Color _sinyalRengi(String type) {
    if (type == 'positive') return const Color(0xFF34D399);
    if (type == 'negative') return const Color(0xFFF87171);
    return const Color(0xFF38BDF8);
  }

  Color _senaryoRengi(String name) {
    final n = name.toLowerCase();
    if (n.contains('olumlu') || n.contains('yüksel')) {
      return const Color(0xFF34D399);
    }
    if (n.contains('olumsuz') || n.contains('düş')) {
      return const Color(0xFFF87171);
    }
    return const Color(0xFF38BDF8);
  }

  String _guvenMetni(int skor) {
    if (skor >= 75) return 'Yüksek güven';
    if (skor >= 50) return 'Orta güven';
    return 'Sınırlı güven';
  }

  String _sonGuncellemeMetni() {
    final t = _sonGuncelleme?.toLocal();
    if (t == null) return 'Henüz güncellenmedi';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String _tarihMetni(DateTime tarih) {
    final t = tarih.toLocal();
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.${t.year} • '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String _paraMetni(double? value, String? currency) {
    if (value == null) return '-';

    // API hangi sayısal değeri döndürdüyse onu koru; tam sayıya yuvarlama yapma.
    // 399.75 -> 399,75 TL | 400.0 -> 400 TL | 6215.54 -> 6.215,54 TL
    final isWhole = value == value.truncateToDouble();
    var raw = value.toStringAsFixed(isWhole ? 0 : 2);
    final parts = raw.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    var formatted = integerPart;
    if (parts.length > 1) {
      var decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');
      if (decimals.isNotEmpty) formatted = '$integerPart,$decimals';
    }

    return currency == null || currency == 'TRY'
        ? '$formatted TL'
        : '$formatted $currency';
  }


  Future<http.Response> _getWithWarmup(Uri uri) async {
    try {
      return await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      // Render ilk istekte uyanıyorsa kısa bir ikinci deneme yap.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 45));
    }
  }

  String _normalizeQuery(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  String _soruyuZenginlestir(String value) {
    final original = value.trim();
    if (original.isEmpty) return original;

    final normalized = _normalizeQuery(original)
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9.]'), '');

    const aliases = <String, Map<String, String>>{
      'bimas': {'symbol': 'BIMAS', 'name': 'BİM Mağazalar A.Ş.'},
      'bim': {'symbol': 'BIMAS', 'name': 'BİM Mağazalar A.Ş.'},
      'bim as': {'symbol': 'BIMAS', 'name': 'BİM Mağazalar A.Ş.'},
      'asels': {'symbol': 'ASELS', 'name': 'ASELSAN'},
      'aselsan': {'symbol': 'ASELS', 'name': 'ASELSAN'},
      'tuprs': {'symbol': 'TUPRS', 'name': 'Tüpraş'},
      'tupras': {'symbol': 'TUPRS', 'name': 'Tüpraş'},
      'thyao': {'symbol': 'THYAO', 'name': 'Türk Hava Yolları'},
      'thy': {'symbol': 'THYAO', 'name': 'Türk Hava Yolları'},
      'eregl': {'symbol': 'EREGL', 'name': 'Ereğli Demir Çelik'},
      'kchol': {'symbol': 'KCHOL', 'name': 'Koç Holding'},
      'sise': {'symbol': 'SISE', 'name': 'Şişecam'},
      'garan': {'symbol': 'GARAN', 'name': 'Garanti BBVA'},
      'isctr': {'symbol': 'ISCTR', 'name': 'Türkiye İş Bankası C'},
      'akbnk': {'symbol': 'AKBNK', 'name': 'Akbank'},
      'froto': {'symbol': 'FROTO', 'name': 'Ford Otosan'},
      'toaso': {'symbol': 'TOASO', 'name': 'Tofaş'},
      'tcell': {'symbol': 'TCELL', 'name': 'Turkcell'},
      'sahol': {'symbol': 'SAHOL', 'name': 'Sabancı Holding'},
      'enjsa': {'symbol': 'ENJSA', 'name': 'Enerjisa Enerji'},
      'astor': {'symbol': 'ASTOR', 'name': 'Astor Enerji'},
      'altin.s1': {'symbol': 'ALTIN.S1', 'name': 'Darphane Altın Sertifikası'},
      'altins1': {'symbol': 'ALTIN.S1', 'name': 'Darphane Altın Sertifikası'},
      'altin s1': {'symbol': 'ALTIN.S1', 'name': 'Darphane Altın Sertifikası'},
    };

    Map<String, String>? matched;
    String? matchedAlias;

    for (final entry in aliases.entries) {
      final alias = entry.key;
      final pattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(alias)}([^a-z0-9]|\$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(normalized) || compact == alias.replaceAll(' ', '')) {
        matched = entry.value;
        matchedAlias = alias;
        break;
      }
    }

    // Kullanıcı BIMAS, BIMAS son 30 günlük hareketi, BIMAS ne olur gibi
    // doğal cümleler yazabilir. Sembolü cümlenin herhangi bir yerinde yakala.
    if (matched == null) {
      final tickerMatch = RegExp(r'\b([A-Za-zÇĞİÖŞÜçğıöşü]{4,6}(?:\.S1)?)\b')
          .allMatches(original)
          .map((m) => (m.group(1) ?? '').toUpperCase())
          .firstWhere(
            (token) => !const {
              'BUGÜN', 'YARIN', 'NASIL', 'NEDİR', 'HAREKET', 'GÜNLÜK',
              'HAFTALIK', 'AYLIK', 'FİYAT', 'SONUÇ', 'ANALİZ', 'YÜKSEL',
              'DÜŞER', 'GEÇEN', 'ÖNÜMÜZDEKİ'
            }.contains(token),
            orElse: () => '',
          );

      if (tickerMatch.isNotEmpty) {
        matched = {
          'symbol': tickerMatch,
          'name': tickerMatch == 'ALTIN.S1'
              ? 'Darphane Altın Sertifikası'
              : '$tickerMatch Borsa İstanbul sermaye piyasası aracı',
        };
      }
    }

    if (matched == null) return original;

    final symbol = matched['symbol']!;
    final name = matched['name']!;
    var userRequest = original;

    // Kullanıcının doğal ifadesini koru; sadece sisteme bağlam ekle.
    if (matchedAlias != null && original.toLowerCase() == matchedAlias) {
      userRequest = '$symbol güncel durumu ve olasılık analizi';
    }

    final horizon = RegExp(
      r'(son|önümüzdeki)?\s*(\d+)\s*(günlük|gün|haftalık|hafta|aylık|ay|yıllık|yıl)',
      caseSensitive: false,
    ).firstMatch(original);
    final horizonText = horizon?.group(0)?.trim();

    return [
      'Finansal araç: $name ($symbol).',
      if (horizonText != null && horizonText.isNotEmpty)
        'İstenen dönem: $horizonText.',
      'Kullanıcının asıl sorusu: "$userRequest".',
      'Bunu arama sonucu özeti gibi değil; güncel fiyat, dönemsel fiyat hareketi, hacim/oynaklık, temel ve haber akışı verilerini araştırıp istatistiksel olarak değerlendirerek; senaryo ve olasılık hesaplayarak yanıtla.',
      'Fiyatları kaynaktaki kesin ondalık değerleriyle göster; yuvarlama yapma.',
    ].join(' ');
  }

  String _temizMetin(String value) {
    var text = value;
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    return text.trim();
  }

  void _mesajGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mesaj), behavior: SnackBarBehavior.floating),
      );
  }

  void _hataGoster(String mesaj) {
    if (!mounted) return;
    setState(() {
      _hataMesaji = mesaj;
      _yukleniyor = false;
      _yenileniyor = false;
    });
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    _animasyonKontrolcusu.dispose();
    _soruKontrolcusu.dispose();
    _soruOdakNoktasi.dispose();
    super.dispose();
  }
}

class TrendAnalizi {
  final String query;
  final String domain;
  final String category;
  final String intent;
  final String answerTitle;
  final String directAnswer;
  final String summary;
  final TahminiAralik estimatedRange;
  final GunlukFiyat dailyPrice;
  final YillikFiyat yearlyPrice;
  final TrendIstatistikleri statistics;
  final List<TrendSenaryosu> scenarios;
  final int confidence;
  final String confidenceLabel;
  final List<TrendSinyali> signals;
  final List<String> keyFactors;
  final List<String> missingInformation;
  final List<String> nextChecks;
  final List<TrendKaynagi> sources;
  final String disclaimer;

  const TrendAnalizi({
    required this.query,
    required this.domain,
    required this.category,
    required this.intent,
    required this.answerTitle,
    required this.directAnswer,
    required this.summary,
    required this.estimatedRange,
    required this.dailyPrice,
    required this.yearlyPrice,
    required this.statistics,
    required this.scenarios,
    required this.confidence,
    required this.confidenceLabel,
    required this.signals,
    required this.keyFactors,
    required this.missingInformation,
    required this.nextChecks,
    required this.sources,
    required this.disclaimer,
  });

  factory TrendAnalizi.fromJson(Map<String, dynamic> j) {
    final confidence = _toInt(j['confidence']).clamp(0, 100);
    final query = _toText(j['query']);
    final answerTitle = _toText(j['answerTitle'], 'Trendora Analizi');
    final directAnswer = _toText(j['directAnswer']);
    final summary = _removeRepeatedSummary(
      directAnswer,
      _toText(j['summary']),
    );
    final rawDomain = _toText(j['domain'], 'general');
    final domain = _correctDomain(
      rawDomain: rawDomain,
      query: query,
      answerTitle: answerTitle,
      directAnswer: directAnswer,
    );
    final dailyPrice = GunlukFiyat.fromJson(
      _toMap(j['dailyPrice'] ?? j['daily_price']),
    );
    final yearlyPrice = YillikFiyat.fromJson(
      _toMap(j['yearlyPrice'] ?? j['yearly_price'] ?? j['weekly52']),
    );
    final statistics = TrendIstatistikleri.fromJson(
      _toMap(j['statistics'] ?? j['scores'] ?? j['metrics']),
      fallbackConfidence: confidence,
    );
    final scenarios = _normalizeScenarios(
      _toList(j['scenarios'])
          .map((e) => TrendSenaryosu.fromJson(_toMap(e)))
          .toList(),
    );
    var estimatedRange = _normalizeRange(
      TahminiAralik.fromJson(_toMap(j['estimatedRange'])),
      '$directAnswer $summary',
    );

    // Backend aralık alanını boş bıraksa bile finans analizlerinde kartı kaybetme.
    // Doğrudan sonuçtaki güncel fiyatı orta değer, senaryolardaki açık TL
    // hedeflerini alt/üst bant olarak kullanır. Değerleri yuvarlamaz.
    estimatedRange = _rangeFromFinancialTextIfMissing(
      range: estimatedRange,
      domain: domain,
      query: query,
      directAnswer: directAnswer,
      scenarios: scenarios,
    );

    return TrendAnalizi(
      query: query,
      domain: domain,
      category: _toText(j['category'], 'Genel Analiz'),
      intent: _toText(j['intent'], 'general_analysis'),
      answerTitle: answerTitle,
      directAnswer: directAnswer,
      summary: summary,
      estimatedRange: estimatedRange,
      dailyPrice: dailyPrice,
      yearlyPrice: yearlyPrice,
      statistics: statistics,
      scenarios: scenarios,
      confidence: confidence,
      confidenceLabel: _toText(
        j['confidenceLabel'],
        confidence >= 75 ? 'Yüksek' : confidence >= 50 ? 'Orta' : 'Düşük',
      ),
      signals: _dedupeSignals(
        _toList(j['signals'])
            .map((e) => TrendSinyali.fromJson(_toMap(e)))
            .toList(),
      ),
      keyFactors: _dedupeStrings(_toStringList(j['keyFactors'])),
      missingInformation: _dedupeStrings(
        _toStringList(j['missingInformation']),
      ),
      nextChecks: _dedupeStrings(_toStringList(j['nextChecks'])),
      sources: _dedupeSources(
        _toList(j['sources'])
            .map((e) => TrendKaynagi.fromJson(_toMap(e)))
            .where((e) => e.url.isNotEmpty)
            .toList(),
      ),
      disclaimer: _toText(
        j['disclaimer'],
        'Bu sonuç açık verilerden üretilen olasılık analizidir.',
      ),
    );
  }

  String get uygulamaKategorisi {
    switch (domain) {
      case 'finance':
        return 'Finans';
      case 'real_estate':
        return 'Emlak';
      case 'vehicle':
        return 'Araç';
      case 'product':
        return 'Ürün';
      case 'travel':
        return 'Seyahat';
      case 'business':
        return 'İş';
      default:
        return 'Genel';
    }
  }

  IconData get icon {
    switch (domain) {
      case 'finance':
        return Icons.show_chart_rounded;
      case 'real_estate':
        return Icons.apartment_rounded;
      case 'vehicle':
        return Icons.directions_car_outlined;
      case 'product':
        return Icons.devices_outlined;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'business':
        return Icons.storefront_outlined;
      default:
        return Icons.analytics_outlined;
    }
  }
}

class GunlukFiyat {
  final double? open;
  final double? high;
  final double? low;
  final double? current;
  final double? average;
  final double? vwap;
  final double? close;
  final double? previousClose;
  final double? change;
  final double? changePercent;
  final double? volume;
  final String? currency;

  const GunlukFiyat({
    required this.open,
    required this.high,
    required this.low,
    required this.current,
    required this.average,
    required this.vwap,
    required this.close,
    required this.previousClose,
    required this.change,
    required this.changePercent,
    required this.volume,
    required this.currency,
  });

  factory GunlukFiyat.fromJson(Map<String, dynamic> j) => GunlukFiyat(
        open: _toDouble(j['open'] ?? j['opening']),
        high: _toDouble(j['high'] ?? j['dailyHigh']),
        low: _toDouble(j['low'] ?? j['dailyLow']),
        current: _toDouble(j['current'] ?? j['regularMarketPrice']),
        average: _toDouble(j['average'] ?? j['avg'] ?? j['dailyAverage']),
        vwap: _toDouble(j['vwap'] ?? j['weightedAverage']),
        close: _toDouble(j['close'] ?? j['closing']),
        previousClose: _toDouble(j['previousClose']),
        change: _toDouble(j['change']),
        changePercent: _toDouble(j['changePercent']),
        volume: _toDouble(j['volume']),
        currency: _toNullableText(j['currency']),
      );

  bool get available =>
      open != null || high != null || low != null || current != null ||
      average != null || vwap != null || close != null;
}

class YillikFiyat {
  final double? low52w;
  final double? average52w;
  final double? high52w;
  final String? currency;

  const YillikFiyat({
    required this.low52w,
    required this.average52w,
    required this.high52w,
    required this.currency,
  });

  factory YillikFiyat.fromJson(Map<String, dynamic> j) => YillikFiyat(
        low52w: _toDouble(j['low52w'] ?? j['low'] ?? j['week52Low']),
        average52w: _toDouble(j['average52w'] ?? j['average'] ?? j['avg52w']),
        high52w: _toDouble(j['high52w'] ?? j['high'] ?? j['week52High']),
        currency: _toNullableText(j['currency']),
      );

  bool get available => low52w != null || average52w != null || high52w != null;
}

class TrendIstatistikleri {
  final int? trendStrength;
  final int? dataConfidence;
  final int? riskScore;
  final int? newsImpact;
  final int? marketInterest;

  const TrendIstatistikleri({
    required this.trendStrength,
    required this.dataConfidence,
    required this.riskScore,
    required this.newsImpact,
    required this.marketInterest,
  });

  factory TrendIstatistikleri.fromJson(
    Map<String, dynamic> j, {
    required int fallbackConfidence,
  }) {
    int? score(dynamic value) {
      if (value == null) return null;
      return _toInt(value).clamp(0, 100);
    }

    return TrendIstatistikleri(
      trendStrength: score(j['trendStrength'] ?? j['trendScore']),
      dataConfidence: score(j['dataConfidence'] ?? j['confidence']) ??
          fallbackConfidence,
      riskScore: score(j['riskScore'] ?? j['risk']),
      newsImpact: score(j['newsImpact'] ?? j['newsScore']),
      marketInterest: score(j['marketInterest'] ?? j['interestScore']),
    );
  }

  bool get hasAny =>
      trendStrength != null ||
      dataConfidence != null ||
      riskScore != null ||
      newsImpact != null ||
      marketInterest != null;
}

class TahminiAralik {
  final bool available;
  final String? currency;
  final double? low;
  final double? mid;
  final double? high;
  final String label;
  final String basis;

  const TahminiAralik({
    required this.available,
    required this.currency,
    required this.low,
    required this.mid,
    required this.high,
    required this.label,
    required this.basis,
  });

  factory TahminiAralik.fromJson(Map<String, dynamic> j) => TahminiAralik(
        available: j['available'] == true,
        currency: j['currency']?.toString(),
        low: _toDouble(j['low']),
        mid: _toDouble(j['mid']),
        high: _toDouble(j['high']),
        label: _toText(j['label'], 'Tahmini aralık'),
        basis: _toText(j['basis']),
      );
}

class TrendSenaryosu {
  final String name;
  final int probability;
  final String description;

  const TrendSenaryosu({
    required this.name,
    required this.probability,
    required this.description,
  });

  factory TrendSenaryosu.fromJson(Map<String, dynamic> j) => TrendSenaryosu(
        name: _toText(j['name'], 'Senaryo'),
        probability: _toInt(j['probability']).clamp(0, 100),
        description: _toText(j['description']),
      );
}

class TrendSinyali {
  final String type;
  final String title;
  final String detail;
  final int weight;

  const TrendSinyali({
    required this.type,
    required this.title,
    required this.detail,
    required this.weight,
  });

  factory TrendSinyali.fromJson(Map<String, dynamic> j) {
    final raw = _toText(j['type'], 'neutral');
    return TrendSinyali(
      type: const ['positive', 'negative', 'neutral'].contains(raw)
          ? raw
          : 'neutral',
      title: _toText(j['title'], 'Sinyal'),
      detail: _toText(j['detail']),
      weight: _toInt(j['weight']).clamp(0, 100),
    );
  }
}

class TrendKaynagi {
  final String title;
  final String publisher;
  final String url;
  final DateTime? publishedAt;

  const TrendKaynagi({
    required this.title,
    required this.publisher,
    required this.url,
    required this.publishedAt,
  });

  factory TrendKaynagi.fromJson(Map<String, dynamic> j) => TrendKaynagi(
        title: _toText(j['title'], 'Kaynak'),
        publisher: _toText(
          j['publisher'] ?? j['source'],
          'Bilinmeyen kaynak',
        ),
        url: _toText(j['url'] ?? j['link']),
        publishedAt:
            DateTime.tryParse(_toText(j['publishedAt'])),
      );
}


List<TrendSenaryosu> _normalizeScenarios(List<TrendSenaryosu> items) {
  if (items.isEmpty) return items;
  final total = items.fold<int>(0, (sum, e) => sum + e.probability);
  if (total == 100 || total <= 0) return items;

  final normalized = <TrendSenaryosu>[];
  var used = 0;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final probability = i == items.length - 1
        ? 100 - used
        : ((item.probability / total) * 100).round().clamp(0, 100);
    used += probability;
    normalized.add(TrendSenaryosu(
      name: item.name,
      probability: probability,
      description: item.description,
    ));
  }
  return normalized;
}

TahminiAralik _rangeFromFinancialTextIfMissing({
  required TahminiAralik range,
  required String domain,
  required String query,
  required String directAnswer,
  required List<TrendSenaryosu> scenarios,
}) {
  // Backend geçerli bir aralık verdiyse aynen koru. Mid alanı finans
  // ekranında ortalama değil güncel fiyat olarak kullanılabilir.
  if (range.available &&
      range.low != null &&
      range.mid != null &&
      range.high != null) {
    return range;
  }
  if (domain != 'finance') return range;

  final allDirectValues = _extractTlValues(directAnswer);
  if (allDirectValues.isEmpty) return range;

  final current = _extractCurrentPrice(directAnswer) ?? allDirectValues.first;
  final requestedPeriod = _requestedPeriodLabel(query);
  final requestedRange = _extractRequestedPeriodRange(
    directAnswer,
    requestedPeriod,
  );

  if (requestedRange != null) {
    return TahminiAralik(
      available: true,
      currency: 'TRY',
      low: requestedRange.$1,
      mid: current,
      high: requestedRange.$2,
      label: '$requestedPeriod Fiyat Aralığı',
      basis: 'Alt ve üst bant istenen dönemin gerçekleşen aralığıdır; orta kutuda güncel fiyat gösterilir.',
    );
  }

  final week52 = _extract52WeekRange(directAnswer);
  if (week52 != null) {
    return TahminiAralik(
      available: true,
      currency: 'TRY',
      low: week52.$1,
      mid: current,
      high: week52.$2,
      label: '52 Haftalık Fiyat Aralığı',
      basis: 'Alt ve üst bant 52 haftalık aralıktır; orta kutuda güncel fiyat gösterilir.',
    );
  }

  final scenarioValues = <double>[];
  for (final scenario in scenarios) {
    scenarioValues.addAll(_extractTlValues(scenario.description));
  }

  final candidates = <double>[current, ...scenarioValues]
      .where((value) => value > 0)
      .toSet()
      .toList()
    ..sort();

  if (candidates.length >= 2) {
    return TahminiAralik(
      available: true,
      currency: 'TRY',
      low: candidates.first,
      mid: current,
      high: candidates.last,
      label: 'Analiz Fiyat Aralığı',
      basis: 'Güncel fiyat ile analizde açıkça belirtilen senaryo seviyeleri kullanılmıştır.',
    );
  }

  // Aralık verisi bulunamazsa fiyat bölümü kaybolmasın. Güncel fiyatı
  // üç kutuya çoğaltmak yerine tek değeri açıkça güncel fiyat olarak göster.
  return TahminiAralik(
    available: true,
    currency: 'TRY',
    low: null,
    mid: current,
    high: null,
    label: 'Güncel Fiyat',
    basis: 'Kaynaklarda güvenilir alt ve üst bant bulunamadığı için yalnızca kesin güncel fiyat gösterilmiştir.',
  );
}

double? _extractNamedTlValue(String text, List<String> labels) {
  for (final label in labels) {
    final escaped = RegExp.escape(label);
    final patterns = <RegExp>[
      RegExp(
        '$escaped[^\\d]{0,25}(\\d{1,3}(?:[.\\s]\\d{3})*(?:,\\d+)?|\\d+(?:[.,]\\d+)?)\\s*TL',
        caseSensitive: false,
      ),
      RegExp(
        '(\\d{1,3}(?:[.\\s]\\d{3})*(?:,\\d+)?|\\d+(?:[.,]\\d+)?)\\s*TL[^.\\n]{0,25}$escaped',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = _toDouble(match?.group(1));
      if (value != null) return value;
    }
  }
  return null;
}

(double, double)? _extractDailyPriceRange(String text) {
  final patterns = <RegExp>[
    RegExp(
      r'(?:günlük|gün içi|bugünkü)[^\d]{0,55}(?:fiyat )?(?:aralığı|düşük[^\d]{0,15}yüksek)[^\d]{0,30}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL[^\d]{0,40}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:günlük|gün içi|bugünkü)[^.\n]{0,120}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL\s*(?:ile|-|–)\s*(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final first = _toDouble(match.group(1));
    final second = _toDouble(match.group(2));
    if (first == null || second == null) continue;
    return first <= second ? (first, second) : (second, first);
  }
  return null;
}

String _buildPointAnalysis({
  required double? current,
  required (double, double)? week52,
  required int confidence,
  required List<TrendSenaryosu> scenarios,
}) {
  final parts = <String>[];
  if (current != null && week52 != null && week52.$2 > week52.$1) {
    final position = ((current - week52.$1) / (week52.$2 - week52.$1) * 100)
        .clamp(0, 100);
    final toHigh = ((week52.$2 - current) / current * 100);
    final fromLow = ((current - week52.$1) / week52.$1 * 100);
    final zone = position < 35
        ? 'alt bölgesinde'
        : position > 65
            ? 'üst bölgesinde'
            : 'orta bölgesinde';
    parts.add(
      'Güncel fiyat, 52 haftalık bandın %${position.toStringAsFixed(1).replaceAll('.', ',')} seviyesinde ve bandın $zone bulunuyor. 52 haftalık yüksek değere uzaklığı yaklaşık %${toHigh.abs().toStringAsFixed(1).replaceAll('.', ',')}; düşük değerin üzerindeki mesafesi ise %${fromLow.abs().toStringAsFixed(1).replaceAll('.', ',')}.',
    );
  } else {
    parts.add(
      '52 haftalık düşük, yüksek veya güncel fiyat verilerinden biri eksik olduğu için fiyatın uzun dönem bandındaki kesin konumu hesaplanamadı.',
    );
  }

  if (scenarios.isNotEmpty) {
    final dominant = scenarios.reduce(
      (a, b) => a.probability >= b.probability ? a : b,
    );
    parts.add(
      'Senaryo dağılımında en yüksek ağırlık %${dominant.probability} ile “${dominant.name}” seçeneğinde. Analizin genel veri güveni %$confidence seviyesinde.',
    );
  } else {
    parts.add('Analizin genel veri güveni %$confidence seviyesinde.');
  }
  return parts.join(' ');
}

(double, double)? _extract52WeekRange(String text) {
  final pattern = RegExp(
    r'52\s*haftal[ıi]k[^\d]{0,80}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL[^\d]{0,40}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final first = _toDouble(match.group(1));
  final second = _toDouble(match.group(2));
  if (first == null || second == null) return null;
  return first <= second ? (first, second) : (second, first);
}

double? _extractCurrentPrice(String text) {
  final patterns = <RegExp>[
    RegExp(
      r'(?:güncel|son|şu anki|mevcut)[^\d]{0,35}(?:fiyat[ıi]?|değer[ıi]?)?[^\d]{0,20}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:işlem görmektedir|seviyesindedir|fiyatı)[^\d]{0,20}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    final value = _toDouble(match?.group(1));
    if (value != null) return value;
  }
  return null;
}

List<double> _extractTlValues(String text) {
  final values = <double>[];
  final matches = RegExp(
    r'(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL\b',
    caseSensitive: false,
  ).allMatches(text);

  for (final match in matches) {
    final raw = match.group(1);
    final value = _toDouble(raw);
    if (value != null && value.isFinite) values.add(value);
  }
  return values;
}

TahminiAralik _normalizeRange(TahminiAralik range, String referenceText) {
  if (!range.available) return range;

  // Sayıları büyütme/küçültme tahmini yapma. API'nin döndürdüğü kesin
  // değeri aynen koru. Önceki sürümde piyasa değeri gibi büyük bir sayı
  // referans alındığı için 72,15 TL yanlışlıkla 72.150.000.000 TL olabiliyordu.
  final low = range.low;
  final mid = range.mid;
  final high = range.high;

  double? safeLow = low;
  double? safeHigh = high;
  if (low != null && high != null && low > high) {
    safeLow = high;
    safeHigh = low;
  }

  return TahminiAralik(
    available: range.available,
    currency: range.currency,
    low: safeLow,
    mid: mid,
    high: safeHigh,
    label: range.label,
    basis: range.basis,
  );
}

double? _extractLargestNumber(String text) {
  final matches = RegExp(r'\d{1,3}(?:[.\s]\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?')
      .allMatches(text);
  double? largest;
  for (final match in matches) {
    final raw = match.group(0);
    final value = _toDouble(raw);
    if (value != null && (largest == null || value > largest)) largest = value;
  }
  return largest;
}


String _correctDomain({
  required String rawDomain,
  required String query,
  required String answerTitle,
  required String directAnswer,
}) {
  final text = '$query $answerTitle $directAnswer'.toLowerCase();
  final compactQuery = query.trim().toUpperCase().replaceAll(' ', '');
  final looksLikeTicker = RegExp(r'^[A-Z]{3,6}(?:\.S1)?$').hasMatch(compactQuery);
  final financeWords = RegExp(
    r'\b(hisse|borsa|bist|fiyat|tl|lot|hacim|piyasa değeri|fk|pd/dd|temettü|altın\.s1|altins1)\b',
    caseSensitive: false,
  ).hasMatch(text);
  if (looksLikeTicker || financeWords) return 'finance';
  return rawDomain;
}

String _removeRepeatedSummary(String directAnswer, String summary) {
  if (summary.isEmpty) return '';
  final a = _comparisonText(directAnswer);
  final b = _comparisonText(summary);
  if (a.isEmpty || b.isEmpty) return summary;
  if (a == b || a.contains(b) || b.contains(a)) return '';

  final aWords = a.split(' ').toSet();
  final bWords = b.split(' ').toSet();
  if (bWords.isEmpty) return summary;
  final overlap = bWords.where(aWords.contains).length / bWords.length;
  return overlap >= 0.82 ? '' : summary;
}

String _comparisonText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'https?://\S+'), '')
    .replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _dedupeStrings(List<String> items) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in items) {
    final key = _comparisonText(item);
    if (key.isNotEmpty && seen.add(key)) result.add(item);
  }
  return result;
}

List<TrendSinyali> _dedupeSignals(List<TrendSinyali> items) {
  final seen = <String>{};
  final result = <TrendSinyali>[];
  for (final item in items) {
    final key = _comparisonText('${item.title} ${item.detail}');
    if (key.isNotEmpty && seen.add(key)) result.add(item);
  }
  return result;
}

List<TrendKaynagi> _dedupeSources(List<TrendKaynagi> items) {
  final seen = <String>{};
  final result = <TrendKaynagi>[];
  for (final item in items) {
    final key = item.url.trim().toLowerCase().isNotEmpty
        ? item.url.trim().toLowerCase()
        : _comparisonText('${item.publisher} ${item.title}');
    if (seen.add(key)) result.add(item);
  }
  return result;
}

String _requestedPeriodLabel(String query) {
  final q = query.toLowerCase();
  if (RegExp(r'\b(30\s*gün|son\s*30\s*gün|1\s*ay|bir\s*ay|aylık)\b').hasMatch(q)) {
    return 'Son 30 Günlük';
  }
  if (RegExp(r'\b(7\s*gün|son\s*7\s*gün|1\s*hafta|bir\s*hafta|haftalık)\b').hasMatch(q)) {
    return 'Son 7 Günlük';
  }
  if (RegExp(r'\b(3\s*ay|üç\s*ay)\b').hasMatch(q)) return 'Son 3 Aylık';
  if (RegExp(r'\b(6\s*ay|altı\s*ay)\b').hasMatch(q)) return 'Son 6 Aylık';
  if (RegExp(r'\b(1\s*yıl|bir\s*yıl|12\s*ay|yıllık)\b').hasMatch(q)) return 'Son 1 Yıllık';
  return '';
}

(double, double)? _extractRequestedPeriodRange(String text, String periodLabel) {
  if (periodLabel.isEmpty) return null;
  final periodPattern = switch (periodLabel) {
    'Son 30 Günlük' => r'(?:son\s*30\s*gün|30\s*günlük|1\s*aylık|aylık)',
    'Son 7 Günlük' => r'(?:son\s*7\s*gün|7\s*günlük|1\s*haftalık|haftalık)',
    'Son 3 Aylık' => r'(?:son\s*3\s*ay|3\s*aylık)',
    'Son 6 Aylık' => r'(?:son\s*6\s*ay|6\s*aylık)',
    'Son 1 Yıllık' => r'(?:son\s*1\s*yıl|1\s*yıllık|12\s*aylık)',
    _ => '',
  };
  if (periodPattern.isEmpty) return null;

  final pattern = RegExp(
    '$periodPattern' r'[^\d]{0,100}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL[^\d]{0,60}(\d{1,3}(?:[.\s]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)\s*TL',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final first = _toDouble(match.group(1));
  final second = _toDouble(match.group(2));
  if (first == null || second == null) return null;
  return first <= second ? (first, second) : (second, first);
}

String? _toNullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _toText(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  var text = value.toString().trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (text.isEmpty) return null;

  if (text.contains('.') && text.contains(',')) {
    if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (text.contains(',')) {
    final parts = text.split(',');
    text = parts.length == 2 && parts.last.length <= 2
        ? text.replaceAll(',', '.')
        : text.replaceAll(',', '');
  } else if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(text)) {
    text = text.replaceAll('.', '');
  }

  return double.tryParse(text);
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _toList(dynamic value) => value is List ? value : const [];

List<String> _toStringList(dynamic value) => _toList(value)
    .map((e) => e?.toString().trim() ?? '')
    .where((e) => e.isNotEmpty)
    .toList();