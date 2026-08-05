import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/ayarlar_sayfasi.dart';

void main() {
  testWidgets('weather is the first setting and notifications are second', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AyarlarSayfasi()));
    await tester.pump();

    final weather = find.text('Akıllı Hava Merkezi');
    final notifications = find.text('Bildirimler');
    expect(weather, findsOneWidget);
    expect(notifications, findsOneWidget);
    expect(
      tester.getTopLeft(weather).dy,
      lessThan(tester.getTopLeft(notifications).dy),
    );
  });
}
