import 'dart:async';

import 'package:flutter/material.dart';

import '../core/auth/trendora_auth_service.dart';
import '../core/daily_digest/daily_digest_models.dart';
import '../core/premium_ai/premium_ai_summary_service.dart';
import '../theme/trendora_theme.dart';

class PremiumAiDigestSection extends StatefulWidget {
  const PremiumAiDigestSection({
    super.key,
    required this.snapshot,
    required this.enabled,
    this.service,
    this.authService,
  });

  final DailyDigestSnapshot? snapshot;
  final bool enabled;
  final PremiumAiSummaryGateway? service;
  final TrendoraAuthGateway? authService;

  @override
  State<PremiumAiDigestSection> createState() => _PremiumAiDigestSectionState();
}

class _PremiumAiDigestSectionState extends State<PremiumAiDigestSection> {
  late final TrendoraAuthGateway _authService;
  late final PremiumAiSummaryGateway _service;
  StreamSubscription<TrendoraAuthUser?>? _authSubscription;
  PremiumAiFeatureAvailability? _availability;
  PremiumAiSummaryResult? _result;
  bool _checkingAvailability = false;
  bool _generating = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? TrendoraAuthService.instance;
    _service =
        widget.service ?? PremiumAiSummaryService(authService: _authService);
    if (widget.enabled) {
      _listenToAuth();
      unawaited(_loadAvailability());
    } else {
      _availability = PremiumAiFeatureAvailability.disabled;
    }
  }

  @override
  void didUpdateWidget(covariant PremiumAiDigestSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _listenToAuth();
      unawaited(_loadAvailability());
    } else if (oldWidget.enabled && !widget.enabled) {
      _requestId += 1;
      _authSubscription?.cancel();
      _authSubscription = null;
      _availability = PremiumAiFeatureAvailability.disabled;
      _result = null;
      _generating = false;
    }
    if (_snapshotKey(oldWidget.snapshot) != _snapshotKey(widget.snapshot)) {
      _requestId += 1;
      _result = null;
      _generating = false;
    }
  }

  @override
  void dispose() {
    _requestId += 1;
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuth() {
    if (_authSubscription != null) return;
    _authSubscription = _authService.authStateChanges().listen((user) {
      if (!mounted || user != null) return;
      setState(() {
        _requestId += 1;
        _result = null;
        _generating = false;
      });
    });
  }

  Future<void> _loadAvailability() async {
    if (_checkingAvailability || !widget.enabled) return;
    setState(() => _checkingAvailability = true);
    final availability = await _service.loadAvailability();
    if (!mounted || !widget.enabled) return;
    setState(() {
      _availability = availability;
      _checkingAvailability = false;
    });
  }

  Future<void> _generate() async {
    final snapshot = widget.snapshot;
    if (_generating ||
        _availability != PremiumAiFeatureAvailability.enabled ||
        snapshot == null ||
        snapshot.isEmpty) {
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _generating = true;
      _result = null;
    });
    final result = await _service.generate(snapshot);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _generating = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    final summary = _result?.summary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TrendoraColors.backgroundSoft,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: TrendoraColors.secondary.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: TrendoraColors.secondary,
                size: 19,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PREMIUM YAPAY ZEKÂ ÖZETİ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TrendoraColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!widget.enabled ||
              availability == PremiumAiFeatureAvailability.disabled)
            const _StatusText('Premium Yapay Zekâ şu anda kapalı')
          else if (_checkingAvailability || availability == null)
            const _StatusText('Premium Yapay Zekâ durumu kontrol ediliyor')
          else if (availability == PremiumAiFeatureAvailability.unavailable)
            const _StatusText('Premium Yapay Zekâ durumu şu anda doğrulanamadı')
          else ...[
            const _StatusText(
              'Yalnızca düğmeye bastığında, mevcut güncel özet verileri yorumlanır.',
            ),
            const SizedBox(height: 10),
            if (widget.snapshot == null || widget.snapshot!.isEmpty)
              const _StatusText(
                'AI özeti için güncel ücretsiz özet verisi bulunmuyor.',
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _generating ? 'Özet oluşturuluyor' : 'Özet oluştur',
                  ),
                ),
              ),
          ],
          if (_result != null && summary == null) ...[
            const SizedBox(height: 9),
            _StatusText(_messageFor(_result!.status)),
          ],
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              summary.title,
              style: const TextStyle(
                color: TrendoraColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Yapay zekâ yorumu',
              style: TextStyle(
                color: TrendoraColors.secondary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              summary.summary,
              style: const TextStyle(
                color: TrendoraColors.textSecondary,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
            if (summary.highlights.isNotEmpty)
              _BulletGroup(title: 'Öne çıkanlar', items: summary.highlights),
            if (summary.risks.isNotEmpty)
              _BulletGroup(title: 'Dikkat noktaları', items: summary.risks),
            const SizedBox(height: 8),
            Text(
              'Kaynaklar: ${summary.sources.join(', ')}',
              style: const TextStyle(
                color: TrendoraColors.textSecondary,
                fontSize: 9,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Veri: ${_dateLabel(summary.dataUpdatedAt)} • '
              'AI: ${_dateLabel(summary.generatedAt)}'
              '${summary.cached ? ' • Önbellek' : ''}',
              style: const TextStyle(color: Colors.white38, fontSize: 8.5),
            ),
            if (summary.disclaimer != null) ...[
              const SizedBox(height: 7),
              Text(
                summary.disclaimer!,
                style: const TextStyle(
                  color: TrendoraColors.accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _messageFor(PremiumAiSummaryStatus status) {
    return switch (status) {
      PremiumAiSummaryStatus.success => 'Premium AI özeti hazır.',
      PremiumAiSummaryStatus.unauthorized =>
        'Oturum doğrulanamadı. Hesabım bölümünden tekrar giriş yap.',
      PremiumAiSummaryStatus.notPremium => 'Premium yetkisi bulunmuyor.',
      PremiumAiSummaryStatus.disabled => 'Premium Yapay Zekâ şu anda kapalı.',
      PremiumAiSummaryStatus.notConfigured =>
        'Premium Yapay Zekâ sunucuda henüz yapılandırılmadı.',
      PremiumAiSummaryStatus.insufficientData =>
        'Özet için yeterli güncel veri bulunamadı.',
      PremiumAiSummaryStatus.rateLimited =>
        'Çok fazla istek gönderildi. Lütfen daha sonra tekrar dene.',
      PremiumAiSummaryStatus.quotaExceeded =>
        'AI kotası şu anda kullanılamıyor. Lütfen daha sonra tekrar dene.',
      PremiumAiSummaryStatus.timeout =>
        'AI isteği zaman aşımına uğradı. Ücretsiz özet kullanılabilir.',
      PremiumAiSummaryStatus.invalidResponse =>
        'AI cevabı güvenlik doğrulamasından geçmedi.',
      PremiumAiSummaryStatus.networkError =>
        'Bağlantı kurulamadı. Ücretsiz özet kullanılabilir.',
    };
  }

  static String _snapshotKey(DailyDigestSnapshot? snapshot) {
    if (snapshot == null) return '';
    return [
      snapshot.generatedAt.toUtc().toIso8601String(),
      ...snapshot.items.map(
        (item) => '${item.id}:${item.updatedAt.toUtc().toIso8601String()}',
      ),
    ].join('|');
  }

  static String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: TrendoraColors.textSecondary,
        fontSize: 10,
        height: 1.35,
      ),
    );
  }
}

class _BulletGroup extends StatelessWidget {
  const _BulletGroup({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TrendoraColors.textPrimary,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: TrendoraColors.textSecondary,
                  fontSize: 9.5,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
