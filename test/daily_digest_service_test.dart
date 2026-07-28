import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_service.dart';
import 'package:trendora_app/core/personalization/personalization_preferences.dart';
import 'package:trendora_app/core/personalization/personalization_storage.dart';
import 'package:trendora_app/core/saved_analysis_store.dart';

void main() {
  final now = DateTime(2026, 7, 28, 10);

  test('disabled digest performs no data work', () async {
    final source = _FakeDigestSource();
    final service = _service(source, _MemoryStore(), now);

    final result = await service.loadDue(
      PersonalizationPreferences.defaults(userId: 'guest:disabled'),
    );

    expect(result, isNull);
    expect(source.callCount, 0);
  });

  test('future scheduled digest performs no data work', () async {
    final source = _FakeDigestSource();
    final service = _service(source, _MemoryStore(), now);
    final preferences = _enabled(
      userId: 'guest:future',
      categories: {DailyDigestCategory.news},
      time: '19:00',
    );

    expect(await service.loadDue(preferences), isNull);
    expect(source.callCount, 0);
  });

  test('same daily slot reuses cache without repeated requests', () async {
    final source = _FakeDigestSource(
      newsRows: [
        {
          'id': 'news-1',
          'title': 'Doğrulanmış önemli gelişme',
          'source': 'Gerçek Haber',
          'isBreaking': true,
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'id': 'news-1',
          'title': 'Doğrulanmış önemli gelişme',
          'source': 'Gerçek Haber',
          'isBreaking': true,
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      ],
    );
    final store = _MemoryStore();
    final service = _service(source, store, now);
    final preferences = _enabled(
      userId: 'guest:cache',
      categories: {DailyDigestCategory.news},
    );

    final first = await service.loadDue(preferences);
    final second = await service.loadDue(preferences);

    expect(first?.items, hasLength(1));
    expect(second?.items.single.id, 'news:news-1');
    expect(source.newsCalls, 1);
  });

  test(
    'cached rows are hidden when they become stale without a new request',
    () async {
      final source = _FakeDigestSource(
        weatherData: {
          'source': 'Open-Meteo',
          'dataTime': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          'location': {'name': 'Ankara'},
          'current': {'description': 'Açık', 'temperature': 25},
        },
      );
      final store = _MemoryStore();
      final preferences = _enabled(
        userId: 'guest:stale-cache',
        categories: {DailyDigestCategory.weather},
      );
      final first = await _service(source, store, now).loadDue(preferences);
      final callsAfterFirstLoad = source.callCount;

      final later = now.add(const Duration(hours: 1));
      final second = await _service(source, store, later).loadDue(preferences);

      expect(first?.items, hasLength(1));
      expect(second?.items, isEmpty);
      expect(source.callCount, callsAfterFirstLoad);
    },
  );

  test('stale, incomplete and unimportant rows are not shown', () async {
    final source = _FakeDigestSource(
      newsRows: [
        {
          'id': 'stale',
          'title': 'Eski haber',
          'source': 'Haber Kaynağı',
          'isBreaking': true,
          'publishedAt': now
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        },
        {
          'id': 'ordinary',
          'title': 'Önem eşiğinin altındaki haber',
          'source': 'Haber Kaynağı',
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      ],
      weatherData: {
        'source': 'Open-Meteo',
        'dataTime': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'location': {'name': 'Ankara'},
        'current': {'description': 'Açık', 'temperature': 25},
      },
    );
    final preferences = _enabled(
      userId: 'guest:no-fake',
      categories: {DailyDigestCategory.news, DailyDigestCategory.weather},
    );

    final snapshot = await _service(
      source,
      _MemoryStore(),
      now,
    ).loadDue(preferences);

    expect(snapshot, isNotNull);
    expect(snapshot!.items, isEmpty);
  });

  test('one failed source does not stop other categories', () async {
    final source = _FakeDigestSource(
      failNews: true,
      opportunityRows: [
        {
          'id': 'offer-1',
          'title': 'Yeni market fırsatı',
          'store': 'Market',
          'source': 'Market',
          'active': true,
          'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
      ],
    );
    final preferences = _enabled(
      userId: 'guest:partial',
      categories: {DailyDigestCategory.news, DailyDigestCategory.opportunities},
    );

    final snapshot = await _service(
      source,
      _MemoryStore(),
      now,
    ).loadDue(preferences);

    expect(snapshot?.items, hasLength(1));
    expect(snapshot?.items.single.category, DailyDigestCategory.opportunities);
  });

  test(
    'only tracked fresh finance rows and significant analyses appear',
    () async {
      final updatedAt = now.subtract(const Duration(hours: 1));
      final source = _FakeDigestSource(
        marketRows: [
          {
            'symbol': 'BIMAS',
            'label': 'BİM',
            'price': 500,
            'changePercent': 1.5,
            'currency': 'TRY',
            'sourceInfo': {
              'name': 'Piyasa Kaynağı',
              'updatedAt': updatedAt.toIso8601String(),
            },
          },
          {
            'symbol': 'OTHER',
            'label': 'Takip edilmeyen',
            'price': 10,
            'changePercent': 4,
            'source': 'Piyasa Kaynağı',
            'updatedAt': updatedAt.toIso8601String(),
          },
        ],
        analyses: [
          SavedAnalysis(
            id: 'analysis-1',
            query: 'ALTIN',
            title: 'Altın analizi',
            savedAt: now.subtract(const Duration(days: 2)),
            startingPrice: 100,
            currency: 'TRY',
            confidence: 70,
            dominantScenario: 'Dengeli',
            dominantProbability: 60,
            expectedDirection: 'neutral',
            latestPrice: 103,
            checkedAt: updatedAt,
          ),
          SavedAnalysis(
            id: 'analysis-small',
            query: 'USDTRY',
            title: 'Dolar analizi',
            savedAt: now.subtract(const Duration(days: 2)),
            startingPrice: 100,
            currency: 'TRY',
            confidence: 70,
            dominantScenario: 'Dengeli',
            dominantProbability: 60,
            expectedDirection: 'neutral',
            latestPrice: 100.2,
            checkedAt: updatedAt,
          ),
        ],
      );
      final preferences =
          _enabled(
            userId: 'guest:finance',
            categories: {
              DailyDigestCategory.finance,
              DailyDigestCategory.savedAnalyses,
            },
          ).copyWith(
            trackedFinancialAssets: {'BIMAS'},
            savedAnalysisIds: {'analysis-1', 'analysis-small'},
          );

      final snapshot = await _service(
        source,
        _MemoryStore(),
        now,
      ).loadDue(preferences);

      expect(snapshot?.items, hasLength(2));
      expect(
        snapshot?.items.map((item) => item.category),
        containsAll({
          DailyDigestCategory.finance,
          DailyDigestCategory.savedAnalyses,
        }),
      );
    },
  );
}

PersonalizationPreferences _enabled({
  required String userId,
  required Set<DailyDigestCategory> categories,
  String time = '09:00',
}) {
  return PersonalizationPreferences.defaults(userId: userId).copyWith(
    dailyDigestEnabled: true,
    digestTime: time,
    digestCategories: categories,
  );
}

DailyDigestService _service(
  DailyDigestDataSource source,
  PersonalizationKeyValueStore store,
  DateTime now,
) {
  return DailyDigestService(source, DailyDigestCache(store), now: () => now);
}

class _FakeDigestSource implements DailyDigestDataSource {
  _FakeDigestSource({
    this.newsRows = const [],
    this.opportunityRows = const [],
    this.marketRows = const [],
    this.weatherData,
    this.analyses = const [],
    this.failNews = false,
  });

  final List<Map<String, dynamic>> newsRows;
  final List<Map<String, dynamic>> opportunityRows;
  final List<Map<String, dynamic>> marketRows;
  final Map<String, dynamic>? weatherData;
  final List<SavedAnalysis> analyses;
  final bool failNews;

  int callCount = 0;
  int newsCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> news() async {
    callCount++;
    newsCalls++;
    if (failNews) throw StateError('news unavailable');
    return newsRows;
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities() async {
    callCount++;
    return opportunityRows;
  }

  @override
  Future<List<Map<String, dynamic>>> marketBoard() async {
    callCount++;
    return marketRows;
  }

  @override
  Future<List<SavedAnalysis>> savedAnalyses() async {
    callCount++;
    return analyses;
  }

  @override
  Future<Map<String, dynamic>?> weather() async {
    callCount++;
    return weatherData;
  }
}

class _MemoryStore implements PersonalizationKeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}
