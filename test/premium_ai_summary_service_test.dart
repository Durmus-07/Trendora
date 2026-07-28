import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trendora_app/core/auth/premium_status_service.dart';
import 'package:trendora_app/core/auth/trendora_auth_service.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';
import 'package:trendora_app/core/feature_flags.dart';
import 'package:trendora_app/core/premium_ai/premium_ai_summary_service.dart';

class _FakeAuthService implements TrendoraAuthGateway {
  _FakeAuthService({
    this.user = const TrendoraAuthUser(
      uid: 'firebase-user',
      email: 'beta@trendora.test',
    ),
    this.token = 'firebase-token',
  });

  final TrendoraAuthUser? user;
  final String? token;
  int tokenCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  TrendoraAuthUser? get currentUser => user;

  @override
  Stream<TrendoraAuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    tokenCalls += 1;
    return token;
  }

  @override
  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

class _FakePremiumStatus implements PremiumStatusGateway {
  _FakePremiumStatus(this.result);

  final PremiumVerificationResult result;
  int calls = 0;

  @override
  Future<PremiumVerificationResult> verify(
    TrendoraAuthGateway authService,
  ) async {
    calls += 1;
    return result;
  }
}

const _verified = PremiumVerificationResult(
  status: PremiumVerificationStatus.verified,
  httpStatus: 200,
);

void main() {
  final now = DateTime.utc(2026, 7, 28, 12);

  test('disabled Premium summary flag performs no network request', () async {
    var getCalls = 0;
    var postCalls = 0;
    final premium = _FakePremiumStatus(_verified);
    final service = PremiumAiSummaryService(
      enabled: false,
      authService: _FakeAuthService(),
      premiumStatusService: premium,
      getRequest: (uri, {headers}) async {
        getCalls += 1;
        return http.Response('{}', 200);
      },
      postRequest: (uri, {headers, body}) async {
        postCalls += 1;
        return http.Response('{}', 200);
      },
    );

    expect(
      await service.loadAvailability(),
      PremiumAiFeatureAvailability.disabled,
    );
    final result = await service.generate(_snapshot(now));
    expect(result.status, PremiumAiSummaryStatus.disabled);
    expect(result.errorCode, 'AI_DISABLED');
    expect(getCalls, 0);
    expect(postCalls, 0);
    expect(premium.calls, 0);
  });

  test('compile-time Premium summary flag controls availability', () async {
    var getCalls = 0;
    final service = PremiumAiSummaryService(
      getRequest: (uri, {headers}) async {
        getCalls += 1;
        return http.Response(
          '{"success":true,"features":{"premiumAiSummary":{"enabled":true}}}',
          200,
        );
      },
    );

    final availability = await service.loadAvailability();
    expect(
      availability,
      FeatureFlags.premiumAiSummaryEnabled
          ? PremiumAiFeatureAvailability.enabled
          : PremiumAiFeatureAvailability.disabled,
    );
    expect(getCalls, FeatureFlags.premiumAiSummaryEnabled ? 1 : 0);
  });

  test('feature availability uses the backend flag and short cache', () async {
    var getCalls = 0;
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(),
      premiumStatusService: _FakePremiumStatus(_verified),
      now: () => now,
      getRequest: (uri, {headers}) async {
        getCalls += 1;
        expect(
          uri.toString(),
          'https://trendora-icj9.onrender.com/api/features',
        );
        return http.Response(
          '{"success":true,"features":{"premiumAiSummary":{"enabled":false}}}',
          200,
        );
      },
    );

    expect(
      await service.loadAvailability(),
      PremiumAiFeatureAvailability.disabled,
    );
    expect(
      await service.loadAvailability(),
      PremiumAiFeatureAvailability.disabled,
    );
    expect(getCalls, 1);
  });

  test('verified Premium request sends only bounded digest data', () async {
    final auth = _FakeAuthService();
    final premium = _FakePremiumStatus(_verified);
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    String? requestedBody;
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: auth,
      premiumStatusService: premium,
      now: () => now,
      postRequest: (uri, {headers, body}) async {
        requestedUri = uri;
        requestedHeaders = headers;
        requestedBody = '$body';
        return http.Response(
          _successBody(),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      },
    );

    final result = await service.generate(_snapshot(now));

    expect(result.status, PremiumAiSummaryStatus.success);
    expect(result.summary?.title, 'Günün özeti');
    expect(result.summary?.cached, isTrue);
    expect(premium.calls, 1);
    expect(auth.tokenCalls, 1);
    expect(
      requestedUri.toString(),
      'https://trendora-icj9.onrender.com/api/premium/ai-summary',
    );
    expect(requestedHeaders?['Authorization'], 'Bearer firebase-token');
    final body = jsonDecode(requestedBody!) as Map<String, dynamic>;
    expect(body.keys, ['digest']);
    expect(requestedBody, isNot(contains('firebase-user')));
    expect(requestedBody, isNot(contains('beta@trendora.test')));
    expect(requestedBody, isNot(contains('firebase-token')));
    expect(requestedBody, isNot(contains('userId')));
    expect(requestedBody, isNot(contains('reference')));
  });

  test('guest user never verifies Premium or sends an AI request', () async {
    var postCalls = 0;
    final premium = _FakePremiumStatus(_verified);
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(user: null),
      premiumStatusService: premium,
      postRequest: (uri, {headers, body}) async {
        postCalls += 1;
        return http.Response('{}', 200);
      },
    );

    final result = await service.generate(_snapshot(now));

    expect(result.status, PremiumAiSummaryStatus.unauthorized);
    expect(premium.calls, 0);
    expect(postCalls, 0);
  });

  test('non-Premium user never sends an AI request', () async {
    var postCalls = 0;
    final premium = _FakePremiumStatus(
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.notPremium,
        httpStatus: 403,
      ),
    );
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(),
      premiumStatusService: premium,
      postRequest: (uri, {headers, body}) async {
        postCalls += 1;
        return http.Response('{}', 200);
      },
    );

    final result = await service.generate(_snapshot(now));

    expect(result.status, PremiumAiSummaryStatus.notPremium);
    expect(postCalls, 0);
  });

  test('missing ID token never sends an AI request', () async {
    var postCalls = 0;
    final auth = _FakeAuthService(token: null);
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: auth,
      premiumStatusService: _FakePremiumStatus(_verified),
      postRequest: (uri, {headers, body}) async {
        postCalls += 1;
        return http.Response('{}', 200);
      },
    );

    final result = await service.generate(_snapshot(now));

    expect(result.status, PremiumAiSummaryStatus.unauthorized);
    expect(auth.tokenCalls, 1);
    expect(postCalls, 0);
  });

  test('unsupported digest categories never send an AI request', () async {
    var postCalls = 0;
    final premium = _FakePremiumStatus(_verified);
    final service = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(),
      premiumStatusService: premium,
      postRequest: (uri, {headers, body}) async {
        postCalls += 1;
        return http.Response('{}', 200);
      },
    );
    final snapshot = DailyDigestSnapshot(
      userId: 'guest:local',
      slotKey: 'slot',
      generatedAt: now,
      items: [
        DailyDigestItem(
          id: 'payment',
          category: DailyDigestCategory.payments,
          title: 'Ödeme',
          detail: 'Gerçek depo bulunmuyor',
          source: 'Yerel',
          updatedAt: now,
          reference: 'payment',
        ),
      ],
    );

    final result = await service.generate(snapshot);

    expect(result.status, PremiumAiSummaryStatus.insufficientData);
    expect(premium.calls, 0);
    expect(postCalls, 0);
  });

  for (final testCase in <(int, String, PremiumAiSummaryStatus)>[
    (401, 'INVALID_TOKEN', PremiumAiSummaryStatus.unauthorized),
    (403, 'PREMIUM_REQUIRED', PremiumAiSummaryStatus.notPremium),
    (422, 'INSUFFICIENT_DATA', PremiumAiSummaryStatus.insufficientData),
    (429, 'RATE_LIMITED', PremiumAiSummaryStatus.rateLimited),
    (429, 'AI_QUOTA_EXCEEDED', PremiumAiSummaryStatus.quotaExceeded),
    (503, 'AI_DISABLED', PremiumAiSummaryStatus.disabled),
    (503, 'AI_NOT_CONFIGURED', PremiumAiSummaryStatus.notConfigured),
    (504, 'AI_TIMEOUT', PremiumAiSummaryStatus.timeout),
    (502, 'INVALID_AI_RESPONSE', PremiumAiSummaryStatus.invalidResponse),
  ]) {
    test('HTTP ${testCase.$1} ${testCase.$2} maps safely', () async {
      final service = PremiumAiSummaryService(
        enabled: true,
        authService: _FakeAuthService(),
        premiumStatusService: _FakePremiumStatus(_verified),
        postRequest: (uri, {headers, body}) async => http.Response(
          jsonEncode({'success': false, 'code': testCase.$2}),
          testCase.$1,
        ),
      );

      final result = await service.generate(_snapshot(now));

      expect(result.status, testCase.$3);
      expect(result.httpStatus, testCase.$1);
      expect(result.errorCode, testCase.$2);
    });
  }

  test('network and malformed success responses remain safe', () async {
    final network = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(),
      premiumStatusService: _FakePremiumStatus(_verified),
      postRequest: (uri, {headers, body}) async => throw StateError('offline'),
    );
    final malformed = PremiumAiSummaryService(
      enabled: true,
      authService: _FakeAuthService(),
      premiumStatusService: _FakePremiumStatus(_verified),
      postRequest: (uri, {headers, body}) async =>
          http.Response('{"success":true,"summary":{}}', 200),
    );

    expect(
      (await network.generate(_snapshot(now))).status,
      PremiumAiSummaryStatus.networkError,
    );
    expect(
      (await malformed.generate(_snapshot(now))).status,
      PremiumAiSummaryStatus.invalidResponse,
    );
  });
}

DailyDigestSnapshot _snapshot(DateTime now) {
  return DailyDigestSnapshot(
    userId: 'guest:must-not-be-sent',
    slotKey: 'slot',
    generatedAt: now,
    items: [
      DailyDigestItem(
        id: 'news-1',
        category: DailyDigestCategory.news,
        title: 'Güncel haber',
        detail: 'Kaynaklı açıklama',
        source: 'Haber Kaynağı',
        updatedAt: now.subtract(const Duration(minutes: 10)),
        reference: 'private-reference',
      ),
    ],
  );
}

String _successBody() {
  return jsonEncode({
    'success': true,
    'summary': {
      'title': 'Günün özeti',
      'summary': 'Güncel veriler doğrulandı.',
      'highlights': ['Önemli gelişme'],
      'risks': ['Koşullar değişebilir'],
      'sources': ['Haber Kaynağı'],
      'generatedAt': '2026-07-28T12:00:00.000Z',
      'dataUpdatedAt': '2026-07-28T11:50:00.000Z',
      'cached': true,
      'aiGenerated': true,
      'disclaimer': null,
    },
  });
}
