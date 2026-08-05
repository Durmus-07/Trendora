import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/smart_notification_engine.dart';
import 'core/personalization/personalization_storage.dart';

class BildirimAyarlariSayfasi extends StatefulWidget {
  const BildirimAyarlariSayfasi({
    super.key,
    this.notificationPermissionRequester,
  });

  final Future<bool> Function()? notificationPermissionRequester;

  @override
  State<BildirimAyarlariSayfasi> createState() =>
      _BildirimAyarlariSayfasiState();
}

class _BildirimAyarlariSayfasiState extends State<BildirimAyarlariSayfasi> {
  SmartNotificationPreferences _preferences =
      const SmartNotificationPreferences();
  SharedPreferencesSmartNotificationStore? _store;
  String? _userId;
  bool _loading = true;
  bool? _permissionAllowed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shared = await SharedPreferences.getInstance();
      final identity = PersonalizationIdentityProvider(
        SharedPreferencesPersonalizationStore(shared),
      );
      final userId = await identity.resolve();
      final store = SharedPreferencesSmartNotificationStore(shared);
      final preferences = await store.loadPreferences(userId);
      bool? permissionAllowed;
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        final android = plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        permissionAllowed = await android?.areNotificationsEnabled();
      } catch (_) {
        // İzin durumu okunamasa da kayıtlı kullanıcı tercihleri yüklenir.
      }
      if (!mounted) return;
      setState(() {
        _store = store;
        _userId = userId;
        _preferences = preferences;
        _permissionAllowed = permissionAllowed;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled) {
      final allowed = await _requestNotificationPermission();
      if (!allowed) {
        _showPermissionDenied();
        return;
      }
      if (mounted) setState(() => _permissionAllowed = true);
    }
    await _save(_preferences.copyWith(enabled: enabled));
  }

  Future<void> _enableAllSupported() async {
    final allowed = await _requestNotificationPermission();
    if (!allowed) {
      _showPermissionDenied();
      return;
    }
    if (mounted) setState(() => _permissionAllowed = true);
    await _save(
      _preferences.copyWith(
        enabled: true,
        categories: supportedSmartNotificationCategories,
      ),
    );
  }

  Future<bool> _requestNotificationPermission() async {
    final requester = widget.notificationPermissionRequester;
    if (requester != null) return requester();
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  void _showPermissionDenied() {
    if (!mounted) return;
    setState(() => _permissionAllowed = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bildirim izni kapalı. Sistem ayarlarından izin verebilirsin.',
        ),
      ),
    );
  }

  Future<void> _toggleCategory(
    SmartNotificationCategory category,
    bool enabled,
  ) async {
    final categories = {..._preferences.categories};
    enabled ? categories.add(category) : categories.remove(category);
    await _save(_preferences.copyWith(categories: categories));
  }

  Future<void> _save(SmartNotificationPreferences value) async {
    final store = _store;
    final userId = _userId;
    if (store == null || userId == null) return;
    try {
      await store.savePreferences(userId, value);
      if (mounted) setState(() => _preferences = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim tercihleri kaydedilemedi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(title: const Text('Akıllı Bildirimler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: Icon(
                    _permissionAllowed == false
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  title: const Text('Sistem bildirim izni'),
                  subtitle: Text(
                    _permissionAllowed == true
                        ? 'İzin verildi'
                        : _permissionAllowed == false
                        ? 'İzin verilmedi'
                        : 'Bu platformda durum doğrulanamadı',
                  ),
                ),
                SwitchListTile(
                  value: _preferences.enabled,
                  onChanged: _setEnabled,
                  title: const Text('Akıllı bildirimleri aç'),
                  subtitle: const Text(
                    'Yalnızca önemli gelişmeler toplu ve kontrollü bildirilir.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.done_all_rounded),
                  title: const Text('Desteklenen tüm bildirimleri aç'),
                  subtitle: const Text(
                    'Yalnızca gerçek olay üreten kategorileri etkinleştirir.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _enableAllSupported,
                ),
                const Divider(),
                for (final category in supportedSmartNotificationCategories)
                  SwitchListTile(
                    value: _preferences.categories.contains(category),
                    onChanged: _preferences.enabled
                        ? (value) => _toggleCategory(category, value)
                        : null,
                    title: Text(_label(category)),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Küçük fiyat hareketleri bildirilmez. Bildirimler yatırım veya satın alma tavsiyesi değildir.',
                  style: TextStyle(color: Colors.white54, height: 1.4),
                ),
              ],
            ),
    );
  }

  static String _label(SmartNotificationCategory category) =>
      switch (category) {
        SmartNotificationCategory.breakingNews => 'Son dakika haberleri',
        SmartNotificationCategory.importantNews => 'Önemli haberler',
        SmartNotificationCategory.followedAssets => 'Takip edilen varlıklar',
        SmartNotificationCategory.marketAlerts => 'Piyasa alarmları',
        SmartNotificationCategory.newOpportunities => 'Yeni fırsatlar',
        SmartNotificationCategory.followedStores => 'Takip edilen mağazalar',
        SmartNotificationCategory.savedContentChanges =>
          'Kaydedilen içerik değişiklikleri',
        SmartNotificationCategory.dailyDigest => 'Günlük kişisel özet',
        SmartNotificationCategory.weatherAlerts => 'Hava uyarıları',
        SmartNotificationCategory.announcements => 'Trendora duyuruları',
        SmartNotificationCategory.finance => 'Finans ve takip listesi',
        SmartNotificationCategory.company => 'KAP ve şirket gelişmeleri',
        SmartNotificationCategory.news => 'Önemli haberler',
        SmartNotificationCategory.opportunities => 'Fırsatlar ve kampanyalar',
        SmartNotificationCategory.weather => 'Hava uyarıları',
        SmartNotificationCategory.reminders => 'Hatırlatmalar',
      };
}
