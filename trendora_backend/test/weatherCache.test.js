'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const weatherRoute = require('../routes/weather');

const weather = weatherRoute._test;

function providerResponse() {
  const now = '2026-08-04T10:00';
  return {
    data: {
      latitude: 41.01,
      longitude: 28.97,
      timezone: 'Europe/Istanbul',
      utc_offset_seconds: 10800,
      current: { time: now, temperature_2m: 28, weather_code: 1 },
      hourly: { time: [now], temperature_2m: [28], weather_code: [1] },
      daily: { time: ['2026-08-04'], weather_code: [1] }
    }
  };
}

test.afterEach(() => weather.reset());

test('same-coordinate concurrent requests share one provider call', async () => {
  let calls = 0;
  weather.setWeatherRequester(async () => {
    calls += 1;
    await new Promise(resolve => setTimeout(resolve, 10));
    return providerResponse();
  });

  const [first, second] = await Promise.all([
    weather.fetchWeather(41.01, 28.97, 'İstanbul'),
    weather.fetchWeather(41.01, 28.97, 'İstanbul')
  ]);

  assert.equal(calls, 1);
  assert.equal(first.current.temperature, 28);
  assert.deepEqual(second, first);
});

test('429 returns stale successful data and activates backoff', async () => {
  weather.setWeatherRequester(async () => providerResponse());
  await weather.fetchWeather(41.01, 28.97, 'İstanbul');
  const entry = weather.weatherCache.get('41.01,28.97');
  entry.expiresAt = Date.now() - 1;

  let calls = 0;
  weather.setWeatherRequester(async () => {
    calls += 1;
    const error = new Error('rate limited');
    error.response = { status: 429, headers: { 'retry-after': '60' } };
    throw error;
  });

  const stale = await weather.fetchWeather(41.01, 28.97, 'İstanbul');
  const duringBackoff = await weather.fetchWeather(41.01, 28.97, 'İstanbul');

  assert.equal(stale.stale, true);
  assert.equal(duringBackoff.stale, true);
  assert.equal(calls, 1);
  assert.match(stale.message, /Son başarılı tahmin/);
});

test('provider 5xx returns stale data and prevents repeated provider calls', async () => {
  weather.setWeatherRequester(async () => providerResponse());
  await weather.fetchWeather(41.01, 28.97, 'İstanbul');
  const entry = weather.weatherCache.get('41.01,28.97');
  entry.expiresAt = Date.now() - 1;

  let calls = 0;
  weather.setWeatherRequester(async () => {
    calls += 1;
    const error = new Error('provider unavailable');
    error.response = { status: 503, headers: {} };
    throw error;
  });

  const stale = await weather.fetchWeather(41.01, 28.97, 'İstanbul');
  const duringBackoff = await weather.fetchWeather(41.01, 28.97, 'İstanbul');

  assert.equal(stale.stale, true);
  assert.equal(duringBackoff.stale, true);
  assert.equal(calls, 1);
});

test('429 without stale cache uses non-AI backup weather provider', async () => {
  weather.setWeatherRequester(async () => {
    const error = new Error('rate limited');
    error.response = { status: 429, headers: { 'retry-after': '60' } };
    throw error;
  });
  weather.setBackupWeatherRequester(async () => ({
    data: {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [36.87, 37.6, 520] },
      properties: {
        timeseries: [
          {
            time: '2026-08-06T20:00:00Z',
            data: {
              instant: {
                details: {
                  air_temperature: 29,
                  relative_humidity: 35,
                  air_pressure_at_sea_level: 1008,
                  wind_speed: 3,
                  wind_from_direction: 190,
                  cloud_area_fraction: 12
                }
              },
              next_1_hours: {
                summary: { symbol_code: 'clearsky_day' },
                details: { precipitation_amount: 0, probability_of_precipitation: 0 }
              }
            }
          }
        ]
      }
    }
  }));

  const result = await weather.fetchWeather(37.6, 36.87, 'Kahramanmaraş');

  assert.equal(result.success, true);
  assert.equal(result.source, 'MET Norway');
  assert.equal(result.fallback, true);
  assert.equal(result.current.temperature, 29);
  assert.equal(result.current.windSpeed, 10.8);
});
