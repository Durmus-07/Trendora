import 'dart:collection';

class NewsConceptExplanation {
  const NewsConceptExplanation({required this.term, required this.explanation});

  final String term;
  final String explanation;
}

class NewsExplanation {
  const NewsExplanation({
    required this.concepts,
    required this.possibleEffects,
  });

  static const String disclaimer =
      'Bu açıklama yalnızca bilgilendirme amacıyla Trendora tarafından '
      'otomatik olarak hazırlanmıştır. Yatırım tavsiyesi değildir.';

  final List<NewsConceptExplanation> concepts;
  final List<String> possibleEffects;

  bool get isEmpty => concepts.isEmpty && possibleEffects.isEmpty;
}

class NewsExplanationService {
  NewsExplanationService({int maximumCacheItems = 64})
    : assert(maximumCacheItems > 0),
      _maximumCacheItems = maximumCacheItems;

  static final NewsExplanationService shared = NewsExplanationService();

  static const List<_ConceptRule> _conceptRules = [
    _ConceptRule(
      term: 'FED',
      keywords: ['fed', 'federal reserve', 'abd merkez bankası'],
      explanation:
          'ABD Merkez Bankasıdır. Faiz ve para politikası kararları küresel '
          'finansman koşullarını etkileyebilir.',
    ),
    _ConceptRule(
      term: 'ECB',
      keywords: ['ecb', 'avrupa merkez bankası'],
      explanation:
          'Euro Bölgesi para politikasını yöneten Avrupa Merkez Bankasıdır.',
    ),
    _ConceptRule(
      term: 'BIST',
      keywords: ['bist', 'bist 100', 'borsa istanbul'],
      explanation:
          'Borsa İstanbul’un kısaltmasıdır. BIST 100, işlem gören büyük '
          'şirketlerin genel seyrini izleyen temel endekstir.',
    ),
    _ConceptRule(
      term: 'NASDAQ',
      keywords: ['nasdaq'],
      explanation:
          'ABD merkezli, teknoloji şirketlerinin ağırlığının yüksek olduğu '
          'bir borsa ve endeks ailesidir.',
    ),
    _ConceptRule(
      term: 'S&P 500',
      keywords: ['s&p 500', 's p 500', 'sp 500', 'sp500'],
      explanation:
          'ABD’deki 500 büyük şirketin piyasa performansını izleyen geniş '
          'kapsamlı bir endekstir.',
    ),
    _ConceptRule(
      term: 'Enflasyon',
      keywords: ['enflasyon*'],
      explanation:
          'Mal ve hizmetlerin genel fiyat düzeyinin zaman içinde artmasıdır; '
          'paranın satın alma gücünü azaltabilir.',
    ),
    _ConceptRule(
      term: 'Faiz',
      keywords: ['faiz*'],
      explanation:
          'Borçlanmanın maliyetini ve tasarrufun getirisini belirleyen orandır. '
          'Kredi, mevduat ve şirket finansmanını etkileyebilir.',
    ),
    _ConceptRule(
      term: 'Tahvil',
      keywords: ['tahvil*'],
      explanation:
          'Devletin veya şirketlerin belirli bir süre için borçlanmak amacıyla '
          'çıkardığı menkul kıymettir.',
    ),
    _ConceptRule(
      term: 'CDS',
      keywords: ['cds', 'kredi risk primi'],
      explanation:
          'Bir ülke veya şirketin borcunu ödeyememe riskine ilişkin piyasa '
          'algısını gösteren risk primidir.',
    ),
    _ConceptRule(
      term: 'DXY',
      keywords: ['dxy', 'dolar endeksi'],
      explanation:
          'ABD dolarının başlıca para birimleri karşısındaki gücünü ölçen '
          'endekstir.',
    ),
    _ConceptRule(
      term: 'Altın',
      keywords: ['altın*', 'ons altın'],
      explanation:
          'Küresel piyasalarda ons ve yerel para cinsinden izlenen kıymetli '
          'madendir; faiz, dolar ve risk algısından etkilenebilir.',
    ),
    _ConceptRule(
      term: 'Petrol',
      keywords: ['petrol*'],
      explanation:
          'Enerji, ulaştırma ve üretim maliyetleri üzerinde etkili olan temel '
          'küresel emtiadır.',
    ),
    _ConceptRule(
      term: 'Brent',
      keywords: ['brent*'],
      explanation:
          'Küresel petrol fiyatlamasında referans olarak kullanılan ham petrol '
          'türlerinden biridir.',
    ),
    _ConceptRule(
      term: 'Bitcoin',
      keywords: ['bitcoin', 'btc'],
      explanation:
          'Merkezi bir otoriteye bağlı olmadan çalışan, blokzincir tabanlı '
          'dijital varlıktır.',
    ),
    _ConceptRule(
      term: 'Ethereum',
      keywords: ['ethereum', 'ether', 'eth'],
      explanation:
          'Akıllı sözleşmelerin çalışabildiği blokzincir ağıdır; ağın yerel '
          'dijital varlığı Ether olarak adlandırılır.',
    ),
    _ConceptRule(
      term: 'KAP',
      keywords: ['kap', 'kamuyu aydınlatma platformu'],
      explanation:
          'Halka açık şirketlerin yatırımcıları ilgilendiren resmi '
          'bildirimlerini yayımladığı Kamuyu Aydınlatma Platformudur.',
    ),
    _ConceptRule(
      term: 'SPK',
      keywords: ['spk', 'sermaye piyasası kurulu'],
      explanation:
          'Türkiye’de sermaye piyasalarını düzenleyen ve denetleyen kamu '
          'kurumudur.',
    ),
    _ConceptRule(
      term: 'BDDK',
      keywords: ['bddk', 'bankacılık düzenleme ve denetleme kurumu'],
      explanation:
          'Türkiye’de bankacılık sektörünü düzenleyen ve denetleyen kamu '
          'kurumudur.',
    ),
    _ConceptRule(
      term: 'TCMB',
      keywords: ['tcmb', 'türkiye cumhuriyet merkez bankası'],
      explanation:
          'Türkiye’nin merkez bankasıdır. Fiyat istikrarı ve para politikası '
          'konularında karar alır.',
    ),
    _ConceptRule(
      term: 'Bilanço',
      keywords: ['bilanço*', 'bilançolar*'],
      explanation:
          'Bir şirketin belirli tarihteki varlıklarını, borçlarını ve öz '
          'kaynaklarını gösteren finansal tablodur.',
    ),
    _ConceptRule(
      term: 'Temettü',
      keywords: ['temettü*', 'kar payı', 'kâr payı'],
      explanation:
          'Şirket kârının belirlenen bölümünün ortaklara dağıtılmasıdır.',
    ),
    _ConceptRule(
      term: 'Geri alım',
      keywords: ['geri alım*', 'pay geri alım*', 'hisse geri alım*'],
      explanation:
          'Şirketin kendi paylarının bir bölümünü piyasadan edinmesi işlemidir.',
    ),
    _ConceptRule(
      term: 'Sermaye artırımı',
      keywords: ['sermaye artırım*', 'bedelli sermaye', 'bedelsiz sermaye'],
      explanation:
          'Şirketin sermaye tutarını yeni kaynak veya iç kaynak kullanarak '
          'yükseltmesidir.',
    ),
  ];

  static const Set<String> _forbiddenSingleWords = {'al', 'sat', 'tut'};
  static const List<String> _forbiddenPhrases = [
    'kesin yükselecek',
    'kesin düşecek',
  ];

  final int _maximumCacheItems;
  final LinkedHashMap<String, NewsExplanation> _cache = LinkedHashMap();

  int get cachedItemCount => _cache.length;

  NewsExplanation explain({
    required String newsId,
    required String title,
    required String summary,
    required String articleText,
    required String category,
  }) {
    final rawText = '$title $summary $articleText $category';
    final cacheKey = _cacheKey(newsId, rawText);
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached;
    }

    final normalizedText = _normalize(rawText);
    final concepts = _conceptRules
        .where((rule) => _matches(normalizedText, rule.keywords))
        .map(
          (rule) => NewsConceptExplanation(
            term: rule.term,
            explanation: rule.explanation,
          ),
        )
        .where(
          (concept) => _isSafe(concept.term) && _isSafe(concept.explanation),
        )
        .take(5)
        .toList(growable: false);
    final conceptTerms = concepts.map((concept) => concept.term).toSet();
    final possibleEffects = _possibleEffects(
      normalizedText,
      conceptTerms,
    ).where(_isSafe).take(3).toList(growable: false);

    final result = NewsExplanation(
      concepts: List.unmodifiable(concepts),
      possibleEffects: List.unmodifiable(possibleEffects),
    );
    if (_cache.length >= _maximumCacheItems) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;
    return result;
  }

  List<String> _possibleEffects(String text, Set<String> terms) {
    final effects = <String>[];

    if (terms.intersection(const {
      'FED',
      'ECB',
      'TCMB',
      'Faiz',
      'Enflasyon',
      'BDDK',
    }).isNotEmpty) {
      effects.add(
        'Olası etkiler bankacılık sektörü, kredi koşulları ve finansman '
        'maliyetlerinde görülebilir.',
      );
    }
    if (terms.intersection(const {'Altın', 'DXY', 'FED', 'Faiz'}).isNotEmpty) {
      effects.add(
        'Genellikle faiz ve dolar endeksindeki değişimler altın piyasasındaki '
        'oynaklığı etkileyebilir.',
      );
    }
    if (terms.intersection(const {'NASDAQ', 'S&P 500'}).isNotEmpty ||
        _matches(text, const ['teknoloji*', 'yapay zeka', 'yapay zekâ'])) {
      effects.add(
        'Olası olarak teknoloji hisselerinde ve büyüme odaklı şirketlerde '
        'oynaklık artabilir.',
      );
    }
    if (terms.intersection(const {'Petrol', 'Brent'}).isNotEmpty) {
      effects.add(
        'Genellikle petrol maliyetlerindeki değişim enflasyon, ulaştırma ve '
        'üretim giderlerine yansıyabilir.',
      );
    }
    if (terms.intersection(const {
      'BIST',
      'KAP',
      'SPK',
      'Bilanço',
      'Temettü',
      'Geri alım',
      'Sermaye artırımı',
    }).isNotEmpty) {
      effects.add(
        'Olası etkiler şirket değerlemeleri, BIST işlem hacmi ve piyasa '
        'oynaklığında görülebilir.',
      );
    }
    if (terms.intersection(const {'Bitcoin', 'Ethereum'}).isNotEmpty) {
      effects.add(
        'Genellikle küresel risk iştahındaki değişimler kripto varlıklardaki '
        'oynaklığa yansıyabilir.',
      );
    }
    if (terms.intersection(const {'CDS', 'Tahvil', 'DXY'}).isNotEmpty) {
      effects.add(
        'Olası etkiler borçlanma maliyetleri, döviz piyasası ve risk algısında '
        'hissedilebilir.',
      );
    }

    return effects.toSet().toList(growable: false);
  }

  String _cacheKey(String newsId, String rawText) {
    final identity = newsId.trim().isEmpty ? rawText : newsId.trim();
    return '$identity|${rawText.hashCode}';
  }

  bool _matches(String normalizedText, List<String> keywords) {
    final paddedText = ' $normalizedText ';
    final tokens = normalizedText.split(' ');

    for (final keyword in keywords) {
      final isPrefix = keyword.endsWith('*');
      final normalizedKeyword = _normalize(
        isPrefix ? keyword.substring(0, keyword.length - 1) : keyword,
      );
      if (normalizedKeyword.isEmpty) continue;

      if (isPrefix &&
          tokens.any((token) => token.startsWith(normalizedKeyword))) {
        return true;
      }
      if (!isPrefix && paddedText.contains(' $normalizedKeyword ')) {
        return true;
      }
    }
    return false;
  }

  bool _isSafe(String value) {
    final normalized = _normalize(value);
    final words = normalized.split(' ').toSet();
    if (words.intersection(_forbiddenSingleWords).isNotEmpty) return false;
    return !_forbiddenPhrases.any(normalized.contains);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' ve ')
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _ConceptRule {
  const _ConceptRule({
    required this.term,
    required this.keywords,
    required this.explanation,
  });

  final String term;
  final List<String> keywords;
  final String explanation;
}
