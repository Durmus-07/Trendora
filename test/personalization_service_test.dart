import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';
import 'package:trendora_app/core/personalization/interest_catalog.dart';
import 'package:trendora_app/core/personalization/personalization_preferences.dart';
import 'package:trendora_app/core/personalization/personalization_service.dart';
import 'package:trendora_app/core/personalization/personalization_storage.dart';

void main() {
  group('PersonalizationPreferences', () {
    test('central catalog contains every phase-one interest', () {
      expect(TrendoraInterestCatalog.all, hasLength(17));
      expect(TrendoraInterestCatalog.contains('stock_market'), isTrue);
      expect(TrendoraInterestCatalog.contains('world_agenda'), isTrue);
    });

    test('missing and invalid fields safely use defaults', () {
      final preferences = PersonalizationPreferences.fromJson(
        {
          'interests': ['technology', 'unknown'],
          'digestTime': '99:99',
        },
        fallbackUserId: 'guest:test',
        now: DateTime.utc(2026, 1, 1),
      );

      expect(preferences.userId, 'guest:test');
      expect(preferences.personalizationEnabled, isFalse);
      expect(preferences.interests, {'technology'});
      expect(preferences.digestTime, '09:00');
      expect(preferences.digestPeriod, DailyDigestPeriod.morning);
      expect(
        preferences.digestCategories,
        containsAll(DailyDigestCategory.values),
      );
      expect(
        preferences.modelVersion,
        PersonalizationPreferences.currentModelVersion,
      );
    });

    test('daily digest additions round-trip without changing legacy fields', () {
      final original = PersonalizationPreferences.defaults(
        userId: 'guest:digest',
      ).copyWith(
        dailyDigestEnabled: true,
        digestPeriod: DailyDigestPeriod.evening,
        digestTime: '19:30',
        digestCategories: {
          DailyDigestCategory.news,
          DailyDigestCategory.weather,
        },
        interests: {'technology'},
      );

      final restored = PersonalizationPreferences.fromJson(
        original.toJson(),
        fallbackUserId: 'guest:fallback',
      );

      expect(restored.userId, 'guest:digest');
      expect(restored.dailyDigestEnabled, isTrue);
      expect(restored.digestPeriod, DailyDigestPeriod.evening);
      expect(restored.digestTime, '19:30');
      expect(
        restored.digestCategories,
        {DailyDigestCategory.news, DailyDigestCategory.weather},
      );
      expect(restored.interests, {'technology'});
    });
  });

  group('PersonalizationLocalRepository', () {
    test('persists data and keeps different users isolated', () async {
      final memory = _MemoryStore();
      final repository = PersonalizationLocalRepository(memory);
      final first = PersonalizationPreferences.defaults(
        userId: 'account:first',
      ).copyWith(interests: {'technology'});
      final second = PersonalizationPreferences.defaults(
        userId: 'account:second',
      ).copyWith(interests: {'sports'});

      await repository.save(first);
      await repository.save(second);

      expect((await repository.load(first.userId)).interests, {'technology'});
      expect((await repository.load(second.userId)).interests, {'sports'});
    });

    test(
      'links legacy analyses and forecasts without changing old keys',
      () async {
        final oldAnalyses = jsonEncode([
          {'id': 'analysis-1', 'query': 'ALTIN'},
        ]);
        final oldForecasts = [
          jsonEncode({'symbol': 'bimas'}),
        ];
        final memory = _MemoryStore(
          strings: {'trendora_saved_analyses_v1': oldAnalyses},
          stringLists: {'saved_market_forecasts': oldForecasts},
        );

        final loaded = await PersonalizationLocalRepository(
          memory,
        ).load('guest:legacy');

        expect(loaded.savedAnalysisIds, {'analysis-1'});
        expect(loaded.trackedFinancialAssets, {'BIMAS'});
        expect(memory.getString('trendora_saved_analyses_v1'), oldAnalyses);
        expect(memory.getStringList('saved_market_forecasts'), oldForecasts);
      },
    );

    test(
      'corrupt data returns defaults and preserves a recovery copy',
      () async {
        final memory = _MemoryStore();
        final repository = PersonalizationLocalRepository(
          memory,
          now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        );
        await repository.save(
          PersonalizationPreferences.defaults(userId: 'guest:corrupt'),
        );
        final personalizationKey = memory.strings.keys.single;
        memory.strings[personalizationKey] = '{broken';

        final loaded = await repository.load('guest:corrupt');

        expect(loaded.personalizationEnabled, isFalse);
        expect(memory.strings[personalizationKey], '{broken');
        expect(
          memory.strings.entries.any(
            (entry) =>
                entry.key.contains('_recovery_') && entry.value == '{broken',
          ),
          isTrue,
        );
      },
    );
  });

  group('PersonalizationService', () {
    test('adds, removes, persists and resets interests safely', () async {
      final memory = _MemoryStore(
        strings: {
          'trendora_anonymous_user_id_v1': 'guest:stable',
          'trendora_saved_analyses_v1': jsonEncode([
            {'id': 'keep-analysis'},
          ]),
        },
      );
      final service = _service(memory);

      await service.initialize();
      await service.setPersonalizationEnabled(true);
      await service.addInterest('technology');
      await service.addInterest('sports');
      await service.removeInterest('sports');
      await service.updateNotificationPreferences(['economy']);

      final reopened = _service(memory);
      final restored = await reopened.initialize();
      expect(restored.personalizationEnabled, isTrue);
      expect(restored.interests, {'technology'});
      expect(restored.notificationCategories, {'economy'});

      final reset = await reopened.resetPreferences();
      expect(reset.personalizationEnabled, isFalse);
      expect(reset.interests, isEmpty);
      expect(reset.savedAnalysisIds, contains('keep-analysis'));
    });

    test('rejects unknown interests and can disable personalization', () async {
      final memory = _MemoryStore();
      final service = _service(memory);

      await service.initialize();
      await service.addInterest('not-in-catalog');
      await service.setPersonalizationEnabled(true);
      final disabled = await service.setPersonalizationEnabled(false);

      expect(disabled.interests, isEmpty);
      expect(disabled.personalizationEnabled, isFalse);
    });
  });
}

PersonalizationService _service(_MemoryStore memory) {
  return PersonalizationService(
    repository: PersonalizationLocalRepository(memory),
    identityProvider: PersonalizationIdentityProvider(memory),
  );
}

class _MemoryStore implements PersonalizationKeyValueStore {
  _MemoryStore({
    Map<String, String>? strings,
    Map<String, List<String>>? stringLists,
  }) : strings = {...?strings},
       stringLists = {
         for (final entry in (stringLists ?? {}).entries)
           entry.key: List<String>.from(entry.value),
       };

  final Map<String, String> strings;
  final Map<String, List<String>> stringLists;

  @override
  String? getString(String key) => strings[key];

  @override
  List<String>? getStringList(String key) {
    final value = stringLists[key];
    return value == null ? null : List<String>.from(value);
  }

  @override
  Future<bool> remove(String key) async {
    final removedString = strings.remove(key) != null;
    final removedList = stringLists.remove(key) != null;
    return removedString || removedList;
  }

  @override
  Future<bool> setString(String key, String value) async {
    strings[key] = value;
    return true;
  }
}
