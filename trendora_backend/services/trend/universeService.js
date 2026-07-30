const {
  fetchBistUniverse,
  getFallbackBistUniverse
} = require('./providers/bistProvider');

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

const memoryCache = new Map();

function getCacheKey(market) {
  return String(market || 'BIST').trim().toUpperCase();
}

function isCacheValid(cacheEntry) {
  return (
    cacheEntry &&
    Array.isArray(cacheEntry.items) &&
    cacheEntry.items.length > 0 &&
    Date.now() - cacheEntry.updatedAt < CACHE_TTL_MS
  );
}

async function getUniverse(options = {}) {
  const market = getCacheKey(options.market);
  const forceRefresh = options.forceRefresh === true;

  if (market !== 'BIST') {
    return [];
  }

  const cached = memoryCache.get(market);

  if (!forceRefresh && isCacheValid(cached)) {
    return cached.items;
  }

  let items;

  try {
    items = await fetchBistUniverse(options);
  } catch (error) {
    console.warn(
      `[Universe] BIST provider başarısız oldu, fallback kullanılıyor: ${error.message}`
    );

    items = getFallbackBistUniverse();
  }

  if (!Array.isArray(items) || items.length === 0) {
    items = getFallbackBistUniverse();
  }

  memoryCache.set(market, {
    updatedAt: Date.now(),
    items
  });

  return items;
}

function clearUniverseCache(market) {
  if (market) {
    memoryCache.delete(getCacheKey(market));
    return;
  }

  memoryCache.clear();
}

module.exports = {
  getUniverse,
  getFallbackBistUniverse,
  clearUniverseCache
};
