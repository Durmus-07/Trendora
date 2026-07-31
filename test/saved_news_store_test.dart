import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/news/saved_news_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saved news store persists complete records and toggles by id',
    () async {
      final item = SavedNews(
        id: 'news-1',
        title: 'Kaydedilen haber',
        summary: 'Haber özeti',
        articleText: 'Tam haber metni',
        imageUrl: 'https://example.com/image.jpg',
        url: 'https://example.com/news-1',
        source: 'Trendora Haber',
        category: 'ekonomi',
        publishedAt: DateTime.utc(2026, 7, 29, 8),
        savedAt: DateTime.utc(2026, 7, 29, 10),
      );

      expect(await SavedNewsStore.toggle(item), isTrue);
      expect(await SavedNewsStore.isSaved('news-1'), isTrue);

      final saved = await SavedNewsStore.load();
      expect(saved, hasLength(1));
      expect(saved.single.title, item.title);
      expect(saved.single.articleText, item.articleText);
      expect(saved.single.category, item.category);

      expect(await SavedNewsStore.toggle(item), isFalse);
      expect(await SavedNewsStore.load(), isEmpty);
    },
  );

  test('saved news store tolerates unreadable legacy data', () async {
    SharedPreferences.setMockInitialValues({SavedNewsStore.storageKey: '{'});
    expect(await SavedNewsStore.load(), isEmpty);
  });
}
