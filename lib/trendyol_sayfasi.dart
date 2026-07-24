import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TrendyolSayfasi extends StatefulWidget {
  const TrendyolSayfasi({super.key});

  @override
  State<TrendyolSayfasi> createState() => _TrendyolSayfasiState();
}

class _TrendyolSayfasiState extends State<TrendyolSayfasi> {
  static const String _apiAdresi =
      'https://trendora-icj9.onrender.com/api/opportunities?limit=100';

  bool _yukleniyor = true;
  bool _yenileniyor = false;
  String? _hataMesaji;
  DateTime? _sonGuncelleme;

  List<TrendyolFirsati> _urunler = [];

  @override
  void initState() {
    super.initState();
    _urunleriGetir();
  }

  Future<void> _urunleriGetir({
    bool yenileme = false,
  }) async {
    if (!mounted) return;

    setState(() {
      if (yenileme) {
        _yenileniyor = true;
      } else {
        _yukleniyor = true;
      }

      _hataMesaji = null;
    });

    try {
      final http.Response cevap = await http
          .get(
            Uri.parse(_apiAdresi),
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (cevap.statusCode != 200) {
        throw Exception(
          'Sunucu hatası: ${cevap.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(
        utf8.decode(cevap.bodyBytes),
      );

      final List<dynamic> hamListe =
          _jsonListesiniBul(decoded);

      final List<TrendyolFirsati> gelenUrunler = hamListe
          .whereType<Map<String, dynamic>>()
          .where(_trendyolKaydiMi)
          .map(TrendyolFirsati.fromJson)
          .toList();

      if (!mounted) return;

      setState(() {
        _urunler = gelenUrunler;
        _sonGuncelleme = DateTime.now();
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _hataMesaji =
            'Sunucu zamanında cevap vermedi. Birkaç saniye sonra tekrar dene.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hataMesaji =
            'Trendyol fırsatları alınamadı.\n\n$e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
        _yenileniyor = false;
      });
    }
  }

  List<dynamic> _jsonListesiniBul(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final List<dynamic> alanlar = [
        decoded['opportunities'],
        decoded['items'],
        decoded['data'],
        decoded['products'],
        decoded['results'],
      ];

      for (final dynamic alan in alanlar) {
        if (alan is List) {
          return alan;
        }

        if (alan is Map<String, dynamic> &&
            alan['items'] is List) {
          return alan['items'] as List<dynamic>;
        }
      }
    }

    return [];
  }

  bool _trendyolKaydiMi(
    Map<String, dynamic> json,
  ) {
    final String aranacakMetin = [
      json['source'],
      json['sourceName'],
      json['source_name'],
      json['store'],
      json['seller'],
      json['title'],
      json['description'],
      json['url'],
      json['officialUrl'],
      json['telegramMessageUrl'],
    ].map(_normalize).join(' ');

    return aranacakMetin.contains('trendyol') ||
        aranacakMetin.contains('ty.gl');
  }

  String _normalize(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  Future<void> _firsatiAc(
    TrendyolFirsati firsat,
  ) async {
    final Uri? uri = Uri.tryParse(
      firsat.url.trim(),
    );

    if (uri == null ||
        !(uri.scheme == 'http' ||
            uri.scheme == 'https')) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fırsat bağlantısı geçerli değil.',
          ),
        ),
      );
      return;
    }

    final bool acildi = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!acildi && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fırsat bağlantısı açılamadı.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Trendyol Fırsatları'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yenileniyor
                ? null
                : () {
                    _urunleriGetir(
                      yenileme: true,
                    );
                  },
            icon: _yenileniyor
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return _urunleriGetir(
            yenileme: true,
          );
        },
        child: _sayfaGovdesi(),
      ),
    );
  }

  Widget _sayfaGovdesi() {
    if (_yukleniyor) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_hataMesaji != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.cloud_off,
            size: 65,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _hataMesaji!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                _urunleriGetir();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ),
        ],
      );
    }

    if (_urunler.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        children: [
          SizedBox(height: 130),
          Icon(
            Icons.search_off,
            size: 60,
            color: Colors.grey,
          ),
          SizedBox(height: 14),
          Text(
            'Şu anda Trendyol fırsatı bulunamadı.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        28,
      ),
      itemCount: _urunler.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _bilgiKarti();
        }

        final TrendyolFirsati firsat =
            _urunler[index - 1];

        return _urunKarti(firsat);
      },
    );
  }

  Widget _bilgiKarti() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.update,
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sonGuncelleme == null
                  ? '${_urunler.length} Trendyol fırsatı bulundu.'
                  : '${_urunler.length} fırsat • Son güncelleme: ${_saatYaz(_sonGuncelleme!)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _urunKarti(
    TrendyolFirsati firsat,
  ) {
    return TrendyolMetinFirsatKarti(
      firsat: firsat,
      onAc: () => _firsatiAc(firsat),
    );
  }

  String _saatYaz(DateTime tarih) {
    final String saat =
        tarih.hour.toString().padLeft(2, '0');

    final String dakika =
        tarih.minute.toString().padLeft(2, '0');

    return '$saat:$dakika';
  }
}


class TrendyolMetinFirsatKarti extends StatefulWidget {
  final TrendyolFirsati firsat;
  final VoidCallback onAc;

  const TrendyolMetinFirsatKarti({
    super.key,
    required this.firsat,
    required this.onAc,
  });

  @override
  State<TrendyolMetinFirsatKarti> createState() =>
      _TrendyolMetinFirsatKartiState();
}

class _TrendyolMetinFirsatKartiState
    extends State<TrendyolMetinFirsatKarti> {
  bool _kaydedildi = false;

  @override
  Widget build(BuildContext context) {
    final TrendyolFirsati firsat = widget.firsat;
    final bool linkHazir = _gecerliWebAdresi(firsat.url);
    final bool fiyatVar = firsat.fiyat.trim().isNotEmpty;
    final bool trendyolLinki =
        firsat.url.toLowerCase().contains('trendyol') ||
            firsat.url.toLowerCase().contains('ty.gl');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF27A1A).withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: linkHazir ? widget.onAc : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _firsatRozeti(firsat),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27A1A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 4.5,
                            backgroundColor: Color(0xFFF27A1A),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'TRENDYOL',
                            style: TextStyle(
                              color: Color(0xFFF27A1A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  firsat.baslik.isEmpty
                      ? 'Trendyol Fırsatı'
                      : firsat.baslik,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                if (firsat.aciklama.isNotEmpty &&
                    firsat.aciklama.trim() != firsat.baslik.trim()) ...[
                  const SizedBox(height: 8),
                  Text(
                    firsat.aciklama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
                if (fiyatVar || firsat.eskiFiyat.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (fiyatVar)
                        Expanded(
                          child: Text(
                            '💰 ${firsat.fiyat}',
                            style: const TextStyle(
                              color: Color(0xFF128447),
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      if (firsat.indirimOrani > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8E8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            '-%${firsat.indirimOrani}',
                            style: const TextStyle(
                              color: Color(0xFFD92525),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (firsat.eskiFiyat.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      firsat.eskiFiyat,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 13),
                _bilgiSatiri(
                  Icons.storefront_outlined,
                  firsat.kaynakAdi.isEmpty
                      ? 'Trendyol'
                      : firsat.kaynakAdi,
                  const Color(0xFFF27A1A),
                ),
                const SizedBox(height: 8),
                _bilgiSatiri(
                  Icons.schedule_outlined,
                  _zamanMetni(firsat.eklenmeTarihi),
                  Colors.blueGrey,
                ),
                if (linkHazir || fiyatVar || trendyolLinki) ...[
                  const SizedBox(height: 8),
                  _dogrulamaSatiri(
                    linkHazir: linkHazir,
                    fiyatVar: fiyatVar,
                    trendyolLinki: trendyolLinki,
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _kaydedildi = !_kaydedildi;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 1),
                              content: Text(
                                _kaydedildi
                                    ? 'Fırsat bu oturum için kaydedildi.'
                                    : 'Fırsat kayıtlardan çıkarıldı.',
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          _kaydedildi
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                        label: Text(
                          _kaydedildi ? 'Kaydedildi' : 'Kaydet',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: const Color(0xFF202A44),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: linkHazir ? widget.onAc : null,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Fırsata Git'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFFF27A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _firsatRozeti(TrendyolFirsati firsat) {
    final String metin;
    final IconData ikon;

    if (firsat.indirimOrani >= 40) {
      metin = 'SÜPER FIRSAT';
      ikon = Icons.local_fire_department;
    } else if (firsat.indirimOrani >= 20) {
      metin = 'FLAŞ İNDİRİM';
      ikon = Icons.bolt;
    } else if (firsat.indirimOrani > 0) {
      metin = 'FİYAT DÜŞTÜ';
      ikon = Icons.trending_down;
    } else {
      metin = 'GÜNCEL FIRSAT';
      ikon = Icons.local_offer_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: 16,
            color: const Color(0xFFE84A1A),
          ),
          const SizedBox(width: 5),
          Text(
            metin,
            style: const TextStyle(
              color: Color(0xFFE84A1A),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bilgiSatiri(
    IconData ikon,
    String metin,
    Color renk,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ikon,
          size: 18,
          color: renk,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            metin,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dogrulamaSatiri({
    required bool linkHazir,
    required bool fiyatVar,
    required bool trendyolLinki,
  }) {
    final List<String> bilgiler = [];

    if (trendyolLinki) {
      bilgiler.add('Trendyol bağlantısı eşleşti');
    }
    if (fiyatVar) {
      bilgiler.add('Fiyat bilgisi mevcut');
    }
    if (linkHazir) {
      bilgiler.add('Bağlantı hazır');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_outlined,
          size: 18,
          color: Color(0xFF128447),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            bilgiler.join('  •  '),
            style: const TextStyle(
              color: Color(0xFF128447),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  bool _gecerliWebAdresi(String adres) {
    final Uri? uri = Uri.tryParse(adres.trim());

    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _zamanMetni(DateTime? tarih) {
    if (tarih == null) {
      return 'Güncel kaynak kaydı';
    }

    final Duration fark = DateTime.now().difference(tarih.toLocal());

    if (fark.isNegative || fark.inMinutes < 1) {
      return 'Az önce';
    }
    if (fark.inMinutes < 60) {
      return '${fark.inMinutes} dakika önce';
    }
    if (fark.inHours < 24) {
      return '${fark.inHours} saat önce';
    }
    if (fark.inDays < 7) {
      return '${fark.inDays} gün önce';
    }

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }
}

class TrendyolFirsati {
  final String baslik;
  final String aciklama;
  final String kaynakAdi;
  final String fiyat;
  final String eskiFiyat;
  final int indirimOrani;
  final String imageUrl;
  final String url;
  final DateTime? eklenmeTarihi;

  const TrendyolFirsati({
    required this.baslik,
    required this.aciklama,
    required this.kaynakAdi,
    required this.fiyat,
    required this.eskiFiyat,
    required this.indirimOrani,
    required this.imageUrl,
    required this.url,
    required this.eklenmeTarihi,
  });

  factory TrendyolFirsati.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrendyolFirsati(
      baslik: _metin(
        json['title'] ??
            json['baslik'] ??
            json['name'] ??
            json['productName'],
      ),
      aciklama: _metin(
        json['description'] ??
            json['aciklama'] ??
            json['summary'],
      ),
      kaynakAdi: _metin(
        json['sourceName'] ??
            json['source_name'] ??
            json['store'] ??
            json['seller'] ??
            json['source'],
      ),
      fiyat: _fiyat(
        json['currentPrice'] ??
            json['price'] ??
            json['fiyat'],
      ),
      eskiFiyat: _fiyat(
        json['oldPrice'] ??
            json['old_price'] ??
            json['eskiFiyat'],
      ),
      indirimOrani: _sayi(
        json['discountRate'] ??
            json['discountPercent'] ??
            json['discount_rate'] ??
            json['indirimOrani'],
      ),
      imageUrl: _metin(
        json['imageUrl'] ??
            json['image_url'] ??
            json['image'] ??
            json['thumbnail'],
      ),
      url: _metin(
        json['officialUrl'] ??
            json['official_url'] ??
            json['url'] ??
            json['link'] ??
            json['telegramMessageUrl'],
      ),
      eklenmeTarihi: _tarih(
        json['createdAt'] ??
            json['created_at'] ??
            json['publishedAt'] ??
            json['date'],
      ),
    );
  }

  static String _metin(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static DateTime? _tarih(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is int) {
      final int milliseconds =
          value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    return DateTime.tryParse(value.toString().trim());
  }

  static int _sayi(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();

    return double.tryParse(
          value
              .toString()
              .replaceAll('%', '')
              .replaceAll(',', '.')
              .trim(),
        )?.round() ??
        0;
  }

  static String _fiyat(dynamic value) {
    if (value == null) return '';

    final String metin =
        value.toString().trim();

    if (metin.isEmpty ||
        metin.toLowerCase() == 'null') {
      return '';
    }

    if (metin.toLowerCase().contains('tl') ||
        metin.contains('₺')) {
      return metin;
    }

    return '$metin TL';
  }
}