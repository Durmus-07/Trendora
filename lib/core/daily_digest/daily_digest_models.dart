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
  });

  final String id;
  final DailyDigestCategory category;
  final String title;
  final String detail;
  final String source;
  final DateTime updatedAt;
  final String reference;

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
  };
}

class DailyDigestSnapshot {
  const DailyDigestSnapshot({
    required this.userId,
    required this.slotKey,
    required this.generatedAt,
    required this.items,
  });

  final String userId;
  final String slotKey;
  final DateTime generatedAt;
  final List<DailyDigestItem> items;

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
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'slotKey': slotKey,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}
