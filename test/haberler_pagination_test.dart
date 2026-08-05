import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trendora_app/haberler_sayfasi.dart';

void main() {
  testWidgets('real API image aliases reach the news card image widget', (
    tester,
  ) async {
    Future<http.Response> request(Uri uri) async => _response(
      items: [
        _newsJson(1)
          ..remove('imageUrl')
          ..['urlToImage'] = 'https://cdn.example.com/fixture.jpg',
      ],
      offset: 0,
      limit: 30,
      total: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('haber-ag-gorseli-news-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'aynı veri sürümünde arka plan yenilemesi listeyi yeniden kurmaz',
    (tester) async {
      var requests = 0;
      Future<http.Response> request(Uri uri) async {
        requests += 1;
        return _response(
          items: [_newsJson(1)],
          offset: 0,
          limit: 30,
          total: 1,
          updatedAt: '2026-08-03T10:00:00.000Z',
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
      );
      await tester.pump();
      final firstElement = tester.element(
        find.byKey(const ValueKey<String>('haber-karti-news-1')),
      );
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();

      expect(requests, 2);
      expect(
        tester.element(
          find.byKey(const ValueKey<String>('haber-karti-news-1')),
        ),
        same(firstElement),
      );
    },
  );

  testWidgets('uygulama background iken periyodik haber isteği yapılmaz', (
    tester,
  ) async {
    var requests = 0;
    Future<http.Response> request(Uri uri) async {
      requests += 1;
      return _response(items: [_newsJson(1)], offset: 0, limit: 30, total: 1);
    }

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();

    expect(requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'infinite scroll uses offset, prevents concurrent requests and deduplicates',
    (tester) async {
      final requestedOffsets = <int>[];
      var activeRequests = 0;
      var maximumActiveRequests = 0;

      Future<http.Response> request(Uri uri) async {
        final offset = int.parse(uri.queryParameters['offset']!);
        final limit = int.parse(uri.queryParameters['limit']!);
        requestedOffsets.add(offset);
        activeRequests += 1;
        if (activeRequests > maximumActiveRequests) {
          maximumActiveRequests = activeRequests;
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));

        final firstIndex = offset == 0 ? 1 : 26;
        final itemCount = offset == 0 ? limit : 10;
        final items = List<Map<String, dynamic>>.generate(
          itemCount,
          (index) => _newsJson(firstIndex + index),
        );
        activeRequests -= 1;

        return _response(items: items, offset: offset, limit: limit, total: 35);
      }

      await tester.pumpWidget(
        MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(requestedOffsets, [0]);
      expect(find.text('Haber 1'), findsOneWidget);

      final scrollable = _newsScrollable();
      await tester.scrollUntilVisible(
        find.text('Haber 26'),
        500,
        scrollable: scrollable,
      );
      await tester.pump();
      await tester.drag(scrollable, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.drag(scrollable, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(requestedOffsets, [0, 30]);
      expect(maximumActiveRequests, 1);

      await tester.scrollUntilVisible(
        find.text('Haber 35'),
        350,
        scrollable: scrollable,
      );
      expect(find.text('Haber 35'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Haber 26'),
        -250,
        scrollable: scrollable,
      );
      expect(find.text('Haber 26'), findsOneWidget);

      await tester.fling(scrollable, const Offset(0, -800), 1200);
      await tester.pumpAndSettle();
      expect(requestedOffsets, [0, 30]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pagination error keeps the list and offers a small retry', (
    tester,
  ) async {
    final requestedOffsets = <int>[];
    var secondPageAttempts = 0;

    Future<http.Response> request(Uri uri) async {
      final offset = int.parse(uri.queryParameters['offset']!);
      final limit = int.parse(uri.queryParameters['limit']!);
      requestedOffsets.add(offset);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      if (offset == 30 && secondPageAttempts++ == 0) {
        return http.Response('temporary failure', 503);
      }

      final firstIndex = offset == 0 ? 1 : 31;
      final itemCount = offset == 0 ? limit : 5;
      return _response(
        items: List<Map<String, dynamic>>.generate(
          itemCount,
          (index) => _newsJson(firstIndex + index),
        ),
        offset: offset,
        limit: limit,
        total: 35,
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    final scrollable = _newsScrollable();
    await tester.scrollUntilVisible(
      find.text('Haber 26'),
      500,
      scrollable: scrollable,
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('Haber 26'), findsOneWidget);
    await tester.fling(scrollable, const Offset(0, -900), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Daha fazla haber için tekrar dene'), findsOneWidget);
    expect(requestedOffsets, [0, 30]);

    await tester.tap(find.text('Daha fazla haber için tekrar dene'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Haber 35'),
      350,
      scrollable: scrollable,
    );
    expect(find.text('Haber 35'), findsOneWidget);
    expect(requestedOffsets, [0, 30, 30]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category change resets paging and restores previous feed', (
    tester,
  ) async {
    final requests = <String>[];

    Future<http.Response> request(Uri uri) async {
      final category = uri.queryParameters['category']!;
      final offset = int.parse(uri.queryParameters['offset']!);
      final limit = int.parse(uri.queryParameters['limit']!);
      requests.add('$category:$offset');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final isAgenda = category == 'gundem';
      final itemCount = isAgenda ? 12 : limit;
      return _response(
        items: List<Map<String, dynamic>>.generate(
          itemCount,
          (index) => _newsJson(
            index + 1,
            titlePrefix: isAgenda ? 'Gündem Haber' : 'Genel Haber',
            category: isAgenda ? 'gundem' : 'genel',
          ),
        ),
        offset: offset,
        limit: limit,
        total: itemCount,
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    var scrollable = _newsScrollable();
    await tester.scrollUntilVisible(
      find.text('Genel Haber 12'),
      450,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final previousPosition = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;

    await tester.tap(find.text('Gündem'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('Gündem Haber 1'), findsOneWidget);
    expect(requests, ['tumu:0', 'gundem:0']);

    await tester.tap(find.text('Genel'));
    await tester.pumpAndSettle();

    scrollable = _newsScrollable();
    final restoredPosition = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(find.text('Genel Haber 12'), findsOneWidget);
    expect(restoredPosition, closeTo(previousPosition, 0.1));
    expect(requests, ['tumu:0', 'gundem:0']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination adds a new source to a stable event cluster', (
    tester,
  ) async {
    Future<http.Response> request(Uri uri) async {
      final offset = int.parse(uri.queryParameters['offset']!);
      final limit = int.parse(uri.queryParameters['limit']!);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final firstIndex = offset == 0 ? 1 : 31;
      final itemCount = offset == 0 ? limit : 5;
      final items = List<Map<String, dynamic>>.generate(
        itemCount,
        (index) => _newsJson(firstIndex + index),
      );
      if (offset == 0) {
        items[0]
          ..['id'] = 'event-source-a'
          ..['title'] = 'TCMB faiz kararı açıklandı politika faizi sabit kaldı'
          ..['description'] = 'Politika faizi sabit bırakıldı.'
          ..['source'] = 'Kaynak A'
          ..['category'] = 'ekonomi';
      } else {
        items[0]
          ..['id'] = 'event-source-b'
          ..['title'] = 'TCMB faiz kararı: politika faizi sabit kaldı'
          ..['description'] = 'Politika faizi sabit bırakıldı.'
          ..['source'] = 'Kaynak B'
          ..['category'] = 'ekonomi';
      }
      return _response(items: items, offset: offset, limit: limit, total: 35);
    }

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    expect(find.text('2 farklı kaynak'), findsNothing);
    final scrollable = _newsScrollable();
    await tester.scrollUntilVisible(
      find.text('Haber 26'),
      500,
      scrollable: scrollable,
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('TCMB faiz kararı açıklandı politika faizi sabit kaldı'),
      -500,
      scrollable: scrollable,
    );
    expect(find.text('2 farklı kaynak'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('haber-karti-event-source-a')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category cache restores prepared event clusters', (
    tester,
  ) async {
    final requests = <String>[];

    Future<http.Response> request(Uri uri) async {
      final category = uri.queryParameters['category']!;
      requests.add(category);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final items = category == 'gundem'
          ? [_newsJson(90, titlePrefix: 'Gündem Haber', category: 'gundem')]
          : [
              _newsJson(1, category: 'ekonomi')
                ..['title'] =
                    'Enflasyon verisi yıllık yüzde 35 olarak açıklandı'
                ..['source'] = 'Kaynak A',
              _newsJson(2, category: 'ekonomi')
                ..['title'] =
                    'Enflasyon verisi yıllık yüzde 35 olarak açıklandı'
                ..['source'] = 'Kaynak B',
            ];
      return _response(items: items, offset: 0, limit: 30, total: items.length);
    }

    await tester.pumpWidget(
      MaterialApp(home: HaberlerSayfasi.paginationTest(request: request)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('2 farklı kaynak'), findsOneWidget);

    await tester.tap(find.text('Gündem'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('Gündem Haber 90'), findsOneWidget);

    await tester.tap(find.text('Genel'));
    await tester.pumpAndSettle();

    expect(find.text('2 farklı kaynak'), findsOneWidget);
    expect(requests, ['tumu', 'gundem']);
    expect(tester.takeException(), isNull);
  });
}

Finder _newsScrollable() {
  return find.descendant(
    of: find.byKey(const PageStorageKey<String>('haber-merkezi-listesi')),
    matching: find.byType(Scrollable),
  );
}

Map<String, dynamic> _newsJson(
  int index, {
  String titlePrefix = 'Haber',
  String category = 'gundem',
}) {
  return {
    'id': 'news-$index',
    'title': '$titlePrefix $index',
    'description': 'Haber $index özeti',
    'content': 'Haber $index tam metni',
    'url': 'https://example.com/news-$index',
    'imageUrl': '',
    'source': 'Test Kaynağı',
    'feedSource': 'Test Akışı',
    'category': category,
    'publishedAt': DateTime(
      2026,
      7,
      29,
      12,
    ).subtract(Duration(minutes: index)).toIso8601String(),
    'isBreaking': false,
    'trendScore': 50,
    'confidenceScore': 80,
  };
}

http.Response _response({
  required List<Map<String, dynamic>> items,
  required int offset,
  required int limit,
  required int total,
  String? updatedAt,
}) {
  final body = jsonEncode({
    'success': true,
    'count': items.length,
    'total': total,
    'offset': offset,
    'limit': limit,
    if (updatedAt != null) 'updatedAt': updatedAt,
    'news': items,
  });

  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
