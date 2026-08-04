import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/daily_digest/daily_digest_models.dart';
import '../core/daily_digest/daily_digest_service.dart';
import '../core/feature_flags.dart';
import '../core/auth/trendora_auth_service.dart';
import '../core/personalization/personalization_preferences.dart';
import '../core/personalization/personalization_service.dart';
import '../core/personalization/personalization_storage.dart';
import '../core/premium_ai/premium_ai_summary_service.dart';
import '../core/notifications/smart_notification_engine.dart';
import '../theme/trendora_theme.dart';
import 'premium_ai_digest_section.dart';

class DailyDigestDependencies {
  const DailyDigestDependencies({
    required this.personalizationService,
    required this.digestService,
  });

  final PersonalizationService personalizationService;
  final DailyDigestService digestService;

  static Future<DailyDigestDependencies> create() async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesPersonalizationStore(preferences);
    return DailyDigestDependencies(
      personalizationService: PersonalizationService(
        repository: PersonalizationLocalRepository(store),
        identityProvider: PersonalizationIdentityProvider(store),
      ),
      digestService: DailyDigestService(
        AppDailyDigestDataSource(preferences),
        DailyDigestCache(store),
      ),
    );
  }
}

class DailyDigestSection extends StatefulWidget {
  const DailyDigestSection({
    super.key,
    required this.onOpenNews,
    required this.onOpenOpportunities,
    required this.onOpenWeather,
    required this.onOpenFinance,
    this.onOpenDirectItem,
    this.onNotificationPayload,
    this.dependenciesBuilder,
    this.now,
    this.premiumAiService,
    this.premiumAiAuthService,
    this.premiumAiEnabled = FeatureFlags.premiumAiSummaryEnabled,
  });

  final VoidCallback onOpenNews;
  final VoidCallback onOpenOpportunities;
  final VoidCallback onOpenWeather;
  final ValueChanged<String> onOpenFinance;
  final Future<bool> Function(DailyDigestItem item)? onOpenDirectItem;
  final ValueChanged<String?>? onNotificationPayload;
  final Future<DailyDigestDependencies> Function()? dependenciesBuilder;
  final DateTime Function()? now;
  final PremiumAiSummaryGateway? premiumAiService;
  final TrendoraAuthGateway? premiumAiAuthService;
  final bool premiumAiEnabled;

  @override
  State<DailyDigestSection> createState() => _DailyDigestSectionState();
}

class _DailyDigestSectionState extends State<DailyDigestSection> {
  DailyDigestDependencies? _dependencies;
  PersonalizationPreferences? _preferences;
  DailyDigestSnapshot? _snapshot;
  Timer? _scheduleTimer;
  bool _initializing = true;
  bool _loadingDigest = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final dependencies =
          await (widget.dependenciesBuilder?.call() ??
              DailyDigestDependencies.create());
      final preferences = await dependencies.personalizationService
          .initialize();
      if (!mounted) return;
      setState(() {
        _dependencies = dependencies;
        _preferences = preferences;
        _initializing = false;
      });
      await _loadDueDigest();
      _scheduleNextLoad();
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _loadDueDigest() async {
    final dependencies = _dependencies;
    final preferences = _preferences;
    if (dependencies == null ||
        preferences == null ||
        !preferences.dailyDigestEnabled ||
        _loadingDigest) {
      return;
    }
    final dueAt = dependencies.digestService.scheduledAt(preferences, _now);
    if (_now.isBefore(dueAt)) return;

    setState(() => _loadingDigest = true);
    try {
      final snapshot = await dependencies.digestService.loadDue(preferences);
      if (mounted) setState(() => _snapshot = snapshot);
      if (snapshot != null) {
        await _dispatchNotifications(preferences.userId, snapshot);
      }
    } catch (_) {
      // Kaynak hatası ana sayfayı durdurmaz; mevcut özet korunur.
    } finally {
      if (mounted) setState(() => _loadingDigest = false);
    }
  }

  Future<void> _dispatchNotifications(
    String userId,
    DailyDigestSnapshot snapshot,
  ) async {
    try {
      final shared = await SharedPreferences.getInstance();
      final store = SharedPreferencesSmartNotificationStore(shared);
      final notificationPreferences = await store.loadPreferences(userId);
      if (!notificationPreferences.enabled) return;
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) =>
            widget.onNotificationPayload?.call(response.payload),
      );
      final engine = SmartNotificationEngine(
        store: store,
        gateway: LocalSmartNotificationGateway(plugin),
      );
      await engine.process(
        userId,
        DailyDigestNotificationEvents.dailySummary(snapshot),
      );
      await engine.process(
        userId,
        DailyDigestNotificationEvents.fromSnapshot(snapshot),
      );
    } catch (_) {
      // Bildirim hatası özet üretimini veya ana ekranı durdurmaz.
    }
  }

  void _scheduleNextLoad() {
    _scheduleTimer?.cancel();
    final dependencies = _dependencies;
    final preferences = _preferences;
    if (dependencies == null ||
        preferences == null ||
        !preferences.dailyDigestEnabled) {
      return;
    }
    final target = dependencies.digestService.nextScheduledAt(preferences);
    final delay = target.difference(_now);
    if (delay <= Duration.zero) return;
    _scheduleTimer = Timer(delay, () async {
      await _loadDueDigest();
      _scheduleNextLoad();
    });
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final dependencies = _dependencies;
    if (dependencies == null) return;
    final updated = await dependencies.personalizationService.update(
      (current) => current.copyWith(dailyDigestEnabled: enabled),
    );
    if (!mounted) return;
    setState(() {
      _preferences = updated;
      if (!enabled) _snapshot = null;
    });
    if (enabled) await _loadDueDigest();
    _scheduleNextLoad();
  }

  Future<void> _openSettings() async {
    final current = _preferences;
    final dependencies = _dependencies;
    if (current == null || dependencies == null) return;
    final result = await showModalBottomSheet<_DigestSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TrendoraColors.backgroundSoft,
      builder: (context) => _DigestSettingsSheet(preferences: current),
    );
    if (result == null) return;

    final updated = await dependencies.personalizationService.update(
      (preferences) => preferences.copyWith(
        dailyDigestEnabled: result.enabled,
        digestPeriod: result.period,
        digestTime: result.time,
        digestCategories: result.categories,
      ),
    );
    if (!mounted) return;
    setState(() {
      _preferences = updated;
      _snapshot = null;
    });
    if (updated.dailyDigestEnabled) await _loadDueDigest();
    _scheduleNextLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    final preferences = _preferences;
    if (preferences == null) return const SizedBox.shrink();

    final grouped = <DailyDigestCategory, List<DailyDigestItem>>{};
    for (final item in _snapshot?.items ?? const <DailyDigestItem>[]) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TrendoraColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: TrendoraColors.accent.withValues(alpha: 0.28),
        ),
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
                  color: TrendoraColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.wb_twilight_rounded,
                  color: TrendoraColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GÜNLÜK KİŞİSEL ÖZET',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: TrendoraColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.05,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Gerçek ve güncel verilerden, yapay zekâ kullanmadan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 9.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Günlük özet ayarları',
                onPressed: _openSettings,
                icon: const Icon(
                  Icons.tune_rounded,
                  color: TrendoraColors.textSecondary,
                  size: 20,
                ),
              ),
              Switch.adaptive(
                value: preferences.dailyDigestEnabled,
                onChanged: _toggleEnabled,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            _statusText(preferences),
            style: const TextStyle(
              color: TrendoraColors.textSecondary,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          if (_loadingDigest) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (preferences.dailyDigestEnabled && grouped.isNotEmpty) ...[
            const SizedBox(height: 13),
            for (final category in DailyDigestCategory.values)
              if (grouped[category]?.isNotEmpty == true) ...[
                _DigestGroup(
                  category: category,
                  items: grouped[category]!,
                  onOpen: _openItem,
                ),
                if (category != grouped.keys.last) const SizedBox(height: 10),
              ],
          ],
          if (preferences.dailyDigestEnabled &&
              _snapshot?.statistics.isEmpty == false) ...[
            const SizedBox(height: 13),
            _DigestStatistics(
              statistics: _snapshot!.statistics,
              onOpenNews: widget.onOpenNews,
            ),
          ],
          PremiumAiDigestSection(
            snapshot: _snapshot,
            enabled: widget.premiumAiEnabled,
            service: widget.premiumAiService,
            authService: widget.premiumAiAuthService,
          ),
        ],
      ),
    );
  }

  String _statusText(PersonalizationPreferences preferences) {
    if (!preferences.dailyDigestEnabled) {
      return 'Özet kapalı. Açılana kadar veri isteği veya zamanlanmış işlem yapılmaz.';
    }
    final period = preferences.digestPeriod == DailyDigestPeriod.morning
        ? 'Sabah'
        : 'Akşam';
    if (_snapshot == null) {
      final dueAt = _dependencies!.digestService.scheduledAt(preferences, _now);
      if (_now.isBefore(dueAt)) {
        return '$period özeti bugün ${preferences.digestTime} saatinde hazırlanacak.';
      }
      return _loadingDigest
          ? '$period özeti hazırlanıyor…'
          : 'Güncel özet içeriği bulunamadı.';
    }
    if (_snapshot!.isEmpty) {
      return 'Seçili kategorilerde güncel ve doğrulanmış yeni içerik bulunamadı.';
    }
    return '$period özeti • ${preferences.digestTime} • ${_timeLabel(_snapshot!.generatedAt)} güncellendi';
  }

  Future<void> _openItem(DailyDigestItem item) async {
    if (await widget.onOpenDirectItem?.call(item) == true) return;
    switch (item.category) {
      case DailyDigestCategory.news:
        widget.onOpenNews();
      case DailyDigestCategory.opportunities:
        widget.onOpenOpportunities();
      case DailyDigestCategory.weather:
        widget.onOpenWeather();
      case DailyDigestCategory.finance:
      case DailyDigestCategory.savedAnalyses:
        widget.onOpenFinance(item.reference);
      case DailyDigestCategory.payments:
      case DailyDigestCategory.reminders:
        break;
    }
  }

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DigestStatistics extends StatelessWidget {
  const _DigestStatistics({required this.statistics, required this.onOpenNews});

  final DailyDigestStatistics statistics;
  final VoidCallback onOpenNews;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, int, IconData, VoidCallback?)>[
      if (statistics.savedAssetCount > 0)
        (
          'Kaydedilen varlık',
          statistics.savedAssetCount,
          Icons.star_outline,
          null,
        ),
      if (statistics.savedAnalysisCount > 0)
        (
          'Kaydedilen analiz',
          statistics.savedAnalysisCount,
          Icons.bookmark_outline,
          null,
        ),
      if (statistics.savedNewsCount > 0)
        (
          'Kaydedilen haber',
          statistics.savedNewsCount,
          Icons.article_outlined,
          onOpenNews,
        ),
      if (statistics.updatedLast24HoursCount > 0)
        (
          '24 saatte güncellenen',
          statistics.updatedLast24HoursCount,
          Icons.update_rounded,
          null,
        ),
      if (statistics.priceChangedCount > 0)
        (
          'Fiyatı değişen',
          statistics.priceChangedCount,
          Icons.swap_vert_rounded,
          null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KAYDEDİLENLER',
          style: TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map(
                (entry) => ActionChip(
                  avatar: Icon(entry.$3, size: 15),
                  label: Text('${entry.$1}: ${entry.$2}'),
                  onPressed: entry.$4,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _DigestGroup extends StatelessWidget {
  const _DigestGroup({
    required this.category,
    required this.items,
    required this.onOpen,
  });

  final DailyDigestCategory category;
  final List<DailyDigestItem> items;
  final ValueChanged<DailyDigestItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TrendoraColors.backgroundSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TrendoraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _categoryIcon(category),
                color: _categoryColor(category),
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _categoryLabel(category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TrendoraColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < items.length; index++) ...[
            _DigestItemTile(
              item: items[index],
              onTap: () => onOpen(items[index]),
            ),
            if (index != items.length - 1)
              const Divider(height: 15, color: TrendoraColors.border),
          ],
        ],
      ),
    );
  }
}

class _DigestItemTile extends StatelessWidget {
  const _DigestItemTile({required this.item, required this.onTap});

  final DailyDigestItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TrendoraColors.textPrimary,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 9.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${item.source} • ${_dateLabel(item.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.chevron_right_rounded,
              color: TrendoraColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DigestSettings {
  const _DigestSettings({
    required this.enabled,
    required this.period,
    required this.time,
    required this.categories,
  });

  final bool enabled;
  final DailyDigestPeriod period;
  final String time;
  final Set<DailyDigestCategory> categories;
}

class _DigestSettingsSheet extends StatefulWidget {
  const _DigestSettingsSheet({required this.preferences});

  final PersonalizationPreferences preferences;

  @override
  State<_DigestSettingsSheet> createState() => _DigestSettingsSheetState();
}

class _DigestSettingsSheetState extends State<_DigestSettingsSheet> {
  late bool _enabled;
  late DailyDigestPeriod _period;
  late String _time;
  late Set<DailyDigestCategory> _categories;

  @override
  void initState() {
    super.initState();
    _enabled = widget.preferences.dailyDigestEnabled;
    _period = widget.preferences.digestPeriod;
    _time = widget.preferences.digestTime;
    _categories = {...widget.preferences.digestCategories};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Günlük Kişisel Özet',
                style: TextStyle(
                  color: TrendoraColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Yalnızca gerçek ve güncel kayıtlar gösterilir.',
                style: TextStyle(color: TrendoraColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Günlük özeti aç'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Sabah'),
                    selected: _period == DailyDigestPeriod.morning,
                    onSelected: (_) => setState(() {
                      _period = DailyDigestPeriod.morning;
                      _time = '09:00';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Akşam'),
                    selected: _period == DailyDigestPeriod.evening,
                    onSelected: (_) => setState(() {
                      _period = DailyDigestPeriod.evening;
                      _time = '19:00';
                    }),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_time),
                    onPressed: _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'ÖZET KATEGORİLERİ',
                style: TextStyle(
                  color: TrendoraColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 7),
              for (final category in DailyDigestCategory.values)
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    _categoryIcon(category),
                    color: _categoryColor(category),
                  ),
                  title: Text(_categoryLabel(category)),
                  value: _categories.contains(category),
                  onChanged: (selected) => setState(() {
                    if (selected) {
                      _categories.add(category);
                    } else {
                      _categories.remove(category);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _DigestSettings(
                      enabled: _enabled,
                      period: _period,
                      time: _time,
                      categories: Set.unmodifiable(_categories),
                    ),
                  ),
                  child: const Text('Tercihleri Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _time =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    });
  }
}

String _categoryLabel(DailyDigestCategory category) {
  return switch (category) {
    DailyDigestCategory.finance => 'Takip edilen varlıklar',
    DailyDigestCategory.news => 'Önemli haberler',
    DailyDigestCategory.opportunities => 'Yeni fırsatlar',
    DailyDigestCategory.weather => 'Hava durumu ve uyarılar',
    DailyDigestCategory.payments => 'Yaklaşan ödemeler',
    DailyDigestCategory.reminders => 'Hatırlatmalar',
    DailyDigestCategory.savedAnalyses => 'Kaydedilen analiz değişiklikleri',
  };
}

IconData _categoryIcon(DailyDigestCategory category) {
  return switch (category) {
    DailyDigestCategory.finance => Icons.show_chart_rounded,
    DailyDigestCategory.news => Icons.article_outlined,
    DailyDigestCategory.opportunities => Icons.local_offer_outlined,
    DailyDigestCategory.weather => Icons.cloud_outlined,
    DailyDigestCategory.payments => Icons.receipt_long_outlined,
    DailyDigestCategory.reminders => Icons.event_note_outlined,
    DailyDigestCategory.savedAnalyses => Icons.bookmark_added_outlined,
  };
}

Color _categoryColor(DailyDigestCategory category) {
  return switch (category) {
    DailyDigestCategory.finance => TrendoraColors.primary,
    DailyDigestCategory.news => TrendoraColors.secondary,
    DailyDigestCategory.opportunities => TrendoraColors.success,
    DailyDigestCategory.weather => const Color(0xFF6EE7F9),
    DailyDigestCategory.payments => TrendoraColors.accent,
    DailyDigestCategory.reminders => const Color(0xFFFF9A76),
    DailyDigestCategory.savedAnalyses => const Color(0xFFB9A7FF),
  };
}
