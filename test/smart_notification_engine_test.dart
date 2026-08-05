import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/notifications/smart_notification_engine.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';

void main() {
  test('disabled preferences never send notifications', () async {
    final store = _MemoryStore();
    final gateway = _FakeGateway();
    final count = await SmartNotificationEngine(
      store: store,
      gateway: gateway,
    ).process('guest', [_event('one')]);
    expect(count, 0);
    expect(gateway.calls, 0);
  });

  test('filters small financial movements', () async {
    final store = _MemoryStore(
      preferences: const SmartNotificationPreferences(
        enabled: true,
        categories: {SmartNotificationCategory.finance},
        minimumPercentageMove: 3,
      ),
    );
    final gateway = _FakeGateway();
    final small = _event(
      'small',
      type: SmartNotificationEventType.percentageMove,
      percentageChange: 1.2,
    );
    final count = await SmartNotificationEngine(
      store: store,
      gateway: gateway,
    ).process('guest', [small]);
    expect(count, 0);
  });

  test('deduplicates an already delivered event', () async {
    final store = _MemoryStore(
      preferences: const SmartNotificationPreferences(
        enabled: true,
        categories: {SmartNotificationCategory.finance},
      ),
    );
    final gateway = _FakeGateway();
    final engine = SmartNotificationEngine(store: store, gateway: gateway);
    await engine.process('guest', [_event('same')]);
    await engine.process('guest', [_event('same')]);
    expect(gateway.calls, 1);
  });

  test(
    'batches at most three important events into one notification',
    () async {
      final store = _MemoryStore(
        preferences: const SmartNotificationPreferences(
          enabled: true,
          categories: {SmartNotificationCategory.finance},
        ),
      );
      final gateway = _FakeGateway();
      final count = await SmartNotificationEngine(
        store: store,
        gateway: gateway,
      ).process('guest', List.generate(5, (index) => _event('$index')));
      expect(count, 3);
      expect(gateway.calls, 1);
      expect(gateway.lastPayload, 'trend');
    },
  );

  test('daily limit prevents a second batch after three events', () async {
    final store = _MemoryStore(
      preferences: const SmartNotificationPreferences(
        enabled: true,
        categories: {SmartNotificationCategory.finance},
      ),
    );
    final gateway = _FakeGateway();
    final engine = SmartNotificationEngine(store: store, gateway: gateway);
    expect(
      await engine.process('guest', [_event('a'), _event('b'), _event('c')]),
      3,
    );
    expect(await engine.process('guest', [_event('d')]), 0);
    expect(gateway.calls, 1);
  });

  test(
    'gateway failure is contained and does not mark event delivered',
    () async {
      final store = _MemoryStore(
        preferences: const SmartNotificationPreferences(
          enabled: true,
          categories: {SmartNotificationCategory.finance},
        ),
      );
      final count = await SmartNotificationEngine(
        store: store,
        gateway: _FailingGateway(),
      ).process('guest', [_event('failure')]);
      expect(count, 0);
      expect(store.delivered, isEmpty);
    },
  );

  test('stale weather digest never creates a notification event', () {
    final snapshot = DailyDigestSnapshot(
      userId: 'guest',
      slotKey: '2026-07-27|morning',
      generatedAt: DateTime.utc(2026, 7, 27),
      items: [
        DailyDigestItem(
          id: 'weather',
          category: DailyDigestCategory.weather,
          title: 'İstanbul',
          detail: 'Eski hava verisi',
          source: 'Open-Meteo',
          updatedAt: DateTime.utc(2026, 7, 27),
          reference: 'İstanbul',
          itemType: 'weather',
          currentStatus: 'stale',
        ),
      ],
    );
    expect(DailyDigestNotificationEvents.fromSnapshot(snapshot), isEmpty);
  });

  test(
    'digest producers match supported categories and keep route payloads',
    () {
      final generatedAt = DateTime.utc(2026, 7, 27);
      final snapshot = DailyDigestSnapshot(
        userId: 'guest',
        slotKey: '2026-07-27|morning',
        generatedAt: generatedAt,
        items: [
          _digestItem('news', DailyDigestCategory.news, 'newsDetail'),
          _digestItem(
            'opportunity',
            DailyDigestCategory.opportunities,
            'opportunityDetail',
          ),
          _digestItem('asset', DailyDigestCategory.finance, 'trendAnalysis'),
          _digestItem('weather', DailyDigestCategory.weather, 'weatherCenter'),
          _digestItem('payment', DailyDigestCategory.payments, 'payments'),
        ],
      );

      final events = [
        ...DailyDigestNotificationEvents.fromSnapshot(snapshot),
        ...DailyDigestNotificationEvents.dailySummary(snapshot),
      ];
      expect(
        events.map((event) => event.category).toSet(),
        supportedSmartNotificationCategories,
      );
      expect(events, hasLength(5));
      for (final event in events) {
        final payload = jsonDecode(event.target) as Map<String, dynamic>;
        expect(payload['type'], isNotEmpty);
        expect(payload['target'], isNotEmpty);
      }
    },
  );
}

DailyDigestItem _digestItem(
  String id,
  DailyDigestCategory category,
  String target,
) => DailyDigestItem(
  id: id,
  category: category,
  title: 'Başlık $id',
  detail: 'Açıklama $id',
  source: 'Test',
  updatedAt: DateTime.utc(2026, 7, 27),
  reference: id,
  itemType: category.name,
  itemId: id,
  target: target,
);

SmartNotificationEvent _event(
  String id, {
  SmartNotificationEventType type = SmartNotificationEventType.trendChange,
  double? percentageChange,
}) => SmartNotificationEvent(
  id: id,
  category: SmartNotificationCategory.finance,
  type: type,
  title: 'Önemli gelişme $id',
  body: 'Gerçek olay açıklaması',
  source: 'Test kaynağı',
  occurredAt: DateTime.utc(2026, 7, 27),
  severity: SmartNotificationSeverity.high,
  target: 'trend',
  percentageChange: percentageChange,
);

class _MemoryStore implements SmartNotificationStateStore {
  _MemoryStore({this.preferences = const SmartNotificationPreferences()});

  SmartNotificationPreferences preferences;
  final Set<String> delivered = {};

  @override
  Future<SmartNotificationPreferences> loadPreferences(String userId) async =>
      preferences;

  @override
  Future<Set<String>> loadDeliveredIds(String userId) async => {...delivered};

  @override
  Future<void> saveDeliveredIds(String userId, Set<String> ids) async {
    delivered
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<void> savePreferences(
    String userId,
    SmartNotificationPreferences value,
  ) async {
    preferences = value;
  }
}

class _FakeGateway implements SmartNotificationGateway {
  int calls = 0;
  String? lastPayload;

  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    calls++;
    lastPayload = payload;
  }
}

class _FailingGateway implements SmartNotificationGateway {
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    throw StateError('notification unavailable');
  }
}
