import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SmartNotificationCategory {
  finance,
  company,
  news,
  opportunities,
  weather,
  reminders,
}

enum SmartNotificationEventType {
  priceTarget,
  percentageMove,
  unusualVolume,
  trendChange,
  companyDisclosure,
  financialReport,
  dividendOrSplit,
  newAnalysis,
  confidenceChange,
  importantNews,
  newOpportunity,
  upcomingReminder,
  severeWeather,
}

enum SmartNotificationSeverity { low, medium, high, critical }

class SmartNotificationPreferences {
  const SmartNotificationPreferences({
    this.enabled = false,
    this.categories = const {},
    this.minimumPercentageMove = 3,
    this.updatedAt,
  });

  final bool enabled;
  final Set<SmartNotificationCategory> categories;
  final double minimumPercentageMove;
  final DateTime? updatedAt;

  SmartNotificationPreferences copyWith({
    bool? enabled,
    Set<SmartNotificationCategory>? categories,
    double? minimumPercentageMove,
  }) => SmartNotificationPreferences(
    enabled: enabled ?? this.enabled,
    categories: categories ?? this.categories,
    minimumPercentageMove: minimumPercentageMove ?? this.minimumPercentageMove,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'categories': categories.map((item) => item.name).toList()..sort(),
    'minimumPercentageMove': minimumPercentageMove,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory SmartNotificationPreferences.fromJson(Map<String, dynamic> json) {
    final categories = <SmartNotificationCategory>{};
    for (final value
        in json['categories'] is List ? json['categories'] as List : const []) {
      for (final category in SmartNotificationCategory.values) {
        if (category.name == '$value') categories.add(category);
      }
    }
    return SmartNotificationPreferences(
      enabled: json['enabled'] == true,
      categories: categories,
      minimumPercentageMove:
          (json['minimumPercentageMove'] as num?)?.toDouble().clamp(1, 20) ?? 3,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
    );
  }
}

class SmartNotificationEvent {
  const SmartNotificationEvent({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    required this.source,
    required this.occurredAt,
    required this.severity,
    required this.target,
    this.percentageChange,
  });

  final String id;
  final SmartNotificationCategory category;
  final SmartNotificationEventType type;
  final String title;
  final String body;
  final String source;
  final DateTime occurredAt;
  final SmartNotificationSeverity severity;
  final String target;
  final double? percentageChange;
}

abstract interface class SmartNotificationStateStore {
  Future<SmartNotificationPreferences> loadPreferences(String userId);
  Future<void> savePreferences(
    String userId,
    SmartNotificationPreferences value,
  );
  Future<Set<String>> loadDeliveredIds(String userId);
  Future<void> saveDeliveredIds(String userId, Set<String> ids);
}

class SharedPreferencesSmartNotificationStore
    implements SmartNotificationStateStore {
  SharedPreferencesSmartNotificationStore(this._preferences);

  final SharedPreferences _preferences;
  static const _preferencesPrefix = 'trendora_smart_notifications_v1_';
  static const _deliveredPrefix = 'trendora_smart_notification_dedup_v1_';

  @override
  Future<SmartNotificationPreferences> loadPreferences(String userId) async {
    try {
      final raw = _preferences.getString(_key(_preferencesPrefix, userId));
      final decoded = raw == null ? null : jsonDecode(raw);
      return decoded is Map
          ? SmartNotificationPreferences.fromJson(
              Map<String, dynamic>.from(decoded),
            )
          : const SmartNotificationPreferences();
    } catch (_) {
      return const SmartNotificationPreferences();
    }
  }

  @override
  Future<void> savePreferences(
    String userId,
    SmartNotificationPreferences value,
  ) async {
    await _preferences.setString(
      _key(_preferencesPrefix, userId),
      jsonEncode(value.toJson()),
    );
  }

  @override
  Future<Set<String>> loadDeliveredIds(String userId) async =>
      (_preferences.getStringList(_key(_deliveredPrefix, userId)) ?? const [])
          .toSet();

  @override
  Future<void> saveDeliveredIds(String userId, Set<String> ids) async {
    await _preferences.setStringList(
      _key(_deliveredPrefix, userId),
      ids.take(500).toList(growable: false),
    );
  }

  static String _key(String prefix, String userId) =>
      '$prefix${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';
}

abstract interface class SmartNotificationGateway {
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  });
}

class LocalSmartNotificationGateway implements SmartNotificationGateway {
  LocalSmartNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.show(
      id: 5200,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'trendora_smart_notifications',
          'Akıllı Bildirimler',
          channelDescription:
              'Önemli ve kişiselleştirilmiş Trendora bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

class SmartNotificationEngine {
  factory SmartNotificationEngine({
    required SmartNotificationStateStore store,
    required SmartNotificationGateway gateway,
  }) {
    return SmartNotificationEngine._(store, gateway);
  }

  SmartNotificationEngine._(this._store, this._gateway);

  final SmartNotificationStateStore _store;
  final SmartNotificationGateway _gateway;

  Future<int> process(
    String userId,
    Iterable<SmartNotificationEvent> events,
  ) async {
    final preferences = await _store.loadPreferences(userId);
    if (!preferences.enabled) return 0;
    final delivered = await _store.loadDeliveredIds(userId);
    final accepted = events.where((event) {
      if (!preferences.categories.contains(event.category)) return false;
      if (delivered.contains(event.id)) return false;
      if (event.type == SmartNotificationEventType.percentageMove &&
          (event.percentageChange?.abs() ?? 0) <
              preferences.minimumPercentageMove) {
        return false;
      }
      return event.severity.index >= SmartNotificationSeverity.high.index;
    }).toList()..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    if (accepted.isEmpty) return 0;

    final selected = accepted.take(3).toList(growable: false);
    final first = selected.first;
    await _gateway.show(
      title: selected.length == 1
          ? first.title
          : '${selected.length} önemli gelişme',
      body: selected.length == 1
          ? first.body
          : selected.map((event) => event.title).join(' • '),
      payload: first.target,
    );
    delivered.addAll(selected.map((event) => event.id));
    await _store.saveDeliveredIds(userId, delivered);
    return selected.length;
  }
}
