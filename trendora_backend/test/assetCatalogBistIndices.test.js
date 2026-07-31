const assert = require('node:assert/strict');
const { test } = require('node:test');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

const expectedIndexSymbols = [
  'XU100', 'XU030', 'XU050', 'XUTUM', 'XTUMY', 'XBANK', 'XUSIN',
  'XUHIZ', 'XUMAL', 'XUTEK', 'XGIDA', 'XILTM', 'XTRZM', 'XULAS',
  'XELEK', 'XKMYA', 'XMANA', 'XMESY', 'XINSA', 'XGMYO', 'XHOLD',
  'XSGRT', 'XFINK', 'XSPOR', 'XTEKS', 'XKAGT', 'XTAST', 'XMADN'
];

const verifiedYahooSymbols = new Map([
  ['XU100', 'XU100.IS'],
  ['XU030', 'XU030.IS'],
  ['XBANK', 'XBANK.IS'],
  ['XUSIN', 'XUSIN.IS'],
  ['XUHIZ', 'XUHIZ.IS'],
  ['XUTEK', 'XUTEK.IS']
]);

const equities = ASSET_CATALOG.filter(asset => asset.assetType === 'equity');
const indices = ASSET_CATALOG.filter(asset => asset.assetType === 'index');

function duplicates(values) {
  const seen = new Set();
  const repeated = new Set();
  for (const value of values) {
    if (seen.has(value)) repeated.add(value);
    seen.add(value);
  }
  return [...repeated];
}

test('catalog contains the expected BIST indices', () => {
  assert.equal(equities.length, 750);
  for (const symbol of expectedIndexSymbols) {
    const asset = indices.find(item => item.canonicalSymbol === symbol);
    assert.ok(asset, `${symbol} should be present`);
    assert.equal(asset.assetType, 'index');
    assert.equal(asset.exchange, 'BIST');
    assert.equal(asset.market, 'BIST');
    assert.equal(asset.currency, 'TRY');
    assert.equal(asset.internalAssetId, `bist:index:${symbol}`);
  }
});

test('BIST index identifiers are unique and not classified as equities', () => {
  assert.deepEqual(duplicates(indices.map(asset => asset.canonicalSymbol)), []);
  assert.deepEqual(duplicates(indices.map(asset => asset.internalAssetId)), []);
  for (const symbol of expectedIndexSymbols) {
    assert.equal(equities.some(asset => asset.canonicalSymbol === symbol), false);
  }
});

test('BIST index provider symbols are only set for verified existing mappings', () => {
  for (const symbol of expectedIndexSymbols) {
    const asset = indices.find(item => item.canonicalSymbol === symbol);
    assert.equal(
      resolveProviderSymbol(asset, 'yahoo'),
      verifiedYahooSymbols.get(symbol) || null,
      symbol
    );
  }
});

test('core BIST index aliases resolve to the intended index', () => {
  const samples = [
    ['bist 100', 'XU100'],
    ['bist100', 'XU100'],
    ['borsa istanbul 100', 'XU100'],
    ['xu100', 'XU100'],
    ['bist 30', 'XU030'],
    ['bist30', 'XU030'],
    ['xu030', 'XU030'],
    ['bist banka', 'XBANK'],
    ['banka endeksi', 'XBANK'],
    ['bankacilik endeksi', 'XBANK'],
    ['xbank', 'XBANK'],
    ['bist sinai', 'XUSIN'],
    ['sinai endeksi', 'XUSIN'],
    ['sanayi endeksi', 'XUSIN'],
    ['xusin', 'XUSIN'],
    ['bist teknoloji', 'XUTEK'],
    ['teknoloji endeksi', 'XUTEK'],
    ['xutek', 'XUTEK']
  ];

  for (const [query, symbol] of samples) {
    const result = matchAsset(query);
    assert.equal(result.matched, true, query);
    assert.equal(result.asset.canonicalSymbol, symbol, query);
    assert.equal(result.asset.assetType, 'index', query);
  }
});

test('generic single words do not resolve to index assets', () => {
  for (const query of ['banka', 'teknoloji', 'spor', 'hizmet', 'mali']) {
    assert.equal(matchAsset(query).matched, false, query);
  }
});
