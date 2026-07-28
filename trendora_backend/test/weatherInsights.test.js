'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { buildWeatherInsights } = require('../services/weatherInsights');

function hour(time, overrides = {}) {
  return {
    time: `2026-07-28T${time}:00`,
    temperature: 22,
    apparentTemperature: 22,
    precipitationProbability: 0,
    precipitation: 0,
    weatherCode: 1,
    visibility: 10000,
    windSpeed: 10,
    windGust: 15,
    uvIndex: 2,
    ...overrides
  };
}

test('benign data does not create fake warnings', () => {
  const result = buildWeatherInsights({}, [
    hour('10', { visibility: null, uvIndex: null }),
    hour('11'),
  ], [], []);

  assert.deepEqual(result.warnings, []);
  assert.equal(result.drivingWarning, null);
  assert.deepEqual(result.sponsoredRecommendations, []);
});

test('storm, icing and low visibility are detected from hourly data', () => {
  const result = buildWeatherInsights({}, [
    hour('15', { weatherCode: 95 }),
    hour('16', { weatherCode: 66, temperature: 0 }),
    hour('17', { visibility: 400 })
  ], [], []);

  assert.ok(result.warnings.some(item => item.type === 'storm'));
  assert.ok(result.warnings.some(item => item.type === 'icing'));
  assert.ok(result.warnings.some(item => item.type === 'low_visibility'));
  assert.ok(result.drivingWarning);
});

test('timed rain, wind and UV insights use real matching hours', () => {
  const result = buildWeatherInsights({}, [
    hour('11', { uvIndex: 7 }),
    hour('12', { uvIndex: 8 }),
    hour('16', { windGust: 55 }),
    hour('19', { precipitationProbability: 70 })
  ], [], []);

  assert.ok(result.insights.some(item => item.type === 'uv_timing'));
  assert.ok(result.insights.some(item => item.type === 'wind_timing'));
  assert.ok(result.insights.some(item => item.message === 'Akşam yağış bekleniyor.'));
  assert.ok(result.warnings.some(item => item.type === 'uv'));
  assert.ok(result.warnings.some(item => item.type === 'wind'));
  assert.ok(result.warnings.some(item => item.type === 'rain'));
});

test('safe consecutive hours produce activity suggestions', () => {
  const result = buildWeatherInsights({}, [
    hour('10'),
    hour('11'),
    hour('12')
  ], [], []);

  assert.ok(result.activities.some(item => item.type === 'walking'));
  assert.ok(result.activities.some(item => item.type === 'with_children'));
});
