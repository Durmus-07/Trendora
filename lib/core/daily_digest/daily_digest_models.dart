enum DailyDigestPeriod { morning, evening }

enum DailyDigestCategory {
  finance,
  news,
  opportunities,
  weather,
  payments,
  reminders,
  savedAnalyses,
}

DailyDigestPeriod dailyDigestPeriodFromName(
  String? value, {
  DailyDigestPeriod fallback = DailyDigestPeriod.morning,
}) {
  return DailyDigestPeriod.values
          .where((item) => item.name == value)
          .firstOrNull ??
      fallback;
}

Set<DailyDigestCategory> dailyDigestCategoriesFromNames(dynamic value) {
  if (value is! List) return Set.unmodifiable(DailyDigestCategory.values);
  final names = value.map((item) => item.toString()).toSet();
  return Set.unmodifiable(
    DailyDigestCategory.values.where((item) => names.contains(item.name)),
  );
}

class DailyDigestItem {
  const DailyDigestItem({
    required this.id,
    required this.category,
    required this.title,
    required this.detail,
    required this.source,
    required this.updatedAt,
    required this.reference,
    this.itemType,
    this.itemId,
    this.originalUrl,
    this.normalizedUrl,
    this.snapshot,
    this.internalAssetId,
    this.canonicalSymbol,
    this.opportunityId,
    this.savedAt,
    this.target,
    this.targetArguments,
    this.dataTime,
    this.currentStatus,
  });

  final String id;
  final DailyDigestCategory category;
  final String title;
  final String detail;
  final String source;
  final DateTime updatedAt;
  final String reference;
  final String? itemType;
  final String? itemId;
  final String? originalUrl;
  final String? normalizedUrl;
  final Map<String, dynamic>? snapshot;
  final String? internalAssetId;
  final String? canonicalSymbol;
  final String? opportunityId;
  final DateTime? savedAt;
  final String? target;
  final Map<String, dynamic>? targetArguments;
  final DateTime? dataTime;
  final String? currentStatus;

  factory DailyDigestItem.fromJson(Map<String, dynamic> json) {
    final category = DailyDigestCategory.values
        .where((item) => item.name == json['category'])
        .firstOrNull;
    final updatedAt = DateTime.tryParse('${json['updatedAt'] ?? ''}');
    if (category == null || updatedAt == null) {
      throw const FormatException('Geçersiz günlük özet öğesi');
    }
    return DailyDigestItem(
      id: '${json['id'] ?? ''}'.trim(),
      category: category,
      title: '${json['title'] ?? ''}'.trim(),
      detail: '${json['detail'] ?? ''}'.trim(),
      source: '${json['source'] ?? ''}'.trim(),
      updatedAt: updatedAt.toUtc(),
      reference: '${json['reference'] ?? ''}'.trim(),
      itemType: _nullableText(json['itemType']),
      itemId: _nullableText(json['itemId']),
      originalUrl: _nullableText(json['originalUrl']),
      normalizedUrl: _nullableText(json['normalizedUrl']),
      snapshot: json['snapshot'] is Map
          ? Map<String, dynamic>.from(json['snapshot'] as Map)
          : null,
      internalAssetId: _nullableText(json['internalAssetId']),
      canonicalSymbol: _nullableText(json['canonicalSymbol']),
      opportunityId: _nullableText(json['opportunityId']),
      savedAt: DateTime.tryParse('${json['savedAt'] ?? ''}'),
      target: _nullableText(json['target']),
      targetArguments: json['targetArguments'] is Map
          ? Map<String, dynamic>.from(json['targetArguments'] as Map)
          : null,
      dataTime: DateTime.tryParse('${json['dataTime'] ?? ''}'),
      currentStatus: _nullableText(json['currentStatus']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'detail': detail,
    'source': source,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'reference': reference,
    if (itemType != null) 'itemType': itemType,
    if (itemId != null) 'itemId': itemId,
    if (originalUrl != null) 'originalUrl': originalUrl,
    if (normalizedUrl != null) 'normalizedUrl': normalizedUrl,
    if (snapshot != null) 'snapshot': snapshot,
    if (internalAssetId != null) 'internalAssetId': internalAssetId,
    if (canonicalSymbol != null) 'canonicalSymbol': canonicalSymbol,
    if (opportunityId != null) 'opportunityId': opportunityId,
    if (savedAt != null) 'savedAt': savedAt!.toUtc().toIso8601String(),
    if (target != null) 'target': target,
    if (targetArguments != null) 'targetArguments': targetArguments,
    if (dataTime != null) 'dataTime': dataTime!.toUtc().toIso8601String(),
    if (currentStatus != null) 'currentStatus': currentStatus,
  };

  static String? _nullableText(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }
}

class DailyDigestStatistics {
  const DailyDigestStatistics({
    this.savedAssetCount = 0,
    this.savedAnalysisCount = 0,
    this.savedNewsCount = 0,
    this.updatedLast24HoursCount = 0,
    this.priceChangedCount = 0,
  });

  final int savedAssetCount;
  final int savedAnalysisCount;
  final int savedNewsCount;
  final int updatedLast24HoursCount;
  final int priceChangedCount;

  bool get isEmpty =>
      savedAssetCount == 0 &&
      savedAnalysisCount == 0 &&
      savedNewsCount == 0 &&
      updatedLast24HoursCount == 0 &&
      priceChangedCount == 0;

  factory DailyDigestStatistics.fromJson(Map<String, dynamic> json) =>
      DailyDigestStatistics(
        savedAssetCount: (json['savedAssetCount'] as num?)?.toInt() ?? 0,
        savedAnalysisCount: (json['savedAnalysisCount'] as num?)?.toInt() ?? 0,
        savedNewsCount: (json['savedNewsCount'] as num?)?.toInt() ?? 0,
        updatedLast24HoursCount:
            (json['updatedLast24HoursCount'] as num?)?.toInt() ?? 0,
        priceChangedCount: (json['priceChangedCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'savedAssetCount': savedAssetCount,
    'savedAnalysisCount': savedAnalysisCount,
    'savedNewsCount': savedNewsCount,
    'updatedLast24HoursCount': updatedLast24HoursCount,
    'priceChangedCount': priceChangedCount,
  };
}

class DailyDigestSnapshot {
  const DailyDigestSnapshot({
    required this.userId,
    required this.slotKey,
    required this.generatedAt,
    required this.items,
    this.statistics = const DailyDigestStatistics(),
  });

  final String userId;
  final String slotKey;
  final DateTime generatedAt;
  final List<DailyDigestItem> items;
  final DailyDigestStatistics statistics;

  bool get isEmpty => items.isEmpty;

  factory DailyDigestSnapshot.fromJson(Map<String, dynamic> json) {
    final generatedAt = DateTime.tryParse('${json['generatedAt'] ?? ''}');
    if (generatedAt == null) {
      throw const FormatException('Geçersiz günlük özet zamanı');
    }
    final rawItems = json['items'];
    final items = <DailyDigestItem>[];
    if (rawItems is List) {
      for (final raw in rawItems.whereType<Map>()) {
        try {
          final item = DailyDigestItem.fromJson(Map<String, dynamic>.from(raw));
          if (item.id.isNotEmpty &&
              item.title.isNotEmpty &&
              item.source.isNotEmpty) {
            items.add(item);
          }
        } catch (_) {}
      }
    }
    return DailyDigestSnapshot(
      userId: '${json['userId'] ?? ''}'.trim(),
      slotKey: '${json['slotKey'] ?? ''}'.trim(),
      generatedAt: generatedAt.toUtc(),
      items: List.unmodifiable(items),
      statistics: json['statistics'] is Map
          ? DailyDigestStatistics.fromJson(
              Map<String, dynamic>.from(json['statistics'] as Map),
            )
          : const DailyDigestStatistics(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'slotKey': slotKey,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'statistics': statistics.toJson(),
  };
}
