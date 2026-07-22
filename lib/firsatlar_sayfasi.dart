import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'trendyol_sayfasi.dart';

const String firsatlarApiAdresi = 'https://trendora-icj9.onrender.com';

class FirsatlarSayfasi extends StatefulWidget {
  const FirsatlarSayfasi({super.key});

  @override
  State<FirsatlarSayfasi> createState() => _FirsatlarSayfasiState();
}

class _FirsatlarSayfasiState extends State<FirsatlarSayfasi> {
  Timer? _yenilemeZamanlayicisi;

  List<FirsatModeli> _oneCikanFirsatlar = [];

  bool _yukleniyor = true;
  bool _yenileniyor = false;

  String? _hataMesaji;
  DateTime? _sonGuncelleme;

  @override
  void initState() {
    super.initState();

    _oneCikanFirsatlariGetir();

    _yenilemeZamanlayicisi = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        _oneCikanFirsatlariGetir(arkaPlanda: true);
      },
    );
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    super.dispose();
  }

  Future<void> _oneCikanFirsatlariGetir({
    bool arkaPlanda = false,
  }) async {
    if (!mounted) return;

    setState(() {
      if (arkaPlanda) {
        _yenileniyor = true;
      } else {
        _yukleniyor = true;
      }

      _hataMesaji = null;
    });

    try {
      final uri = Uri.parse(
        '$firsatlarApiAdresi/api/opportunities?limit=6',
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Sunucu hata kodu: ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      final List<dynamic> hamListe = _jsonListesiniBul(decoded);

      final List<FirsatModeli> gelenFirsatlar = hamListe
          .whereType<Map<String, dynamic>>()
          .map(FirsatModeli.fromJson)
          .toList();

      if (!mounted) return;

      setState(() {
        _oneCikanFirsatlar = gelenFirsatlar;
        _sonGuncelleme = DateTime.now();
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _hataMesaji =
            'Sunucu zamanında cevap vermedi. Backend açık mı kontrol et.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hataMesaji =
            'Fırsatlar alınamadı. Backend bağlantısını kontrol et.\n\n$e';
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
      final List<dynamic> olasiAlanlar = [
        decoded['opportunities'],
        decoded['firsatlar'],
        decoded['items'],
        decoded['data'],
        decoded['results'],
      ];

      for (final dynamic alan in olasiAlanlar) {
        if (alan is List) {
          return alan;
        }

        if (alan is Map<String, dynamic>) {
          final dynamic items = alan['items'];

          if (items is List) {
            return items;
          }
        }
      }
    }

    return [];
  }

  void _kategoriSayfasiniAc({
    required String baslik,
    required String kategori,
    required Color renk,
    String? kaynak,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CanliFirsatlarListeSayfasi(
          baslik: baslik,
          kategori: kategori,
          kaynak: kaynak,
          renk: renk,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Fırsat Merkezi'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yenileniyor
                ? null
                : () {
                    _oneCikanFirsatlariGetir();
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
        onRefresh: _oneCikanFirsatlariGetir,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            _ustBilgiKarti(),
            const SizedBox(height: 20),

            const BolumBasligi(
              ikon: Icons.shopping_bag_outlined,
              baslik: 'E-Ticaret Fırsatları',
              aciklama:
                  'Popüler ürünler, kampanyalar ve fiyat düşüşleri',
            ),
            const SizedBox(height: 12),

            _kategoriKarti(
              baslik: 'Trendyol',
              aciklama:
                  'En çok satan ürünler ve öne çıkan indirimler',
              renk: Colors.orange,
              ikon: Icons.shopping_bag,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrendyolSayfasi(),
                  ),
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Amazon Türkiye',
              aciklama:
                  'Flaş fırsatlar ve popüler ürün kampanyaları',
              renk: Colors.blueGrey,
              ikon: Icons.inventory_2_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Amazon Fırsatları',
                  kategori: 'ecommerce',
                  kaynak: 'amazon',
                  renk: Colors.blueGrey,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Hepsiburada',
              aciklama:
                  'Günün kampanyaları ve fiyatı düşen ürünler',
              renk: Colors.blue,
              ikon: Icons.shopping_cart_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Hepsiburada Fırsatları',
                  kategori: 'ecommerce',
                  kaynak: 'hepsiburada',
                  renk: Colors.blue,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'n11',
              aciklama:
                  'Kuponlu ürünler ve dönemsel kampanyalar',
              renk: Colors.green,
              ikon: Icons.local_offer_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'n11 Fırsatları',
                  kategori: 'ecommerce',
                  kaynak: 'n11',
                  renk: Colors.green,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Telegram Fırsatları',
              aciklama:
                  'Takip edilen fırsat kanallarından gelen güncel paylaşımlar',
              renk: Colors.lightBlue,
              ikon: Icons.send_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Telegram Fırsatları',
                  kategori: 'all',
                  kaynak: 'telegram',
                  renk: Colors.lightBlue,
                );
              },
            ),

            const SizedBox(height: 10),

            const BolumBasligi(
              ikon: Icons.storefront_outlined,
              baslik: 'Market Fırsatları',
              aciklama:
                  'Marketlerin güncel ürün ve kampanyaları',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _marketKarti(
                    isim: 'BİM',
                    renk: Colors.red,
                    onTap: () {
                      _kategoriSayfasiniAc(
                        baslik: 'BİM Fırsatları',
                        kategori: 'market',
                        kaynak: 'bim',
                        renk: Colors.red,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _marketKarti(
                    isim: 'A101',
                    renk: Colors.blue,
                    onTap: () {
                      _kategoriSayfasiniAc(
                        baslik: 'A101 Fırsatları',
                        kategori: 'market',
                        kaynak: 'a101',
                        renk: Colors.blue,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _marketKarti(
                    isim: 'ŞOK',
                    renk: Colors.amber.shade800,
                    onTap: () {
                      _kategoriSayfasiniAc(
                        baslik: 'ŞOK Fırsatları',
                        kategori: 'market',
                        kaynak: 'sok',
                        renk: Colors.amber.shade800,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _marketKarti(
                    isim: 'Migros',
                    renk: Colors.orange,
                    onTap: () {
                      _kategoriSayfasiniAc(
                        baslik: 'Migros Fırsatları',
                        kategori: 'market',
                        kaynak: 'migros',
                        renk: Colors.orange,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _kategoriKarti(
              baslik: 'Banka Kampanyaları',
              aciklama:
                  'Kart indirimleri, puanlar ve para iadeleri',
              renk: Colors.green,
              ikon: Icons.credit_card,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Banka Kampanyaları',
                  kategori: 'bank',
                  renk: Colors.green,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Otomobil Kampanyaları',
              aciklama:
                  'Sıfır araç, servis, lastik ve akaryakıt fırsatları',
              renk: Colors.indigo,
              ikon: Icons.directions_car_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Otomobil Kampanyaları',
                  kategori: 'automotive',
                  renk: Colors.indigo,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Kupon Merkezi',
              aciklama:
                  'Aktif indirim kodları ve kullanılabilir kuponlar',
              renk: Colors.purple,
              ikon: Icons.confirmation_number_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Kupon Merkezi',
                  kategori: 'coupon',
                  renk: Colors.purple,
                );
              },
            ),

            _kategoriKarti(
              baslik: 'Trendora AI',
              aciklama:
                  'Bütçene göre seçilmiş fırsat önerileri',
              renk: Colors.red,
              ikon: Icons.auto_awesome,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Trendora AI Önerileri',
                  kategori: 'ai',
                  renk: Colors.red,
                );
              },
            ),

            const SizedBox(height: 20),

            const BolumBasligi(
              ikon: Icons.local_fire_department_outlined,
              baslik: 'Şu An Öne Çıkanlar',
              aciklama:
                  'Canlı kaynaklardan alınan son fırsatlar',
            ),
            const SizedBox(height: 12),

            _oneCikanlarBolumu(),
          ],
        ),
      ),
    );
  }

  Widget _ustBilgiKarti() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF202A44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white12,
            child: Icon(
              Icons.radar,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fırsatlar canlı taranıyor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _sonGuncelleme == null
                      ? 'Marketler, bankalar ve e-ticaret kaynakları kontrol ediliyor.'
                      : 'Son güncelleme: ${_saatYaz(_sonGuncelleme!)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_yenileniyor)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _oneCikanlarBolumu() {
    if (_yukleniyor) {
      return const YukleniyorKarti();
    }

    if (_hataMesaji != null) {
      return HataKarti(
        mesaj: _hataMesaji!,
        yenidenDene: () {
          _oneCikanFirsatlariGetir();
        },
      );
    }

    if (_oneCikanFirsatlar.isEmpty) {
      return const BosKarti();
    }

    return Column(
      children: _oneCikanFirsatlar
          .map(
            (firsat) => FirsatKarti(
              firsat: firsat,
            ),
          )
          .toList(),
    );
  }

  Widget _kategoriKarti({
    required String baslik,
    required String aciklama,
    required Color renk,
    required IconData ikon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: renk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ikon,
                  color: renk,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      aciklama,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marketKarti({
    required String isim,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 10,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: renk.withOpacity(0.13),
                child: Icon(
                  Icons.storefront,
                  color: renk,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isim,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fırsatları gör',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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

class CanliFirsatlarListeSayfasi extends StatefulWidget {
  final String baslik;
  final String kategori;
  final String? kaynak;
  final Color renk;

  const CanliFirsatlarListeSayfasi({
    super.key,
    required this.baslik,
    required this.kategori,
    required this.renk,
    this.kaynak,
  });

  @override
  State<CanliFirsatlarListeSayfasi> createState() =>
      _CanliFirsatlarListeSayfasiState();
}

class _CanliFirsatlarListeSayfasiState
    extends State<CanliFirsatlarListeSayfasi> {
  Timer? _yenilemeZamanlayicisi;

  List<FirsatModeli> _firsatlar = [];

  bool _yukleniyor = true;
  bool _yenileniyor = false;

  String? _hataMesaji;
  DateTime? _sonGuncelleme;

  @override
  void initState() {
    super.initState();

    _firsatlariGetir();

    _yenilemeZamanlayicisi = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        _firsatlariGetir(arkaPlanda: true);
      },
    );
  }

  @override
  void dispose() {
    _yenilemeZamanlayicisi?.cancel();
    super.dispose();
  }

  Future<void> _firsatlariGetir({
    bool arkaPlanda = false,
  }) async {
    if (!mounted) return;

    setState(() {
      if (arkaPlanda) {
        _yenileniyor = true;
      } else {
        _yukleniyor = true;
      }

      _hataMesaji = null;
    });

    try {
      final String? kaynak = widget.kaynak?.trim().toLowerCase();

      final Set<String> dogrudanKaynaklar = {
        'a101',
        'bim',
        'sok',
        'migros',
        'telegram',
      };

      final Map<String, String> sorgu = {
        'limit': '100',
      };

      /*
        Telegram fırsatlarının source alanı "telegram" olduğu için
        Amazon, Hepsiburada, Trendyol ve n11 ayrımı mağaza/link
        bilgisine bakılarak Flutter tarafında yapılır.
      */
      if (kaynak != null &&
          kaynak.isNotEmpty &&
          dogrudanKaynaklar.contains(kaynak)) {
        sorgu['source'] = kaynak;
      } else if (kaynak == null || kaynak.isEmpty) {
        if (widget.kategori != 'all') {
          sorgu['category'] = widget.kategori;
        }
      }

      final Uri uri = Uri.parse(
        '$firsatlarApiAdresi/api/opportunities',
      ).replace(
        queryParameters: sorgu,
      );

      final http.Response response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Sunucu hata kodu: ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      final List<dynamic> hamListe =
          _jsonListesiniBul(decoded);

      final List<FirsatModeli> gelenFirsatlar = hamListe
          .whereType<Map<String, dynamic>>()
          .where(_kayitBuSayfayaAitMi)
          .map(FirsatModeli.fromJson)
          .toList();

      if (!mounted) return;

      setState(() {
        _firsatlar = gelenFirsatlar;
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
            'Fırsatlar alınamadı.\n\n$e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
        _yenileniyor = false;
      });
    }
  }

  bool _kayitBuSayfayaAitMi(
    Map<String, dynamic> json,
  ) {
    final String? istenenKaynak =
        widget.kaynak?.trim().toLowerCase();

    if (istenenKaynak == null || istenenKaynak.isEmpty) {
      return true;
    }

    final String source = _normalize(
      json['source'],
    );

    if (istenenKaynak == 'telegram') {
      return source == 'telegram';
    }

    if ({
      'a101',
      'bim',
      'sok',
      'migros',
    }.contains(istenenKaynak)) {
      return source == istenenKaynak;
    }

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

    switch (istenenKaynak) {
      case 'trendyol':
        return aranacakMetin.contains('trendyol') ||
            aranacakMetin.contains('ty.gl');

      case 'hepsiburada':
        return aranacakMetin.contains('hepsiburada') ||
            aranacakMetin.contains('hb.biz') ||
            aranacakMetin.contains('app.hb.biz');

      case 'amazon':
        return aranacakMetin.contains('amazon') ||
            aranacakMetin.contains('amzn') ||
            aranacakMetin.contains('amazon.com.tr');

      case 'n11':
        return aranacakMetin.contains('n11') ||
            aranacakMetin.contains('sl.n11');

      default:
        return source == istenenKaynak ||
            aranacakMetin.contains(istenenKaynak);
    }
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

  List<dynamic> _jsonListesiniBul(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final List<dynamic> olasiAlanlar = [
        decoded['opportunities'],
        decoded['firsatlar'],
        decoded['items'],
        decoded['data'],
        decoded['results'],
      ];

      for (final dynamic alan in olasiAlanlar) {
        if (alan is List) {
          return alan;
        }

        if (alan is Map<String, dynamic>) {
          final dynamic items = alan['items'];

          if (items is List) {
            return items;
          }
        }
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.baslik),
        actions: [
          IconButton(
            onPressed: _yenileniyor
                ? null
                : () {
                    _firsatlariGetir();
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
        onRefresh: _firsatlariGetir,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.renk.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.update,
                    color: widget.renk,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sonGuncelleme == null
                          ? 'Güncel fırsatlar kontrol ediliyor.'
                          : 'Son güncelleme: ${_tarihSaatYaz(_sonGuncelleme!)}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_yukleniyor)
              const YukleniyorKarti()
            else if (_hataMesaji != null)
              HataKarti(
                mesaj: _hataMesaji!,
                yenidenDene: () {
                  _firsatlariGetir();
                },
              )
            else if (_firsatlar.isEmpty)
              const BosKarti()
            else
              ..._firsatlar.map(
                (firsat) => FirsatKarti(
                  firsat: firsat,
                  vurguRengi: widget.renk,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _tarihSaatYaz(DateTime tarih) {
    final String gun =
        tarih.day.toString().padLeft(2, '0');

    final String ay =
        tarih.month.toString().padLeft(2, '0');

    final String saat =
        tarih.hour.toString().padLeft(2, '0');

    final String dakika =
        tarih.minute.toString().padLeft(2, '0');

    return '$gun.$ay.${tarih.year} $saat:$dakika';
  }
}

class FirsatModeli {
  final String baslik;
  final String aciklama;
  final String kategori;
  final String kaynakAdi;
  final String fiyat;
  final String eskiFiyat;
  final int indirimOrani;
  final String kampanyaTarihi;
  final String imageUrl;
  final String officialUrl;
  final String stokUyarisi;
  final String rozet;

  const FirsatModeli({
    required this.baslik,
    required this.aciklama,
    required this.kategori,
    required this.kaynakAdi,
    required this.fiyat,
    required this.eskiFiyat,
    required this.indirimOrani,
    required this.kampanyaTarihi,
    required this.imageUrl,
    required this.officialUrl,
    required this.stokUyarisi,
    required this.rozet,
  });

  factory FirsatModeli.fromJson(
    Map<String, dynamic> json,
  ) {
    return FirsatModeli(
      baslik: _metneCevir(
        json['title'] ??
            json['baslik'] ??
            json['name'] ??
            json['productName'],
      ),
      aciklama: _metneCevir(
        json['description'] ??
            json['aciklama'] ??
            json['summary'],
      ),
      kategori: _metneCevir(
        json['category'] ??
            json['kategori'] ??
            json['type'],
      ),
      kaynakAdi: _metneCevir(
        json['sourceName'] ??
            json['source_name'] ??
            json['kaynakAdi'] ??
            json['source'] ??
            json['kaynak'],
      ),
      fiyat: _fiyatDuzenle(
        json['price'] ??
            json['fiyat'] ??
            json['currentPrice'],
      ),
      eskiFiyat: _fiyatDuzenle(
        json['oldPrice'] ??
            json['old_price'] ??
            json['eskiFiyat'],
      ),
      indirimOrani: _sayiyaCevir(
        json['discountRate'] ??
            json['discount_rate'] ??
            json['indirimOrani'] ??
            json['discount'],
      ),
      kampanyaTarihi: _metneCevir(
        json['campaignDate'] ??
            json['campaign_date'] ??
            json['kampanyaTarihi'] ??
            json['validity'],
      ),
      imageUrl: _metneCevir(
        json['imageUrl'] ??
            json['image_url'] ??
            json['image'] ??
            json['thumbnail'],
      ),
      officialUrl: _metneCevir(
        json['officialUrl'] ??
            json['official_url'] ??
            json['url'] ??
            json['link'],
      ),
      stokUyarisi: _metneCevir(
        json['stockWarning'] ??
            json['stock_warning'] ??
            json['stokUyarisi'],
      ),
      rozet: _metneCevir(
        json['badge'] ??
            json['rozet'],
      ),
    );
  }

  static String _metneCevir(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static int _sayiyaCevir(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    final String temiz = value
        .toString()
        .replaceAll('%', '')
        .replaceAll(',', '.')
        .trim();

    return double.tryParse(temiz)?.round() ?? 0;
  }

  static String _fiyatDuzenle(dynamic value) {
    if (value == null) {
      return '';
    }

    final String fiyat = value.toString().trim();

    if (fiyat.isEmpty) {
      return '';
    }

    if (fiyat.toLowerCase().contains('tl') ||
        fiyat.contains('₺')) {
      return fiyat;
    }

    return '$fiyat TL';
  }

  String get kategoriEtiketi {
    final String temizKategori =
        kategori.toLowerCase();

    switch (temizKategori) {
      case 'market':
        return 'MARKET';
      case 'bank':
      case 'banka':
        return 'BANKA';
      case 'ecommerce':
      case 'eticaret':
        return 'E-TİCARET';
      case 'automotive':
        return 'OTOMOBİL';
      case 'coupon':
        return 'KUPON';
      case 'ai':
        return 'AI ÖNERİSİ';
      default:
        return 'FIRSAT';
    }
  }
}

class FirsatKarti extends StatelessWidget {
  final FirsatModeli firsat;
  final Color vurguRengi;

  const FirsatKarti({
    super.key,
    required this.firsat,
    this.vurguRengi = Colors.deepOrange,
  });

  Future<void> _firsatiAc(BuildContext context) async {
    final String adres = firsat.officialUrl.trim();

    if (adres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu fırsat için bağlantı bulunamadı.'),
        ),
      );
      return;
    }

    final Uri? uri = Uri.tryParse(adres);

    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat bağlantısı geçerli değil.'),
        ),
      );
      return;
    }

    final bool acildi = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!acildi && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı açılamadı.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: firsat.officialUrl.trim().isEmpty
            ? null
            : () => _firsatiAc(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firsat.imageUrl.trim().isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  firsat.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
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
                      child: const CircularProgressIndicator(
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
                              vurguRengi.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          firsat.kategoriEtiketi,
                          style: TextStyle(
                            color: vurguRengi,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (firsat.rozet.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            firsat.rozet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: vurguRengi,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else
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
                        ? 'Fırsat'
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
                        Icons.verified_outlined,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          firsat.kaynakAdi.isEmpty
                              ? 'Kaynak belirtilmedi'
                              : firsat.kaynakAdi,
                        ),
                      ),
                    ],
                  ),
                  if (firsat.kampanyaTarihi.isNotEmpty)
                    ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              firsat.kampanyaTarihi,
                            ),
                          ),
                        ],
                      ),
                    ],
                  if (firsat.stokUyarisi.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            firsat.stokUyarisi,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (firsat.officialUrl.trim().isNotEmpty)
                    ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _firsatiAc(context),
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
            'Ürün görseli bulunamadı',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class BolumBasligi extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String aciklama;

  const BolumBasligi({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ikon,
          size: 25,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                aciklama,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class YukleniyorKarti extends StatelessWidget {
  const YukleniyorKarti({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Güncel fırsatlar yükleniyor...',
          ),
        ],
      ),
    );
  }
}

class BosKarti extends StatelessWidget {
  const BosKarti({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off,
            size: 45,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'Şu anda gösterilecek fırsat bulunamadı.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class HataKarti extends StatelessWidget {
  final String mesaj;
  final VoidCallback yenidenDene;

  const HataKarti({
    super.key,
    required this.mesaj,
    required this.yenidenDene,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off,
            size: 42,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          Text(
            mesaj,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: yenidenDene,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}