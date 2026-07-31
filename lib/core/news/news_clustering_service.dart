import 'dart:collection';

enum NewsClusterMatchStrength { strong, uncertain, weak }

class NewsClusterSignals {
  const NewsClusterSignals({
    required this.normalizedTitle,
    required this.titleTokens,
    required this.entities,
    required this.eventTypes,
    required this.numericValues,
  });

  final String normalizedTitle;
  final Set<String> titleTokens;
  final Set<String> entities;
  final Set<String> eventTypes;
  final Set<String> numericValues;
}

class NewsClusterCandidate {
  const NewsClusterCandidate({
    required this.newsId,
    required this.title,
    required this.summary,
    required this.source,
    required this.feedSource,
    required this.category,
    required this.publishedAt,
    required this.url,
    required this.imageUrl,
    this.articleText = '',
    this.originalTitle = '',
    this.isFeedItem = true,
    this.trendoraScore = 0,
    this.sourceScore = 0,
  });

  final String newsId;
  final String title;
  final String originalTitle;
  final String summary;
  final String articleText;
  final String source;
  final String feedSource;
  final String category;
  final DateTime? publishedAt;
  final String url;
  final String imageUrl;
  final bool isFeedItem;
  final int trendoraScore;
  final int sourceScore;

  String get stableId {
    final id = newsId.trim();
    if (id.isNotEmpty) return id;
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl.isNotEmpty) return normalizedUrl;
    return '${title.trim()}|${publishedAt?.toUtc().toIso8601String() ?? 'no-date'}';
  }

  String get sourceLabel {
    final value = source.trim();
    if (value.isNotEmpty) return value;
    final fallback = feedSource.trim();
    return fallback.isEmpty ? 'Kaynak belirtilmedi' : fallback;
  }
}

class NewsClusterSimilarity {
  const NewsClusterSimilarity({
    required this.score,
    required this.strength,
    required this.reasons,
  });

  final double score;
  final NewsClusterMatchStrength strength;
  final List<String> reasons;
}

class NewsEventCluster {
  const NewsEventCluster({
    required this.id,
    required this.representative,
    required this.items,
    required this.explanation,
  });

  final String id;
  final NewsClusterCandidate representative;
  final List<NewsClusterCandidate> items;
  final String explanation;

  int get uniqueSourceCount => sourceLabels.length;

  List<String> get sourceLabels {
    final labels = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final label = item.sourceLabel;
      if (seen.add(_normalizeText(label))) labels.add(label);
    }
    return List.unmodifiable(labels);
  }

  List<NewsClusterCandidate> get oldestFirstItems {
    final sorted = [...items];
    sorted.sort(_oldestFirst);
    return List.unmodifiable(sorted);
  }

  bool contains(String newsId) {
    return items.any((item) => item.stableId == newsId);
  }
}

class NewsClusteringService {
  NewsClusteringService({
    int maximumAnalysisCacheItems = defaultMaximumAnalysisCacheItems,
    int maximumResultCacheItems = defaultMaximumResultCacheItems,
    DateTime Function()? now,
  }) : assert(maximumAnalysisCacheItems > 0),
       assert(maximumResultCacheItems > 0),
       _maximumAnalysisCacheItems = maximumAnalysisCacheItems,
       _maximumResultCacheItems = maximumResultCacheItems,
       _now = now ?? DateTime.now;

  static final NewsClusteringService shared = NewsClusteringService();

  static const int defaultMaximumAnalysisCacheItems = 512;
  static const int defaultMaximumResultCacheItems = 12;
  static const int maximumCandidateClustersPerItem = 24;
  static const Duration maximumEventWindow = Duration(hours: 72);

  static const double strongMatchThreshold = 0.72;
  static const double uncertainMatchThreshold = 0.58;
  static const double minimumStrongTitleSimilarity = 0.55;
  static const int minimumSharedTitleTokens = 2;

  static const double titleSimilarityWeight = 0.44;
  static const double entitySimilarityWeight = 0.18;
  static const double eventTypeWeight = 0.14;
  static const double categoryWeight = 0.08;
  static const double timeWeight = 0.08;
  static const double numericWeight = 0.06;
  static const double sourceDiversityWeight = 0.02;

  static const double representativeTrendoraWeight = 0.35;
  static const double representativeFreshnessWeight = 0.20;
  static const double representativeSourceWeight = 0.15;
  static const double representativeCompletenessWeight = 0.20;
  static const double representativeCoverageWeight = 0.10;

  static const Set<String> _stopWords = {
    'aciklandi',
    'açıklandı',
    'ardindan',
    'ardından',
    'belli',
    'bir',
    'bu',
    'da',
    'de',
    'dedi',
    'icin',
    'için',
    'ile',
    'ise',
    'mi',
    'mı',
    'mu',
    'mü',
    'ne',
    'olan',
    'olarak',
    'oldu',
    'sonra',
    've',
    'veya',
    'yeni',
    'the',
    'and',
    'for',
    'from',
    'into',
    'over',
    'says',
    'with',
  };

  static const Map<String, List<String>> _eventKeywords = {
    'faiz-karari': [
      'faiz kararı',
      'faiz',
      'interest rate decision',
      'interest rate',
      'rate decision',
    ],
    'enflasyon-verisi': ['enflasyon', 'tüfe', 'üfe', 'inflation'],
    'bilanco': ['bilanço', 'finansal sonuç', 'financial results', 'earnings'],
    'sozlesme': ['sözleşme', 'ihale', 'contract', 'tender'],
    'satin-alma': ['satın alma', 'devral', 'acquisition', 'takeover'],
    'temettu': ['temettü', 'dividend'],
    'geri-alim': ['geri alım', 'share buyback', 'buyback'],
    'sermaye-artirimi': ['sermaye artırımı', 'bedelli', 'bedelsiz'],
    'duzenleme': ['düzenleme', 'yönetmelik', 'resmî gazete', 'regulation'],
    'atama': ['atandı', 'atama', 'görevden alındı', 'appointed'],
    'urun-lansmani': [
      'tanıttı',
      'lansman',
      'yeni model',
      'launches',
      'unveils',
    ],
    'istihdam': ['işten çıkar', 'istihdam', 'layoff', 'jobs report'],
    'secim': ['seçim', 'oylama', 'election'],
    'deprem': ['deprem', 'earthquake'],
    'yangin': ['yangın', 'wildfire', 'fire'],
    'kaza': ['kaza', 'çarpıştı', 'accident', 'crash'],
    'catisma': ['çatışma', 'saldırı', 'savaş', 'attack', 'war'],
    'mac': ['maçı', 'maçında', 'finale', 'yarı final', 'match'],
    'fiyat-hareketi': ['yükseldi', 'düştü', 'rekor kırdı', 'rallied', 'fell'],
  };

  static const Map<String, List<String>> _entityKeywordGroups = {
    'tcmb': ['tcmb', 'türkiye cumhuriyet merkez bankası'],
    'fed': ['fed', 'federal reserve', 'abd merkez bankası'],
    'ecb': ['ecb', 'avrupa merkez bankası', 'european central bank'],
    'merkez-bankasi': ['merkez bankası', 'central bank'],
    'bist': ['bist', 'borsa istanbul'],
    'nasdaq': ['nasdaq'],
    's&p-500': ['s&p 500', 's p 500'],
    'spk': ['spk', 'sermaye piyasası kurulu'],
    'bddk': ['bddk', 'bankacılık düzenleme ve denetleme kurumu'],
    'tuik': ['tüik', 'tuik', 'türkiye istatistik kurumu'],
    'kap': ['kap', 'kamuyu aydınlatma platformu'],
    'avrupa-birligi': ['avrupa birliği', 'european union'],
    'abd': ['abd', 'amerika birleşik devletleri', 'united states'],
    'turkiye': ['türkiye', 'turkey'],
    'almanya': ['almanya', 'germany'],
    'fransa': ['fransa', 'france'],
    'ispanya': ['ispanya', 'spain'],
    'ingiltere': ['ingiltere', 'britain', 'united kingdom'],
    'cin': ['çin', 'china'],
    'rusya': ['rusya', 'russia'],
    'ukrayna': ['ukrayna', 'ukraine'],
    'iran': ['iran'],
    'israil': ['israil', 'israel'],
  };

  final int _maximumAnalysisCacheItems;
  final int _maximumResultCacheItems;
  final DateTime Function() _now;
  final LinkedHashMap<String, _CandidateAnalysis> _analysisCache =
      LinkedHashMap();
  final LinkedHashMap<String, List<NewsEventCluster>> _resultCache =
      LinkedHashMap();

  int get cachedAnalysisCount => _analysisCache.length;
  int get cachedResultCount => _resultCache.length;

  static String normalizeTitle(
    String value, {
    Iterable<String> sourceNames = const [],
  }) {
    var normalized = _normalizeText(value);
    const prefixes = [
      'son dakika haberi ',
      'son dakika ',
      'breaking news ',
      'breaking ',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length).trim();
        break;
      }
    }

    const genericSuffixes = ['son dakika haberleri', 'latest news'];
    for (final suffix in genericSuffixes) {
      if (normalized.endsWith(' $suffix')) {
        normalized = normalized
            .substring(0, normalized.length - suffix.length)
            .trim();
      }
    }

    for (final sourceName in sourceNames) {
      final source = _normalizeText(sourceName);
      if (source.length < 3 || source == normalized) continue;
      if (normalized.endsWith(' $source')) {
        normalized = normalized
            .substring(0, normalized.length - source.length)
            .trim();
      }
    }
    return normalized;
  }

  NewsClusterSignals extractSignals(NewsClusterCandidate candidate) {
    final analysis = _analysisFor(candidate);
    return NewsClusterSignals(
      normalizedTitle: analysis.normalizedTitle,
      titleTokens: Set.unmodifiable(analysis.titleTokens),
      entities: Set.unmodifiable(analysis.entities),
      eventTypes: Set.unmodifiable(analysis.eventTypes),
      numericValues: Set.unmodifiable(analysis.numericValues),
    );
  }

  NewsClusterSimilarity compare(
    NewsClusterCandidate left,
    NewsClusterCandidate right,
  ) {
    return _compareAnalyses(_analysisFor(left), _analysisFor(right));
  }

  List<NewsEventCluster> cluster({
    required String categoryKey,
    required Iterable<NewsClusterCandidate> candidates,
    List<NewsEventCluster> previousClusters = const [],
  }) {
    final uniqueCandidates = _deduplicate(candidates);
    if (uniqueCandidates.isEmpty) return const [];

    final batchKey = _batchKey(categoryKey, uniqueCandidates, previousClusters);
    final cached = _resultCache.remove(batchKey);
    if (cached != null) {
      _resultCache[batchKey] = cached;
      return cached;
    }

    final previousIdsByMember = <String, String>{};
    for (final cluster in previousClusters) {
      for (final item in cluster.items) {
        previousIdsByMember[item.stableId] = cluster.id;
      }
    }

    final groups = <_MutableCluster>[];
    final candidateIndex = <String, List<_MutableCluster>>{};

    for (final candidate in uniqueCandidates) {
      final analysis = _analysisFor(candidate);
      _placeCandidate(
        candidate: candidate,
        analysis: analysis,
        groups: groups,
        candidateIndex: candidateIndex,
      );
    }

    final result = _buildClusters(
      categoryKey: categoryKey,
      groups: groups,
      previousIdsByMember: previousIdsByMember,
    );

    _rememberResult(batchKey, result);
    return result;
  }

  List<NewsEventCluster> appendToClusters({
    required String categoryKey,
    required List<NewsEventCluster> previousClusters,
    required Iterable<NewsClusterCandidate> candidates,
  }) {
    final uniqueAdditions = _deduplicate(candidates);
    if (uniqueAdditions.isEmpty) return previousClusters;
    if (previousClusters.isEmpty) {
      return cluster(categoryKey: categoryKey, candidates: uniqueAdditions);
    }

    final existingItems = previousClusters
        .expand((cluster) => cluster.items)
        .toList(growable: false);
    final existingIdentities = <String>{};
    for (final item in existingItems) {
      existingIdentities.addAll(_deduplicationKeys(item, _analysisFor(item)));
    }

    final hasIdentityCollision = uniqueAdditions.any((candidate) {
      final identities = _deduplicationKeys(candidate, _analysisFor(candidate));
      return identities.any(existingIdentities.contains);
    });
    if (hasIdentityCollision) {
      return cluster(
        categoryKey: categoryKey,
        candidates: [...existingItems, ...uniqueAdditions],
        previousClusters: previousClusters,
      );
    }

    final groups = previousClusters
        .map(
          (cluster) => _MutableCluster.fromExisting(
            cluster,
            cluster.items.map(_analysisFor).toList(growable: false),
          ),
        )
        .toList(growable: true);
    final candidateIndex = <String, List<_MutableCluster>>{};
    for (final group in groups) {
      for (final analysis in group.analyses) {
        _indexGroup(candidateIndex, group, analysis);
      }
    }

    for (final candidate in uniqueAdditions) {
      _placeCandidate(
        candidate: candidate,
        analysis: _analysisFor(candidate),
        groups: groups,
        candidateIndex: candidateIndex,
      );
    }

    return _buildClusters(
      categoryKey: categoryKey,
      groups: groups,
      previousIdsByMember: const {},
    );
  }

  List<NewsClusterCandidate> _deduplicate(
    Iterable<NewsClusterCandidate> candidates,
  ) {
    final candidatesBySlot = <String, NewsClusterCandidate>{};
    final identitySlots = <String, String>{};
    final slotOrder = <String>[];
    for (final candidate in candidates) {
      if (candidate.title.trim().isEmpty) continue;
      final analysis = _analysisFor(candidate);
      final identityKeys = _deduplicationKeys(candidate, analysis);
      String? slot;
      for (final identityKey in identityKeys) {
        slot ??= identitySlots[identityKey];
      }
      if (slot == null) {
        slot = 'slot:${slotOrder.length}';
        slotOrder.add(slot);
      }
      for (final identityKey in identityKeys) {
        identitySlots[identityKey] = slot;
      }

      final existing = candidatesBySlot[slot];
      if (existing == null) {
        candidatesBySlot[slot] = candidate;
      } else if (_candidateCompleteness(candidate) >
          _candidateCompleteness(existing)) {
        candidatesBySlot[slot] = candidate;
      }
    }
    return slotOrder
        .map((slot) => candidatesBySlot[slot]!)
        .toList(growable: false);
  }

  List<String> _deduplicationKeys(
    NewsClusterCandidate candidate,
    _CandidateAnalysis analysis,
  ) {
    final keys = <String>[];
    final newsId = candidate.newsId.trim();
    if (newsId.isNotEmpty) keys.add('id:$newsId');

    final normalizedUrl = _normalizeUrl(candidate.url);
    if (normalizedUrl.isNotEmpty) keys.add('url:$normalizedUrl');

    final day =
        candidate.publishedAt?.toUtc().toIso8601String().split('T').first ??
        'no-date';
    final events = analysis.eventTypes.toList()..sort();
    final numbers = analysis.numericValues.toList()..sort();
    keys.add(
      'story:${analysis.normalizedTitle}|${analysis.sourceIdentity}|$day|'
      'events:${events.join(',')}|numbers:${numbers.join(',')}',
    );
    return keys;
  }

  void _placeCandidate({
    required NewsClusterCandidate candidate,
    required _CandidateAnalysis analysis,
    required List<_MutableCluster> groups,
    required Map<String, List<_MutableCluster>> candidateIndex,
  }) {
    final possibleGroups = <_MutableCluster>{};
    for (final key in _indexKeys(analysis)) {
      final indexedGroups = candidateIndex[key];
      if (indexedGroups == null) continue;
      for (final group in indexedGroups.reversed) {
        possibleGroups.add(group);
        if (possibleGroups.length >= maximumCandidateClustersPerItem) break;
      }
      if (possibleGroups.length >= maximumCandidateClustersPerItem) break;
    }

    _MutableCluster? bestGroup;
    NewsClusterSimilarity? bestMatch;
    for (final group in possibleGroups) {
      final match = group.safeStrongMatchFor(analysis, _compareAnalyses);
      if (match == null) continue;
      if (bestMatch == null || match.score > bestMatch.score) {
        bestGroup = group;
        bestMatch = match;
      }
    }

    final target = bestGroup ?? _MutableCluster();
    if (bestGroup == null) groups.add(target);
    target.add(candidate, analysis, bestMatch);
    _indexGroup(candidateIndex, target, analysis);
  }

  void _indexGroup(
    Map<String, List<_MutableCluster>> candidateIndex,
    _MutableCluster group,
    _CandidateAnalysis analysis,
  ) {
    for (final key in _indexKeys(analysis)) {
      final indexed = candidateIndex.putIfAbsent(key, () => []);
      if (!indexed.contains(group)) indexed.add(group);
      if (indexed.length > maximumCandidateClustersPerItem) {
        indexed.removeAt(0);
      }
    }
  }

  List<NewsEventCluster> _buildClusters({
    required String categoryKey,
    required List<_MutableCluster> groups,
    required Map<String, String> previousIdsByMember,
  }) {
    return groups
        .map((group) {
          final original = group.original;
          if (original != null && !group.modified) return original;

          final representative = _selectRepresentative(group);
          final previousIds =
              group.items
                  .map((item) => previousIdsByMember[item.stableId])
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort();
          final id =
              original?.id ??
              (previousIds.isNotEmpty
                  ? previousIds.first
                  : _clusterId(categoryKey, group.analyses.first));
          final sortedItems = [...group.items]..sort(_newestFirst);
          return NewsEventCluster(
            id: id,
            representative: representative,
            items: List.unmodifiable(sortedItems),
            explanation: group.explanation,
          );
        })
        .toList(growable: false);
  }

  NewsClusterSimilarity _compareAnalyses(
    _CandidateAnalysis left,
    _CandidateAnalysis right,
  ) {
    final exactTitle = left.normalizedTitle == right.normalizedTitle;
    final sharedTitleTokens = left.titleTokens.intersection(right.titleTokens);
    final titleSimilarity = _tokenSimilarity(
      left.titleTokens,
      right.titleTokens,
    );
    final entitySimilarity = _setSimilarity(left.entities, right.entities);
    final sharedEvents = left.eventTypes.intersection(right.eventTypes);
    final eventSimilarity = _optionalSetSimilarity(
      left.eventTypes,
      right.eventTypes,
    );
    final categorySimilarity = _categorySimilarity(
      left.category,
      right.category,
    );
    final timeSimilarity = _timeSimilarity(left.publishedAt, right.publishedAt);
    final numericSimilarity = _numericSimilarity(
      left.numericValues,
      right.numericValues,
    );
    final differentSources = left.sourceIdentity != right.sourceIdentity;
    final sourceSimilarity = differentSources ? 1.0 : 0.4;

    final numericConflict =
        left.numericValues.isNotEmpty &&
        right.numericValues.isNotEmpty &&
        left.numericValues.intersection(right.numericValues).isEmpty;
    final eventConflict =
        left.eventTypes.isNotEmpty &&
        right.eventTypes.isNotEmpty &&
        sharedEvents.isEmpty;
    final timeConflict = timeSimilarity == 0;
    final categoryConflict = _categoriesConflict(left.category, right.category);

    final score =
        (titleSimilarity * titleSimilarityWeight +
                entitySimilarity * entitySimilarityWeight +
                eventSimilarity * eventTypeWeight +
                categorySimilarity * categoryWeight +
                timeSimilarity * timeWeight +
                numericSimilarity * numericWeight +
                sourceSimilarity * sourceDiversityWeight)
            .clamp(0.0, 1.0);

    final hardConflict =
        numericConflict || eventConflict || timeConflict || categoryConflict;
    final enoughSharedWords =
        sharedTitleTokens.length >= minimumSharedTitleTokens;
    final supportingSignal =
        sharedEvents.isNotEmpty ||
        left.entities.intersection(right.entities).isNotEmpty ||
        titleSimilarity >= 0.82;

    final strength =
        !hardConflict &&
            ((exactTitle && titleSimilarity == 1) ||
                (score >= strongMatchThreshold &&
                    titleSimilarity >= minimumStrongTitleSimilarity &&
                    enoughSharedWords &&
                    supportingSignal))
        ? NewsClusterMatchStrength.strong
        : !hardConflict && score >= uncertainMatchThreshold
        ? NewsClusterMatchStrength.uncertain
        : NewsClusterMatchStrength.weak;

    final reasons = <String>[];
    if (exactTitle) {
      reasons.add('Başlıklar normalizasyon sonrasında aynı.');
    } else if (titleSimilarity >= minimumStrongTitleSimilarity) {
      reasons.add('Başlıklarda birden fazla ortak anlamlı ifade var.');
    }
    if (sharedEvents.isNotEmpty) {
      reasons.add('Ortak olay türü: ${sharedEvents.join(', ')}.');
    }
    final sharedEntities = left.entities.intersection(right.entities);
    if (sharedEntities.isNotEmpty) {
      reasons.add(
        'Ortak konu veya varlık: ${sharedEntities.take(3).join(', ')}.',
      );
    }
    if (numericConflict) {
      reasons.add('Sayısal değerler farklı olduğu için haberler ayrı tutuldu.');
    }
    if (eventConflict) {
      reasons.add('Olay türleri farklı olduğu için haberler ayrı tutuldu.');
    }
    if (timeConflict) {
      reasons.add('Yayın zamanları güvenli olay penceresinin dışında.');
    }
    if (categoryConflict) {
      reasons.add('Kategoriler güvenli biçimde bağdaştırılamadı.');
    }
    if (strength == NewsClusterMatchStrength.uncertain) {
      reasons.add(
        'Eşleşme belirsiz kaldığı için otomatik olarak birleştirilmedi.',
      );
    }
    if (reasons.isEmpty) {
      reasons.add(
        'Aynı olay olduğunu gösterecek yeterli ortak sinyal bulunmadı.',
      );
    }

    return NewsClusterSimilarity(
      score: score,
      strength: strength,
      reasons: List.unmodifiable(reasons),
    );
  }

  NewsClusterCandidate _selectRepresentative(_MutableCluster group) {
    final allTokens = <String>{};
    for (final analysis in group.analyses) {
      allTokens.addAll(analysis.titleTokens);
    }

    var best = group.items.first;
    var bestScore = -1.0;
    for (var index = 0; index < group.items.length; index++) {
      final item = group.items[index];
      final analysis = group.analyses[index];
      final coverage = allTokens.isEmpty
          ? 0.0
          : analysis.titleTokens.length / allTokens.length;
      final score =
          item.trendoraScore.clamp(0, 100) * representativeTrendoraWeight +
          _freshnessScore(item.publishedAt) * representativeFreshnessWeight +
          item.sourceScore.clamp(0, 100) * representativeSourceWeight +
          _candidateCompleteness(item) * representativeCompletenessWeight +
          coverage * 100 * representativeCoverageWeight;
      if (score > bestScore ||
          (score == bestScore && item.stableId.compareTo(best.stableId) < 0)) {
        best = item;
        bestScore = score;
      }
    }
    return best;
  }

  double _freshnessScore(DateTime? publishedAt) {
    if (publishedAt == null) return 0;
    final age = _now().toUtc().difference(publishedAt.toUtc());
    if (age.isNegative) return 0;
    if (age <= const Duration(hours: 2)) return 100;
    if (age <= const Duration(hours: 24)) return 80;
    if (age <= const Duration(days: 7)) return 55;
    return 20;
  }

  _CandidateAnalysis _analysisFor(NewsClusterCandidate candidate) {
    final signature = _stableHash(
      '${candidate.stableId}|${candidate.title}|${candidate.summary}|'
      '${candidate.source}|${candidate.feedSource}|${candidate.category}|'
      '${candidate.publishedAt?.toUtc().toIso8601String()}',
    );
    final cacheKey = '${candidate.stableId}|$signature';
    final cached = _analysisCache.remove(cacheKey);
    if (cached != null) {
      _analysisCache[cacheKey] = cached;
      return cached;
    }

    final normalizedTitle = normalizeTitle(
      candidate.title,
      sourceNames: [candidate.source, candidate.feedSource],
    );
    final titleTokens = _significantTokens(normalizedTitle);
    final fullText = _normalizeText('${candidate.title} ${candidate.summary}');
    final entities = <String>{};
    for (final entry in _entityKeywordGroups.entries) {
      if (entry.value.any(
        (keyword) => _containsPhrase(fullText, _normalizeText(keyword)),
      )) {
        entities.add(entry.key);
        if (entry.key == 'tcmb' || entry.key == 'fed' || entry.key == 'ecb') {
          entities.add('merkez-bankasi');
        }
      }
    }
    entities.addAll(_uppercaseEntities(candidate.title));

    final eventTypes = <String>{};
    for (final entry in _eventKeywords.entries) {
      if (entry.value.any(
        (keyword) => _containsPhraseOrPrefix(fullText, keyword),
      )) {
        eventTypes.add(entry.key);
      }
    }

    final analysis = _CandidateAnalysis(
      candidate: candidate,
      normalizedTitle: normalizedTitle,
      titleTokens: titleTokens,
      entities: entities,
      eventTypes: eventTypes,
      numericValues: _numericValues('${candidate.title} ${candidate.summary}'),
      category: _normalizeCategory(candidate.category),
      sourceIdentity: _normalizeText(candidate.sourceLabel),
      publishedAt: candidate.publishedAt,
    );
    _rememberAnalysis(cacheKey, analysis);
    return analysis;
  }

  Iterable<String> _indexKeys(_CandidateAnalysis analysis) sync* {
    final category = analysis.category;
    for (final event in analysis.eventTypes.take(3)) {
      yield '$category|event:$event';
    }
    for (final entity in analysis.entities.take(6)) {
      yield '$category|entity:$entity';
    }
    for (final token in analysis.titleTokens.take(6)) {
      yield '$category|token:$token';
    }
    if (analysis.normalizedTitle.isNotEmpty) {
      yield '$category|title:${_stableHash(analysis.normalizedTitle)}';
    }
  }

  String _clusterId(String categoryKey, _CandidateAnalysis anchor) {
    final eventPart = (anchor.eventTypes.toList()..sort()).take(2).join(',');
    final entityPart = (anchor.entities.toList()..sort()).take(3).join(',');
    return 'event-${_stableHash('${_normalizeCategory(categoryKey)}|$eventPart|$entityPart|${anchor.normalizedTitle}')}'
        .toLowerCase();
  }

  String _batchKey(
    String categoryKey,
    List<NewsClusterCandidate> candidates,
    List<NewsEventCluster> previousClusters,
  ) {
    final candidatePart = candidates
        .map((item) => _stableHash(_candidateResultSignature(item)))
        .join('|');
    final previousPart = previousClusters
        .map(
          (cluster) =>
              '${cluster.id}:${cluster.items.map((item) => item.stableId).join(',')}',
        )
        .join('|');
    return '${_normalizeCategory(categoryKey)}|${candidates.length}|'
        '${_stableHash(candidatePart)}|${_stableHash(previousPart)}';
  }

  String _candidateResultSignature(NewsClusterCandidate item) {
    return [
      item.stableId,
      item.title,
      item.originalTitle,
      item.summary,
      item.articleText,
      item.source,
      item.feedSource,
      item.category,
      item.publishedAt?.toUtc().toIso8601String() ?? 'no-date',
      item.url,
      item.imageUrl,
      item.isFeedItem.toString(),
      item.trendoraScore.toString(),
      item.sourceScore.toString(),
      _freshnessScore(item.publishedAt).toString(),
    ].map((value) => '${value.length}:$value').join('|');
  }

  void _rememberAnalysis(String key, _CandidateAnalysis value) {
    if (_analysisCache.length >= _maximumAnalysisCacheItems) {
      _analysisCache.remove(_analysisCache.keys.first);
    }
    _analysisCache[key] = value;
  }

  void _rememberResult(String key, List<NewsEventCluster> value) {
    if (_resultCache.length >= _maximumResultCacheItems) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[key] = value;
  }
}

class _CandidateAnalysis {
  const _CandidateAnalysis({
    required this.candidate,
    required this.normalizedTitle,
    required this.titleTokens,
    required this.entities,
    required this.eventTypes,
    required this.numericValues,
    required this.category,
    required this.sourceIdentity,
    required this.publishedAt,
  });

  final NewsClusterCandidate candidate;
  final String normalizedTitle;
  final Set<String> titleTokens;
  final Set<String> entities;
  final Set<String> eventTypes;
  final Set<String> numericValues;
  final String category;
  final String sourceIdentity;
  final DateTime? publishedAt;
}

class _MutableCluster {
  _MutableCluster() : original = null, previousExplanation = null;

  _MutableCluster.fromExisting(
    NewsEventCluster cluster,
    List<_CandidateAnalysis> existingAnalyses,
  ) : original = cluster,
      previousExplanation = cluster.explanation {
    items.addAll(cluster.items);
    analyses.addAll(existingAnalyses);
  }

  final List<NewsClusterCandidate> items = [];
  final List<_CandidateAnalysis> analyses = [];
  final List<NewsClusterSimilarity> matches = [];
  final NewsEventCluster? original;
  final String? previousExplanation;
  bool modified = false;

  String get explanation {
    final existingExplanation = previousExplanation;
    if (existingExplanation != null && existingExplanation.isNotEmpty) {
      return existingExplanation;
    }
    if (matches.isEmpty) {
      return 'Bu kayıt için güçlü bir benzer olay eşleşmesi bulunmadı.';
    }
    final reasons = <String>[];
    for (final match in matches) {
      for (final reason in match.reasons) {
        if (!reason.contains('ayrı tutuldu') &&
            !reason.contains('belirsiz') &&
            !reasons.contains(reason)) {
          reasons.add(reason);
        }
      }
    }
    return reasons.isEmpty
        ? 'Benzer başlık, ortak konu ve yakın yayın zamanı güçlü eşleşme sağladı.'
        : reasons.take(3).join(' ');
  }

  void add(
    NewsClusterCandidate item,
    _CandidateAnalysis analysis,
    NewsClusterSimilarity? match,
  ) {
    items.add(item);
    analyses.add(analysis);
    if (match != null) matches.add(match);
    modified = true;
  }

  NewsClusterSimilarity? safeStrongMatchFor(
    _CandidateAnalysis analysis,
    NewsClusterSimilarity Function(_CandidateAnalysis, _CandidateAnalysis)
    compare,
  ) {
    NewsClusterSimilarity? weakestStrongMatch;
    for (final existing in analyses) {
      final result = compare(analysis, existing);
      if (result.strength != NewsClusterMatchStrength.strong) return null;
      if (weakestStrongMatch == null ||
          result.score < weakestStrongMatch.score) {
        weakestStrongMatch = result;
      }
    }
    return weakestStrongMatch;
  }
}

double _tokenSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  if (left.length == right.length && left.containsAll(right)) return 1;
  final intersection = left.intersection(right).length;
  if (intersection == 0) return 0;
  final union = left.union(right).length;
  final jaccard = intersection / union;
  final containment =
      intersection / (left.length < right.length ? left.length : right.length);
  return jaccard * 0.55 + containment * 0.45;
}

double _setSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  return left.intersection(right).length / left.union(right).length;
}

double _optionalSetSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty && right.isEmpty) return 0.35;
  if (left.isEmpty || right.isEmpty) return 0.25;
  return _setSimilarity(left, right);
}

double _numericSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty && right.isEmpty) return 0.6;
  if (left.isEmpty || right.isEmpty) return 0.45;
  final common = left.intersection(right).length;
  if (common == 0) return 0;
  return common / left.union(right).length;
}

double _categorySimilarity(String left, String right) {
  if (left == right) return 1;
  if (left == 'genel' ||
      right == 'genel' ||
      left == 'gundem' ||
      right == 'gundem') {
    return 0.6;
  }
  return 0.15;
}

bool _categoriesConflict(String left, String right) {
  if (left == right || left == 'genel' || right == 'genel') return false;
  if (left == 'gundem' || right == 'gundem') return false;
  const financial = {'ekonomi', 'borsa', 'kripto'};
  if (financial.contains(left) && financial.contains(right)) return false;
  return left == 'spor' || right == 'spor';
}

double _timeSimilarity(DateTime? left, DateTime? right) {
  if (left == null || right == null) return 0.4;
  final difference = left.toUtc().difference(right.toUtc()).abs();
  if (difference <= const Duration(hours: 6)) return 1;
  if (difference <= const Duration(hours: 24)) return 0.85;
  if (difference <= NewsClusteringService.maximumEventWindow) return 0.6;
  return 0;
}

Set<String> _significantTokens(String value) {
  return value
      .split(' ')
      .where(
        (token) =>
            token.length >= 3 &&
            !NewsClusteringService._stopWords.contains(token),
      )
      .map(_canonicalToken)
      .toSet();
}

String _canonicalToken(String token) {
  const canonicalForms = {
    'kararı': 'karar',
    'kararını': 'karar',
    'kararının': 'karar',
    'kararında': 'karar',
    'faizi': 'faiz',
    'faizini': 'faiz',
    'fiyatı': 'fiyat',
    'fiyatını': 'fiyat',
    'gelişmeler': 'gelişme',
    'gelişmeleri': 'gelişme',
    'hisseleri': 'hisse',
    'hisselerinde': 'hisse',
    'oranı': 'oran',
    'oranını': 'oran',
    'sonuçları': 'sonuç',
    'sonuçlarını': 'sonuç',
    'yangınları': 'yangın',
    'yangınlarında': 'yangın',
  };
  return canonicalForms[token] ?? token;
}

Set<String> _uppercaseEntities(String value) {
  final matches = RegExp(
    r'(^|\s)([A-ZÇĞİÖŞÜ]{2,6})(?=\s|$)',
  ).allMatches(value.replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+'), ' '));
  return matches.map((match) => _normalizeText(match.group(2)!)).toSet();
}

Set<String> _numericValues(String value) {
  final matches = RegExp(
    r'\d+(?:[.,]\d+)?(?:\s*(?:%|milyar|milyon|bin|trilyon|tl|dolar|euro))?',
    caseSensitive: false,
  ).allMatches(value);
  return matches
      .map(
        (match) => match
            .group(0)!
            .toLowerCase()
            .replaceAll(',', '.')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .toSet();
}

bool _containsPhrase(String text, String phrase) {
  return ' $text '.contains(' $phrase ');
}

bool _containsPhraseOrPrefix(String text, String rawKeyword) {
  final keyword = _normalizeText(rawKeyword);
  if (keyword.isEmpty) return false;
  if (keyword.contains(' ')) return _containsPhrase(text, keyword);
  return text.split(' ').any((token) => token.startsWith(keyword));
}

String _normalizeCategory(String value) {
  final normalized = _normalizeText(value).replaceAll(' ', '_');
  return switch (normalized) {
    'tumu' || 'all' => 'genel',
    'turkiye' => 'gundem',
    'world' => 'dunya',
    'economy' || 'finance' => 'ekonomi',
    'sports' => 'spor',
    'technology' || 'tech' => 'teknoloji',
    _ => normalized.isEmpty ? 'genel' : normalized,
  };
}

String _normalizeText(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('&amp;', ' ve ')
      .replaceAll('&', ' ve ')
      .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return '';
  final queryParameters = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) {
      final normalized = key.toLowerCase();
      return normalized.startsWith('utm_') ||
          normalized == 'fbclid' ||
          normalized == 'gclid' ||
          normalized == 'oc';
    });
  return uri
      .replace(queryParameters: queryParameters, fragment: '')
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
}

double _candidateCompleteness(NewsClusterCandidate item) {
  var score = 0.0;
  if (item.title.trim().isNotEmpty) score += 30;
  if (item.summary.trim().isNotEmpty) score += 25;
  if (item.imageUrl.trim().isNotEmpty) score += 20;
  if (item.url.trim().isNotEmpty) score += 15;
  if (item.articleText.trim().isNotEmpty) score += 10;
  return score;
}

String _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int _newestFirst(NewsClusterCandidate left, NewsClusterCandidate right) {
  final leftDate = left.publishedAt;
  final rightDate = right.publishedAt;
  if (leftDate == null && rightDate == null) {
    return left.stableId.compareTo(right.stableId);
  }
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  final dateResult = rightDate.compareTo(leftDate);
  return dateResult != 0 ? dateResult : left.stableId.compareTo(right.stableId);
}

int _oldestFirst(NewsClusterCandidate left, NewsClusterCandidate right) {
  return -_newestFirst(left, right);
}
