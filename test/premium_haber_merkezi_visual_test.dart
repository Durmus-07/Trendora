import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/haberler_sayfasi.dart';

void main() {
  testWidgets('premium news center keeps its compact phone layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final news = [
      TrendoraHaber(
        id: 'visual-hero',
        title: 'Piyasaların yönünü belirleyecek karar açıklandı',
        description:
            'Ekonomi yönetiminin yeni adımları yatırımcılar tarafından izleniyor.',
        content: List.filled(390, 'piyasa').join(' '),
        url: 'https://example.com/visual-hero',
        imageUrl: '',
        source: 'Trendora Finans',
        feedSource: 'Ekonomi Akışı',
        category: 'ekonomi',
        publishedAt: now.subtract(const Duration(minutes: 12)),
        isBreaking: true,
        trendScore: 94,
        confidenceScore: 96,
        sourceCount: 4,
        confirmingSources: const [
          'Trendora Finans',
          'AA',
          'Reuters',
          'Bloomberg',
        ],
      ),
      TrendoraHaber(
        id: 'visual-large',
        title: 'Yapay zekâ yatırımları teknoloji sektörünü dönüştürüyor',
        description:
            'Yeni ürünler ve veri merkezi yatırımları büyümenin odağında.',
        content: 'Teknoloji haberinin ayrıntıları.',
        url: 'https://example.com/visual-large',
        imageUrl: '',
        source: 'Teknoloji Gündemi',
        feedSource: 'Teknoloji Akışı',
        category: 'teknoloji',
        publishedAt: now.subtract(const Duration(minutes: 26)),
        isBreaking: false,
        trendScore: 82,
        confidenceScore: 91,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HaberlerSayfasi.test(news: news),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(
      const ValueKey<String>('haber-kart-tipi-hero-visual-hero'),
    );
    expect(hero, findsOneWidget);
    expect(find.text('GÜNÜN ÖNE ÇIKANI'), findsOneWidget);
    expect(find.textContaining('4 güvenilir kaynak doğruladı'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

    final heroRect = tester.getRect(hero);
    expect(heroRect.width, inInclusiveRange(350, 360));
    expect(heroRect.height, greaterThan(350));
    expect(tester.takeException(), isNull);
  });
}
