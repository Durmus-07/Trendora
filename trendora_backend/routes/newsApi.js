'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const { normalizeNews } = require('../services/dataModels');
const sourceHealth = require('../services/sourceHealth');

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

function readJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) {
      return fallback;
    }

    const raw = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    console.error(
      `[NEWS API] ${path.basename(filePath)} okunamadı:`,
      error.message
    );

    return fallback;
  }
}

function normalizeText(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR');
}

function normalizeCategory(value) {
  const category = normalizeText(value)
    .replace(/\s+/g, '_')
    .replace(/-/g, '_');

  const aliases = {
    genel: 'all',
    general: 'all',
    tumu: 'all',
    tümü: 'all',
    son_dakika: 'son_dakika',
    sondakika: 'son_dakika',
    breaking: 'son_dakika',
    gündem: 'gundem',
    gundem: 'gundem',
    dünya: 'dunya',
    dunya: 'dunya',
    ekonomi: 'ekonomi',
    spor: 'spor',
    teknoloji: 'teknoloji'
  };

  return aliases[category] || category || 'all';
}

function normalizePeriod(value) {
  const period = normalizeText(value || 'all');

  return Object.prototype.hasOwnProperty.call(
    PERIODS,
    period
  )
    ? period
    : 'all';
}

function filterByPeriod(items, period) {
  const duration = PERIODS[period];

  if (duration === null) {
    return items;
  }

  const now = Date.now();
  const cutoff = now - duration;

  return items.filter(item => {
    const timestamp =
      new Date(item.publishedAt).getTime();

    return (
      Number.isFinite(timestamp) &&
      timestamp >= cutoff &&
      timestamp <= now + 5 * 60 * 1000
    );
  });
}

function filterByCategory(items, category) {
  if (category === 'all') {
    return items;
  }

  if (category === 'son_dakika') {
    return items.filter(
      item => item.isBreaking === true
    );
  }

  return items.filter(
    item =>
      normalizeCategory(item.category) ===
      category
  );
}

function filterBySearch(items, query) {
  const search = normalizeText(query);

  if (!search) {
    return items;
  }

  return items.filter(item => {
    const haystack = normalizeText([
      item.title,
      item.description,
      item.source,
      item.feedSource,
      item.category
    ].join(' '));

    return haystack.includes(search);
  });
}

function sortNews(items) {
  return [...items].sort((left, right) => {
    const breakingDifference =
      Number(right.isBreaking === true) -
      Number(left.isBreaking === true);

    if (breakingDifference !== 0) {
      return breakingDifference;
    }

    const importanceDifference =
      Number(right.importanceScore || 0) -
      Number(left.importanceScore || 0);

    if (importanceDifference !== 0) {
      return importanceDifference;
    }

    return (
      new Date(right.publishedAt).getTime() -
      new Date(left.publishedAt).getTime()
    );
  });
}

function readNewsDatabase() {
  const database = readJson(
    NEWS_DATABASE_FILE,
    {
      success: false,
      updatedAt: null,
      newsCount: 0,
      totalSources: 0,
      activeSources: 0,
      failedSources: 0,
      items: [],
      sourceResults: []
    }
  );

  return {
    ...database,
    items: Array.isArray(database.items)
      ? database.items
      : [],
    sourceResults:
      Array.isArray(database.sourceResults)
        ? database.sourceResults
        : []
  };
}

async function getNewsStatus() {
  const database = readNewsDatabase();

  const collectorStatus = readJson(
    NEWS_STATUS_FILE,
    {
      running: false,
      phase: 'unknown',
      error: null
    }
  );

  const activeSources = Number(
    database.activeSources ??
    database.sourceResults.filter(
      item => item.ok === true
    ).length
  );

  const totalSources = Number(
    database.totalSources ??
    collectorStatus.totalSources ??
    database.sourceResults.length
  );

  const failedSources = Number(
    database.failedSources ??
    Math.max(0, totalSources - activeSources)
  );

  return {
    newsCount: database.items.length,
    totalSources,
    activeSources,
    failedSources,
    updatedAt:
      database.updatedAt ||
      collectorStatus.completedAt ||
      null,
    collectorRunning:
      collectorStatus.running === true,
    collectorPhase:
      collectorStatus.phase || 'unknown',
    error:
      collectorStatus.error || null
  };
}

router.get('/', async (req, res) => {
  try {
    const database = readNewsDatabase();

    const period = normalizePeriod(
      req.query.period
    );

    const category = normalizeCategory(
      req.query.category
    );

    const query =
      req.query.q || req.query.search || '';

    const requestedLimit = Number(
      req.query.limit || 100
    );

    const requestedOffset = Number(
      req.query.offset || 0
    );

    const limit = Math.min(
      500,
      Math.max(
        1,
        Number.isFinite(requestedLimit)
          ? requestedLimit
          : 100
      )
    );

    const offset = Math.max(
      0,
      Number.isFinite(requestedOffset)
        ? requestedOffset
        : 0
    );

    let items = database.items;

    items = filterByPeriod(items, period);
    items = filterByCategory(
      items,
      category
    );
    items = filterBySearch(items, query);
    items = sortNews(items);

    const total = items.length;
    const pageItems = items
      .slice(offset, offset + limit)
      .map(item => normalizeNews(item, { updatedAt: database.updatedAt }));
    sourceHealth.success('news-database', {
      recordCount: database.items.length,
      responseTimeMs: Date.now() - Number(req._startedAt || Date.now())
    });

    res.set(
      'Cache-Control',
      'public, max-age=60, stale-while-revalidate=180'
    );

    res.json({
      success: true,
      count: pageItems.length,
      total,
      offset,
      limit,
      period,
      category,
      updatedAt:
        database.updatedAt || null,
      partial:
        database.partial === true,
      news: pageItems,
      items: pageItems,
      data: pageItems
    });
  } catch (error) {
    console.error(
      '[NEWS API] Haberler gönderilemedi:',
      error.message
    );

    res.status(500).json({
      success: false,
      message:
        'Haberler şu anda okunamadı.',
      error: error.message,
      news: [],
      items: [],
      data: []
    });
  }
});

router.get('/status', async (req, res) => {
  try {
    res.set('Cache-Control', 'no-store');

    res.json({
      success: true,
      ...(await getNewsStatus())
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message:
        'Haber durumu okunamadı.',
      error: error.message
    });
  }
});

router.get('/health', async (req, res) => {
  try {
    const status = await getNewsStatus();

    res.set('Cache-Control', 'no-store');

    res.json({
      success: true,
      service: 'news',
      ready: status.newsCount > 0,
      ...status
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      service: 'news',
      ready: false,
      error: error.message
    });
  }
});

module.exports = {
  router,
  getNewsStatus
};
