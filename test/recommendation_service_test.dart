import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/personalization/personalization_preferences.dart';
import 'package:trendora_app/core/recommendations/recommendation_service.dart';

void main() {
  test(
    'disabled personalization does not request recommendation data',
    () async {
      final source = _FakeDataSource();
      final preferences = PersonalizationPreferences.defaults(
        userId: 'guest:off',
      );

      final result = await RecommendationService(
        dataSource: source,
      ).load(preferences);

      expect(result.isEmpty, isTrue);
      expect(source.callCount, 0);
    },
  );

  test('ranks real matching data and limits today section to five', () async {
    final source = _FakeDataSource(
      newsRows: List.generate(
        7,
        (index) => {
          'id': 'news-$index',
          'title': 'Teknoloji gelişmesi $index',
          'category': 'teknoloji',
          'source': 'Test Haber',
          'publishedAt': DateTime.now().toIso8601String(),
        },
      ),
    );
    final preferences = PersonalizationPreferences.defaults(
      userId: 'guest:news',
    ).copyWith(personalizationEnabled: true, interests: {'technology'});

    final result = await RecommendationService(
      dataSource: source,
    ).load(preferences);

    expect(result.today, hasLength(5));
    expect(result.forYou, hasLength(2));
    expect(result.today.map((item) => item.id).toSet(), hasLength(5));
    expect(result.today.every((item) => item.source == 'Test Haber'), isTrue);
  });

  test(
    'one failed source does not stop other recommendation sources',
    () async {
      final source = _FakeDataSource(
        failNews: true,
        opportunityRows: [
          {
            'id': 'offer-1',
            'title': 'Gerçek market fırsatı',
            'store': 'Test Market',
            'active': true,
          },
        ],
      );
      final preferences =
          PersonalizationPreferences.defaults(userId: 'guest:partial').copyWith(
            personalizationEnabled: true,
            interests: {'technology', 'market_opportunities'},
          );

      final result = await RecommendationService(
        dataSource: source,
      ).load(preferences);

      expect(result.today, hasLength(1));
      expect(result.today.single.type, RecommendationType.opportunity);
    },
  );

  test('hidden recommendations are not returned again', () async {
    final source = _FakeDataSource(
      newsRows: [
        {
          'id': 'hidden-news',
          'title': 'Teknoloji haberi',
          'category': 'teknoloji',
        },
      ],
    );
    final preferences = PersonalizationPreferences.defaults(
      userId: 'guest:hidden',
    ).copyWith(personalizationEnabled: true, interests: {'technology'});

    final result = await RecommendationService(dataSource: source).load(
      preferences,
      feedback: const RecommendationFeedback(hiddenIds: {'news:hidden-news'}),
    );

    expect(result.isEmpty, isTrue);
  });

  test('prioritizes a tracked financial asset', () async {
    final source = _FakeDataSource(
      marketRows: [
        {
          'symbol': 'BIMAS',
          'label': 'BIMAS',
          'price': 480.25,
          'changePercent': 1.2,
          'source': 'Piyasa kaynağı',
        },
      ],
    );
    final preferences = PersonalizationPreferences.defaults(
      userId: 'guest:finance',
    ).copyWith(personalizationEnabled: true, trackedFinancialAssets: {'BIMAS'});

    final result = await RecommendationService(
      dataSource: source,
    ).load(preferences);

    expect(result.today.single.type, RecommendationType.finance);
    expect(result.today.single.reason, 'Takip ettiğin finansal varlık');
  });
}

class _FakeDataSource implements RecommendationDataSource {
  _FakeDataSource({
    this.newsRows = const [],
    this.opportunityRows = const [],
    this.marketRows = const [],
    this.failNews = false,
  });

  final List<Map<String, dynamic>> newsRows;
  final List<Map<String, dynamic>> opportunityRows;
  final List<Map<String, dynamic>> marketRows;
  final bool failNews;
  int callCount = 0;

  @override
  Future<List<Map<String, dynamic>>> news() async {
    callCount++;
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
}
