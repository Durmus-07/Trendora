import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../auth/premium_status_service.dart';
import '../auth/trendora_auth_service.dart';
import '../daily_digest/daily_digest_models.dart';
import '../feature_flags.dart';

enum PremiumAiFeatureAvailability { enabled, disabled, unavailable }

enum PremiumAiSummaryStatus {
  success,
  unauthorized,
  notPremium,
  disabled,
  notConfigured,
  insufficientData,
  rateLimited,
  quotaExceeded,
  timeout,
  invalidResponse,
  networkError,
}

class PremiumAiSummary {
  const PremiumAiSummary({
    required this.title,
    required this.summary,
    required this.highlights,
    required this.risks,
    required this.sources,
    required this.generatedAt,
    required this.dataUpdatedAt,
    required this.cached,
    required this.aiGenerated,
    this.disclaimer,
  });

  final String title;
  final String summary;
  final List<String> highlights;
  final List<String> risks;
  final List<String> sources;
  final DateTime generatedAt;
  final DateTime dataUpdatedAt;
  final bool cached;
  final bool aiGenerated;
  final String? disclaimer;

  factory PremiumAiSummary.fromJson(Map<String, dynamic> json) {
    final title = '${json['title'] ?? ''}'.trim();
    final summary = '${json['summary'] ?? ''}'.trim();
    final generatedAt = DateTime.tryParse('${json['generatedAt'] ?? ''}');
    final dataUpdatedAt = DateTime.tryParse('${json['dataUpdatedAt'] ?? ''}');
    final sources = _stringList(json['sources']);
    if (title.isEmpty ||
        summary.isEmpty ||
        generatedAt == null ||
        dataUpdatedAt == null ||
        sources.isEmpty ||
        json['aiGenerated'] != true) {
      throw const FormatException('Geçersiz Premium AI özeti');
    }
    return PremiumAiSummary(
      title: title,
      summary: summary,
      highlights: _stringList(json['highlights']),
      risks: _stringList(json['risks']),
      sources: sources,
      generatedAt: generatedAt.toUtc(),
      dataUpdatedAt: dataUpdatedAt.toUtc(),
      cached: json['cached'] == true,
      aiGenerated: true,
      disclaimer: '${json['disclaimer'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['disclaimer']}'.trim(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return List.unmodifiable(
      value.map((item) => '$item'.trim()).where((item) => item.isNotEmpty),
    );
  }
}

class PremiumAiSummaryResult {
  const PremiumAiSummaryResult({
    required this.status,
    this.summary,
    this.httpStatus,
    this.errorCode,
  });

  final PremiumAiSummaryStatus status;
  final PremiumAiSummary? summary;
  final int? httpStatus;
  final String? errorCode;
}

abstract interface class PremiumAiSummaryGateway {
  Future<PremiumAiFeatureAvailability> loadAvailability();

  Future<PremiumAiSummaryResult> generate(DailyDigestSnapshot snapshot);
}

typedef PremiumAiGetRequest =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});
typedef PremiumAiPostRequest =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });

class PremiumAiSummaryService implements PremiumAiSummaryGateway {
  PremiumAiSummaryService({
    TrendoraAuthGateway? authService,
    PremiumStatusGateway? premiumStatusService,
    PremiumAiGetRequest? getRequest,
    PremiumAiPostRequest? postRequest,
    DateTime Function()? now,
    bool? enabled,
  }) : _authService = authService ?? TrendoraAuthService.instance,
       _premiumStatusService = premiumStatusService ?? PremiumStatusService(),
       _getRequest = getRequest ?? http.get,
       _postRequest =
           postRequest ??
           ((uri, {headers, body}) =>
               http.post(uri, headers: headers, body: body)),
       _now = now ?? DateTime.now,
       _enabled = enabled ?? FeatureFlags.premiumAiSummaryEnabled;

  static final Uri _featuresEndpoint = Uri.parse(
    '${ApiConfig.baseUrl}/api/features',
  );
  static final Uri _summaryEndpoint = Uri.parse(
    '${ApiConfig.baseUrl}/api/premium/ai-summary',
  );
  static const Duration _availabilityCacheTtl = Duration(minutes: 5);
  static const Set<DailyDigestCategory> _allowedCategories = {
    DailyDigestCategory.finance,
    DailyDigestCategory.news,
    DailyDigestCategory.opportunities,
    DailyDigestCategory.weather,
    DailyDigestCategory.savedAnalyses,
  };

  final TrendoraAuthGateway _authService;
  final PremiumStatusGateway _premiumStatusService;
  final PremiumAiGetRequest _getRequest;
  final PremiumAiPostRequest _postRequest;
  final DateTime Function() _now;
  final bool _enabled;

  PremiumAiFeatureAvailability? _availability;
  DateTime? _availabilityCheckedAt;
  Future<PremiumAiFeatureAvailability>? _availabilityRequest;

  @override
  Future<PremiumAiFeatureAvailability> loadAvailability() {
    if (!_enabled) {
      return Future.value(PremiumAiFeatureAvailability.disabled);
    }
    final checkedAt = _availabilityCheckedAt;
    final cached = _availability;
    if (cached != null &&
        checkedAt != null &&
        _now().difference(checkedAt) < _availabilityCacheTtl) {
      return Future.value(cached);
    }
    final pending = _availabilityRequest;
    if (pending != null) return pending;

    final request = _loadAvailability();
    _availabilityRequest = request;
    return request.whenComplete(() => _availabilityRequest = null);
  }

  Future<PremiumAiFeatureAvailability> _loadAvailability() async {
    try {
      final response = await _getRequest(
        _featuresEndpoint,
        headers: const {'Accept': 'application/json'},
      ).timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200) {
        return _remember(PremiumAiFeatureAvailability.unavailable);
      }
      final body = _map(response.body);
      final features = body?['features'];
      final premiumAiSummary = features is Map
          ? features['premiumAiSummary']
          : null;
      if (premiumAiSummary is! Map ||
          premiumAiSummary['enabled'] is! bool) {
        return _remember(PremiumAiFeatureAvailability.unavailable);
      }
      return _remember(
        premiumAiSummary['enabled'] == true
            ? PremiumAiFeatureAvailability.enabled
            : PremiumAiFeatureAvailability.disabled,
      );
    } catch (_) {
      return _remember(PremiumAiFeatureAvailability.unavailable);
    }
  }

  PremiumAiFeatureAvailability _remember(
    PremiumAiFeatureAvailability availability,
  ) {
    _availability = availability;
    _availabilityCheckedAt = _now();
    return availability;
  }

  @override
  Future<PremiumAiSummaryResult> generate(DailyDigestSnapshot snapshot) async {
    if (!_enabled) {
      return const PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.disabled,
        errorCode: 'AI_DISABLED',
      );
    }
    final items = snapshot.items
        .where((item) => _allowedCategories.contains(item.category))
        .toList(growable: false);
    if (items.isEmpty) {
      return const PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.insufficientData,
      );
    }
    if (_authService.currentUser == null) {
      return const PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.unauthorized,
      );
    }

    final premium = await _premiumStatusService.verify(_authService);
    switch (premium.status) {
      case PremiumVerificationStatus.verified:
        break;
      case PremiumVerificationStatus.notPremium:
        return const PremiumAiSummaryResult(
          status: PremiumAiSummaryStatus.notPremium,
          httpStatus: 403,
          errorCode: 'PREMIUM_REQUIRED',
        );
      case PremiumVerificationStatus.unauthorized:
      case PremiumVerificationStatus.tokenUnavailable:
        return const PremiumAiSummaryResult(
          status: PremiumAiSummaryStatus.unauthorized,
          httpStatus: 401,
        );
      case PremiumVerificationStatus.idle:
      case PremiumVerificationStatus.checking:
      case PremiumVerificationStatus.networkError:
      case PremiumVerificationStatus.invalidResponse:
        return const PremiumAiSummaryResult(
          status: PremiumAiSummaryStatus.networkError,
        );
    }

    final token = await _authService.getIdToken();
    if (token == null || token.trim().isEmpty) {
      return const PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.unauthorized,
        httpStatus: 401,
      );
    }

    try {
      final response = await _postRequest(
        _summaryEndpoint,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'digest': {
            'generatedAt': snapshot.generatedAt.toUtc().toIso8601String(),
            'items': items
                .map(
                  (item) => {
                    'category': item.category.name,
                    'title': item.title,
                    'detail': item.detail,
                    'source': item.source,
                    'updatedAt': item.updatedAt.toUtc().toIso8601String(),
                  },
                )
                .toList(growable: false),
          },
        }),
      ).timeout(ApiConfig.requestTimeout);
      return _parseResponse(response);
    } catch (_) {
      return const PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.networkError,
      );
    }
  }

  PremiumAiSummaryResult _parseResponse(http.Response response) {
    final body = _map(response.body);
    final code = '${body?['code'] ?? ''}'.trim();
    if (response.statusCode == 200) {
      try {
        final raw = body?['summary'];
        if (body?['success'] != true || raw is! Map) {
          throw const FormatException('Geçersiz cevap');
        }
        return PremiumAiSummaryResult(
          status: PremiumAiSummaryStatus.success,
          summary: PremiumAiSummary.fromJson(Map<String, dynamic>.from(raw)),
          httpStatus: 200,
        );
      } catch (_) {
        return const PremiumAiSummaryResult(
          status: PremiumAiSummaryStatus.invalidResponse,
          httpStatus: 200,
        );
      }
    }
    final status = switch ((response.statusCode, code)) {
      (401, _) => PremiumAiSummaryStatus.unauthorized,
      (403, _) => PremiumAiSummaryStatus.notPremium,
      (422, _) => PremiumAiSummaryStatus.insufficientData,
      (429, 'AI_QUOTA_EXCEEDED') => PremiumAiSummaryStatus.quotaExceeded,
      (429, _) => PremiumAiSummaryStatus.rateLimited,
      (503, 'AI_DISABLED') => PremiumAiSummaryStatus.disabled,
      (503, 'AI_NOT_CONFIGURED') => PremiumAiSummaryStatus.notConfigured,
      (504, _) => PremiumAiSummaryStatus.timeout,
      (502, _) => PremiumAiSummaryStatus.invalidResponse,
      _ => PremiumAiSummaryStatus.networkError,
    };
    return PremiumAiSummaryResult(
      status: status,
      httpStatus: response.statusCode,
      errorCode: code.isEmpty ? null : code,
    );
  }

  static Map<String, dynamic>? _map(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
