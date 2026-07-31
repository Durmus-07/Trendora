const assert = require('node:assert/strict');
const { test } = require('node:test');

const orchestratorPath = require.resolve('../services/trend/analysisOrchestrator');
const trendEnginePath = require.resolve('../services/trendEngine');

function loadTrendEngineWithStub(stub) {
  delete require.cache[trendEnginePath];
  require.cache[orchestratorPath] = {
    id: orchestratorPath,
    filename: orchestratorPath,
    loaded: true,
    exports: { analyzeQuestion: stub }
  };
  return require('../services/trendEngine');
}

function clearLoadedModules() {
  delete require.cache[trendEnginePath];
  delete require.cache[orchestratorPath];
}

test('same equity aliases use one analysis identity and cache entry', async () => {
  let calls = 0;
  const engine = loadTrendEngineWithStub(async query => {
    calls += 1;
    return {
      query,
      domain: 'finance',
      entity: {
        symbol: 'ASELS',
        internalAssetId: 'bist:equity:ASELS',
        canonicalSymbol: 'ASELS'
      },
      confidence: 70,
      engine: { mode: 'stub' }
    };
  });

  const first = await engine.analyzeQuery('ASELS');
  const second = await engine.analyzeQuery('ASELSAN');
  const third = await engine.analyzeQuery('ASELS.IS');

  assert.equal(calls, 1);
  assert.equal(first.engine.cache, 'miss');
  assert.equal(second.engine.cache, 'hit');
  assert.equal(third.engine.cache, 'hit');
  assert.equal(second.entity.internalAssetId, 'bist:equity:ASELS');
  clearLoadedModules();
});

test('BIST index aliases use one analysis identity and cache entry', async () => {
  let calls = 0;
  const engine = loadTrendEngineWithStub(async query => {
    calls += 1;
    return {
      query,
      domain: 'finance',
      entity: {
        symbol: 'XU100',
        internalAssetId: 'bist:index:XU100',
        canonicalSymbol: 'XU100',
        assetType: 'index'
      },
      confidence: 66,
      engine: { mode: 'stub' }
    };
  });

  await engine.analyzeQuery('BIST 100');
  const second = await engine.analyzeQuery('BIST100');
  const third = await engine.analyzeQuery('XU100');

  assert.equal(calls, 1);
  assert.equal(second.engine.cache, 'hit');
  assert.equal(third.entity.canonicalSymbol, 'XU100');
  clearLoadedModules();
});

test('non-catalog assets keep legacy query based analysis behavior', async () => {
  let calls = 0;
  const engine = loadTrendEngineWithStub(async query => {
    calls += 1;
    return {
      query,
      domain: 'finance',
      entity: { symbol: query, subtype: 'bist_stock' },
      confidence: 60,
      engine: { mode: 'stub' }
    };
  });

  await engine.analyzeQuery('BIMAS');
  await engine.analyzeQuery('BIMAS');
  await engine.analyzeQuery('BIMAS farkli soru');

  assert.equal(calls, 2);
  clearLoadedModules();
});

test('matcher failure does not stop analysis and response format is preserved', async () => {
  const matcher = require('../services/assets/assetMatcher');
  const originalMatchAsset = matcher.matchAsset;
  matcher.matchAsset = () => {
    throw new Error('forced matcher failure');
  };

  try {
    let calls = 0;
    const engine = loadTrendEngineWithStub(async query => {
      calls += 1;
      return {
        query,
        domain: 'finance',
        entity: { symbol: 'ASELS', name: 'ASELSAN', subtype: 'bist_stock' },
        confidence: 71,
        answerTitle: 'Trendora Analizi',
        engine: { mode: 'stub' }
      };
    });

    const result = await engine.analyzeQuery('ASELS');

    assert.equal(calls, 1);
    assert.equal(result.query, 'ASELS');
    assert.equal(result.domain, 'finance');
    assert.equal(result.entity.symbol, 'ASELS');
    assert.equal(result.confidence, 71);
    assert.equal(result.answerTitle, 'Trendora Analizi');
    assert.equal(result.engine.cache, 'miss');
    clearLoadedModules();
  } finally {
    matcher.matchAsset = originalMatchAsset;
  }
});
