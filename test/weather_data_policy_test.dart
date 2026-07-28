import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trendora_app/core/weather/weather_data_policy.dart';

void main() {
  test('coordinates are reduced to approximate two-decimal precision', () {
    expect(WeatherDataPolicy.approximateCoordinate(41.0082376), 41.01);
    expect(WeatherDataPolicy.approximateCoordinate(28.9783589), 28.98);
  });

  test('denied location permissions keep city fallback active', () {
    expect(
      WeatherDataPolicy.shouldUseCityFallback(LocationPermission.denied),
      isTrue,
    );
    expect(
      WeatherDataPolicy.shouldUseCityFallback(LocationPermission.deniedForever),
      isTrue,
    );
    expect(
      WeatherDataPolicy.shouldUseCityFallback(LocationPermission.whileInUse),
      isFalse,
    );
  });

  test('old and missing timestamps are never treated as current', () {
    final now = DateTime.parse('2026-07-28T12:00:00Z').toLocal();

    expect(
      WeatherDataPolicy.isStale({
        'updatedAt': '2026-07-28T11:45:00Z',
      }, now: now),
      isFalse,
    );
    expect(
      WeatherDataPolicy.isStale({
        'updatedAt': '2026-07-28T10:00:00Z',
      }, now: now),
      isTrue,
    );
    expect(WeatherDataPolicy.isStale({}, now: now), isTrue);
  });

  test('source and update labels use standardized metadata', () {
    final data = {'source': 'Open-Meteo', 'dataTime': '2026-07-28T09:30:00Z'};

    expect(WeatherDataPolicy.sourceName(data), 'Open-Meteo');
    expect(WeatherDataPolicy.updatedLabel(data), contains('28.07.2026'));
  });
}
