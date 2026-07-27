import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/smart_notification_engine.dart';
import 'core/personalization/personalization_storage.dart';

class BildirimAyarlariSayfasi extends StatefulWidget {
  const BildirimAyarlariSayfasi({super.key});

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
      if (!mounted) return;
      setState(() {
        _store = store;
        _userId = userId;
        _preferences = preferences;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.requestNotificationsPermission() ?? true;
      if (!allowed) return;
    }
    final categories = enabled && _preferences.categories.isEmpty
        ? SmartNotificationCategory.values.toSet()
        : _preferences.categories;
    await _save(
      _preferences.copyWith(enabled: enabled, categories: categories),
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
                SwitchListTile(
                  value: _preferences.enabled,
                  onChanged: _setEnabled,
                  title: const Text('Akıllı bildirimleri aç'),
                  subtitle: const Text(
                    'Yalnızca önemli gelişmeler toplu ve kontrollü bildirilir.',
                  ),
                ),
                const Divider(),
                for (final category in SmartNotificationCategory.values)
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
        SmartNotificationCategory.finance => 'Finans ve takip listesi',
        SmartNotificationCategory.company => 'KAP ve şirket gelişmeleri',
        SmartNotificationCategory.news => 'Önemli haberler',
        SmartNotificationCategory.opportunities => 'Fırsatlar ve kampanyalar',
        SmartNotificationCategory.weather => 'Hava uyarıları',
        SmartNotificationCategory.reminders => 'Hatırlatmalar',
      };
}
