import 'dart:collection';

enum NewsSourceLevel { official, corporate, newsOrganization, limited }

enum NewsFreshnessLevel { veryNew, current, recent, old, unknown }

class NewsSourceAssessment {
  const NewsSourceAssessment({
    required this.level,
    required this.label,
    required this.score,
    required this.reason,
  });

  final NewsSourceLevel level;
  final String label;
  final int score;
  final String reason;
}

class NewsFreshnessAssessment {
  const NewsFreshnessAssessment({
    required this.level,
    required this.label,
    required this.score,
    required this.reason,
  });

  final NewsFreshnessLevel level;
  final String label;
  final int score;
  final String reason;
}

class NewsConfidenceAssessment {
  const NewsConfidenceAssessment({
    required this.label,
    required this.score,
    required this.sourceCount,
    required this.confirmingSourceCount,
    required this.reason,
  });

  final String label;
  final int score;
  final int sourceCount;
  final int confirmingSourceCount;
  final String reason;
}

class NewsFinancialImpactAssessment {
  const NewsFinancialImpactAssessment({
    required this.stockMarket,
    required this.banking,
    required this.gold,
    required this.foreignExchange,
    required this.crypto,
    required this.oil,
    required this.sectors,
    required this.companies,
    required this.overallMarket,
    required this.riskLevel,
    required this.impactScore,
    required this.affectedAssets,
  });

  final String stockMarket;
  final String banking;
  final String gold;
  final String foreignExchange;
  final String crypto;
  final String oil;
  final List<String> sectors;
  final List<String> companies;
  final String overallMarket;
  final String riskLevel;
  final int impactScore;
  final List<String> affectedAssets;
}

class NewsIntelligenceResult {
  const NewsIntelligenceResult({
    required this.importanceScore,
    required this.financialRelevanceScore,
    required this.source,
    required this.freshness,
    required this.trendoraScore,
    required this.importanceReason,
    required this.financialReason,
    required this.trendoraReason,
    required this.matchedSignals,
    required this.financialImpact,
    required this.confidence,
  });

  final int importanceScore;
  final int financialRelevanceScore;
  final NewsSourceAssessment source;
  final NewsFreshnessAssessment freshness;
  final int trendoraScore;
  final String importanceReason;
  final String financialReason;
  final String trendoraReason;
  final List<String> matchedSignals;
  final NewsFinancialImpactAssessment financialImpact;
  final NewsConfidenceAssessment confidence;

  String get importanceLevel => _scoreLevel(importanceScore);

  String get financialRelevanceLevel => _scoreLevel(financialRelevanceScore);

  static String _scoreLevel(int score) {
    if (score >= NewsIntelligenceService.highScoreThreshold) return 'Yüksek';
    if (score >= NewsIntelligenceService.mediumScoreThreshold) return 'Orta';
    return 'Düşük';
  }
}

class NewsIntelligenceService {
  NewsIntelligenceService({
    int maximumCacheItems = defaultMaximumCacheItems,
    DateTime Function()? now,
  }) : assert(maximumCacheItems > 0),
       _maximumCacheItems = maximumCacheItems,
       _now = now ?? DateTime.now;

  static final NewsIntelligenceService shared = NewsIntelligenceService();

  static const int defaultMaximumCacheItems = 256;
  static const int minimumScore = 0;
  static const int maximumScore = 100;
  static const int highScoreThreshold = 70;
  static const int mediumScoreThreshold = 40;

  static const double importanceWeight = 0.40;
  static const double financialRelevanceWeight = 0.30;
  static const double freshnessWeight = 0.20;
  static const double sourceWeight = 0.10;

  static const int _baseImportanceScore = 5;
  static const double _importanceFreshnessContribution = 0.10;
  static const int _centralBankImportance = 30;
  static const int _ratesAndInflationImportance = 22;
  static const int _marketImportance = 18;
  static const int _regulationImportance = 24;
  static const int _corporateEventImportance = 22;
  static const int _macroDataImportance = 18;
  static const int _assetMarketImportance = 15;
  static const int _geopoliticalImportance = 18;
  static const int _urgentImportance = 20;

  static const int _economyCategoryFinancialScore = 25;
  static const int _marketCategoryFinancialScore = 35;
  static const int _centralBankFinancialScore = 25;
  static const int _ratesAndInflationFinancialScore = 30;
  static const int _marketFinancialScore = 30;
  static const int _regulationFinancialScore = 25;
  static const int _corporateEventFinancialScore = 25;
  static const int _assetMarketFinancialScore = 25;
  static const int _bankingFinancialScore = 22;
  static const int _macroDataFinancialScore = 20;
  static const int _globalMarketFinancialScore = 20;
  static const int _businessFinancialScore = 15;

  static const int _officialSourceScore = 100;
  static const int _corporateSourceScore = 78;
  static const int _newsOrganizationScore = 65;
  static const int _limitedSourceScore = 35;

  static const Duration _veryNewLimit = Duration(hours: 2);
  static const Duration _currentLimit = Duration(hours: 24);
  static const Duration _recentLimit = Duration(days: 7);
  static const Duration _futureTolerance = Duration(minutes: 5);
  static const int _veryNewScore = 100;
  static const int _currentScore = 80;
  static const int _recentScore = 55;
  static const int _oldScore = 20;
  static const int _unknownFreshnessScore = 0;

  static const List<String> _centralBankKeywords = [
    'tcmb',
    'fed',
    'ecb',
    'merkez bankası',
    'para politikası kurulu',
    'ppk',
  ];
  static const List<String> _ratesAndInflationKeywords = [
    'faiz*',
    'enflasyon*',
    'politika faizi',
    'tüfe',
    'üfe',
  ];
  static const List<String> _marketKeywords = [
    'bist',
    'borsa istanbul',
    'borsa*',
    'hisse*',
    'nasdaq',
    's&p 500',
    's p 500',
    'endeks*',
  ];
  static const List<String> _regulationKeywords = [
    'spk',
    'bddk',
    'tüik',
    'tuik',
    'resmi gazete',
  ];
  static const List<String> _corporateEventKeywords = [
    'bilanço*',
    'birleşme*',
    'satın alma*',
    'iflas*',
    'temettü*',
    'geri alım*',
    'sermaye artırım*',
  ];
  static const List<String> _macroDataKeywords = [
    'işsizlik*',
    'büyüme*',
    'gsyh',
    'gayrisafi yurt içi hasıla',
    'cari açık',
    'dış ticaret',
    'sanayi üretimi',
    'tüketici fiyat*',
  ];
  static const List<String> _assetMarketKeywords = [
    'döviz*',
    'dolar*',
    'euro*',
    'altın*',
    'petrol*',
    'brent*',
    'bitcoin',
    'ethereum',
    'kripto*',
  ];
  static const List<String> _geopoliticalKeywords = [
    'jeopolitik*',
    'savaş*',
    'çatışma*',
    'yaptırım*',
    'olağanüstü hal',
    'seferberlik*',
  ];
  static const List<String> _urgentKeywords = [
    'son dakika',
    'acil gelişme',
    'flaş gelişme',
    'deprem*',
    'yangın*',
  ];
  static const List<String> _bankingKeywords = [
    'banka*',
    'bankacılık*',
    'kredi*',
    'mevduat*',
  ];
  static const List<String> _globalMarketKeywords = [
    'küresel piyasa*',
    'wall street',
    'avrupa borsaları',
    'asya piyasaları',
  ];
  static const List<String> _businessKeywords = [
    'iş dünyası',
    'şirket*',
    'ihracat*',
    'ithalat*',
    'yatırım teşvik*',
  ];

  static const List<String> _goldKeywords = [
    'altın*',
    'ons altın',
    'gram altın',
    'xau',
  ];
  static const List<String> _foreignExchangeKeywords = [
    'döviz*',
    'dolar*',
    'euro*',
    'avro*',
    'sterlin*',
    'usd try',
    'eur try',
    'dxy',
    'türk lirası',
    'tl',
  ];
  static const List<String> _cryptoKeywords = [
    'bitcoin',
    'btc',
    'ethereum',
    'ether',
    'eth',
    'kripto*',
    'altcoin*',
    'blockchain',
  ];
  static const List<String> _oilKeywords = [
    'petrol*',
    'brent*',
    'wti',
    'ham petrol',
    'opec',
  ];

  static const Map<String, List<String>> _sectorKeywords = {
    'Bankacılık': _bankingKeywords,
    'Teknoloji': [
      'teknoloji*',
      'yazılım*',
      'yapay zeka',
      'yapay zekâ',
      'çip*',
      'siber*',
    ],
    'Enerji': [
      'enerji*',
      'petrol*',
      'doğal gaz',
      'doğalgaz*',
      'elektrik*',
      'rafineri*',
    ],
    'Otomotiv': ['otomotiv*', 'otomobil*', 'araç*', 'elektrikli araç'],
    'Havacılık': ['havacılık*', 'hava yolu', 'havayolu*', 'uçuş*', 'uçak*'],
    'Savunma': ['savunma*', 'füze*', 'silah*', 'askeri*'],
    'Perakende': ['perakende*', 'market*', 'mağaza*', 'tüketici*'],
    'İnşaat': ['inşaat*', 'konut*', 'gayrimenkul*', 'çimento*'],
    'Turizm': ['turizm*', 'otel*', 'seyahat*'],
    'Madencilik ve Metal': ['maden*', 'madencilik*', 'çelik*', 'demir*'],
  };

  static const Map<String, List<String>> _companyKeywords = {
    'Akbank (AKBNK)': ['akbank', 'akbnk'],
    'Garanti BBVA (GARAN)': ['garanti bbva', 'garan'],
    'İş Bankası (ISCTR)': ['iş bankası', 'isctr'],
    'Yapı Kredi (YKBNK)': ['yapı kredi', 'ykbnk'],
    'Türk Hava Yolları (THYAO)': ['türk hava yolları', 'thy', 'thyao'],
    'Tüpraş (TUPRS)': ['tüpraş', 'tupras', 'tuprs'],
    'Ereğli Demir Çelik (EREGL)': ['ereğli demir çelik', 'erdemir', 'eregl'],
    'Koç Holding (KCHOL)': ['koç holding', 'koc holding', 'kchol'],
    'Sabancı Holding (SAHOL)': ['sabancı holding', 'sabanci holding', 'sahol'],
    'ASELSAN (ASELS)': ['aselsan', 'asels'],
    'BİM (BIMAS)': ['bim', 'bimas'],
    'Turkcell (TCELL)': ['turkcell', 'tcell'],
    'Apple (AAPL)': ['apple', 'aapl'],
    'Microsoft (MSFT)': ['microsoft', 'msft'],
    'Nvidia (NVDA)': ['nvidia', 'nvda'],
    'Tesla (TSLA)': ['tesla', 'tsla'],
  };

  static const List<String> _officialSourceKeywords = [
    'türkiye cumhuriyet merkez bankası',
    'sermaye piyasası kurulu',
    'bankacılık düzenleme ve denetleme kurumu',
    'türkiye istatistik kurumu',
    'kamuyu aydınlatma platformu',
    'resmi gazete',
    'bakanlığı',
    'cumhurbaşkanlığı',
  ];
  static const Set<String> _officialSourceExact = {
    'tcmb',
    'spk',
    'bddk',
    'tüik',
    'tuik',
    'kap',
  };
  static const List<String> _corporateSourceKeywords = [
    'yatırımcı ilişkileri',
    'investor relations',
    'kurumsal iletişim',
    'şirket açıklaması',
    'basın odası',
  ];
  static const List<String> _knownNewsOrganizations = [
    'anadolu ajansı',
    'aa',
    'reuters',
    'bloomberg',
    'bbc',
    'associated press',
    'ap news',
    'financial times',
    'the new york times',
    'the guardian',
    'euronews',
    'dw',
    'trt haber',
    'cnbc',
    'wall street journal',
    'forbes',
    'al jazeera',
    'cbs news',
    'hürriyet',
    'sabah',
    'cumhuriyet',
    'sözcü',
    'ntv',
    'cnn türk',
    'habertürk',
    'ekonomim',
    'bigpara',
    't24',
    'karar',
    'yeni şafak',
    'chip online',
    'fanatik',
  ];

  static const Set<String> _forbiddenSingleWords = {'al', 'sat', 'tut'};
  static const List<String> _forbiddenPhrases = [
    'kesin yükselecek',
    'kesin düşecek',
    'hedef fiyat',
  ];

  final int _maximumCacheItems;
  final DateTime Function() _now;
  final LinkedHashMap<String, NewsIntelligenceResult> _cache = LinkedHashMap();
  final Map<String, String> _identityKeys = {};
  final Map<String, String> _keyIdentities = {};

  int get cachedItemCount => _cache.length;

  NewsIntelligenceResult evaluate({
    required String newsId,
    required String title,
    required String summary,
    required String articleText,
    required String category,
    required String source,
    required String feedSource,
    required DateTime? publishedAt,
    required bool isBreaking,
    int sourceCount = 1,
    int confirmingSourceCount = 0,
  }) {
    final safeSourceCount = sourceCount.clamp(1, 999);
    final safeConfirmingSourceCount = confirmingSourceCount.clamp(0, 998);
    final identity = _identity(newsId, title, publishedAt);
    final contentSignature = Object.hash(
      title,
      summary,
      articleText,
      category,
      source,
      feedSource,
      publishedAt?.toUtc(),
      isBreaking,
      safeSourceCount,
      safeConfirmingSourceCount,
    );
    final cacheKey = '$identity|$contentSignature';
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached;
    }

    final previousKey = _identityKeys[identity];
    if (previousKey != null && previousKey != cacheKey) {
      _cache.remove(previousKey);
      _keyIdentities.remove(previousKey);
    }

    final text = _NewsText('$title $summary $articleText $category');
    final freshness = _assessFreshness(publishedAt);
    final sourceAssessment = _assessSource(source, feedSource);
    final signals = _detectSignals(text, isBreaking);
    final importance = _importanceScore(signals, freshness);
    final financial = _financialScore(signals, category);
    final trendora = _bounded(
      (importance * importanceWeight +
              financial * financialRelevanceWeight +
              freshness.score * freshnessWeight +
              sourceAssessment.score * sourceWeight)
          .round(),
    );
    final financialImpact = _financialImpact(
      text: text,
      signals: signals,
      importanceScore: importance,
      financialScore: financial,
    );
    final confidence = _confidenceAssessment(
      sourceCount: safeSourceCount,
      confirmingSourceCount: safeConfirmingSourceCount,
      freshness: freshness,
      source: sourceAssessment,
    );

    final result = NewsIntelligenceResult(
      importanceScore: importance,
      financialRelevanceScore: financial,
      source: sourceAssessment,
      freshness: freshness,
      trendoraScore: trendora,
      importanceReason: _safeReason(
        signals.importanceLabels.isEmpty
            ? 'Haberde yüksek etkili bir gelişmeye ilişkin açık sinyal '
                  'bulunmadı.'
            : '${signals.importanceLabels.join(', ')} haberde açıkça geçtiği '
                  'için önem puanına katkı sağladı.',
      ),
      financialReason: _safeReason(
        signals.financialLabels.isEmpty && !_isFinancialCategory(category)
            ? 'Metinde doğrudan finansal piyasa bağlantısı bulunmadı.'
            : '${signals.financialLabels.isEmpty ? 'Finans kategorisi' : signals.financialLabels.join(', ')} '
                  'finansal ilgi puanına katkı sağladı.',
      ),
      trendoraReason:
          'Trendora skoru; önem %40, finansal ilgi %30, güncellik %20 ve '
          'kaynak sınıfı %10 ağırlıklarıyla hesaplandı.',
      matchedSignals: List.unmodifiable(signals.allLabels),
      financialImpact: financialImpact,
      confidence: confidence,
    );

    _remember(identity, cacheKey, result);
    return result;
  }

  NewsIntelligenceResult? cachedFor(String newsId) {
    final identity = newsId.trim();
    if (identity.isEmpty) return null;
    final cacheKey = _identityKeys[identity];
    if (cacheKey == null) return null;
    final cached = _cache.remove(cacheKey);
    if (cached == null) {
      _identityKeys.remove(identity);
      _keyIdentities.remove(cacheKey);
      return null;
    }
    _cache[cacheKey] = cached;
    return cached;
  }

  _DetectedSignals _detectSignals(_NewsText text, bool isBreaking) {
    final importanceLabels = <String>[];
    final financialLabels = <String>[];

    bool addWhen(bool matched, String label, {bool financial = false}) {
      if (!matched) return false;
      importanceLabels.add(label);
      if (financial) financialLabels.add(label);
      return true;
    }

    final centralBank = addWhen(
      text.containsAny(_centralBankKeywords),
      'merkez bankası kararı',
      financial: true,
    );
    final ratesAndInflation = addWhen(
      text.containsAny(_ratesAndInflationKeywords),
      'faiz veya enflasyon gelişmesi',
      financial: true,
    );
    final market = addWhen(
      text.containsAny(_marketKeywords),
      'borsa veya piyasa hareketi',
      financial: true,
    );
    final regulation = addWhen(
      text.containsAny(_regulationKeywords) || text.containsKap,
      'resmî finansal düzenleme',
      financial: true,
    );
    final corporateEvent = addWhen(
      text.containsAny(_corporateEventKeywords),
      'şirket finansmanı gelişmesi',
      financial: true,
    );
    final macroData = addWhen(
      text.containsAny(_macroDataKeywords),
      'makroekonomik veri',
      financial: true,
    );
    final assetMarket = addWhen(
      text.containsAny(_assetMarketKeywords),
      'döviz veya varlık piyasası',
      financial: true,
    );
    final geopolitical = addWhen(
      text.containsAny(_geopoliticalKeywords),
      'jeopolitik gelişme',
    );
    final urgent = addWhen(
      isBreaking || text.containsAny(_urgentKeywords),
      'olağanüstü veya acil gelişme',
    );
    final banking = text.containsAny(_bankingKeywords);
    if (banking) financialLabels.add('bankacılık');
    final globalMarket = text.containsAny(_globalMarketKeywords);
    if (globalMarket) financialLabels.add('küresel piyasalar');
    final business = text.containsAny(_businessKeywords);
    if (business) financialLabels.add('iş dünyası');

    return _DetectedSignals(
      centralBank: centralBank,
      ratesAndInflation: ratesAndInflation,
      market: market,
      regulation: regulation,
      corporateEvent: corporateEvent,
      macroData: macroData,
      assetMarket: assetMarket,
      geopolitical: geopolitical,
      urgent: urgent,
      banking: banking,
      globalMarket: globalMarket,
      business: business,
      importanceLabels: importanceLabels,
      financialLabels: financialLabels,
    );
  }

  int _importanceScore(
    _DetectedSignals signals,
    NewsFreshnessAssessment freshness,
  ) {
    var score = _baseImportanceScore;
    if (signals.centralBank) score += _centralBankImportance;
    if (signals.ratesAndInflation) score += _ratesAndInflationImportance;
    if (signals.market) score += _marketImportance;
    if (signals.regulation) score += _regulationImportance;
    if (signals.corporateEvent) score += _corporateEventImportance;
    if (signals.macroData) score += _macroDataImportance;
    if (signals.assetMarket) score += _assetMarketImportance;
    if (signals.geopolitical) score += _geopoliticalImportance;
    if (signals.urgent) score += _urgentImportance;
    score += (freshness.score * _importanceFreshnessContribution).round();
    return _bounded(score);
  }

  int _financialScore(_DetectedSignals signals, String category) {
    var score = switch (_normalize(category)) {
      'borsa' || 'kripto' => _marketCategoryFinancialScore,
      'ekonomi' => _economyCategoryFinancialScore,
      _ => minimumScore,
    };
    if (signals.centralBank) score += _centralBankFinancialScore;
    if (signals.ratesAndInflation) score += _ratesAndInflationFinancialScore;
    if (signals.market) score += _marketFinancialScore;
    if (signals.regulation) score += _regulationFinancialScore;
    if (signals.corporateEvent) score += _corporateEventFinancialScore;
    if (signals.assetMarket) score += _assetMarketFinancialScore;
    if (signals.banking) score += _bankingFinancialScore;
    if (signals.macroData) score += _macroDataFinancialScore;
    if (signals.globalMarket) score += _globalMarketFinancialScore;
    if (signals.business) score += _businessFinancialScore;
    return _bounded(score);
  }

  NewsFinancialImpactAssessment _financialImpact({
    required _NewsText text,
    required _DetectedSignals signals,
    required int importanceScore,
    required int financialScore,
  }) {
    final goldMatched = text.containsAny(_goldKeywords);
    final foreignExchangeMatched = text.containsAny(_foreignExchangeKeywords);
    final cryptoMatched = text.containsAny(_cryptoKeywords);
    final oilMatched = text.containsAny(_oilKeywords);
    final stockMatched =
        signals.market || signals.corporateEvent || signals.regulation;
    final bankingMatched =
        signals.banking || signals.centralBank || signals.ratesAndInflation;

    final sectors = <String>[
      for (final entry in _sectorKeywords.entries)
        if (text.containsAny(entry.value)) entry.key,
    ];
    if (bankingMatched && !sectors.contains('Bankacılık')) {
      sectors.insert(0, 'Bankacılık');
    }

    final companies = <String>[
      for (final entry in _companyKeywords.entries)
        if (text.containsAny(entry.value)) entry.key,
    ];

    final affectedAssets = <String>{
      ...companies,
      ...sectors,
      if (stockMatched && companies.isEmpty) 'BIST ve hisse senetleri',
      if (goldMatched) 'Altın',
      if (oilMatched) 'Brent petrol',
      if (cryptoMatched) ...[
        if (text.containsAny(const ['bitcoin', 'btc'])) 'Bitcoin',
        if (text.containsAny(const ['ethereum', 'ether', 'eth'])) 'Ethereum',
        if (!text.containsAny(const [
          'bitcoin',
          'btc',
          'ethereum',
          'ether',
          'eth',
        ]))
          'Kripto varlıklar',
      ],
      if (foreignExchangeMatched) ...[
        if (text.containsAny(const ['dolar*', 'usd try', 'dxy'])) 'ABD doları',
        if (text.containsAny(const ['euro*', 'avro*', 'eur try'])) 'Euro',
        if (text.containsAny(const ['türk lirası', 'tl'])) 'Türk lirası',
      ],
    }.take(12).toList(growable: false);

    final breadth = <bool>[
      stockMatched,
      bankingMatched,
      goldMatched,
      foreignExchangeMatched,
      cryptoMatched,
      oilMatched,
    ].where((matched) => matched).length;
    final impactScore = _bounded(
      (importanceScore * 0.50 + financialScore * 0.40 + (breadth / 6) * 10)
          .round(),
    );
    final riskScore = _bounded(
      (impactScore * 0.72 +
              (signals.geopolitical ? 18 : 0) +
              (signals.urgent ? 10 : 0))
          .round(),
    );
    final riskLevel = switch (riskScore) {
      >= 80 => 'Çok Yüksek',
      >= 60 => 'Yüksek',
      >= 35 => 'Orta',
      _ => 'Düşük',
    };

    return NewsFinancialImpactAssessment(
      stockMarket: stockMatched || signals.centralBank
          ? 'Borsa endeksleri ve hisselerde haber akışına duyarlılık ile oynaklık artabilir.'
          : 'Borsa için doğrudan ve belirgin bir etki sinyali saptanmadı.',
      banking: bankingMatched
          ? 'Faiz, kredi koşulları ve banka hisselerinin fiyatlaması etkilenebilir.'
          : 'Bankacılık için doğrudan bir etki sinyali saptanmadı.',
      gold: goldMatched || signals.ratesAndInflation || signals.geopolitical
          ? 'Faiz, dolar ve güvenli liman talebi üzerinden altın fiyatlaması etkilenebilir.'
          : 'Altın için doğrudan bir etki sinyali saptanmadı.',
      foreignExchange:
          foreignExchangeMatched ||
              signals.centralBank ||
              signals.ratesAndInflation
          ? 'Faiz beklentileri ve risk algısı döviz kurlarında oynaklık oluşturabilir.'
          : 'Döviz için doğrudan bir etki sinyali saptanmadı.',
      crypto: cryptoMatched || signals.ratesAndInflation
          ? 'Küresel likidite ve risk iştahındaki değişim kripto varlıklara yansıyabilir.'
          : 'Kripto varlıklar için doğrudan bir etki sinyali saptanmadı.',
      oil: oilMatched || signals.geopolitical
          ? 'Arz beklentileri ve jeopolitik riskler petrol fiyatlamasını etkileyebilir.'
          : 'Petrol için doğrudan bir etki sinyali saptanmadı.',
      sectors: List.unmodifiable(sectors.take(8)),
      companies: List.unmodifiable(companies.take(8)),
      overallMarket: impactScore >= 70
          ? 'Haber, birden fazla piyasa alanında yüksek önem taşıyor ve geniş çaplı fiyatlama hassasiyeti oluşturabilir.'
          : impactScore >= 40
          ? 'Haberin piyasa etkisi seçili varlık ve sektörlerde sınırlı-orta ölçekte hissedilebilir.'
          : 'Haberin genel piyasa üzerindeki doğrudan etkisinin sınırlı kalması beklenebilir.',
      riskLevel: riskLevel,
      impactScore: impactScore,
      affectedAssets: List.unmodifiable(affectedAssets),
    );
  }

  NewsConfidenceAssessment _confidenceAssessment({
    required int sourceCount,
    required int confirmingSourceCount,
    required NewsFreshnessAssessment freshness,
    required NewsSourceAssessment source,
  }) {
    final sourceBreadthScore = switch (sourceCount) {
      >= 4 => 100,
      3 => 85,
      2 => 65,
      _ => 35,
    };
    final confirmationScore = switch (confirmingSourceCount) {
      >= 3 => 100,
      2 => 82,
      1 => 60,
      _ => 25,
    };
    final score = _bounded(
      (sourceBreadthScore * 0.30 +
              confirmationScore * 0.30 +
              freshness.score * 0.25 +
              source.score * 0.15)
          .round(),
    );
    final label = switch (score) {
      >= 85 => 'Çok Yüksek',
      >= 70 => 'Yüksek',
      >= 45 => 'Orta',
      _ => 'Düşük',
    };

    return NewsConfidenceAssessment(
      label: label,
      score: score,
      sourceCount: sourceCount,
      confirmingSourceCount: confirmingSourceCount,
      reason:
          '$sourceCount kaynak, $confirmingSourceCount doğrulayan kaynak ve '
          '${freshness.label.toLowerCase()} yayın zamanı birlikte değerlendirildi.',
    );
  }

  NewsSourceAssessment _assessSource(String source, String feedSource) {
    final value = source.trim().isNotEmpty ? source.trim() : feedSource.trim();
    final normalized = _normalize(value);
    final rawLower = value.toLowerCase();

    final isOfficial =
        _officialSourceExact.contains(normalized) ||
        _officialSourceKeywords.any(normalized.contains) ||
        rawLower.contains('.gov.tr') ||
        rawLower.contains('kap.org.tr') ||
        rawLower.contains('tcmb.gov.tr') ||
        rawLower.contains('spk.gov.tr') ||
        rawLower.contains('bddk.org.tr') ||
        rawLower.contains('tuik.gov.tr');
    if (isOfficial) {
      return const NewsSourceAssessment(
        level: NewsSourceLevel.official,
        label: 'Resmî Kaynak',
        score: _officialSourceScore,
        reason:
            'Kaynak adı resmî kurum sinyali taşıyor. Bu sınıf haber '
            'doğruluğunun kesin garantisi değildir.',
      );
    }

    if (_corporateSourceKeywords.any(normalized.contains)) {
      return const NewsSourceAssessment(
        level: NewsSourceLevel.corporate,
        label: 'Kurumsal Kaynak',
        score: _corporateSourceScore,
        reason:
            'Kaynak kurumsal açıklama kanalı olarak tanımlanıyor. İçerik '
            'ayrıca bağlamıyla değerlendirilmelidir.',
      );
    }

    if (_knownNewsOrganizations.any(
      (organization) => _containsPhrase(normalized, organization),
    )) {
      return const NewsSourceAssessment(
        level: NewsSourceLevel.newsOrganization,
        label: 'Haber Kuruluşu',
        score: _newsOrganizationScore,
        reason:
            'Kaynak adı tanınan haber kuruluşları listesiyle eşleşiyor. Bu '
            'sınıf haber doğruluğunun kesin garantisi değildir.',
      );
    }

    return const NewsSourceAssessment(
      level: NewsSourceLevel.limited,
      label: 'Kaynak Bilgisi Sınırlı',
      score: _limitedSourceScore,
      reason:
          'Kaynak için sınırlı sınıflandırma bilgisi bulunuyor; güvenilirlik '
          'hakkında kesin bir iddia üretilmedi.',
    );
  }

  NewsFreshnessAssessment _assessFreshness(DateTime? publishedAt) {
    if (publishedAt == null) {
      return const NewsFreshnessAssessment(
        level: NewsFreshnessLevel.unknown,
        label: 'Tarih Bilgisi Yok',
        score: _unknownFreshnessScore,
        reason: 'Geçerli yayın tarihi bulunmadığı için güncellik hesaplanmadı.',
      );
    }

    final now = _now().toUtc();
    final published = publishedAt.toUtc();
    if (published.isAfter(now.add(_futureTolerance))) {
      return const NewsFreshnessAssessment(
        level: NewsFreshnessLevel.unknown,
        label: 'Tarih Bilgisi Geçersiz',
        score: _unknownFreshnessScore,
        reason: 'Yayın tarihi gelecekte göründüğü için güncellik hesaplanmadı.',
      );
    }

    final age = now.difference(published);
    if (age <= _veryNewLimit) {
      return const NewsFreshnessAssessment(
        level: NewsFreshnessLevel.veryNew,
        label: 'Çok Yeni',
        score: _veryNewScore,
        reason: 'Haber son iki saat içinde yayımlandı.',
      );
    }
    if (age <= _currentLimit) {
      return const NewsFreshnessAssessment(
        level: NewsFreshnessLevel.current,
        label: 'Güncel',
        score: _currentScore,
        reason: 'Haber son 24 saat içinde yayımlandı.',
      );
    }
    if (age <= _recentLimit) {
      return const NewsFreshnessAssessment(
        level: NewsFreshnessLevel.recent,
        label: 'Yakın Dönem',
        score: _recentScore,
        reason: 'Haber son yedi gün içinde yayımlandı.',
      );
    }
    return const NewsFreshnessAssessment(
      level: NewsFreshnessLevel.old,
      label: 'Eski',
      score: _oldScore,
      reason: 'Haberin yayın tarihinin üzerinden yedi günden fazla geçti.',
    );
  }

  void _remember(
    String identity,
    String cacheKey,
    NewsIntelligenceResult result,
  ) {
    if (_cache.length >= _maximumCacheItems) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      final oldestIdentity = _keyIdentities.remove(oldestKey);
      if (oldestIdentity != null &&
          _identityKeys[oldestIdentity] == oldestKey) {
        _identityKeys.remove(oldestIdentity);
      }
    }
    _cache[cacheKey] = result;
    _identityKeys[identity] = cacheKey;
    _keyIdentities[cacheKey] = identity;
  }

  String _identity(String newsId, String title, DateTime? publishedAt) {
    final value = newsId.trim();
    if (value.isNotEmpty) return value;
    return '${title.trim()}|${publishedAt?.toUtc().toIso8601String() ?? 'no-date'}';
  }

  bool _isFinancialCategory(String category) {
    final value = _normalize(category);
    return value == 'ekonomi' || value == 'borsa' || value == 'kripto';
  }

  int _bounded(int value) => value.clamp(minimumScore, maximumScore);

  String _safeReason(String value) {
    final normalized = _normalize(value);
    final words = normalized.split(' ').toSet();
    if (words.intersection(_forbiddenSingleWords).isNotEmpty ||
        _forbiddenPhrases.any(normalized.contains)) {
      return 'Bu değerlendirme yalnızca haber metnindeki açıklanabilir '
          'sinyallere dayanır.';
    }
    return value;
  }

  static bool _containsPhrase(String normalizedText, String phrase) {
    return ' $normalizedText '.contains(' ${_normalize(phrase)} ');
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' ve ')
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _NewsText {
  _NewsText(this.raw) : normalized = NewsIntelligenceService._normalize(raw);

  final String raw;
  final String normalized;

  bool get containsKap {
    return RegExp(r'(^|[^A-ZÇĞİÖŞÜ0-9])KAP([^A-ZÇĞİÖŞÜ0-9]|$)').hasMatch(raw) ||
        containsAny(const [
          'kamuyu aydınlatma platformu',
          'kap açıklaması',
          'kap bildirimi',
        ]);
  }

  bool containsAny(List<String> keywords) {
    final paddedText = ' $normalized ';
    final tokens = normalized.split(' ');

    for (final keyword in keywords) {
      final isPrefix = keyword.endsWith('*');
      final normalizedKeyword = NewsIntelligenceService._normalize(
        isPrefix ? keyword.substring(0, keyword.length - 1) : keyword,
      );
      if (normalizedKeyword.isEmpty) continue;
      if (isPrefix &&
          tokens.any((token) => token.startsWith(normalizedKeyword))) {
        return true;
      }
      if (!isPrefix && paddedText.contains(' $normalizedKeyword ')) return true;
    }
    return false;
  }
}

class _DetectedSignals {
  const _DetectedSignals({
    required this.centralBank,
    required this.ratesAndInflation,
    required this.market,
    required this.regulation,
    required this.corporateEvent,
    required this.macroData,
    required this.assetMarket,
    required this.geopolitical,
    required this.urgent,
    required this.banking,
    required this.globalMarket,
    required this.business,
    required this.importanceLabels,
    required this.financialLabels,
  });

  final bool centralBank;
  final bool ratesAndInflation;
  final bool market;
  final bool regulation;
  final bool corporateEvent;
  final bool macroData;
  final bool assetMarket;
  final bool geopolitical;
  final bool urgent;
  final bool banking;
  final bool globalMarket;
  final bool business;
  final List<String> importanceLabels;
  final List<String> financialLabels;

  List<String> get allLabels =>
      {...importanceLabels, ...financialLabels}.toList(growable: false);
}
