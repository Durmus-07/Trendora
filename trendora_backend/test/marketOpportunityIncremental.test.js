'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const axios = require('axios');
const {
  classifySourceBatch,
  opportunityHash,
  snapshotSignature
} = require('../services/opportunityIncremental');
const {
  SOURCE_DEFINITIONS,
  backoffMs,
  sourceIsDue
} = require('../services/marketCollectorScheduler');
const { marketUrunleriniGetir } = require('../services/marketCollectorCore');
const { bimBatchGetir } = require('../services/bimCollector');
const opportunitiesRoute = require('../routes/opportunities');

function product(id, overrides = {}) {
  return {
    id,
    source: 'migros',
    store: 'migros',
    title: `Ürün ${id}`,
    currentPrice: 100,
    oldPrice: 120,
    discountRate: 17,
    currency: 'TRY',
    officialUrl: `https://example.com/${id}`,
    imageUrl: `https://example.com/${id}.jpg`,
    verifiedAt: '2026-08-03T10:00:00.000Z',
    active: true,
    ...overrides
  };
}

test('yalnızca BİM ve Migros normal scheduler kaynağıdır', () => {
  const statuses = Object.fromEntries(SOURCE_DEFINITIONS.map(item => [item.source, item.status]));
  assert.equal(statuses.bim, 'active');
  assert.equal(statuses.migros, 'active');
  assert.equal(statuses.carrefoursa, 'health_check_only');
  assert.equal(statuses.a101, 'health_check_only');
});

test('ilk tur active kaynağı çalıştırır ve sağlık kontrolü vaktini bekler', () => {
  const bim = SOURCE_DEFINITIONS.find(item => item.source === 'bim');
  const carrefour = SOURCE_DEFINITIONS.find(item => item.source === 'carrefoursa');
  const future = new Date(Date.now() + 60_000).toISOString();
  assert.equal(sourceIsDue(bim, { nextEligibleFetchAt: future }, { initialRun: true }), true);
  assert.equal(sourceIsDue(carrefour, { nextHealthCheckAt: future }, { initialRun: true }), false);
  assert.equal(sourceIsDue(carrefour, { nextHealthCheckAt: 'invalid-date' }), true);
});

test('304 cevap parse edilmeden önceki kaynak durumunu korur', async () => {
  const originalGet = axios.get;
  axios.get = async (_url, options) => {
    assert.equal(options.headers['If-None-Match'], '"v1"');
    return { status: 304, data: '', headers: {} };
  };
  try {
    const result = await marketUrunleriniGetir({
      source: 'migros', seller: 'Migros', url: 'https://example.com', maxItems: 10
    }, { etag: '"v1"', itemCount: 5 });
    assert.equal(result.changed, false);
    assert.equal(result.reason, 'not-modified');
    assert.deepEqual(result.items, []);
  } finally {
    axios.get = originalGet;
  }
});

test('BİM 304 cevabında ürün parse etmez', async () => {
  const originalGet = axios.get;
  axios.get = async (_url, options) => {
    assert.equal(options.headers['If-None-Match'], '"bim-v1"');
    return { status: 304, data: '', headers: {} };
  };
  try {
    const result = await bimBatchGetir({ etag: '"bim-v1"', itemCount: 8 });
    assert.equal(result.changed, false);
    assert.equal(result.reason, 'not-modified');
    assert.deepEqual(result.items, []);
  } finally {
    axios.get = originalGet;
  }
});

test('ürünler new changed unchanged olarak ayrılır ve önceki nesne yeniden kullanılır', () => {
  const same = product('same');
  const changed = product('changed');
  const result = classifySourceBatch(
    [same, changed],
    [{ ...same, verifiedAt: '2026-08-04T10:00:00.000Z' }, product('changed', { currentPrice: 90 }), product('new')]
  );
  assert.equal(result.newProducts, 1);
  assert.equal(result.changedProducts, 1);
  assert.equal(result.unchangedProducts, 1);
  assert.equal(result.items[0], same);
  assert.equal(result.items[1].id, changed.id);
  assert.equal(result.items[1].previousPrice, 100);
  assert.equal(result.items[1].statusChangedAt, undefined);
});

test('ürün ve snapshot hash geçici doğrulama zamanından etkilenmez', () => {
  const first = product('hash');
  const second = { ...first, verifiedAt: '2026-08-04T10:00:00.000Z' };
  assert.equal(opportunityHash(first), opportunityHash(second));
  assert.equal(snapshotSignature([first]), snapshotSignature([second]));
  assert.notEqual(opportunityHash(first), opportunityHash({ ...first, currentPrice: 99 }));
});

test('backoff 3 ve 5 hatada beklenen süreyi uygular', () => {
  assert.equal(backoffMs(2), 0);
  assert.equal(backoffMs(3), 30 * 60 * 1000);
  assert.equal(backoffMs(5), 2 * 60 * 60 * 1000);
});

test('süresi dolan ve tarihsiz eski fırsat aktif değildir', () => {
  assert.equal(opportunitiesRoute.isActive(product('expired', {
    catalogEndDate: '2020-01-01'
  })), false);
  assert.equal(opportunitiesRoute.isActive(product('stale', {
    catalogEndDate: null,
    verifiedAt: '2020-01-01T00:00:00.000Z'
  })), false);
  assert.equal(opportunitiesRoute.isActive(product('fresh', {
    catalogEndDate: null,
    verifiedAt: new Date().toISOString()
  })), true);
});
