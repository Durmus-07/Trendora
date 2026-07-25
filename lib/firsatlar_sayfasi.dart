import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


const String firsatlarApiAdresi = 'https://trendora-icj9.onrender.com';

class FirsatlarSayfasi extends StatefulWidget {
  const FirsatlarSayfasi({super.key});

  @override
  State<FirsatlarSayfasi> createState() => _FirsatlarSayfasiState();
}

class _FirsatlarSayfasiState extends State<FirsatlarSayfasi> {
  static const bool _oneCikanlarAktif = false;

  Timer? _yenilemeZamanlayicisi;

  List<FirsatModeli> _oneCikanFirsatlar = [];

  bool _yukleniyor = true;
  bool _yenileniyor = false;

  String? _hataMesaji;
  DateTime? _sonGuncelleme;

  @override
  void initState() {
    super.initState();

    if (_oneCikanlarAktif) {
      _oneCikanFirsatlariGetir();

      _yenilemeZamanlayicisi = Timer.periodic(
        const Duration(seconds: 60),
        (_) {
          _oneCikanFirsatlariGetir(arkaPlanda: true);
        },
      );
    }
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
              ikon: Icons.local_offer_outlined,
              baslik: 'Online Fırsatlar',
              aciklama:
                  'İnternetteki güncel kampanya, indirim ve uygun fiyat fırsatları',
            ),
            const SizedBox(height: 12),

            _kategoriKarti(
              baslik: 'Online Fırsatlar',
              aciklama:
                  'Takip edilen fırsat kaynaklarından gelen güncel paylaşımlar',
              renk: Colors.lightBlue,
              ikon: Icons.send_outlined,
              onTap: () {
                _kategoriSayfasiniAc(
                  baslik: 'Online Fırsatlar',
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

            if (_oneCikanlarAktif) ...[
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
  final TextEditingController _aramaKontrolcusu = TextEditingController();

  List<FirsatModeli> _firsatlar = [];
  String _aramaMetni = '';

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
    _aramaKontrolcusu.dispose();
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
          .where((json) => !_telegramYonlendirmesiMi(json))
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

  bool _telegramYonlendirmesiMi(
    Map<String, dynamic> json,
  ) {
    final dynamic hamAdres =
        json['officialUrl'] ??
        json['official_url'] ??
        json['url'] ??
        json['link'];

    final String adres = hamAdres?.toString().trim() ?? '';

    if (adres.isEmpty) return false;

    final String kucukAdres = adres.toLowerCase();
    final Uri? uri = Uri.tryParse(kucukAdres);

    if (kucukAdres.startsWith('tg://')) return true;

    if (uri == null) {
      return kucukAdres.startsWith('t.me/') ||
          kucukAdres.startsWith('telegram.me/');
    }

    final String host = uri.host.toLowerCase();
    return host == 't.me' ||
        host.endsWith('.t.me') ||
        host == 'telegram.me' ||
        host.endsWith('.telegram.me');
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

  List<FirsatModeli> get _filtrelenmisFirsatlar {
    final String arama = _normalize(_aramaMetni);

    if (arama.isEmpty) {
      return _firsatlar;
    }

    final List<String> kelimeler = arama
        .split(RegExp(r'\s+'))
        .where((kelime) => kelime.isNotEmpty)
        .toList();

    return _firsatlar.where((firsat) {
      final String aranacakMetin = _normalize([
        firsat.baslik,
        firsat.aciklama,
        firsat.kategori,
        firsat.kaynakAdi,
        firsat.rozet,
        firsat.stokUyarisi,
      ].join(' '));

      return kelimeler.every(aranacakMetin.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<FirsatModeli> gosterilecekFirsatlar =
        _filtrelenmisFirsatlar;

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

            TextField(
              controller: _aramaKontrolcusu,
              textInputAction: TextInputAction.search,
              onChanged: (deger) {
                setState(() {
                  _aramaMetni = deger;
                });
              },
              decoration: InputDecoration(
                hintText: 'Ürün, kategori veya kupon ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _aramaMetni.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: () {
                          _aramaKontrolcusu.clear();
                          setState(() {
                            _aramaMetni = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E5EC),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: widget.renk,
                    width: 1.5,
                  ),
                ),
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
            else if (gosterilecekFirsatlar.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E5EC),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 42,
                      color: widget.renk,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '“$_aramaMetni” ile eşleşen fırsat bulunamadı.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...gosterilecekFirsatlar.map(
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
  final DateTime? eklenmeTarihi;

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
    required this.eklenmeTarihi,
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
      eklenmeTarihi: _tariheCevir(
        json['createdAt'] ??
            json['created_at'] ??
            json['publishedAt'] ??
            json['date'],
      ),
    );
  }

  static String _metneCevir(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static DateTime? _tariheCevir(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      final int milliseconds =
          value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    return DateTime.tryParse(value.toString().trim());
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


class FirsatKarti extends StatefulWidget {
  final FirsatModeli firsat;
  final Color vurguRengi;

  const FirsatKarti({
    super.key,
    required this.firsat,
    this.vurguRengi = Colors.deepOrange,
  });

  @override
  State<FirsatKarti> createState() => _FirsatKartiState();
}

class _FirsatKartiState extends State<FirsatKarti> {
  bool _kaydedildi = false;

  FirsatModeli get firsat => widget.firsat;

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

    final String host = uri.host.toLowerCase();
    final bool telegramAdresi = host == 't.me' ||
        host.endsWith('.t.me') ||
        host == 'telegram.me' ||
        host.endsWith('.telegram.me');

    if (telegramAdresi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Telegram kanal bağlantıları güvenlik nedeniyle açılmıyor.',
          ),
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
    final _MagazaBilgisi magaza = _magazaBilgisi();
    final bool linkHazir = _gecerliWebAdresi(firsat.officialUrl);
    final bool fiyatVar = firsat.fiyat.trim().isNotEmpty;
    final bool magazaEslesiyor = _magazaLinkiEslesiyor(magaza.anahtar);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: magaza.renk.withOpacity(0.16),
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
          onTap: linkHazir ? () => _firsatiAc(context) : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ustFirsatRozeti(),
                    const Spacer(),
                    _magazaRozeti(magaza),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  firsat.baslik.isEmpty ? 'Güncel Fırsat' : firsat.baslik,
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
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
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
                  magaza.ad,
                  magaza.renk,
                ),
                const SizedBox(height: 8),
                _bilgiSatiri(
                  Icons.schedule_outlined,
                  _zamanMetni(),
                  Colors.blueGrey,
                ),
                if (linkHazir || fiyatVar || magazaEslesiyor) ...[
                  const SizedBox(height: 8),
                  _dogrulamaBilgisi(
                    linkHazir: linkHazir,
                    fiyatVar: fiyatVar,
                    magazaEslesiyor: magazaEslesiyor,
                  ),
                ],
                if (firsat.stokUyarisi.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _bilgiSatiri(
                    Icons.info_outline,
                    firsat.stokUyarisi,
                    Colors.orange.shade800,
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
                        onPressed:
                            linkHazir ? () => _firsatiAc(context) : null,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Fırsata Git'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: magaza.renk,
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

  Widget _ustFirsatRozeti() {
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
      metin = firsat.rozet.trim().isNotEmpty
          ? firsat.rozet.trim().toUpperCase()
          : 'GÜNCEL FIRSAT';
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

  Widget _magazaRozeti(_MagazaBilgisi magaza) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: magaza.renk.withOpacity(0.11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: magaza.renk,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            magaza.ad.toUpperCase(),
            style: TextStyle(
              color: magaza.renk,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
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

  Widget _dogrulamaBilgisi({
    required bool linkHazir,
    required bool fiyatVar,
    required bool magazaEslesiyor,
  }) {
    final List<String> bilgiler = [];

    if (magazaEslesiyor) {
      bilgiler.add('Mağaza bağlantısı eşleşti');
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

    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return false;
    }

    final String host = uri.host.toLowerCase();
    final bool telegramAdresi = host == 't.me' ||
        host.endsWith('.t.me') ||
        host == 'telegram.me' ||
        host.endsWith('.telegram.me');

    return !telegramAdresi;
  }

  bool _magazaLinkiEslesiyor(String anahtar) {
    final String adres = firsat.officialUrl.toLowerCase();

    switch (anahtar) {
      case 'trendyol':
        return adres.contains('trendyol') || adres.contains('ty.gl');
      case 'hepsiburada':
        return adres.contains('hepsiburada') || adres.contains('hb.biz');
      case 'amazon':
        return adres.contains('amazon') || adres.contains('amzn');
      case 'n11':
        return adres.contains('n11');
      default:
        return false;
    }
  }

  String _zamanMetni() {
    final DateTime? tarih = firsat.eklenmeTarihi;

    if (tarih == null) {
      return firsat.kampanyaTarihi.isNotEmpty
          ? firsat.kampanyaTarihi
          : 'Güncel kaynak kaydı';
    }

    final Duration fark = DateTime.now().difference(tarih.toLocal());

    if (fark.isNegative) {
      return 'Az önce';
    }
    if (fark.inMinutes < 1) {
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

  _MagazaBilgisi _magazaBilgisi() {
    final String metin = [
      firsat.kaynakAdi,
      firsat.baslik,
      firsat.aciklama,
      firsat.officialUrl,
    ].join(' ').toLowerCase();

    if (metin.contains('trendyol') || metin.contains('ty.gl')) {
      return const _MagazaBilgisi(
        anahtar: 'trendyol',
        ad: 'Trendyol',
        renk: Color(0xFFF27A1A),
      );
    }

    if (metin.contains('hepsiburada') || metin.contains('hb.biz')) {
      return const _MagazaBilgisi(
        anahtar: 'hepsiburada',
        ad: 'Hepsiburada',
        renk: Color(0xFF5A31F4),
      );
    }

    if (metin.contains('amazon') || metin.contains('amzn')) {
      return const _MagazaBilgisi(
        anahtar: 'amazon',
        ad: 'Amazon',
        renk: Color(0xFF232F3E),
      );
    }

    if (metin.contains('n11')) {
      return const _MagazaBilgisi(
        anahtar: 'n11',
        ad: 'n11',
        renk: Color(0xFF25A55F),
      );
    }

    if (metin.contains('telegram')) {
      return const _MagazaBilgisi(
        anahtar: 'telegram',
        ad: 'Telegram',
        renk: Color(0xFF229ED9),
      );
    }

    if (metin.contains('a101')) {
      return const _MagazaBilgisi(
        anahtar: 'a101',
        ad: 'A101',
        renk: Color(0xFF1674C4),
      );
    }

    if (metin.contains('bim')) {
      return const _MagazaBilgisi(
        anahtar: 'bim',
        ad: 'BİM',
        renk: Color(0xFFD71920),
      );
    }

    if (metin.contains('migros')) {
      return const _MagazaBilgisi(
        anahtar: 'migros',
        ad: 'Migros',
        renk: Color(0xFFF58220),
      );
    }

    if (metin.contains('sok') || metin.contains('şok')) {
      return const _MagazaBilgisi(
        anahtar: 'sok',
        ad: 'ŞOK',
        renk: Color(0xFFF2B705),
      );
    }

    return _MagazaBilgisi(
      anahtar: 'diger',
      ad: firsat.kaynakAdi.isEmpty ? 'Trendora' : firsat.kaynakAdi,
      renk: widget.vurguRengi,
    );
  }
}

class _MagazaBilgisi {
  final String anahtar;
  final String ad;
  final Color renk;

  const _MagazaBilgisi({
    required this.anahtar,
    required this.ad,
    required this.renk,
  });
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