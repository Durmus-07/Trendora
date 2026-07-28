import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/auth/trendora_auth_service.dart';
import 'package:trendora_app/core/daily_digest/daily_digest_models.dart';
import 'package:trendora_app/core/premium_ai/premium_ai_summary_service.dart';
import 'package:trendora_app/theme/trendora_theme.dart';
import 'package:trendora_app/widgets/premium_ai_digest_section.dart';

class _FakePremiumAiService implements PremiumAiSummaryGateway {
  _FakePremiumAiService({
    this.availability = PremiumAiFeatureAvailability.enabled,
    this.result = const PremiumAiSummaryResult(
      status: PremiumAiSummaryStatus.networkError,
    ),
  });

  final PremiumAiFeatureAvailability availability;
  final PremiumAiSummaryResult result;
  int availabilityCalls = 0;
  int generateCalls = 0;

  @override
  Future<PremiumAiFeatureAvailability> loadAvailability() async {
    availabilityCalls += 1;
    return availability;
  }

  @override
  Future<PremiumAiSummaryResult> generate(DailyDigestSnapshot snapshot) async {
    generateCalls += 1;
    return result;
  }
}

class _FakeAuthService implements TrendoraAuthGateway {
  final _changes = StreamController<TrendoraAuthUser?>.broadcast();
  TrendoraAuthUser? _user = const TrendoraAuthUser(
    uid: 'firebase-user',
    email: 'beta@trendora.test',
  );

  void emit(TrendoraAuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  Future<void> dispose() => _changes.close();

  @override
  bool get isAvailable => true;

  @override
  TrendoraAuthUser? get currentUser => _user;

  @override
  Stream<TrendoraAuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'token';

  @override
  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

void main() {
  final now = DateTime.utc(2026, 7, 28, 12);

  testWidgets('disabled feature performs no availability or AI request', (
    tester,
  ) async {
    final service = _FakePremiumAiService();
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _app(service: service, auth: auth, snapshot: _snapshot(now)),
    );
    await tester.pump();

    expect(find.text('Premium Yapay Zekâ şu anda kapalı'), findsOneWidget);
    expect(service.availabilityCalls, 0);
    expect(service.generateCalls, 0);
  });

  testWidgets('backend-disabled AI stays closed without a generate action', (
    tester,
  ) async {
    final service = _FakePremiumAiService(
      availability: PremiumAiFeatureAvailability.disabled,
    );
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _app(
        service: service,
        auth: auth,
        snapshot: _snapshot(now),
        enabled: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium Yapay Zekâ şu anda kapalı'), findsOneWidget);
    expect(find.text('Özet oluştur'), findsNothing);
    expect(service.availabilityCalls, 1);
    expect(service.generateCalls, 0);
  });

  testWidgets('AI request starts only after the user taps create', (
    tester,
  ) async {
    final service = _FakePremiumAiService(
      result: PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.success,
        summary: _summary(now),
        httpStatus: 200,
      ),
    );
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _app(
        service: service,
        auth: auth,
        snapshot: _snapshot(now),
        enabled: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Özet oluştur'), findsOneWidget);
    expect(service.availabilityCalls, 1);
    expect(service.generateCalls, 0);

    await tester.tap(find.text('Özet oluştur'));
    await tester.pumpAndSettle();

    expect(service.generateCalls, 1);
    expect(find.text('Günün Premium özeti'), findsOneWidget);
    expect(find.text('Yapay zekâ yorumu'), findsOneWidget);
    expect(find.textContaining('Kaynaklar: Haber Kaynağı'), findsOneWidget);
    expect(find.textContaining('Önbellek'), findsOneWidget);
  });

  for (final testCase in <(PremiumAiSummaryStatus, String)>[
    (
      PremiumAiSummaryStatus.unauthorized,
      'Oturum doğrulanamadı. Hesabım bölümünden tekrar giriş yap.',
    ),
    (PremiumAiSummaryStatus.notPremium, 'Premium yetkisi bulunmuyor.'),
    (
      PremiumAiSummaryStatus.rateLimited,
      'Çok fazla istek gönderildi. Lütfen daha sonra tekrar dene.',
    ),
    (PremiumAiSummaryStatus.disabled, 'Premium Yapay Zekâ şu anda kapalı.'),
    (
      PremiumAiSummaryStatus.networkError,
      'Bağlantı kurulamadı. Ücretsiz özet kullanılabilir.',
    ),
  ]) {
    testWidgets('safe UI message is shown for ${testCase.$1.name}', (
      tester,
    ) async {
      final service = _FakePremiumAiService(
        result: PremiumAiSummaryResult(status: testCase.$1),
      );
      final auth = _FakeAuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _app(
          service: service,
          auth: auth,
          snapshot: _snapshot(now),
          enabled: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Özet oluştur'));
      await tester.pumpAndSettle();

      expect(find.text(testCase.$2), findsOneWidget);
    });
  }

  testWidgets('sign-out clears an already generated Premium result', (
    tester,
  ) async {
    final service = _FakePremiumAiService(
      result: PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.success,
        summary: _summary(now),
      ),
    );
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _app(
        service: service,
        auth: auth,
        snapshot: _snapshot(now),
        enabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özet oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Günün Premium özeti'), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Günün Premium özeti'), findsNothing);
  });

  testWidgets('Premium AI section does not overflow on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(288, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakePremiumAiService(
      result: PremiumAiSummaryResult(
        status: PremiumAiSummaryStatus.success,
        summary: _summary(now),
      ),
    );
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _app(
        service: service,
        auth: auth,
        snapshot: _snapshot(now),
        enabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özet oluştur'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required PremiumAiSummaryGateway service,
  required TrendoraAuthGateway auth,
  required DailyDigestSnapshot snapshot,
  bool enabled = false,
}) {
  return MaterialApp(
    theme: TrendoraTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: PremiumAiDigestSection(
          snapshot: snapshot,
          enabled: enabled,
          service: service,
          authService: auth,
        ),
      ),
    ),
  );
}

DailyDigestSnapshot _snapshot(DateTime now) {
  return DailyDigestSnapshot(
    userId: 'guest:test',
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
        reference: 'news-1',
      ),
    ],
  );
}

PremiumAiSummary _summary(DateTime now) {
  return PremiumAiSummary(
    title: 'Günün Premium özeti',
    summary: 'Doğrulanmış veriler kısa ve tarafsız biçimde yorumlandı.',
    highlights: const ['Önemli gelişme kaynakta bulunuyor.'],
    risks: const ['Koşullar değişebilir.'],
    sources: const ['Haber Kaynağı'],
    generatedAt: now,
    dataUpdatedAt: now.subtract(const Duration(minutes: 10)),
    cached: true,
    aiGenerated: true,
    disclaimer: 'Yatırım tavsiyesi değildir.',
  );
}
