import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../personalization/personalization_service.dart';
import '../personalization/personalization_storage.dart';
import '../saved_analysis_store.dart';

enum SmartCommandTarget {
  none,
  news,
  opportunities,
  weather,
  trend,
  savedAnalyses,
  home,
}

enum SmartCommandIntent {
  gold,
  foreignExchange,
  financialAsset,
  watchlist,
  watchlistRisers,
  watchlistFallers,
  economyNews,
  weather,
  automotiveCampaigns,
  opportunities,
  savedAnalyses,
  payments,
  reminders,
  personalizedSummary,
  unknown,
}

class SmartCommandResult {
  const SmartCommandResult({
    required this.intent,
    required this.message,
    required this.source,
    required this.updatedAt,
    required this.target,
    this.targetQuery,
    this.available = true,
  });

  final SmartCommandIntent intent;
  final String message;
  final String source;
  final DateTime? updatedAt;
  final SmartCommandTarget target;
  final String? targetQuery;
  final bool available;
}

class SmartCommandParser {
  const SmartCommandParser();

  SmartCommandIntent parse(String input) {
    final value = _normalize(input);
    if (value.isEmpty) return SmartCommandIntent.unknown;
    if (value.contains('bugun benim icin') ||
        value.contains('onemli olanlar')) {
      return SmartCommandIntent.personalizedSummary;
    }
    if (value.contains('yaklasan odeme') || value.contains('odemelerim')) {
      return SmartCommandIntent.payments;
    }
    if (value.contains('hatirlatmalarim')) return SmartCommandIntent.reminders;
    if (value.contains('kaydettigim analiz')) {
      return SmartCommandIntent.savedAnalyses;
    }
    if (value.contains('takip listem') && value.contains('yukselen')) {
      return SmartCommandIntent.watchlistRisers;
    }
    if (value.contains('takip listem') && value.contains('dusen')) {
      return SmartCommandIntent.watchlistFallers;
    }
    if (value.contains('takip ettigim') || value.contains('takip listem')) {
      return SmartCommandIntent.watchlist;
    }
    if (value.contains('ekonomi haber')) return SmartCommandIntent.economyNews;
    if (value.contains('otomobil kampanya') ||
        value.contains('arac kampanya')) {
      return SmartCommandIntent.automotiveCampaigns;
    }
    if (value.contains('firsat')) return SmartCommandIntent.opportunities;
    if (value.contains('yagmur') || value.contains('hava')) {
      return SmartCommandIntent.weather;
    }
    if (value.contains('altin')) return SmartCommandIntent.gold;
    if (value.contains('dolar') ||
        value.contains('euro') ||
        value.contains('doviz')) {
      return SmartCommandIntent.foreignExchange;
    }
    if (RegExp(r'\b[A-ZÇĞİÖŞÜ]{3,6}\b').hasMatch(input) ||
        value.contains('hisse')) {
      return SmartCommandIntent.financialAsset;
    }
    return SmartCommandIntent.unknown;
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}

abstract interface class SmartCommandDataSource {
  Future<List<Map<String, dynamic>>> marketBoard();
  Future<List<Map<String, dynamic>>> news();
  Future<List<Map<String, dynamic>>> opportunities();
  Future<({String location, String description, double? temperature})?>
  weather();
  Future<Set<String>> trackedSymbols();
  Future<int> savedAnalysisCount();
}

class DefaultSmartCommandDataSource implements SmartCommandDataSource {
  factory DefaultSmartCommandDataSource({
    required SharedPreferences preferences,
    required PersonalizationService personalization,
  }) {
    return DefaultSmartCommandDataSource._(preferences, personalization);
  }

  DefaultSmartCommandDataSource._(this._preferences, this._personalization);

  final SharedPreferences _preferences;
  final PersonalizationService _personalization;

  @override
  Future<List<Map<String, dynamic>>> marketBoard() => _apiList(
    Uri.parse('${ApiConfig.trends}/market-board'),
    const ['items', 'data'],
  );

  @override
  Future<List<Map<String, dynamic>>> news() => _apiList(
    Uri.parse(
      ApiConfig.news,
    ).replace(queryParameters: const {'category': 'ekonomi', 'limit': '20'}),
    const ['news', 'items', 'data'],
  );

  @override
  Future<List<Map<String, dynamic>>> opportunities() => _apiList(
    Uri.parse(
      ApiConfig.opportunities,
    ).replace(queryParameters: const {'limit': '40'}),
    const ['opportunities', 'items', 'data'],
  );

  @override
  Future<({String location, String description, double? temperature})?>
  weather() async {
    final location =
        _preferences.getString('weather_card_location')?.trim() ?? '';
    final description =
        _preferences.getString('weather_card_description')?.trim() ?? '';
    if (location.isEmpty && description.isEmpty) return null;
    return (
      location: location.isEmpty ? 'Konumum' : location,
      description: description,
      temperature: _preferences.getDouble('weather_card_temperature'),
    );
  }

  @override
  Future<Set<String>> trackedSymbols() async {
    final preferences = await _personalization.getPreferences();
    return preferences.trackedFinancialAssets;
  }

  @override
  Future<int> savedAnalysisCount() async =>
      (await SavedAnalysisStore.load()).length;

  Future<List<Map<String, dynamic>>> _apiList(
    Uri uri,
    List<String> keys,
  ) async {
    final response = await ApiClient.get(
      uri,
      cacheTtl: const Duration(minutes: 2),
      timeout: const Duration(seconds: 35),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return const [];
    for (final key in keys) {
      final value = decoded[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const [];
  }
}

class SmartCommandService {
  factory SmartCommandService({
    required SmartCommandDataSource dataSource,
    SmartCommandParser parser = const SmartCommandParser(),
  }) {
    return SmartCommandService._(dataSource, parser);
  }

  const SmartCommandService._(this._dataSource, this._parser);

  final SmartCommandDataSource _dataSource;
  final SmartCommandParser _parser;

  Future<SmartCommandResult> execute(String command) async {
    final intent = _parser.parse(command);
    try {
      return await switch (intent) {
        SmartCommandIntent.gold => _market(command, intent, const [
          'ALTIN',
          'XAU',
        ]),
        SmartCommandIntent.foreignExchange => _market(command, intent, const [
          'USD',
          'EUR',
          'DOLAR',
          'EURO',
        ]),
        SmartCommandIntent.financialAsset => _market(command, intent, const []),
        SmartCommandIntent.watchlist => _watchlist(intent),
        SmartCommandIntent.watchlistRisers => _watchlist(intent, rising: true),
        SmartCommandIntent.watchlistFallers => _watchlist(
          intent,
          rising: false,
        ),
        SmartCommandIntent.economyNews => _economyNews(intent),
        SmartCommandIntent.weather => _weather(intent),
        SmartCommandIntent.automotiveCampaigns => _opportunities(
          intent,
          automotiveOnly: true,
        ),
        SmartCommandIntent.opportunities => _opportunities(intent),
        SmartCommandIntent.savedAnalyses => _savedAnalyses(intent),
        SmartCommandIntent.payments => _unavailable(
          intent,
          'Kayıtlı ödeme verisi bulunmuyor.',
          SmartCommandTarget.none,
        ),
        SmartCommandIntent.reminders => _unavailable(
          intent,
          'Kayıtlı hatırlatma bulunmuyor.',
          SmartCommandTarget.none,
        ),
        SmartCommandIntent.personalizedSummary => Future.value(
          SmartCommandResult(
            intent: intent,
            message:
                'Kişisel gelişmeler ana sayfadaki “Bugün Senin İçin” bölümünde.',
            source: 'Trendora kişiselleştirme verisi',
            updatedAt: DateTime.now(),
            target: SmartCommandTarget.home,
          ),
        ),
        SmartCommandIntent.unknown => _unavailable(
          intent,
          'Bu komutu henüz anlayamadım. Altın, döviz, hisse, haber, fırsat veya hava sorabilirsin.',
          SmartCommandTarget.none,
        ),
      };
    } catch (_) {
      return SmartCommandResult(
        intent: intent,
        message:
            'Güncel veri şu anda alınamıyor. Daha sonra tekrar deneyebilirsin.',
        source: 'Trendora veri ağı',
        updatedAt: null,
        target: _targetFor(intent),
        targetQuery: command,
        available: false,
      );
    }
  }

  Future<SmartCommandResult> _market(
    String command,
    SmartCommandIntent intent,
    List<String> preferredTokens,
  ) async {
    final rows = await _dataSource.marketBoard();
    final upper = command.toUpperCase();
    Map<String, dynamic>? match;
    for (final row in rows) {
      final symbol = '${row['symbol'] ?? ''}'.toUpperCase();
      final label = '${row['label'] ?? ''}'.toUpperCase();
      final preferred = preferredTokens.any(
        (token) => symbol.contains(token) || label.contains(token),
      );
      final mentioned =
          symbol.isNotEmpty && upper.contains(symbol.replaceAll('.IS', '')) ||
          label.isNotEmpty && upper.contains(label);
      if (preferred || mentioned) {
        match = row;
        break;
      }
    }
    if (match == null) {
      return await _unavailable(
        intent,
        'Sorulan varlık için güncel fiyat bulunamadı.',
        SmartCommandTarget.trend,
        query: command,
      );
    }
    final label = '${match['label'] ?? match['symbol']}';
    final price = match['price'];
    final change = match['changePercent'] ?? match['change'];
    final changeText = change is num
        ? ' • ${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%'
        : '';
    return SmartCommandResult(
      intent: intent,
      message: '$label: ${price ?? '-'}$changeText',
      source: _source(match),
      updatedAt: _date(match),
      target: SmartCommandTarget.trend,
      targetQuery: label,
    );
  }

  Future<SmartCommandResult> _watchlist(
    SmartCommandIntent intent, {
    bool? rising,
  }) async {
    final tracked = await _dataSource.trackedSymbols();
    if (tracked.isEmpty) {
      return _unavailable(
        intent,
        'Takip listende finansal varlık bulunmuyor.',
        SmartCommandTarget.trend,
      );
    }
    if (rising == null) {
      return SmartCommandResult(
        intent: intent,
        message:
            'Takip listende ${tracked.length} varlık var: ${tracked.take(5).join(', ')}',
        source: 'Cihazdaki takip listesi',
        updatedAt: DateTime.now(),
        target: SmartCommandTarget.trend,
      );
    }
    final rows = await _dataSource.marketBoard();
    final matches = rows
        .where((row) {
          final symbol = '${row['symbol'] ?? ''}'.toUpperCase();
          final change = row['changePercent'] ?? row['change'];
          return tracked.any((item) => symbol.contains(item.toUpperCase())) &&
              change is num &&
              (rising ? change > 0 : change < 0);
        })
        .take(5)
        .toList();
    final names = matches
        .map((row) => '${row['label'] ?? row['symbol']}')
        .join(', ');
    return SmartCommandResult(
      intent: intent,
      message: names.isEmpty
          ? 'Takip listende bu ölçüte uyan güncel varlık bulunamadı.'
          : '${rising ? 'Yükselenler' : 'Düşenler'}: $names',
      source: 'Takip listesi ve piyasa veri ağı',
      updatedAt: matches.isEmpty ? null : _date(matches.first),
      target: SmartCommandTarget.trend,
      available: matches.isNotEmpty,
    );
  }

  Future<SmartCommandResult> _economyNews(SmartCommandIntent intent) async {
    final rows = await _dataSource.news();
    if (rows.isEmpty) {
      return _unavailable(
        intent,
        'Güncel ekonomi haberi bulunamadı.',
        SmartCommandTarget.news,
      );
    }
    final first = rows.first;
    return SmartCommandResult(
      intent: intent,
      message: '${first['title'] ?? first['name']}',
      source: _source(first),
      updatedAt: _date(first),
      target: SmartCommandTarget.news,
    );
  }

  Future<SmartCommandResult> _weather(SmartCommandIntent intent) async {
    final weather = await _dataSource.weather();
    if (weather == null) {
      return _unavailable(
        intent,
        'Hava verisi bulunmuyor. Hava Merkezinden konum seçebilirsin.',
        SmartCommandTarget.weather,
      );
    }
    final temperature = weather.temperature == null
        ? ''
        : ' • ${weather.temperature!.toStringAsFixed(0)}°';
    return SmartCommandResult(
      intent: intent,
      message: '${weather.location}$temperature • ${weather.description}',
      source: 'Cihazdaki son hava verisi',
      updatedAt: DateTime.now(),
      target: SmartCommandTarget.weather,
    );
  }

  Future<SmartCommandResult> _opportunities(
    SmartCommandIntent intent, {
    bool automotiveOnly = false,
  }) async {
    final rows = await _dataSource.opportunities();
    final filtered = automotiveOnly
        ? rows.where((row) {
            final text = '${row['category']} ${row['title']} ${row['source']}'
                .toLowerCase();
            return text.contains('otomobil') || text.contains('araç');
          }).toList()
        : rows;
    if (filtered.isEmpty) {
      return _unavailable(
        intent,
        automotiveOnly
            ? 'Güncel otomobil kampanyası bulunamadı.'
            : 'Güncel fırsat bulunamadı.',
        SmartCommandTarget.opportunities,
      );
    }
    final first = filtered.first;
    return SmartCommandResult(
      intent: intent,
      message: '${first['title'] ?? first['name']}',
      source: _source(first),
      updatedAt: _date(first),
      target: SmartCommandTarget.opportunities,
    );
  }

  Future<SmartCommandResult> _savedAnalyses(SmartCommandIntent intent) async {
    final count = await _dataSource.savedAnalysisCount();
    return SmartCommandResult(
      intent: intent,
      message: count == 0
          ? 'Kaydedilmiş analiz bulunmuyor.'
          : '$count kaydedilmiş analizin var.',
      source: 'Cihazdaki kaydedilen analizler',
      updatedAt: DateTime.now(),
      target: SmartCommandTarget.savedAnalyses,
      available: count > 0,
    );
  }

  Future<SmartCommandResult> _unavailable(
    SmartCommandIntent intent,
    String message,
    SmartCommandTarget target, {
    String? query,
  }) async {
    return SmartCommandResult(
      intent: intent,
      message: message,
      source: 'Trendora',
      updatedAt: null,
      target: target,
      targetQuery: query,
      available: false,
    );
  }

  static SmartCommandTarget _targetFor(SmartCommandIntent intent) {
    return switch (intent) {
      SmartCommandIntent.economyNews => SmartCommandTarget.news,
      SmartCommandIntent.weather => SmartCommandTarget.weather,
      SmartCommandIntent.automotiveCampaigns ||
      SmartCommandIntent.opportunities => SmartCommandTarget.opportunities,
      SmartCommandIntent.savedAnalyses => SmartCommandTarget.savedAnalyses,
      SmartCommandIntent.personalizedSummary => SmartCommandTarget.home,
      SmartCommandIntent.gold ||
      SmartCommandIntent.foreignExchange ||
      SmartCommandIntent.financialAsset ||
      SmartCommandIntent.watchlist ||
      SmartCommandIntent.watchlistRisers ||
      SmartCommandIntent.watchlistFallers => SmartCommandTarget.trend,
      _ => SmartCommandTarget.none,
    };
  }

  static String _source(Map<String, dynamic> row) =>
      '${row['sourceInfo'] is Map ? row['sourceInfo']['name'] : row['source'] ?? row['store'] ?? 'Trendora veri ağı'}';

  static DateTime? _date(Map<String, dynamic> row) {
    final sourceInfo = row['sourceInfo'];
    final value = sourceInfo is Map
        ? sourceInfo['updatedAt'] ?? sourceInfo['dataTime']
        : row['updatedAt'] ?? row['publishedAt'] ?? row['dataTime'];
    return DateTime.tryParse('$value');
  }
}

class SmartCommandRuntime {
  const SmartCommandRuntime({
    required this.userId,
    required this.service,
    required this.preferences,
  });

  final String userId;
  final SmartCommandService service;
  final SharedPreferences preferences;

  static Future<SmartCommandRuntime> create() async {
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesPersonalizationStore(preferences);
    final identity = PersonalizationIdentityProvider(storage);
    final personalization = PersonalizationService(
      repository: PersonalizationLocalRepository(storage),
      identityProvider: identity,
    );
    final userPreferences = await personalization.initialize();
    return SmartCommandRuntime(
      userId: userPreferences.userId,
      preferences: preferences,
      service: SmartCommandService(
        dataSource: DefaultSmartCommandDataSource(
          preferences: preferences,
          personalization: personalization,
        ),
      ),
    );
  }
}
