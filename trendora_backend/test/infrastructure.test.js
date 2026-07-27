'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { normalizeNews, normalizeOpportunity, normalizeFinancial } = require('../services/dataModels');
const { findDuplicates, dedupe } = require('../services/duplicateDetector');
const { resilientRequest } = require('../services/resilientRequest');

test('common models preserve legacy fields while adding metadata', () => {
  const news = normalizeNews({ title: 'A', feedSource: 'Feed' }, { updatedAt: '2026-01-01' });
  const opportunity = normalizeOpportunity({ title: 'B', seller: 'Store', oldPrice: 10 });
  const financial = normalizeFinancial({ symbol: 'X', dailyPrice: { current: 4, volume: 9 } });
  assert.equal(news.title, 'A');
  assert.equal(opportunity.oldPrice, 10);
  assert.equal(financial.price, 4);
  assert.equal(financial.volume, 9);
  assert.ok(news.sourceInfo);
});

test('duplicate detector finds repeated opportunities without mutating input', () => {
  const items = [{ title: 'Ürün A', store: 'X', price: 10 }, { title: 'Ürün A', store: 'X', price: 10 }];
  assert.equal(findDuplicates(items, 'opportunity').length, 1);
  assert.equal(dedupe(items, 'opportunity').length, 1);
  assert.equal(items.length, 2);
});

test('duplicate detector preserves distinct opportunity records with stable IDs', () => {
  const items = [
    { id: 'campaign-1', title: 'Ürün A', store: 'X', price: 10 },
    { id: 'campaign-2', title: 'Ürün A', store: 'X', price: 10 }
  ];

  assert.equal(dedupe(items, 'opportunity').length, 2);
  assert.equal(dedupe([items[0], { ...items[0] }], 'opportunity').length, 1);
});

test('resilient requests coalesce simultaneous calls', async () => {
  let calls = 0;
  const operation = async () => { calls += 1; return { ok: true }; };
  await Promise.all([
    resilientRequest('same', operation, { ttlMs: 1000 }),
    resilientRequest('same', operation, { ttlMs: 1000 })
  ]);
  assert.equal(calls, 1);
});
