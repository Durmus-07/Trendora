const axios = require('axios');
const cheerio = require('cheerio');
const { BIST_ENTITIES } = require('../entityEngine');

const KAP_BIST_URL = 'https://kap.org.tr/tr/bist-sirketler';
const MIN_VALID_LIVE_SYMBOLS = 100;
const MAX_VALID_LIVE_SYMBOLS = 1200;

function normalizeUniverseItem(item, source = 'fallback') {
  if (!item || !item.symbol) {
    return null;
  }

  const symbol = String(item.symbol).trim().toUpperCase();

  if (!/^[A-Z0-9]{4,6}$/.test(symbol)) {
    return null;
  }

  return {
    symbol,
    name: String(item.name || symbol).replace(/\s+/g, ' ').trim(),
    aliases: Array.isArray(item.aliases) ? item.aliases : [],
    market: 'BIST',
    exchange: 'BIST',
    assetType: symbol.endsWith('.S1') ? 'certificate' : 'equity',
    currency: 'TRY',
    country: 'TR',
    active: true,
    source
  };
}

function getFallbackBistUniverse() {
  return BIST_ENTITIES
    .filter(item => !String(item.symbol || '').endsWith('.S1'))
    .map(item => normalizeUniverseItem(item, 'fallback'))
    .filter(Boolean);
}

function parseKapBistCompanies(html) {
  const $ = cheerio.load(html);
  const companies = new Map();

  $('table tbody tr').each((_, row) => {
    const cells = $(row).find('td');

    if (cells.length < 2) {
      return;
    }

    const symbol = $(cells[0])
      .text()
      .replace(/\s+/g, ' ')
      .trim()
      .split(' ')[0]
      .toUpperCase();

    const name = $(cells[1])
      .text()
      .replace(/\s+/g, ' ')
      .trim();

    if (!/^[A-Z0-9]{4,6}$/.test(symbol)) {
      return;
    }

    const normalized = normalizeUniverseItem(
      {
        symbol,
        name: name || symbol,
        aliases: []
      },
      'kap'
    );

    if (normalized) {
      companies.set(symbol, normalized);
    }
  });

  return [...companies.values()].sort((a, b) =>
    a.symbol.localeCompare(b.symbol, 'tr')
  );
}

async function fetchKapBistUniverse() {
  const response = await axios.get(KAP_BIST_URL, {
    timeout: 20000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; Trendora/1.0)',
      'Accept-Language': 'tr-TR,tr;q=0.9',
      Accept: 'text/html,application/xhtml+xml'
    }
  });

  const universe = parseKapBistCompanies(response.data);

  if (
    universe.length < MIN_VALID_LIVE_SYMBOLS ||
    universe.length > MAX_VALID_LIVE_SYMBOLS
  ) {
    throw new Error(
      `KAP evreni şüpheli sayıda sembol döndürdü: ${universe.length}`
    );
  }

  return universe;
}

async function fetchBistUniverse() {
  try {
    return await fetchKapBistUniverse();
  } catch (error) {
    console.warn(
      '[BIST Universe] KAP canlı liste alınamadı, fallback kullanılıyor:',
      error.message
    );

    return getFallbackBistUniverse();
  }
}

module.exports = {
  fetchBistUniverse,
  fetchKapBistUniverse,
  getFallbackBistUniverse,
  normalizeUniverseItem,
  parseKapBistCompanies
};
