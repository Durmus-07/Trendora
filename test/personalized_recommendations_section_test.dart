import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/recommendations/recommendation_service.dart';
import 'package:trendora_app/widgets/personalized_recommendations_section.dart';

void main() {
  testWidgets('shows both sections only when real items exist', (tester) async {
    var newsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedRecommendationsSection(
            onOpenNews: () => newsOpened = true,
            onOpenOpportunities: () {},
            onOpenFinance: (_) {},
            loadRecommendations: () async => RecommendationBundle(
              today: [_item('today', RecommendationType.news)],
              forYou: [_item('other', RecommendationType.opportunity)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SANA ÖZEL ÖNERİLER'));
    await tester.pumpAndSettle();

    expect(find.text('BUGÜN SENİN İÇİN'), findsOneWidget);
    expect(find.text('SANA ÖNERİLER'), findsOneWidget);
    expect(find.text('Gerçek içerik today'), findsOneWidget);

    await tester.tap(find.text('Gerçek içerik today'));
    expect(newsOpened, isTrue);
  });

  testWidgets('renders no empty recommendation cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedRecommendationsSection(
            onOpenNews: () {},
            onOpenOpportunities: () {},
            onOpenFinance: (_) {},
            loadRecommendations: () async => const RecommendationBundle(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BUGÜN SENİN İÇİN'), findsNothing);
    expect(find.text('SANA ÖNERİLER'), findsNothing);
  });
}

RecommendationItem _item(String id, RecommendationType type) {
  return RecommendationItem(
    id: id,
    type: type,
    title: 'Gerçek içerik $id',
    description: 'Gerçek veri açıklaması',
    reason: 'İlgi alanınla eşleşiyor',
    source: 'Test kaynağı',
    updatedAt: DateTime.utc(2026, 7, 27),
    score: 90,
    reference: id,
  );
}
