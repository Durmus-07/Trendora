import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TrendoraAuthUser {
  const TrendoraAuthUser({required this.uid, required this.email});

  final String uid;
  final String? email;
}

class TrendoraAuthFailure implements Exception {
  const TrendoraAuthFailure(this.message);

  final String message;
}

abstract class TrendoraAuthGateway {
  bool get isAvailable;

  TrendoraAuthUser? get currentUser;

  Stream<TrendoraAuthUser?> authStateChanges();

  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<String?> getIdToken({bool forceRefresh = false});
}

class TrendoraAuthService implements TrendoraAuthGateway {
  TrendoraAuthService._();

  static final TrendoraAuthService instance = TrendoraAuthService._();

  FirebaseAuth? _auth;

  Future<bool> initialize() async {
    if (_auth != null) return true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _auth = FirebaseAuth.instance;
      return true;
    } catch (_) {
      _auth = null;
      return false;
    }
  }

  @override
  bool get isAvailable => _auth != null;

  @override
  TrendoraAuthUser? get currentUser => _mapUser(_auth?.currentUser);

  @override
  Stream<TrendoraAuthUser?> authStateChanges() {
    final auth = _auth;
    if (auth == null) return Stream<TrendoraAuthUser?>.value(null);
    return auth.authStateChanges().map(_mapUser);
  }

  @override
  Future<TrendoraAuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const TrendoraAuthFailure(
        'Hesap servisine şu anda ulaşılamıyor. Misafir olarak devam edebilirsin.',
      );
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const TrendoraAuthFailure(
          'Oturum açılamadı. Lütfen tekrar dene.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw TrendoraAuthFailure(_messageFor(error.code));
    }
  }

  @override
  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) return;

    try {
      await auth.signOut();
    } on FirebaseAuthException {
      throw const TrendoraAuthFailure(
        'Oturum kapatılamadı. Lütfen tekrar dene.',
      );
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth?.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } on FirebaseAuthException {
      return null;
    }
  }

  static TrendoraAuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return TrendoraAuthUser(uid: user.uid, email: user.email);
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Geçerli bir e-posta adresi gir.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-posta veya şifre doğrulanamadı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar dene.';
      case 'network-request-failed':
        return 'İnternet bağlantısını kontrol edip tekrar dene.';
      default:
        return 'Oturum açılamadı. Lütfen tekrar dene.';
    }
  }
}
