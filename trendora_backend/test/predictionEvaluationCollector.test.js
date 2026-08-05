'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, beforeEach, test } = require('node:test');
const express = require('express');

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), 'trendora-prediction-evaluation-')
);
const memoryFile = path.join(temporaryDirectory, 'prediction_memory.json');
const trendsFile = path.join(temporaryDirectory, 'trends_database.json');
const statusFile = path.join(temporaryDirectory, 'trends_status.json');
const previousMemoryFile = process.env.TRENDORA_PREDICTION_MEMORY_FILE;

process.env.TRENDORA_PREDICTION_MEMORY_FILE = memoryFile;

const {
  evaluateAllDuePredictionsWithMarketData
} = require('../services/trend/predictionEvaluatorService');
const { collectTrends } = require('../services/trendCollector');

function prediction({
  id,
  dueAt,
  status = 'pending',
  evaluatedAt = null,
  outcome = null
}) {
  return {
    id,
    createdAt: '2026-01-01T00:00:00.000Z',
    dueAt,
    status,
    evaluatedAt,
    outcome,
    query: id,
    horizonDays: 30,
    asset: { name: id, symbol: id.toUpperCase() },
    prediction: {
      direction: 'rising',
      currentPrice: 100,
      confidence: 70
    },
    technicalSnapshot: null,
    statisticsSnapshot: null,
    scenarios: []
  };
}

function writeMemory(predictions) {
  fs.writeFileSync(
    memoryFile,
    JSON.stringify({
      version: 1,
      updatedAt: '2026-01-01T00:00:00.000Z',
      predictions
    }, null, 2),
    'utf8'
  );
}

function readMemory() {
  return JSON.parse(fs.readFileSync(memoryFile, 'utf8'));
}

beforeEach(() => {
  writeMemory([]);
  for (const filePath of [trendsFile, statusFile]) {
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  }
});

after(() => {
  if (previousMemoryFile == null) {
    delete process.env.TRENDORA_PREDICTION_MEMORY_FILE;
  } else {
    process.env.TRENDORA_PREDICTION_MEMORY_FILE = previousMemoryFile;
  }
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
});

test('vadesi gelmemiş pending tahmin değerlendirilmez', async () => {
  writeMemory([
    prediction({ id: 'future', dueAt: '2999-01-01T00:00:00.000Z' })
  ]);
  let priceCalls = 0;

  const summary = await evaluateAllDuePredictionsWithMarketData({
    priceResolver: async () => {
      priceCalls += 1;
      return 110;
    }
  });

  assert.equal(summary.total, 0);
  assert.equal(priceCalls, 0);
  assert.equal(readMemory().predictions[0].status, 'pending');
});

test('vadesi gelmiş pending tahmin piyasa fiyatıyla değerlendirilir', async () => {
  writeMemory([
    prediction({ id: 'due', dueAt: '2020-01-01T00:00:00.000Z' })
  ]);

  const summary = await evaluateAllDuePredictionsWithMarketData({
    priceResolver: async () => 110
  });
  const saved = readMemory().predictions[0];

  assert.equal(summary.evaluated, 1);
  assert.equal(summary.skipped, 0);
  assert.equal(summary.failed, 0);
  assert.equal(saved.status, 'evaluated');
  assert.ok(saved.evaluatedAt);
  assert.equal(saved.outcome.finalPrice, 110);
  assert.equal(saved.outcome.isCorrect, true);
});

test('değerlendirilmiş tahmin ikinci kez değerlendirilmez', async () => {
  writeMemory([
    prediction({ id: 'once', dueAt: '2020-01-01T00:00:00.000Z' })
  ]);
  let priceCalls = 0;
  const options = {
    priceResolver: async () => {
      priceCalls += 1;
      return 105;
    }
  };

  await evaluateAllDuePredictionsWithMarketData(options);
  const evaluatedAt = readMemory().predictions[0].evaluatedAt;
  const second = await evaluateAllDuePredictionsWithMarketData(options);

  assert.equal(second.total, 0);
  assert.equal(priceCalls, 1);
  assert.equal(readMemory().predictions[0].evaluatedAt, evaluatedAt);
});

test('fiyat alınamazsa prediction memory kaydı bozulmaz', async () => {
  writeMemory([
    prediction({ id: 'no-price', dueAt: '2020-01-01T00:00:00.000Z' })
  ]);
  const before = fs.readFileSync(memoryFile, 'utf8');

  const summary = await evaluateAllDuePredictionsWithMarketData({
    priceResolver: async () => null
  });

  assert.equal(summary.skipped, 1);
  assert.equal(summary.results[0].reason, 'final_price_not_found');
  assert.equal(fs.readFileSync(memoryFile, 'utf8'), before);
});

test('collector değerlendirme hatasında trend veritabanını tamamlar', async () => {
  const logs = [];
  const errors = [];
  await collectTrends({
    trendsDatabaseFile: trendsFile,
    trendsStatusFile: statusFile,
    getTrendOverview: async () => ({
      updatedAt: '2026-08-05T00:00:00.000Z',
      methodology: { version: 'test' },
      trends: [{ id: 'trend-1' }]
    }),
    evaluateDuePredictions: async () => {
      throw new Error('forced evaluator failure');
    },
    logger: {
      log: (...values) => logs.push(values.join(' ')),
      error: (...values) => errors.push(values.join(' '))
    }
  });

  const trends = JSON.parse(fs.readFileSync(trendsFile, 'utf8'));
  const status = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
  assert.equal(trends.ready, true);
  assert.equal(trends.trendCount, 1);
  assert.equal(status.phase, 'completed');
  assert.equal(status.error, null);
  assert.ok(errors.some(line =>
    line.includes('0 başarılı, 0 atlanan, 1 servis hatası')));
  assert.ok(logs.some(line => line.includes('Tamamlandı: 1 trend')));
});

test('collector değerlendirme sayaçlarını anlaşılır biçimde loglar', async () => {
  const logs = [];
  await collectTrends({
    trendsDatabaseFile: trendsFile,
    trendsStatusFile: statusFile,
    getTrendOverview: async () => ({ trends: [] }),
    evaluateDuePredictions: async () => ({
      evaluated: 2,
      skipped: 1,
      failed: 3
    }),
    logger: {
      log: (...values) => logs.push(values.join(' ')),
      error: () => {}
    }
  });

  assert.ok(logs.some(line =>
    line.includes('2 başarılı, 1 atlanan, 3 başarısız')));
});

test('prediction API mevcut cevap yapısını korur', async () => {
  writeMemory([
    prediction({ id: 'api-shape', dueAt: '2999-01-01T00:00:00.000Z' })
  ]);
  const router = require('../routes/trends');
  const app = express();
  app.use('/api/trends', router);
  const server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });

  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/trends/predictions`
    );
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.deepEqual(Object.keys(body).sort(), [
      'count',
      'items',
      'status',
      'success',
      'updatedAt'
    ]);
    assert.equal(body.success, true);
    assert.equal(body.status, 'all');
    assert.equal(body.count, 1);
    assert.deepEqual(Object.keys(body.items[0]).sort(), [
      'asset',
      'createdAt',
      'dueAt',
      'evaluatedAt',
      'horizonDays',
      'id',
      'outcome',
      'prediction',
      'query',
      'scenarios',
      'statisticsSnapshot',
      'status',
      'technicalSnapshot'
    ]);
  } finally {
    await new Promise((resolve, reject) => server.close(error =>
      error ? reject(error) : resolve()));
  }
});
