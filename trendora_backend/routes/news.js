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
    return JSON.parse(raw);
  } catch (error) {
    console.error(
      `[NEWS API] ${path.basename(filePath)} okunamadı:`,
      error?.message || error
    );
    return fallbackValue;
  }
}

function readNewsDatabase() {
  const data = readJsonFile(NEWS_DATABASE_FILE, null);

  if (!data || !Array.isArray(data.items)) {
    return {
      createdAt: 0,
      updatedAt: null,
      newsCount: 0,
      totalSources: 0,
      activeSources: 0,
      failedSources: 0,
      items: [],
      sourceResults: []
    };
  }

  return {
    createdAt: Number(data.createdAt || 0),
    updatedAt: data.updatedAt || null,
    newsCount: Number(data.newsCount || data.items.length),
    totalSources: Number(data.totalSources || 0),
    activeSources: Number(data.activeSources || 0),
    failedSources: Number(data.failedSources || 0),
    items: data.items,
    sourceResults: Array.isArray(data.sourceResults)
      ? data.sourceResults
      : []
  };
}

function cleanText(value) {
  return String(value || '').trim();
}

function normalizePeriod(value) {
  const period = String(value || 'all').toLowerCase();

  return Object.prototype.hasOwnProperty.call(PERIODS, period)
    ? period
    : 'all';
}

function filterByPeriod(items, period) {
  const duration = PERIODS[period];

  if (duration == null) {
    return items;
  }

  const now = Date.now();
  const cutoff = now - duration;

  return items.filter((item) => {
    const time = new Date(item.publishedAt).getTime();

    return (
      Number.isFinite(time) &&
      time >= cutoff &&
      time <= now + 5 * 60 * 1000
    );
  });
}

function isStrictBreaking(item) {
  const ageMs =
    Date.now() - new Date(item.publishedAt).getTime();

  return (
    item.isBreaking === true &&
    ageMs >= 0 &&
    ageMs <= 2 * 60 * 60 * 1000
  );
}

function diversifySources(items) {
  const queue = [...items];
  const output = [];

  while (queue.length > 0) {
    const recentSources = new Set(
      output.slice(-3).map((item) => item.source)
    );

    let index = queue.findIndex(
      (item) => !recentSources.has(item.source)
    );

    if (index < 0) {
      index = 0;
    }

    output.push(queue.splice(index, 1)[0]);
  }

  return output;
}

function balanceGeneralFeed(items) {
  const categories = [
    'gundem',
    'dunya',
    'ekonomi',
    'spor',
    'teknoloji'
  ];

  const buckets = new Map(
    categories.map((category) => [category, []])
  );

  const others = [];

  for (const item of items) {
    const bucket = buckets.get(item.category);

    if (bucket) {
      bucket.push(item);
    } else {
      others.push(item);
    }
  }

  for (const bucket of buckets.values()) {
    bucket.sort((left, right) => {
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

  const weights = [
    'gundem',
    'dunya',
    'ekonomi',
    'gundem',
    'spor',
    'teknoloji'
  ];

  const output = [];
  let progressed = true;

  while (progressed) {
    progressed = false;

    for (const category of weights) {
      const bucket = buckets.get(category);

      if (bucket && bucket.length > 0) {
        output.push(bucket.shift());
        progressed = true;
      }
    }
  }

  return diversifySources([...output, ...others]);
}

router.get('/', (req, res) => {
  try {
    const database = readNewsDatabase();

    const requestedCategory = cleanText(
      req.query.category
    ).toLocaleLowerCase('tr-TR');

    const breakingOnly =
      String(req.query.breaking || '').toLowerCase() ===
      'true';

    const region = cleanText(
      req.query.region
    ).toLowerCase();

    const period = normalizePeriod(
      req.query.period
    );

    const page = Math.max(
      1,
      Number.parseInt(req.query.page, 10) || 1
    );

    const parsedLimit = Number.parseInt(
      req.query.limit,
      10
    );

    const limit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 2000)
      : 1500;

    let filtered = filterByPeriod(
      database.items,
      period
    );

    if (
      requestedCategory &&
      !['tumu', 'genel'].includes(requestedCategory)
    ) {
      if (requestedCategory === 'son_dakika') {
        filtered = filtered.filter(isStrictBreaking);
      } else if (requestedCategory === 'gundem') {
        filtered = filtered.filter(
          (item) => item.category === 'gundem'
        );
      } else {
        filtered = filtered.filter(
          (item) =>
            item.category === requestedCategory
        );
      }
    }

    if (breakingOnly) {
      filtered = filtered.filter(isStrictBreaking);
    }

    if (region === 'world') {
      filtered = filtered.filter(
        (item) => item.region === 'world'
      );
    }

    if (region === 'tr') {
      filtered = filtered.filter(
        (item) => item.region !== 'world'
      );
    }

    filtered =
      requestedCategory &&
      !['tumu', 'genel'].includes(requestedCategory)
        ? diversifySources(filtered)
        : balanceGeneralFeed(filtered);

    const offset = (page - 1) * limit;
    const pageItems = filtered.slice(
      offset,
      offset + limit
    );

    res.set('Cache-Control', 'no-store');
    res.json({
      success: true,
      message: database.updatedAt
        ? 'Trendora Akıllı Haber Servisi Aktif'
        : 'Haber collector ilk taramayı henüz tamamlamadı.',
      ready: Boolean(database.updatedAt),
      updatedAt: database.updatedAt,
      fromCache: true,
      total: filtered.length,
      returned: pageItems.length,
      page,
      limit,
      hasMore:
        offset + pageItems.length < filtered.length,
      archiveCount: database.items.length,
      workingSources: database.activeSources,
      totalSources: database.totalSources,
      failedSources: database.failedSources,
      filters: {
        category: requestedCategory || 'genel',
        breakingOnly,
        region: region || 'all',
        period
      },
      news: pageItems,
      data: pageItems
    });
  } catch (error) {
    console.error('[NEWS API] Genel hata:', error);

    res.status(500).json({
      success: false,
      error: 'Haberler şu anda okunamadı.',
      details:
        process.env.NODE_ENV === 'development'
          ? error?.message
          : undefined
    });
  }
});

router.get('/health', (req, res) => {
  const database = readNewsDatabase();
  const collector = readJsonFile(
    NEWS_STATUS_FILE,
    {
      running: false,
      phase: 'not_started',
      error: null
    }
  );

  res.set('Cache-Control', 'no-store');
  res.json({
    success: true,
    service: 'Trendora Akıllı Haber Merkezi',
    ready: Boolean(database.updatedAt),
    cachedNewsCount: database.items.length,
    cacheUpdatedAt: database.updatedAt,
    collector
  });
});

router.get('/sources', (req, res) => {
  const database = readNewsDatabase();

  res.json({
    success: true,
    total: database.totalSources,
    activeSources: database.activeSources,
    failedSources: database.failedSources,
    sources: database.sourceResults
  });
});

async function getNewsStatus() {
  const database = readNewsDatabase();
  const collector = readJsonFile(
    NEWS_STATUS_FILE,
    {
      running: false,
      phase: 'not_started',
      error: null
    }
  );

  return {
    newsCount: database.items.length,
    totalSources: database.totalSources,
    activeSources: database.activeSources,
    failedSources: database.failedSources,
    updatedAt: database.updatedAt,
    fromCache: true,
    collectorRunning: collector.running === true,
    collectorPhase: collector.phase || 'unknown',
    error: collector.error || null
  };
}

module.exports = router;
module.exports.getNewsStatus = getNewsStatus;
