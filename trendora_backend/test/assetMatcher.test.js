const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  matchAsset,
  normalizeAssetQuery,
  findAssetCandidates
} = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

function assertSymbol(query, expectedSymbol, expectedType) {
  const result = matchAsset(query);
  assert.equal(result.matched, true, query);
  assert.equal(result.asset.canonicalSymbol, expectedSymbol, query);
  if (expectedType) assert.equal(result.asset.assetType, expectedType, query);
}

test('normalizes Turkish characters, provider suffixes and compact pairs', () => {
  assert.equal(normalizeAssetQuery(' Koç Holding ').normalized, 'koc holding');
  assert.equal(normalizeAssetQuery('ASELS.IS').providerSuffixRemoved, 'ASELS');
  assert.equal(normalizeAssetQuery('USD/TRY').compact, 'usdtry');
});

test('matches core BIST equities', () => {
  for (const query of ['ASELS', 'asels', 'ASELS.IS', 'Aselsan', 'Aselsan Elektronik', 'Aselsan hissesi']) {
    assertSymbol(query, 'ASELS', 'equity');
  }
  for (const query of ['THY', 'Türk Hava Yolları', 'THYAO']) {
    assertSymbol(query, 'THYAO', 'equity');
  }
  for (const query of ['Koc Holding', 'Koç Holding', 'KCHOL']) {
    assertSymbol(query, 'KCHOL', 'equity');
  }
});

test('matches BIST indices separately from equities', () => {
  for (const query of ['BIST100', 'BIST 100', 'XU100', 'XU100.IS']) {
    assertSymbol(query, 'XU100', 'index');
  }
  assertSymbol('XU030', 'XU030', 'index');
  assertSymbol('XBANK', 'XBANK', 'index');
});

test('matches fx, gold commodity and gold certificate distinctly', () => {
  assertSymbol('USD/TRY', 'USDTRY', 'fx');
  assertSymbol('USDTRY', 'USDTRY', 'fx');
  assertSymbol('altın', 'GRAM_ALTIN', 'commodity');
  assertSymbol('ALTIN.S1', 'ALTIN.S1', 'certificate');
});

test('does not promote unknown or low-confidence symbols', () => {
  assert.equal(matchAsset('ZZZZZ').matched, false);
  assert.equal(matchAsset('Aselsannn').matched, false);
});

test('returns candidates without changing the selected API result shape', () => {
  const candidates = findAssetCandidates('BIST 100');
  assert.ok(candidates.some(item => item.asset.canonicalSymbol === 'XU100'));
  assert.equal(matchAsset('BIST 100').asset.assetType, 'index');
  assert.equal(matchAsset('ASELS').asset.assetType, 'equity');
});

test('resolves Yahoo provider symbols only from catalog data', () => {
  assert.equal(resolveProviderSymbol('bist:equity:ASELS', 'yahoo'), 'ASELS.IS');
  assert.equal(resolveProviderSymbol(matchAsset('XU100').asset, 'yahoo'), 'XU100.IS');
  assert.equal(resolveProviderSymbol(matchAsset('USD/TRY').asset, 'yahoo'), 'TRY=X');
  assert.equal(resolveProviderSymbol(matchAsset('altın').asset, 'yahoo'), null);
  assert.equal(resolveProviderSymbol('unknown', 'yahoo'), null);
});
