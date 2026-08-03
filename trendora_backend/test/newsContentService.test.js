'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const {
  createNewsContentService,
  extractArticleContent,
  isPrivateIp,
  normalizeUrl,
  resolvePublicUrl,
  streamToText
} = require('../services/newsContentService');
const { findNewsRecord, router } = require('../routes/newsApi');
const express = require('express');

const longText = Array.from(
  { length: 95 },
  (_, index) => `haber metninin güvenli ve anlamlı kelimesi ${index}`
).join(' ');

test('yeterli RSS metni ağ çağrısı yapmadan kullanılır', async () => {
  let calls = 0;
  const service = createNewsContentService({
    fetchHtml: async () => {
      calls += 1;
      throw new Error('çağrılmamalı');
    }
  });
  const result = await service.resolve({
    id: 'rss-content-test',
    url: 'https://example.com/rss',
    content: longText
  });
  assert.equal(result.contentStatus, 'full');
  assert.equal(result.contentSource, 'rss');
  assert.equal(calls, 0);
});

test('eşzamanlı istekler tek fetch üzerinde birleşir ve sonuç cache edilir', async () => {
  let calls = 0;
  const service = createNewsContentService({
    fetchHtml: async url => {
      calls += 1;
      await new Promise(resolve => setTimeout(resolve, 10));
      return { html: `<article><p>${longText}</p></article>`, resolvedUrl: url };
    }
  });
  const record = { id: 'coalesce-content-test', url: 'https://example.com/a' };
  const [first, second] = await Promise.all([
    service.resolve(record),
    service.resolve(record)
  ]);
  const third = await service.resolve(record);
  assert.equal(first.contentStatus, 'full');
  assert.equal(second.content, first.content);
  assert.equal(third.cached, true);
  assert.equal(calls, 1);
});

test('article metni çıkarılır, script ve reklam alanları atılır', () => {
  const result = extractArticleContent(`
    <html><body><nav>menü</nav><article>
      <script>gizliTehlike()</script><div class="advertisement">reklam metni</div>
      <p>${longText}</p>
    </article></body></html>
  `);
  assert.match(result.content, /haber metninin/);
  assert.doesNotMatch(result.content, /gizliTehlike|reklam metni/);
});

test('schema ve JSON-LD articleBody alanları çıkarılır', () => {
  const schema = extractArticleContent(
    `<div itemprop="articleBody"><p>${longText}</p></div>`
  );
  const jsonLd = extractArticleContent(
    `<script type="application/ld+json">${JSON.stringify({
      '@type': 'NewsArticle',
      articleBody: longText
    })}</script>`
  );
  assert.equal(schema.method, 'schema');
  assert.equal(jsonLd.method, 'jsonld');
});

test('JSON-LD içinde Article türü genel articleBody alanına tercih edilir', () => {
  const preferred = `${longText} tercih-edilen-metin`;
  const result = extractArticleContent(`
    <script type="application/ld+json">${JSON.stringify({ articleBody: longText })}</script>
    <script type="application/ld+json">${JSON.stringify({
      '@type': 'NewsArticle',
      articleBody: preferred
    })}</script>
  `);
  assert.equal(result.method, 'jsonld');
  assert.match(result.content, /tercih-edilen-metin/);
});

test('main etiketi article olmadığında güvenli fallback olur', () => {
  const result = extractArticleContent(`<main><p>${longText}</p></main>`);
  assert.equal(result.method, 'main');
});

test('çok kısa çıkarım tam metin sayılmaz', async () => {
  const service = createNewsContentService({
    fetchHtml: async url => ({
      html: '<article><p>Bu metin tam haber sayılmak için çok kısa kalır.</p></article>',
      resolvedUrl: url
    })
  });
  const result = await service.resolve({
    id: 'short-content-test',
    url: 'https://example.com/short',
    summary: 'Kısa sonuç yerine mevcut ve güvenilir haber özeti gösterilmeye devam eder.'
  });
  assert.equal(result.contentStatus, 'summary');
  assert.match(result.content, /güvenilir haber özeti/);
});

test('başarısız çıkarım özeti korur ve negatif cache kullanır', async () => {
  let calls = 0;
  const service = createNewsContentService({
    fetchHtml: async () => {
      calls += 1;
      throw new Error('timeout');
    }
  });
  const record = {
    id: 'negative-content-test',
    url: 'https://example.com/fail',
    summary: 'Bu kayıt için elde bulunan güvenli haber özeti kullanıcıya gösterilir.'
  };
  const first = await service.resolve(record);
  const second = await service.resolve(record);
  assert.equal(first.contentStatus, 'summary');
  assert.match(first.content, /güvenli haber özeti/);
  assert.equal(second.cached, true);
  assert.equal(calls, 1);
});

test('özel ağ adresleri ve güvensiz protokoller reddedilir', async () => {
  for (const address of ['127.0.0.1', '10.1.2.3', '169.254.1.1', '::1',
    'fc00::1', '::ffff:127.0.0.1']) {
    assert.equal(isPrivateIp(address), true, address);
  }
  assert.equal(normalizeUrl('file:///etc/passwd'), '');
  await assert.rejects(resolvePublicUrl('http://127.0.0.1/private'));
  await assert.rejects(resolvePublicUrl('http://[::ffff:127.0.0.1]/private'));
  await assert.rejects(resolvePublicUrl('https://example.com:8443/news'));
});

test('maksimum response boyutu aşılınca stream kapatılır', async () => {
  const stream = Readable.from([Buffer.alloc(2 * 1024 * 1024 + 1)]);
  await assert.rejects(streamToText(stream), /çok büyük/);
  assert.equal(stream.destroyed, true);
});

test('negatif cache süresi geçince loadingPromise temizlenmiş olarak yeniden dener', async () => {
  let calls = 0;
  let timestamp = Date.UTC(2026, 0, 1);
  const service = createNewsContentService({
    now: () => timestamp,
    fetchHtml: async url => {
      calls += 1;
      if (calls === 1) throw new Error('geçici hata');
      return { html: `<article><p>${longText}</p></article>`, resolvedUrl: url };
    }
  });
  const record = { id: 'retry-after-negative-test', url: 'https://example.com/retry' };
  const first = await service.resolve(record);
  timestamp += 3 * 60 * 60 * 1000 + 1;
  const second = await service.resolve(record);
  assert.equal(first.contentStatus, 'unavailable');
  assert.equal(second.contentStatus, 'full');
  assert.equal(calls, 2);
});

test('haber yalnızca kayıtlı id veya normalize URL ile bulunur', () => {
  const items = [{ id: 'known', url: 'https://example.com/news?utm_source=rss' }];
  assert.equal(findNewsRecord(items, { id: 'known' }), items[0]);
  assert.equal(findNewsRecord(items, { url: 'https://example.com/news' }), items[0]);
  assert.equal(findNewsRecord(items, { id: 'unknown', url: 'https://evil.test' }), null);
});

test('haber route alias, bilinmeyen içerik, status ve health cevapları uyumludur', async () => {
  const app = express();
  app.use('/api/news', router);
  const server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  try {
    const address = server.address();
    const base = `http://127.0.0.1:${address.port}/api/news`;
    const [listResponse, missingResponse, statusResponse, healthResponse] =
      await Promise.all([
        fetch(`${base}?limit=1`),
        fetch(`${base}/content?id=definitely-unknown-news-id`),
        fetch(`${base}/status`),
        fetch(`${base}/health`)
      ]);
    const list = await listResponse.json();
    const missing = await missingResponse.json();
    assert.equal(listResponse.status, 200);
    assert.ok(Array.isArray(list.news));
    assert.deepEqual(list.news, list.items);
    assert.deepEqual(list.news, list.data);
    assert.equal(missingResponse.status, 404);
    assert.equal(missing.contentStatus, 'unavailable');
    assert.equal(statusResponse.status, 200);
    assert.equal(healthResponse.status, 200);
  } finally {
    await new Promise((resolve, reject) => server.close(error =>
      error ? reject(error) : resolve()));
  }
});
