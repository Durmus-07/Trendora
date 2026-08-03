'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createSmartSearchPlan } = require('../services/smartSearchService');

for (const [query, symbol] of [
  ['ASELSAN kaç TL?', 'ASELS'], ['THY analiz et', 'THYAO'],
  ['Şişecam görünümü', 'SISE'], ['Koç Holding kaç TL?', 'KCHOL'],
  ['Tüpraş fiyatı', 'TUPRS'], ['ALTIN.S1 kaç TL?', 'ALTIN.S1'],
  ['Gram altın ne kadar?', 'GRAM_ALTIN'], ['BIST 100 kaç TL?', 'XU100'],
  ['aselsn kaç tl', 'ASELS']
]) {
  test(`${query} merkezi katalogdan ${symbol} çözer`, () => {
    const plan = createSmartSearchPlan(query);
    assert.equal(plan.assetResolution, 'matched');
    assert.equal(plan.asset.canonicalSymbol, symbol);
    assert.ok(plan.asset.internalAssetId);
  });
}
test('saved query market intentine kaymaz', () => assert.equal(createSmartSearchPlan('Kaydettiğim ASELSAN').intent, 'saved_items'));
test('general question AI planına gider, anlamsız girdi gitmez', () => {
  assert.equal(createSmartSearchPlan('Bileşik faiz nedir?').service, 'ai');
  assert.equal(createSmartSearchPlan('asdf').service, null);
});
test('news and opportunity plans use only their own services', () => {
  const breaking = createSmartSearchPlan('Son dakika haberleri');
  const technology = createSmartSearchPlan('Teknoloji haberleri');
  const migros = createSmartSearchPlan('Migros fırsatları');
  const bim = createSmartSearchPlan('BİM fırsatları');
  assert.equal(breaking.service, 'news');
  assert.equal(breaking.filters.breaking, true);
  assert.equal(technology.filters.category, 'teknoloji');
  assert.equal(migros.service, 'opportunities');
  assert.equal(migros.filters.source, 'migros');
  assert.equal(bim.filters.source, 'bim');
});
test('unknown asset never fabricates a symbol', () => {
  const plan = createSmartSearchPlan('ZZZZ bilinmeyen şirket kaç TL?');
  assert.equal(plan.assetResolution, 'not_found');
  assert.equal(plan.asset, null);
});

test('ambiguous catalog query returns canonical selection cards', () => {
  const plan = createSmartSearchPlan('Değişken fon fiyatı');
  assert.equal(plan.intent, 'asset_selection');
  assert.equal(plan.assetResolution, 'selection_required');
  assert.ok(plan.candidates.length >= 2);
  assert.ok(plan.candidates.every(item => item.canonicalSymbol && item.internalAssetId));
  assert.equal(plan.requestedIntent, 'market_price');
});
