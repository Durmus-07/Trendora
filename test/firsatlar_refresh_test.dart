import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trendora_app/firsatlar_sayfasi.dart';

http.Response response(
  String updatedAt, {
  List<Map<String, dynamic>>? items,
}) => http.Response(
  jsonEncode({
    'success': true,
    'updatedAt': updatedAt,
    'items': items ?? [
      {
        'id': 'deal-1',
        'title': 'Test Fırsatı',
        'description': 'Açıklama',
        'category': 'market',
        'source': 'migros',
        'currentPrice': 90,
        'oldPrice': 100,
        'discountRate': 10,
        'officialUrl': 'https://example.com/deal-1',
        'verifiedAt': '2026-08-03T10:00:00.000Z',
        'active': true,
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Widget app(Future<http.Response> Function(Uri) request) => MaterialApp(
  home: CanliFirsatlarListeSayfasi(
    baslik: 'Canlı Fırsatlar',
    kategori: 'all',
    renk: Colors.orange,
    testIstegi: request,
  ),
);

void main() {
  testWidgets('aynı updatedAt arka plan yenilemesinde listeyi yeniden kurmaz', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      app((_) async {
        requests += 1;
        return response('2026-08-03T10:00:00.000Z');
      }),
    );
    await tester.pumpAndSettle();
    final before = tester.element(find.text('Test Fırsatı').first);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(requests, 2);
    expect(tester.element(find.text('Test Fırsatı').first), same(before));
  });

  testWidgets('uygulama background iken periyodik istek göndermez', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      app((_) async {
        requests += 1;
        return response('2026-08-03T10:00:00.000Z');
      }),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    expect(requests, 1);
  });

  testWidgets('updatedAt change refreshes and duplicate ids are collapsed', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      app((_) async {
        requests += 1;
        if (requests == 1) return response('v1');
        return response('v2', items: [
          {
            'id': 'deal-2',
            'title': 'Yeni Fırsat',
            'category': 'market',
            'source': 'migros',
            'currentPrice': 80,
            'officialUrl': 'https://example.com/deal-2',
          },
          {
            'id': 'deal-2',
            'title': 'Yeni Fırsat',
            'category': 'market',
            'source': 'migros',
            'currentPrice': 75,
            'officialUrl': 'https://example.com/deal-2',
          },
        ]);
      }),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(find.text('Yeni Fırsat'), findsOneWidget);
    expect(find.text('Test Fırsatı'), findsNothing);
  });

  testWidgets('hidden route and dispose stop periodic requests', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      app((_) async {
        requests += 1;
        return response('v1');
      }),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Canlı Fırsatlar').first);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detay')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    expect(requests, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 60));
    expect(requests, 1);
  });
}
