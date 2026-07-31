'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const Module = require('module');

const {
  runAssetCatalogSync,
  startAssetCatalogSyncScheduler,
  stopAssetCatalogSyncScheduler
} = require('../services/assets/assetCatalogSyncService');
const { ASSET_CATALOG } = require('../services/assets/assetCatalog');

const assetCatalogPath = path.join(__dirname, '..', 'services', 'assets', 'assetCatalog.js');

const sampleBist = ASSET_CATALOG
  .filter(asset => asset.assetType === 'equity' && asset.exchange === 'BIST')
  .map(asset => ({ symbol: asset.canonicalSymbol, name: asset.displayName }));

const sampleTefas = ASSET_CATALOG
  .filter(asset => asset.assetType === 'fund' && asset.market === 'TEFAS')
  .map(asset => ({ code: asset.canonicalSymbol, name: asset.displayName }));

function quietOptions(extra = {}) {
  return {
    logger: false,
    fetchBistSource: async () => sampleBist,
    fetchTefasSource: async () => sampleTefas,
    ...extra
  };
}

test('unchanged BIST and TEFAS sources produce no changes', async () => {
  const result = await runAssetCatalogSync(quietOptions());

  assert.equal(result.status, 'success');
  assert.equal(result.changed, false);
  assert.equal(result.bist.sourceCount, 750);
  assert.equal(result.tefas.sourceCount, 774);
  assert.deepEqual(result.bist.added, []);
  assert.deepEqual(result.tefas.added, []);
});

test('new BIST symbol is reported in added list', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchBistSource: async () => [
      ...sampleBist,
      { symbol: 'ZZABC', name: 'ZZ TEST ANONIM SIRKETI' }
    ]
  }));

  assert.equal(result.changed, true);
  assert.equal(result.bist.added.length, 1);
  assert.equal(result.bist.added[0].canonicalSymbol, 'ZZABC');
  assert.equal(result.bist.added[0].internalAssetId, 'bist:equity:ZZABC');
  assert.equal(result.bist.added[0].providerSymbols.yahoo, 'ZZABC.IS');
});

test('new active TEFAS fund is reported in added list', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchTefasSource: async () => [
      ...sampleTefas,
      { code: 'ZZF', name: 'ZZ PORTFOY TEST FONU' }
    ]
  }));

  assert.equal(result.changed, true);
  assert.equal(result.tefas.added.length, 1);
  assert.equal(result.tefas.added[0].canonicalSymbol, 'ZZF');
  assert.equal(result.tefas.added[0].internalAssetId, 'tefas:fund:ZZF');
  assert.equal(result.tefas.added[0].providerSymbols.yahoo, null);
});

test('TEFAS name change is reported as metadata change, not a new fund', async () => {
  const changed = sampleTefas.map(item =>
    item.code === 'AFT'
      ? { ...item, name: 'AK PORTFOY YENI TEKNOLOJILER FONU YENI AD' }
      : item
  );

  const result = await runAssetCatalogSync(quietOptions({
    fetchTefasSource: async () => changed
  }));

  assert.equal(result.tefas.added.length, 0);
  assert.ok(result.tefas.metadataChanged.some(item => item.canonicalSymbol === 'AFT'));
});

test('source-missing catalog assets are reported but never deleted', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchBistSource: async () => sampleBist.filter(item => item.symbol !== 'ASELS')
  }));

  assert.equal(result.changed, true);
  assert.ok(result.bist.missingFromSource.some(item => item.canonicalSymbol === 'ASELS'));
  assert.ok(ASSET_CATALOG.some(asset => asset.canonicalSymbol === 'ASELS'));
});

test('empty BIST source is degraded and does not mass-report deletions', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchBistSource: async () => []
  }));

  assert.equal(result.status, 'degraded');
  assert.equal(result.bist.valid, false);
  assert.deepEqual(result.bist.missingFromSource, []);
  assert.ok(result.errors.some(error => error.source === 'bist'));
});

test('empty TEFAS source is degraded and does not mass-report deletions', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchTefasSource: async () => []
  }));

  assert.equal(result.status, 'degraded');
  assert.equal(result.tefas.valid, false);
  assert.deepEqual(result.tefas.missingFromSource, []);
  assert.ok(result.errors.some(error => error.source === 'tefas'));
});

test('source failures leave catalog untouched and are reported as degraded', async () => {
  const before = ASSET_CATALOG.length;
  const result = await runAssetCatalogSync(quietOptions({
    fetchBistSource: async () => {
      throw new Error('network down');
    }
  }));

  assert.equal(result.status, 'degraded');
  assert.equal(ASSET_CATALOG.length, before);
  assert.ok(result.errors.some(error => error.source === 'bist' && error.message.includes('network down')));
});

test('assetType or canonical collisions are reported as conflicts', async () => {
  const result = await runAssetCatalogSync(quietOptions({
    fetchTefasSource: async () => [
      ...sampleTefas,
      { code: 'ASELS', name: 'CONFLICT FUND' }
    ]
  }));

  assert.equal(result.tefas.added.length, 0);
  assert.ok(result.tefas.conflicts.some(item => item.code === 'ASELS' && item.assetType === 'equity'));
});

test('dry-run mode does not rewrite assetCatalog.js', async () => {
  const before = fs.readFileSync(assetCatalogPath, 'utf8');

  const result = await runAssetCatalogSync(quietOptions({
    mode: 'dry-run',
    fetchBistSource: async () => [
      ...sampleBist,
      { symbol: 'ZZDRY', name: 'ZZ DRY RUN A.S.' }
    ]
  }));

  const after = fs.readFileSync(assetCatalogPath, 'utf8');
  assert.equal(result.mode, 'dry-run');
  assert.equal(result.changed, true);
  assert.equal(after, before);
});

test('sync service does not load OpenAI or AI services', async () => {
  const originalLoad = Module._load;
  const forbidden = [];

  Module._load = function patchedLoad(request, parent, isMain) {
    if (String(request).toLowerCase().includes('openai')) {
      forbidden.push(request);
      throw new Error(`forbidden AI module: ${request}`);
    }
    return originalLoad.call(this, request, parent, isMain);
  };

  try {
    const result = await runAssetCatalogSync(quietOptions());
    assert.equal(result.status, 'success');
    assert.deepEqual(forbidden, []);
  } finally {
    Module._load = originalLoad;
  }
});

test('scheduler starts only once when explicitly enabled', () => {
  stopAssetCatalogSyncScheduler();
  const first = startAssetCatalogSyncScheduler({
    enabled: true,
    initialDelayMs: 60 * 60 * 1000,
    logger: false
  });
  const second = startAssetCatalogSyncScheduler({
    enabled: true,
    initialDelayMs: 60 * 60 * 1000,
    logger: false
  });

  assert.equal(first.started, true);
  assert.equal(second.started, false);
  assert.equal(second.reason, 'already_started');
  stopAssetCatalogSyncScheduler();
});

test('scheduler does not start when environment is disabled', () => {
  stopAssetCatalogSyncScheduler();
  const result = startAssetCatalogSyncScheduler({
    enabled: false,
    logger: false
  });

  assert.deepEqual(result, { started: false, reason: 'disabled' });
});

test('current catalog counts are preserved', () => {
  const counts = ASSET_CATALOG.reduce((accumulator, asset) => {
    accumulator[asset.assetType] = (accumulator[asset.assetType] || 0) + 1;
    return accumulator;
  }, {});

  assert.equal(counts.equity, 750);
  assert.equal(counts.index, 28);
  assert.equal(counts.fund, 774);
  assert.equal(counts.fx, 17);
  assert.equal(counts.commodity, 21);
  assert.equal(counts.certificate, 1);
  assert.equal(ASSET_CATALOG.length, 1591);
});
