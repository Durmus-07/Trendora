import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/news/news_explanation_service.dart';

void main() {
  test('explains only concepts present in the news with cautious effects', () {
    final service = NewsExplanationService();

    final result = service.explain(
      newsId: 'finance-news',
      title: 'FED faiz kararı sonrası NASDAQ, DXY ve altın gündemde',
      summary: 'ABD Merkez Bankası enflasyon verilerini değerlendirdi.',
      articleText: 'S&P 500 şirketleri kararı yakından izliyor.',
      category: 'ekonomi',
    );

    expect(
      result.concepts.map((concept) => concept.term),
      containsAll(['FED', 'NASDAQ', 'S&P 500', 'Enflasyon', 'Faiz']),
    );
    expect(result.concepts, hasLength(5));
    expect(result.possibleEffects, isNotEmpty);
    expect(
      result.possibleEffects.every(
        (effect) =>
            effect.startsWith('Olası') || effect.startsWith('Genellikle'),
      ),
      isTrue,
    );
  });

  test('does not invent concepts or effects for an unrelated news item', () {
    final service = NewsExplanationService();

    final result = service.explain(
      newsId: 'sport-news',
      title: 'Takım yeni sezon hazırlıklarına başladı',
      summary: 'Oyuncular ilk antrenmana çıktı.',
      articleText: 'Teknik ekip çalışma programını duyurdu.',
      category: 'spor',
    );

    expect(result.isEmpty, isTrue);
    expect(result.concepts, isEmpty);
    expect(result.possibleEffects, isEmpty);
  });

  test('reuses cached explanation and keeps the cache bounded', () {
    final service = NewsExplanationService(maximumCacheItems: 2);

    NewsExplanation explain(String id, String title) {
      return service.explain(
        newsId: id,
        title: title,
        summary: '',
        articleText: '',
        category: 'ekonomi',
      );
    }

    final first = explain('a', 'FED faiz kararı');
    final cached = explain('a', 'FED faiz kararı');
    expect(identical(first, cached), isTrue);

    explain('b', 'BIST bilanço açıklaması');
    explain('c', 'Brent petrol fiyatı');
    expect(service.cachedItemCount, 2);

    final regenerated = explain('a', 'FED faiz kararı');
    expect(identical(first, regenerated), isFalse);
    expect(service.cachedItemCount, 2);
  });

  test('generated copy never contains investment instruction language', () {
    final service = NewsExplanationService();
    final result = service.explain(
      newsId: 'all-finance-terms',
      title: 'FED ECB TCMB BIST NASDAQ S&P 500 gündemi',
      summary:
          'Enflasyon faiz tahvil CDS DXY altın petrol Brent Bitcoin Ethereum',
      articleText:
          'KAP SPK BDDK bilanço temettü geri alım sermaye artırımı açıklandı.',
      category: 'ekonomi',
    );
    final output = [
      for (final concept in result.concepts) ...[
        concept.term,
        concept.explanation,
      ],
      ...result.possibleEffects,
      NewsExplanation.disclaimer,
    ].join(' ').toLowerCase();

    expect(
      RegExp(r'(^|\s)(al|sat|tut)(\s|[.!?,;:]|$)').hasMatch(output),
      isFalse,
    );
    expect(output, isNot(contains('kesin yükselecek')));
    expect(output, isNot(contains('kesin düşecek')));
    expect(output, contains('yatırım tavsiyesi değildir'));
  });
}
