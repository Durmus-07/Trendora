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
      return const ListView(
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
      return const ListView(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: InkWell(
        onTap: firsat.url.isEmpty
            ? null
            : () {
                _firsatiAc(firsat);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firsat.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  firsat.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _gorselYerTutucu();
                  },
                  loadingBuilder: (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child:
                          const CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    );
                  },
                ),
              )
            else
              _gorselYerTutucu(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Colors.orange.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TRENDYOL',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (firsat.indirimOrani > 0)
                        Text(
                          '%${firsat.indirimOrani} indirim',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    firsat.baslik.isEmpty
                        ? 'Trendyol Fırsatı'
                        : firsat.baslik,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (firsat.aciklama.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      firsat.aciklama,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (firsat.fiyat.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          firsat.fiyat,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (firsat.eskiFiyat.isNotEmpty)
                          ...[
                            const SizedBox(width: 10),
                            Text(
                              firsat.eskiFiyat,
                              style: const TextStyle(
                                color: Colors.grey,
                                decoration:
                                    TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          firsat.kaynakAdi.isEmpty
                              ? 'Telegram fırsat kaynağı'
                              : firsat.kaynakAdi,
                        ),
                      ),
                    ],
                  ),
                  if (firsat.url.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          _firsatiAc(firsat);
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                        ),
                        label: const Text(
                          'Fırsata Git',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gorselYerTutucu() {
    return Container(
      height: 135,
      width: double.infinity,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 36,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            'Ürün görseli hazırlanıyor',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
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

class TrendyolFirsati {
  final String baslik;
  final String aciklama;
  final String kaynakAdi;
  final String fiyat;
  final String eskiFiyat;
  final int indirimOrani;
  final String imageUrl;
  final String url;

  const TrendyolFirsati({
    required this.baslik,
    required this.aciklama,
    required this.kaynakAdi,
    required this.fiyat,
    required this.eskiFiyat,
    required this.indirimOrani,
    required this.imageUrl,
    required this.url,
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
    );
  }

  static String _metin(dynamic value) {
    return (value ?? '').toString().trim();
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