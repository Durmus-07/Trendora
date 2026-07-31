'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

const EXPECTED_FX_SYMBOLS = Object.freeze([
  'USDTRY',
  'EURTRY',
  'GBPTRY',
  'CHFTRY',
  'JPYTRY',
  'CADTRY',
  'AUDTRY',
  'NZDTRY',
  'CNYTRY',
  'RUBTRY',
  'SARTRY',
  'AEDTRY',
  'QARTRY',
  'KWDTRY',
  'NOKTRY',
  'SEKTRY',
  'DKKTRY'
]);

const EXPECTED_BIST_EQUITY_COUNT = 750;
const EXPECTED_BIST_INDEX_COUNT = 28;
const EXPECTED_TEFAS_FUND_COUNT = 774;

const fxAssets = ASSET_CATALOG.filter(asset => asset.assetType === 'fx');

function duplicates(values) {
  const seen = new Set();
  const duplicateValues = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicateValues.add(value);
    seen.add(value);
  }
  return [...duplicateValues].sort();
}

function assertFx(query, expectedSymbol) {
  const result = matchAsset(query);
  assert.equal(result.matched, true, query);
  assert.equal(result.asset.canonicalSymbol, expectedSymbol, query);
  assert.equal(result.asset.assetType, 'fx', query);
  assert.equal(result.asset.internalAssetId, `fx:${expectedSymbol}`, query);
}

test('expected TRY-based FX pairs exist in catalog', () => {
  assert.deepEqual(fxAssets.map(asset => asset.canonicalSymbol).sort(), [...EXPECTED_FX_SYMBOLS].sort());
});

test('all FX records use the existing FX identity shape', () => {
  for (const asset of fxAssets) {
    assert.equal(asset.assetType, 'fx');
    assert.equal(asset.exchange, null);
    assert.equal(asset.market, 'FX');
    assert.equal(asset.currency, 'TRY');
    assert.match(asset.canonicalSymbol, /^[A-Z]{3}TRY$/);
    assert.equal(asset.internalAssetId, `fx:${asset.canonicalSymbol}`);
  }
});

test('FX canonical symbols and internal ids are unique', () => {
  assert.deepEqual(duplicates(fxAssets.map(asset => asset.canonicalSymbol)), []);
  assert.deepEqual(duplicates(fxAssets.map(asset => asset.internalAssetId)), []);
});

test('verified provider symbol is preserved and unverified pairs stay null', () => {
  assert.equal(resolveProviderSymbol('fx:USDTRY', 'yahoo'), 'TRY=X');

  for (const symbol of EXPECTED_FX_SYMBOLS.filter(item => item !== 'USDTRY')) {
    assert.equal(resolveProviderSymbol(`fx:${symbol}`, 'yahoo'), null, symbol);
  }

  assert.deepEqual(duplicates(fxAssets.map(asset => asset.providerSymbols.yahoo).filter(Boolean)), []);
});

test('USD/TRY aliases resolve to the same central FX asset', () => {
  for (const query of ['USDTRY', 'USD/TRY', 'usd try', 'dolar TL', 'dolar kuru']) {
    assertFx(query, 'USDTRY');
  }

  assertFx('dolar', 'USDTRY');
});

test('EUR/TRY aliases resolve to the same central FX asset', () => {
  for (const query of ['EURTRY', 'EUR/TRY', 'eur try', 'euro TL', 'euro kuru', 'avro TL', 'avro kuru']) {
    assertFx(query, 'EURTRY');
  }
});

test('sterling, franc, yen and dirham examples resolve to their TRY pairs', () => {
  assertFx('sterlin tl', 'GBPTRY');
  assertFx('sterlin kuru', 'GBPTRY');
  assertFx('frank tl', 'CHFTRY');
  assertFx('japon yeni tl', 'JPYTRY');
  assertFx('yen tl', 'JPYTRY');
  assertFx('bae dirhemi tl', 'AEDTRY');
  assertFx('dubai dirhemi', 'AEDTRY');
  assertFx('dirhem tl', 'AEDTRY');
});

test('the same FX pair is not represented by multiple catalog records', () => {
  for (const symbol of EXPECTED_FX_SYMBOLS) {
    assert.equal(fxAssets.filter(asset => asset.canonicalSymbol === symbol).length, 1, symbol);
  }
});

test('currency codes do not resolve to TEFAS funds or BIST equities by themselves', () => {
  for (const query of ['USD', 'EUR', 'GBP']) {
    const result = matchAsset(query);

    assert.notEqual(result.asset?.assetType, 'fund', query);
    assert.notEqual(result.asset?.assetType, 'equity', query);
  }
});

test('generic currency words keep documented legacy behavior or remain unmatched', () => {
  assertFx('dolar', 'USDTRY');

  for (const query of ['kur', 'doviz', 'para']) {
    const result = matchAsset(query);

    assert.equal(result.matched, false, query);
  }
});

test('FX symbols do not collide with non-FX asset canonical symbols', () => {
  const nonFxSymbols = new Set(
    ASSET_CATALOG
      .filter(asset => asset.assetType !== 'fx')
      .map(asset => asset.canonicalSymbol)
  );
  const collisions = fxAssets
    .map(asset => asset.canonicalSymbol)
    .filter(symbol => nonFxSymbols.has(symbol));

  assert.deepEqual(collisions, []);
});

test('existing BIST equity, BIST index and TEFAS fund counts are preserved', () => {
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'equity' && asset.exchange === 'BIST').length, EXPECTED_BIST_EQUITY_COUNT);
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'index' && asset.exchange === 'BIST').length, EXPECTED_BIST_INDEX_COUNT);
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'fund' && asset.market === 'TEFAS').length, EXPECTED_TEFAS_FUND_COUNT);
});
