const axios = require('axios');
const Parser = require('rss-parser');

const parser = new Parser({
  timeout: 20000,
  headers: {
    'User-Agent': 'Trendora/2.0'
  }
});

function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildGoogleNewsUrl(query, days = 30) {
  const encodedQuery = encodeURIComponent(`${query} when:${days}d`);

  return (
    'https://news.google.com/rss/search' +
    `?q=${encodedQuery}` +
    '&hl=tr&gl=TR&ceid=TR:tr'
  );
}

function uniqueItems(items) {
  const seen = new Set();

  return items.filter(item => {
    const key = normalizeText(item.title)
      .replace(/[^\p{L}\p{N}\s]/gu, '')
      .slice(0, 160);

    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function collectNewsEvidence(query, days = 30) {
  const response = await axios.get(buildGoogleNewsUrl(query, days), {
    timeout: 20000,
    headers: {
      'User-Agent': 'Trendora/2.0'
    },
    responseType: 'text'
  });

  const feed = await parser.parseString(response.data);

  const items = (feed.items || []).map(item => ({
    title: item.title || 'Başlıksız içerik',
    url: item.link || '',
    source:
      item.creator ||
      item['dc:creator'] ||
      'Google Haberler',
    publishedAt: item.isoDate || item.pubDate || null,
    evidenceType: 'news'
  }));

  return uniqueItems(items).slice(0, 30);
}

module.exports = {
  collectNewsEvidence
};
