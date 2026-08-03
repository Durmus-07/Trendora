import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/core/news/news_content_service.dart';
import 'package:trendora_app/core/news/saved_news_store.dart';
import 'package:trendora_app/haber_detay_sayfasi.dart';

class _FakeContentGateway implements NewsContentGateway {
  _FakeContentGateway(this.future);

  final Future<NewsContentResult> future;

  @override
  Future<NewsContentResult> load({required String id, required String url}) {
    return future;
  }
}

Widget _detail(NewsContentGateway gateway) {
  return MaterialApp(
    home: HaberDetaySayfasi(
      id: 'news-1',
      title: 'Deneme haberi',
      imageUrl: '',
      source: 'Kaynak',
      publishedAt: DateTime(2026),
      summary: 'Detay ekranı açılır açılmaz gösterilen mevcut haber özeti.',
      articleText: '',
      url: 'https://example.com/news-1',
      contentGateway: gateway,
    ),
  );
}

void main() {
  testWidgets('özet hemen görünür, tam metin gelince yerini alır', (
    tester,
  ) async {
    final completer = Completer<NewsContentResult>();
    await tester.pumpWidget(_detail(_FakeContentGateway(completer.future)));
    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-tam-metin-yukleniyor')),
      250,
    );

    expect(find.textContaining('mevcut haber özeti'), findsWidgets);
    expect(find.byKey(const Key('haber-tam-metin-yukleniyor')), findsOneWidget);

    completer.complete(
      const NewsContentResult(
        content: 'Servisten gelen temiz ve okunabilir tam haber metni.',
        status: 'full',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Servisten gelen temiz', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const Key('haber-tam-metin-yukleniyor')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-kaynaga-git')),
      250,
    );
    expect(find.text('Orijinal Kaynağı Aç'), findsOneWidget);
  });

  testWidgets('servis hatasında özet korunur', (tester) async {
    final completer = Completer<NewsContentResult>();
    await tester.pumpWidget(_detail(_FakeContentGateway(completer.future)));
    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-tam-metin-yukleniyor')),
      250,
    );
    completer.completeError(StateError('timeout'));
    await tester.pump();

    expect(find.textContaining('mevcut haber özeti'), findsWidgets);
    expect(find.byKey(const Key('haber-tam-metin-alinamadi')), findsOneWidget);
  });

  test('istemcinin savunmacı temizliği HTML ve script içeriğini kaldırır', () {
    final result = NewsContentResult.fromJson({
      'contentStatus': 'full',
      'content':
          '<script>tehlike()</script><p>Okunabilir &amp; temiz metin</p>',
    });
    expect(result.content, 'Okunabilir & temiz metin');
  });

  testWidgets('ekran kapandıktan gelen cevap setState hatası üretmez', (
    tester,
  ) async {
    final completer = Completer<NewsContentResult>();
    await tester.pumpWidget(_detail(_FakeContentGateway(completer.future)));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    completer.complete(
      const NewsContentResult(content: 'Geç gelen içerik', status: 'full'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tam metin geldikten sonra kaydetme güncel metni saklar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final completer = Completer<NewsContentResult>();
    await tester.pumpWidget(_detail(_FakeContentGateway(completer.future)));
    await tester.scrollUntilVisible(
      find.byKey(const Key('haber-tam-metin-yukleniyor')),
      250,
    );
    completer.complete(
      const NewsContentResult(
        content: 'Sonradan indirilen ve kaydedilmesi gereken tam metin.',
        status: 'full',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('haber-kaydet')), 250);
    await tester.pump();
    await tester.tap(find.byKey(const Key('haber-kaydet')));
    await tester.pump();

    final saved = await SavedNewsStore.load();
    expect(saved.single.articleText, contains('Sonradan indirilen'));
  });
}
