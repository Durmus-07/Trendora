import 'package:flutter/material.dart';

import 'core/daily_digest/daily_digest_models.dart';
import 'firsatlar_sayfasi.dart';
import 'haber_detay_sayfasi.dart';
import 'hava_merkezi_sayfasi.dart';
import 'trend_tahmini_sayfasi.dart';

Future<bool> openDailyDigestItem(
  BuildContext context,
  DailyDigestItem item,
) async {
  switch (item.itemType ?? item.category.name) {
    case 'news':
      return _openNews(context, item);
    case 'opportunity':
      return _openOpportunity(context, item);
    case 'asset':
    case 'analysis':
    case 'finance':
    case 'savedAnalyses':
      final query =
          (item.canonicalSymbol ??
                  item.targetArguments?['query']?.toString() ??
                  item.reference)
              .trim();
      if (query.isEmpty) return false;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrendTahminiSayfasi(
            initialQuery: '$query güncel durumu ve olasılık analizi',
            autoAnalyze: true,
          ),
        ),
      );
      return true;
    case 'weather':
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HavaMerkeziSayfasi()),
      );
      return true;
    default:
      return false;
  }
}

Future<bool> _openNews(BuildContext context, DailyDigestItem item) async {
  final data = item.snapshot ?? const <String, dynamic>{};
  final id = (item.itemId ?? '${data['id'] ?? ''}').trim();
  final url = (item.originalUrl ?? '${data['url'] ?? data['link'] ?? ''}')
      .trim();
  final title = '${data['title'] ?? item.title}'.trim();
  final source = '${data['source'] ?? data['feedSource'] ?? item.source}'
      .trim();
  if (id.isEmpty && item.normalizedUrl?.isNotEmpty != true && url.isEmpty) {
    return false;
  }
  if (title.isEmpty || source.isEmpty) return false;
  final publishedAt =
      DateTime.tryParse(
        '${data['publishedAt'] ?? data['updatedAt'] ?? item.dataTime ?? item.updatedAt}',
      ) ??
      item.updatedAt;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HaberDetaySayfasi(
        id: id,
        title: title,
        imageUrl: '${data['imageUrl'] ?? data['image'] ?? ''}',
        source: source,
        publishedAt: publishedAt,
        summary: '${data['summary'] ?? data['description'] ?? item.detail}',
        articleText: '${data['articleText'] ?? data['content'] ?? ''}',
        url: url,
        category: '${data['category'] ?? ''}',
        feedSource: '${data['feedSource'] ?? ''}',
        isBreaking: data['isBreaking'] == true,
      ),
    ),
  );
  return true;
}

Future<bool> _openOpportunity(
  BuildContext context,
  DailyDigestItem item,
) async {
  final data = item.snapshot;
  if (data == null || data.isEmpty) return false;
  final identity =
      (item.opportunityId ?? item.itemId ?? item.normalizedUrl ?? '').trim();
  if (identity.isEmpty) return false;
  final opportunity = FirsatModeli.fromJson(data);
  if (opportunity.baslik.trim().isEmpty) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF4F6FA),
    builder: (sheetContext) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            if (item.currentStatus == 'expired')
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Bu fırsat sona ermiş olabilir. Son kayıtlı bilgi gösteriliyor.',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            FirsatKarti(firsat: opportunity),
          ],
        ),
      ),
    ),
  );
  return true;
}
