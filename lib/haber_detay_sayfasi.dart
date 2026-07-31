import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/news/news_explanation_service.dart';
import 'core/news/news_intelligence_service.dart';
import 'core/news/news_share_service.dart';
import 'core/news/saved_news_store.dart';

typedef NewsSourceLauncher = Future<bool> Function();
typedef NewsShareAction = Future<void> Function();

String _resolvedNewsId({
  required String id,
  required String url,
  required String title,
  required DateTime publishedAt,
}) {
  if (id.trim().isNotEmpty) return id.trim();
  if (url.trim().isNotEmpty) return url.trim();
  return '${title.trim()}|${publishedAt.toUtc().toIso8601String()}';
}

class RelatedNewsItem {
  const RelatedNewsItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
    required this.summary,
    required this.articleText,
    required this.url,
    required this.category,
    this.feedSource = '',
    this.isBreaking = false,
    this.hasValidPublishedAt = true,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String source;
  final DateTime publishedAt;
  final String summary;
  final String articleText;
  final String url;
  final String category;
  final String feedSource;
  final bool isBreaking;
  final bool hasValidPublishedAt;
}

class HaberDetaySayfasi extends StatelessWidget {
  HaberDetaySayfasi({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
    required this.summary,
    required this.articleText,
    required this.url,
    this.id = '',
    this.category = '',
    this.feedSource = '',
    this.isBreaking = false,
    this.relatedNews = const [],
    this.onOpenSource,
    this.onShare,
    NewsShareService? shareService,
    NewsExplanationService? explanationService,
    NewsIntelligenceService? intelligenceService,
    NewsIntelligenceResult? intelligence,
    this.hasValidPublishedAt = true,
    this.sourceCount = 1,
    this.confirmingSourceCount = 0,
  }) : _shareService = shareService ?? NewsShareService(),
       _explanation = (explanationService ?? NewsExplanationService.shared)
           .explain(
             newsId: _resolvedNewsId(
               id: id,
               url: url,
               title: title,
               publishedAt: publishedAt,
             ),
             title: title,
             summary: summary,
             articleText: articleText,
             category: category,
           ),
       _intelligence =
           intelligence ??
           (intelligenceService ?? NewsIntelligenceService.shared).evaluate(
             newsId: _resolvedNewsId(
               id: id,
               url: url,
               title: title,
               publishedAt: publishedAt,
             ),
             title: title,
             summary: summary,
             articleText: articleText,
             category: category,
             source: source,
             feedSource: feedSource,
             publishedAt: hasValidPublishedAt ? publishedAt : null,
             isBreaking: isBreaking,
             sourceCount: sourceCount,
             confirmingSourceCount: confirmingSourceCount,
           );

  final String title;
  final String imageUrl;
  final String source;
  final DateTime publishedAt;
  final String summary;
  final String articleText;
  final String url;
  final String id;
  final String category;
  final String feedSource;
  final bool isBreaking;
  final bool hasValidPublishedAt;
  final int sourceCount;
  final int confirmingSourceCount;
  final List<RelatedNewsItem> relatedNews;
  final NewsSourceLauncher? onOpenSource;
  final NewsShareAction? onShare;
  final NewsShareService _shareService;
  final NewsExplanation _explanation;
  final NewsIntelligenceResult _intelligence;

  String get _newsId =>
      _resolvedNewsId(id: id, url: url, title: title, publishedAt: publishedAt);

  SavedNews get _savedNews => SavedNews(
    id: _newsId,
    title: title.trim(),
    summary: summary.trim(),
    articleText: articleText.trim(),
    imageUrl: imageUrl.trim(),
    url: url.trim(),
    source: _sourceLabel,
    category: category.trim(),
    publishedAt: publishedAt,
    savedAt: DateTime.now(),
  );

  Uri? get _sourceUri {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  String get _sourceLabel {
    final value = source.trim();
    return value.isEmpty ? 'Kaynak belirtilmedi' : value;
  }

  String get _publishedLabel {
    if (!hasValidPublishedAt) return 'Yayın tarihi bilinmiyor';
    final local = publishedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} • $hour:$minute';
  }

  int get _readingMinutes {
    final text = articleText.trim().isEmpty
        ? summary.trim()
        : articleText.trim();
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (words / 190).ceil().clamp(1, 99);
  }

  String get _readingTimeLabel => '$_readingMinutes dk okuma';

  String get _readableArticleText {
    final fullText = articleText.trim();
    if (fullText.isNotEmpty) return fullText;

    final shortText = summary.trim();
    if (shortText.isNotEmpty) {
      return '$shortText\n\nKaynak bu kayıt için tam haber metnini '
          'sağlamadı. Tüm ayrıntılar için Kaynağa Git butonunu kullanabilirsin.';
    }

    return 'Haberin tam metni kaynaktan sağlanmadı. Tüm ayrıntılar için '
        'Kaynağa Git butonunu kullanabilirsin.';
  }

  bool get _hasSeparateSummary {
    final shortText = summary.trim();
    return shortText.isNotEmpty && shortText != articleText.trim();
  }

  List<String> get _importancePoints {
    final text = '$title $summary $articleText $category'.toLowerCase();
    final points = <String>[];

    if (_containsAny(text, const ['bist', 'borsa', 'hisse', 'şirket'])) {
      points.add('BIST şirketlerini ve yatırımcı kararlarını etkileyebilir.');
    }
    if (_containsAny(text, const [
      'faiz',
      'banka',
      'kredi',
      'merkez bankası',
    ])) {
      points.add('Bankacılık sektörü ve finansman koşullarını etkileyebilir.');
    }
    if (_containsAny(text, const [
      'dünya',
      'küresel',
      'abd',
      'avrupa',
      'çin',
      'rusya',
      'uluslararası',
    ])) {
      points.add('Küresel piyasaları ve uluslararası gündemi ilgilendiriyor.');
    }
    if (_containsAny(text, const [
      'teknoloji',
      'yapay zeka',
      'yapay zekâ',
      'yazılım',
      'siber',
    ])) {
      points.add('Teknoloji ekosistemi ve dijital ürünler için önem taşıyor.');
    }
    if (_containsAny(text, const [
      'enflasyon',
      'dolar',
      'euro',
      'vergi',
      'zam',
    ])) {
      points.add('Fiyatlama, tasarruf ve tüketici kararlarına yansıyabilir.');
    }
    if (_containsAny(text, const [
      'spor',
      'maç',
      'lig',
      'futbol',
      'basketbol',
    ])) {
      points.add('Spor gündemini ve ilgili organizasyonları etkileyebilir.');
    }

    if (points.isEmpty) {
      points.add('Gündemin yönünü ve kamuoyu kararlarını etkileyebilir.');
    }

    return points.take(3).toList(growable: false);
  }

  bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF091426),
        foregroundColor: Colors.white,
        title: const Text(
          'Haber Detayı',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('haber-ust-paylas'),
            tooltip: 'Paylaş',
            onPressed: () => _share(context),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _PremiumReadingView(
          readingMinutes: _readingMinutes,
          slivers: [
            SliverToBoxAdapter(child: _buildImage()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              sliver: SliverList.list(
                children: [
                  Text(
                    title.trim().isEmpty ? 'Başlıksız haber' : title.trim(),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 29,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetadata(),
                  const SizedBox(height: 22),
                  _NewsTextSection(
                    title: 'Haberin Tam Metni',
                    text: _readableArticleText,
                    primary: true,
                  ),
                  if (_hasSeparateSummary) ...[
                    const SizedBox(height: 18),
                    _NewsTextSection(title: 'Kısa Bakış', text: summary.trim()),
                  ],
                  const SizedBox(height: 18),
                  _WhyItMattersSection(points: _importancePoints),
                  const SizedBox(height: 18),
                  _TrendoraExplainsCard(explanation: _explanation),
                  const SizedBox(height: 26),
                  _buildActions(context),
                  if (relatedNews.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    _RelatedNewsSection(items: relatedNews),
                  ],
                  const SizedBox(height: 30),
                  _TrendoraAssessmentCard(intelligence: _intelligence),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final value = imageUrl.trim();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          value.isEmpty
              ? const _NewsImagePlaceholder()
              : Image.network(
                  value,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: child,
                        );
                      },
                  errorBuilder: (_, __, ___) => const _NewsImagePlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _NewsImagePlaceholder(showProgress: true);
                  },
                ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x59091426)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xDD091426),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF77B7FF),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            _sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: Color(0xFFB8C8DD),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _publishedLabel,
                          style: const TextStyle(
                            color: Color(0xFFE7EDF5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _NewsMetadataItem(
          icon: Icons.menu_book_rounded,
          text: _readingTimeLabel,
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final sourceEnabled = _sourceUri != null || onOpenSource != null;
    final sourceButton = TextButton.icon(
      key: const Key('haber-kaynaga-git'),
      onPressed: sourceEnabled ? () => _openSource(context) : null,
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('Kaynağa Git'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF526075),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    final shareButton = OutlinedButton.icon(
      key: const Key('haber-paylas'),
      onPressed: () => _share(context),
      icon: const Icon(Icons.share_rounded),
      label: const Text('Paylaş'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF172B4D),
        side: const BorderSide(color: Color(0xFFB8C2D0)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
    final saveButton = _SaveNewsButton(news: _savedNews);

    return LayoutBuilder(
      builder: (context, constraints) {
        final primaryActions = constraints.maxWidth < 340
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [saveButton, const SizedBox(height: 10), shareButton],
              )
            : Row(
                children: [
                  Expanded(child: saveButton),
                  const SizedBox(width: 10),
                  Expanded(child: shareButton),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primaryActions,
            const SizedBox(height: 8),
            Center(child: sourceButton),
          ],
        );
      },
    );
  }

  Future<void> _openSource(BuildContext context) async {
    try {
      final opened = onOpenSource != null
          ? await onOpenSource!()
          : await launchUrl(_sourceUri!, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        _showMessage(context, 'Haber kaynağı açılamadı.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Haber kaynağı açılamadı.');
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      if (onShare != null) {
        await onShare!();
        return;
      }

      final result = await _shareService.share(title: title, url: url);
      if (result == NewsShareResult.copiedToClipboard && context.mounted) {
        _showMessage(
          context,
          'Paylaşım paneli açılamadı; haber bağlantısı panoya kopyalandı.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Haber paylaşılamadı.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TrendoraAssessmentCard extends StatelessWidget {
  const _TrendoraAssessmentCard({required this.intelligence});

  final NewsIntelligenceResult intelligence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final impact = intelligence.financialImpact;

    return Container(
      key: const Key('trendora-degerlendirmesi'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trendora Analizi',
                        key: const Key('trendora-analizi'),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Finansal etki ve piyasa önemi',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${impact.impactScore}',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        'ETKİ / 100',
                        style: TextStyle(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Bu değerlendirme Trendora tarafından oluşturulmuştur. '
                'Yatırım tavsiyesi değildir.',
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _FinancialImpactRow(
              icon: Icons.candlestick_chart_rounded,
              label: 'Borsa Etkisi',
              text: impact.stockMarket,
            ),
            _FinancialImpactRow(
              icon: Icons.account_balance_rounded,
              label: 'Bankacılık Etkisi',
              text: impact.banking,
            ),
            _FinancialImpactRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Altın Etkisi',
              text: impact.gold,
            ),
            _FinancialImpactRow(
              icon: Icons.currency_exchange_rounded,
              label: 'Döviz Etkisi',
              text: impact.foreignExchange,
            ),
            _FinancialImpactRow(
              icon: Icons.currency_bitcoin_rounded,
              label: 'Kripto Etkisi',
              text: impact.crypto,
            ),
            _FinancialImpactRow(
              icon: Icons.oil_barrel_outlined,
              label: 'Petrol Etkisi',
              text: impact.oil,
            ),
            _FinancialImpactRow(
              icon: Icons.factory_outlined,
              label: 'Etkilenen sektörler',
              text: impact.sectors.isEmpty
                  ? 'Belirgin bir sektör bağlantısı saptanmadı.'
                  : impact.sectors.join(', '),
            ),
            _FinancialImpactRow(
              icon: Icons.business_rounded,
              label: 'Etkilenen şirketler',
              text: impact.companies.isEmpty
                  ? 'Metinde adı geçen belirgin bir şirket saptanmadı.'
                  : impact.companies.join(', '),
            ),
            _FinancialImpactRow(
              icon: Icons.public_rounded,
              label: 'Genel piyasa etkisi',
              text: impact.overallMarket,
            ),
            _FinancialImpactRow(
              icon: Icons.warning_amber_rounded,
              label: 'Risk seviyesi',
              text: impact.riskLevel,
              showDivider: false,
            ),
            const SizedBox(height: 14),
            Text(
              'Etkilenen Varlıklar',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            if (impact.affectedAssets.isEmpty)
              Text(
                'Bu haber için belirgin bir finansal varlık etiketi saptanmadı.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final asset in impact.affectedAssets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        asset,
                        style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Güven Seviyesi: ${intelligence.confidence.label}',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${intelligence.confidence.score}/100 • '
                    '${intelligence.confidence.reason}',
                    style: TextStyle(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Analiz dayanağı',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            _AssessmentMetric(
              icon: Icons.priority_high_rounded,
              label: 'Önem seviyesi',
              value:
                  '${intelligence.importanceLevel} • ${intelligence.importanceScore}/100',
            ),
            _AssessmentMetric(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Finansal ilgi',
              value:
                  '${intelligence.financialRelevanceLevel} • ${intelligence.financialRelevanceScore}/100',
            ),
            _AssessmentMetric(
              icon: Icons.verified_user_outlined,
              label: 'Kaynak sınıfı',
              value: intelligence.source.label,
            ),
            _AssessmentMetric(
              icon: Icons.schedule_rounded,
              label: 'Güncellik',
              value: intelligence.freshness.label,
              showDivider: false,
            ),
            const SizedBox(height: 14),
            Text(
              'Neden bu puan?',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _AssessmentReason(text: intelligence.importanceReason),
            const SizedBox(height: 6),
            _AssessmentReason(text: intelligence.financialReason),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${intelligence.trendoraReason} Etki puanı metindeki finansal '
                'sinyallerin kapsamını gösterir; fiyat yönü veya getiri vaadi '
                'değildir.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialImpactRow extends StatelessWidget {
  const _FinancialImpactRow({
    required this.icon,
    required this.label,
    required this.text,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String text;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}

class _AssessmentMetric extends StatelessWidget {
  const _AssessmentMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}

class _AssessmentReason extends StatelessWidget {
  const _AssessmentReason({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 5, color: colors.primary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendoraExplainsCard extends StatelessWidget {
  const _TrendoraExplainsCard({required this.explanation});

  final NewsExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const Key('trendora-acikliyor'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.62),
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: colors.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '🧠 Trendora Açıklıyor',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (explanation.concepts.isEmpty)
              Text(
                'Bu haberde ek açıklama gerektiren teknik bir kavram '
                'tespit edilmedi.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.45,
                ),
              )
            else
              for (final concept in explanation.concepts)
                _ConceptExplanationTile(concept: concept),
            if (explanation.possibleEffects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.insights_rounded, size: 19, color: colors.primary),
                  const SizedBox(width: 7),
                  Text(
                    'Olası Etkiler',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              for (final effect in explanation.possibleEffects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          effect,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.64),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      NewsExplanation.disclaimer,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptExplanationTile extends StatelessWidget {
  const _ConceptExplanationTile({required this.concept});

  final NewsConceptExplanation concept;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.64),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              concept.term,
              style: TextStyle(
                color: colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              concept.explanation,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyItMattersSection extends StatelessWidget {
  const _WhyItMattersSection({required this.points});

  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F5FF), Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E4F5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 20,
                  color: Color(0xFF315B91),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Neden Önemli?',
                    maxLines: 2,
                    style: TextStyle(
                      color: Color(0xFF172B4D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Color(0xFF4C78AE),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          color: Color(0xFF465469),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RelatedNewsSection extends StatelessWidget {
  const _RelatedNewsSection({required this.items});

  final List<RelatedNewsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Benzer Haberler',
          style: TextStyle(
            color: Color(0xFF172B4D),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items.take(3)) ...[
          _RelatedNewsCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RelatedNewsCard extends StatelessWidget {
  const _RelatedNewsCard({required this.item});

  final RelatedNewsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => HaberDetaySayfasi(
            id: item.id,
            title: item.title,
            imageUrl: item.imageUrl,
            source: item.source,
            publishedAt: item.publishedAt,
            hasValidPublishedAt: item.hasValidPublishedAt,
            summary: item.summary,
            articleText: item.articleText,
            url: item.url,
            category: item.category,
            feedSource: item.feedSource,
            isBreaking: item.isBreaking,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(17),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE3E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: const Color(0xFF315B91),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF778398),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String value) {
    return switch (value.toLowerCase()) {
      'ekonomi' || 'borsa' => Icons.show_chart_rounded,
      'teknoloji' || 'yapay_zeka' => Icons.memory_rounded,
      'spor' => Icons.sports_soccer_rounded,
      'dunya' => Icons.public_rounded,
      _ => Icons.newspaper_rounded,
    };
  }
}

class _PremiumReadingView extends StatefulWidget {
  const _PremiumReadingView({
    required this.readingMinutes,
    required this.slivers,
  });

  final int readingMinutes;
  final List<Widget> slivers;

  @override
  State<_PremiumReadingView> createState() => _PremiumReadingViewState();
}

class _PremiumReadingViewState extends State<_PremiumReadingView> {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateProgress)
      ..dispose();
    _progress.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_controller.hasClients) return;
    final maxExtent = _controller.position.maxScrollExtent;
    final next = maxExtent <= 0
        ? 1.0
        : (_controller.offset / maxExtent).clamp(0.0, 1.0);
    if ((next - _progress.value).abs() >= 0.005 || next == 0 || next == 1) {
      _progress.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(
          key: const Key('haber-detay-kaydirma-alani'),
          controller: _controller,
          slivers: widget.slivers,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, progress, _) {
              return Semantics(
                label: 'Haber okunma ilerlemesi',
                value: 'Yüzde ${(progress * 100).round()}',
                child: LinearProgressIndicator(
                  key: const Key('haber-okuma-ilerlemesi'),
                  value: progress,
                  minHeight: 3,
                  color: const Color(0xFF3B82F6),
                  backgroundColor: const Color(0xFFD8E0EA),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 14,
          top: 13,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, progress, _) {
              final remaining = (widget.readingMinutes * (1 - progress))
                  .ceil()
                  .clamp(0, widget.readingMinutes);
              return Semantics(
                liveRegion: true,
                label: remaining == 0
                    ? 'Okuma tamamlandı'
                    : 'Tahmini $remaining dakika kaldı',
                child: Container(
                  key: const Key('haber-kalan-okuma'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE091426),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_stories_outlined,
                        size: 14,
                        color: Color(0xFF9CCBFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        remaining == 0 ? 'Tamamlandı' : '$remaining dk kaldı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SaveNewsButton extends StatefulWidget {
  const _SaveNewsButton({required this.news});

  final SavedNews news;

  @override
  State<_SaveNewsButton> createState() => _SaveNewsButtonState();
}

class _SaveNewsButtonState extends State<_SaveNewsButton> {
  bool _saved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant _SaveNewsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.news.id != widget.news.id) {
      _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return FilledButton.icon(
      key: const Key('haber-kaydet'),
      onPressed: _loading ? null : _toggle,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF172B4D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: AnimatedSwitcher(
        duration: animationDuration,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _loading
            ? const SizedBox(
                key: Key('haber-kaydet-yukleniyor'),
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey<bool>(_saved),
              ),
      ),
      label: AnimatedSwitcher(
        duration: animationDuration,
        child: Text(
          _saved ? 'Kaydedildi' : 'Haberi Kaydet',
          key: ValueKey<bool>(_saved),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _loadState() async {
    try {
      final saved = await SavedNewsStore.isSaved(widget.news.id);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);

    try {
      final saved = await SavedNewsStore.toggle(widget.news);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _loading = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(saved ? 'Haber kaydedildi.' : 'Kayıttan çıkarıldı.'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Haber kaydedilemedi.')));
    }
  }
}

class _NewsMetadataItem extends StatelessWidget {
  const _NewsMetadataItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF526075),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsTextSection extends StatelessWidget {
  const _NewsTextSection({
    required this.title,
    required this.text,
    this.primary = false,
  });

  final String title;
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E8F0)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: primary ? 19 : 16,
              vertical: primary ? 20 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF172B4D),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: primary ? 12 : 9),
                SelectionArea(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: const Color(0xFF344054),
                      fontSize: primary ? 16.5 : 15,
                      height: primary ? 1.72 : 1.55,
                      letterSpacing: primary ? 0.05 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172B4D), Color(0xFF294A74)],
        ),
      ),
      child: Center(
        child: showProgress
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(
                Icons.newspaper_rounded,
                size: 58,
                color: Colors.white,
              ),
      ),
    );
  }
}
