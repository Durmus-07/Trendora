import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TrendoraAiSayfasi extends StatefulWidget {
  const TrendoraAiSayfasi({super.key});

  @override
  State<TrendoraAiSayfasi> createState() => _TrendoraAiSayfasiState();
}

class _TrendoraAiSayfasiState extends State<TrendoraAiSayfasi>
    with SingleTickerProviderStateMixin {
  // Gerçek Android telefonda USB ile test ederken terminalde:
  // adb reverse tcp:3000 tcp:3000
  //
  // komutunu çalıştır. Böylece telefon, bilgisayardaki backend'e
  // 127.0.0.1:3000 adresinden ulaşabilir.
  static const String _backendBaseUrl = 'http://127.0.0.1:3000';

  final TextEditingController _mesajController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  final List<_SohbetMesaji> _mesajlar = <_SohbetMesaji>[
    const _SohbetMesaji(
      metin:
          'Merhaba! Ben Trendora AI. Bana teknoloji, piyasalar, haberler veya yükselen trendler hakkında soru sorabilirsin.',
      kullaniciMi: false,
    ),
  ];

  bool _yanitBekleniyor = false;
  bool _backendKontrolEdiliyor = false;
  bool? _backendAktif;
  String _sonHata = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _backendDurumunuKontrolEt();
  }

  @override
  void dispose() {
    _mesajController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _backendDurumunuKontrolEt() async {
    if (_backendKontrolEdiliyor) return;

    setState(() {
      _backendKontrolEdiliyor = true;
      _sonHata = '';
    });

    try {
      final http.Response response = await http
          .get(Uri.parse('$_backendBaseUrl/'))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      setState(() {
        _backendAktif = response.statusCode == 200;
        if (response.statusCode != 200) {
          _sonHata = 'Backend ${response.statusCode} kodu döndürdü.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _backendAktif = false;
        _sonHata =
            'Backend bağlantısı kurulamadı. Node.js sunucusunun çalıştığını ve adb reverse komutunun uygulandığını kontrol et.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _backendKontrolEdiliyor = false;
        });
      }
    }
  }

  Future<void> _mesajGonder() async {
    final String mesaj = _mesajController.text.trim();

    if (mesaj.isEmpty || _yanitBekleniyor) return;

    FocusScope.of(context).unfocus();
    _mesajController.clear();

    setState(() {
      _mesajlar.add(_SohbetMesaji(metin: mesaj, kullaniciMi: true));
      _yanitBekleniyor = true;
      _sonHata = '';
    });

    _asagiKaydir();

    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_backendBaseUrl/ai'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{'message': mesaj}),
          )
          .timeout(const Duration(seconds: 90));

      Map<String, dynamic> veri = <String, dynamic>{};

      try {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          veri = decoded;
        }
      } catch (_) {
        // Sunucu JSON dışında bir cevap döndürürse aşağıdaki genel hata kullanılır.
      }

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          veri['success'] == true) {
        final String cevap =
            (veri['answer'] ?? 'AI boş bir cevap döndürdü.').toString().trim();

        setState(() {
          _mesajlar.add(
            _SohbetMesaji(
              metin: cevap.isEmpty ? 'AI boş bir cevap döndürdü.' : cevap,
              kullaniciMi: false,
            ),
          );
          _backendAktif = true;
        });
      } else {
        final String hataMesaji =
            (veri['error'] ?? 'Sunucudan geçerli bir cevap alınamadı.')
                .toString();

        setState(() {
          _sonHata = hataMesaji;
          _mesajlar.add(
            _SohbetMesaji(
              metin: 'Üzgünüm, şu anda cevap oluşturamadım.\n\n$hataMesaji',
              kullaniciMi: false,
              hataMi: true,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _backendAktif = false;
        _sonHata =
            'Bağlantı zaman aşımına uğradı veya backend kapalı. Sunucuyu ve telefon bağlantısını kontrol et.';
        _mesajlar.add(
          const _SohbetMesaji(
            metin:
                'Backend bağlantısı kurulamadı. Bilgisayarda npm run dev çalışıyor olmalı. Gerçek telefonda ayrıca adb reverse tcp:3000 tcp:3000 komutunu çalıştır.',
            kullaniciMi: false,
            hataMi: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _yanitBekleniyor = false;
        });
        _asagiKaydir();
      }
    }
  }

  void _asagiKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  void _hizliSoruGonder(String soru) {
    _mesajController.text = soru;
    _mesajGonder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1420),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A1420),
        foregroundColor: const Color(0xFFF8FAFC),
        titleSpacing: 12,
        title: const Row(
          children: <Widget>[
            _LogoKutusu(),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Trendora AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Gerçek yapay zekâ bağlantısı',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Bağlantıyı kontrol et',
            onPressed:
                _backendKontrolEdiliyor ? null : _backendDurumunuKontrolEt,
            icon: _backendKontrolEdiliyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _backendAktif == true
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: _backendAktif == true
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                  ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF4B860),
          labelColor: const Color(0xFFF8FAFC),
          unselectedLabelColor: const Color(0xFF94A3B8),
          dividerColor: Colors.transparent,
          tabs: const <Widget>[
            Tab(
              icon: Icon(Icons.auto_awesome_rounded),
              text: 'Trendora AI',
            ),
            Tab(
              icon: Icon(Icons.developer_mode_rounded),
              text: 'Geliştirici Modu',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _sohbetSekmesi(),
            _gelistiriciSekmesi(),
          ],
        ),
      ),
    );
  }

  Widget _sohbetSekmesi() {
    return Column(
      children: <Widget>[
        _baglantiBandi(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            itemCount: _mesajlar.length + (_yanitBekleniyor ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (_yanitBekleniyor && index == _mesajlar.length) {
                return const _YaziyorBalonu();
              }

              return _MesajBalonu(mesaj: _mesajlar[index]);
            },
          ),
        ),
        _hizliSorular(),
        _mesajKutusu(),
      ],
    );
  }

  Widget _baglantiBandi() {
    final bool aktif = _backendAktif == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: aktif
            ? const Color(0xFF12352F)
            : const Color(0xFF3A2B18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: aktif
              ? const Color(0xFF2D6A5C)
              : const Color(0xFF71552C),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            aktif ? Icons.check_circle_rounded : Icons.info_rounded,
            size: 19,
            color: aktif
                ? const Color(0xFF6EE7B7)
                : const Color(0xFFFCD34D),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _backendKontrolEdiliyor
                  ? 'Backend bağlantısı kontrol ediliyor...'
                  : aktif
                      ? 'Trendora Backend çevrimiçi'
                      : 'Backend bağlantısı henüz doğrulanmadı',
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _backendKontrolEdiliyor ? null : _backendDurumunuKontrolEt,
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _hizliSorular() {
    const List<String> sorular = <String>[
      'Bugünün teknoloji trendlerini özetle',
      'Yapay zekâ alanındaki fırsatlar neler?',
      'Bir iş fikrini nasıl analiz edersin?',
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: sorular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          return ActionChip(
            onPressed:
                _yanitBekleniyor ? null : () => _hizliSoruGonder(sorular[index]),
            backgroundColor: const Color(0xFF152333),
            side: const BorderSide(color: Color(0xFF2A3C50)),
            label: Text(
              sorular[index],
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mesajKutusu() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1926),
        border: Border(
          top: BorderSide(color: Color(0xFF1E3042)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _mesajController,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: Color(0xFFF8FAFC)),
              decoration: InputDecoration(
                hintText: 'Trendora AI’ya bir şey sor...',
                hintStyle: const TextStyle(color: Color(0xFF718096)),
                filled: true,
                fillColor: const Color(0xFF142333),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF2A3D50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFFF4B860),
                    width: 1.3,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!_yanitBekleniyor) {
                  _mesajGonder();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            height: 50,
            child: FilledButton(
              onPressed: _yanitBekleniyor ? null : _mesajGonder,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFF4B860),
                foregroundColor: const Color(0xFF111827),
                disabledBackgroundColor: const Color(0xFF4B5563),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _yanitBekleniyor
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Color(0xFFF8FAFC),
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gelistiriciSekmesi() {
    return RefreshIndicator(
      onRefresh: _backendDurumunuKontrolEt,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _Baslik(
            baslik: 'Sistem Durumu',
            aciklama:
                'Trendora’nın Flutter, Node.js ve OpenAI bağlantılarını izle.',
          ),
          const SizedBox(height: 14),
          _DurumKarti(
            ikon: Icons.phone_android_rounded,
            baslik: 'Flutter Uygulaması',
            deger: 'Çalışıyor',
            aciklama: 'Mobil arayüz aktif.',
            basarili: true,
          ),
          const SizedBox(height: 10),
          _DurumKarti(
            ikon: Icons.dns_rounded,
            baslik: 'Node.js Backend',
            deger: _backendKontrolEdiliyor
                ? 'Kontrol ediliyor'
                : _backendAktif == true
                    ? 'Çevrimiçi'
                    : 'Bağlantı yok',
            aciklama: '$_backendBaseUrl adresi kullanılıyor.',
            basarili: _backendAktif == true,
          ),
          const SizedBox(height: 10),
          _DurumKarti(
            ikon: Icons.psychology_rounded,
            baslik: 'OpenAI',
            deger: _backendAktif == true ? 'Backend üzerinden hazır' : 'Bekliyor',
            aciklama:
                'API anahtarı yalnızca backend içindeki .env dosyasında tutulur.',
            basarili: _backendAktif == true,
          ),
          const SizedBox(height: 20),
          const _Baslik(
            baslik: 'Güvenli Gelişim Sistemi',
            aciklama:
                'AI kendi kodunu otomatik değiştirmez; eksikleri belirler ve onaylanabilir öneriler üretir.',
          ),
          const SizedBox(height: 14),
          const _BilgiKarti(
            ikon: Icons.fact_check_rounded,
            baslik: 'Eksik Analizi',
            aciklama:
                'Başarısız cevaplar ve kullanıcı geri bildirimleri ileride veritabanına kaydedilecek.',
          ),
          const SizedBox(height: 10),
          const _BilgiKarti(
            ikon: Icons.code_rounded,
            baslik: 'Kod Önerileri',
            aciklama:
                'Trendora değişiklik önerisi, dosya listesi ve test planı hazırlayacak; uygulama ancak sen onayladığında güncellenecek.',
          ),
          const SizedBox(height: 10),
          const _BilgiKarti(
            ikon: Icons.shield_rounded,
            baslik: 'Güvenlik',
            aciklama:
                'OpenAI anahtarı Flutter içine gömülmez ve kullanıcıya gösterilmez.',
          ),
          if (_sonHata.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const _Baslik(
              baslik: 'Son Hata',
              aciklama: 'Bağlantı sırasında alınan son hata mesajı.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1F25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF783A47)),
              ),
              child: Text(
                _sonHata,
                style: const TextStyle(
                  color: Color(0xFFFECACA),
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                _backendKontrolEdiliyor ? null : _backendDurumunuKontrolEt,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Sistem durumunu yenile'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF4B860),
              foregroundColor: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoKutusu extends StatelessWidget {
  const _LogoKutusu();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF4B860),
            Color(0xFFDB8E36),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _MesajBalonu extends StatelessWidget {
  const _MesajBalonu({required this.mesaj});

  final _SohbetMesaji mesaj;

  @override
  Widget build(BuildContext context) {
    final bool kullaniciMi = mesaj.kullaniciMi;

    return Align(
      alignment: kullaniciMi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          gradient: kullaniciMi
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFF315C72),
                    Color(0xFF24465B),
                  ],
                )
              : null,
          color: kullaniciMi
              ? null
              : mesaj.hataMi
                  ? const Color(0xFF3A1F25)
                  : const Color(0xFF152536),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(kullaniciMi ? 18 : 5),
            bottomRight: Radius.circular(kullaniciMi ? 5 : 18),
          ),
          border: Border.all(
            color: kullaniciMi
                ? const Color(0xFF47778E)
                : mesaj.hataMi
                    ? const Color(0xFF78404A)
                    : const Color(0xFF2A3C50),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!kullaniciMi) ...<Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    mesaj.hataMi
                        ? Icons.error_outline_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                    color: mesaj.hataMi
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFF4B860),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mesaj.hataMi ? 'Trendora Hata' : 'Trendora AI',
                    style: TextStyle(
                      color: mesaj.hataMi
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFF4B860),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(
              mesaj.metin,
              style: const TextStyle(
                color: Color(0xFFF1F5F9),
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YaziyorBalonu extends StatelessWidget {
  const _YaziyorBalonu();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 145,
        child: Card(
          color: Color(0xFF152536),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFF4B860),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Düşünüyor...',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik({
    required this.baslik,
    required this.aciklama,
  });

  final String baslik;
  final String aciklama;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          baslik,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          aciklama,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DurumKarti extends StatelessWidget {
  const _DurumKarti({
    required this.ikon,
    required this.baslik,
    required this.deger,
    required this.aciklama,
    required this.basarili,
  });

  final IconData ikon;
  final String baslik;
  final String deger;
  final String aciklama;
  final bool basarili;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF142333),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF293C4F)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C3042),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(ikon, color: const Color(0xFFF4B860)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  aciklama,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Icon(
                basarili
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: basarili
                    ? const Color(0xFF34D399)
                    : const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 4),
              Text(
                deger,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BilgiKarti extends StatelessWidget {
  const _BilgiKarti({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF142333),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF293C4F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(ikon, color: const Color(0xFFF4B860)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  aciklama,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SohbetMesaji {
  const _SohbetMesaji({
    required this.metin,
    required this.kullaniciMi,
    this.hataMi = false,
  });

  final String metin;
  final bool kullaniciMi;
  final bool hataMi;
}

