'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

const EXPECTED_COMMODITY_SYMBOLS = Object.freeze([
  'XAUUSD',
  'GRAM_ALTIN',
  'XAGUSD',
  'GRAM_GUMUS',
  'XPTUSD',
  'XPDUSD',
  'BRENT',
  'WTI',
  'NATGAS',
  'COPPER',
  'ALUMINUM',
  'ZINC',
  'NICKEL',
  'LEAD',
  'IRONORE',
  'WHEAT',
  'CORN',
  'COTTON',
  'COFFEE',
  'COCOA',
  'SUGAR'
]);

const EXPECTED_BIST_EQUITY_COUNT = 750;
const EXPECTED_BIST_INDEX_COUNT = 28;
const EXPECTED_TEFAS_FUND_COUNT = 774;
const EXPECTED_FX_COUNT = 17;

const commodities = ASSET_CATALOG.filter(asset => asset.assetType === 'commodity');

function duplicates(values) {
  const seen = new Set();
  const duplicateValues = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicateValues.add(value);
    seen.add(value);
  }
  return [...duplicateValues].sort();
}

function assertCommodity(query, expectedSymbol) {
  const result = matchAsset(query);
  assert.equal(result.matched, true, query);
  assert.equal(result.asset.canonicalSymbol, expectedSymbol, query);
  assert.equal(result.asset.assetType, 'commodity', query);
}

test('expected core commodities exist in catalog', () => {
  assert.deepEqual(commodities.map(asset => asset.canonicalSymbol).sort(), [...EXPECTED_COMMODITY_SYMBOLS].sort());
});

test('all commodity records use the existing commodity identity shape', () => {
  for (const asset of commodities) {
    assert.equal(asset.assetType, 'commodity');
    assert.equal(asset.exchange, null);
    assert.equal(asset.market, 'COMMODITY');
    assert.match(asset.internalAssetId, /^commodity:[a-z]+:[A-Z_]+$/);
    assert.ok(asset.currency === 'USD' || asset.currency === 'TRY');
  }
});

test('commodity canonical symbols and internal ids are unique', () => {
  assert.deepEqual(duplicates(commodities.map(asset => asset.canonicalSymbol)), []);
  assert.deepEqual(duplicates(commodities.map(asset => asset.internalAssetId)), []);
});

test('verified spot provider symbols are set and unverified commodities stay null', () => {
  assert.equal(resolveProviderSymbol('commodity:gold:XAUUSD', 'yahoo'), 'XAUUSD=X');
  assert.equal(resolveProviderSymbol('commodity:silver:XAGUSD', 'yahoo'), 'XAGUSD=X');

  for (const symbol of EXPECTED_COMMODITY_SYMBOLS.filter(item => !['XAUUSD', 'XAGUSD'].includes(item))) {
    const asset = commodities.find(item => item.canonicalSymbol === symbol);
    assert.equal(resolveProviderSymbol(asset, 'yahoo'), null, symbol);
  }

  assert.deepEqual(duplicates(commodities.map(asset => asset.providerSymbols.yahoo).filter(Boolean)), []);
});

test('gold ounce and gram gold are separate central assets', () => {
  assertCommodity('xauusd', 'XAUUSD');
  assertCommodity('xau/usd', 'XAUUSD');
  assertCommodity('ons altin', 'XAUUSD');

  assertCommodity('altin', 'GRAM_ALTIN');
  assertCommodity('gram altin', 'GRAM_ALTIN');
  assertCommodity('altin gram', 'GRAM_ALTIN');

  assert.notEqual(
    matchAsset('xauusd').asset.internalAssetId,
    matchAsset('gram altin').asset.internalAssetId
  );
});

test('silver ounce and gram silver are separate central assets', () => {
  assertCommodity('xagusd', 'XAGUSD');
  assertCommodity('xag/usd', 'XAGUSD');
  assertCommodity('ons gumus', 'XAGUSD');

  assertCommodity('gumus', 'GRAM_GUMUS');
  assertCommodity('gram gumus', 'GRAM_GUMUS');
  assertCommodity('gumus gram', 'GRAM_GUMUS');

  assert.notEqual(
    matchAsset('xagusd').asset.internalAssetId,
    matchAsset('gram gumus').asset.internalAssetId
  );
});

test('energy and industrial commodity aliases resolve to intended assets', () => {
  assertCommodity('brent', 'BRENT');
  assertCommodity('brent petrol', 'BRENT');
  assertCommodity('wti', 'WTI');
  assertCommodity('amerikan ham petrol', 'WTI');
  assertCommodity('dogal gaz', 'NATGAS');
  assertCommodity('natural gas', 'NATGAS');
  assertCommodity('bakir fiyati', 'COPPER');
  assertCommodity('copper', 'COPPER');
});

test('generic commodity words do not silently resolve to a specific commodity', () => {
  for (const query of ['metal', 'enerji', 'tarim', 'emtia', 'petrol', 'gaz', 'maden']) {
    const result = matchAsset(query);

    assert.notEqual(result.asset?.assetType, 'commodity', query);
  }
});

test('TEFAS gold fund full names do not resolve to commodity gold', () => {
  const tefasGoldFund = ASSET_CATALOG.find(asset =>
    asset.assetType === 'fund' &&
    asset.market === 'TEFAS' &&
    String(asset.displayName).includes('ALTIN')
  );

  assert.ok(tefasGoldFund, 'expected at least one TEFAS gold fund fixture');

  const result = matchAsset(tefasGoldFund.displayName);
  assert.equal(result.asset.internalAssetId, tefasGoldFund.internalAssetId);
  assert.equal(result.asset.assetType, 'fund');
});

test('commodity symbols do not collide with non-commodity canonical symbols', () => {
  const nonCommoditySymbols = new Set(
    ASSET_CATALOG
      .filter(asset => asset.assetType !== 'commodity')
      .map(asset => asset.canonicalSymbol)
  );
  const collisions = commodities
    .map(asset => asset.canonicalSymbol)
    .filter(symbol => nonCommoditySymbols.has(symbol));

  assert.deepEqual(collisions, []);
});

test('existing BIST equity, BIST index, TEFAS fund and FX counts are preserved', () => {
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'equity' && asset.exchange === 'BIST').length, EXPECTED_BIST_EQUITY_COUNT);
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'index' && asset.exchange === 'BIST').length, EXPECTED_BIST_INDEX_COUNT);
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'fund' && asset.market === 'TEFAS').length, EXPECTED_TEFAS_FUND_COUNT);
  assert.equal(ASSET_CATALOG.filter(asset => asset.assetType === 'fx').length, EXPECTED_FX_COUNT);
});
