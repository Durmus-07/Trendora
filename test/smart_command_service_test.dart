import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/shortcuts/smart_command_service.dart';
import 'package:trendora_app/core/shortcuts/smart_shortcut_store.dart';
import 'package:trendora_app/core/news/saved_news_store.dart';

void main() {
  test('parser recognizes supported commands without network access', () {
    const parser = SmartCommandParser();
    expect(
      parser.parse('Bugün altın ne kadar?'),
      SmartCommandIntent.marketPrice,
    );
    expect(
      parser.parse('Takip listemde yükselenler hangileri?'),
      SmartCommandIntent.watchlistRisers,
    );
    expect(
      parser.parse('Bugün yağmur yağacak mı?'),
      SmartCommandIntent.weather,
    );
    expect(
      parser.parse('anlaşılmayan bir şey'),
      SmartCommandIntent.generalQuestion,
    );
  });

  test('parser routes Sprint 5 intents and tolerates common typos', () {
    const parser = SmartCommandParser();
    expect(parser.parse('ASELSAN kaç TL?'), SmartCommandIntent.marketPrice);
    expect(parser.parse('ASELS kaç TL?'), SmartCommandIntent.marketPrice);
    expect(parser.parse('THY analiz et'), SmartCommandIntent.marketAnalysis);
    expect(parser.parse('ALTIN.S1 kaç TL?'), SmartCommandIntent.marketPrice);
    expect(parser.parse('son dakka haber'), SmartCommandIntent.breakingNews);
    expect(
      parser.parse('teknoloji haberleri'),
      SmartCommandIntent.newsCategory,
    );
    expect(
      parser.parse('migors fırsat'),
      SmartCommandIntent.opportunitiesSource,
    );
    expect(
      parser.parse('indirimli kahve var mı'),
      SmartCommandIntent.opportunitiesSearch,
    );
    expect(parser.parse('kaydetigim hisseler'), SmartCommandIntent.savedItems);
    expect(parser.parse('kaydettiğim haberler'), SmartCommandIntent.savedNews);
  });

  test('returns a real market value with source and target', () async {
    final service = SmartCommandService(
      dataSource: _FakeSource(
        market: [
          {
            'symbol': 'XAU',
            'label': 'Gram Altın',
            'price': 4200.5,
            'changePercent': 1.1,
            'source': 'Test Piyasa',
            'updatedAt': '2026-07-27T10:00:00Z',
          },
        ],
      ),
    );

    final result = await service.execute('Altın bugün ne kadar?');

    expect(result.message, contains('4200.5'));
    expect(result.source, 'Test Piyasa');
    expect(result.target, SmartCommandTarget.trend);
    expect(result.available, isTrue);
  });

  test('unknown text is routed to Trendora general search safely', () async {
    final source = _FakeSource();
    final result = await SmartCommandService(
      dataSource: source,
    ).execute('xyz qwerty');
    expect(result.intent, SmartCommandIntent.generalQuestion);
    expect(result.available, isFalse);
    expect(source.calls, 0);
  });

  test('general question uses safe fallback without calling data', () async {
    final source = _FakeSource();
    final result = await SmartCommandService(
      dataSource: source,
    ).execute('Enflasyon nedir?');
    expect(result.intent, SmartCommandIntent.generalQuestion);
    expect(result.available, isFalse);
    expect(source.calls, 0);
  });

  test(
    'general AI result is clearly marked and separate from live data',
    () async {
      final result = await SmartCommandService(
        dataSource: _FakeSource(aiAnswer: 'Bileşik faiz kısa bir açıklamadır.'),
      ).execute('Bileşik faiz nedir?');
      expect(result.source, 'Trendora Arama');
      expect(result.message, contains('Bileşik faiz'));
    },
  );

  test('catalog-only BIST symbol can return a real board value', () async {
    final result = await SmartCommandService(
      dataSource: _FakeSource(
        market: const [
          {
            'symbol': 'TUPRS',
            'label': 'Tüpraş',
            'price': 190.5,
            'source': 'Test Piyasa',
            'updatedAt': '2026-08-04T10:00:00Z',
          },
        ],
      ),
    ).execute('TUPRS kaç TL?');
    expect(result.message, contains('190.5'));
    expect(result.targetQuery, 'TUPRS');
  });

  test('ambiguous catalog result returns safe selection cards', () async {
    final result = await SmartCommandService(
      dataSource: _FakeSource(
        planOverride: const {
          'assetResolution': 'selection_required',
          'normalizedQuery': 'abc kac tl',
          'candidates': [
            {'canonicalSymbol': 'ABCD', 'displayName': 'Birinci Varlık'},
            {'canonicalSymbol': 'ABCE', 'displayName': 'İkinci Varlık'},
          ],
        },
      ),
    ).execute('ABC kaç TL?');
    expect(result.available, isTrue);
    expect(result.cards, hasLength(2));
    expect(result.message, contains('varlık seç'));
  });

  test('source failure returns a safe response', () async {
    final result = await SmartCommandService(
      dataSource: _FakeSource(failMarket: true),
    ).execute('Dolar kaç TL?');
    expect(result.available, isFalse);
    expect(result.message, contains('şu anda alınamıyor'));
  });

  test(
    'shortcut order is persisted and missing defaults are appended',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = SmartShortcutStore(preferences);
      final reordered = List<SmartShortcutDefinition>.from(
        SmartShortcutCatalog.all,
      );
      reordered.insert(0, reordered.removeLast());

      await store.save('guest:test', reordered);
      final restored = store.load('guest:test');

      expect(restored.first.id, 'for_you');
      expect(restored, hasLength(SmartShortcutCatalog.all.length));
    },
  );
}

class _FakeSource implements SmartCommandDataSource {
  _FakeSource({
    this.market = const [],
    this.failMarket = false,
    this.aiAnswer,
    this.planOverride,
  });

  final List<Map<String, dynamic>> market;
  final bool failMarket;
  final String? aiAnswer;
  final Map<String, dynamic>? planOverride;
  int calls = 0;

  @override
  Future<Map<String, dynamic>?> smartSearchPlan(String query) async {
    if (planOverride != null) return planOverride;
    final normalized = SmartCommandParser.normalize(query);
    final symbol =
        SmartCommandParser.assetSymbol(query) ??
        (normalized.contains('dolar') ? 'USDTRY' : null) ??
        RegExp(r'\b[A-Z]{4,6}\b').firstMatch(query)?.group(0);
    return {
      'service': query.toLowerCase().contains('nedir') ? 'ai' : 'market_board',
      'normalizedQuery': SmartCommandParser.normalize(query),
      'assetResolution': symbol == null ? 'not_found' : 'matched',
      'asset': symbol == null
          ? null
          : {'canonicalSymbol': symbol, 'displayName': symbol},
      'candidates': const [],
    };
  }

  @override
  Future<Map<String, dynamic>?> generalSearch(String query) async =>
      aiAnswer == null
      ? null
      : {
          'success': true,
          'answer': aiAnswer,
          'provider': 'gemini',
          'results': const [],
        };

  @override
  Future<List<Map<String, dynamic>>> marketBoard() async {
    calls++;
    if (failMarket) throw StateError('offline');
    return market;
  }

  @override
  Future<List<Map<String, dynamic>>> news({
    String? category,
    String? query,
    bool breaking = false,
  }) async {
    calls++;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities({
    String? source,
    String? query,
  }) async {
    calls++;
    return const [];
  }

  @override
  Future<int> savedAnalysisCount() async => 0;

  @override
  Future<List<SavedNews>> savedNews() async => const [];

  @override
  Future<Set<String>> trackedSymbols() async => {};

  @override
  Future<({String description, String location, double? temperature})?>
  weather() async => null;
}
