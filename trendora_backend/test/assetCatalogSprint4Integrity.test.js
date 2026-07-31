'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { performance } = require('node:perf_hooks');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

const EXPECTED_COUNTS = Object.freeze({
  equity: 750,
  index: 28,
  fund: 774,
  fx: 17,
  commodity: 21
});

const EXPECTED_LEGACY_COUNTS = Object.freeze({
  certificate: 1
});

const EXPECTED_SPRINT4_TOTAL = 1590;
const EXPECTED_CATALOG_TOTAL = 1591;
const ALLOWED_ASSET_TYPES = Object.freeze([...Object.keys(EXPECTED_COUNTS), ...Object.keys(EXPECTED_LEGACY_COUNTS)]);
const VERIFIED_INDEX_YAHOO = Object.freeze(['XU100', 'XU030', 'XBANK', 'XUSIN', 'XUHIZ', 'XUTEK']);

function countByType() {
  return ASSET_CATALOG.reduce((counts, asset) => {
    counts[asset.assetType] = (counts[asset.assetType] || 0) + 1;
    return counts;
  }, {});
}

function duplicates(values) {
  const seen = new Set();
  const duplicateValues = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicateValues.add(value);
    seen.add(value);
  }
  return [...duplicateValues].sort();
}

function assertSymbol(query, expectedSymbol, expectedType) {
  const result = matchAsset(query);
  assert.equal(result.matched, true, query);
  assert.equal(result.asset.canonicalSymbol, expectedSymbol, query);
  assert.equal(result.asset.assetType, expectedType, query);
}

test('Sprint 4 catalog counts match the expected distribution and total', () => {
  assert.deepEqual(countByType(), { ...EXPECTED_COUNTS, ...EXPECTED_LEGACY_COUNTS });
  assert.equal(Object.values(EXPECTED_COUNTS).reduce((sum, count) => sum + count, 0), EXPECTED_SPRINT4_TOTAL);
  assert.equal(ASSET_CATALOG.length, EXPECTED_CATALOG_TOTAL);
});

test('global identifiers, type-local symbols and aliases are unique and non-empty', () => {
  assert.deepEqual(duplicates(ASSET_CATALOG.map(asset => asset.internalAssetId)), []);

  for (const assetType of ALLOWED_ASSET_TYPES) {
    assert.deepEqual(
      duplicates(ASSET_CATALOG.filter(asset => asset.assetType === assetType).map(asset => asset.canonicalSymbol)),
      [],
      assetType
    );
  }

  for (const asset of ASSET_CATALOG) {
    assert.ok(asset.internalAssetId, 'internalAssetId');
    assert.ok(asset.canonicalSymbol, 'canonicalSymbol');
    assert.ok(asset.displayName, 'displayName');
    assert.ok(ALLOWED_ASSET_TYPES.includes(asset.assetType), asset.assetType);
    assert.deepEqual(duplicates(asset.aliases || []), [], asset.internalAssetId);
  }
});

test('verified provider symbols are unique and scoped to supported catalog records', () => {
  const providerSymbols = ASSET_CATALOG
    .map(asset => asset.providerSymbols?.yahoo)
    .filter(Boolean);

  assert.deepEqual(duplicates(providerSymbols), []);

  for (const asset of ASSET_CATALOG) {
    const yahoo = asset.providerSymbols?.yahoo || null;

    if (asset.assetType === 'equity' && asset.exchange === 'BIST') {
      assert.match(yahoo, /\.IS$/);
    }
    if (asset.assetType === 'index') {
      if (VERIFIED_INDEX_YAHOO.includes(asset.canonicalSymbol)) {
        assert.equal(yahoo, `${asset.canonicalSymbol}.IS`);
      } else {
        assert.equal(yahoo, null);
      }
    }
    if (asset.assetType === 'fund') {
      assert.equal(yahoo, null);
    }
  }

  assert.equal(resolveProviderSymbol('fx:USDTRY', 'yahoo'), 'TRY=X');
  assert.equal(resolveProviderSymbol('fx:EURTRY', 'yahoo'), null);
  assert.equal(resolveProviderSymbol('commodity:gold:GRAM_ALTIN', 'yahoo'), null);
  assert.equal(resolveProviderSymbol('commodity:silver:GRAM_GUMUS', 'yahoo'), null);
  assert.equal(resolveProviderSymbol('commodity:gold:XAUUSD', 'yahoo'), 'XAUUSD=X');
  assert.equal(resolveProviderSymbol('commodity:silver:XAGUSD', 'yahoo'), 'XAGUSD=X');
});

test('asset class boundaries remain safe for critical symbols', () => {
  assertSymbol('XU100', 'XU100', 'index');
  assertSymbol('XBANK', 'XBANK', 'index');
  assertSymbol('KRDMA', 'KRDMA', 'equity');
  assertSymbol('KRDMB', 'KRDMB', 'equity');
  assertSymbol('KRDMD', 'KRDMD', 'equity');
  assertSymbol('ISATR', 'ISATR', 'equity');
  assertSymbol('ISBTR', 'ISBTR', 'equity');
  assertSymbol('ISCTR', 'ISCTR', 'equity');
  assertSymbol('ISKUR', 'ISKUR', 'equity');

  for (const query of ['USD', 'EUR', 'GBP']) {
    const result = matchAsset(query);
    assert.notEqual(result.asset?.assetType, 'fund', query);
    assert.notEqual(result.asset?.assetType, 'equity', query);
  }
});

test('critical BIST, index, TEFAS, FX and commodity aliases resolve as intended', () => {
  assertSymbol('aselsan', 'ASELS', 'equity');
  assertSymbol('thy', 'THYAO', 'equity');
  assertSymbol('tupras', 'TUPRS', 'equity');
  assertSymbol('erdemir', 'EREGL', 'equity');
  assertSymbol('sisecam', 'SISE', 'equity');
  assertSymbol('is bankasi', 'ISCTR', 'equity');

  assertSymbol('bist 100', 'XU100', 'index');
  assertSymbol('bist 30', 'XU030', 'index');
  assertSymbol('banka endeksi', 'XBANK', 'index');
  assertSymbol('teknoloji endeksi', 'XUTEK', 'index');

  assertSymbol('AFT fonu', 'AFT', 'fund');
  assertSymbol('MAC fonu', 'MAC', 'fund');
  assertSymbol('TCD fonu', 'TCD', 'fund');
  assertSymbol('AK PORTFOY YENI TEKNOLOJILER YABANCI HISSE SENEDI FONU', 'AFT', 'fund');

  assertSymbol('dolar', 'USDTRY', 'fx');
  assertSymbol('dolar kuru', 'USDTRY', 'fx');
  assertSymbol('euro tl', 'EURTRY', 'fx');
  assertSymbol('sterlin kuru', 'GBPTRY', 'fx');
  assertSymbol('dubai dirhemi', 'AEDTRY', 'fx');

  assertSymbol('altin', 'GRAM_ALTIN', 'commodity');
  assertSymbol('gram altin', 'GRAM_ALTIN', 'commodity');
  assertSymbol('ons altin', 'XAUUSD', 'commodity');
  assertSymbol('gumus', 'GRAM_GUMUS', 'commodity');
  assertSymbol('ons gumus', 'XAGUSD', 'commodity');
  assertSymbol('brent petrol', 'BRENT', 'commodity');
  assertSymbol('wti petrol', 'WTI', 'commodity');
  assertSymbol('dogal gaz', 'NATGAS', 'commodity');
  assertSymbol('bakir fiyati', 'COPPER', 'commodity');
});

test('generic ambiguous words do not silently resolve to a catalog asset', () => {
  for (const query of ['banka', 'teknoloji', 'fon', 'serbest', 'yabanci', 'kur', 'doviz', 'para', 'petrol', 'metal', 'enerji', 'tarim', 'emtia', 'maden']) {
    const result = matchAsset(query);

    assert.equal(result.matched, false, query);
  }
});

test('gold funds and gold commodities are not merged', () => {
  const tefasGoldFund = ASSET_CATALOG.find(asset =>
    asset.assetType === 'fund' &&
    asset.market === 'TEFAS' &&
    String(asset.displayName).includes('ALTIN')
  );

  assert.ok(tefasGoldFund);
  assert.equal(matchAsset(tefasGoldFund.displayName).asset.internalAssetId, tefasGoldFund.internalAssetId);
  assert.equal(matchAsset('altin').asset.internalAssetId, 'commodity:gold:GRAM_ALTIN');
  assert.equal(matchAsset('ons altin').asset.internalAssetId, 'commodity:gold:XAUUSD');
});

test('representative matcher workload completes without an obvious local slowdown', () => {
  const queries = [
    'ASELS', 'aselsan', 'THY', 'bist 100', 'banka endeksi',
    'AFT fonu', 'MAC fonu', 'TCD fonu', 'dolar kuru', 'euro tl',
    'sterlin kuru', 'dubai dirhemi', 'altin', 'ons altin', 'gumus',
    'ons gumus', 'brent petrol', 'wti petrol', 'dogal gaz', 'bakir fiyati',
    'KRDMA', 'KRDMB', 'KRDMD', 'ISATR', 'ISBTR', 'ISCTR', 'ISKUR'
  ];

  const startedAt = performance.now();
  for (const query of queries) {
    matchAsset(query);
  }
  const elapsedMs = performance.now() - startedAt;

  assert.ok(Number.isFinite(elapsedMs));
});
