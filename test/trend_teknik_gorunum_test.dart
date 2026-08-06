import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/trend_tahmini_sayfasi.dart';
import 'package:trendora_app/widgets/trendora_technical_view_card.dart';

void main() {
  Map<String, dynamic> analysisJson([Map<String, dynamic>? technical]) => {
    'query': 'TEST teknik analiz',
    'domain': 'finance',
    'category': 'Finans',
    'intent': 'technical_analysis',
    'answerTitle': 'Test Analizi',
    'directAnswer': 'Teknik görünüm oluşturuldu.',
    'summary': '',
    'confidence': 70,
    'confidenceLabel': 'Yüksek',
    if (technical != null) 'technical': technical,
  };

  Map<String, dynamic> completeTechnical() => {
    'technicalScore': '78',
    'confidenceScore': 86,
    'confidenceLevel': 'Yüksek',
    'dataSufficiency': {
      'status': 'sufficient',
      'label': 'Yeterli',
      'available': '240',
      'required': 200,
    },
    'dataPointCount': '240',
    'dataTime': '2026-07-30T09:15:00.000Z',
    'shortTermTrend': 'Güçlü Yükseliş',
    'mediumTermTrend': 'Yükseliş',
    'longTermTrend': 'Yatay',
    'rsi14': '58.4',
    'macd': 1.25,
    'macdSignal': '0.95',
    'sma': 101.2,
    'sma100': '96.8',
    'ema20': 103.1,
    'ema50': '99.4',
    'ema100': 97.2,
    'ema200': '92.6',
    'bollingerUpper': 109.5,
    'bollingerMiddle': '102.2',
    'bollingerLower': 94.9,
    'atr14': '2.45',
    'supportLevels': ['99.5', 96.2],
    'resistanceLevels': [106.4, '110.8'],
    'scoreContributions': {'movingAverages': '12', 'rsi': 7, 'macd': '9'},
  };

  test('parser reads all optional technical fields and mixed number types', () {
    final result = TrendAnalizi.fromJson(analysisJson(completeTechnical()));
    final technical = result.technical;

    expect(technical.technicalScore, 78);
    expect(technical.confidenceScore, 86);
    expect(technical.confidenceLevel, 'Yüksek');
    expect(technical.dataSufficiency.status, 'sufficient');
    expect(technical.dataPointCount, 240);
    expect(technical.dataTime, isNotNull);
    expect(technical.shortTermTrend, 'Güçlü Yükseliş');
    expect(technical.mediumTermTrend, 'Yükseliş');
    expect(technical.longTermTrend, 'Yatay');
    expect(technical.rsi14, 58.4);
    expect(technical.macd, 1.25);
    expect(technical.macdSignal, 0.95);
    expect(technical.sma, 101.2);
    expect(technical.sma100, 96.8);
    expect(technical.ema20, 103.1);
    expect(technical.ema50, 99.4);
    expect(technical.ema100, 97.2);
    expect(technical.ema200, 92.6);
    expect(technical.bollingerUpper, 109.5);
    expect(technical.bollingerMiddle, 102.2);
    expect(technical.bollingerLower, 94.9);
    expect(technical.atr14, 2.45);
    expect(technical.supportLevels, [99.5, 96.2]);
    expect(technical.resistanceLevels, [106.4, 110.8]);
    expect(technical.scoreContributions['movingAverages'], 12);
    expect(technical.hasAny, isTrue);
  });


  test('zero and negative price levels are ignored', () {
    final result = TrendAnalizi.fromJson(
      analysisJson({
        'supportLevels': [0, -1, null, 99.5],
        'resistanceLevels': [0, -5, 106.4],
      }),
    );

    expect(result.technical.supportLevels, [99.5]);
    expect(result.technical.resistanceLevels, [106.4]);
  });

  test('old API response remains valid without technical fields', () {
    final result = TrendAnalizi.fromJson(analysisJson());

    expect(result.technical.hasAny, isFalse);
    expect(result.technical.technicalScore, isNull);
    expect(result.answerTitle, 'Test Analizi');
  });

  test('partial technical data ignores invalid values and empty levels', () {
    final result = TrendAnalizi.fromJson(
      analysisJson({
        'rsi14': '51,25',
        'macd': double.infinity,
        'supportLevels': [],
        'resistanceLevels': null,
      }),
    );

    expect(result.technical.hasAny, isTrue);
    expect(result.technical.rsi14, 51.25);
    expect(result.technical.macd, isNull);
    expect(result.technical.supportLevels, isEmpty);
    expect(result.technical.resistanceLevels, isEmpty);
  });

  testWidgets('technical card shows score trends indicators and disclaimer', (
    tester,
  ) async {
    final technical = TrendAnalizi.fromJson(
      analysisJson(completeTechnical()),
    ).technical;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111F),
          body: SingleChildScrollView(
            child: TrendoraTechnicalViewCard(analysis: technical),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('teknik-gorunum-karti')), findsOneWidget);
    expect(find.text('Teknik Görünüm'), findsOneWidget);
    expect(find.textContaining('78/100', findRichText: true), findsOneWidget);
    expect(find.text('Kısa Vade'), findsOneWidget);
    expect(find.text('Orta Vade'), findsOneWidget);
    expect(find.text('Uzun Vade'), findsOneWidget);
    expect(find.text('Güçlü Yükseliş'), findsOneWidget);
    expect(find.text('RSI'), findsOneWidget);
    expect(find.text('MACD'), findsOneWidget);
    expect(find.text('ATR'), findsOneWidget);
    expect(find.text('Destek'), findsOneWidget);
    expect(find.text('Direnç'), findsOneWidget);
    expect(
      find.text('Bu değerlendirme yatırım tavsiyesi değildir.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Diğer göstergeler'));
    await tester.pumpAndSettle();
    expect(find.text('SMA100'), findsOneWidget);
    expect(find.text('EMA200'), findsOneWidget);
    expect(find.text('Bollinger üst'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insufficient data shows a neutral message without high score', (
    tester,
  ) async {
    final technical = TrendAnalizi.fromJson(
      analysisJson({
        'technicalScore': 95,
        'confidenceLevel': 'Veri Yetersiz',
        'dataSufficiency': {
          'status': 'insufficient',
          'label': 'Yetersiz',
          'available': 12,
          'required': 200,
        },
        'rsi14': 50,
      }),
    ).technical;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TrendoraTechnicalViewCard(analysis: technical)),
      ),
    );

    expect(find.byKey(const Key('teknik-veri-yetersiz')), findsOneWidget);
    expect(
      find.text('Teknik analiz için yeterli piyasa verisi bulunamadı.'),
      findsOneWidget,
    );
    expect(find.text('95/100'), findsNothing);
    expect(find.text('RSI'), findsNothing);
  });

  testWidgets('lazy list can locate the technical card safely', (tester) async {
    final technical = TrendAnalizi.fromJson(
      analysisJson(completeTechnical()),
    ).technical;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 18,
            itemBuilder: (context, index) => index == 16
                ? TrendoraTechnicalViewCard(analysis: technical)
                : const SizedBox(height: 120),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final card = find.byKey(const Key('teknik-gorunum-karti'));
    for (var attempt = 0; attempt < 8 && card.evaluate().isEmpty; attempt++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump();
    }

    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
