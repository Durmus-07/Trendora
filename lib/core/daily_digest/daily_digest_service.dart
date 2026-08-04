import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../personalization/personalization_preferences.dart';
import '../personalization/personalization_storage.dart';
import '../recommendations/recommendation_service.dart';
import '../news/saved_news_store.dart';
import '../news/news_clustering_service.dart' show normalizeContentUrl;
import '../saved_analysis_store.dart';
import '../weather/weather_data_policy.dart';
import 'daily_digest_models.dart';

abstract interface class DailyDigestDataSource {
  Future<List<Map<String, dynamic>>> news();
  Future<List<Map<String, dynamic>>> opportunities();
  Future<List<Map<String, dynamic>>> marketBoard();
  Future<Map<String, dynamic>?> weather();
  Future<List<SavedAnalysis>> savedAnalyses();
}

abstract interface class DailyDigestSavedDataSource {
  Future<List<SavedNews>> savedNews();
}

class AppDailyDigestDataSource
    implements DailyDigestDataSource, DailyDigestSavedDataSource {
  AppDailyDigestDataSource(
    this._preferences, [
    this._recommendationDataSource = const ApiRecommendationDataSource(),
  ]);

  final SharedPreferences _preferences;
  final RecommendationDataSource _recommendationDataSource;

  @override
  Future<List<Map<String, dynamic>>> news() => _recommendationDataSource.news();

  @override
  Future<List<Map<String, dynamic>>> opportunities() =>
      _recommendationDataSource.opportunities();

  @override
  Future<List<Map<String, dynamic>>> marketBoard() =>
      _recommendationDataSource.marketBoard();

  @override
  Future<List<SavedAnalysis>> savedAnalyses() => SavedAnalysisStore.load();

  @override
  Future<List<SavedNews>> savedNews() => SavedNewsStore.load();

  @override
  Future<Map<String, dynamic>?> weather() async {
    final latitude = _preferences.getDouble('weather_card_latitude');
    final longitude = _preferences.getDouble('weather_card_longitude');
    if (latitude == null || longitude == null) return null;

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/weather').replace(
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
        'name': _preferences.getString('weather_card_location') ?? 'Konumum',
      },
    );
    final response = await ApiClient.get(
      uri,
      cacheTtl: WeatherDataPolicy.cacheTtl,
      timeout: const Duration(seconds: 25),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }
}

class DailyDigestCache {
  DailyDigestCache(this._store);

  static const String _prefix = 'trendora_daily_digest_cache_v1_';
  final PersonalizationKeyValueStore _store;

  DailyDigestSnapshot? read(String userId) {
    try {
      final raw = _store.getString(_key(userId));
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is! Map) return null;
      final snapshot = DailyDigestSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return snapshot.userId == userId ? snapshot : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DailyDigestSnapshot snapshot) async {
    try {
      await _store.setString(
        _key(snapshot.userId),
        jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // Özet yine gösterilebilir; yalnızca tekrar kullanım önbelleği kaybolur.
    }
  }

  static String _key(String userId) {
    final encoded = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return '$_prefix$encoded';
  }
}

class DailyDigestService {
  DailyDigestService(this._dataSource, this._cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const Duration _financeFreshness = Duration(hours: 6);
  static const Duration _newsFreshness = Duration(hours: 24);
  static const Duration _opportunityFreshness = Duration(hours: 48);
  static const Duration _analysisFreshness = Duration(hours: 48);

  final DailyDigestDataSource _dataSource;
  final DailyDigestCache _cache;
  final DateTime Function() _now;

  DailyDigestSnapshot? cached(String userId) => _cache.read(userId);

  Future<DailyDigestSnapshot?> loadDue(
    PersonalizationPreferences preferences, {
    bool forceRefresh = false,
  }) async {
    if (!preferences.dailyDigestEnabled) return null;
    final now = _now();
    if (now.isBefore(scheduledAt(preferences, now))) return null;

    final slotKey = _slotKey(preferences, now);
    final previous = _cache.read(preferences.userId);
    if (!forceRefresh && previous?.slotKey == slotKey) {
      return _freshCachedSnapshot(previous!, now);
    }

    final items = <DailyDigestItem>[];
    List<SavedAnalysis> savedAnalyses = const [];
    List<SavedNews> savedNews = const [];
    try {
      savedAnalyses = await _dataSource.savedAnalyses();
    } catch (_) {}
    if (_dataSource case final DailyDigestSavedDataSource savedSource) {
      try {
        savedNews = await savedSource.savedNews();
      } catch (_) {}
    }
    final categories = preferences.digestCategories;

    if (categories.contains(DailyDigestCategory.finance) &&
        preferences.trackedFinancialAssets.isNotEmpty) {
      try {
        items.addAll(
          _finance(await _dataSource.marketBoard(), preferences, now),
        );
      } catch (_) {}
    }
    if (categories.contains(DailyDigestCategory.news)) {
      try {
        items.addAll(_news(await _dataSource.news(), preferences, now));
      } catch (_) {}
    }
    if (categories.contains(DailyDigestCategory.opportunities)) {
      try {
        items.addAll(
          _opportunities(await _dataSource.opportunities(), preferences, now),
        );
      } catch (_) {}
    }
    if (categories.contains(DailyDigestCategory.weather)) {
      try {
        final weather = await _dataSource.weather();
        final item = weather == null ? null : _weather(weather, now);
        if (item != null) items.add(item);
      } catch (_) {}
    }
    if (categories.contains(DailyDigestCategory.savedAnalyses)) {
      items.addAll(_savedAnalyses(savedAnalyses, preferences, now));
    }

    final previousEventIds = previous?.slotKey == slotKey
        ? const <String>{}
        : previous?.items
                  .where((item) => _isOneTimeEvent(item.category))
                  .map((item) => item.id)
                  .toSet() ??
              const <String>{};
    final unique = <String, DailyDigestItem>{};
    for (final item in items) {
      if (_isOneTimeEvent(item.category) &&
          previousEventIds.contains(item.id)) {
        continue;
      }
      unique.putIfAbsent(item.id, () => item);
    }

    final snapshot = DailyDigestSnapshot(
      userId: preferences.userId,
      slotKey: slotKey,
      generatedAt: now.toUtc(),
      items: List.unmodifiable(unique.values),
      statistics: _statistics(preferences, savedAnalyses, savedNews, now),
    );
    await _cache.save(snapshot);
    return snapshot;
  }

  DateTime scheduledAt(PersonalizationPreferences preferences, DateTime day) {
    final parts = preferences.digestTime.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  DateTime nextScheduledAt(PersonalizationPreferences preferences) {
    final now = _now();
    final today = scheduledAt(preferences, now);
    return now.isBefore(today) ? today : today.add(const Duration(days: 1));
  }

  List<DailyDigestItem> _finance(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
    DateTime now,
  ) {
    final tracked = preferences.trackedFinancialAssets
        .map((item) => item.toUpperCase())
        .toSet();
    if (tracked.isEmpty) return const [];

    return rows
        .map((row) {
          final symbol = _text(row, const ['symbol']).toUpperCase();
          final label = _text(row, const ['label', 'symbol']);
          if (!tracked.contains(symbol) &&
              !tracked.contains(label.toUpperCase())) {
            return null;
          }
          final updatedAt = _date(row);
          final source = _source(row);
          final price = _number(row['price']);
          final change = _number(row['changePercent'] ?? row['change']);
          if (!_isFresh(updatedAt, _financeFreshness, now) ||
              source.isEmpty ||
              price == null ||
              change == null) {
            return null;
          }
          final currency = _text(row, const ['currency']);
          final priceText = _formatNumber(price);
          final changeText =
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%';
          return DailyDigestItem(
            id: 'finance:$symbol',
            category: DailyDigestCategory.finance,
            title: label,
            detail:
                'Fiyat: $priceText${currency.isEmpty ? '' : ' $currency'} • Günlük değişim: $changeText',
            source: source,
            updatedAt: updatedAt!.toUtc(),
            reference: symbol,
            itemType: 'asset',
            itemId: _text(row, const ['id', 'internalAssetId']),
            internalAssetId: _text(row, const ['internalAssetId', 'id']),
            canonicalSymbol: symbol,
            snapshot: Map<String, dynamic>.from(row),
            target: 'assetDetail',
            targetArguments: {'canonicalSymbol': symbol},
            dataTime: updatedAt.toUtc(),
            currentStatus: 'active',
          );
        })
        .whereType<DailyDigestItem>()
        .take(3)
        .toList(growable: false);
  }

  List<DailyDigestItem> _news(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
    DateTime now,
  ) {
    final followed = preferences.followedNewsCategories
        .map((item) => item.toLowerCase())
        .toSet();
    final result = <DailyDigestItem>[];
    for (final row in rows) {
      final title = _text(row, const ['title']);
      final reference = _text(row, const ['id', 'url', 'link']);
      final category = _text(row, const ['category']).toLowerCase();
      final source = _source(row);
      final updatedAt = _date(row);
      final importance = _number(row['importanceScore']) ?? 0;
      final trend = _number(row['trendScore']) ?? 0;
      final important =
          row['isBreaking'] == true || importance >= 60 || trend >= 70;
      if (!important ||
          title.isEmpty ||
          reference.isEmpty ||
          source.isEmpty ||
          !_isFresh(updatedAt, _newsFreshness, now)) {
        continue;
      }
      if (followed.isNotEmpty && !followed.contains(category)) continue;
      result.add(
        DailyDigestItem(
          id: 'news:$reference',
          category: DailyDigestCategory.news,
          title: title,
          detail: _text(row, const ['description', 'summary']),
          source: source,
          updatedAt: updatedAt!.toUtc(),
          reference: reference,
          itemType: 'news',
          itemId: _text(row, const ['id']),
          originalUrl: _text(row, const ['url', 'link']),
          normalizedUrl: normalizeContentUrl(_text(row, const ['url', 'link'])),
          snapshot: Map<String, dynamic>.from(row),
          target: 'newsDetail',
          targetArguments: {
            if (_text(row, const ['id']).isNotEmpty)
              'itemId': _text(row, const ['id']),
          },
          dataTime: updatedAt.toUtc(),
          currentStatus: 'active',
        ),
      );
      if (result.length == 3) break;
    }
    return result;
  }

  List<DailyDigestItem> _opportunities(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
    DateTime now,
  ) {
    final followed = preferences.followedOpportunityCategories
        .map((item) => item.toLowerCase())
        .toSet();
    final result = <DailyDigestItem>[];
    for (final row in rows) {
      if (row['active'] == false) continue;
      final title = _text(row, const ['title', 'name', 'productName']);
      final reference = _text(row, const ['id', 'officialUrl', 'url', 'link']);
      final source = _source(row);
      final updatedAt = _date(row);
      final category = _text(row, const ['category']).toLowerCase();
      if (title.isEmpty ||
          reference.isEmpty ||
          source.isEmpty ||
          !_isFresh(updatedAt, _opportunityFreshness, now)) {
        continue;
      }
      if (followed.isNotEmpty && !followed.contains(category)) continue;
      final price = _text(row, const ['price', 'newPrice', 'salePrice']);
      final store = _text(row, const ['store', 'market']);
      result.add(
        DailyDigestItem(
          id: 'opportunity:$reference',
          category: DailyDigestCategory.opportunities,
          title: title,
          detail: [store, price].where((item) => item.isNotEmpty).join(' • '),
          source: source,
          updatedAt: updatedAt!.toUtc(),
          reference: reference,
          itemType: 'opportunity',
          itemId: _text(row, const ['id', 'externalId']),
          opportunityId: _text(row, const ['id', 'externalId']),
          originalUrl: _text(row, const ['officialUrl', 'url', 'link']),
          normalizedUrl: normalizeContentUrl(
            _text(row, const ['officialUrl', 'url', 'link']),
          ),
          snapshot: Map<String, dynamic>.from(row),
          target: 'opportunityDetail',
          targetArguments: {
            if (_text(row, const ['id', 'externalId']).isNotEmpty)
              'opportunityId': _text(row, const ['id', 'externalId']),
          },
          dataTime: updatedAt.toUtc(),
          currentStatus: row['active'] == false ? 'expired' : 'active',
        ),
      );
      if (result.length == 3) break;
    }
    return result;
  }

  DailyDigestItem? _weather(Map<String, dynamic> data, DateTime now) {
    if (WeatherDataPolicy.isStale(data, now: now)) return null;
    final updatedAt = WeatherDataPolicy.updatedAt(data);
    final source = WeatherDataPolicy.sourceName(data);
    final current = data['current'];
    final location = data['location'];
    if (updatedAt == null || source == 'Bilinmiyor' || current is! Map) {
      return null;
    }
    final title = location is Map ? '${location['name'] ?? ''}'.trim() : '';
    final description = '${current['description'] ?? ''}'.trim();
    final temperature = _number(current['temperature']);
    if (title.isEmpty || description.isEmpty || temperature == null) {
      return null;
    }

    final details = <String>[
      '$description • ${temperature.toStringAsFixed(1)}°',
    ];
    final warnings = data['warnings'];
    if (warnings is List) {
      for (final warning in warnings.whereType<Map>().take(2)) {
        final message = '${warning['message'] ?? ''}'.trim();
        if (message.isNotEmpty) details.add(message);
      }
    }
    return DailyDigestItem(
      id: 'weather:${updatedAt.toUtc().toIso8601String()}',
      category: DailyDigestCategory.weather,
      title: title,
      detail: details.join(' • '),
      source: source,
      updatedAt: updatedAt.toUtc(),
      reference: title,
      itemType: 'weather',
      snapshot: Map<String, dynamic>.from(data),
      target: 'weatherCenter',
      dataTime: updatedAt.toUtc(),
      currentStatus: data['stale'] == true ? 'stale' : 'active',
    );
  }

  List<DailyDigestItem> _savedAnalyses(
    List<SavedAnalysis> analyses,
    PersonalizationPreferences preferences,
    DateTime now,
  ) {
    final selected = preferences.savedAnalysisIds;
    final result = <DailyDigestItem>[];
    for (final analysis in analyses) {
      if (selected.isNotEmpty && !selected.contains(analysis.id)) continue;
      final checkedAt = analysis.checkedAt;
      final starting = analysis.startingPrice;
      final latest = analysis.latestPrice;
      if (!_isFresh(checkedAt, _analysisFreshness, now) ||
          starting == null ||
          latest == null ||
          starting == 0) {
        continue;
      }
      final change = ((latest - starting) / starting) * 100;
      if (change.abs() < 1) continue;
      result.add(
        DailyDigestItem(
          id: 'analysis:${analysis.id}:${checkedAt!.toUtc().toIso8601String()}',
          category: DailyDigestCategory.savedAnalyses,
          title: analysis.title.isEmpty ? analysis.query : analysis.title,
          detail:
              'Kaydedildiğinden beri değişim: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
          source: 'Kaydedilen analiz',
          updatedAt: checkedAt.toUtc(),
          reference: analysis.query,
          itemType: 'analysis',
          itemId: analysis.id,
          canonicalSymbol: analysis.query.trim().toUpperCase(),
          savedAt: analysis.savedAt,
          snapshot: analysis.toJson(),
          target: 'analysisDetail',
          targetArguments: {'query': analysis.query, 'analysisId': analysis.id},
          dataTime: checkedAt.toUtc(),
          currentStatus: 'saved',
        ),
      );
      if (result.length == 3) break;
    }
    return result;
  }

  String _slotKey(PersonalizationPreferences preferences, DateTime now) {
    final categories =
        preferences.digestCategories.map((item) => item.name).toList()..sort();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '$date|${preferences.digestPeriod.name}|${preferences.digestTime}|${categories.join(',')}';
  }

  static bool _isOneTimeEvent(DailyDigestCategory category) {
    return category == DailyDigestCategory.news ||
        category == DailyDigestCategory.opportunities ||
        category == DailyDigestCategory.savedAnalyses;
  }

  DailyDigestSnapshot _freshCachedSnapshot(
    DailyDigestSnapshot snapshot,
    DateTime now,
  ) {
    final freshItems = snapshot.items
        .where((item) {
          final maximumAge = switch (item.category) {
            DailyDigestCategory.finance => _financeFreshness,
            DailyDigestCategory.news => _newsFreshness,
            DailyDigestCategory.opportunities => _opportunityFreshness,
            DailyDigestCategory.weather => WeatherDataPolicy.staleAfter,
            DailyDigestCategory.savedAnalyses => _analysisFreshness,
            DailyDigestCategory.payments ||
            DailyDigestCategory.reminders => const Duration(hours: 24),
          };
          return _isFresh(item.updatedAt, maximumAge, now);
        })
        .toList(growable: false);
    return DailyDigestSnapshot(
      userId: snapshot.userId,
      slotKey: snapshot.slotKey,
      generatedAt: snapshot.generatedAt,
      items: freshItems,
      statistics: snapshot.statistics,
    );
  }

  static bool _isFresh(DateTime? value, Duration maximumAge, DateTime now) {
    if (value == null) return false;
    final age = now.toUtc().difference(value.toUtc());
    return age >= const Duration(minutes: -10) && age <= maximumAge;
  }

  static DateTime? _date(Map<String, dynamic> row) {
    final sourceInfo = row['sourceInfo'];
    if (sourceInfo is Map) {
      final nested = Map<String, dynamic>.from(sourceInfo);
      final value = _text(nested, const ['updatedAt', 'fetchedAt', 'dataTime']);
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(
      _text(row, const [
        'updatedAt',
        'publishedAt',
        'createdAt',
        'dataTime',
        'date',
      ]),
    );
  }

  static String _source(Map<String, dynamic> row) {
    final sourceInfo = row['sourceInfo'];
    if (sourceInfo is Map) {
      final value = _text(Map<String, dynamic>.from(sourceInfo), const [
        'name',
      ]);
      if (value.isNotEmpty) return value;
    }
    return _text(row, const ['source', 'feedSource', 'store', 'market']);
  }

  static String _text(Map<dynamic, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '.'));
  }

  static String _formatNumber(double value) {
    final digits = value.abs() < 1000 ? 2 : 0;
    return value.toStringAsFixed(digits).replaceAll('.', ',');
  }

  static DailyDigestStatistics _statistics(
    PersonalizationPreferences preferences,
    List<SavedAnalysis> analyses,
    List<SavedNews> news,
    DateTime now,
  ) {
    final assets = preferences.trackedFinancialAssets
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final uniqueAnalyses = <String, SavedAnalysis>{};
    for (final item in analyses) {
      uniqueAnalyses.putIfAbsent(item.id.trim(), () => item);
    }
    final uniqueNews = <String, SavedNews>{};
    for (final item in news) {
      final key = item.id.trim().isNotEmpty
          ? item.id.trim()
          : normalizeContentUrl(item.url);
      if (key.isNotEmpty) uniqueNews.putIfAbsent(key, () => item);
    }
    final cutoff = now.subtract(const Duration(hours: 24));
    final updatedAnalyses = uniqueAnalyses.values.where(
      (item) => item.checkedAt != null && item.checkedAt!.isAfter(cutoff),
    );
    return DailyDigestStatistics(
      savedAssetCount: assets.length,
      savedAnalysisCount: uniqueAnalyses.length,
      savedNewsCount: uniqueNews.length,
      updatedLast24HoursCount: updatedAnalyses.length,
      priceChangedCount: uniqueAnalyses.values.where((item) {
        final start = item.startingPrice;
        final latest = item.latestPrice;
        return start != null &&
            latest != null &&
            (latest - start).abs() > 0.000001;
      }).length,
    );
  }
}
