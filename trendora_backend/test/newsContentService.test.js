'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const dns = require('node:dns');
const axios = require('axios');
const {
  createNewsContentService,
  extractArticleContent,
  isPrivateIp,
  normalizeUrl,
  pinnedAgent,
  resolvePublicUrl,
  streamToText
} = require('../services/newsContentService');
const { extractNewsItems, findNewsRecord, router } = require('../routes/newsApi');
const {
  createNewsTranslationService
} = require('../services/newsTranslationService');
const express = require('express');

const longText = Array.from(
  { length: 95 },
  (_, index) => `haber metninin güvenli ve anlamlı kelimesi ${index}`
).join(' ');

test('yalnizca Ingilizce haber cevrilir ve ayni icerik cache kullanir', async () => {
  let calls = 0;
  const service = createNewsTranslationService({
    translate: async fields => {
      calls += 1;
      return {
        title: `TR ${fields.title}`,
        summary: `TR ${fields.summary}`,
        content: `TR ${fields.content}`
      };
    }
  });
  const record = {
    id: 'translation-cache-test',
    language: 'en',
    title: 'English title',
    description: 'English summary',
    url: 'https://example.com/translation'
  };
  const first = await service.resolve(record, { content: 'English content' });
  const second = await service.resolve(record, { content: 'English content' });

  assert.equal(first.title, 'TR English title');
  assert.equal(first.cached, false);
  assert.equal(second.cached, true);
  assert.equal(calls, 1);
  await assert.rejects(
    service.resolve({ ...record, language: 'tr' }, { content: 'Metin' }),
    error => error.code === 'UNSUPPORTED_LANGUAGE'
  );
});

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

test('haber snapshot array ve tekil alias köklerinden çoğaltılmadan çıkarılır', () => {
  const item = { id: 'root-shape-news' };
  assert.deepEqual(extractNewsItems([item]), [item]);
  assert.deepEqual(extractNewsItems({ news: [item] }), [item]);
  assert.deepEqual(extractNewsItems({ items: [item], data: [item, item] }), [item]);
  assert.deepEqual(extractNewsItems({ data: [item] }), [item]);
});

test('uzun ve özel karakterli ID query encode/decode sonrasında birebir bulunur', async () => {
  const id = `${'Base64Benzeri'.repeat(30)}+/=%`;
  const app = express();
  app.get('/find', (req, res) => {
    const match = findNewsRecord([{ id, url: 'https://example.com/special' }], req.query);
    res.json({ found: Boolean(match), id: req.query.id });
  });
  const server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/find?id=${encodeURIComponent(id)}`
    );
    const body = await response.json();
    assert.equal(body.found, true);
    assert.equal(body.id, id);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
});

test('pinned DNS lookup Node all seçeneğinde doğrulanan adres listesini döndürür', async () => {
  const agent = pinnedAgent('https:', '93.184.216.34', 4);
  const lookup = agent.options.lookup;
  const result = await new Promise((resolve, reject) => {
    lookup('example.com', { all: true }, (error, addresses) =>
      error ? reject(error) : resolve(addresses));
  });
  assert.deepEqual(result, [{ address: '93.184.216.34', family: 4 }]);
  agent.destroy();
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
    const [
      listResponse,
      missingResponse,
      statusResponse,
      healthResponse,
      translationDisabledResponse
    ] =
      await Promise.all([
        fetch(`${base}?limit=1`),
        fetch(`${base}/content?id=definitely-unknown-news-id`),
        fetch(`${base}/status`),
        fetch(`${base}/health`),
        fetch(`${base}/translation?id=definitely-unknown-news-id`)
      ]);
    const list = await listResponse.json();
    const missing = await missingResponse.json();
    const status = await statusResponse.json();
    assert.equal(listResponse.status, 200);
    assert.ok(Array.isArray(list.news));
    assert.deepEqual(list.news, list.items);
    assert.deepEqual(list.news, list.data);
    assert.ok(list.news[0]?.id);
    assert.equal(missingResponse.status, 404);
    assert.equal(missing.contentStatus, 'unavailable');
    assert.equal(statusResponse.status, 200);
    assert.ok(['fresh', 'delayed', 'stale', 'running', 'error'].includes(
      status.freshnessStatus));
    assert.equal(healthResponse.status, 200);
    assert.equal(translationDisabledResponse.status, 503);

    const originalLookup = dns.promises.lookup;
    const originalGet = axios.get;
    dns.promises.lookup = async () => [{ address: '93.184.216.34', family: 4 }];
    axios.get = async () => ({
      status: 200,
      headers: { 'content-type': 'text/html; charset=utf-8' },
      data: Readable.from([`<article><p>${longText}</p></article>`])
    });
    try {
      const listedId = list.news[0].id;
      const contentResponse = await fetch(
        `${base}/content?id=${encodeURIComponent(listedId)}`
      );
      const content = await contentResponse.json();
      assert.equal(contentResponse.status, 200);
      assert.equal(content.success, true);
      assert.equal(content.id, listedId);
      assert.ok(['full', 'partial', 'summary'].includes(content.contentStatus));
      assert.equal(content.title, list.news[0].title);
      assert.equal(content.url, list.news[0].url);
      assert.ok(content.content);
    } finally {
      dns.promises.lookup = originalLookup;
      axios.get = originalGet;
    }
  } finally {
    await new Promise((resolve, reject) => server.close(error =>
      error ? reject(error) : resolve()));
  }
});
