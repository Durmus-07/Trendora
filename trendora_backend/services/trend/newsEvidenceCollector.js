const axios = require('axios');
const Parser = require('rss-parser');

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
  const requests = buildEvidenceQueries(query).map(item => fetchFeed(item, days));
  const settled = await Promise.allSettled(requests);
  const items = settled
    .filter(result => result.status === 'fulfilled')
    .flatMap(result => result.value || []);

  if (!items.length && settled.some(result => result.status === 'rejected')) {
    const firstError = settled.find(result => result.status === 'rejected')?.reason;
    throw firstError || new Error('Haber kanıtı alınamadı.');
  }

  return uniqueItems(items).slice(0, 36);
}

module.exports = {
  collectNewsEvidence,
  buildEvidenceQueries
};
