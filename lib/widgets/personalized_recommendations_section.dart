import 'package:flutter/material.dart';

import '../core/personalization/personalization_service.dart';
import '../core/personalization/personalization_storage.dart';
import '../core/recommendations/recommendation_service.dart';
import '../theme/trendora_theme.dart';

class PersonalizedRecommendationsSection extends StatefulWidget {
  const PersonalizedRecommendationsSection({
    super.key,
    required this.onOpenNews,
    required this.onOpenOpportunities,
    required this.onOpenFinance,
    this.loadRecommendations,
  });

  final VoidCallback onOpenNews;
  final VoidCallback onOpenOpportunities;
  final ValueChanged<String> onOpenFinance;
  final Future<RecommendationBundle> Function()? loadRecommendations;

  @override
  State<PersonalizedRecommendationsSection> createState() =>
      _PersonalizedRecommendationsSectionState();
}

class _PersonalizedRecommendationsSectionState
    extends State<PersonalizedRecommendationsSection> {
  RecommendationBundle _bundle = const RecommendationBundle();
  PersonalizationService? _personalizationService;
  RecommendationFeedbackStore? _feedbackStore;
  String? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final injectedLoader = widget.loadRecommendations;
      if (injectedLoader != null) {
        final bundle = await injectedLoader();
        if (!mounted) return;
        setState(() {
          _bundle = bundle;
          _loading = false;
        });
        return;
      }
      final storage = await SharedPreferencesPersonalizationStore.create();
      final personalization = PersonalizationService(
        repository: PersonalizationLocalRepository(storage),
        identityProvider: PersonalizationIdentityProvider(storage),
      );
      final preferences = await personalization.initialize();
      if (!preferences.personalizationEnabled) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final feedbackStore = await RecommendationFeedbackStore.create();
      final feedback = feedbackStore.load(preferences.userId);
      final bundle = await RecommendationService(
        dataSource: ApiRecommendationDataSource(),
      ).load(preferences, feedback: feedback);
      if (!mounted) return;
      setState(() {
        _personalizationService = personalization;
        _feedbackStore = feedbackStore;
        _userId = preferences.userId;
        _bundle = bundle;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(
    RecommendationItem item,
    _RecommendationAction action,
  ) async {
    final userId = _userId;
    final feedback = _feedbackStore;
    final personalization = _personalizationService;
    if (userId == null || feedback == null || personalization == null) return;

    try {
      switch (action) {
        case _RecommendationAction.interested:
          await feedback.markInterested(userId, item.id);
          _message('Bu öneriyi beğendiğin kaydedildi.');
        case _RecommendationAction.notInterested:
          await feedback.hide(userId, item.id);
          _remove(item.id);
        case _RecommendationAction.save:
          await personalization.update((current) {
            return switch (item.type) {
              RecommendationType.news => current.copyWith(
                savedNewsIds: {...current.savedNewsIds, item.reference},
              ),
              RecommendationType.opportunity => current.copyWith(
                savedOpportunityIds: {
                  ...current.savedOpportunityIds,
                  item.reference,
                },
              ),
              RecommendationType.finance => current.copyWith(
                trackedFinancialAssets: {
                  ...current.trackedFinancialAssets,
                  item.reference,
                },
              ),
            };
          });
          _message('Öneri kaydedildi.');
        case _RecommendationAction.follow:
          await personalization.update((current) {
            if (item.type == RecommendationType.finance) {
              return current.copyWith(
                trackedFinancialAssets: {
                  ...current.trackedFinancialAssets,
                  item.reference,
                },
              );
            }
            return current.copyWith(
              notificationCategories: {
                ...current.notificationCategories,
                item.type.name,
              },
            );
          });
          _message('Takip tercihin kaydedildi.');
        case _RecommendationAction.remindLater:
          await feedback.remindLater(userId, item.id);
          _remove(item.id);
          _message('Bir gün sonra yeniden gösterilecek.');
        case _RecommendationAction.reduce:
          await feedback.reduceType(userId, item.type);
          _removeType(item.type);
          _message('Bu tür önerilerin önceliği azaltıldı.');
      }
    } catch (_) {
      _message('İşlem kaydedilemedi; uygulamayı kullanmaya devam edebilirsin.');
    }
  }

  void _open(RecommendationItem item) {
    switch (item.type) {
      case RecommendationType.news:
        widget.onOpenNews();
      case RecommendationType.opportunity:
        widget.onOpenOpportunities();
      case RecommendationType.finance:
        widget.onOpenFinance(item.reference);
    }
  }

  void _remove(String id) {
    if (!mounted) return;
    setState(() {
      _bundle = RecommendationBundle(
        today: _bundle.today.where((item) => item.id != id).toList(),
        forYou: _bundle.forYou.where((item) => item.id != id).toList(),
      );
    });
  }

  void _removeType(RecommendationType type) {
    if (!mounted) return;
    setState(() {
      _bundle = RecommendationBundle(
        today: _bundle.today.where((item) => item.type != type).toList(),
        forYou: _bundle.forYou.where((item) => item.type != type).toList(),
      );
    });
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _bundle.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_bundle.today.isNotEmpty) ...[
          const _SectionTitle(
            title: 'BUGÜN SENİN İÇİN',
            subtitle: 'İlgi alanlarına göre güncel gelişmeler',
          ),
          const SizedBox(height: 9),
          _RecommendationList(
            items: _bundle.today,
            onOpen: _open,
            onAction: _handleAction,
          ),
        ],
        if (_bundle.today.isNotEmpty && _bundle.forYou.isNotEmpty)
          const SizedBox(height: 16),
        if (_bundle.forYou.isNotEmpty) ...[
          const _SectionTitle(
            title: 'SANA ÖNERİLER',
            subtitle: 'Seçimlerinle eşleşen diğer içerikler',
          ),
          const SizedBox(height: 9),
          _RecommendationList(
            items: _bundle.forYou,
            onOpen: _open,
            onAction: _handleAction,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TrendoraColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({
    required this.items,
    required this.onOpen,
    required this.onAction,
  });

  final List<RecommendationItem> items;
  final ValueChanged<RecommendationItem> onOpen;
  final Future<void> Function(RecommendationItem, _RecommendationAction)
  onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _RecommendationCard(
            item: item,
            onOpen: () => onOpen(item),
            onAction: (action) => onAction(item, action),
          );
        },
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final RecommendationItem item;
  final VoidCallback onOpen;
  final ValueChanged<_RecommendationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      RecommendationType.news => TrendoraColors.secondary,
      RecommendationType.opportunity => TrendoraColors.success,
      RecommendationType.finance => TrendoraColors.primary,
    };
    final icon = switch (item.type) {
      RecommendationType.news => Icons.article_outlined,
      RecommendationType.opportunity => Icons.local_offer_outlined,
      RecommendationType.finance => Icons.show_chart_rounded,
    };
    return SizedBox(
      width: 265,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101D2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<_RecommendationAction>(
                      tooltip: 'Öneri seçenekleri',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onSelected: onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _RecommendationAction.interested,
                          child: Text('İlgileniyorum'),
                        ),
                        PopupMenuItem(
                          value: _RecommendationAction.notInterested,
                          child: Text('İlgilenmiyorum'),
                        ),
                        PopupMenuItem(
                          value: _RecommendationAction.save,
                          child: Text('Kaydet'),
                        ),
                        PopupMenuItem(
                          value: _RecommendationAction.follow,
                          child: Text('Takibe al'),
                        ),
                        PopupMenuItem(
                          value: _RecommendationAction.remindLater,
                          child: Text('Daha sonra hatırlat'),
                        ),
                        PopupMenuItem(
                          value: _RecommendationAction.reduce,
                          child: Text('Bu tür önerileri azalt'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                const SizedBox(height: 5),
                Text(
                  _metadata(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _metadata(RecommendationItem item) {
    final source = item.source.isEmpty ? 'Trendora veri ağı' : item.source;
    final date = item.updatedAt?.toLocal();
    if (date == null) return source;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$source • $day.$month $hour:$minute';
  }
}

enum _RecommendationAction {
  interested,
  notInterested,
  save,
  follow,
  remindLater,
  reduce,
}
