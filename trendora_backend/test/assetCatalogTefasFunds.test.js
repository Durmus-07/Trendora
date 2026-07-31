'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');

const EXPECTED_TEFAS_FUND_COUNT = 774;
const EXPECTED_BIST_EQUITY_COUNT = 750;
const EXPECTED_BIST_INDEX_COUNT = 28;

const tefasFunds = ASSET_CATALOG.filter(asset => asset.assetType === 'fund' && asset.market === 'TEFAS');
const bistEquities = ASSET_CATALOG.filter(asset => asset.assetType === 'equity' && asset.exchange === 'BIST');
const bistIndices = ASSET_CATALOG.filter(asset => asset.assetType === 'index' && asset.exchange === 'BIST');

function duplicates(values) {
  const seen = new Set();
  const duplicateValues = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicateValues.add(value);
    seen.add(value);
  }
  return [...duplicateValues].sort();
}

function fundByCode(code) {
  return tefasFunds.find(asset => asset.canonicalSymbol === code);
}

test('TEFAS active fund count matches the fixed source count', () => {
  assert.equal(tefasFunds.length, EXPECTED_TEFAS_FUND_COUNT);
});

test('known active TEFAS fund codes are present', () => {
  for (const code of ['AFT', 'MAC', 'TCD', 'YAY', 'IPB']) {
    const asset = fundByCode(code);
    assert.ok(asset, `${code} should be in TEFAS fund catalog`);
    assert.equal(asset.internalAssetId, `tefas:fund:${code}`);
  }
});

test('all TEFAS fund records use fund asset type and TEFAS market identity', () => {
  assert.ok(tefasFunds.length > 0);
  for (const asset of tefasFunds) {
    assert.equal(asset.assetType, 'fund');
    assert.equal(asset.exchange, 'TEFAS');
    assert.equal(asset.market, 'TEFAS');
    assert.equal(asset.providerSymbols.yahoo, null);
    assert.match(asset.internalAssetId, /^tefas:fund:[A-Z0-9]{3,6}$/);
    assert.match(asset.canonicalSymbol, /^[A-Z0-9]{3,6}$/);
  }
});

test('TEFAS fund identifiers and provider symbols do not contain duplicates', () => {
  assert.deepEqual(duplicates(tefasFunds.map(asset => asset.canonicalSymbol)), []);
  assert.deepEqual(duplicates(tefasFunds.map(asset => asset.internalAssetId)), []);
  assert.deepEqual(duplicates(tefasFunds.map(asset => asset.providerSymbols.yahoo).filter(Boolean)), []);
});

test('TEFAS fund code and code fund aliases resolve to the same fund', () => {
  for (const code of ['AFT', 'MAC', 'TCD', 'YAY', 'IPB']) {
    const byCode = matchAsset(code);
    const byAlias = matchAsset(`${code} fonu`);

    assert.equal(byCode.asset.canonicalSymbol, code);
    assert.equal(byCode.asset.internalAssetId, `tefas:fund:${code}`);
    assert.equal(byAlias.asset.canonicalSymbol, code);
    assert.equal(byAlias.asset.internalAssetId, byCode.asset.internalAssetId);
  }
});

test('TEFAS fund full names resolve to the correct catalog record', () => {
  for (const code of ['AFT', 'MAC', 'TCD', 'YAY', 'IPB']) {
    const asset = fundByCode(code);
    const result = matchAsset(asset.displayName);

    assert.equal(result.asset.canonicalSymbol, code);
    assert.equal(result.asset.internalAssetId, asset.internalAssetId);
  }
});

test('generic fund category words are not matched to a specific TEFAS fund', () => {
  for (const query of ['altın', 'teknoloji', 'serbest', 'fon', 'hisse', 'para piyasası', 'yabancı', 'değişken']) {
    const result = matchAsset(query);

    assert.notEqual(result.asset?.assetType, 'fund', `${query} should not resolve to a TEFAS fund`);
  }
});

test('existing BIST equity and index catalog counts are preserved', () => {
  assert.equal(bistEquities.length, EXPECTED_BIST_EQUITY_COUNT);
  assert.equal(bistIndices.length, EXPECTED_BIST_INDEX_COUNT);
});

test('TEFAS fund codes do not silently collide with non-fund asset canonical symbols', () => {
  const nonFundSymbols = new Set(
    ASSET_CATALOG
      .filter(asset => asset.assetType !== 'fund')
      .map(asset => asset.canonicalSymbol)
  );
  const collisions = tefasFunds
    .map(asset => asset.canonicalSymbol)
    .filter(symbol => nonFundSymbols.has(symbol));

  assert.deepEqual(collisions, []);
});
