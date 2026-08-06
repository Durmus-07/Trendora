import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../news/saved_news_store.dart';
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
  marketPrice,
  marketAnalysis,
  breakingNews,
  newsSearch,
  newsCategory,
  opportunitiesSearch,
  opportunitiesSource,
  savedItems,
  savedNews,
  dailyDigest,
  generalQuestion,
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
    this.cards = const [],
    this.suggestions = const [],
    this.buttonLabel,
    this.query = '',
    this.normalizedQuery = '',
    this.fallbackUsed = false,
  });

  final SmartCommandIntent intent;
  final String message;
  final String source;
  final DateTime? updatedAt;
  final SmartCommandTarget target;
  final String? targetQuery;
  final bool available;
  final List<Map<String, dynamic>> cards;
  final List<String> suggestions;
  final String? buttonLabel;
  final String query;
  final String normalizedQuery;
  final bool fallbackUsed;
}

class SmartCommandParser {
  const SmartCommandParser();

  SmartCommandIntent parse(String input) {
    final value = normalize(input);
    if (value.isEmpty) return SmartCommandIntent.unknown;
    final saved =
        value.contains('kaydettigim') ||
        value.contains('kaydetigim') ||
        value.contains('favorilerim');
    if (saved && value.contains('haber')) return SmartCommandIntent.savedNews;
    if (saved) return SmartCommandIntent.savedItems;
    if (value.contains('gunluk ozet')) return SmartCommandIntent.dailyDigest;
    if (value.contains('son dakika') ||
        value.contains('son dakka') ||
        value.contains('son gelisme')) {
      return SmartCommandIntent.breakingNews;
    }
    if ((value.contains('migros') ||
            value.contains('migors') ||
            value.contains('bim')) &&
        (value.contains('firsat') ||
            value.contains('indirim') ||
            value.contains('ne var'))) {
      return SmartCommandIntent.opportunitiesSource;
    }
    if (value.contains('firsat') ||
        value.contains('indirim') ||
        value.contains('kampanya')) {
      return SmartCommandIntent.opportunitiesSearch;
    }
    if (value.contains('haber')) {
      if (value.contains('ekonomi') || value.contains('teknoloji')) {
        return SmartCommandIntent.newsCategory;
      }
      return SmartCommandIntent.newsSearch;
    }
    if (value.contains('analiz') ||
        value.contains('gorunumu') ||
        value.contains('kisa vadede')) {
      return SmartCommandIntent.marketAnalysis;
    }
    if (value.contains('kac tl') ||
        value.contains('ne kadar') ||
        value.contains('fiyat')) {
      return SmartCommandIntent.marketPrice;
    }
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
    if (value.endsWith(' nedir') ||
        value.startsWith('nasil ') ||
        value.startsWith('neden ') ||
        value.contains(' nerede') ||
        value.startsWith('hangi ') ||
        value.contains(' sirala') ||
        value.contains(' goster') ||
        value.contains(' bul')) {
      return SmartCommandIntent.generalQuestion;
    }
    if (value.split(' ').where((part) => part.isNotEmpty).length >= 3) {
      return SmartCommandIntent.generalQuestion;
    }
    return SmartCommandIntent.generalQuestion;
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
  static String normalize(String value) => _normalize(value)
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? assetSymbol(String value) {
    final text = normalize(value);
    const aliases = <String, String>{
      'aselsan': 'ASELS',
      'asels': 'ASELS',
      'thy': 'THYAO',
      'thyao': 'THYAO',
      'turk hava yollari': 'THYAO',
      'sisecam': 'SISE',
      'sise': 'SISE',
      'altin.s1': 'ALTIN.S1',
      'altin s1': 'ALTIN.S1',
      'gram altin': 'GRAM_ALTIN',
      'altin': 'GRAM_ALTIN',
      'bist 100': 'XU100',
      'xu100': 'XU100',
    };
    for (final entry in aliases.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

abstract interface class SmartCommandDataSource {
  Future<Map<String, dynamic>?> smartSearchPlan(String query);
  Future<Map<String, dynamic>?> generalSearch(String query);
  Future<List<Map<String, dynamic>>> marketBoard();
  Future<List<Map<String, dynamic>>> news({
    String? category,
    String? query,
    bool breaking = false,
  });
  Future<List<Map<String, dynamic>>> opportunities({
    String? source,
    String? query,
  });
  Future<({String location, String description, double? temperature})?>
  weather();
  Future<Set<String>> trackedSymbols();
  Future<int> savedAnalysisCount();
  Future<List<SavedNews>> savedNews();
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
  Future<Map<String, dynamic>?> smartSearchPlan(String query) async {
    final response = await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/api/smart-search'),
      body: jsonEncode({'query': query}),
      timeout: const Duration(seconds: 5),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<Map<String, dynamic>?> generalSearch(String query) async {
    final response = await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/api/smart-search/answer'),
      body: jsonEncode({'query': query}),
      timeout: const Duration(seconds: 14),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['success'] != true) return null;
    return Map<String, dynamic>.from(decoded);
  }

  @override
  Future<List<Map<String, dynamic>>> marketBoard() => _apiList(
    Uri.parse('${ApiConfig.trends}/market-board'),
    const ['items', 'data'],
  );

  @override
  Future<List<Map<String, dynamic>>> news({
    String? category,
    String? query,
    bool breaking = false,
  }) {
    final parameters = <String, String>{'limit': '5'};
    if (category != null) parameters['category'] = category;
    if (query != null) parameters['q'] = query;
    if (breaking) parameters['breaking'] = 'true';
    return _apiList(
      Uri.parse(ApiConfig.news).replace(queryParameters: parameters),
      const ['news', 'items', 'data'],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities({
    String? source,
    String? query,
  }) {
    final parameters = <String, String>{'limit': '5', 'active': 'true'};
    if (source != null) parameters['source'] = source;
    if (query != null) parameters['q'] = query;
    return _apiList(
      Uri.parse(ApiConfig.opportunities).replace(queryParameters: parameters),
      const ['opportunities', 'items', 'data'],
    );
  }

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

  @override
  Future<List<SavedNews>> savedNews() => SavedNewsStore.load();

  Future<List<Map<String, dynamic>>> _apiList(
    Uri uri,
    List<String> keys,
  ) async {
    final response = await ApiClient.get(
      uri,
      cacheTtl: const Duration(minutes: 2),
      timeout: const Duration(seconds: 10),
      retries: 0,
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
      final plan = await _dataSource.smartSearchPlan(command);
      if (intent == SmartCommandIntent.marketPrice ||
          intent == SmartCommandIntent.marketAnalysis) {
        return await _centralMarket(command, intent, plan);
      }
      if (intent == SmartCommandIntent.generalQuestion) {
        return await _generalQuestion(command, intent, plan);
      }
      return await switch (intent) {
        SmartCommandIntent.marketPrice => throw StateError('unreachable'),
        SmartCommandIntent.marketAnalysis => throw StateError('unreachable'),
        SmartCommandIntent.breakingNews ||
        SmartCommandIntent.newsSearch ||
        SmartCommandIntent.newsCategory => _newsSearch(command, intent),
        SmartCommandIntent.opportunitiesSearch ||
        SmartCommandIntent.opportunitiesSource => _opportunitySearch(
          command,
          intent,
        ),
        SmartCommandIntent.savedItems => _savedItems(command, intent),
        SmartCommandIntent.savedNews => _savedNews(intent),
        SmartCommandIntent.dailyDigest => Future.value(
          SmartCommandResult(
            intent: intent,
            message: 'Günlük özetin ana sayfada hazır.',
            source: 'Trendora günlük özet',
            updatedAt: DateTime.now(),
            target: SmartCommandTarget.home,
            buttonLabel: 'Özeti Göster',
          ),
        ),
        SmartCommandIntent.generalQuestion => throw StateError('unreachable'),
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
        SmartCommandIntent.unknown => _generalQuestion(
          command,
          intent,
          plan,
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

  Future<SmartCommandResult> _centralMarket(
    String command,
    SmartCommandIntent intent,
    Map<String, dynamic>? plan,
  ) async {
    final resolution = '${plan?['assetResolution'] ?? ''}';
    final candidates = plan?['candidates'];
    if (resolution == 'selection_required' && candidates is List) {
      return SmartCommandResult(
        intent: intent,
        query: command,
        normalizedQuery: '${plan?['normalizedQuery'] ?? ''}',
        message:
            'Birden fazla güçlü eşleşme bulundu. Devam etmek için bir varlık seç.',
        source: 'Trendora merkezi varlık kataloğu',
        updatedAt: DateTime.now(),
        target: SmartCommandTarget.none,
        cards: candidates
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .take(5)
            .toList(),
      );
    }
    final asset = plan?['asset'];
    if (resolution != 'matched' || asset is! Map) {
      return _generalQuestion(command, intent, plan);
    }
    final symbol = '${asset['canonicalSymbol'] ?? ''}'.trim();
    final name = '${asset['displayName'] ?? symbol}'.trim();
    if (intent == SmartCommandIntent.marketAnalysis) {
      return _analysis(command, intent, symbol: symbol, displayName: name);
    }
    return _market(command, intent, [symbol], resolvedSymbol: symbol);
  }

  Future<SmartCommandResult> _generalQuestion(
    String command,
    SmartCommandIntent intent,
    Map<String, dynamic>? plan,
  ) async {
    final response = await _dataSource.generalSearch(command);
    if (response == null) {
      return _unavailable(
        intent,
        'Trendora Arama şu anda güncel sonuçlara ulaşamıyor.',
        SmartCommandTarget.none,
      );
    }
    final answer = '${response['answer'] ?? ''}'.trim();
    final rawResults = response['results'];
    final cards = rawResults is List
        ? rawResults
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return SmartCommandResult(
      intent: intent,
      query: command,
      normalizedQuery: '${plan?['normalizedQuery'] ?? ''}',
      message: answer.isEmpty ? 'Bulduğum sonuçlar:' : answer,
      source: 'Trendora Arama',
      updatedAt: DateTime.now(),
      target: SmartCommandTarget.none,
      cards: cards,
      fallbackUsed: response['fallbackReason'] != null,
      suggestions: const ['Son dakika haberleri', 'Güncel fırsatlar'],
    );
  }

  Future<SmartCommandResult> _market(
    String command,
    SmartCommandIntent intent,
    List<String> preferredTokens, {
    String? resolvedSymbol,
  }) async {
    final rows = await _dataSource.marketBoard();
    final upper = command.toUpperCase();
    final tokens = preferredTokens
        .expand((token) {
          if (token == 'GRAM_ALTIN') return const ['ALTIN', 'XAU', 'GRAM'];
          return [token];
        })
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    Map<String, dynamic>? match;
    for (final row in rows) {
      final symbol = '${row['symbol'] ?? ''}'.toUpperCase();
      final label = '${row['label'] ?? ''}'.toUpperCase();
      final preferred = tokens.any(
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
      return _generalQuestion(command, intent, null);
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
      targetQuery: resolvedSymbol ?? label,
    );
  }

  Future<SmartCommandResult> _analysis(
    String command,
    SmartCommandIntent intent, {
    String? symbol,
    String? displayName,
  }) async {
    final resolved = symbol ?? SmartCommandParser.assetSymbol(command);
    if (resolved == null) {
      return _generalQuestion(command, intent, null);
    }
    return SmartCommandResult(
      intent: intent,
      query: command,
      normalizedQuery: SmartCommandParser.normalize(command),
      message:
          '${displayName ?? resolved} ($resolved) için güncel teknik görünümü analiz ekranında inceleyebilirsin. Yatırım tavsiyesi değildir.',
      source: 'Trendora analiz sistemi',
      updatedAt: DateTime.now(),
      target: SmartCommandTarget.trend,
      targetQuery: resolved,
      buttonLabel: 'Analizi Aç',
      suggestions: ['$resolved fiyatı', '$resolved haberleri'],
    );
  }

  Future<SmartCommandResult> _newsSearch(
    String command,
    SmartCommandIntent intent,
  ) async {
    final normalized = SmartCommandParser.normalize(command);
    final category = normalized.contains('ekonomi')
        ? 'ekonomi'
        : normalized.contains('teknoloji')
        ? 'teknoloji'
        : null;
    final symbol = SmartCommandParser.assetSymbol(command)?.toLowerCase();
    final rows = await _dataSource.news(
      category: category,
      query: symbol,
      breaking: intent == SmartCommandIntent.breakingNews,
    );
    final filtered = rows
        .where((row) {
          final text = SmartCommandParser.normalize(
            '${row['title']} ${row['summary']} ${row['category']}',
          );
          if (category != null && !text.contains(category)) return false;
          if (symbol != null && !text.contains(symbol)) return false;
          return true;
        })
        .take(5)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return _generalQuestion(command, intent, null);
    }
    return SmartCommandResult(
      intent: intent,
      query: command,
      normalizedQuery: normalized,
      message: '${filtered.length} ilgili güncel haber bulundu.',
      source: 'Trendora Haber Merkezi',
      updatedAt: _date(filtered.first),
      target: SmartCommandTarget.news,
      buttonLabel: 'Tüm Haberleri Gör',
      cards: filtered,
      suggestions: const ['Son dakika haberleri', 'Ekonomi haberleri'],
    );
  }

  Future<SmartCommandResult> _opportunitySearch(
    String command,
    SmartCommandIntent intent,
  ) async {
    final normalized = SmartCommandParser.normalize(command);
    final source =
        normalized.contains('migros') || normalized.contains('migors')
        ? 'migros'
        : normalized.contains('bim')
        ? 'bim'
        : null;
    const ignored = {
      'firsat',
      'firsatlari',
      'indirim',
      'indirimli',
      'var',
      'mi',
      'ne',
      'en',
      'yeni',
      'migros',
      'migors',
      'bim',
    };
    final terms = normalized
        .split(' ')
        .where((word) => word.length > 2 && !ignored.contains(word))
        .toList();
    final rows = await _dataSource.opportunities(
      source: source,
      query: terms.isEmpty ? null : terms.join(' '),
    );
    final filtered = rows
        .where((row) {
          final rowSource = SmartCommandParser.normalize(
            '${row['source'] ?? row['store']}',
          );
          final text = SmartCommandParser.normalize(
            '${row['title']} ${row['name']} ${row['category']}',
          );
          if (source != null && !rowSource.contains(source)) return false;
          return terms.isEmpty || terms.every(text.contains);
        })
        .take(5)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return _generalQuestion(command, intent, null);
    }
    return SmartCommandResult(
      intent: intent,
      query: command,
      normalizedQuery: normalized,
      message: '${filtered.length} uygun fırsat bulundu.',
      source: 'Trendora Fırsatlar Merkezi',
      updatedAt: _date(filtered.first),
      target: SmartCommandTarget.opportunities,
      targetQuery: source,
      buttonLabel: 'Tüm Fırsatları Gör',
      cards: filtered,
      suggestions: const ['En yeni fırsatlar', 'En yüksek indirimler'],
    );
  }

  Future<SmartCommandResult> _savedNews(SmartCommandIntent intent) async {
    final items = await _dataSource.savedNews();
    if (items.isEmpty) {
      return _unavailable(
        intent,
        'Kaydedilmiş haber bulunmuyor.',
        SmartCommandTarget.news,
      );
    }
    return SmartCommandResult(
      intent: intent,
      message: '${items.length} kaydedilmiş haberin var.',
      source: 'Cihazdaki kaydedilen haberler',
      updatedAt: items.first.savedAt,
      target: SmartCommandTarget.news,
      buttonLabel: 'Haberlere Git',
      cards: items
          .take(5)
          .map(
            (item) => {
              'title': item.title,
              'source': item.source,
              'updatedAt': item.savedAt.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  Future<SmartCommandResult> _savedItems(
    String command,
    SmartCommandIntent intent,
  ) async {
    final count = await _dataSource.savedAnalysisCount();
    final symbol = SmartCommandParser.assetSymbol(command);
    return SmartCommandResult(
      intent: intent,
      query: command,
      normalizedQuery: SmartCommandParser.normalize(command),
      message: count == 0
          ? 'Kaydedilmiş analiz bulunmuyor.'
          : '$count kaydedilmiş analizin var.',
      source: 'Cihazdaki kaydedilen analizler',
      updatedAt: DateTime.now(),
      target: SmartCommandTarget.savedAnalyses,
      targetQuery: symbol,
      buttonLabel: 'Kaydedilenleri Aç',
      available: count > 0,
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
      SmartCommandIntent.breakingNews ||
      SmartCommandIntent.newsSearch ||
      SmartCommandIntent.newsCategory ||
      SmartCommandIntent.savedNews => SmartCommandTarget.news,
      SmartCommandIntent.opportunitiesSearch ||
      SmartCommandIntent.opportunitiesSource =>
        SmartCommandTarget.opportunities,
      SmartCommandIntent.marketPrice ||
      SmartCommandIntent.marketAnalysis ||
      SmartCommandIntent.savedItems => SmartCommandTarget.trend,
      SmartCommandIntent.dailyDigest => SmartCommandTarget.home,
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
