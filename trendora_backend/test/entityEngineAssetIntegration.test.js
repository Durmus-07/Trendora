const assert = require('node:assert/strict');
const { test } = require('node:test');

const { resolveEntity } = require('../services/trend/entityEngine');

function assertResolved(query, expectedSymbol) {
  const entity = resolveEntity(query);
  assert.equal(entity.found, true, query);
  assert.equal(entity.symbol, expectedSymbol, query);
  assert.equal(entity.canonicalSymbol, expectedSymbol, query);
  assert.ok(entity.name, query);
  assert.ok(entity.subtype, query);
  assert.ok(entity.internalAssetId, query);
  assert.ok(entity.providerSymbols && typeof entity.providerSymbols === 'object', query);
  return entity;
}

test('ASELS keeps legacy fields and gains central catalog fields', () => {
  const entity = assertResolved('ASELS', 'ASELS');
  assert.equal(entity.name, 'ASELSAN ELEKTRONİK SANAYİ VE TİCARET A.Ş.');
  assert.equal(entity.subtype, 'bist_stock');
  assert.equal(entity.market, 'BIST');
  assert.equal(entity.internalAssetId, 'bist:equity:ASELS');
  assert.equal(entity.assetType, 'equity');
  assert.equal(entity.exchange, 'BIST');
  assert.equal(entity.currency, 'TRY');
  assert.equal(entity.providerSymbols.yahoo, 'ASELS.IS');
});

test('central catalog resolves provider suffixes and aliases', () => {
  assertResolved('ASELS.IS', 'ASELS');
  assertResolved('Aselsan', 'ASELS');
  assertResolved('THY', 'THYAO');
  assertResolved('Türk Hava Yolları', 'THYAO');
  assertResolved('Koc Holding', 'KCHOL');
});

test('central catalog resolves BIST index identity without losing legacy shape', () => {
  const bist100 = assertResolved('BIST 100', 'XU100');
  assert.equal(bist100.assetType, 'index');
  assert.equal(bist100.subtype, 'index');

  const xu100 = assertResolved('XU100', 'XU100');
  assert.equal(xu100.assetType, 'index');
  assert.equal(xu100.subtype, 'index');
});

test('central catalog resolves USD/TRY with added fields', () => {
  const entity = assertResolved('USD/TRY', 'USDTRY');
  assert.equal(entity.assetType, 'fx');
  assert.equal(entity.subtype, 'fx');
  assert.equal(entity.market, 'FX');
  assert.equal(entity.providerSymbols.yahoo, 'TRY=X');
});

test('existing gold behavior keeps old semantic fields while adding catalog fields', () => {
  const entity = resolveEntity('altın');
  assert.equal(entity.found, true);
  assert.equal(entity.symbol, 'GRAM_ALTIN');
  assert.equal(entity.subtype, 'commodity');
  assert.equal(entity.assetType, 'commodity');
  assert.equal(entity.internalAssetId, 'commodity:gold:GRAM_ALTIN');
});

test('legacy fallback still resolves assets outside the new catalog', () => {
  const entity = resolveEntity('BTC');
  assert.equal(entity.found, true);
  assert.equal(entity.symbol, 'BTC');
  assert.equal(entity.name, 'Bitcoin');
  assert.equal(entity.subtype, 'crypto');
  assert.equal(entity.internalAssetId, undefined);
});

test('unknown query keeps old unresolved behavior', () => {
  const entity = resolveEntity('bilinmeyen sembol');
  assert.equal(entity.found, false);
  assert.equal(entity.domain, null);
  assert.equal(entity.symbol, null);
  assert.equal(entity.name, null);
  assert.equal(entity.confidence, 0);
});
