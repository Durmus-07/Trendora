'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const axios = require('axios');
const {
  classifyNewsItems,
  fetchSource,
  mergeCollectorStatus,
  newsContentHash,
  refreshTierForSource,
  snapshotSignature,
  sourceBackoffMs,
  sourceIsEligible,
  sourceStateFor
} = require('../services/newsCollector');

function source(name, overrides = {}) {
  return {
    name,
    category: 'gundem',
    url: 'https://example.com/feed.xml',
    priority: 85,
    confidence: 90,
    region: 'tr',
    ...overrides
  };
}

function item(id, overrides = {}) {
  return {
    id,
    title: `Haber ${id}`,
    description: 'Kararlı haber açıklaması',
    content: '',
    url: `https://example.com/${id}`,
    imageUrl: '',
    source: 'Test',
    publishedAt: '2026-08-03T10:00:00.000Z',
    trendScore: 77,
    clusterId: `cluster-${id}`,
    ...overrides
  };
}

test('kaynaklar güvenli varsayılan güncellik sınıflarına ayrılır', () => {
  assert.equal(refreshTierForSource(source('breaking', { category: 'son_dakika' })), 'breaking');
  assert.equal(refreshTierForSource(source('fast', { priority: 93 })), 'fast');
  assert.equal(refreshTierForSource(source('normal')), 'normal');
  assert.equal(refreshTierForSource(source('slow', { category: 'teknoloji' })), 'slow');
});

test('yeni değişmiş ve değişmemiş haberler ayrılır', () => {
  const unchanged = item('same');
  const changedBefore = item('changed');
  const changedAfter = item('changed', { description: 'Güncellenmiş açıklama' });
  const result = classifyNewsItems(
    [item('new'), { ...unchanged }, changedAfter],
    [unchanged, changedBefore]
  );
  assert.equal(result.newCount, 1);
  assert.equal(result.changedCount, 1);
  assert.equal(result.unchangedCount, 1);
  assert.equal(result.items[1], unchanged);
  assert.equal(result.items[1].trendScore, 77);
  assert.equal(result.items[1].clusterId, 'cluster-same');
});

test('haber hash ve snapshot imzası kararlı, içerik değişiminde farklıdır', () => {
  const original = item('hash');
  assert.equal(newsContentHash(original), newsContentHash({ ...original }));
  assert.notEqual(
    newsContentHash(original),
    newsContentHash({ ...original, description: 'Değişti' })
  );
  assert.equal(snapshotSignature([original]), snapshotSignature([{ ...original }]));
});

test('başarısız kaynak backoff alır ve uygunluk zamanı uygulanır', () => {
  const testSource = source('backoff-source');
  const state = sourceStateFor(testSource);
  state.nextEligibleFetchAt = new Date(Date.now() + 60_000).toISOString();
  assert.equal(sourceIsEligible(testSource), false);
  state.nextEligibleFetchAt = new Date(Date.now() - 1).toISOString();
  assert.equal(sourceIsEligible(testSource), true);
  assert.equal(sourceBackoffMs(testSource, 3), 30 * 60 * 1000);
  assert.equal(sourceBackoffMs(testSource, 5), 2 * 60 * 60 * 1000);
});

test('304 kaynak RSS parse etmeden başarılı ve değişmemiş döner', async () => {
  const testSource = source('not-modified-source');
  const state = sourceStateFor(testSource);
  state.lastItemCount = 12;
  state.lastEtag = '"v1"';
  const originalGet = axios.get;
  axios.get = async (_url, options) => {
    assert.equal(options.headers['If-None-Match'], '"v1"');
    return { status: 304, headers: {}, data: '' };
  };
  try {
    const result = await fetchSource(testSource);
    assert.equal(result.ok, true);
    assert.equal(result.notModified, true);
    assert.equal(result.count, 12);
    assert.deepEqual(result.items, []);
  } finally {
    axios.get = originalGet;
  }
});

test('invalid eligibility date does not block a source permanently', () => {
  const testSource = source('invalid-eligibility-source');
  sourceStateFor(testSource).nextEligibleFetchAt = 'invalid-date';
  assert.equal(sourceIsEligible(testSource), true);
});

test('collector status merge preserves the previous successful run', () => {
  const previous = {
    lastSuccessfulRunAt: '2026-08-03T10:00:00.000Z',
    totalSources: 111
  };
  const merged = mergeCollectorStatus(previous, {
    running: false,
    phase: 'failed',
    error: 'test error'
  });
  assert.equal(merged.lastSuccessfulRunAt, previous.lastSuccessfulRunAt);
  assert.equal(merged.totalSources, 111);
  assert.equal(merged.phase, 'failed');
});

test('başarılı kaynak backoff durumunu temizler', async () => {
  const testSource = source('recovered-source');
  const state = sourceStateFor(testSource);
  state.consecutiveFailures = 5;
  const originalGet = axios.get;
  axios.get = async () => ({
    status: 200,
    headers: { etag: '"v2"' },
    data: `<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title>
      <item><title>Yeni haber</title><link>https://example.com/new</link>
      <pubDate>Sun, 03 Aug 2026 10:00:00 GMT</pubDate><description>Yeni açıklama</description></item>
      </channel></rss>`
  });
  try {
    const result = await fetchSource(testSource);
    assert.equal(result.ok, true);
    assert.equal(result.count, 1);
    assert.equal(state.consecutiveFailures, 0);
    assert.equal(state.lastErrorType, null);
  } finally {
    axios.get = originalGet;
  }
});
