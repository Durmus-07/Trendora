import 'package:flutter/material.dart';

import 'core/news/news_clustering_service.dart';
import 'haber_detay_sayfasi.dart';

class HaberOlayDetaySayfasi extends StatelessWidget {
  const HaberOlayDetaySayfasi({super.key, required this.cluster});

  final NewsEventCluster cluster;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        title: const Text(
          'Gelişme Akışı',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('haber-olay-detay-listesi'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            _EventHeader(cluster: cluster),
            const SizedBox(height: 22),
            Text(
              'Bu Gelişmeyle İlgili Haberler',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'En yeni haber üstte gösterilir.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < cluster.items.length; index++)
              _TimelineNewsItem(
                item: cluster.items[index],
                sourceCount: cluster.uniqueSourceCount,
                isRepresentative:
                    cluster.items[index].stableId ==
                    cluster.representative.stableId,
                isLast: index == cluster.items.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.cluster});

  final NewsEventCluster cluster;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const Key('haber-olay-ozeti'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.hub_outlined, color: colors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cluster.uniqueSourceCount} farklı kaynak',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cluster.items.length} haber kaydı',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            cluster.explanation,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
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
                    'Benzer başlıklar, ortak konular ve yayın zamanlarına göre '
                    'otomatik olarak gruplandırılmıştır. Bu gruplama kesin '
                    'doğruluk veya aynı olay garantisi vermez.',
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
    );
  }
}

class _TimelineNewsItem extends StatelessWidget {
  const _TimelineNewsItem({
    required this.item,
    required this.sourceCount,
    required this.isRepresentative,
    required this.isLast,
  });

  final NewsClusterCandidate item;
  final int sourceCount;
  final bool isRepresentative;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isRepresentative
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary, width: 2),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 154, color: colors.outlineVariant),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                key: ValueKey<String>('olay-haberi-${item.stableId}'),
                onTap: () => _openNews(context),
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.sourceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dateLabel(item.publishedAt),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isRepresentative) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'ANA HABER',
                            style: TextStyle(
                              color: colors.onSecondaryContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 14.5,
                          height: 1.32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.originalTitle.trim().isNotEmpty &&
                          item.originalTitle.trim() != item.title.trim()) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Orijinal: ${item.originalTitle.trim()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Haberi aç',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openNews(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HaberDetaySayfasi(
          id: item.stableId,
          title: item.title,
          imageUrl: item.imageUrl,
          source: item.sourceLabel,
          publishedAt: item.publishedAt ?? DateTime.now(),
          hasValidPublishedAt: item.publishedAt != null,
          summary: item.summary,
          articleText: item.articleText,
          url: item.url,
          category: item.category,
          feedSource: item.feedSource,
          sourceCount: sourceCount,
          confirmingSourceCount: (sourceCount - 1).clamp(0, 998),
        ),
      ),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Tarih bilinmiyor';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} • $hour:$minute';
  }
}
