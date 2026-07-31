const assert = require('node:assert/strict');
const { test } = require('node:test');

const { ASSET_CATALOG } = require('../services/assets/assetCatalog');
const { matchAsset } = require('../services/assets/assetMatcher');
const { resolveProviderSymbol } = require('../services/assets/providerSymbolResolver');

const equities = ASSET_CATALOG.filter(asset => asset.assetType === 'equity');
const equitySymbols = equities.map(asset => asset.canonicalSymbol);

function duplicates(values) {
  const seen = new Set();
  const repeated = new Set();
  for (const value of values) {
    if (seen.has(value)) repeated.add(value);
    seen.add(value);
  }
  return [...repeated];
}

test('catalog contains the expanded BIST equity universe', () => {
  assert.equal(equities.length, 750);
  for (const symbol of ['A1CAP', 'ACSEL', 'ASELS', 'BIMAS', 'KCHOL', 'THYAO', 'TUPRS', 'ZOREN']) {
    assert.ok(
      equities.some(asset => asset.canonicalSymbol === symbol),
      `${symbol} should be present`
    );
  }
});

test('catalog covers multi-code KAP company rows explicitly', () => {
  const kapSourceRowCount = 745;
  const kapSourceCodeCount = 750;
  assert.equal(equities.length, kapSourceCodeCount);
  assert.equal(kapSourceCodeCount - kapSourceRowCount, 5);

  for (const symbol of ['KRDMA', 'KRDMB', 'KRDMD']) {
    const asset = equities.find(item => item.canonicalSymbol === symbol);
    assert.ok(asset, `${symbol} should be present`);
    assert.equal(asset.displayName, 'KARDEMİR KARABÜK DEMİR ÇELİK SANAYİ VE TİCARET A.Ş.');
  }

  for (const symbol of ['ISATR', 'ISBTR', 'ISCTR', 'ISKUR']) {
    const asset = equities.find(item => item.canonicalSymbol === symbol);
    assert.ok(asset, `${symbol} should be present`);
    assert.equal(asset.displayName, 'TÜRKİYE İŞ BANKASI A.Ş.');
  }
});

test('BIST equity identifiers and Yahoo symbols are unique', () => {
  assert.deepEqual(duplicates(equitySymbols), []);
  assert.deepEqual(duplicates(equities.map(asset => asset.internalAssetId)), []);
  assert.deepEqual(duplicates(equities.map(asset => asset.providerSymbols.yahoo)), []);

  for (const asset of equities) {
    assert.equal(asset.internalAssetId, `bist:equity:${asset.canonicalSymbol}`);
    assert.equal(asset.providerSymbols.yahoo, `${asset.canonicalSymbol}.IS`);
    assert.equal(asset.exchange, 'BIST');
    assert.equal(asset.market, 'BIST');
    assert.equal(asset.currency, 'TRY');
  }
});

test('catalog does not include obvious non-equity BIST index symbols as equities', () => {
  for (const symbol of ['XU100', 'XU030', 'XBANK', 'XUSIN', 'XUTEK', 'XUHIZ']) {
    assert.equal(equitySymbols.includes(symbol), false);
  }
});

test('BIST equity aliases do not contain duplicates', () => {
  for (const asset of equities) {
    assert.deepEqual(
      duplicates(asset.aliases),
      [],
      `${asset.canonicalSymbol} aliases should be unique`
    );
  }
});

test('newly added equities are matched through the existing matcher', () => {
  for (const symbol of ['ACSEL', 'BIMAS', 'TUPRS', 'KRDMB', 'KRDMD', 'ISBTR', 'ISCTR', 'ISKUR', 'ZOREN']) {
    const result = matchAsset(symbol);
    assert.equal(result.matched, true, symbol);
    assert.equal(result.asset.canonicalSymbol, symbol);
    assert.equal(result.asset.assetType, 'equity');
    assert.equal(resolveProviderSymbol(result.asset, 'yahoo'), `${symbol}.IS`);
  }
});

test('common company aliases resolve to the intended equities', () => {
  const samples = [
    ['Tupras', 'TUPRS'],
    ['Eregli', 'EREGL'],
    ['Erdemir', 'EREGL'],
    ['Sisecam', 'SISE'],
    ['Koc Holding', 'KCHOL'],
    ['Turk Hava Yollari', 'THYAO'],
    ['THY', 'THYAO'],
    ['Garanti', 'GARAN'],
    ['Is Bankasi', 'ISCTR'],
    ['BIM', 'BIMAS'],
    ['Aselsan', 'ASELS']
  ];

  for (const [query, symbol] of samples) {
    const result = matchAsset(query);
    assert.equal(result.matched, true, query);
    assert.equal(result.asset.canonicalSymbol, symbol, query);
  }
});

test('short generic words do not resolve to random equities', () => {
  for (const query of ['ak', 'as', 'is', 'gar', 'turk', 'holding', 'yatirim']) {
    assert.equal(matchAsset(query).matched, false, query);
  }
});
