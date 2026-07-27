class SourceInfo {
  const SourceInfo({required this.name, this.updatedAt, this.fetchedAt});

  final String name;
  final DateTime? updatedAt;
  final DateTime? fetchedAt;

  factory SourceInfo.fromJson(Map<String, dynamic> json) => SourceInfo(
        name: json['name']?.toString() ?? json['source']?.toString() ?? 'unknown',
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? ''),
      );
}

class FinancialData {
  const FinancialData({required this.symbol, this.price, this.change, this.volume, required this.source});
  final String symbol;
  final num? price;
  final num? change;
  final num? volume;
  final SourceInfo source;

  factory FinancialData.fromJson(Map<String, dynamic> json) => FinancialData(
        symbol: json['symbol']?.toString() ?? '',
        price: json['price'] as num?,
        change: (json['change'] ?? json['changePercent']) as num?,
        volume: json['volume'] as num?,
        source: SourceInfo.fromJson((json['sourceInfo'] as Map?)?.cast<String, dynamic>() ?? json),
      );
}

class NewsData {
  const NewsData({required this.raw, required this.category, required this.source, required this.similarNews, required this.inAppReadable});
  final Map<String, dynamic> raw;
  final String category;
  final SourceInfo source;
  final List<dynamic> similarNews;
  final bool inAppReadable;

  factory NewsData.fromJson(Map<String, dynamic> json) => NewsData(
        raw: json,
        category: json['category']?.toString() ?? 'genel',
        source: SourceInfo.fromJson((json['sourceInfo'] as Map?)?.cast<String, dynamic>() ?? json),
        similarNews: json['similarNews'] as List? ?? const [],
        inAppReadable: json['inAppReadable'] == true,
      );
}

class OpportunityData {
  const OpportunityData({required this.raw, required this.store, required this.category, this.price, required this.active, required this.source});
  final Map<String, dynamic> raw;
  final String store;
  final String category;
  final num? price;
  final bool active;
  final SourceInfo source;

  factory OpportunityData.fromJson(Map<String, dynamic> json) => OpportunityData(
        raw: json,
        store: json['store']?.toString() ?? '',
        category: json['category']?.toString() ?? 'genel',
        price: json['price'] as num?,
        active: json['active'] != false,
        source: SourceInfo.fromJson((json['sourceInfo'] as Map?)?.cast<String, dynamic>() ?? json),
      );
}
