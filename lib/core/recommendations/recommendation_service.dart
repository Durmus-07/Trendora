import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../personalization/interest_catalog.dart';
import '../personalization/personalization_preferences.dart';

enum RecommendationType { news, opportunity, finance }

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.reason,
    required this.source,
    required this.updatedAt,
    required this.score,
    required this.reference,
    this.snapshot = const {},
  });

  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final String reason;
  final String source;
  final DateTime? updatedAt;
  final int score;
  final String reference;
  final Map<String, dynamic> snapshot;
}

class RecommendationBundle {
  const RecommendationBundle({this.today = const [], this.forYou = const []});

  final List<RecommendationItem> today;
  final List<RecommendationItem> forYou;
  bool get isEmpty => today.isEmpty && forYou.isEmpty;
}

abstract interface class RecommendationDataSource {
  Future<List<Map<String, dynamic>>> news();
  Future<List<Map<String, dynamic>>> opportunities();
  Future<List<Map<String, dynamic>>> marketBoard();
}

class ApiRecommendationDataSource implements RecommendationDataSource {
  const ApiRecommendationDataSource();

  @override
  Future<List<Map<String, dynamic>>> news() async {
    final uri = Uri.parse(ApiConfig.news).replace(
      queryParameters: const {
        'period': '7d',
        'category': 'tumu',
        'page': '1',
        'limit': '30',
      },
    );
    return _load(uri, const ['news', 'items', 'data']);
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities() {
    final uri = Uri.parse(
      ApiConfig.opportunities,
    ).replace(queryParameters: const {'limit': '40'});
    return _load(uri, const ['opportunities', 'items', 'data']);
  }

  @override
  Future<List<Map<String, dynamic>>> marketBoard() {
    return _load(Uri.parse('${ApiConfig.trends}/market-board'), const [
      'items',
      'data',
    ]);
  }

  Future<List<Map<String, dynamic>>> _load(
    Uri uri,
    List<String> responseKeys,
  ) async {
    final response = await ApiClient.get(
      uri,
      cacheTtl: const Duration(minutes: 2),
      timeout: const Duration(seconds: 35),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) return const [];
    for (final key in responseKeys) {
      final raw = body[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const [];
  }
}

class RecommendationFeedback {
  const RecommendationFeedback({
    this.hiddenIds = const {},
    this.reducedTypes = const {},
    this.snoozedUntil = const {},
  });

  final Set<String> hiddenIds;
  final Set<String> reducedTypes;
  final Map<String, DateTime> snoozedUntil;
}

class RecommendationFeedbackStore {
  RecommendationFeedbackStore(this._preferences);

  static const String _prefix = 'trendora_recommendation_feedback_v1_';
  final SharedPreferences _preferences;

  static Future<RecommendationFeedbackStore> create() async {
    return RecommendationFeedbackStore(await SharedPreferences.getInstance());
  }

  RecommendationFeedback load(String userId) {
    try {
      final raw = _preferences.getString(_key(userId));
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is! Map) return const RecommendationFeedback();
      return RecommendationFeedback(
        hiddenIds: _strings(decoded['hiddenIds']),
        reducedTypes: _strings(decoded['reducedTypes']),
        snoozedUntil: _dates(decoded['snoozedUntil']),
      );
    } catch (_) {
      return const RecommendationFeedback();
    }
  }

  Future<void> hide(String userId, String recommendationId) async {
    final current = load(userId);
    await _save(
      userId,
      hiddenIds: {...current.hiddenIds, recommendationId},
      reducedTypes: current.reducedTypes,
      snoozedUntil: current.snoozedUntil,
    );
  }

  Future<void> reduceType(String userId, RecommendationType type) async {
    final current = load(userId);
    await _save(
      userId,
      hiddenIds: current.hiddenIds,
      reducedTypes: {...current.reducedTypes, type.name},
      snoozedUntil: current.snoozedUntil,
    );
  }

  Future<void> remindLater(String userId, String recommendationId) async {
    final current = load(userId);
    await _save(
      userId,
      hiddenIds: current.hiddenIds,
      reducedTypes: current.reducedTypes,
      snoozedUntil: {
        ...current.snoozedUntil,
        recommendationId: DateTime.now().add(const Duration(days: 1)).toUtc(),
      },
    );
  }

  Future<void> markInterested(String userId, String recommendationId) async {
    await _preferences.setString(
      '${_key(userId)}_interested_$recommendationId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _save(
    String userId, {
    required Set<String> hiddenIds,
    required Set<String> reducedTypes,
    required Map<String, DateTime> snoozedUntil,
  }) async {
    await _preferences.setString(
      _key(userId),
      jsonEncode({
        'hiddenIds': hiddenIds.toList()..sort(),
        'reducedTypes': reducedTypes.toList()..sort(),
        'snoozedUntil': snoozedUntil.map(
          (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
        ),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Set<String> _strings(dynamic value) {
    if (value is! List) return {};
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static Map<String, DateTime> _dates(dynamic value) {
    if (value is! Map) return {};
    final result = <String, DateTime>{};
    for (final entry in value.entries) {
      final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
      if (parsed != null) result[entry.key.toString()] = parsed.toUtc();
    }
    return result;
  }

  static String _key(String userId) =>
      '$_prefix${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';
}

class RecommendationService {
  factory RecommendationService({
    required RecommendationDataSource dataSource,
  }) {
    return RecommendationService._(dataSource);
  }

  const RecommendationService._(this._dataSource);

  final RecommendationDataSource _dataSource;

  Future<RecommendationBundle> load(
    PersonalizationPreferences preferences, {
    RecommendationFeedback feedback = const RecommendationFeedback(),
  }) async {
    if (!preferences.personalizationEnabled) {
      return const RecommendationBundle();
    }

    final candidates = <RecommendationItem>[];
    if (_needsNews(preferences)) {
      try {
        candidates.addAll(_news(await _dataSource.news(), preferences));
      } catch (_) {}
    }
    if (_needsOpportunities(preferences)) {
      try {
        candidates.addAll(
          _opportunities(await _dataSource.opportunities(), preferences),
        );
      } catch (_) {}
    }
    if (_needsFinance(preferences)) {
      try {
        candidates.addAll(
          _finance(await _dataSource.marketBoard(), preferences),
        );
      } catch (_) {}
    }

    final unique = <String, RecommendationItem>{};
    for (final item in candidates) {
      if (feedback.hiddenIds.contains(item.id)) continue;
      final snoozedUntil = feedback.snoozedUntil[item.id];
      if (snoozedUntil != null &&
          snoozedUntil.isAfter(DateTime.now().toUtc())) {
        continue;
      }
      final adjusted = feedback.reducedTypes.contains(item.type.name)
          ? RecommendationItem(
              id: item.id,
              type: item.type,
              title: item.title,
              description: item.description,
              reason: item.reason,
              source: item.source,
              updatedAt: item.updatedAt,
              score: item.score - 40,
              reference: item.reference,
              snapshot: item.snapshot,
            )
          : item;
      final existing = unique[item.id];
      if (existing == null || adjusted.score > existing.score) {
        unique[item.id] = adjusted;
      }
    }
    final ranked = unique.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty) return const RecommendationBundle();

    final today = ranked.take(5).toList(growable: false);
    final todayIds = today.map((item) => item.id).toSet();
    final forYou = ranked
        .where((item) => !todayIds.contains(item.id))
        .take(5)
        .toList(growable: false);
    return RecommendationBundle(today: today, forYou: forYou);
  }

  List<RecommendationItem> _news(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
  ) {
    final result = <RecommendationItem>[];
    for (final row in rows) {
      final title = _text(row, const ['title', 'name']);
      if (title.isEmpty) continue;
      final category = _text(row, const ['category']).toLowerCase();
      final interest = _matchingNewsInterest(
        preferences.interests,
        category,
        title,
      );
      if (interest == null) continue;
      final reference = _text(row, const ['id', 'url', 'link', 'title']);
      result.add(
        RecommendationItem(
          id: 'news:$reference',
          type: RecommendationType.news,
          title: title,
          description: _text(row, const ['description', 'summary']),
          reason: 'İlgi alanın: ${_interestLabel(interest)}',
          source: _source(row),
          updatedAt: _date(row),
          score: 80 + _freshnessScore(_date(row)),
          reference: reference,
          snapshot: Map<String, dynamic>.from(row),
        ),
      );
    }
    return result;
  }

  List<RecommendationItem> _opportunities(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
  ) {
    final interests = preferences.interests;
    final interested =
        interests.contains('market_opportunities') ||
        interests.contains('shopping_opportunities') ||
        interests.contains('automotive');
    return rows
        .where((row) => row['active'] != false)
        .map((row) {
          final title = _text(row, const ['title', 'name', 'productName']);
          final reference = _text(row, const [
            'id',
            'officialUrl',
            'url',
            'title',
          ]);
          final date = _date(row);
          return RecommendationItem(
            id: 'opportunity:$reference',
            type: RecommendationType.opportunity,
            title: title,
            description: _opportunityDescription(row),
            reason: interested
                ? 'Takip ettiğin fırsat kategorisiyle eşleşiyor'
                : 'Sana uygun güncel ve doğrulanmış fırsat',
            source: _source(row),
            updatedAt: date,
            score: 70 + _freshnessScore(date),
            reference: reference,
            snapshot: Map<String, dynamic>.from(row),
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }

  List<RecommendationItem> _finance(
    List<Map<String, dynamic>> rows,
    PersonalizationPreferences preferences,
  ) {
    final tracked = preferences.trackedFinancialAssets
        .map((item) => item.toUpperCase())
        .toSet();
    return rows
        .map((row) {
          final symbol = _text(row, const ['symbol', 'label']).toUpperCase();
          final label = _text(row, const ['label', 'symbol']);
          final isTracked =
              tracked.contains(symbol) || tracked.contains(label.toUpperCase());
          final generalMatch = _financeInterestMatch(
            preferences.interests,
            symbol,
            label,
          );
          if (!isTracked && generalMatch == null) return null;
          final date = _date(row);
          return RecommendationItem(
            id: 'finance:$symbol',
            type: RecommendationType.finance,
            title: label,
            description: _financialDescription(row),
            reason: isTracked
                ? 'Takip ettiğin finansal varlık'
                : 'İlgi alanın: ${_interestLabel(generalMatch!)}',
            source: _source(row),
            updatedAt: date,
            score: (isTracked ? 100 : 75) + _freshnessScore(date),
            reference: symbol,
            snapshot: Map<String, dynamic>.from(row),
          );
        })
        .whereType<RecommendationItem>()
        .toList(growable: false);
  }

  static bool _needsNews(PersonalizationPreferences preferences) => true;

  static bool _needsOpportunities(PersonalizationPreferences preferences) =>
      true;

  static bool _needsFinance(PersonalizationPreferences preferences) =>
      preferences.trackedFinancialAssets.isNotEmpty ||
      preferences.interests.any(
        const {'stock_market', 'gold', 'foreign_exchange', 'crypto'}.contains,
      );

  static String? _matchingNewsInterest(
    Set<String> interests,
    String category,
    String title,
  ) {
    final haystack = '$category ${title.toLowerCase()}';
    for (final entry in _newsKeywords.entries) {
      if (!interests.contains(entry.key)) continue;
      if (entry.value.any(haystack.contains)) return entry.key;
    }
    return null;
  }

  static String? _financeInterestMatch(
    Set<String> interests,
    String symbol,
    String label,
  ) {
    final value = '$symbol $label'.toLowerCase();
    if (interests.contains('gold') && value.contains('altın')) return 'gold';
    if (interests.contains('crypto') &&
        (value.contains('btc') ||
            value.contains('eth') ||
            value.contains('bitcoin'))) {
      return 'crypto';
    }
    if (interests.contains('foreign_exchange') &&
        (value.contains('usd') ||
            value.contains('eur') ||
            value.contains('dolar'))) {
      return 'foreign_exchange';
    }
    if (interests.contains('stock_market') &&
        (symbol.endsWith('.IS') || value.contains('bist'))) {
      return 'stock_market';
    }
    return null;
  }

  static String _interestLabel(String id) =>
      TrendoraInterestCatalog.all
          .where((item) => item.id == id)
          .map((item) => item.label)
          .firstOrNull ??
      id;

  static String _source(Map<String, dynamic> row) {
    final sourceInfo = row['sourceInfo'];
    if (sourceInfo is Map) {
      final name = _text(Map<String, dynamic>.from(sourceInfo), const ['name']);
      if (name.isNotEmpty) return name;
    }
    return _text(row, const ['source', 'feedSource', 'store', 'market']);
  }

  static DateTime? _date(Map<String, dynamic> row) {
    final sourceInfo = row['sourceInfo'];
    if (sourceInfo is Map) {
      final nested = Map<String, dynamic>.from(sourceInfo);
      final parsed = DateTime.tryParse(
        _text(nested, const ['updatedAt', 'fetchedAt', 'dataTime']),
      );
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(
      _text(row, const ['updatedAt', 'publishedAt', 'dataTime', 'date']),
    );
  }

  static int _freshnessScore(DateTime? date) {
    if (date == null) return 0;
    final age = DateTime.now().difference(date.toLocal());
    if (age.isNegative || age.inHours <= 24) return 15;
    if (age.inDays <= 7) return 8;
    return 0;
  }

  static String _opportunityDescription(Map<String, dynamic> row) {
    final store = _text(row, const ['store', 'market', 'source']);
    final price = _text(row, const ['price', 'newPrice', 'salePrice']);
    return [store, price].where((item) => item.isNotEmpty).join(' • ');
  }

  static String _financialDescription(Map<String, dynamic> row) {
    final price = _text(row, const ['price']);
    final change = row['changePercent'] ?? row['change'];
    final changeText = change is num
        ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%'
        : '';
    return [price, changeText].where((item) => item.isNotEmpty).join(' • ');
  }

  static String _text(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }
}

const Set<String> _newsInterestIds = {
  'economy',
  'politics',
  'sports',
  'automotive',
  'technology',
  'science',
  'space',
  'health',
  'travel',
  'local_news',
  'world_agenda',
};

const Map<String, List<String>> _newsKeywords = {
  'economy': ['ekonomi', 'finans', 'piyasa'],
  'politics': ['siyaset', 'politika', 'gündem'],
  'sports': ['spor', 'futbol', 'basketbol'],
  'automotive': ['otomobil', 'araba', 'araç'],
  'technology': ['teknoloji', 'yapay zeka', 'dijital'],
  'science': ['bilim', 'araştırma'],
  'space': ['uzay', 'nasa', 'uydu'],
  'health': ['sağlık', 'tıp'],
  'travel': ['seyahat', 'turizm'],
  'local_news': ['yerel', 'belediye'],
  'world_agenda': ['dünya', 'world', 'global'],
};
