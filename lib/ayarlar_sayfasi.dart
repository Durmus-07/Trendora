import 'package:flutter/material.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _baslik('Kişiselleştirme'),
          _menu(
            context,
            ikon: Icons.person_outline,
            baslik: 'Hesabım',
            altBaslik: 'Yakında',
            yakinda: true,
          ),
          _menu(
            context,
            ikon: Icons.smart_toy_outlined,
            baslik: 'Trendora AI Ayarları',
            altBaslik: 'Yakında',
            yakinda: true,
          ),
          _menu(
            context,
            ikon: Icons.notifications_none,
            baslik: 'Bildirimler',
            altBaslik: 'Alarm ve bildirim tercihleri',
            yakinda: true,
          ),
          _menu(
            context,
            ikon: Icons.dark_mode_outlined,
            baslik: 'Görünüm',
            altBaslik: 'Tema seçenekleri',
            yakinda: true,
          ),
          _menu(
            context,
            ikon: Icons.language,
            baslik: 'Dil',
            altBaslik: 'Türkçe',
            yakinda: true,
          ),

          const SizedBox(height: 18),
          _baslik('Trendora'),
          _menu(
            context,
            ikon: Icons.workspace_premium_outlined,
            baslik: 'Premium',
            altBaslik: 'Gelişmiş özellikleri keşfet',
            yakinda: true,
          ),
          _menu(
            context,
            ikon: Icons.insights_outlined,
            baslik: 'Trendora Skoru',
            altBaslik: 'Puanlama sistemimiz nasıl çalışır?',
            sayfa: const BilgiSayfasi(
              baslik: 'Trendora Skoru',
              ikon: Icons.insights,
              icerik: '''
Trendora Skoru, farklı veri kaynaklarının analiz edilmesiyle oluşturulan değerlendirme puanıdır.

Puanlama sırasında güncel fiyat, fiyat geçmişi, gerçek indirim oranı, talep eğilimi, popülerlik, kampanyalar, piyasa hareketleri ve güncel veriler birlikte değerlendirilir.

Trendora Skoru yatırım, finans veya satın alma tavsiyesi değildir. Yalnızca kullanıcıların verileri daha kolay anlamasına yardımcı olmak amacıyla sunulur.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.storage_outlined,
            baslik: 'Veri Kaynakları',
            altBaslik: 'Analizlerde kullanılan kaynaklar',
            sayfa: const BilgiSayfasi(
              baslik: 'Veri Kaynakları',
              ikon: Icons.storage,
              icerik: '''
Trendora; kamuya açık, lisanslı ve güvenilir veri kaynaklarından yararlanmayı hedefler.

Finansal piyasa verileri, ekonomik göstergeler, haber kaynakları, alışveriş platformları, kampanyalar, araç piyasası verileri ve kullanıcı eğilimleri analizlerde birlikte değerlendirilebilir.

Verilerin güncelliği, kullanılan kaynağın yayın sıklığına göre değişebilir.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.help_outline,
            baslik: 'Sık Sorulan Sorular',
            altBaslik: 'Trendora hakkında merak edilenler',
            sayfa: const BilgiSayfasi(
              baslik: 'Sık Sorulan Sorular',
              ikon: Icons.help_outline,
              icerik: '''
Trendora yatırım tavsiyesi verir mi?

Hayır. Trendora verileri analiz eder, puanlar ve anlaşılır biçimde sunar.

Trendora Skoru nasıl oluşturulur?

Fiyat geçmişi, güncel değer, talep eğilimi, popülerlik, kampanyalar ve farklı piyasa göstergeleri birlikte analiz edilir.

Veriler ne kadar günceldir?

Veriler, desteklenen kaynakların güncelleme sıklığına göre mümkün olan en güncel şekilde sunulur.
''',
            ),
          ),

          const SizedBox(height: 18),
          _baslik('Yasal ve Destek'),
          _menu(
            context,
            ikon: Icons.privacy_tip_outlined,
            baslik: 'Gizlilik Politikası',
            altBaslik: 'Verilerinizin korunması',
            sayfa: const BilgiSayfasi(
              baslik: 'Gizlilik Politikası',
              ikon: Icons.privacy_tip_outlined,
              icerik: '''
Trendora kullanıcı gizliliğine önem verir.

Kişisel verilerin yürürlükteki yasal düzenlemelere uygun biçimde korunması ve yalnızca hizmet kalitesini geliştirmek amacıyla işlenmesi hedeflenir.

Bu bölüm, uygulama yayınlanmadan önce hazırlanacak resmî gizlilik politikası ile güncellenecektir.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.description_outlined,
            baslik: 'Kullanım Koşulları',
            altBaslik: 'Platform kullanım şartları',
            sayfa: const BilgiSayfasi(
              baslik: 'Kullanım Koşulları',
              ikon: Icons.description_outlined,
              icerik: '''
Trendora içerisinde sunulan içerikler bilgilendirme ve analiz amaçlıdır.

Platform yatırım, finans, hukuk veya satın alma tavsiyesi vermez. Kullanıcılar kendi kararlarından sorumludur.

Bu bölüm, yayın öncesinde hazırlanacak resmî kullanım koşulları ile güncellenecektir.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.mail_outline,
            baslik: 'İletişim',
            altBaslik: 'Öneri, destek ve iş birlikleri',
            sayfa: const BilgiSayfasi(
              baslik: 'İletişim',
              ikon: Icons.mail_outline,
              icerik: '''
Sorularınız, önerileriniz ve iş birliği talepleriniz için Trendora ekibine ulaşabilirsiniz.

İletişim bilgileri ve resmî destek kanalları uygulama yayınlanmadan önce bu bölüme eklenecektir.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.feedback_outlined,
            baslik: 'Geri Bildirim Gönder',
            altBaslik: 'Trendora’yı geliştirmemize yardımcı olun',
            yakinda: true,
          ),

          const SizedBox(height: 18),
          _baslik('Uygulama'),
          _menu(
            context,
            ikon: Icons.info_outline,
            baslik: 'Hakkında',
            altBaslik: 'Trendora’yı yakından tanıyın',
            sayfa: const BilgiSayfasi(
              baslik: 'Trendora Hakkında',
              ikon: Icons.auto_awesome,
              icerik: '''
Trendora, yapay zekâ destekli dijital karar platformudur.

Finans, borsa, kripto varlıklar, döviz, altın, haberler, alışveriş, kampanyalar, ürünler, araç piyasası ve güncel trendleri tek ekosistemde bir araya getirir.

Trendora yatırım veya satın alma tavsiyesi vermez. Güncel verileri analiz eder; fiyat uygunluğunu, gerçek indirimleri, yeni kampanyaları, talep eğilimlerini, popülerlik değişimlerini ve piyasa hareketlerini anlaşılır şekilde sunar.

Trendora Skoru sayesinde ürünler, varlıklar ve farklı seçenekler belirli kriterlere göre puanlanarak kullanıcıların kendi kararlarını daha bilinçli vermelerine yardımcı olunur.

Amacımız, karmaşık verileri sadeleştirerek insanların zaman kazanmasını ve günlük kararlarını daha güvenilir bilgilerle vermesini sağlamaktır.

Trendora; veriyi analiz eder, puanlar ve karar vermeyi kolaylaştırır.
''',
            ),
          ),
          _menu(
            context,
            ikon: Icons.rocket_launch_outlined,
            baslik: 'Sürüm Bilgisi',
            altBaslik: 'Trendora v1.0.0',
            sayfa: const BilgiSayfasi(
              baslik: 'Sürüm Bilgisi',
              ikon: Icons.rocket_launch_outlined,
              icerik: '''
Trendora

Sürüm: 1.0.0

Yapay zekâ destekli dijital karar platformu.

© 2026 Trendora
''',
            ),
          ),

          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Trendora • Veriyi analiz eder, puanlar\nve karar vermeyi kolaylaştırır.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _baslik(String metin) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        metin.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF58E6D9),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _menu(
    BuildContext context, {
    required IconData ikon,
    required String baslik,
    required String altBaslik,
    Widget? sayfa,
    bool yakinda = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF58E6D9).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            ikon,
            color: const Color(0xFF58E6D9),
          ),
        ),
        title: Text(
          baslik,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          altBaslik,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: yakinda
            ? const Text(
                'Yakında',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              )
            : const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
        onTap: () {
          if (yakinda) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$baslik özelliği yakında eklenecek.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          if (sayfa != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => sayfa),
            );
          }
        },
      ),
    );
  }
}

class BilgiSayfasi extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  final String icerik;

  const BilgiSayfasi({
    super.key,
    required this.baslik,
    required this.ikon,
    required this.icerik,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: Text(baslik),
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF101D2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF58E6D9).withOpacity(0.18),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF58E6D9).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ikon,
                  size: 36,
                  color: const Color(0xFF58E6D9),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                baslik,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                icerik.trim(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}