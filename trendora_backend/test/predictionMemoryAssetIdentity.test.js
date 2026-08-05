const assert = require('node:assert/strict');
const { after, before, beforeEach, test } = require('node:test');
const fs = require('fs');
const os = require('os');
const path = require('path');

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), 'trendora-prediction-identity-')
);
const databasePath = path.join(temporaryDirectory, 'prediction_memory.json');
const previousMemoryFile = process.env.TRENDORA_PREDICTION_MEMORY_FILE;
process.env.TRENDORA_PREDICTION_MEMORY_FILE = databasePath;

function writeDatabase(predictions = []) {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
  fs.writeFileSync(
    databasePath,
    JSON.stringify({
      version: 1,
      updatedAt: new Date().toISOString(),
      predictions
    }, null, 2),
    'utf8'
  );
}

function financeAnalysis(query, entity) {
  return {
    query,
    domain: 'finance',
    entity,
    period: { days: 30 },
    confidence: 72,
    dailyPrice: { current: 100 },
    estimatedRange: { low: 90, mid: 100, high: 110, currency: 'TRY' },
    technical: { score: 61 },
    statistics: {},
    scenarios: [],
    sources: []
  };
}

function loadService() {
  delete require.cache[require.resolve('../services/trend/predictionMemoryService')];
  return require('../services/trend/predictionMemoryService');
}

before(() => writeDatabase([]));

beforeEach(() => {
  writeDatabase([]);
});

after(() => {
  if (previousMemoryFile == null) {
    delete process.env.TRENDORA_PREDICTION_MEMORY_FILE;
  } else {
    process.env.TRENDORA_PREDICTION_MEMORY_FILE = previousMemoryFile;
  }
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
});

test('ASELS aliases share the same central identity and pending record', () => {
  const service = loadService();
  const inputs = [
    ['ASELS', { name: 'ASELSAN', symbol: 'ASELS', subtype: 'bist_stock' }],
    ['ASELS.IS', { name: 'ASELSAN', symbol: 'ASELS.IS', subtype: 'bist_stock' }],
    ['ASELSAN', { name: 'Aselsan', symbol: 'ASELSAN', subtype: 'bist_stock' }]
  ];

  const predictions = inputs.map(([query, entity]) =>
    service.buildPredictionFromAnalysis(financeAnalysis(query, entity))
  );

  for (const prediction of predictions) {
    assert.equal(prediction.asset.internalAssetId, 'bist:equity:ASELS');
    assert.equal(prediction.asset.canonicalSymbol, 'ASELS');
    service.savePrediction(prediction);
  }

  const saved = service.getPredictions();
  assert.equal(saved.length, 1);
  assert.equal(saved[0].asset.internalAssetId, 'bist:equity:ASELS');
});

test('BIST 100 aliases share XU100 central identity', () => {
  const service = loadService();
  for (const query of ['BIST 100', 'BIST100', 'XU100']) {
    const prediction = service.buildPredictionFromAnalysis(
      financeAnalysis(query, {
        name: query,
        symbol: query,
        subtype: 'index'
      })
    );
    assert.equal(prediction.asset.internalAssetId, 'bist:index:XU100');
    assert.equal(prediction.asset.canonicalSymbol, 'XU100');
    assert.equal(prediction.asset.assetType, 'index');
    service.savePrediction(prediction);
  }
  assert.equal(service.getPredictions().length, 1);
});

test('non-catalog legacy asset and unknown query keep fallback behavior', () => {
  const service = loadService();
  const legacy = service.buildPredictionFromAnalysis(
    financeAnalysis('BTC', {
      name: 'Bitcoin',
      symbol: 'BTC',
      subtype: 'crypto'
    })
  );
  assert.equal(legacy.asset.symbol, 'BTC');
  assert.equal(legacy.asset.internalAssetId, undefined);
  assert.equal(service.savePrediction(legacy).asset.symbol, 'BTC');

  const unknown = service.buildPredictionFromAnalysis(
    financeAnalysis('bilinmeyen sembol', {
      name: 'Bilinmeyen',
      symbol: 'ZZZZZ',
      subtype: 'bist_stock'
    })
  );
  assert.equal(unknown.asset.symbol, 'ZZZZZ');
  assert.equal(unknown.asset.internalAssetId, undefined);
});

test('old prediction format is still readable', () => {
  writeDatabase([
    {
      id: 'legacy_prediction',
      createdAt: '2026-01-01T00:00:00.000Z',
      status: 'pending',
      evaluatedAt: null,
      outcome: null,
      query: 'OLD',
      asset: { name: 'Old Asset', symbol: 'OLD', subtype: 'legacy' },
      dueAt: '2026-02-01T00:00:00.000Z'
    }
  ]);

  const service = loadService();
  const predictions = service.getPredictions();
  assert.equal(predictions.length, 1);
  assert.equal(predictions[0].asset.symbol, 'OLD');
  assert.equal(predictions[0].asset.internalAssetId, undefined);
});

test('central catalog fields are added to prediction asset', () => {
  const service = loadService();
  const prediction = service.buildPredictionFromAnalysis(
    financeAnalysis('USD/TRY', {
      name: 'Dolar/TL',
      symbol: 'USDTRY',
      subtype: 'fx'
    })
  );

  assert.equal(prediction.asset.internalAssetId, 'fx:USDTRY');
  assert.equal(prediction.asset.canonicalSymbol, 'USDTRY');
  assert.equal(prediction.asset.displayName, 'USD/TRY');
  assert.equal(prediction.asset.assetType, 'fx');
  assert.equal(prediction.asset.currency, 'TRY');
});

test('matcher failure does not stop prediction memory fallback', () => {
  const matcher = require('../services/assets/assetMatcher');
  const originalMatchAsset = matcher.matchAsset;
  matcher.matchAsset = () => {
    throw new Error('forced matcher failure');
  };

  try {
    const service = loadService();
    const prediction = service.buildPredictionFromAnalysis(
      financeAnalysis('ASELS', {
        name: 'ASELSAN',
        symbol: 'ASELS',
        subtype: 'bist_stock'
      })
    );
    assert.equal(prediction.asset.symbol, 'ASELS');
    assert.equal(prediction.asset.internalAssetId, undefined);
    assert.equal(service.savePrediction(prediction).asset.symbol, 'ASELS');
  } finally {
    matcher.matchAsset = originalMatchAsset;
  }
});

test('evaluated history for the same asset is preserved when a new pending prediction is saved', () => {
  writeDatabase([
    {
      id: 'evaluated_asels_prediction',
      createdAt: '2026-01-01T00:00:00.000Z',
      status: 'evaluated',
      evaluatedAt: '2026-02-01T00:00:00.000Z',
      outcome: { directionMatched: true },
      query: 'ASELS',
      asset: {
        name: 'ASELSAN',
        symbol: 'ASELS',
        subtype: 'bist_stock',
        internalAssetId: 'bist:equity:ASELS',
        canonicalSymbol: 'ASELS'
      },
      dueAt: '2026-02-01T00:00:00.000Z'
    }
  ]);

  const service = loadService();
  const prediction = service.buildPredictionFromAnalysis(
    financeAnalysis('ASELS.IS', {
      name: 'ASELSAN',
      symbol: 'ASELS.IS',
      subtype: 'bist_stock'
    })
  );
  const saved = service.savePrediction(prediction);
  const predictions = service.getPredictions();

  assert.equal(saved.status, 'pending');
  assert.equal(predictions.length, 2);
  assert.ok(predictions.some(item =>
    item.id === 'evaluated_asels_prediction' &&
    item.status === 'evaluated' &&
    item.outcome?.directionMatched === true
  ));
  assert.ok(predictions.some(item =>
    item.status === 'pending' &&
    item.asset?.internalAssetId === 'bist:equity:ASELS'
  ));
});
