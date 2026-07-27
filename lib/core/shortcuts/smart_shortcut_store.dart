import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SmartShortcutDefinition {
  const SmartShortcutDefinition({
    required this.id,
    required this.label,
    required this.command,
  });

  final String id;
  final String label;
  final String command;
}

class SmartShortcutCatalog {
  SmartShortcutCatalog._();

  static const List<SmartShortcutDefinition> all = [
    SmartShortcutDefinition(
      id: 'gold',
      label: 'Altın',
      command: 'Bugün altın ne kadar?',
    ),
    SmartShortcutDefinition(id: 'fx', label: 'Döviz', command: 'Dolar kaç TL?'),
    SmartShortcutDefinition(
      id: 'watchlist',
      label: 'Takip Listem',
      command: 'Takip ettiğim hisseleri göster.',
    ),
    SmartShortcutDefinition(
      id: 'stock_search',
      label: 'Hisse Ara',
      command: 'Bir hisse ara.',
    ),
    SmartShortcutDefinition(
      id: 'news',
      label: 'Günün Haberleri',
      command: 'Bugün önemli ekonomi haberleri neler?',
    ),
    SmartShortcutDefinition(
      id: 'opportunities',
      label: 'Fırsatlar',
      command: 'Bugünkü fırsatları göster.',
    ),
    SmartShortcutDefinition(
      id: 'weather',
      label: 'Hava',
      command: 'Bugün yağmur yağacak mı?',
    ),
    SmartShortcutDefinition(
      id: 'reminders',
      label: 'Hatırlatmalarım',
      command: 'Hatırlatmalarımı göster.',
    ),
    SmartShortcutDefinition(
      id: 'for_you',
      label: 'Bugün Senin İçin',
      command: 'Bugün benim için önemli olanları göster.',
    ),
  ];

  static SmartShortcutDefinition? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class SmartShortcutStore {
  SmartShortcutStore(this._preferences);

  static const String _prefix = 'trendora_shortcut_order_v1_';
  final SharedPreferences _preferences;

  List<SmartShortcutDefinition> load(String userId) {
    final saved = _preferences.getStringList(_key(userId)) ?? const [];
    final ordered = <SmartShortcutDefinition>[];
    final seen = <String>{};
    for (final id in saved) {
      final item = SmartShortcutCatalog.byId(id);
      if (item != null && seen.add(item.id)) ordered.add(item);
    }
    for (final item in SmartShortcutCatalog.all) {
      if (seen.add(item.id)) ordered.add(item);
    }
    return ordered;
  }

  Future<void> save(String userId, List<SmartShortcutDefinition> items) async {
    await _preferences.setStringList(
      _key(userId),
      items.map((item) => item.id).toList(growable: false),
    );
  }

  static String _key(String userId) =>
      '$_prefix${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';
}
