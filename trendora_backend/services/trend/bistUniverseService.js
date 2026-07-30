const axios = require('axios');
const { BIST_ENTITIES } = require('./entityEngine');

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

let memoryCache = {
  updatedAt: 0,
  items: []
};

function getFallbackUniverse() {
  return BIST_ENTITIES
    .filter(item => item && item.symbol)
    .filter(item => !item.symbol.endsWith('.S1'))
    .map(item => ({
      symbol: item.symbol,
      name: item.name || item.symbol,
      aliases: Array.isArray(item.aliases) ? item.aliases : [],
      market: 'BIST',
      currency: 'TRY',
      active: true,
      source: 'fallback'
    }));
}

function isCacheValid() {
  return (
    Array.isArray(memoryCache.items) &&
    memoryCache.items.length > 0 &&
    Date.now() - memoryCache.updatedAt < CACHE_TTL_MS
  );
}

async function getBistUniverse() {
  if (isCacheValid()) {
    return memoryCache.items;
  }

  const fallbackUniverse = getFallbackUniverse();

  memoryCache = {
    updatedAt: Date.now(),
    items: fallbackUniverse
  };

  return fallbackUniverse;
}

function clearUniverseCache() {
  memoryCache = {
    updatedAt: 0,
    items: []
  };
}

module.exports = {
  getBistUniverse,
  getFallbackUniverse,
  clearUniverseCache
};
