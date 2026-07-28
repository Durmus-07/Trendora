import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Widget _app(TrendoraAuthGateway service) {
  return MaterialApp(home: HesabimSayfasi(authService: service));
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
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));
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
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));
    expect(await auth.getIdToken(), isNotNull);

    await tester.tap(find.text('Oturumu Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Misafir modu'), findsOneWidget);
    expect(await auth.getIdToken(), isNull);
  });

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
