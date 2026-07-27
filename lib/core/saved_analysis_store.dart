import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedAnalysis {
  final String id;
  final String query;
  final String title;
  final DateTime savedAt;
  final double? startingPrice;
  final String currency;
  final int confidence;
  final String dominantScenario;
  final int dominantProbability;
  final String expectedDirection;
  final double? latestPrice;
  final DateTime? checkedAt;
  final bool? directionMatched;

  const SavedAnalysis({
    required this.id,
    required this.query,
    required this.title,
    required this.savedAt,
    required this.startingPrice,
    required this.currency,
    required this.confidence,
    required this.dominantScenario,
    required this.dominantProbability,
    required this.expectedDirection,
    this.latestPrice,
    this.checkedAt,
    this.directionMatched,
  });

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) => SavedAnalysis(
        id: json['id']?.toString() ?? '',
        query: json['query']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
            DateTime.now(),
        startingPrice: (json['startingPrice'] as num?)?.toDouble(),
        currency: json['currency']?.toString() ?? 'TRY',
        confidence: (json['confidence'] as num?)?.round() ?? 0,
        dominantScenario: json['dominantScenario']?.toString() ?? '',
        dominantProbability:
            (json['dominantProbability'] as num?)?.round() ?? 0,
        expectedDirection: json['expectedDirection']?.toString() ?? 'neutral',
        latestPrice: (json['latestPrice'] as num?)?.toDouble(),
        checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? ''),
        directionMatched: json['directionMatched'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'startingPrice': startingPrice,
        'currency': currency,
        'confidence': confidence,
        'dominantScenario': dominantScenario,
        'dominantProbability': dominantProbability,
        'expectedDirection': expectedDirection,
        'latestPrice': latestPrice,
        'checkedAt': checkedAt?.toIso8601String(),
        'directionMatched': directionMatched,
      };

  SavedAnalysis withOutcome({
    required double latestPrice,
    required DateTime checkedAt,
    required bool directionMatched,
  }) =>
      SavedAnalysis(
        id: id,
        query: query,
        title: title,
        savedAt: savedAt,
        startingPrice: startingPrice,
        currency: currency,
        confidence: confidence,
        dominantScenario: dominantScenario,
        dominantProbability: dominantProbability,
        expectedDirection: expectedDirection,
        latestPrice: latestPrice,
        checkedAt: checkedAt,
        directionMatched: directionMatched,
      );
}

class SavedAnalysisStore {
  SavedAnalysisStore._();

  static const _key = 'trendora_saved_analyses_v1';

  static Future<List<SavedAnalysis>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => SavedAnalysis.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty && item.query.isNotEmpty)
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<SavedAnalysis> items) async {
    final preferences = await SharedPreferences.getInstance();
    final limited = items.take(100).map((item) => item.toJson()).toList();
    await preferences.setString(_key, jsonEncode(limited));
  }
}
