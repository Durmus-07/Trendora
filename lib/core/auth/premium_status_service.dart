import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'trendora_auth_service.dart';

enum PremiumVerificationStatus {
  idle,
  checking,
  verified,
  notPremium,
  unauthorized,
  tokenUnavailable,
  networkError,
  invalidResponse,
}

class PremiumVerificationResult {
  const PremiumVerificationResult({
    required this.status,
    this.httpStatus,
    this.errorCode,
  });

  final PremiumVerificationStatus status;
  final int? httpStatus;
  final String? errorCode;
}

abstract class PremiumStatusGateway {
  Future<PremiumVerificationResult> verify(TrendoraAuthGateway authService);
}

typedef PremiumStatusRequest =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

class PremiumStatusService implements PremiumStatusGateway {
  PremiumStatusService({PremiumStatusRequest? request})
    : _request = request ?? http.get;

  final PremiumStatusRequest _request;

  static final Uri _endpoint = Uri.parse(
    '${ApiConfig.baseUrl}/api/premium/status',
  );

  @override
  Future<PremiumVerificationResult> verify(
    TrendoraAuthGateway authService,
  ) async {
    if (authService.currentUser == null) {
      return const PremiumVerificationResult(
        status: PremiumVerificationStatus.unauthorized,
      );
    }

    try {
      final token = await authService.getIdToken(forceRefresh: true);
      if (token == null || token.trim().isEmpty) {
        return const PremiumVerificationResult(
          status: PremiumVerificationStatus.tokenUnavailable,
        );
      }

      final response = await _request(
        _endpoint,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = _responseMap(response.body);
        if (body?['success'] == true &&
            body?['authenticated'] == true &&
            body?['premium'] == true) {
          return const PremiumVerificationResult(
            status: PremiumVerificationStatus.verified,
            httpStatus: 200,
          );
        }
        return const PremiumVerificationResult(
          status: PremiumVerificationStatus.invalidResponse,
          httpStatus: 200,
        );
      }
      if (response.statusCode == 401) {
        return PremiumVerificationResult(
          status: PremiumVerificationStatus.unauthorized,
          httpStatus: 401,
          errorCode: _safeErrorCode(_responseCode(response.body)),
        );
      }
      if (response.statusCode == 403 &&
          _responseCode(response.body) == 'PREMIUM_REQUIRED') {
        return const PremiumVerificationResult(
          status: PremiumVerificationStatus.notPremium,
          httpStatus: 403,
          errorCode: 'PREMIUM_REQUIRED',
        );
      }
      if (response.statusCode >= 500) {
        return PremiumVerificationResult(
          status: PremiumVerificationStatus.networkError,
          httpStatus: response.statusCode,
        );
      }
      return PremiumVerificationResult(
        status: PremiumVerificationStatus.invalidResponse,
        httpStatus: response.statusCode,
      );
    } catch (_) {
      return const PremiumVerificationResult(
        status: PremiumVerificationStatus.networkError,
      );
    }
  }

  static Map<String, dynamic>? _responseMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static String? _responseCode(String body) {
    return _responseMap(body)?['code']?.toString();
  }

  static String? _safeErrorCode(String? code) {
    return const {'AUTH_REQUIRED', 'INVALID_TOKEN'}.contains(code)
        ? code
        : null;
  }
}
