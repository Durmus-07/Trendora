import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/shortcuts/smart_command_service.dart';
import 'package:trendora_app/core/shortcuts/smart_shortcut_store.dart';

void main() {
  test('parser recognizes supported commands without network access', () {
    const parser = SmartCommandParser();
    expect(parser.parse('Bugün altın ne kadar?'), SmartCommandIntent.gold);
    expect(
      parser.parse('Takip listemde yükselenler hangileri?'),
      SmartCommandIntent.watchlistRisers,
    );
    expect(
      parser.parse('Bugün yağmur yağacak mı?'),
      SmartCommandIntent.weather,
    );
    expect(parser.parse('anlaşılmayan bir şey'), SmartCommandIntent.unknown);
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

  test('unknown command does not call a data source', () async {
    final source = _FakeSource();
    final result = await SmartCommandService(
      dataSource: source,
    ).execute('xyz nedir?');
    expect(result.intent, SmartCommandIntent.unknown);
    expect(result.available, isFalse);
    expect(source.calls, 0);
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
  _FakeSource({this.market = const [], this.failMarket = false});

  final List<Map<String, dynamic>> market;
  final bool failMarket;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> marketBoard() async {
    calls++;
    if (failMarket) throw StateError('offline');
    return market;
  }

  @override
  Future<List<Map<String, dynamic>>> news() async {
    calls++;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities() async {
    calls++;
    return const [];
  }

  @override
  Future<int> savedAnalysisCount() async => 0;

  @override
  Future<Set<String>> trackedSymbols() async => {};

  @override
  Future<({String description, String location, double? temperature})?>
  weather() async => null;
}
