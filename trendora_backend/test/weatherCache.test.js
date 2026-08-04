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
