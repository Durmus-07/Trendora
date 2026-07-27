import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'personalization_preferences.dart';

abstract interface class PersonalizationKeyValueStore {
  String? getString(String key);
  List<String>? getStringList(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

class SharedPreferencesPersonalizationStore
    implements PersonalizationKeyValueStore {
  SharedPreferencesPersonalizationStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesPersonalizationStore> create() async {
    return SharedPreferencesPersonalizationStore(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  List<String>? getStringList(String key) => _preferences.getStringList(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

class PersonalizationIdentityProvider {
  PersonalizationIdentityProvider(this._store);

  static const String _anonymousIdKey = 'trendora_anonymous_user_id_v1';
  final PersonalizationKeyValueStore _store;

  Future<String> resolve({String? authenticatedUserId}) async {
    final accountId = authenticatedUserId?.trim() ?? '';
    if (accountId.isNotEmpty) return 'account:$accountId';

    try {
      final existing = _store.getString(_anonymousIdKey)?.trim() ?? '';
      if (existing.isNotEmpty) return existing;

      final generated = 'guest:${_randomHex(16)}';
      await _store.setString(_anonymousIdKey, generated);
      return generated;
    } catch (_) {
      return 'guest-session:${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  static String _randomHex(int byteCount) {
    final random = Random.secure();
    return List.generate(
      byteCount,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class PersonalizationLocalRepository {
  PersonalizationLocalRepository(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const String _prefix = 'trendora_personalization_v1_';
  static const String _savedAnalysesKey = 'trendora_saved_analyses_v1';
  static const String _savedForecastsKey = 'saved_market_forecasts';

  final PersonalizationKeyValueStore _store;
  final DateTime Function() _now;

  Future<PersonalizationPreferences> load(String userId) async {
    final fallback = _legacyAwareDefaults(userId);
    final key = _keyFor(userId);

    try {
      final raw = _store.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        await save(fallback);
        return fallback;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid root value');
      final preferences = PersonalizationPreferences.fromJson(
        Map<String, dynamic>.from(decoded),
        fallbackUserId: userId,
        now: _now(),
      );
      return _mergeLegacyLinks(preferences, fallback);
    } catch (_) {
      await _preserveUnreadableValue(key);
      return fallback;
    }
  }

  Future<void> save(PersonalizationPreferences preferences) async {
    await _store.setString(
      _keyFor(preferences.userId),
      jsonEncode(preferences.toJson()),
    );
  }

  Future<PersonalizationPreferences> reset(String userId) async {
    await _store.remove(_keyFor(userId));
    final defaults = _legacyAwareDefaults(userId);
    await save(defaults);
    return defaults;
  }

  PersonalizationPreferences _legacyAwareDefaults(String userId) {
    final savedAnalysisIds = <String>{};
    final trackedAssets = <String>{};

    try {
      final rawAnalyses = _store.getString(_savedAnalysesKey);
      final decoded = rawAnalyses == null ? null : jsonDecode(rawAnalyses);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          final id = item['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) savedAnalysisIds.add(id);
        }
      }
    } catch (_) {
      // Eski kayıt bozuksa olduğu yerde korunur ve kişiselleştirme açılışı sürer.
    }

    try {
      for (final raw in _store.getStringList(_savedForecastsKey) ?? const []) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final symbol = decoded['symbol']?.toString().trim() ?? '';
        if (symbol.isNotEmpty) trackedAssets.add(symbol.toUpperCase());
      }
    } catch (_) {
      // Eski öngörü listesi hiçbir koşulda değiştirilmez.
    }

    return PersonalizationPreferences.defaults(
      userId: userId,
      now: _now(),
      savedAnalysisIds: savedAnalysisIds,
      trackedFinancialAssets: trackedAssets,
    );
  }

  PersonalizationPreferences _mergeLegacyLinks(
    PersonalizationPreferences current,
    PersonalizationPreferences legacy,
  ) {
    return current.copyWith(
      savedAnalysisIds: {
        ...current.savedAnalysisIds,
        ...legacy.savedAnalysisIds,
      },
      trackedFinancialAssets: {
        ...current.trackedFinancialAssets,
        ...legacy.trackedFinancialAssets,
      },
      updatedAt: current.updatedAt,
    );
  }

  Future<void> _preserveUnreadableValue(String key) async {
    try {
      final raw = _store.getString(key);
      if (raw == null || raw.isEmpty) return;
      final recoveryKey =
          '${key}_recovery_${_now().toUtc().millisecondsSinceEpoch}';
      await _store.setString(recoveryKey, raw);
    } catch (_) {
      // Depolama erişilemiyorsa güvenli varsayılan yine döndürülebilir.
    }
  }

  static String _keyFor(String userId) {
    final encoded = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return '$_prefix$encoded';
  }
}
