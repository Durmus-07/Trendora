'use strict';

const dns = require('node:dns');
const http = require('node:http');
const https = require('node:https');
const axios = require('axios');
const cheerio = require('cheerio');

const FULL_TTL_MS = 14 * 24 * 60 * 60 * 1000;
const PARTIAL_TTL_MS = 24 * 60 * 60 * 1000;
const NEGATIVE_TTL_MS = 3 * 60 * 60 * 1000;
const MAX_CACHE_ITEMS = 500;
const MAX_HTML_BYTES = 2 * 1024 * 1024;
const REQUEST_TIMEOUT_MS = 10000;
const MAX_REDIRECTS = 3;
const MAX_CONCURRENT_FETCHES = 4;

const cache = new Map();
const inFlight = new Map();
const domainLastRequestAt = new Map();
let activeFetches = 0;
const fetchWaiters = [];

function normalizeUrl(value) {
  try {
    const url = new URL(String(value || '').trim());
    if (!['http:', 'https:'].includes(url.protocol)) return '';
    url.hash = '';
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_|fbclid|gclid)/i.test(key)) url.searchParams.delete(key);
    }
    return url.toString();
  } catch (_) {
    return '';
  }
}

function isPrivateIp(address) {
  const value = String(address || '').toLowerCase();
  if (!value) return true;
  if (value === '::' || value === '::1' || value === '0.0.0.0' ||
      /^fe[89ab][0-9a-f]:/.test(value) || value.startsWith('fc') ||
      value.startsWith('fd') || value.startsWith('ff')) return true;
  const mapped = value.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/)?.[1];
  const ipv4 = mapped || (/^\d+\.\d+\.\d+\.\d+$/.test(value) ? value : '');
  if (!ipv4) return false;
  const parts = ipv4.split('.').map(Number);
  return parts[0] === 10 || parts[0] === 127 || parts[0] === 0 ||
    (parts[0] === 169 && parts[1] === 254) ||
    (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
    (parts[0] === 192 && parts[1] === 168) ||
    (parts[0] === 192 && parts[1] === 0) ||
    (parts[0] === 192 && parts[1] === 0 && parts[2] === 2) ||
    (parts[0] === 100 && parts[1] >= 64 && parts[1] <= 127) ||
    (parts[0] === 198 && (parts[1] === 18 || parts[1] === 19)) ||
    (parts[0] === 198 && parts[1] === 51 && parts[2] === 100) ||
    (parts[0] === 203 && parts[1] === 0 && parts[2] === 113) ||
    parts[0] >= 224;
}

async function resolvePublicUrl(value) {
  const normalized = normalizeUrl(value);
  if (!normalized) throw new Error('Geçersiz kaynak URL.');
  const url = new URL(normalized);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('Kaynak protokolüne izin verilmiyor.');
  }
  const allowedPort = url.protocol === 'https:' ? '443' : '80';
  if (url.port && url.port !== allowedPort) {
    throw new Error('Kaynak portuna izin verilmiyor.');
  }
  const hostname = url.hostname.toLowerCase().replace(/\.$/, '');
  if (hostname === 'localhost' || hostname.endsWith('.localhost') ||
      hostname === '0.0.0.0') throw new Error('Özel ağ adresine izin verilmiyor.');

  const addresses = await dns.promises.lookup(hostname, { all: true, verbatim: true });
  if (!addresses.length || addresses.some(item => isPrivateIp(item.address))) {
    throw new Error('Özel ağ adresine izin verilmiyor.');
  }
  return { url, address: addresses[0].address, family: addresses[0].family };
}

function pinnedAgent(protocol, address, family) {
  const Agent = protocol === 'https:' ? https.Agent : http.Agent;
  return new Agent({
    keepAlive: false,
    lookup: (_hostname, _options, callback) => callback(null, address, family)
  });
}

async function waitForFetchSlot() {
  if (activeFetches < MAX_CONCURRENT_FETCHES) {
    activeFetches += 1;
    return;
  }
  await new Promise(resolve => fetchWaiters.push(resolve));
  activeFetches += 1;
}

function releaseFetchSlot() {
  activeFetches -= 1;
  fetchWaiters.shift()?.();
}

async function respectDomainDelay(hostname) {
  const now = Date.now();
  const scheduledAt = Math.max(now, Number(domainLastRequestAt.get(hostname) || 0));
  domainLastRequestAt.set(hostname, scheduledAt + 500);
  if (scheduledAt > now) {
    await new Promise(resolve => setTimeout(resolve, scheduledAt - now));
  }
}

async function streamToText(stream) {
  const chunks = [];
  let size = 0;
  try {
    for await (const chunk of stream) {
      size += chunk.length;
      if (size > MAX_HTML_BYTES) {
        throw new Error('Kaynak yanıtı çok büyük.');
      }
      chunks.push(chunk);
    }
  } catch (error) {
    stream.destroy();
    throw error;
  }
  return Buffer.concat(chunks).toString('utf8');
}

async function fetchHtml(initialUrl) {
  let currentUrl = initialUrl;
  await waitForFetchSlot();
  try {
    for (let redirect = 0; redirect <= MAX_REDIRECTS; redirect += 1) {
      const target = await resolvePublicUrl(currentUrl);
      await respectDomainDelay(target.url.hostname);
      const agent = pinnedAgent(target.url.protocol, target.address, target.family);
      const response = await axios.get(target.url.toString(), {
        timeout: REQUEST_TIMEOUT_MS,
        maxRedirects: 0,
        responseType: 'stream',
        validateStatus: () => true,
        httpAgent: target.url.protocol === 'http:' ? agent : undefined,
        httpsAgent: target.url.protocol === 'https:' ? agent : undefined,
        headers: {
          'User-Agent': 'Trendora/2.0 (+https://trendora-icj9.onrender.com)',
          Accept: 'text/html,application/xhtml+xml;q=0.9,text/plain;q=0.7'
        }
      });
      if (response.status >= 300) {
        response.data.destroy();
        if (response.status >= 400) {
          throw new Error(`Kaynak HTTP ${response.status} döndürdü.`);
        }
        const location = response.headers.location;
        if (!location || redirect === MAX_REDIRECTS) throw new Error('Yönlendirme sınırı aşıldı.');
        currentUrl = new URL(location, target.url).toString();
        continue;
      }
      const contentType = String(response.headers['content-type'] || '').toLowerCase();
      if (!contentType.includes('text/html') && !contentType.includes('application/xhtml+xml') &&
          !contentType.includes('text/plain')) {
        response.data.destroy();
        throw new Error('Kaynak HTML içeriği döndürmedi.');
      }
      return { html: await streamToText(response.data), resolvedUrl: target.url.toString() };
    }
    throw new Error('Kaynak çözümlenemedi.');
  } finally {
    releaseFetchSlot();
  }
}

const REMOVE_TAGS = 'script,style,noscript,iframe,form,button,input,canvas,svg,nav,header,footer,aside';
const BOILERPLATE = /(^|[-_\s])(ads?|advert(?:isement)?|reklam|banner|promo(?:tion)?|sponsored|social|share|related|recommendation|newsletter|subscribe|comment|cookie|consent|sidebar|navigation|footer|header)([-_\s]|$)/i;

function cleanDocument($) {
  $(REMOVE_TAGS).remove();
  $('[class], [id]').each((_, node) => {
    const marker = `${$(node).attr('class') || ''} ${$(node).attr('id') || ''}`;
    if (BOILERPLATE.test(marker)) $(node).remove();
  });
}

function normalizeParagraphs(values) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const text = String(value || '')
      .replace(/[\u200B-\u200D\uFEFF]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    if (text.length < 25) continue;
    const key = text.toLocaleLowerCase('tr-TR');
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result.join('\n\n').trim();
}

function textFromElement($, element) {
  const paragraphs = $(element).find('p').map((_, node) => $(node).text()).get();
  if (paragraphs.length) return normalizeParagraphs(paragraphs);
  return normalizeParagraphs([$(element).text()]);
}

function findJsonLdArticleBody($) {
  let fallback = '';
  for (const node of $('script[type="application/ld+json"]').toArray()) {
    try {
      const parsed = JSON.parse($(node).text());
      const queue = Array.isArray(parsed) ? [...parsed] : [parsed];
      while (queue.length) {
        const item = queue.shift();
        if (!item || typeof item !== 'object') continue;
        if (Array.isArray(item['@graph'])) queue.push(...item['@graph']);
        if (typeof item.articleBody !== 'string') continue;
        const body = normalizeParagraphs([item.articleBody]);
        const types = Array.isArray(item['@type']) ? item['@type'] : [item['@type']];
        if (types.some(type => type === 'Article' || type === 'NewsArticle')) return body;
        if (!fallback) fallback = body;
      }
    } catch (_) {}
  }
  return fallback;
}

function extractArticleContent(html) {
  const $ = cheerio.load(String(html || ''));
  const jsonLd = findJsonLdArticleBody($);
  cleanDocument($);

  const candidates = [
    ['schema', $('[itemprop="articleBody"]').first()],
    ['jsonld', jsonLd ? { length: 1, __text: jsonLd } : null],
    ['article', $('article').first()],
    ['main', $('main').first()],
    ['article', $('[class*="article-body"], [class*="article-content"], [class*="story-body"], [class*="news-content"]').first()]
  ];

  let best = { content: '', method: 'fallback' };
  for (const [method, element] of candidates) {
    if (!element?.length) continue;
    const content = element.__text || textFromElement($, element);
    if (contentStatus(content) !== 'summary') return { content, method };
    if (content.length > best.content.length) best = { content, method };
  }
  if (best.content.length < 180) {
    const dense = normalizeParagraphs($('p').map((_, node) => $(node).text()).get());
    if (dense.length > best.content.length) best = { content: dense, method: 'paragraphs' };
  }
  return best;
}

function contentStatus(content) {
  const words = String(content || '').split(/\s+/).filter(Boolean).length;
  if (content.length >= 500 && words >= 80) return 'full';
  if (content.length >= 180 && words >= 30) return 'partial';
  return 'summary';
}

function cacheKey(record) {
  return String(record.id || '').trim() || normalizeUrl(record.url);
}

function setCache(key, value, now) {
  if (cache.size >= MAX_CACHE_ITEMS && !cache.has(key)) cache.delete(cache.keys().next().value);
  cache.set(key, value);
  return { ...value, cached: false };
}

function createNewsContentService(options = {}) {
  const requestHtml = options.fetchHtml || fetchHtml;
  const now = options.now || (() => Date.now());

  async function resolve(record) {
    const key = cacheKey(record);
    if (!key) return unavailable(record, 'Haber kimliği bulunamadı.', now());
    const cached = cache.get(key);
    if (cached && cached.expiresAtMs > now()) return { ...cached, cached: true };
    if (inFlight.has(key)) return inFlight.get(key);

    const task = (async () => {
      const rssContent = normalizeParagraphs([record.content]);
      if (contentStatus(rssContent) === 'full') {
        return setCache(key, buildResult(record, rssContent, 'full', 'rss', record.url, now(), FULL_TTL_MS), now());
      }
      try {
        const safeUrl = normalizeUrl(record.url);
        if (!safeUrl) throw new Error('Kayıtlı kaynak URL geçersiz.');
        const fetched = await requestHtml(safeUrl);
        const extracted = extractArticleContent(fetched.html);
        const status = contentStatus(extracted.content);
        if (status === 'summary') throw new Error('Yeterli haber metni çıkarılamadı.');
        const ttl = status === 'full' ? FULL_TTL_MS : PARTIAL_TTL_MS;
        return setCache(key, buildResult(record, extracted.content, status, extracted.method,
          fetched.resolvedUrl || safeUrl, now(), ttl), now());
      } catch (error) {
        const result = unavailable(record, error.message, now());
        cache.set(key, result);
        return { ...result, cached: false };
      }
    })().finally(() => inFlight.delete(key));
    inFlight.set(key, task);
    return task;
  }

  return { resolve };
}

function buildResult(record, content, status, method, resolvedUrl, timestamp, ttl) {
  return {
    success: true,
    id: record.id || '',
    title: record.title || '',
    source: record.source || record.feedSource || '',
    url: record.url || '',
    originalUrl: record.url || '',
    resolvedUrl,
    content,
    contentStatus: status,
    contentSource: method,
    extractionMethod: method,
    fetchedAt: new Date(timestamp).toISOString(),
    updatedAt: record.updatedAt || null,
    expiresAt: new Date(timestamp + ttl).toISOString(),
    expiresAtMs: timestamp + ttl,
    errorState: null,
    retryAfter: null
  };
}

function unavailable(record, message, timestamp) {
  const summary = normalizeParagraphs([record.description || record.summary || record.content]);
  return {
    success: true,
    id: record.id || '',
    title: record.title || '',
    source: record.source || record.feedSource || '',
    url: record.url || '',
    originalUrl: record.url || '',
    resolvedUrl: null,
    content: summary,
    contentStatus: summary ? 'summary' : 'unavailable',
    contentSource: summary ? 'fallback' : 'unavailable',
    extractionMethod: summary ? 'fallback' : 'unavailable',
    fetchedAt: new Date(timestamp).toISOString(),
    updatedAt: record.updatedAt || null,
    expiresAt: new Date(timestamp + NEGATIVE_TTL_MS).toISOString(),
    expiresAtMs: timestamp + NEGATIVE_TTL_MS,
    errorState: message,
    retryAfter: new Date(timestamp + NEGATIVE_TTL_MS).toISOString()
  };
}

module.exports = {
  createNewsContentService,
  extractArticleContent,
  isPrivateIp,
  normalizeUrl,
  resolvePublicUrl,
  streamToText
};
