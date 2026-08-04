import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_service.dart';
import 'package:trendora_app/core/personalization/personalization_service.dart';
import 'package:trendora_app/core/personalization/personalization_storage.dart';
import 'package:trendora_app/core/saved_analysis_store.dart';
import 'package:trendora_app/theme/trendora_theme.dart';
import 'package:trendora_app/widgets/daily_digest_section.dart';

void main() {
  final now = DateTime(2026, 7, 28, 20);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('disabled digest is responsive and does not load sources', (
    tester,
  ) async {
    final source = _FakeDigestSource();
    final dependencies = _dependencies(_MemoryStore(), source, now);
    await tester.binding.setSurfaceSize(const Size(288, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(dependencies, now));
    await tester.pumpAndSettle();

    expect(find.text('GÜNLÜK KİŞİSEL ÖZET'), findsOneWidget);
    expect(find.textContaining('Özet kapalı'), findsOneWidget);
    expect(find.text('Premium Yapay Zekâ şu anda kapalı'), findsOneWidget);
    expect(find.text('Özet oluştur'), findsNothing);
    expect(source.callCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period, enabled state and category choices persist', (
    tester,
  ) async {
    final store = _MemoryStore();
    final source = _FakeDigestSource();
    final dependencies = _dependencies(store, source, now);
    await tester.pumpWidget(_app(dependencies, now));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Günlük özet ayarları'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akşam'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Günlük özeti aç'));
    final opportunityTile = find.widgetWithText(
      SwitchListTile,
      'Yeni fırsatlar',
    );
    await tester.ensureVisible(opportunityTile);
    await tester.tap(opportunityTile);
    await tester.ensureVisible(find.text('Tercihleri Kaydet'));
    await tester.tap(find.text('Tercihleri Kaydet'));
    await tester.pumpAndSettle();

    final restored = await dependencies.personalizationService.getPreferences();
    expect(restored.dailyDigestEnabled, isTrue);
    expect(restored.digestPeriod, DailyDigestPeriod.evening);
    expect(restored.digestTime, '19:00');
    expect(
      restored.digestCategories,
      isNot(contains(DailyDigestCategory.opportunities)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fresh content fits a small phone without empty sections', (
    tester,
  ) async {
    final store = _MemoryStore();
    final source = _FakeDigestSource(
      newsRows: [
        {
          'id': 'important-1',
          'title': 'Güncel ve önemli haber',
          'description': 'Doğrulanmış kısa açıklama',
          'source': 'Haber Kaynağı',
          'isBreaking': true,
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      ],
    );
    final dependencies = _dependencies(store, source, now);
    await dependencies.personalizationService.initialize();
    await dependencies.personalizationService.update(
      (current) => current.copyWith(
        dailyDigestEnabled: true,
        digestTime: '09:00',
        digestCategories: {DailyDigestCategory.news},
      ),
    );
    await tester.binding.setSurfaceSize(const Size(288, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(dependencies, now));
    await tester.pumpAndSettle();

    expect(find.text('Güncel ve önemli haber'), findsOneWidget);
    expect(find.text('Önemli haberler'), findsOneWidget);
    expect(find.text('Yeni fırsatlar'), findsNothing);
    expect(find.text('Yaklaşan ödemeler'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('digest card forwards exact identity to direct navigator', (
    tester,
  ) async {
    final source = _FakeDigestSource(
      newsRows: [
        {
          'id': 'news-direct-1',
          'title': 'Doğrudan açılacak haber',
          'source': 'Haber Kaynağı',
          'url': 'https://example.com/direct?utm_source=test',
          'isBreaking': true,
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      ],
    );
    final dependencies = _dependencies(_MemoryStore(), source, now);
    await dependencies.personalizationService.initialize();
    await dependencies.personalizationService.update(
      (current) => current.copyWith(
        dailyDigestEnabled: true,
        digestTime: '09:00',
        digestCategories: {DailyDigestCategory.news},
      ),
    );
    DailyDigestItem? opened;
    await tester.pumpWidget(
      _app(
        dependencies,
        now,
        onOpenDirectItem: (item) async {
          opened = item;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doğrudan açılacak haber'));
    await tester.pump();

    expect(opened?.itemId, 'news-direct-1');
    expect(opened?.target, 'newsDetail');
    expect(opened?.normalizedUrl, 'https://example.com/direct');
  });
}

Widget _app(
  DailyDigestDependencies dependencies,
  DateTime now, {
  Future<bool> Function(DailyDigestItem item)? onOpenDirectItem,
}) {
  return MaterialApp(
    theme: TrendoraTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        child: DailyDigestSection(
          dependenciesBuilder: () async => dependencies,
          now: () => now,
          onOpenNews: () {},
          onOpenOpportunities: () {},
          onOpenWeather: () {},
          onOpenFinance: (_) {},
          onOpenDirectItem: onOpenDirectItem,
        ),
      ),
    ),
  );
}

DailyDigestDependencies _dependencies(
  PersonalizationKeyValueStore store,
  DailyDigestDataSource source,
  DateTime now,
) {
  return DailyDigestDependencies(
    personalizationService: PersonalizationService(
      repository: PersonalizationLocalRepository(store),
      identityProvider: PersonalizationIdentityProvider(store),
    ),
    digestService: DailyDigestService(
      source,
      DailyDigestCache(store),
      now: () => now,
    ),
  );
}

class _FakeDigestSource implements DailyDigestDataSource {
  _FakeDigestSource({this.newsRows = const []});

  final List<Map<String, dynamic>> newsRows;
  int callCount = 0;

  @override
  Future<List<Map<String, dynamic>>> news() async {
    callCount++;
    return newsRows;
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities() async {
    callCount++;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> marketBoard() async {
    callCount++;
    return const [];
  }

  @override
  Future<List<SavedAnalysis>> savedAnalyses() async {
    callCount++;
    return const [];
  }

  @override
  Future<Map<String, dynamic>?> weather() async {
    callCount++;
    return null;
  }
}

class _MemoryStore implements PersonalizationKeyValueStore {
  _MemoryStore()
    : values = {'trendora_anonymous_user_id_v1': 'guest:digest-widget'};

  final Map<String, String> values;

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
