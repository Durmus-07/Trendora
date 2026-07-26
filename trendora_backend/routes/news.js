const express = require('express');
const fs = require('fs');
const path = require('path');

const router = express.Router();

const NEWS_DATABASE_FILE = path.join(
  __dirname,
  '..',
  'database',
  'news_database.json'
);

const NEWS_STATUS_FILE = path.join(
  __dirname,
  '..',
  'database',
  'news_status.json'
);

const PERIODS = {
  '1h': 60 * 60 * 1000,
  '4h': 4 * 60 * 60 * 1000,
  '12h': 12 * 60 * 60 * 1000,
  '24h': 24 * 60 * 60 * 1000,
  '48h': 48 * 60 * 60 * 1000,
  '7d': 7 * 24 * 60 * 60 * 1000,
  '30d': 30 * 24 * 60 * 60 * 1000,
  '60d': 60 * 24 * 60 * 60 * 1000,
  '180d': 180 * 24 * 60 * 60 * 1000,
  '365d': 365 * 24 * 60 * 60 * 1000,
  all: null
};

function readJsonFile(filePath, fallbackValue) {
  try {
    if (!fs.existsSync(filePath)) {
      return fallbackValue;
    }

    const raw = fs.readFileSync(filePath, 'utf8');

    if (!raw.trim()) {
      return fallbackValue;
    }

    return JSON.parse(raw);
  } catch (error) {
    console.error(
      `[NEWS ROUTE] ${path.basename(filePath)} okunamadı:`,
      error.message
    );

    return fallbackValue;
  }
}

function readNewsDatabase() {
  const database = readJsonFile(NEWS_DATABASE_FILE, {
    success: false,
    createdAt: null,
    updatedAt: null,
    newsCount: 0,
    totalSources: 0,
    activeSources: 0,
    failedSources: 0,
    completedSourceCount: 0,
    partial: true,
    items: [],
    sourceResults: []
  });

  return {
    success: database.success !== false,
    createdAt: database.createdAt || null,
    updatedAt: database.updatedAt || null,
    newsCount: Number(database.newsCount || 0),
    totalSources: Number(database.totalSources || 0),
    activeSources: Number(database.activeSources || 0),
    failedSources: Number(database.failedSources || 0),
    completedSourceCount: Number(
      database.completedSourceCount ||
        (Array.isArray(database.sourceResults)
          ? database.sourceResults.length
          : 0)
    ),
    partial: Boolean(database.partial),
    items: Array.isArray(database.items) ? database.items : [],
    sourceResults: Array.isArray(database.sourceResults)
      ? database.sourceResults
      : []
  };
}

function readCollectorStatus() {
  return readJsonFile(NEWS_STATUS_FILE, {
    running: false,
    phase: 'unknown',
    startedAt: null,
    completedAt: null,
    durationMs: null,
    newsCount: 0,
    totalSources: 0,
    activeSources: 0,
    failedSources: 0,
    error: null
  });
}

function normalizeText(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/[\s-]+/g, '_');
}

function normalizeCategory(value) {
  const category = normalizeText(value || 'tumu');

  const categoryMap = {
    all: 'tumu',
    tum: 'tumu',
    tumu: 'tumu',
    genel: 'tumu',
    sondakika: 'son_dakika',
    son_dakika: 'son_dakika',
    breaking: 'son_dakika',
    gundem: 'gundem',
    turkiye: 'gundem',
    dunya: 'dunya',
    world: 'dunya',
    ekonomi: 'ekonomi',
    economy: 'ekonomi',
    finance: 'ekonomi',
    spor: 'spor',
    sports: 'spor',
    teknoloji: 'teknoloji',
    technology: 'teknoloji',
    tech: 'teknoloji'
  };

  return categoryMap[category] || category;
}

function normalizePeriod(value) {
  const period = String(value || 'all').trim().toLowerCase();

  return Object.prototype.hasOwnProperty.call(PERIODS, period)
    ? period
    : 'all';
}

function parsePositiveInteger(value, fallback, maximum) {
  const parsed = Number.parseInt(String(value || ''), 10);

  if (!Number.isFinite(parsed) || parsed < 1) {
    return fallback;
  }

  return Math.min(parsed, maximum);
}

function filterByCategory(items, category) {
  if (category === 'tumu') {
    return items;
  }

  if (category === 'son_dakika') {
    return items.filter((item) => item.isBreaking === true);
  }

  return items.filter(
    (item) => normalizeCategory(item.category) === category
  );
}

function filterByPeriod(items, period) {
  const duration = PERIODS[period];

  if (duration == null) {
    return items;
  }

  const now = Date.now();
  const cutoff = now - duration;

  return items.filter((item) => {
    const publishedTime = new Date(item.publishedAt).getTime();

    return (
      Number.isFinite(publishedTime) &&
      publishedTime >= cutoff &&
      publishedTime <= now + 5 * 60 * 1000
    );
  });
}

function filterBySearch(items, searchValue) {
  const search = normalizeText(searchValue);

  if (!search) {
    return items;
  }

  return items.filter((item) => {
    const haystack = normalizeText(
      [
        item.title,
        item.description,
        item.source,
        item.feedSource,
        item.category
      ].join(' ')
    );

    return haystack.includes(search);
  });
}

function sortNews(items) {
  return [...items].sort((left, right) => {
    const breakingDifference =
      Number(right.isBreaking === true) - Number(left.isBreaking === true);

    if (breakingDifference !== 0) {
      return breakingDifference;
    }

    const rightImportance = Number(
      right.importanceScore || right.trendScore || 0
    );

    const leftImportance = Number(
      left.importanceScore || left.trendScore || 0
    );

    const importanceDifference = rightImportance - leftImportance;

    if (importanceDifference !== 0) {
      return importanceDifference;
    }

    return (
      new Date(right.publishedAt).getTime() -
      new Date(left.publishedAt).getTime()
    );
  });
}

function buildEmptyResponse(database, collectorStatus) {
  return {
    success: true,
    message:
      collectorStatus.running === true
        ? 'Haberler hazırlanıyor.'
        : 'Henüz gösterilecek haber bulunamadı.',
    news: [],
    items: [],
    data: [],
    count: 0,
    total: 0,
    page: 1,
    limit: 20,
    totalPages: 0,
    hasMore: false,
    category: 'tumu',
    period: 'all',
    updatedAt: database.updatedAt,
    workingSources: database.activeSources,
    activeSources: database.activeSources,
    totalSources: database.totalSources,
    failedSources: database.failedSources,
    partial: database.partial,
    collectorRunning: collectorStatus.running === true,
    collectorPhase: collectorStatus.phase || 'unknown'
  };
}

router.get('/', (req, res) => {
  try {
    const database = readNewsDatabase();
    const collectorStatus = readCollectorStatus();

    const category = normalizeCategory(
      req.query.category || req.query.kategori || 'tumu'
    );

    const period = normalizePeriod(
      req.query.period || req.query.sure || 'all'
    );

    const page = parsePositiveInteger(req.query.page, 1, 100000);
    const limit = parsePositiveInteger(req.query.limit, 20, 100);
    const search = req.query.search || req.query.q || '';

    let filteredItems = [...database.items];

    filteredItems = filterByCategory(filteredItems, category);
    filteredItems = filterByPeriod(filteredItems, period);
    filteredItems = filterBySearch(filteredItems, search);
    filteredItems = sortNews(filteredItems);

    const total = filteredItems.length;
    const totalPages = total === 0 ? 0 : Math.ceil(total / limit);
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedItems = filteredItems.slice(startIndex, endIndex);
    const hasMore = endIndex < total;

    res.set('Cache-Control', 'no-store');

    if (database.items.length === 0 && paginatedItems.length === 0) {
      return res.json(buildEmptyResponse(database, collectorStatus));
    }

    return res.json({
      success: true,
      message: 'Haberler başarıyla getirildi.',
      news: paginatedItems,
      items: paginatedItems,
      data: paginatedItems,
      count: paginatedItems.length,
      total,
      page,
      limit,
      totalPages,
      hasMore,
      category,
      period,
      search: String(search || ''),
      updatedAt: database.updatedAt || database.createdAt || null,
      workingSources: database.activeSources,
      activeSources: database.activeSources,
      totalSources: database.totalSources,
      failedSources: database.failedSources,
      completedSourceCount: database.completedSourceCount,
      partial: database.partial || collectorStatus.running === true,
      collectorRunning: collectorStatus.running === true,
      collectorPhase: collectorStatus.phase || 'unknown',
      collectorError: collectorStatus.error || null
    });
  } catch (error) {
    console.error(
      '[NEWS ROUTE] Haberler gönderilemedi:',
      error.stack || error.message
    );

    return res.status(500).json({
      success: false,
      message: 'Haberler okunamadı.',
      error: error.message,
      news: [],
      items: [],
      data: [],
      count: 0,
      total: 0,
      hasMore: false
    });
  }
});

router.get('/status', async (req, res) => {
  try {
    res.set('Cache-Control', 'no-store');

    return res.json({
      success: true,
      ...(await getNewsStatus())
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Haber durumu okunamadı.',
      error: error.message
    });
  }
});

async function getNewsStatus() {
  const database = readNewsDatabase();
  const collectorStatus = readCollectorStatus();

  return {
    newsCount: database.items.length || database.newsCount || 0,
    totalSources:
      database.totalSources || Number(collectorStatus.totalSources || 0),
    activeSources:
      database.activeSources || Number(collectorStatus.activeSources || 0),
    failedSources:
      database.failedSources || Number(collectorStatus.failedSources || 0),
    completedSourceCount: database.completedSourceCount,
    updatedAt:
      database.updatedAt ||
      database.createdAt ||
      collectorStatus.completedAt ||
      null,
    ready: database.items.length > 0,
    partial: database.partial || collectorStatus.running === true,
    collectorRunning: collectorStatus.running === true,
    collectorPhase: collectorStatus.phase || 'unknown',
    error: collectorStatus.error || null
  };
}

module.exports = router;
module.exports.router = router;
module.exports.getNewsStatus = getNewsStatus;