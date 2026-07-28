import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trendora_app/core/auth/premium_status_service.dart';
import 'package:trendora_app/core/auth/trendora_auth_service.dart';

class _FakeAuthService implements TrendoraAuthGateway {
  _FakeAuthService({
    this.user = const TrendoraAuthUser(
      uid: 'firebase-beta-user',
      email: 'beta@trendora.test',
    ),
    this.token = 'firebase-id-token',
  });

  final TrendoraAuthUser? user;
  final String? token;
  bool? lastForceRefresh;

  @override
  bool get isAvailable => true;

  @override
  TrendoraAuthUser? get currentUser => user;

  @override
  Stream<TrendoraAuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    lastForceRefresh = forceRefresh;
    return token;
  }

  @override
  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }
}

void main() {
  test('200 verifies Premium with a force-refreshed bearer token', () async {
    final auth = _FakeAuthService();
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    final service = PremiumStatusService(
      request: (uri, {headers}) async {
        requestedUri = uri;
        requestedHeaders = headers;
        return http.Response(
          '{"success":true,"authenticated":true,"premium":true}',
          200,
        );
      },
    );

    final result = await service.verify(auth);

    expect(result.status, PremiumVerificationStatus.verified);
    expect(result.httpStatus, 200);
    expect(auth.lastForceRefresh, isTrue);
    expect(
      requestedUri.toString(),
      'https://trendora-icj9.onrender.com/api/premium/status',
    );
    expect(requestedHeaders?['Authorization'], 'Bearer firebase-id-token');
  });

  test('403 PREMIUM_REQUIRED reports missing Premium permission', () async {
    final service = PremiumStatusService(
      request: (_, {headers}) async =>
          http.Response('{"code":"PREMIUM_REQUIRED"}', 403),
    );

    final result = await service.verify(_FakeAuthService());

    expect(result.status, PremiumVerificationStatus.notPremium);
    expect(result.httpStatus, 403);
    expect(result.errorCode, 'PREMIUM_REQUIRED');
  });

  test('401 reports an unauthorized session', () async {
    final service = PremiumStatusService(
      request: (_, {headers}) async =>
          http.Response('{"code":"INVALID_TOKEN"}', 401),
    );

    final result = await service.verify(_FakeAuthService());

    expect(result.status, PremiumVerificationStatus.unauthorized);
    expect(result.httpStatus, 401);
    expect(result.errorCode, 'INVALID_TOKEN');
  });

  test('200 without verified Premium fields is an invalid response', () async {
    final service = PremiumStatusService(
      request: (_, {headers}) async =>
          http.Response('{"success":true,"premium":false}', 200),
    );

    final result = await service.verify(_FakeAuthService());

    expect(result.status, PremiumVerificationStatus.invalidResponse);
    expect(result.httpStatus, 200);
  });

  test('server and network errors remain safely unavailable', () async {
    final serverService = PremiumStatusService(
      request: (_, {headers}) async => http.Response('{}', 503),
    );
    final networkService = PremiumStatusService(
      request: (_, {headers}) async => throw Exception('offline'),
    );

    expect(
      (await serverService.verify(_FakeAuthService())).status,
      PremiumVerificationStatus.networkError,
    );
    expect(
      (await networkService.verify(_FakeAuthService())).status,
      PremiumVerificationStatus.networkError,
    );
  });

  test('missing refreshed token does not send a Premium request', () async {
    var requestCount = 0;
    final auth = _FakeAuthService(token: null);
    final service = PremiumStatusService(
      request: (_, {headers}) async {
        requestCount += 1;
        return http.Response('{}', 200);
      },
    );

    final result = await service.verify(auth);

    expect(result.status, PremiumVerificationStatus.tokenUnavailable);
    expect(auth.lastForceRefresh, isTrue);
    expect(requestCount, 0);
  });

  test('guest user does not send a Premium request', () async {
    var requestCount = 0;
    final service = PremiumStatusService(
      request: (_, {headers}) async {
        requestCount += 1;
        return http.Response('{}', 200);
      },
    );

    final result = await service.verify(_FakeAuthService(user: null));

    expect(result.status, PremiumVerificationStatus.unauthorized);
    expect(requestCount, 0);
  });
}
