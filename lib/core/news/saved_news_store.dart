import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedNews {
  const SavedNews({
    required this.id,
    required this.title,
    required this.summary,
    required this.articleText,
    required this.imageUrl,
    required this.url,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String articleText;
  final String imageUrl;
  final String url;
  final String source;
  final String category;
  final DateTime publishedAt;
  final DateTime savedAt;

  factory SavedNews.fromJson(Map<String, dynamic> json) {
    return SavedNews(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      articleText: json['articleText']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'articleText': articleText,
    'imageUrl': imageUrl,
    'url': url,
    'source': source,
    'category': category,
    'publishedAt': publishedAt.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
  };
}

class SavedNewsStore {
  SavedNewsStore._();

  static const String storageKey = 'trendora_saved_news_v1';
  static const int _maximumItemCount = 100;

  static Future<List<SavedNews>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => SavedNews.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isSaved(String id) async {
    if (id.trim().isEmpty) return false;
    return (await load()).any((item) => item.id == id);
  }

  static Future<bool> toggle(SavedNews item) async {
    final items = await load();
    final existingIndex = items.indexWhere((saved) => saved.id == item.id);

    if (existingIndex >= 0) {
      items.removeAt(existingIndex);
      await _saveAll(items);
      return false;
    }

    await _saveAll([item, ...items]);
    return true;
  }

  static Future<void> _saveAll(List<SavedNews> items) async {
    final preferences = await SharedPreferences.getInstance();
    final limited = items
        .take(_maximumItemCount)
        .map((item) => item.toJson())
        .toList(growable: false);
    await preferences.setString(storageKey, jsonEncode(limited));
  }
}
