import '../daily_digest/daily_digest_models.dart';
import 'interest_catalog.dart';

class PersonalizationPreferences {
  const PersonalizationPreferences({
    required this.userId,
    required this.personalizationEnabled,
    required this.interests,
    required this.trackedFinancialAssets,
    required this.followedNewsCategories,
    required this.followedOpportunityCategories,
    required this.followedWeatherLocations,
    required this.savedAnalysisIds,
    required this.savedNewsIds,
    required this.savedOpportunityIds,
    required this.notificationCategories,
    required this.dailyDigestEnabled,
    required this.digestTime,
    required this.digestPeriod,
    required this.digestCategories,
    required this.language,
    required this.updatedAt,
    required this.modelVersion,
  });

  static const int currentModelVersion = 1;

  final String userId;
  final bool personalizationEnabled;
  final Set<String> interests;
  final Set<String> trackedFinancialAssets;
  final Set<String> followedNewsCategories;
  final Set<String> followedOpportunityCategories;
  final Set<String> followedWeatherLocations;
  final Set<String> savedAnalysisIds;
  final Set<String> savedNewsIds;
  final Set<String> savedOpportunityIds;
  final Set<String> notificationCategories;
  final bool dailyDigestEnabled;
  final String digestTime;
  final DailyDigestPeriod digestPeriod;
  final Set<DailyDigestCategory> digestCategories;
  final String language;
  final DateTime updatedAt;
  final int modelVersion;

  factory PersonalizationPreferences.defaults({
    required String userId,
    DateTime? now,
    Iterable<String> savedAnalysisIds = const [],
    Iterable<String> trackedFinancialAssets = const [],
  }) {
    return PersonalizationPreferences(
      userId: userId,
      personalizationEnabled: false,
      interests: const {},
      trackedFinancialAssets: Set.unmodifiable(trackedFinancialAssets),
      followedNewsCategories: const {},
      followedOpportunityCategories: const {},
      followedWeatherLocations: const {},
      savedAnalysisIds: Set.unmodifiable(savedAnalysisIds),
      savedNewsIds: const {},
      savedOpportunityIds: const {},
      notificationCategories: const {},
      dailyDigestEnabled: false,
      digestTime: '09:00',
      digestPeriod: DailyDigestPeriod.morning,
      digestCategories: Set.unmodifiable(DailyDigestCategory.values),
      language: 'tr',
      updatedAt: (now ?? DateTime.now()).toUtc(),
      modelVersion: currentModelVersion,
    );
  }

  factory PersonalizationPreferences.fromJson(
    Map<String, dynamic> json, {
    required String fallbackUserId,
    DateTime? now,
  }) {
    final parsedUserId = json['userId']?.toString().trim() ?? '';
    return PersonalizationPreferences(
      userId: parsedUserId.isEmpty ? fallbackUserId : parsedUserId,
      personalizationEnabled: json['personalizationEnabled'] == true,
      interests: Set.unmodifiable(
        _strings(json['interests']).where(TrendoraInterestCatalog.contains),
      ),
      trackedFinancialAssets: Set.unmodifiable(
        _strings(json['trackedFinancialAssets']),
      ),
      followedNewsCategories: Set.unmodifiable(
        _strings(json['followedNewsCategories']),
      ),
      followedOpportunityCategories: Set.unmodifiable(
        _strings(json['followedOpportunityCategories']),
      ),
      followedWeatherLocations: Set.unmodifiable(
        _strings(json['followedWeatherLocations']),
      ),
      savedAnalysisIds: Set.unmodifiable(_strings(json['savedAnalysisIds'])),
      savedNewsIds: Set.unmodifiable(_strings(json['savedNewsIds'])),
      savedOpportunityIds: Set.unmodifiable(
        _strings(json['savedOpportunityIds']),
      ),
      notificationCategories: Set.unmodifiable(
        _strings(json['notificationCategories']),
      ),
      dailyDigestEnabled: json['dailyDigestEnabled'] == true,
      digestTime: _validTime(json['digestTime']?.toString()),
      digestPeriod: dailyDigestPeriodFromName(
        json['digestPeriod']?.toString(),
        fallback: _periodForTime(_validTime(json['digestTime']?.toString())),
      ),
      digestCategories: dailyDigestCategoriesFromNames(
        json['digestCategories'],
      ),
      language: _nonEmpty(json['language']?.toString(), 'tr'),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          (now ?? DateTime.now()).toUtc(),
      modelVersion: _positiveInt(json['modelVersion']) ?? currentModelVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'personalizationEnabled': personalizationEnabled,
    'interests': interests.toList()..sort(),
    'trackedFinancialAssets': trackedFinancialAssets.toList()..sort(),
    'followedNewsCategories': followedNewsCategories.toList()..sort(),
    'followedOpportunityCategories': followedOpportunityCategories.toList()
      ..sort(),
    'followedWeatherLocations': followedWeatherLocations.toList()..sort(),
    'savedAnalysisIds': savedAnalysisIds.toList()..sort(),
    'savedNewsIds': savedNewsIds.toList()..sort(),
    'savedOpportunityIds': savedOpportunityIds.toList()..sort(),
    'notificationCategories': notificationCategories.toList()..sort(),
    'dailyDigestEnabled': dailyDigestEnabled,
    'digestTime': digestTime,
    'digestPeriod': digestPeriod.name,
    'digestCategories': digestCategories.map((item) => item.name).toList()
      ..sort(),
    'language': language,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'modelVersion': modelVersion,
  };

  PersonalizationPreferences copyWith({
    bool? personalizationEnabled,
    Set<String>? interests,
    Set<String>? trackedFinancialAssets,
    Set<String>? followedNewsCategories,
    Set<String>? followedOpportunityCategories,
    Set<String>? followedWeatherLocations,
    Set<String>? savedAnalysisIds,
    Set<String>? savedNewsIds,
    Set<String>? savedOpportunityIds,
    Set<String>? notificationCategories,
    bool? dailyDigestEnabled,
    String? digestTime,
    DailyDigestPeriod? digestPeriod,
    Set<DailyDigestCategory>? digestCategories,
    String? language,
    DateTime? updatedAt,
  }) {
    return PersonalizationPreferences(
      userId: userId,
      personalizationEnabled:
          personalizationEnabled ?? this.personalizationEnabled,
      interests: Set.unmodifiable(interests ?? this.interests),
      trackedFinancialAssets: Set.unmodifiable(
        trackedFinancialAssets ?? this.trackedFinancialAssets,
      ),
      followedNewsCategories: Set.unmodifiable(
        followedNewsCategories ?? this.followedNewsCategories,
      ),
      followedOpportunityCategories: Set.unmodifiable(
        followedOpportunityCategories ?? this.followedOpportunityCategories,
      ),
      followedWeatherLocations: Set.unmodifiable(
        followedWeatherLocations ?? this.followedWeatherLocations,
      ),
      savedAnalysisIds: Set.unmodifiable(
        savedAnalysisIds ?? this.savedAnalysisIds,
      ),
      savedNewsIds: Set.unmodifiable(savedNewsIds ?? this.savedNewsIds),
      savedOpportunityIds: Set.unmodifiable(
        savedOpportunityIds ?? this.savedOpportunityIds,
      ),
      notificationCategories: Set.unmodifiable(
        notificationCategories ?? this.notificationCategories,
      ),
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      digestTime: digestTime == null ? this.digestTime : _validTime(digestTime),
      digestPeriod: digestPeriod ?? this.digestPeriod,
      digestCategories: Set.unmodifiable(
        digestCategories ?? this.digestCategories,
      ),
      language: language == null ? this.language : _nonEmpty(language, 'tr'),
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
      modelVersion: currentModelVersion,
    );
  }

  static Iterable<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty);
  }

  static int? _positiveInt(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String _validTime(String? value) {
    final candidate = value?.trim() ?? '';
    return RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(candidate)
        ? candidate
        : '09:00';
  }

  static DailyDigestPeriod _periodForTime(String value) {
    final hour = int.tryParse(value.split(':').first) ?? 9;
    return hour >= 15
        ? DailyDigestPeriod.evening
        : DailyDigestPeriod.morning;
  }

  static String _nonEmpty(String? value, String fallback) {
    final candidate = value?.trim() ?? '';
    return candidate.isEmpty ? fallback : candidate;
  }
}
