import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/premium_status_service.dart';
import 'core/auth/trendora_auth_service.dart';

class HesabimSayfasi extends StatefulWidget {
  const HesabimSayfasi({
    super.key,
    this.authService,
    this.premiumStatusService,
  });

  final TrendoraAuthGateway? authService;
  final PremiumStatusGateway? premiumStatusService;

  @override
  State<HesabimSayfasi> createState() => _HesabimSayfasiState();
}

class _HesabimSayfasiState extends State<HesabimSayfasi> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final TrendoraAuthGateway _authService;
  late final PremiumStatusGateway _premiumStatusService;
  StreamSubscription<TrendoraAuthUser?>? _authSubscription;
  TrendoraAuthUser? _user;
  PremiumVerificationResult _premiumStatus = const PremiumVerificationResult(
    status: PremiumVerificationStatus.idle,
  );
  String? _premiumCheckedUid;
  int _premiumRequestId = 0;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? TrendoraAuthService.instance;
    _premiumStatusService =
        widget.premiumStatusService ?? PremiumStatusService();
    _user = _authService.currentUser;
    final initialUser = _user;
    if (initialUser != null) {
      _premiumCheckedUid = initialUser.uid;
      _premiumStatus = const PremiumVerificationResult(
        status: PremiumVerificationStatus.checking,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _user?.uid == initialUser.uid) {
          unawaited(_refreshPremiumStatus(showLoading: false));
        }
      });
    }
    _authSubscription = _authService.authStateChanges().listen((user) {
      _handleAuthStateChanged(user);
    });
  }

  @override
  void dispose() {
    _premiumRequestId += 1;
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _passwordController.clear();
      _handleAuthStateChanged(user);
    } on TrendoraAuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Oturum açılamadı. Lütfen tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _authService.signOut();
      _handleAuthStateChanged(null);
    } on TrendoraAuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Oturum kapatılamadı. Lütfen tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleAuthStateChanged(TrendoraAuthUser? user) {
    if (!mounted) return;
    final shouldCheck = user != null && _premiumCheckedUid != user.uid;

    setState(() {
      _user = user;
      if (user == null) {
        _premiumRequestId += 1;
        _premiumCheckedUid = null;
        _premiumStatus = const PremiumVerificationResult(
          status: PremiumVerificationStatus.idle,
        );
      } else if (shouldCheck) {
        _premiumCheckedUid = user.uid;
        _premiumStatus = const PremiumVerificationResult(
          status: PremiumVerificationStatus.checking,
        );
      }
    });

    if (shouldCheck) {
      unawaited(_refreshPremiumStatus(showLoading: false));
    }
  }

  Future<void> _refreshPremiumStatus({bool showLoading = true}) async {
    final user = _user;
    if (user == null) return;

    final requestId = ++_premiumRequestId;
    if (showLoading && mounted) {
      setState(() {
        _premiumStatus = const PremiumVerificationResult(
          status: PremiumVerificationStatus.checking,
        );
      });
    }

    final result = await _premiumStatusService.verify(_authService);
    if (!mounted || requestId != _premiumRequestId || _user?.uid != user.uid) {
      return;
    }
    setState(() => _premiumStatus = result);
  }

  String get _premiumStatusMessage {
    return switch (_premiumStatus.status) {
      PremiumVerificationStatus.checking => 'Premium yetkisi kontrol ediliyor',
      PremiumVerificationStatus.verified => 'Premium yetkisi doğrulandı',
      PremiumVerificationStatus.notPremium => 'Premium yetkisi bulunmuyor',
      PremiumVerificationStatus.unauthorized => 'Oturum doğrulanamadı',
      PremiumVerificationStatus.tokenUnavailable => 'Oturum doğrulanamadı',
      PremiumVerificationStatus.networkError =>
        'Premium durumu şu anda doğrulanamadı',
      PremiumVerificationStatus.invalidResponse =>
        'Premium durumu şu anda doğrulanamadı',
      PremiumVerificationStatus.idle => 'Premium durumu henüz kontrol edilmedi',
    };
  }

  String? get _premiumDiagnosticMessage {
    final code = _premiumStatus.errorCode;
    final codeSuffix = code == null ? '' : ' ($code)';
    return switch (_premiumStatus.status) {
      PremiumVerificationStatus.checking => 'Premium kontrolü başlatıldı',
      PremiumVerificationStatus.verified => 'Sunucu 200 döndürdü',
      PremiumVerificationStatus.notPremium => 'Sunucu 403 döndürdü$codeSuffix',
      PremiumVerificationStatus.unauthorized
          when _premiumStatus.httpStatus == 401 =>
        'Sunucu 401 döndürdü$codeSuffix',
      PremiumVerificationStatus.unauthorized => 'Oturum tokenı alınamadı',
      PremiumVerificationStatus.tokenUnavailable => 'Oturum tokenı alınamadı',
      PremiumVerificationStatus.networkError
          when _premiumStatus.httpStatus != null =>
        'Sunucu ${_premiumStatus.httpStatus} döndürdü',
      PremiumVerificationStatus.networkError => 'Ağ hatası',
      PremiumVerificationStatus.invalidResponse
          when _premiumStatus.httpStatus != null =>
        'Geçersiz cevap (HTTP ${_premiumStatus.httpStatus})',
      PremiumVerificationStatus.invalidResponse => 'Geçersiz cevap',
      PremiumVerificationStatus.idle => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Hesabım'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _user == null
                  ? _buildGuestContent()
                  : _buildAccountContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(
          icon: Icons.person_outline_rounded,
          title: 'Misafir modu',
          description:
              'Trendora’nın ücretsiz özelliklerini hesabına giriş yapmadan kullanmaya devam edebilirsin.',
        ),
        const SizedBox(height: 16),
        if (!_authService.isAvailable)
          _messageCard(
            'Hesap servisine şu anda ulaşılamıyor. Mevcut tercihlerin ve kayıtlı verilerin korunur.',
          )
        else
          _loginCard(),
      ],
    );
  }

  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Beta hesabıyla giriş yap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hesap oluşturma işlemi yalnızca Firebase Console üzerinden yönetilir.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailController,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'E-posta',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Geçerli bir e-posta adresi gir.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !_busy,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _signIn(),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Şifre',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Şifreni gir.';
                return null;
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _messageCard(_message!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountContent() {
    final email = _user?.email?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(
          icon: Icons.verified_user_outlined,
          title: 'Oturum açık',
          description: email == null || email.isEmpty
              ? 'Firebase hesabı'
              : email,
        ),
        const SizedBox(height: 16),
        _messageCard(_premiumStatusMessage, detail: _premiumDiagnosticMessage),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _premiumStatus.status == PremiumVerificationStatus.checking
              ? null
              : _refreshPremiumStatus,
          icon: _premiumStatus.status == PremiumVerificationStatus.checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('Premium durumunu yenile'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Premium Yapay Zekâ bu aşamada kapalıdır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _messageCard(_message!),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Oturumu Kapat'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Oturum açmak veya kapatmak cihazındaki mevcut Trendora tercihlerini, bildirimlerini ve kayıtlı verilerini değiştirmez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF58E6D9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF58E6D9)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(String message, {String? detail}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF58E6D9).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF58E6D9).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          if (detail != null) ...[
            const SizedBox(height: 5),
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF101D2E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: const Color(0xFF58E6D9)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF07111F),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
  }
}
