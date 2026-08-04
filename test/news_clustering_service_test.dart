import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/news/news_clustering_service.dart';

void main() {
  final now = DateTime.utc(2026, 7, 29, 12);

  group('content URL normalization', () {
    test('removes tracking parameters and empty fragments', () {
      expect(
        normalizeContentUrl('https://example.com/direct?utm_source=test#'),
        'https://example.com/direct',
      );
    });

    test('preserves content identity parameters', () {
      expect(
        normalizeContentUrl('https://example.com/news?id=123&utm_campaign=x'),
        'https://example.com/news?id=123',
      );
      expect(
        normalizeContentUrl('https://example.com/page?category=ekonomi'),
        'https://example.com/page?category=ekonomi',
      );
    });

    test('removes all supported tracking keys case-insensitively', () {
      expect(
        normalizeContentUrl(
          'https://example.com/product?sku=ABC&UTM_Medium=x&fbclid=1&gclid=2&dclid=3&msclkid=4&mc_cid=5&MC_EID=6',
        ),
        'https://example.com/product?sku=ABC',
      );
    });

    test('removes non-empty fragments consistently with existing matching', () {
      expect(
        normalizeContentUrl('https://example.com/page#section'),
        'https://example.com/page',
      );
    });

    test('invalid and unsafe URLs fail closed', () {
      expect(normalizeContentUrl('not a url'), isEmpty);
      expect(normalizeContentUrl('file:///tmp/content'), isEmpty);
    });
  });

  NewsClusteringService service({
    int analysisCapacity = 512,
    int resultCapacity = 12,
  }) {
    return NewsClusteringService(
      maximumAnalysisCacheItems: analysisCapacity,
      maximumResultCacheItems: resultCapacity,
      now: () => now,
    );
  }

  test('same event from different sources forms one explainable cluster', () {
    final clustering = service();
    final items = [
      _candidate(
        id: 'tcmb-aa',
        title:
            'TCMB faiz kararını açıkladı: Politika faizi yüzde 45 seviyesinde sabit kaldı',
        source: 'Anadolu Ajansı',
        publishedAt: now.subtract(const Duration(minutes: 15)),
      ),
      _candidate(
        id: 'tcmb-reuters',
        title:
            'Merkez Bankası faiz kararı: Politika faizi yüzde 45 seviyesinde sabit tutuldu',
        source: 'Reuters',
        publishedAt: now.subtract(const Duration(minutes: 25)),
      ),
    ];

    final comparison = clustering.compare(items[0], items[1]);
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: items,
    );

    expect(
      comparison.strength,
      NewsClusterMatchStrength.strong,
      reason: 'score=${comparison.score}, reasons=${comparison.reasons}',
    );
    expect(clusters, hasLength(1));
    expect(clusters.single.items, hasLength(2));
    expect(clusters.single.uniqueSourceCount, 2);
    expect(clusters.single.explanation, contains('Ortak olay türü'));
  });

  test('different events about the same company remain separate', () {
    final clustering = service();
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'aselsan-contract',
          title: 'ASELSAN yeni savunma sözleşmesi imzaladı',
          summary: 'Şirket yeni bir ihale sözleşmesini duyurdu.',
        ),
        _candidate(
          id: 'aselsan-earnings',
          title: 'ASELSAN ikinci çeyrek bilançosunu açıkladı',
          summary: 'Şirket finansal sonuçlarını yayımladı.',
        ),
      ],
    );

    expect(clusters, hasLength(2));
    final comparison = clustering.compare(
      clusters[0].items.single,
      clusters[1].items.single,
    );
    expect(comparison.strength, NewsClusterMatchStrength.weak);
    expect(comparison.reasons.join(' '), contains('Olay türleri farklı'));
  });

  test('a bridge article cannot transitively merge conflicting events', () {
    final clustering = service();
    final contract = _candidate(
      id: 'bridge-contract',
      title: 'KAP defense contract tender details announced',
      summary: 'The defense contract and tender details were announced.',
    );
    final bridge = _candidate(
      id: 'bridge-both',
      title:
          'KAP defense contract tender and earnings financial results details announced',
      summary:
          'The contract, earnings and financial results details were announced.',
    );
    final earnings = _candidate(
      id: 'bridge-earnings',
      title: 'KAP earnings financial results details announced',
      summary: 'The earnings and financial results details were announced.',
    );

    final contractBridge = clustering.compare(contract, bridge);
    final bridgeEarnings = clustering.compare(bridge, earnings);
    expect(
      contractBridge.strength,
      NewsClusterMatchStrength.strong,
      reason: 'score=${contractBridge.score}',
    );
    expect(
      bridgeEarnings.strength,
      NewsClusterMatchStrength.strong,
      reason: 'score=${bridgeEarnings.score}',
    );
    expect(
      clustering.compare(contract, earnings).strength,
      NewsClusterMatchStrength.weak,
    );

    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [contract, bridge, earnings],
    );
    final clusterContainingContract = clusters.singleWhere(
      (cluster) => cluster.contains(contract.stableId),
    );

    expect(clusters, hasLength(2));
    expect(clusterContainingContract.contains(bridge.stableId), isTrue);
    expect(clusterContainingContract.contains(earnings.stableId), isFalse);
  });

  test('conflicting numeric values are never merged', () {
    final clustering = service();
    final left = _candidate(
      id: 'investment-10',
      title: 'Şirket yeni tesis için 10 milyar TL yatırım açıkladı',
      source: 'Kaynak A',
    );
    final right = _candidate(
      id: 'investment-100',
      title: 'Şirket yeni tesis için 100 milyar TL yatırım açıkladı',
      source: 'Kaynak B',
    );

    final comparison = clustering.compare(left, right);
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [left, right],
    );

    expect(comparison.strength, NewsClusterMatchStrength.weak);
    expect(comparison.reasons.join(' '), contains('Sayısal değerler farklı'));
    expect(clusters, hasLength(2));
  });

  test('same title and source keep distinct numeric stories', () {
    final clustering = service();
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'same-title-10',
          title: 'Sirket yatirim tutarini acikladi',
          summary: 'Yeni yatirimin tutari 10 milyar TL olarak duyuruldu.',
          source: 'Same Source',
          url: 'https://example.com/investment-10',
        ),
        _candidate(
          id: 'same-title-100',
          title: 'Sirket yatirim tutarini acikladi',
          summary: 'Yeni yatirimin tutari 100 milyar TL olarak duyuruldu.',
          source: 'Same Source',
          url: 'https://example.com/investment-100',
        ),
      ],
    );

    expect(clusters, hasLength(2));
    expect(
      clusters.expand((cluster) => cluster.items).map((item) => item.stableId),
      containsAll(['same-title-10', 'same-title-100']),
    );
  });

  test('different dates outside the event window remain separate', () {
    final clustering = service();
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'old-rate',
          title: 'TCMB faiz kararını açıkladı politika faizi sabit kaldı',
          publishedAt: now.subtract(const Duration(days: 8)),
        ),
        _candidate(
          id: 'new-rate',
          title: 'TCMB faiz kararını açıkladı politika faizi sabit kaldı',
          publishedAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );

    expect(clusters, hasLength(2));
  });

  test('exact repeats from one source do not multiply a cluster', () {
    final clustering = service();
    final duplicate = _candidate(
      id: 'repeat-a',
      title: 'Enflasyon verisi açıklandı',
      source: 'Aynı Kaynak',
      url: 'https://example.com/economy?tracking=one',
    );
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        duplicate,
        _candidate(
          id: 'repeat-b',
          title: duplicate.title,
          source: duplicate.source,
          url: 'https://example.com/economy?tracking=two',
        ),
      ],
    );

    expect(clusters, hasLength(1));
    expect(clusters.single.items, hasLength(1));
    expect(clusters.single.uniqueSourceCount, 1);
  });

  test('different sources are preserved and counted once', () {
    final clustering = service();
    final clusters = clustering.cluster(
      categoryKey: 'dunya',
      candidates: [
        _candidate(
          id: 'fire-a',
          title: 'Fransa orman yangınlarında 250 bin kişi tahliye edildi',
          source: 'BBC',
        ),
        _candidate(
          id: 'fire-b',
          title: 'Fransa yangınları: 250 bin kişi evlerinden tahliye edildi',
          source: 'Reuters',
        ),
        _candidate(
          id: 'fire-c',
          title: 'Fransa orman yangınlarında 250 bin kişi tahliye edildi',
          source: 'BBC',
          url: 'https://example.com/fire-copy',
        ),
      ],
    );

    expect(clusters, hasLength(1));
    expect(clusters.single.uniqueSourceCount, 2);
    expect(clusters.single.sourceLabels, containsAll(['BBC', 'Reuters']));
  });

  test('representative selection is deterministic and multi-factor', () {
    final clustering = service();
    final candidates = [
      _candidate(
        id: 'plain',
        title: 'TCMB faiz kararı açıklandı politika faizi sabit kaldı',
        source: 'Kaynak A',
        trendoraScore: 45,
        sourceScore: 35,
      ),
      _candidate(
        id: 'complete',
        title: 'TCMB faiz kararı açıklandı politika faizi sabit kaldı',
        source: 'Resmî Kaynak',
        summary: 'Kararın ayrıntıları ve gerekçeleri açıklandı.',
        imageUrl: 'https://example.com/image.jpg',
        articleText: 'Tam metin',
        trendoraScore: 90,
        sourceScore: 100,
      ),
    ];

    final first = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: candidates,
    );
    final second = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: candidates,
    );

    expect(first.single.representative.stableId, 'complete');
    expect(second.single.representative.stableId, 'complete');
    expect(identical(first, second), isTrue);
  });

  test('result cache invalidates when representative inputs change', () {
    final clustering = service();
    final first = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'cache-a',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source A',
          trendoraScore: 95,
          sourceScore: 95,
        ),
        _candidate(
          id: 'cache-b',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source B',
          trendoraScore: 10,
          sourceScore: 10,
        ),
      ],
    );
    final second = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'cache-a',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source A',
          trendoraScore: 10,
          sourceScore: 10,
        ),
        _candidate(
          id: 'cache-b',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source B',
          trendoraScore: 95,
          sourceScore: 95,
        ),
      ],
    );

    expect(first.single.representative.stableId, 'cache-a');
    expect(second.single.representative.stableId, 'cache-b');
    expect(identical(first, second), isFalse);
  });

  test('pagination adds a source to an existing stable cluster', () {
    final clustering = service();
    final firstPage = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'rate-first',
          title: 'TCMB faiz kararı açıklandı politika faizi sabit kaldı',
          source: 'Kaynak A',
        ),
      ],
    );
    final secondPage = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        firstPage.single.items.single,
        _candidate(
          id: 'rate-second',
          title: 'TCMB faiz kararı: politika faizi sabit kaldı',
          source: 'Kaynak B',
        ),
      ],
      previousClusters: firstPage,
    );

    expect(secondPage, hasLength(1));
    expect(secondPage.single.items, hasLength(2));
    expect(secondPage.single.id, firstPage.single.id);
  });

  test('incremental append rebuilds only the affected clusters', () {
    final clustering = service();
    final firstPage = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(
          id: 'incremental-rate-a',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source A',
        ),
        _candidate(
          id: 'incremental-independent',
          title: 'Oil production report published for July',
          source: 'Source C',
        ),
      ],
    );
    final unchangedCluster = firstPage.singleWhere(
      (cluster) => cluster.contains('incremental-independent'),
    );

    final appended = clustering.appendToClusters(
      categoryKey: 'ekonomi',
      previousClusters: firstPage,
      candidates: [
        _candidate(
          id: 'incremental-rate-b',
          title: 'TCMB interest rate decision remained unchanged',
          source: 'Source B',
        ),
      ],
    );
    final changedCluster = appended.singleWhere(
      (cluster) => cluster.contains('incremental-rate-a'),
    );
    final stillUnchangedCluster = appended.singleWhere(
      (cluster) => cluster.contains('incremental-independent'),
    );

    expect(changedCluster.items, hasLength(2));
    expect(changedCluster.id, firstPage.first.id);
    expect(identical(stillUnchangedCluster, unchangedCluster), isTrue);
  });

  test('a news item never appears in two clusters', () {
    final clustering = service();
    final clusters = clustering.cluster(
      categoryKey: 'gundem',
      candidates: [
        _candidate(id: 'one', title: 'Ankara için yeni karar açıklandı'),
        _candidate(id: 'two', title: 'İstanbul için yeni karar açıklandı'),
        _candidate(id: 'one', title: 'Ankara için yeni karar açıklandı'),
      ],
    );
    final ids = clusters
        .expand((cluster) => cluster.items)
        .map((item) => item.stableId)
        .toList();

    expect(ids.toSet().length, ids.length);
  });

  test('category runs stay isolated and generate different identities', () {
    final clustering = service();
    final economy = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [
        _candidate(id: 'shared', title: 'Günün gelişmesi açıklandı'),
      ],
    );
    final sport = clustering.cluster(
      categoryKey: 'spor',
      candidates: [
        _candidate(
          id: 'sport-shared',
          title: 'Günün gelişmesi açıklandı',
          category: 'spor',
        ),
      ],
    );

    expect(economy.single.id, isNot(sport.single.id));
  });

  test('Turkish characters and numeric values survive normalization', () {
    final clustering = service();
    final signals = clustering.extractSignals(
      _candidate(
        id: 'turkish',
        title: 'ŞİRKET 10 milyar TL sözleşme imzaladı | Örnek Kaynak',
        source: 'Örnek Kaynak',
      ),
    );

    expect(signals.normalizedTitle, contains('şirket'));
    expect(signals.normalizedTitle, isNot(contains('örnek kaynak')));
    expect(signals.numericValues, contains('10 milyar'));
    expect(signals.eventTypes, contains('sozlesme'));
  });

  test('uncertain matches are deliberately kept separate', () {
    final clustering = service();
    final left = _candidate(
      id: 'market-a',
      title: 'Küresel piyasalarda teknoloji hisseleri yükseldi',
      source: 'Kaynak A',
    );
    final right = _candidate(
      id: 'market-b',
      title: 'Küresel piyasalarda enerji hisseleri yükseldi',
      source: 'Kaynak B',
    );
    final comparison = clustering.compare(left, right);
    final clusters = clustering.cluster(
      categoryKey: 'ekonomi',
      candidates: [left, right],
    );

    expect(comparison.strength, isNot(NewsClusterMatchStrength.strong));
    expect(clusters, hasLength(2));
  });

  test('analysis and result caches remain bounded', () {
    final clustering = service(analysisCapacity: 3, resultCapacity: 2);
    for (var index = 0; index < 8; index++) {
      clustering.cluster(
        categoryKey: 'category-$index',
        candidates: [
          _candidate(id: 'news-$index', title: 'Bağımsız haber başlığı $index'),
        ],
      );
    }

    expect(clustering.cachedAnalysisCount, lessThanOrEqualTo(3));
    expect(clustering.cachedResultCount, lessThanOrEqualTo(2));
  });

  test('generated explanations contain no investment direction', () {
    final clustering = service();
    final cluster = clustering
        .cluster(
          categoryKey: 'ekonomi',
          candidates: [
            _candidate(
              id: 'safe-a',
              title: 'BIST endeksinde günün gelişmeleri açıklandı',
              source: 'Kaynak A',
            ),
            _candidate(
              id: 'safe-b',
              title: 'BIST endeksinde günün gelişmeleri açıklandı',
              source: 'Kaynak B',
            ),
          ],
        )
        .single;
    final explanation = cluster.explanation.toLowerCase();

    expect(
      RegExp(r'(^|\s)(al|sat|tut)(\s|[.!?,;:]|$)').hasMatch(explanation),
      isFalse,
    );
    expect(explanation, isNot(contains('hedef fiyat')));
    expect(explanation, isNot(contains('kesin yükselecek')));
    expect(explanation, isNot(contains('kesin düşecek')));
  });
}

NewsClusterCandidate _candidate({
  required String id,
  required String title,
  String summary = '',
  String articleText = '',
  String source = 'Test Kaynağı',
  String feedSource = '',
  String category = 'ekonomi',
  DateTime? publishedAt,
  String? url,
  String imageUrl = '',
  int trendoraScore = 60,
  int sourceScore = 65,
}) {
  return NewsClusterCandidate(
    newsId: id,
    title: title,
    summary: summary,
    articleText: articleText,
    source: source,
    feedSource: feedSource,
    category: category,
    publishedAt: publishedAt ?? DateTime.utc(2026, 7, 29, 11),
    url: url ?? 'https://example.com/$id',
    imageUrl: imageUrl,
    trendoraScore: trendoraScore,
    sourceScore: sourceScore,
  );
}
