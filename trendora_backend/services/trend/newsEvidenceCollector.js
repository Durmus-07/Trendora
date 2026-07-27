const axios = require('axios');
const Parser = require('rss-parser');
const fs = require('fs');
const path = require('path');

const NEWS_DATABASE_FILE = path.join(
  __dirname,
  '..',
  '..',
  'database',
  'news_database.json'
);
const EVIDENCE_CACHE_TTL_MS = Math.max(
  60 * 1000,
  Number(process.env.TRENDORA_EVIDENCE_CACHE_TTL_MS || 10 * 60 * 1000)
);
const LOCAL_NEWS_LIMIT = Math.max(
  500,
  Number(process.env.TRENDORA_LOCAL_NEWS_LIMIT || 3000)
);
const evidenceCache = new Map();
const evidenceRequests = new Map();
let localNewsCache = { mtimeMs: 0, loadedAt: 0, items: [] };

const parser = new Parser({
  timeout: 20000,
  headers: { 'User-Agent': 'Trendora/4.3' }
});

function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildGoogleNewsUrl(query, days = 30) {
  const encodedQuery = encodeURIComponent(`${query} when:${days}d`);
  return `https://news.google.com/rss/search?q=${encodedQuery}&hl=tr&gl=TR&ceid=TR:tr`;
}

function splitGoogleTitle(value) {
  const parts = String(value || '').split(' - ');
  if (parts.length < 2) return { title: String(value || ''), publisher: 'Google Haberler' };
  const publisher = parts.pop().trim();
  return { title: parts.join(' - ').trim(), publisher };
}

function canonicalTitle(value) {
  return normalizeText(value)
    .replace(/[^\p{L}\p{N}\s]/gu, '')
    .replace(/\b(aş|as|anonim şirketi|şirketi)\b/g, '')
    .replace(/\s+/g, ' ')
    .slice(0, 180);
}

function uniqueItems(items) {
  const seen = new Set();
  return items.filter(item => {
    const key = canonicalTitle(item.title);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function queryTokens(value) {
  return normalizeText(value)
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter(token => token.length >= 3);
}

function loadLocalNews() {
  try {
    const stat = fs.statSync(NEWS_DATABASE_FILE);
    const fresh = localNewsCache.items.length > 0 &&
      localNewsCache.mtimeMs === stat.mtimeMs;
    if (fresh) return localNewsCache.items;

    const database = JSON.parse(fs.readFileSync(NEWS_DATABASE_FILE, 'utf8'));
    const items = Array.isArray(database?.items)
      ? database.items.slice(0, LOCAL_NEWS_LIMIT)
      : [];
    localNewsCache = {
      mtimeMs: stat.mtimeMs,
      loadedAt: Date.now(),
      items
    };
    return items;
  } catch (error) {
    console.error('Yerel haber kanıt havuzu okunamadı:', error.message);
    return localNewsCache.items;
  }
}

function searchLocalEvidence(query) {
  const tokens = queryTokens(query);
  if (!tokens.length) return [];
  const publisherCounts = new Map();

  return loadLocalNews()
    .map(item => {
      const title = normalizeText(item?.title);
      const description = normalizeText(item?.description);
      const matches = tokens.reduce(
        (score, token) => score +
          (title.includes(token) ? 5 : 0) +
          (description.includes(token) ? 2 : 0),
        0
      );
      const publishedAt = new Date(item?.publishedAt || 0).getTime();
      const ageDays = Number.isFinite(publishedAt)
        ? Math.max(0, (Date.now() - publishedAt) / 86400000)
        : 365;
      const recency = Math.max(0, 5 - ageDays / 7);
      return { item, score: matches + recency };
    })
    .filter(entry => entry.score >= 5)
    .sort((a, b) => b.score - a.score)
    .map(entry => entry.item)
    .filter(item => {
      const publisher = String(item?.source || item?.feedSource || 'Bilinmeyen');
      const count = publisherCounts.get(publisher) || 0;
      if (count >= 3) return false;
      publisherCounts.set(publisher, count + 1);
      return true;
    })
    .slice(0, 24)
    .map(item => ({
      title: item.title || 'Başlıksız içerik',
      url: item.url || '',
      source: item.source || item.feedSource || 'Trendora Haber Havuzu',
      publisher: item.source || item.feedSource || 'Trendora Haber Havuzu',
      publishedAt: item.publishedAt || null,
      evidenceType: 'news',
      credibility: Number(item.confidenceScore || 60)
    }));
}

function buildEvidenceQueries(query) {
  const cleaned = String(query || '').trim();
  const looksFinancial = /\b[A-Z]{4,6}\b|bist|hisse|altın|gümüş|dolar|euro|bitcoin|fon/i.test(cleaned);
  const queries = [cleaned];

  if (looksFinancial) {
    queries.push(`${cleaned} KAP OR "Kamuyu Aydınlatma Platformu"`);
    queries.push(`${cleaned} Borsa İstanbul OR bilanço OR sözleşme OR temettü`);
  }

  return [...new Set(queries.filter(Boolean))].slice(0, 3);
}

async function fetchFeed(query, days) {
  const response = await axios.get(buildGoogleNewsUrl(query, days), {
    timeout: 20000,
    headers: { 'User-Agent': 'Trendora/4.3' },
    responseType: 'text'
  });

  const feed = await parser.parseString(response.data);
  return (feed.items || []).map(item => {
    const parsedTitle = splitGoogleTitle(item.title);
    return {
      title: parsedTitle.title || 'Başlıksız içerik',
      url: item.link || '',
      source: item.creator || item['dc:creator'] || parsedTitle.publisher || 'Google Haberler',
      publisher: parsedTitle.publisher || item.creator || 'Google Haberler',
      publishedAt: item.isoDate || item.pubDate || null,
      evidenceType: /kap|kamuyu aydınlatma/i.test(parsedTitle.title) ? 'official-disclosure-news' : 'news'
    };
  });
}

async function collectNewsEvidence(query, days = 30) {
  const cacheKey = `${normalizeText(query)}:${days}`;
  const cached = evidenceCache.get(cacheKey);
  if (cached && Date.now() - cached.createdAt < EVIDENCE_CACHE_TTL_MS) {
    return cached.items.map(item => ({ ...item }));
  }
  if (evidenceRequests.has(cacheKey)) {
    return evidenceRequests.get(cacheKey);
  }

  const request = (async () => {
    const localItems = searchLocalEvidence(query);
    let remoteItems = [];

    if (localItems.length < 8) {
      try {
        remoteItems = await fetchFeed(buildEvidenceQueries(query)[0] || query, days);
      } catch (error) {
        if (!localItems.length) throw error;
      }
    }

    const items = uniqueItems([...localItems, ...remoteItems]).slice(0, 24);
    evidenceCache.set(cacheKey, { createdAt: Date.now(), items });
    if (evidenceCache.size > 200) {
      evidenceCache.delete(evidenceCache.keys().next().value);
    }
    return items.map(item => ({ ...item }));
  })();

  evidenceRequests.set(cacheKey, request);
  try {
    return await request;
  } finally {
    evidenceRequests.delete(cacheKey);
  }
}

module.exports = {
  collectNewsEvidence,
  buildEvidenceQueries
};
