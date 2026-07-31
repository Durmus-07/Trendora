import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/news/news_preview_image_service.dart';

void main() {
  final baseUri = Uri.parse('https://example.com/news/article');

  test(
    'preview metadata follows OpenGraph Twitter and Schema.org priority',
    () {
      const html = '''
      <meta name="twitter:image" content="https://cdn.example.com/twitter.jpg">
      <meta property="og:image" content="https://cdn.example.com/open-graph.jpg">
      <script type="application/ld+json">
        {"@type":"NewsArticle","image":"https://cdn.example.com/schema.jpg"}
      </script>
    ''';

      expect(
        extractNewsPreviewImage(html, baseUri),
        'https://cdn.example.com/open-graph.jpg',
      );
    },
  );

  test('Twitter Card is used when OpenGraph is absent', () {
    const html = '''
      <meta content="/images/twitter-card.jpg" name="twitter:image:src">
      <script type="application/ld+json">
        {"image":"https://cdn.example.com/schema.jpg"}
      </script>
    ''';

    expect(
      extractNewsPreviewImage(html, baseUri),
      'https://example.com/images/twitter-card.jpg',
    );
  });

  test('Schema.org image object is the final metadata fallback', () {
    const html = '''
      <script type="application/ld+json">
        {
          "@context":"https://schema.org",
          "@type":"NewsArticle",
          "image":{"@type":"ImageObject","contentUrl":"/schema/cover.webp"}
        }
      </script>
    ''';

    expect(
      extractNewsPreviewImage(html, baseUri),
      'https://example.com/schema/cover.webp',
    );
  });

  test('unsafe or missing preview URLs return null', () {
    expect(
      extractNewsPreviewImage(
        '<meta property="og:image" content="data:image/png;base64,abc">',
        baseUri,
      ),
      isNull,
    );
    expect(extractNewsPreviewImage('<html></html>', baseUri), isNull);
  });
}
