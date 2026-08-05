'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  analyzeTechnicalData,
  choosePreviousClose
} = require('../services/marketDataService');
const { normalizeAnalysis } = require('../services/trend/analysisOrchestrator');

function rows(count, {
  start = 100,
  step = 0.25,
  volume = true,
  fixed = false,
  zero = false
} = {}) {
  const now = Date.now();
  return Array.from({ length: count }, (_, index) => {
    const close = zero ? 0 : fixed ? start : start + step * index;
    const spread = zero || fixed ? 0 : Math.max(0.5, Math.abs(close) * 0.006);
    return {
      timestamp: Math.floor((now - (count - index) * 86400000) / 1000),
      open: close,
      high: close + spread,
      low: close - spread,
      close,
      volume: volume ? 1000 + index * 3 : null
    };
  });
}

function assertNoInvalidNumbers(value) {
  if (typeof value === 'number') {
    assert.ok(Number.isFinite(value), `Geçersiz sayı bulundu: ${value}`);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach(assertNoInvalidNumbers);
    return;
  }
  if (value && typeof value === 'object') {
    Object.values(value).forEach(assertNoInvalidNumbers);
  }
}

test('normal OHLCV data produces the complete technical result model', () => {
  const result = analyzeTechnicalData(rows(240), {
    symbol: 'TEST.IS',
    updatedAt: new Date().toISOString()
  });

  assert.equal(result.assetSymbol, 'TEST.IS');
  assert.equal(result.dataPointCount, 240);
  assert.equal(result.dataSufficiency.status, 'sufficient');
  assert.ok(result.currentPrice > 0);
  assert.ok(result.ema20 != null && result.ema200 != null);
  assert.ok(result.sma20 != null && result.sma200 != null);
  assert.ok(result.rsi14 >= 0 && result.rsi14 <= 100);
  assert.ok(result.macd != null && result.macdSignal != null);
  assert.ok(result.atr14 != null);
  assert.ok(result.dataTime);
  assert.equal(result.integration.newsImpactReady, true);
  assert.equal(result.integration.newsImpactIncluded, false);
  assertNoInvalidNumbers(result);
});

test('insufficient data is explicit and cannot receive high confidence', () => {
  const result = analyzeTechnicalData(rows(10), { symbol: 'SHORT' });

  assert.equal(result.dataSufficiency.status, 'insufficient');
  assert.equal(result.confidenceLevel, 'Veri Yetersiz');
  assert.equal(result.macd, null);
  assert.equal(result.ema20, null);
  assert.equal(result.longTermTrend, 'Veri Yetersiz');
  assert.ok(!['Yüksek', 'Çok Yüksek'].includes(result.confidenceLevel));
  assertNoInvalidNumbers(result);
});

test('fixed prices keep RSI neutral and Bollinger bands ordered', () => {
  const result = analyzeTechnicalData(rows(220, { start: 125, fixed: true }));

  assert.equal(result.rsi14, 50);
  assert.equal(result.bollingerUpper, 125);
  assert.equal(result.bollingerMiddle, 125);
  assert.equal(result.bollingerLower, 125);
  assert.ok(result.bollingerUpper >= result.bollingerMiddle);
  assert.ok(result.bollingerMiddle >= result.bollingerLower);
  assertNoInvalidNumbers(result);
});

test('rising and falling series produce bounded RSI, score and trend states', () => {
  const rising = analyzeTechnicalData(rows(240, { start: 50, step: 0.8 }));
  const falling = analyzeTechnicalData(rows(240, { start: 300, step: -0.8 }));

  assert.equal(rising.rsi14, 100);
  assert.equal(falling.rsi14, 0);
  assert.ok(['Güçlü Yükseliş', 'Yükseliş'].includes(rising.shortTermTrend));
  assert.ok(['Güçlü Yükseliş', 'Yükseliş'].includes(rising.longTermTrend));
  assert.ok(['Güçlü Düşüş', 'Düşüş'].includes(falling.shortTermTrend));
  assert.ok(['Güçlü Düşüş', 'Düşüş'].includes(falling.longTermTrend));
  assert.ok(rising.score >= 0 && rising.score <= 100);
  assert.ok(falling.score >= 0 && falling.score <= 100);
  assertNoInvalidNumbers(rising);
  assertNoInvalidNumbers(falling);
});

test('missing volume does not block price indicators', () => {
  const result = analyzeTechnicalData(rows(220, { volume: false }));

  assert.equal(result.volumeRatio, null);
  assert.ok(result.rsi14 != null);
  assert.ok(result.macd != null);
  assert.ok(result.bollingerMiddle != null);
  assertNoInvalidNumbers(result);
});

test('zero values never create NaN, infinity or division errors', () => {
  const result = analyzeTechnicalData(rows(220, { zero: true }));

  assert.equal(result.currentPrice, 0);
  assert.equal(result.rsi14, 50);
  assert.equal(result.atrPercent, null);
  assert.ok(result.score >= 0 && result.score <= 100);
  assertNoInvalidNumbers(result);
});

test('daily change uses the previous trading close before provider metadata', () => {
  for (const fixture of [
    { current: 110, previous: 100, expected: 10 },
    { current: 90, previous: 100, expected: -10 },
    { current: 100, previous: 100, expected: 0 }
  ]) {
    const previousClose = choosePreviousClose({
      current: fixture.current,
      latestOpen: 95,
      previousRowClose: fixture.previous,
      metaPreviousClose: 80,
      chartPreviousClose: 70
    });
    const changePercent = ((fixture.current - previousClose) / previousClose) * 100;
    assert.equal(previousClose, fixture.previous);
    assert.equal(changePercent, fixture.expected);
  }
});

test('MACD, Bollinger, support and resistance are generated from OHLCV', () => {
  const normal = rows(120, { start: 90, step: 0.18 }).map((row, index) => ({
    ...row,
    close: row.close + Math.sin(index / 4) * 2,
    high: row.high + Math.sin(index / 4) * 2,
    low: row.low + Math.sin(index / 4) * 2
  }));
  const result = analyzeTechnicalData(normal);

  assert.ok(Number.isFinite(result.macd));
  assert.ok(Number.isFinite(result.macdSignal));
  assert.ok(result.bollingerUpper >= result.bollingerMiddle);
  assert.ok(result.bollingerMiddle >= result.bollingerLower);
  assert.ok(result.supportLevels.length > 0);
  assert.ok(result.resistanceLevels.length > 0);
  assertNoInvalidNumbers(result);
});

test('technical score exposes deterministic contributions within 0-100', () => {
  const first = analyzeTechnicalData(rows(240, { start: 70, step: 0.4 }));
  const second = analyzeTechnicalData(rows(240, { start: 70, step: 0.4 }));

  assert.equal(first.score, second.score);
  assert.equal(first.technicalScore, first.score);
  assert.ok(first.score >= 0 && first.score <= 100);
  assert.deepEqual(first.scoreContributions, second.scoreContributions);
  for (const key of [
    'movingAverages', 'rsi', 'macd', 'bollingerPosition',
    'supportResistance', 'atrVolatility'
  ]) {
    assert.ok(Object.hasOwn(first.scoreContributions, key));
  }
});

test('analysis normalization preserves legacy fields and optional technical model', () => {
  const technical = analyzeTechnicalData(rows(220), { symbol: 'MODEL.IS' });
  const result = normalizeAnalysis(
    { confidence: 70, technical },
    'MODEL teknik analiz',
    {
      domain: 'finance', label: 'Finans', intent: 'technical_analysis',
      period: { label: '3 Ay', days: 90 }, entity: { symbol: 'MODEL.IS' }
    },
    { sources: [] }
  );

  assert.equal(result.technical.score, technical.score);
  assert.equal(result.technical.rsi14, technical.rsi14);
  assert.equal(result.technical.assetSymbol, 'MODEL.IS');
  assert.equal(result.technical.dataPointCount, 220);
  assert.equal(result.technical.dataSufficiency.status, 'sufficient');
  assert.equal(result.technical.integration.newsImpactReady, true);
  assert.equal(result.confidence, 70);
});
