import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProfesyonelGrafikSayfasi extends StatefulWidget {
  final String baslik;
  final String sorgu;
  final double? guncelFiyat;
  final double? elliIkiHaftaDusuk;
  final double? elliIkiHaftaYuksek;
  final String paraBirimi;
  final int guvenPuani;

  const ProfesyonelGrafikSayfasi({
    super.key,
    required this.baslik,
    required this.sorgu,
    required this.guncelFiyat,
    required this.elliIkiHaftaDusuk,
    required this.elliIkiHaftaYuksek,
    required this.paraBirimi,
    required this.guvenPuani,
  });

  @override
  State<ProfesyonelGrafikSayfasi> createState() =>
      _ProfesyonelGrafikSayfasiState();
}

class _ProfesyonelGrafikSayfasiState
    extends State<ProfesyonelGrafikSayfasi> {
  static const _donemler = ['1G', '1H', '1A', '3A', '6A', '1Y'];
  static const _araclar = <_CizimAraci>[
    _CizimAraci(Icons.show_chart_rounded, 'Trend'),
    _CizimAraci(Icons.horizontal_rule_rounded, 'Destek'),
    _CizimAraci(Icons.straighten_rounded, 'Fibonacci'),
    _CizimAraci(Icons.delete_sweep_outlined, 'Temizle'),
  ];

  String _seciliDonem = '3A';
  bool _emaAcik = true;
  bool _smaAcik = false;
  bool _bollingerAcik = true;
  bool _hacimAcik = true;
  bool _rsiAcik = true;
  bool _macdAcik = true;
  int? _seciliMum;
  int _seciliArac = -1;
  final List<_Cizgi> _cizgiler = [];
  Offset? _baslangic;
  Offset? _geciciBitis;
  late List<_Mum> _mumlar;

  @override
  void initState() {
    super.initState();
    _mumlariYenile();
  }

  void _mumlariYenile() {
    final adet = switch (_seciliDonem) {
      '1G' => 32,
      '1H' => 42,
      '1A' => 46,
      '3A' => 60,
      '6A' => 72,
      _ => 90,
    };
    _mumlar = _demoMumlariUret(adet);
    _seciliMum = null;
  }

  List<_Mum> _demoMumlariUret(int adet) {
    final seed = widget.sorgu.codeUnits.fold<int>(17, (a, b) => a * 31 + b);
    final random = math.Random(seed + adet);
    final current = widget.guncelFiyat ?? 100;
    final low52 = widget.elliIkiHaftaDusuk ?? current * 0.72;
    final high52 = widget.elliIkiHaftaYuksek ?? current * 1.25;
    final altSinir = math.min(low52, current * 0.68);
    final ustSinir = math.max(high52, current * 1.22);

    var close = (current * (0.82 + random.nextDouble() * 0.12))
        .clamp(altSinir, ustSinir)
        .toDouble();
    final now = DateTime.now();
    final result = <_Mum>[];

    for (var i = 0; i < adet; i++) {
      final progress = i / math.max(1, adet - 1);
      final hedef = close * (1 - progress) + current * progress;
      final oynaklik = math.max(current * 0.008, (ustSinir - altSinir) * 0.018);
      final open = close;
      close = (hedef + (random.nextDouble() - 0.48) * oynaklik)
          .clamp(altSinir, ustSinir)
          .toDouble();
      final wick = oynaklik * (0.35 + random.nextDouble());
      final high = math.max(open, close) + wick * random.nextDouble();
      final low = math.max(0.01, math.min(open, close) - wick * random.nextDouble());
      final volume = 650000 + random.nextDouble() * 4200000;
      result.add(
        _Mum(
          tarih: now.subtract(Duration(days: adet - i)),
          acilis: open,
          yuksek: high,
          dusuk: low,
          kapanis: close,
          hacim: volume,
        ),
      );
    }

    if (result.isNotEmpty && widget.guncelFiyat != null) {
      final son = result.last;
      final target = widget.guncelFiyat!;
      result[result.length - 1] = _Mum(
        tarih: son.tarih,
        acilis: son.acilis,
        yuksek: math.max(son.yuksek, target),
        dusuk: math.min(son.dusuk, target),
        kapanis: target,
        hacim: son.hacim,
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final son = _mumlar.last;
    final onceki = _mumlar.length > 1 ? _mumlar[_mumlar.length - 2] : son;
    final degisim = onceki.kapanis == 0
        ? 0.0
        : ((son.kapanis - onceki.kapanis) / onceki.kapanis) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF050C16),
      body: SafeArea(
        child: Column(
          children: [
            _ustBar(son, degisim),
            _donemCubugu(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                children: [
                  _demoUyarisi(),
                  const SizedBox(height: 10),
                  _anaGrafikKarti(),
                  if (_hacimAcik) ...[
                    const SizedBox(height: 10),
                    _gostergeKarti(
                      baslik: 'Hacim',
                      yukseklik: 118,
                      child: CustomPaint(
                        painter: _HacimPainter(_mumlar),
                      ),
                    ),
                  ],
                  if (_rsiAcik) ...[
                    const SizedBox(height: 10),
                    _gostergeKarti(
                      baslik: 'RSI (14)',
                      rozet: _rsiRozeti(),
                      yukseklik: 128,
                      child: CustomPaint(
                        painter: _RsiPainter(_mumlar),
                      ),
                    ),
                  ],
                  if (_macdAcik) ...[
                    const SizedBox(height: 10),
                    _gostergeKarti(
                      baslik: 'MACD (12, 26, 9)',
                      yukseklik: 138,
                      child: CustomPaint(
                        painter: _MacdPainter(_mumlar),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _gostergeSecici(),
                  const SizedBox(height: 12),
                  _cizimAraclari(),
                  const SizedBox(height: 12),
                  _bilgiKarti(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ustBar(_Mum son, double degisim) {
    final olumlu = degisim >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF071421),
        border: Border(bottom: BorderSide(color: Color(0xFF173149))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: const Color(0xFFC7D9E8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_fiyat(son.kapanis)}  •  ${olumlu ? '+' : ''}${degisim.toStringAsFixed(2).replaceAll('.', ',')}%',
                  style: TextStyle(
                    color: olumlu
                        ? const Color(0xFF5DE2A5)
                        : const Color(0xFFFF7D87),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2638),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF23516B)),
            ),
            child: Text(
              'Güven ${widget.guvenPuani}',
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Tam ekran',
            onPressed: () => _mesaj('Grafik zaten tam ekran görünümünde.'),
            icon: const Icon(Icons.fullscreen_rounded),
            color: const Color(0xFF8FB9D4),
          ),
        ],
      ),
    );
  }

  Widget _donemCubugu() {
    return Container(
      height: 48,
      color: const Color(0xFF081725),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: _donemler.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final donem = _donemler[index];
          final secili = donem == _seciliDonem;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _seciliDonem = donem;
                _mumlariYenile();
                _cizgiler.clear();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: secili
                    ? const Color(0xFF156B8A)
                    : const Color(0xFF102235),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: secili
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF1A3851),
                ),
              ),
              child: Text(
                donem,
                style: TextStyle(
                  color: secili ? Colors.white : const Color(0xFF91A9BC),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _demoUyarisi() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2110),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF6A5018)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Color(0xFFFFD166), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ön izleme: Mum geçmişi şimdilik demo olarak üretiliyor. Güncel fiyat varsa son mumda korunur.',
              style: TextStyle(
                color: Color(0xFFFFDEA0),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anaGrafikKarti() {
    final secili = _seciliMum == null ? null : _mumlar[_seciliMum!];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071522),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF193A52)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.candlestick_chart_rounded,
                  color: Color(0xFF6EE7F9),
                  size: 19,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Mum Grafiği',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  _seciliDonem,
                  style: const TextStyle(
                    color: Color(0xFF7291A8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (secili != null) _mumBilgisi(secili),
          SizedBox(
            height: 330,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  if (_seciliArac >= 0) return;
                  final index = ((details.localPosition.dx / constraints.maxWidth) *
                          _mumlar.length)
                      .floor()
                      .clamp(0, _mumlar.length - 1);
                  setState(() => _seciliMum = index);
                },
                onPanStart: (details) {
                  if (_seciliArac < 0 || _seciliArac == 3) return;
                  setState(() {
                    _baslangic = details.localPosition;
                    _geciciBitis = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  if (_baslangic == null) return;
                  setState(() => _geciciBitis = details.localPosition);
                },
                onPanEnd: (_) {
                  if (_baslangic == null || _geciciBitis == null) return;
                  setState(() {
                    _cizgiler.add(
                      _Cizgi(
                        baslangic: _oransal(_baslangic!, constraints.biggest),
                        bitis: _oransal(_geciciBitis!, constraints.biggest),
                        tur: _seciliArac,
                      ),
                    );
                    _baslangic = null;
                    _geciciBitis = null;
                  });
                },
                child: CustomPaint(
                  painter: _MumGrafikPainter(
                    mumlar: _mumlar,
                    emaAcik: _emaAcik,
                    smaAcik: _smaAcik,
                    bollingerAcik: _bollingerAcik,
                    seciliIndex: _seciliMum,
                    cizgiler: _cizgiler,
                    geciciBaslangic: _baslangic,
                    geciciBitis: _geciciBitis,
                    geciciTur: _seciliArac,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _lejant(const Color(0xFF5DE2A5), 'Yükseliş'),
                const SizedBox(width: 10),
                _lejant(const Color(0xFFFF6F7D), 'Düşüş'),
                const Spacer(),
                const Icon(Icons.touch_app_outlined,
                    size: 15, color: Color(0xFF607F96)),
                const SizedBox(width: 4),
                const Text(
                  'Muma dokun',
                  style: TextStyle(color: Color(0xFF607F96), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mumBilgisi(_Mum mum) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2031),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 5,
        children: [
          _miniDeger('A', mum.acilis),
          _miniDeger('Y', mum.yuksek),
          _miniDeger('D', mum.dusuk),
          _miniDeger('K', mum.kapanis),
          Text(
            '${mum.tarih.day.toString().padLeft(2, '0')}.${mum.tarih.month.toString().padLeft(2, '0')}.${mum.tarih.year}',
            style: const TextStyle(color: Color(0xFF7D99AE), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _miniDeger(String label, double value) => Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: Color(0xFF6F8DA3)),
            ),
            TextSpan(
              text: _sayi(value),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 10.5),
      );

  Widget _gostergeKarti({
    required String baslik,
    required double yukseklik,
    required Widget child,
    String? rozet,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071522),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF193A52)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 5),
            child: Row(
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Color(0xFFDCECF7),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                if (rozet != null)
                  Text(
                    rozet,
                    style: const TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: yukseklik, child: child),
        ],
      ),
    );
  }

  Widget _gostergeSecici() {
    final items = <({String ad, bool deger, ValueChanged<bool> degistir})>[
      (ad: 'EMA', deger: _emaAcik, degistir: (v) => setState(() => _emaAcik = v)),
      (ad: 'SMA', deger: _smaAcik, degistir: (v) => setState(() => _smaAcik = v)),
      (ad: 'Bollinger', deger: _bollingerAcik, degistir: (v) => setState(() => _bollingerAcik = v)),
      (ad: 'Hacim', deger: _hacimAcik, degistir: (v) => setState(() => _hacimAcik = v)),
      (ad: 'RSI', deger: _rsiAcik, degistir: (v) => setState(() => _rsiAcik = v)),
      (ad: 'MACD', deger: _macdAcik, degistir: (v) => setState(() => _macdAcik = v)),
    ];

    return _panel(
      baslik: 'Göstergeler',
      icon: Icons.tune_rounded,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: items
            .map(
              (e) => FilterChip(
                selected: e.deger,
                onSelected: e.degistir,
                label: Text(e.ad),
                selectedColor: const Color(0xFF155E75),
                backgroundColor: const Color(0xFF102235),
                side: BorderSide(
                  color: e.deger
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF1D3D55),
                ),
                labelStyle: TextStyle(
                  color: e.deger ? Colors.white : const Color(0xFF90A9BC),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
                showCheckmark: false,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _cizimAraclari() {
    return _panel(
      baslik: 'Çizim araçları',
      icon: Icons.edit_road_rounded,
      child: Row(
        children: List.generate(_araclar.length, (index) {
          final arac = _araclar[index];
          final secili = _seciliArac == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == _araclar.length - 1 ? 0 : 7),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (index == 3) {
                    setState(() {
                      _cizgiler.clear();
                      _seciliArac = -1;
                    });
                    return;
                  }
                  setState(() => _seciliArac = secili ? -1 : index);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: secili
                        ? const Color(0xFF164E63)
                        : const Color(0xFF0C1D2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: secili
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF1A3850),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        arac.icon,
                        size: 18,
                        color: secili
                            ? const Color(0xFF7DD3FC)
                            : const Color(0xFF7D99AE),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        arac.ad,
                        style: TextStyle(
                          color: secili ? Colors.white : const Color(0xFF7D99AE),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _bilgiKarti() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34445A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFFFD166), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Bu ekran grafik modülünün çalışan ön izlemesidir. Gerçek geçmiş mum verisi backend uç noktası eklendiğinde aynı ekran veri kaynağı değiştirilerek kullanılacak; mevcut Trend Merkezi bozulmayacak.',
              style: TextStyle(
                color: Color(0xFFC5D0DB),
                height: 1.42,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String baslik,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF071522),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF193A52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6EE7F9), size: 18),
              const SizedBox(width: 7),
              Text(
                baslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _lejant(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Color(0xFF7993A8), fontSize: 10)),
        ],
      );

  String _rsiRozeti() {
    final values = _rsi(_mumlar.map((e) => e.kapanis).toList(), 14);
    final value = values.isEmpty ? 50.0 : values.last;
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  Offset _oransal(Offset point, Size size) => Offset(
        (point.dx / math.max(1, size.width)).clamp(0.0, 1.0),
        (point.dy / math.max(1, size.height)).clamp(0.0, 1.0),
      );

  String _fiyat(double value) => '${_sayi(value)} ${widget.paraBirimi == 'TRY' ? 'TL' : widget.paraBirimi}';

  String _sayi(double value) {
    final raw = value.toStringAsFixed(value.abs() >= 1000 ? 2 : 3);
    final parts = raw.split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    final decimals = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
    return decimals.isEmpty ? integer : '$integer,$decimals';
  }

  void _mesaj(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

class _MumGrafikPainter extends CustomPainter {
  final List<_Mum> mumlar;
  final bool emaAcik;
  final bool smaAcik;
  final bool bollingerAcik;
  final int? seciliIndex;
  final List<_Cizgi> cizgiler;
  final Offset? geciciBaslangic;
  final Offset? geciciBitis;
  final int geciciTur;

  const _MumGrafikPainter({
    required this.mumlar,
    required this.emaAcik,
    required this.smaAcik,
    required this.bollingerAcik,
    required this.seciliIndex,
    required this.cizgiler,
    required this.geciciBaslangic,
    required this.geciciBitis,
    required this.geciciTur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const right = 54.0;
    const top = 8.0;
    const bottom = 22.0;
    final area = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (area.width <= 0 || area.height <= 0 || mumlar.isEmpty) return;

    var minPrice = mumlar.map((e) => e.dusuk).reduce(math.min);
    var maxPrice = mumlar.map((e) => e.yuksek).reduce(math.max);
    final padding = math.max((maxPrice - minPrice) * 0.08, maxPrice * 0.005);
    minPrice -= padding;
    maxPrice += padding;

    double y(double price) => area.bottom - ((price - minPrice) / math.max(0.0001, maxPrice - minPrice)) * area.height;

    final grid = Paint()..color = const Color(0xFF173044)..strokeWidth = 0.7;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 5; i++) {
      final yy = area.top + area.height * i / 5;
      canvas.drawLine(Offset(area.left, yy), Offset(area.right, yy), grid);
      final value = maxPrice - (maxPrice - minPrice) * i / 5;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(value.abs() >= 1000 ? 0 : 2),
        style: const TextStyle(color: Color(0xFF5F7D93), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(area.right + 5, yy - textPainter.height / 2));
    }

    for (var i = 0; i <= 5; i++) {
      final xx = area.left + area.width * i / 5;
      canvas.drawLine(Offset(xx, area.top), Offset(xx, area.bottom), grid);
    }

    final step = area.width / mumlar.length;
    final bodyWidth = math.max(2.0, math.min(8.0, step * 0.62));
    final upPaint = Paint()..color = const Color(0xFF5DE2A5)..strokeWidth = 1;
    final downPaint = Paint()..color = const Color(0xFFFF6F7D)..strokeWidth = 1;

    for (var i = 0; i < mumlar.length; i++) {
      final m = mumlar[i];
      final x = area.left + step * (i + 0.5);
      final paint = m.kapanis >= m.acilis ? upPaint : downPaint;
      canvas.drawLine(Offset(x, y(m.yuksek)), Offset(x, y(m.dusuk)), paint);
      final bodyTop = y(math.max(m.acilis, m.kapanis));
      final bodyBottom = y(math.min(m.acilis, m.kapanis));
      final body = Rect.fromLTRB(
        x - bodyWidth / 2,
        bodyTop,
        x + bodyWidth / 2,
        math.max(bodyTop + 1.5, bodyBottom),
      );
      canvas.drawRect(body, paint);
    }

    final closes = mumlar.map((e) => e.kapanis).toList();
    if (bollingerAcik) {
      final bands = _bollinger(closes, 20, 2);
      _drawLine(canvas, area, bands.$1, minPrice, maxPrice, const Color(0xFF8B7CF6), 1.0);
      _drawLine(canvas, area, bands.$2, minPrice, maxPrice, const Color(0xFF4C7FD9), 0.8);
      _drawLine(canvas, area, bands.$3, minPrice, maxPrice, const Color(0xFF8B7CF6), 1.0);
    }
    if (emaAcik) {
      _drawLine(canvas, area, _ema(closes, 12), minPrice, maxPrice, const Color(0xFFFFC857), 1.4);
    }
    if (smaAcik) {
      _drawLine(canvas, area, _sma(closes, 20), minPrice, maxPrice, const Color(0xFF38BDF8), 1.3);
    }

    if (seciliIndex != null && seciliIndex! >= 0 && seciliIndex! < mumlar.length) {
      final x = area.left + step * (seciliIndex! + 0.5);
      final cross = Paint()..color = const Color(0xFF8FB7CF)..strokeWidth = 0.8;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), cross);
      final yy = y(mumlar[seciliIndex!].kapanis);
      canvas.drawLine(Offset(area.left, yy), Offset(area.right, yy), cross);
    }

    for (final line in cizgiler) {
      _drawUserLine(canvas, size, line.baslangic, line.bitis, line.tur);
    }
    if (geciciBaslangic != null && geciciBitis != null) {
      final a = Offset(geciciBaslangic!.dx / size.width, geciciBaslangic!.dy / size.height);
      final b = Offset(geciciBitis!.dx / size.width, geciciBitis!.dy / size.height);
      _drawUserLine(canvas, size, a, b, geciciTur);
    }
  }

  void _drawUserLine(Canvas canvas, Size size, Offset a, Offset b, int tur) {
    final start = Offset(a.dx * size.width, a.dy * size.height);
    var end = Offset(b.dx * size.width, b.dy * size.height);
    final paint = Paint()
      ..color = tur == 1 ? const Color(0xFFFFD166) : tur == 2 ? const Color(0xFFB794F4) : const Color(0xFF38BDF8)
      ..strokeWidth = 1.4;
    if (tur == 1) end = Offset(size.width, start.dy);
    canvas.drawLine(start, end, paint);
    if (tur == 2) {
      for (final ratio in [0.236, 0.382, 0.5, 0.618, 0.786]) {
        final yy = start.dy + (end.dy - start.dy) * ratio;
        canvas.drawLine(Offset(0, yy), Offset(size.width, yy), paint..strokeWidth = 0.6);
      }
    }
  }

  void _drawLine(
    Canvas canvas,
    Rect area,
    List<double?> values,
    double min,
    double max,
    Color color,
    double width,
  ) {
    final path = Path();
    var started = false;
    final step = area.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final x = area.left + step * (i + 0.5);
      final y = area.bottom - ((value - min) / math.max(0.0001, max - min)) * area.height;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _MumGrafikPainter oldDelegate) => true;
}

class _HacimPainter extends CustomPainter {
  final List<_Mum> mumlar;
  const _HacimPainter(this.mumlar);

  @override
  void paint(Canvas canvas, Size size) {
    if (mumlar.isEmpty) return;
    final maxVolume = mumlar.map((e) => e.hacim).reduce(math.max);
    final step = size.width / mumlar.length;
    final width = math.max(1.5, step * 0.62);
    for (var i = 0; i < mumlar.length; i++) {
      final m = mumlar[i];
      final height = (m.hacim / maxVolume) * (size.height - 10);
      final x = step * (i + 0.5);
      final paint = Paint()..color = m.kapanis >= m.acilis ? const Color(0x885DE2A5) : const Color(0x88FF6F7D);
      canvas.drawRect(Rect.fromLTWH(x - width / 2, size.height - height, width, height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HacimPainter oldDelegate) => true;
}

class _RsiPainter extends CustomPainter {
  final List<_Mum> mumlar;
  const _RsiPainter(this.mumlar);

  @override
  void paint(Canvas canvas, Size size) {
    final values = _rsi(mumlar.map((e) => e.kapanis).toList(), 14);
    final grid = Paint()..color = const Color(0xFF284154)..strokeWidth = 0.7;
    for (final level in [30.0, 50.0, 70.0]) {
      final y = size.height - level / 100 * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length <= 1 ? 0.0 : i / (values.length - 1) * size.width;
      final y = size.height - values[i] / 100 * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFFB794F4)..strokeWidth = 1.5..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _RsiPainter oldDelegate) => true;
}

class _MacdPainter extends CustomPainter {
  final List<_Mum> mumlar;
  const _MacdPainter(this.mumlar);

  @override
  void paint(Canvas canvas, Size size) {
    final closes = mumlar.map((e) => e.kapanis).toList();
    final fast = _emaRaw(closes, 12);
    final slow = _emaRaw(closes, 26);
    final macd = List<double>.generate(closes.length, (i) => fast[i] - slow[i]);
    final signal = _emaRaw(macd, 9);
    final hist = List<double>.generate(macd.length, (i) => macd[i] - signal[i]);
    final maxAbs = [
      ...macd.map((e) => e.abs()),
      ...signal.map((e) => e.abs()),
      ...hist.map((e) => e.abs()),
      0.0001,
    ].reduce(math.max);
    final zero = size.height / 2;
    canvas.drawLine(Offset(0, zero), Offset(size.width, zero), Paint()..color = const Color(0xFF284154)..strokeWidth = 0.8);
    final step = size.width / hist.length;
    for (var i = 0; i < hist.length; i++) {
      final h = hist[i] / maxAbs * (size.height * 0.38);
      canvas.drawRect(
        Rect.fromLTWH(step * i + 1, zero - math.max(0, h), math.max(1, step - 2), h.abs()),
        Paint()..color = h >= 0 ? const Color(0x885DE2A5) : const Color(0x88FF6F7D),
      );
    }
    _drawSeries(canvas, size, macd, maxAbs, const Color(0xFF38BDF8));
    _drawSeries(canvas, size, signal, maxAbs, const Color(0xFFFFC857));
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, double maxAbs, Color color) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length <= 1 ? 0.0 : i / (values.length - 1) * size.width;
      final y = size.height / 2 - values[i] / maxAbs * (size.height * 0.38);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _MacdPainter oldDelegate) => true;
}

class _Mum {
  final DateTime tarih;
  final double acilis;
  final double yuksek;
  final double dusuk;
  final double kapanis;
  final double hacim;

  const _Mum({
    required this.tarih,
    required this.acilis,
    required this.yuksek,
    required this.dusuk,
    required this.kapanis,
    required this.hacim,
  });
}

class _CizimAraci {
  final IconData icon;
  final String ad;
  const _CizimAraci(this.icon, this.ad);
}

class _Cizgi {
  final Offset baslangic;
  final Offset bitis;
  final int tur;
  const _Cizgi({required this.baslangic, required this.bitis, required this.tur});
}

List<double?> _sma(List<double> values, int period) {
  final result = <double?>[];
  for (var i = 0; i < values.length; i++) {
    if (i + 1 < period) {
      result.add(null);
      continue;
    }
    final start = i + 1 - period;
    final sum = values.sublist(start, i + 1).fold<double>(0, (a, b) => a + b);
    result.add(sum / period);
  }
  return result;
}

List<double?> _ema(List<double> values, int period) => _emaRaw(values, period).map<double?>((e) => e).toList();

List<double> _emaRaw(List<double> values, int period) {
  if (values.isEmpty) return [];
  final multiplier = 2 / (period + 1);
  final result = <double>[values.first];
  for (var i = 1; i < values.length; i++) {
    result.add((values[i] - result.last) * multiplier + result.last);
  }
  return result;
}

(List<double?>, List<double?>, List<double?>) _bollinger(
  List<double> values,
  int period,
  double multiplier,
) {
  final upper = <double?>[];
  final middle = <double?>[];
  final lower = <double?>[];
  for (var i = 0; i < values.length; i++) {
    if (i + 1 < period) {
      upper.add(null);
      middle.add(null);
      lower.add(null);
      continue;
    }
    final window = values.sublist(i + 1 - period, i + 1);
    final mean = window.fold<double>(0, (a, b) => a + b) / period;
    final variance = window.fold<double>(0, (a, b) => a + math.pow(b - mean, 2)) / period;
    final sd = math.sqrt(variance);
    upper.add(mean + sd * multiplier);
    middle.add(mean);
    lower.add(mean - sd * multiplier);
  }
  return (upper, middle, lower);
}

List<double> _rsi(List<double> values, int period) {
  if (values.length < 2) return List<double>.filled(values.length, 50);
  final result = List<double>.filled(values.length, 50);
  var gains = 0.0;
  var losses = 0.0;
  for (var i = 1; i < values.length; i++) {
    final diff = values[i] - values[i - 1];
    final gain = math.max(0, diff);
    final loss = math.max(0, -diff);
    if (i <= period) {
      gains += gain;
      losses += loss;
      if (i == period) {
        gains /= period;
        losses /= period;
      }
    } else {
      gains = (gains * (period - 1) + gain) / period;
      losses = (losses * (period - 1) + loss) / period;
    }
    if (i >= period) {
      final rs = losses == 0 ? 100.0 : gains / losses;
      result[i] = 100 - 100 / (1 + rs);
    }
  }
  return result;
}
