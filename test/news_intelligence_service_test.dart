import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/news/news_intelligence_service.dart';

void main() {
  final now = DateTime.utc(2026, 7, 29, 12);

  NewsIntelligenceService service({int cacheSize = 256}) {
    return NewsIntelligenceService(
      maximumCacheItems: cacheSize,
      now: () => now,
    );
  }

  NewsIntelligenceResult evaluate(
    NewsIntelligenceService subject, {
    String id = 'news',
    String title = 'Günün gelişmeleri',
    String summary = '',
    String articleText = '',
    String category = 'gundem',
    String source = 'Bilinmeyen Yerel Kaynak',
    String feedSource = 'Genel Akış',
    DateTime? publishedAt,
    bool isBreaking = false,
    int sourceCount = 1,
    int confirmingSourceCount = 0,
  }) {
    return subject.evaluate(
      newsId: id,
      title: title,
      summary: summary,
      articleText: articleText,
      category: category,
      source: source,
      feedSource: feedSource,
      publishedAt: publishedAt ?? now.subtract(const Duration(hours: 1)),
      isBreaking: isBreaking,
      sourceCount: sourceCount,
      confirmingSourceCount: confirmingSourceCount,
    );
  }

  test('TCMB and KAP news receives high financial relevance', () {
    final result = evaluate(
      service(),
      title: 'TCMB faiz kararı KAP üzerinden duyuruldu',
      summary: 'Karar BIST ve bankacılık sektörünü ilgilendiriyor.',
      category: 'ekonomi',
      source: 'Türkiye Cumhuriyet Merkez Bankası',
    );

    expect(result.financialRelevanceScore, greaterThanOrEqualTo(70));
    expect(result.importanceScore, greaterThanOrEqualTo(70));
    expect(result.source.level, NewsSourceLevel.official);
    expect(result.matchedSignals, contains('merkez bankası kararı'));
    expect(result.matchedSignals, contains('resmî finansal düzenleme'));
  });

  test('sports news does not receive an unnecessary financial score', () {
    final result = evaluate(
      service(),
      title: 'Takım yeni sezonun ilk antrenmanına çıktı',
      summary: 'Teknik ekip hazırlık programını açıkladı.',
      category: 'spor',
      source: 'Fanatik',
    );

    expect(result.financialRelevanceScore, 0);
    expect(result.financialReason, contains('bağlantısı bulunmadı'));
    expect(result.matchedSignals, isEmpty);
  });

  test('unrelated news does not invent institutions or market concepts', () {
    final result = evaluate(
      service(),
      title: 'Kent parkında yeni yürüyüş rotası açıldı',
      summary: 'Belediye peyzaj çalışmalarının tamamlandığını bildirdi.',
      category: 'yasam',
    );
    final output = [
      result.importanceReason,
      result.financialReason,
      ...result.matchedSignals,
    ].join(' ').toLowerCase();

    expect(result.matchedSignals, isEmpty);
    expect(output, isNot(contains('tcmb')));
    expect(output, isNot(contains('bist')));
    expect(output, isNot(contains('kap')));
  });

  test('official sources are classified without guaranteeing accuracy', () {
    final result = evaluate(service(), source: 'Sermaye Piyasası Kurulu');

    expect(result.source.level, NewsSourceLevel.official);
    expect(result.source.label, 'Resmî Kaynak');
    expect(result.source.reason, contains('kesin garantisi değildir'));
  });

  test('unknown source only reports limited source information', () {
    final result = evaluate(
      service(),
      source: 'Örnek Bölgesel Yayın',
      feedSource: 'Toplayıcı Akışı',
    );

    expect(result.source.level, NewsSourceLevel.limited);
    expect(result.source.label, 'Kaynak Bilgisi Sınırlı');
    expect(result.source.reason.toLowerCase(), isNot(contains('güvenilmez')));
    expect(result.source.reason, contains('kesin bir iddia üretilmedi'));
  });

  test('current and old news receive different freshness levels', () {
    final current = evaluate(
      service(),
      id: 'current',
      publishedAt: now.subtract(const Duration(hours: 6)),
    );
    final old = evaluate(
      service(),
      id: 'old',
      publishedAt: now.subtract(const Duration(days: 10)),
    );

    expect(current.freshness.level, NewsFreshnessLevel.current);
    expect(current.freshness.label, 'Güncel');
    expect(old.freshness.level, NewsFreshnessLevel.old);
    expect(old.freshness.label, 'Eski');
    expect(current.freshness.score, greaterThan(old.freshness.score));
  });

  test('missing date is handled safely and honestly', () {
    final subject = service();
    final result = subject.evaluate(
      newsId: 'missing-date',
      title: 'Tarihsiz haber',
      summary: '',
      articleText: '',
      category: 'gundem',
      source: '',
      feedSource: '',
      publishedAt: null,
      isBreaking: false,
    );

    expect(result.freshness.level, NewsFreshnessLevel.unknown);
    expect(result.freshness.label, 'Tarih Bilgisi Yok');
    expect(result.freshness.score, 0);
  });

  test('all generated scores remain in the zero to one hundred range', () {
    final scenarios = [
      evaluate(service(), id: 'low'),
      evaluate(
        service(),
        id: 'high',
        title: 'SON DAKİKA: TCMB faiz ve enflasyon kararını açıkladı',
        summary: 'KAP, BIST, dolar, altın, petrol ve banka hisseleri gündemde.',
        articleText: 'Bilanço, temettü ve sermaye artırımı değerlendirildi.',
        category: 'borsa',
        source: 'TCMB',
        isBreaking: true,
      ),
    ];

    for (final result in scenarios) {
      expect(result.importanceScore, inInclusiveRange(0, 100));
      expect(result.financialRelevanceScore, inInclusiveRange(0, 100));
      expect(result.source.score, inInclusiveRange(0, 100));
      expect(result.freshness.score, inInclusiveRange(0, 100));
      expect(result.trendoraScore, inInclusiveRange(0, 100));
      expect(result.financialImpact.impactScore, inInclusiveRange(0, 100));
      expect(result.confidence.score, inInclusiveRange(0, 100));
    }
  });

  test('financial impact exposes every Sprint 2D market field', () {
    final result = evaluate(
      service(),
      id: 'financial-impact',
      title: 'TCMB faiz kararı sonrası BIST, dolar ve altın gündemde',
      summary:
          'Akbank ve Türk Hava Yolları hisseleri ile bankacılık sektörü izleniyor.',
      articleText:
          'Brent petrol, Bitcoin ve teknoloji şirketlerinde oynaklık görülebilir.',
      category: 'borsa',
      source: 'TCMB',
      sourceCount: 4,
      confirmingSourceCount: 3,
    );
    final impact = result.financialImpact;

    expect(impact.stockMarket, isNotEmpty);
    expect(impact.banking, isNotEmpty);
    expect(impact.gold, isNotEmpty);
    expect(impact.foreignExchange, isNotEmpty);
    expect(impact.crypto, isNotEmpty);
    expect(impact.oil, isNotEmpty);
    expect(impact.sectors, containsAll(['Bankacılık', 'Teknoloji', 'Enerji']));
    expect(
      impact.companies,
      containsAll(['Akbank (AKBNK)', 'Türk Hava Yolları (THYAO)']),
    );
    expect(impact.overallMarket, isNotEmpty);
    expect(impact.riskLevel, isNotEmpty);
    expect(impact.impactScore, inInclusiveRange(0, 100));
    expect(
      impact.affectedAssets,
      containsAll(['Altın', 'Brent petrol', 'Bitcoin', 'ABD doları']),
    );
  });

  test('confidence uses source breadth, confirmations and freshness', () {
    final high = evaluate(
      service(),
      id: 'high-confidence',
      source: 'Reuters',
      sourceCount: 4,
      confirmingSourceCount: 3,
      publishedAt: now.subtract(const Duration(minutes: 20)),
    );
    final low = evaluate(
      service(),
      id: 'low-confidence',
      sourceCount: 1,
      confirmingSourceCount: 0,
      publishedAt: now.subtract(const Duration(days: 12)),
    );

    expect(high.confidence.label, 'Çok Yüksek');
    expect(high.confidence.score, greaterThan(low.confidence.score));
    expect(high.confidence.reason, contains('4 kaynak'));
    expect(high.confidence.reason, contains('3 doğrulayan kaynak'));
  });

  test('named Trendora score weights sum to one', () {
    expect(
      NewsIntelligenceService.importanceWeight +
          NewsIntelligenceService.financialRelevanceWeight +
          NewsIntelligenceService.freshnessWeight +
          NewsIntelligenceService.sourceWeight,
      closeTo(1.0, 1e-12),
    );
  });

  test('same news produces and reuses the same result', () {
    final subject = service();
    final first = evaluate(
      subject,
      id: 'stable',
      title: 'BIST şirketi bilanço açıkladı',
      category: 'borsa',
    );
    final second = evaluate(
      subject,
      id: 'stable',
      title: 'BIST şirketi bilanço açıkladı',
      category: 'borsa',
    );

    expect(identical(first, second), isTrue);
    expect(second.trendoraScore, first.trendoraScore);
    expect(subject.cachedFor('stable'), same(first));
  });

  test('cache remains within its configured capacity', () {
    final subject = service(cacheSize: 2);
    evaluate(subject, id: 'one', title: 'FED faiz kararı');
    evaluate(subject, id: 'two', title: 'BIST bilanço haberi');
    evaluate(subject, id: 'three', title: 'Brent petrol haberi');

    expect(subject.cachedItemCount, 2);
    expect(subject.cachedFor('one'), isNull);
    expect(subject.cachedFor('two'), isNotNull);
    expect(subject.cachedFor('three'), isNotNull);
  });

  test('generated explanations contain no investment directions', () {
    final result = evaluate(
      service(),
      title: 'TCMB faiz kararı BIST ve KAP gündemini etkiledi',
      summary: 'Dolar, altın, banka ve şirket bilançoları izleniyor.',
      category: 'borsa',
      source: 'KAP',
    );
    final output = [
      result.importanceReason,
      result.financialReason,
      result.source.reason,
      result.freshness.reason,
      result.trendoraReason,
    ].join(' ').toLowerCase();

    expect(
      RegExp(r'(^|\s)(al|sat|tut)(\s|[.!?,;:]|$)').hasMatch(output),
      isFalse,
    );
    expect(output, isNot(contains('kesin yükselecek')));
    expect(output, isNot(contains('kesin düşecek')));
    expect(output, isNot(contains('hedef fiyat')));
  });
}
