import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/hava_merkezi_sayfasi.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('legacy weather response remains visible without new fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HavaMerkeziSayfasi(
          autoLocate: false,
          initialWeather: _weatherData(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Akıllı Hava Merkezi'), findsOneWidget);
    expect(find.textContaining('İstanbul'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guidance cards do not overflow on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = _weatherData()
      ..addAll({
        'insights': [
          {'type': 'rain_timing', 'message': 'Akşam yağış bekleniyor.'},
        ],
        'activities': [
          {
            'type': 'walking',
            'suitable': true,
            'message': 'Bugün 18.00–20.00 arası yürüyüş için daha uygun.',
          },
        ],
        'drivingWarning': {
          'message':
              'Araç kullanırken hızını ve takip mesafeni hava koşullarına göre ayarla.',
        },
      });

    await tester.pumpWidget(
      MaterialApp(
        home: HavaMerkeziSayfasi(autoLocate: false, initialWeather: data),
      ),
    );
    await tester.pumpAndSettle();

    final notesTitle = find.text('Bugünün Hava Notları');
    await tester.scrollUntilVisible(
      notesTitle,
      160,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 8,
    );
    await tester.pumpAndSettle();

    expect(notesTitle, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _weatherData() => {
  'success': true,
  'location': {'name': 'İstanbul', 'latitude': 41.01, 'longitude': 28.98},
  'current': {
    'temperature': 24,
    'apparentTemperature': 25,
    'humidity': 55,
    'weatherCode': 1,
    'description': 'Açık',
    'windSpeed': 12,
    'pressure': 1012,
    'cloudCover': 10,
  },
  'warnings': <Map<String, dynamic>>[],
  'hourly': <Map<String, dynamic>>[],
  'daily': <Map<String, dynamic>>[],
  'source': 'Open-Meteo',
  'updatedAt': DateTime.now().toUtc().toIso8601String(),
  'cached': false,
};
