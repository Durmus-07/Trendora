import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/auth/premium_status_service.dart';
import 'package:trendora_app/core/auth/trendora_auth_service.dart';
import 'package:trendora_app/hesabim_sayfasi.dart';

class _FakeAuthService implements TrendoraAuthGateway {
  _FakeAuthService({this.available = true});

  final bool available;
  final _changes = StreamController<TrendoraAuthUser?>.broadcast();
  TrendoraAuthUser? _user;

  void setAuthenticatedUser(TrendoraAuthUser user) {
    _user = user;
  }

  @override
  bool get isAvailable => available;

  @override
  TrendoraAuthUser? get currentUser => _user;

  @override
  Stream<TrendoraAuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!available) {
      throw const TrendoraAuthFailure('Hesap servisi kullanılamıyor.');
    }
    _user = TrendoraAuthUser(uid: 'firebase-beta-user', email: email.trim());
    _changes.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _user == null ? null : 'mock-firebase-id-token';
  }

  Future<void> dispose() => _changes.close();
}

class _FakePremiumStatusService implements PremiumStatusGateway {
  _FakePremiumStatusService({
    this.result = const PremiumVerificationResult(
      status: PremiumVerificationStatus.networkError,
    ),
  });

  final PremiumVerificationResult result;
  int requestCount = 0;

  @override
  Future<PremiumVerificationResult> verify(
    TrendoraAuthGateway authService,
  ) async {
    requestCount += 1;
    return result;
  }
}

class _PendingPremiumStatusService implements PremiumStatusGateway {
  final completer = Completer<PremiumVerificationResult>();

  @override
  Future<PremiumVerificationResult> verify(TrendoraAuthGateway authService) {
    return completer.future;
  }
}

Widget _app(
  TrendoraAuthGateway service, {
  PremiumStatusGateway? premiumStatusService,
}) {
  return MaterialApp(
    home: HesabimSayfasi(
      authService: service,
      premiumStatusService: premiumStatusService ?? _FakePremiumStatusService(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest user keeps free access and no signup action is shown', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));

    expect(find.text('Misafir modu'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Kayıt Ol'), findsNothing);
    expect(find.textContaining('ücretsiz özelliklerini'), findsOneWidget);
  });

  testWidgets('beta login preserves existing guest preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'trendora_guest_data_test': 'korunacak-deger',
    });
    final auth = _FakeAuthService();
    final premium = _FakePremiumStatusService(
      result: const PremiumVerificationResult(
        status: PremiumVerificationStatus.verified,
        httpStatus: 200,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth, premiumStatusService: premium));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'beta@trendora.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'beta-password');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Oturum açık'), findsOneWidget);
    expect(find.text('beta@trendora.test'), findsOneWidget);
    expect(find.text('Oturumu Kapat'), findsOneWidget);
    expect(find.text('Premium yetkisi doğrulandı'), findsOneWidget);
    expect(find.text('Sunucu 200 döndürdü'), findsOneWidget);
    expect(
      find.textContaining('Premium yetkisi yalnızca sunucu tarafından'),
      findsNothing,
    );
    expect(premium.requestCount, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('trendora_guest_data_test'), 'korunacak-deger');
  });

  testWidgets('signing out closes authenticated access', (tester) async {
    final auth = _FakeAuthService()
      ..setAuthenticatedUser(
        const TrendoraAuthUser(
          uid: 'firebase-beta-user',
          email: 'beta@trendora.test',
        ),
      );
    final premium = _FakePremiumStatusService(
      result: const PremiumVerificationResult(
        status: PremiumVerificationStatus.verified,
        httpStatus: 200,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth, premiumStatusService: premium));
    await tester.pumpAndSettle();
    expect(find.text('Premium yetkisi doğrulandı'), findsOneWidget);
    expect(await auth.getIdToken(), isNotNull);

    await tester.tap(find.text('Oturumu Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Misafir modu'), findsOneWidget);
    expect(find.text('Premium yetkisi doğrulandı'), findsNothing);
    expect(await auth.getIdToken(), isNull);
  });

  testWidgets('signed-in user can refresh the verified Premium status', (
    tester,
  ) async {
    final auth = _FakeAuthService()
      ..setAuthenticatedUser(
        const TrendoraAuthUser(
          uid: 'firebase-beta-user',
          email: 'beta@trendora.test',
        ),
      );
    final premium = _FakePremiumStatusService(
      result: const PremiumVerificationResult(
        status: PremiumVerificationStatus.verified,
        httpStatus: 200,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth, premiumStatusService: premium));
    await tester.pumpAndSettle();

    expect(find.text('Premium yetkisi doğrulandı'), findsOneWidget);
    expect(premium.requestCount, 1);

    await tester.tap(find.text('Premium durumunu yenile'));
    await tester.pumpAndSettle();

    expect(premium.requestCount, 2);
    expect(find.text('Premium yetkisi doğrulandı'), findsOneWidget);
  });

  testWidgets('Premium check shows a loading state', (tester) async {
    final auth = _FakeAuthService()
      ..setAuthenticatedUser(
        const TrendoraAuthUser(
          uid: 'firebase-beta-user',
          email: 'beta@trendora.test',
        ),
      );
    final premium = _PendingPremiumStatusService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth, premiumStatusService: premium));
    await tester.pump();

    expect(find.text('Premium yetkisi kontrol ediliyor'), findsOneWidget);
    expect(find.text('Premium kontrolü başlatıldı'), findsOneWidget);

    premium.completer.complete(
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.verified,
        httpStatus: 200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium yetkisi doğrulandı'), findsOneWidget);
  });

  for (final testCase in <(PremiumVerificationResult, String, String)>[
    (
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.notPremium,
        httpStatus: 403,
        errorCode: 'PREMIUM_REQUIRED',
      ),
      'Premium yetkisi bulunmuyor',
      'Sunucu 403 döndürdü (PREMIUM_REQUIRED)',
    ),
    (
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.unauthorized,
        httpStatus: 401,
        errorCode: 'INVALID_TOKEN',
      ),
      'Oturum doğrulanamadı',
      'Sunucu 401 döndürdü (INVALID_TOKEN)',
    ),
    (
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.tokenUnavailable,
      ),
      'Oturum doğrulanamadı',
      'Oturum tokenı alınamadı',
    ),
    (
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.networkError,
      ),
      'Premium durumu şu anda doğrulanamadı',
      'Ağ hatası',
    ),
    (
      const PremiumVerificationResult(
        status: PremiumVerificationStatus.invalidResponse,
        httpStatus: 200,
      ),
      'Premium durumu şu anda doğrulanamadı',
      'Geçersiz cevap (HTTP 200)',
    ),
  ]) {
    testWidgets('Premium response displays ${testCase.$2}', (tester) async {
      final auth = _FakeAuthService()
        ..setAuthenticatedUser(
          const TrendoraAuthUser(
            uid: 'firebase-beta-user',
            email: 'beta@trendora.test',
          ),
        );
      final premium = _FakePremiumStatusService(result: testCase.$1);
      addTearDown(auth.dispose);

      await tester.pumpWidget(_app(auth, premiumStatusService: premium));
      await tester.pumpAndSettle();

      expect(find.text(testCase.$2), findsOneWidget);
      expect(find.text(testCase.$3), findsOneWidget);
    });
  }

  testWidgets('Firebase outage leaves guest mode usable', (tester) async {
    final auth = _FakeAuthService(available: false);
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));

    expect(find.text('Misafir modu'), findsOneWidget);
    expect(find.textContaining('Hesap servisine'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account screen does not overflow on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(288, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
