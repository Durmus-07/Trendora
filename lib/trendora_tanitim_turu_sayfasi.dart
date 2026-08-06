import 'package:flutter/material.dart';

class TrendoraTanitimTuruSayfasi extends StatefulWidget {
  const TrendoraTanitimTuruSayfasi({
    required this.onCompleted,
    this.tekrarModu = false,
    super.key,
  });

  final Future<void> Function() onCompleted;
  final bool tekrarModu;

  @override
  State<TrendoraTanitimTuruSayfasi> createState() =>
      _TrendoraTanitimTuruSayfasiState();
}

class _TrendoraTanitimTuruSayfasiState
    extends State<TrendoraTanitimTuruSayfasi> {
  int _adim = 0;
  bool _tamamlaniyor = false;

  static const _adimlar = <_TurAdimi>[
    _TurAdimi(
      baslik: 'Dünya Taranıyor',
      aciklama:
          'Trendora önemli gelişmeleri senin için tek ekranda toplar. Devam etmek için tarama kartına dokun.',
      ikon: Icons.radar_rounded,
      eylem: 'Taramayı dene',
      kartBasligi: 'Dünya şu anda taranıyor',
      kartAciklamasi: 'Haberler, fırsatlar ve yükselen eğilimler inceleniyor.',
    ),
    _TurAdimi(
      baslik: 'Akıllı Arama',
      aciklama:
          'Sorunu günlük dille yazabilirsin. Örnek aramayı çalıştırarak Trendora’nın sonucu nasıl düzenlediğini gör.',
      ikon: Icons.search_rounded,
      eylem: 'Örnek aramayı çalıştır',
      kartBasligi: 'ASELSAN son durum',
      kartAciklamasi: 'Doğrudan cevap, ilgili haberler ve analiz yolu birlikte sunulur.',
    ),
    _TurAdimi(
      baslik: 'Haber Merkezi',
      aciklama:
          'Farklı kaynaklardan gelen haberleri özet, kaynak ve önem bilgileriyle inceleyebilirsin. Örnek haberi aç.',
      ikon: Icons.newspaper_rounded,
      eylem: 'Örnek haberi aç',
      kartBasligi: 'Piyasalarda günün öne çıkan gelişmesi',
      kartAciklamasi: '2 dk okuma • Birden fazla kaynakla doğrulandı',
    ),
    _TurAdimi(
      baslik: 'Fırsatlar Merkezi',
      aciklama:
          'İndirim ve kampanyaları tek yerde karşılaştırabilirsin. Örnek fırsatı incele.',
      ikon: Icons.local_offer_rounded,
      eylem: 'Fırsatı incele',
      kartBasligi: 'Market fırsatı',
      kartAciklamasi: 'Güncel fiyat ve kampanya bilgisi birlikte gösterilir.',
    ),
    _TurAdimi(
      baslik: 'Trend Analiz Merkezi',
      aciklama:
          'Teknik veriler, haberler ve geçmiş sonuçlar birlikte değerlendirilir. Bu bölüm yatırım tavsiyesi değil, veriye dayalı öngörü sunar.',
      ikon: Icons.insights_rounded,
      eylem: 'Analiz örneğini gör',
      kartBasligi: 'Teknik görünüm: Dengeli',
      kartAciklamasi: 'Güven puanı, göstergeler ve risk notları birlikte açıklanır.',
    ),
    _TurAdimi(
      baslik: 'Bildirimler ve Kişiselleştirme',
      aciklama:
          'İlgi alanlarını seçtiğinde Trendora önemli gelişmeleri önceliklendirir ve yalnızca izin verdiğin bildirimleri gönderir.',
      ikon: Icons.notifications_active_rounded,
      eylem: 'Örnek bildirimi dene',
      kartBasligi: 'Takip ettiğin konuda önemli gelişme',
      kartAciklamasi: 'Bildirime dokunduğunda doğrudan ilgili ayrıntı açılır.',
    ),
  ];

  Future<void> _denemeyiAc() async {
    final tamamlandi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrnekDenemeSayfasi(adim: _adimlar[_adim]),
    );

    if (tamamlandi == true && mounted) {
      await _ilerle();
    }
  }

  Future<void> _ilerle() async {
    if (_adim < _adimlar.length - 1) {
      setState(() => _adim += 1);
      return;
    }
    if (_tamamlaniyor) return;
    setState(() => _tamamlaniyor = true);
    try {
      await widget.onCompleted();
    } finally {
      if (mounted) setState(() => _tamamlaniyor = false);
    }
  }

  Future<void> _atla() async {
    if (_tamamlaniyor) return;
    setState(() => _tamamlaniyor = true);
    try {
      await widget.onCompleted();
    } finally {
      if (mounted) setState(() => _tamamlaniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adim = _adimlar[_adim];
    final sonAdim = _adim == _adimlar.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        automaticallyImplyLeading: widget.tekrarModu,
        title: const Text('Trendora’yı Deneyerek Öğren'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _tamamlaniyor ? null : _atla,
            child: Text(widget.tekrarModu ? 'Kapat' : 'Turu Atla'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_adim + 1) / _adimlar.length,
                        minHeight: 7,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF58E6D9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_adim + 1}/${_adimlar.length}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: SingleChildScrollView(
                    key: ValueKey(_adim),
                    child: Column(
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: const Color(0xFF58E6D9).withValues(alpha: .12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF58E6D9).withValues(alpha: .35),
                            ),
                          ),
                          child: Icon(
                            adim.ikon,
                            color: const Color(0xFF58E6D9),
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          adim.baslik,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          adim.aciklama,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC7D2E8),
                            fontSize: 15.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _DenemeKarti(adim: adim, onTap: _denemeyiAc),
                        const SizedBox(height: 18),
                        const Text(
                          'Bu eğitim örnek veriler kullanır; favorilerini, takiplerini veya bildirim ayarlarını değiştirmez.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (sonAdim)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Son adım: örnek bildirime dokun ve turu tamamla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFFD166).withValues(alpha: .9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _OrnekDenemeSayfasi extends StatelessWidget {
  const _OrnekDenemeSayfasi({required this.adim});

  final _TurAdimi adim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: const BoxDecoration(
          color: Color(0xFF07111F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF58E6D9).withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(adim.ikon, color: const Color(0xFF58E6D9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${adim.baslik} denemesi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Bu ekran yalnızca eğitim amaçlı örnek veri kullanır.',
                          style: TextStyle(color: Colors.white54, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _OrnekDenemeIcerigi(adim: adim),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('denemeyi_tamamla'),
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0077FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Denemeyi tamamla ve devam et'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrnekDenemeIcerigi extends StatelessWidget {
  const _OrnekDenemeIcerigi({required this.adim});

  final _TurAdimi adim;

  @override
  Widget build(BuildContext context) {
    final baslik = adim.baslik;

    if (baslik == 'Dünya Taranıyor') {
      return const _OrnekPanel(
        baslik: 'Canlı tarama sonucu',
        rozet: 'TARAMA TAMAMLANDI',
        satirlar: [
          '80 haber kaynağı incelendi',
          '3 önemli gelişme öne çıkarıldı',
          '2 yeni fırsat bulundu',
          '1 yükselen trend tespit edildi',
        ],
      );
    }

    if (baslik == 'Akıllı Arama') {
      return const _OrnekPanel(
        baslik: 'ASELSAN son durum',
        rozet: 'AKILLI CEVAP',
        aciklama:
            'Trendora sorunu doğrudan cevap, ilgili haberler ve analiz bağlantılarıyla tek sonuçta düzenler.',
        satirlar: [
          'Güncel özet hazırlandı',
          'İlgili haberler eşleştirildi',
          'Trend Merkezi yolu önerildi',
        ],
      );
    }

    if (baslik == 'Haber Merkezi') {
      return const _OrnekPanel(
        baslik: 'Piyasalarda günün öne çıkan gelişmesi',
        rozet: 'DOĞRULANMIŞ HABER',
        aciklama:
            'Kısa özet burada görünür. Kaynak, önem seviyesi ve yaklaşık okuma süresi birlikte gösterilir.',
        satirlar: [
          '2 dakika okuma',
          'Birden fazla kaynakla doğrulandı',
          'Tam metin Trendora içinde açılır',
        ],
      );
    }

    if (baslik == 'Fırsatlar Merkezi') {
      return const _OrnekPanel(
        baslik: 'Market fırsatı',
        rozet: '%25 İNDİRİM',
        aciklama:
            'Eski fiyat, güncel fiyat, mağaza ve kampanya koşulları aynı kartta karşılaştırılır.',
        satirlar: [
          'Eski fiyat: 199,90 TL',
          'Güncel fiyat: 149,90 TL',
          'Kampanya bugün geçerli',
        ],
      );
    }

    if (baslik == 'Trend Analiz Merkezi') {
      return const _OrnekPanel(
        baslik: 'Teknik görünüm: Dengeli',
        rozet: 'GÜVEN %72',
        aciklama:
            'Göstergeler, haber etkisi ve risk notları birlikte değerlendirilir. Bu içerik yatırım tavsiyesi değildir.',
        satirlar: [
          'RSI: Nötr bölge',
          'Haber etkisi: Hafif olumlu',
          'Risk seviyesi: Orta',
        ],
      );
    }

    return const _OrnekPanel(
      baslik: 'Takip ettiğin konuda önemli gelişme',
      rozet: 'ÖRNEK BİLDİRİM',
      aciklama:
          'Bildirim seçtiğin ilgi alanına göre hazırlanır ve dokunduğunda doğrudan ilgili ayrıntıyı açar.',
      satirlar: [
        'Yalnızca izin verdiğin bildirimler',
        'Sessiz saatlere uyum',
        'İlgili içeriğe doğrudan geçiş',
      ],
    );
  }
}

class _OrnekPanel extends StatelessWidget {
  const _OrnekPanel({
    required this.baslik,
    required this.rozet,
    required this.satirlar,
    this.aciklama,
  });

  final String baslik;
  final String rozet;
  final String? aciklama;
  final List<String> satirlar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101D2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF58E6D9).withValues(alpha: .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF58E6D9).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rozet,
              style: const TextStyle(
                color: Color(0xFF58E6D9),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            baslik,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (aciklama != null) ...[
            const SizedBox(height: 12),
            Text(
              aciklama!,
              style: const TextStyle(
                color: Color(0xFFC7D2E8),
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ...satirlar.map(
            (satir) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF58E6D9),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      satir,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14.5,
                        height: 1.35,
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
}

class _DenemeKarti extends StatelessWidget {
  const _DenemeKarti({required this.adim, required this.onTap});

  final _TurAdimi adim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101D2E),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF58E6D9).withValues(alpha: .35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(adim.ikon, color: const Color(0xFF58E6D9)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adim.kartBasligi,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                adim.kartAciklamasi,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      adim.eylem,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurAdimi {
  const _TurAdimi({
    required this.baslik,
    required this.aciklama,
    required this.ikon,
    required this.eylem,
    required this.kartBasligi,
    required this.kartAciklamasi,
  });

  final String baslik;
  final String aciklama;
  final IconData ikon;
  final String eylem;
  final String kartBasligi;
  final String kartAciklamasi;
}
