import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/news/saved_news_store.dart';
import 'package:trendora_app/haber_detay_sayfasi.dart';
import 'package:trendora_app/haberler_sayfasi.dart';

void main() {
  testWidgets('news detail shows real fields and runs explicit actions', (
    tester,
  ) async {
    var sourceOpened = false;
    var shared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HaberDetaySayfasi(
          title: 'Trendora uygulama içi haber',
          imageUrl: '',
          source: 'Trendora Haber',
          publishedAt: DateTime(2026, 7, 29, 11, 30),
          summary: 'Doğrulanmış haber özeti.',
          articleText: 'Kaynaktan gelen haber metni.',
          url: 'https://example.com/news',
          onOpenSource: () async {
            sourceOpened = true;
            return true;
          },
          onShare: () async {
            shared = true;
          },
        ),
      ),
    );

    expect(find.text('Trendora uygulama içi haber'), findsOneWidget);
    expect(find.text('Trendora Haber'), findsOneWidget);
    expect(find.text('29.07.2026 • 11:30'), findsOneWidget);

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('haber-detay-kaydirma-alani')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Doğrulanmış haber özeti.'),
      200,
      scrollable: detailScrollable,
    );
    expect(find.text('Doğrulanmış haber özeti.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Kaynaktan gelen haber metni.'),
      200,
      scrollable: detailScrollable,
    );
    expect(find.text('Kaynaktan gelen haber metni.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-kaynaga-git')),
      300,
      scrollable: detailScrollable,
    );
    await tester.tap(find.byKey(const Key('haber-kaynaga-git')));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('haber-paylas'))),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('haber-paylas')));
    await tester.pump();

    expect(sourceOpened, isTrue);
    expect(shared, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing article data is stated honestly without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(288, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HaberDetaySayfasi(
          title:
              'Dar ekranda uzun bir haber başlığı güvenli biçimde gösterilir',
          imageUrl: '',
          source: 'Uzun Haber Kaynağı Adı',
          publishedAt: DateTime(2026, 7, 29, 9),
          summary: '',
          articleText: '',
          url: '',
          onShare: () async {},
        ),
      ),
    );

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('haber-detay-kaydirma-alani')),
      matching: find.byType(Scrollable),
    );
    final missingArticle = find.textContaining(
      'Haberin tam metni kaynaktan sağlanmadı.',
    );
    await tester.scrollUntilVisible(
      missingArticle,
      200,
      scrollable: detailScrollable,
    );
    expect(missingArticle, findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-paylas')),
      300,
      scrollable: detailScrollable,
    );
    expect(find.byKey(const Key('haber-kaynaga-git')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail derives importance and shows related news', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HaberDetaySayfasi(
          id: 'main-news',
          title: 'BIST şirketleri için yeni karar',
          imageUrl: '',
          source: 'Ekonomi Kaynağı',
          publishedAt: DateTime(2026, 7, 29, 9),
          summary: 'Karar borsa ve şirketleri etkileyebilir.',
          articleText: 'Gelişmenin ayrıntıları açıklandı.',
          url: 'https://example.com/main',
          category: 'ekonomi',
          relatedNews: [
            RelatedNewsItem(
              id: 'related-news',
              title: 'Piyasalarda günün gelişmeleri',
              imageUrl: '',
              source: 'Piyasa Kaynağı',
              publishedAt: DateTime(2026, 7, 29, 8),
              summary: 'Piyasa özeti',
              articleText: 'Piyasa metni',
              url: 'https://example.com/related',
              category: 'ekonomi',
            ),
          ],
        ),
      ),
    );

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('haber-detay-kaydirma-alani')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Neden Önemli?'),
      250,
      scrollable: detailScrollable,
    );
    expect(
      find.text('BIST şirketlerini ve yatırımcı kararlarını etkileyebilir.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Benzer Haberler'),
      400,
      scrollable: detailScrollable,
    );
    expect(find.text('Piyasalarda günün gelişmeleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Trendora explains supplied Turkish content without investment advice',
    (tester) async {
      const translatedTitle = 'FED faiz kararı sonrası altın gündemde';
      const translatedSummary =
          'ABD Merkez Bankası enflasyon gelişmelerini değerlendirdi.';

      await tester.pumpWidget(
        MaterialApp(
          home: HaberDetaySayfasi(
            id: 'explained-news',
            title: translatedTitle,
            imageUrl: '',
            source: 'Global News Türkçe',
            publishedAt: DateTime(2026, 7, 29, 9),
            summary: translatedSummary,
            articleText: 'DXY ve tahvil piyasaları kararı izliyor.',
            url: 'https://example.com/explained',
            category: 'ekonomi',
          ),
        ),
      );

      expect(find.text(translatedTitle), findsOneWidget);
      expect(find.text('Global News Türkçe'), findsOneWidget);

      final detailScrollable = find.descendant(
        of: find.byKey(const Key('haber-detay-kaydirma-alani')),
        matching: find.byType(Scrollable),
      );
      final assessmentCard = find.byKey(const Key('trendora-degerlendirmesi'));
      await tester.scrollUntilVisible(
        assessmentCard,
        300,
        scrollable: detailScrollable,
      );
      expect(find.text('Trendora Analizi'), findsOneWidget);
      expect(find.text('Borsa Etkisi'), findsOneWidget);
      expect(find.text('Bankacılık Etkisi'), findsOneWidget);
      expect(find.text('Altın Etkisi'), findsOneWidget);
      expect(find.text('Döviz Etkisi'), findsOneWidget);
      expect(find.text('Kripto Etkisi'), findsOneWidget);
      expect(find.text('Petrol Etkisi'), findsOneWidget);
      expect(find.text('Etkilenen sektörler'), findsOneWidget);
      expect(find.text('Etkilenen şirketler'), findsOneWidget);
      expect(find.text('Genel piyasa etkisi'), findsOneWidget);
      expect(find.text('Risk seviyesi'), findsOneWidget);
      expect(find.text('Etkilenen Varlıklar'), findsOneWidget);
      expect(find.textContaining('Güven Seviyesi:'), findsOneWidget);
      expect(find.textContaining('ETKİ / 100'), findsOneWidget);
      expect(find.text('Önem seviyesi'), findsOneWidget);
      expect(find.text('Finansal ilgi'), findsOneWidget);
      expect(find.text('Kaynak sınıfı'), findsOneWidget);
      expect(find.text('Güncellik'), findsOneWidget);
      expect(
        find.text(
          'Bu değerlendirme Trendora tarafından oluşturulmuştur. '
          'Yatırım tavsiyesi değildir.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('getiri vaadi değildir'), findsOneWidget);

      final explainsCard = find.byKey(const Key('trendora-acikliyor'));
      await tester.scrollUntilVisible(
        explainsCard,
        300,
        scrollable: detailScrollable,
      );

      expect(find.text('🧠 Trendora Açıklıyor'), findsOneWidget);
      expect(find.text('FED'), findsOneWidget);
      expect(find.text('Faiz'), findsOneWidget);
      expect(find.text('Olası Etkiler'), findsOneWidget);
      expect(
        find.text(
          'Bu açıklama yalnızca bilgilendirme amacıyla Trendora tarafından '
          'otomatik olarak hazırlanmıştır. Yatırım tavsiyesi değildir.',
        ),
        findsOneWidget,
      );

      final cardText = tester
          .widgetList<Text>(
            find.descendant(of: explainsCard, matching: find.byType(Text)),
          )
          .map((widget) => widget.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(
        RegExp(r'(^|\s)(al|sat|tut)(\s|[.!?,;:]|$)').hasMatch(cardText),
        isFalse,
      );
      expect(cardText, isNot(contains('kesin yükselecek')));
      expect(cardText, isNot(contains('kesin düşecek')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('news cards show at most two meaningful intelligence badges', (
    tester,
  ) async {
    final news = [
      TrendoraHaber(
        id: 'high-finance',
        title: 'TCMB faiz kararı KAP ve BIST gündemini etkiledi',
        description: 'Bankacılık ve dolar piyasaları kararı izliyor.',
        content: '',
        url: 'https://example.com/high-finance',
        imageUrl: '',
        source: 'Türkiye Cumhuriyet Merkez Bankası',
        feedSource: 'Ekonomi Akışı',
        category: 'ekonomi',
        publishedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        isBreaking: false,
        trendScore: 80,
        confidenceScore: 95,
      ),
      TrendoraHaber(
        id: 'official-general',
        title: 'Kurum çalışma takvimini duyurdu',
        description: 'Yeni çalışma takvimi kamuoyuyla paylaşıldı.',
        content: '',
        url: 'https://example.com/official-general',
        imageUrl: '',
        source: 'Sermaye Piyasası Kurulu',
        feedSource: 'Genel Akış',
        category: 'gundem',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        isBreaking: false,
        trendScore: 10,
        confidenceScore: 90,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.test(news: news)),
    );

    final highFinanceCard = find.byKey(
      const ValueKey<String>('haber-karti-high-finance'),
    );
    final highFinanceLabels = tester
        .widgetList<Text>(
          find.descendant(of: highFinanceCard, matching: find.byType(Text)),
        )
        .map((widget) => widget.data)
        .where(
          (label) => const {
            'ÖNEMLİ',
            'FİNANS ODAKLI',
            'RESMÎ KAYNAK',
            'TREND',
            'EKONOMİ',
          }.contains(label),
        )
        .toList();
    expect(highFinanceLabels, ['ÖNEMLİ', 'FİNANS ODAKLI']);

    final listScrollable = find.descendant(
      of: find.byKey(const PageStorageKey<String>('haber-merkezi-listesi')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Kurum çalışma takvimini duyurdu'),
      350,
      scrollable: listScrollable,
    );
    final officialCard = find.byKey(
      const ValueKey<String>('haber-karti-official-general'),
    );
    expect(
      find.descendant(of: officialCard, matching: find.text('RESMÎ KAYNAK')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'multi-source event opens chronological source detail without changing badges',
    (tester) async {
      final publishedAt = DateTime(2026, 7, 29, 11);
      final news = TrendoraHaber(
        id: 'event-main',
        title: 'TCMB faiz kararı açıklandı politika faizi sabit kaldı',
        originalTitle: 'Central bank keeps the policy rate unchanged',
        description: 'Kararın ayrıntıları kamuoyuyla paylaşıldı.',
        content: '',
        url: 'https://example.com/event-main',
        imageUrl: '',
        source: 'Anadolu Ajansı',
        feedSource: 'Ekonomi Akışı',
        category: 'ekonomi',
        publishedAt: publishedAt,
        isBreaking: false,
        trendScore: 70,
        confidenceScore: 90,
        sourceCount: 2,
        confirmingSources: const ['Anadolu Ajansı', 'Reuters'],
        relatedStories: [
          TrendoraRelatedStory(
            title: 'TCMB faiz kararı: politika faizi sabit kaldı',
            originalTitle: 'Central bank leaves interest rate unchanged',
            source: 'Reuters',
            url: 'https://example.com/event-reuters',
            publishedAt: publishedAt.subtract(const Duration(minutes: 12)),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: HaberlerSayfasi.test(news: [news])),
      );

      expect(find.text('2 farklı kaynak'), findsOneWidget);
      final card = find.byKey(const ValueKey<String>('haber-karti-event-main'));
      final badgeLabels = tester
          .widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )
          .map((widget) => widget.data)
          .where(
            (label) => const {
              'ÖNEMLİ',
              'FİNANS ODAKLI',
              'RESMÎ KAYNAK',
              'TREND',
              'EKONOMİ',
            }.contains(label),
          )
          .toList();
      expect(badgeLabels.length, lessThanOrEqualTo(2));

      final sourceAction = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('olay-kaynak-'),
      );
      expect(sourceAction, findsOneWidget);
      await tester.ensureVisible(sourceAction);
      await tester.pumpAndSettle();
      await tester.tap(sourceAction);
      await tester.pumpAndSettle();

      expect(find.text('Gelişme Akışı'), findsOneWidget);
      expect(find.text('Bu Gelişmeyle İlgili Haberler'), findsOneWidget);
      expect(find.text('Anadolu Ajansı'), findsOneWidget);
      expect(find.text('Reuters'), findsOneWidget);
      expect(find.text('ANA HABER'), findsOneWidget);
      expect(
        find.textContaining('otomatik olarak gruplandırılmıştır'),
        findsOneWidget,
      );
      expect(find.textContaining('Orijinal: Central bank'), findsWidgets);

      final reutersNews = find.byKey(
        const ValueKey<String>('olay-haberi-https://example.com/event-reuters'),
      );
      await tester.ensureVisible(reutersNews);
      await tester.pumpAndSettle();
      await tester.tap(reutersNews);
      await tester.pumpAndSettle();

      expect(find.text('Haber Detayı'), findsOneWidget);
      expect(find.text('Reuters'), findsWidgets);
      expect(
        find.text('TCMB faiz kararı: politika faizi sabit kaldı'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save action persists and removes the complete news record', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: HaberDetaySayfasi(
          id: 'saved-news',
          title: 'Kaydedilecek haber',
          imageUrl: '',
          source: 'Trendora Haber',
          publishedAt: DateTime(2026, 7, 29, 10),
          summary: 'Kaydedilecek özet',
          articleText: 'Kaydedilecek tam metin',
          url: 'https://example.com/saved',
          category: 'gundem',
        ),
      ),
    );

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('haber-detay-kaydirma-alani')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-kaydet')),
      400,
      scrollable: detailScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('haber-kaydet')));
    await tester.pumpAndSettle();

    var saved = await SavedNewsStore.load();
    expect(saved, hasLength(1));
    expect(saved.single.id, 'saved-news');
    expect(saved.single.articleText, 'Kaydedilecek tam metin');

    await tester.tap(find.byKey(const Key('haber-kaydet')));
    await tester.pumpAndSettle();
    saved = await SavedNewsStore.load();
    expect(saved, isEmpty);
  });

  testWidgets('returning from detail preserves news list scroll position', (
    tester,
  ) async {
    final news = List<TrendoraHaber>.generate(
      14,
      (index) => TrendoraHaber(
        id: 'news-$index',
        title: 'Haber ${index + 1}',
        description: 'Haber ${index + 1} özeti',
        content: 'Haber ${index + 1} metni',
        url: 'https://example.com/news-$index',
        imageUrl: '',
        source: 'Test Kaynağı',
        feedSource: 'Test Akışı',
        category: 'genel',
        publishedAt: DateTime(2026, 7, 29).subtract(Duration(minutes: index)),
        isBreaking: false,
        trendScore: 50,
        confidenceScore: 80,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.test(news: news)),
    );

    final listScrollable = find.descendant(
      of: find.byKey(const PageStorageKey<String>('haber-merkezi-listesi')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Haber 10'),
      500,
      scrollable: listScrollable,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Haber 10')),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    final positionBefore = tester
        .state<ScrollableState>(listScrollable)
        .position
        .pixels;

    await tester.tap(find.text('Haber 10'));
    await tester.pumpAndSettle();
    expect(find.text('Haber Detayı'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final positionAfter = tester
        .state<ScrollableState>(listScrollable)
        .position
        .pixels;
    expect(positionAfter, closeTo(positionBefore, 0.1));
    expect(find.text('Haber 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'news center hides empty source counters and varies placeholders',
    (tester) async {
      final news = [
        TrendoraHaber(
          id: 'technology',
          title: 'Yeni teknoloji haberi',
          description: 'Teknoloji özeti',
          content: '',
          url: 'https://example.com/technology',
          imageUrl: '',
          source: 'Teknoloji Kaynağı',
          feedSource: '',
          category: 'teknoloji',
          publishedAt: DateTime(2026, 7, 29),
          isBreaking: false,
          trendScore: 20,
          confidenceScore: 80,
        ),
        TrendoraHaber(
          id: 'sport',
          title: 'Yeni spor haberi',
          description: 'Spor özeti',
          content: '',
          url: 'https://example.com/sport',
          imageUrl: '',
          source: 'Spor Kaynağı',
          feedSource: '',
          category: 'spor',
          publishedAt: DateTime(2026, 7, 28),
          isBreaking: false,
          trendScore: 20,
          confidenceScore: 80,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HaberlerSayfasi.test(news: news)),
      );

      expect(find.textContaining('0 / 0'), findsNothing);
      expect(find.textContaining('Sayfa '), findsNothing);
      expect(find.text('2 yeni haber'), findsOneWidget);
      expect(find.textContaining('farklı kaynak'), findsNothing);
      expect(find.byIcon(Icons.memory_rounded), findsWidgets);

      final listScrollable = find.descendant(
        of: find.byKey(const PageStorageKey<String>('haber-merkezi-listesi')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Yeni spor haberi'),
        350,
        scrollable: listScrollable,
      );
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('premium feed presents hero large standard and compact cards', (
    tester,
  ) async {
    final now = DateTime.now();
    final news = [
      TrendoraHaber(
        id: 'premium-0',
        title: 'Merkez Bankası enflasyon raporunu yayımladı',
        description: 'Piyasaların izlediği rapor kamuoyuyla paylaşıldı.',
        content: List.filled(420, 'ekonomi').join(' '),
        url: 'https://example.com/premium-0',
        imageUrl: '',
        source: 'Trendora Ekonomi',
        feedSource: 'Ekonomi Akışı',
        category: 'ekonomi',
        publishedAt: now.subtract(const Duration(minutes: 10)),
        isBreaking: true,
        trendScore: 92,
        confidenceScore: 96,
        sourceCount: 3,
        confirmingSources: const ['Trendora Ekonomi', 'Reuters', 'AA'],
      ),
      TrendoraHaber(
        id: 'premium-1',
        title: 'Yeni nesil işlemci teknoloji dünyasına tanıtıldı',
        description: 'Üretici performans ve verimlilik ayrıntılarını açıkladı.',
        content: 'Teknoloji haberinin tüm ayrıntıları.',
        url: 'https://example.com/premium-1',
        imageUrl: '',
        source: 'Teknoloji Gündemi',
        feedSource: 'Teknoloji Akışı',
        category: 'teknoloji',
        publishedAt: now.subtract(const Duration(minutes: 20)),
        isBreaking: false,
        trendScore: 72,
        confidenceScore: 88,
      ),
      TrendoraHaber(
        id: 'premium-2',
        title: 'Milli takım hazırlık maçını kazandı',
        description: 'Karşılaşmanın öne çıkan anları belli oldu.',
        content: 'Spor haberinin tüm ayrıntıları.',
        url: 'https://example.com/premium-2',
        imageUrl: '',
        source: 'Spor Merkezi',
        feedSource: 'Spor Akışı',
        category: 'spor',
        publishedAt: now.subtract(const Duration(minutes: 30)),
        isBreaking: false,
        trendScore: 66,
        confidenceScore: 84,
      ),
      TrendoraHaber(
        id: 'premium-3',
        title: 'Petrol üretim planı enerji piyasasına açıklandı',
        description: 'Yeni üretim takvimi küresel piyasalarda izleniyor.',
        content: 'Enerji haberinin tüm ayrıntıları.',
        url: 'https://example.com/premium-3',
        imageUrl: '',
        source: 'Enerji Haber',
        feedSource: 'Dünya Akışı',
        category: 'dunya',
        publishedAt: now.subtract(const Duration(minutes: 40)),
        isBreaking: false,
        trendScore: 58,
        confidenceScore: 80,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.test(news: news)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('haber-kart-tipi-hero-premium-0')),
      findsOneWidget,
    );
    expect(find.text('GÜNÜN ÖNE ÇIKANI'), findsOneWidget);
    expect(find.textContaining('3 güvenilir kaynak doğruladı'), findsOneWidget);
    expect(find.textContaining('dk okuma'), findsWidgets);
    expect(find.textContaining('Önem '), findsWidgets);
    expect(find.textContaining('Güven '), findsWidgets);

    final listScrollable = find.descendant(
      of: find.byKey(const PageStorageKey<String>('haber-merkezi-listesi')),
      matching: find.byType(Scrollable),
    );
    for (final entry in const [
      (
        'premium-1',
        'large',
        'Yeni nesil işlemci teknoloji dünyasına tanıtıldı',
      ),
      ('premium-2', 'standard', 'Milli takım hazırlık maçını kazandı'),
      (
        'premium-3',
        'compact',
        'Petrol üretim planı enerji piyasasına açıklandı',
      ),
    ]) {
      final card = find.byKey(
        ValueKey<String>('haber-kart-tipi-${entry.$2}-${entry.$1}'),
      );
      for (var attempt = 0; attempt < 6 && card.evaluate().isEmpty; attempt++) {
        await tester.drag(listScrollable, const Offset(0, -360));
        await tester.pumpAndSettle();
      }
      expect(card, findsOneWidget);
      expect(find.text(entry.$3), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('long article reports reading progress and remaining time', (
    tester,
  ) async {
    final longArticle = List<String>.generate(
      1500,
      (index) => 'haber${index % 17}',
    ).join(' ');

    await tester.pumpWidget(
      MaterialApp(
        home: HaberDetaySayfasi(
          title: 'Uzun haber okuma deneyimi',
          imageUrl: '',
          source: 'Trendora Haber',
          publishedAt: DateTime(2026, 7, 30, 9),
          summary: 'Uzun haberin kısa bakışı.',
          articleText: longArticle,
          url: 'https://example.com/long-read',
        ),
      ),
    );
    await tester.pumpAndSettle();

    LinearProgressIndicator indicator = tester.widget(
      find.byKey(const Key('haber-okuma-ilerlemesi')),
    );
    expect(indicator.value, 0);
    expect(find.text('8 dk kaldı'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('haber-detay-kaydirma-alani')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    indicator = tester.widget(find.byKey(const Key('haber-okuma-ilerlemesi')));
    expect(indicator.value, greaterThan(0));
    expect(find.byKey(const Key('haber-kalan-okuma')), findsOneWidget);
    expect(find.textContaining('dk kaldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('news model keeps optional full text backwards compatible', () {
    final withContent = TrendoraHaber.fromJson({
      'id': '1',
      'title': 'Başlık',
      'summary': 'Özet',
      'fullText': 'Tam haber metni',
      'publishedAt': '2026-07-29T08:00:00Z',
    });
    final legacy = TrendoraHaber.fromJson({
      'id': '2',
      'title': 'Eski kayıt',
      'description': 'Eski özet',
      'publishedAt': '2026-07-29T08:00:00Z',
    });
    final invalidDate = TrendoraHaber.fromJson({
      'id': '3',
      'title': 'Tarihi geçersiz kayıt',
      'publishedAt': 'geçersiz-tarih',
    });
    final clustered = TrendoraHaber.fromJson({
      'id': '4',
      'title': 'Kümelenmiş haber',
      'publishedAt': '2026-07-29T08:00:00Z',
      'sourceCount': 2,
      'confirmingSources': ['Kaynak A', 'Kaynak B'],
      'relatedStories': [
        {
          'title': 'Aynı gelişmenin ikinci haberi',
          'source': 'Kaynak B',
          'url': 'https://example.com/related',
          'publishedAt': '2026-07-29T07:50:00Z',
        },
      ],
    });

    expect(withContent.description, 'Özet');
    expect(withContent.content, 'Tam haber metni');
    expect(legacy.description, 'Eski özet');
    expect(legacy.content, isEmpty);
    expect(withContent.hasValidPublishedAt, isTrue);
    expect(invalidDate.hasValidPublishedAt, isFalse);
    expect(clustered.sourceCount, 2);
    expect(clustered.confirmingSources, ['Kaynak A', 'Kaynak B']);
    expect(clustered.relatedStories, hasLength(1));
    expect(clustered.relatedStories.single.source, 'Kaynak B');
  });
}
