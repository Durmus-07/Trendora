const express = require('express');
const fs = require('fs');
const path = require('path');

const {
  bimUrunleriniGetir
} = require('../services/bimCollector');

const router = express.Router();

const dataFilePath = path.join(
  __dirname,
  '..',
  'database',
  'opportunities.json'
);

function readDatabase() {
  try {
    if (!fs.existsSync(dataFilePath)) {
      return {
        updatedAt: null,
        items: []
      };
    }

    const rawData = fs.readFileSync(
      dataFilePath,
      'utf8'
    );

    const parsedData = JSON.parse(rawData);

    return {
      updatedAt: parsedData.updatedAt || null,
      items: Array.isArray(parsedData.items)
        ? parsedData.items
        : []
    };
  } catch (error) {
    console.error(
      'opportunities.json okunamadı:',
      error.message
    );

    return {
      updatedAt: null,
      items: []
    };
  }
}

function writeDatabase(items) {
  const database = {
    updatedAt: new Date().toISOString(),
    items
  };

  fs.writeFileSync(
    dataFilePath,
    JSON.stringify(database, null, 2),
    'utf8'
  );

  return database;
}

function normalize(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR');
}

function normalizeStoreKey(value) {
  const normalized = normalize(value);

  if (
    normalized === 'amazon' ||
    normalized === 'amazon.com.tr' ||
    normalized === 'amzn'
  ) {
    return 'amazon';
  }

  if (
    normalized === 'trendyol' ||
    normalized === 'ty'
  ) {
    return 'trendyol';
  }

  if (
    normalized === 'n11' ||
    normalized === 'n 11'
  ) {
    return 'n11';
  }

  if (
    normalized === 'hepsiburada' ||
    normalized === 'hepsi burada' ||
    normalized === 'hb'
  ) {
    return 'hepsiburada';
  }

  if (
    normalized === 'a101' ||
    normalized === 'a 101'
  ) {
    return 'a101';
  }

  if (normalized === 'bim' || normalized === 'bi̇m') {
    return 'bim';
  }

  if (
    normalized === 'sok' ||
    normalized === 'şok'
  ) {
    return 'sok';
  }

  if (normalized === 'migros') {
    return 'migros';
  }

  if (
    normalized === 'carrefoursa' ||
    normalized === 'carrefour'
  ) {
    return 'carrefoursa';
  }

  if (normalized === 'pazarama') {
    return 'pazarama';
  }

  if (normalized === 'teknosa') {
    return 'teknosa';
  }

  if (
    normalized === 'mediamarkt' ||
    normalized === 'media markt'
  ) {
    return 'mediamarkt';
  }

  return normalized;
}

function parseLimit(value, defaultValue = 100) {
  const parsed = Number.parseInt(value, 10);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return defaultValue;
  }

  return Math.min(parsed, 500);
}

function isActive(item) {
  if (item.active === false) {
    return false;
  }

  const now = new Date();

  if (item.catalogStartDate) {
    const startDate = new Date(
      `${item.catalogStartDate}T00:00:00`
    );

    if (
      !Number.isNaN(startDate.getTime()) &&
      now < startDate
    ) {
      return false;
    }
  }

  if (item.catalogEndDate) {
    const endDate = new Date(
      `${item.catalogEndDate}T23:59:59`
    );

    if (
      !Number.isNaN(endDate.getTime()) &&
      now > endDate
    ) {
      return false;
    }
  }

  return true;
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (
      typeof value === 'string' &&
      value.trim() !== ''
    ) {
      return value.trim();
    }
  }

  return '';
}

function collectSearchText(item) {
  const rawLinks = Array.isArray(item.rawLinks)
    ? item.rawLinks.join(' ')
    : '';

  return normalize([
    item.source,
    item.store,
    item.seller,
    item.sourceName,
    item.title,
    item.description,
    item.url,
    item.officialUrl,
    item.link,
    item.finalUrl,
    item.resolvedUrl,
    item.productUrl,
    rawLinks
  ].join(' '));
}

function detectStore(item) {
  const explicitCandidates = [
    item.store,
    item.source,
    item.seller
  ];

  for (const candidate of explicitCandidates) {
    const key = normalizeStoreKey(candidate);

    if (
      key &&
      key !== 'telegram' &&
      key !== 'genel'
    ) {
      return key;
    }
  }

  const text = collectSearchText(item);

  if (
    text.includes('amazon.com.tr') ||
    text.includes('amzn.to') ||
    text.includes('amzn-') ||
    text.includes('/amzn') ||
    text.includes('amazon')
  ) {
    return 'amazon';
  }

  if (
    text.includes('trendyol.com') ||
    text.includes('ty.gl') ||
    text.includes('trendyol')
  ) {
    return 'trendyol';
  }

  if (
    text.includes('n11.com') ||
    text.includes('sl.n11.com') ||
    text.includes('n11')
  ) {
    return 'n11';
  }

  if (
    text.includes('hepsiburada.com') ||
    text.includes('app.hb.biz') ||
    text.includes('hb.biz') ||
    text.includes('hepsiburada') ||
    text.includes('hepsi burada')
  ) {
    return 'hepsiburada';
  }

  if (
    text.includes('a101.com.tr') ||
    text.includes('a101')
  ) {
    return 'a101';
  }

  if (
    text.includes('bim.com.tr') ||
    text.includes('bim')
  ) {
    return 'bim';
  }

  if (
    text.includes('sokmarket.com.tr') ||
    text.includes('şok market') ||
    text.includes('sok market')
  ) {
    return 'sok';
  }

  if (text.includes('migros')) {
    return 'migros';
  }

  if (
    text.includes('carrefoursa') ||
    text.includes('carrefour')
  ) {
    return 'carrefoursa';
  }

  if (text.includes('pazarama')) {
    return 'pazarama';
  }

  if (text.includes('teknosa')) {
    return 'teknosa';
  }

  if (
    text.includes('mediamarkt') ||
    text.includes('media markt')
  ) {
    return 'mediamarkt';
  }

  return normalizeStoreKey(
    item.store ||
    item.source ||
    'telegram'
  );
}

function prepareItem(item) {
  const detectedStore = detectStore(item);

  const imageUrl = firstNonEmpty(
    item.imageUrl,
    item.image,
    item.thumbnail,
    item.thumbnailUrl,
    item.productImage,
    item.productImageUrl,
    item.telegramImage,
    item.telegramImageUrl,
    item.messageImage,
    item.messageImageUrl,
    item.photoUrl,
    item.mediaUrl,
    item.ogImage
  );

  const officialUrl = firstNonEmpty(
    item.officialUrl,
    item.finalUrl,
    item.resolvedUrl,
    item.productUrl,
    item.url,
    item.link,
    item.telegramMessageUrl
  );

  return {
    ...item,
    store: detectedStore,
    imageUrl,
    officialUrl,
    url: officialUrl,
    verified:
      item.verified === true ||
      Boolean(item.verifiedAt),
    status: isActive(item)
      ? 'active'
      : 'expired'
  };
}

function itemMatchesSource(item, requestedSource) {
  const wanted = normalizeStoreKey(
    requestedSource
  );

  if (!wanted) {
    return true;
  }

  const detectedStore = detectStore(item);

  if (detectedStore === wanted) {
    return true;
  }

  const source = normalizeStoreKey(
    item.source
  );

  const store = normalizeStoreKey(
    item.store
  );

  return (
    source === wanted ||
    store === wanted
  );
}

function filterAndLimitItems(items, {
  source,
  category,
  limit
}) {
  let result = items
    .map(prepareItem)
    .filter(item => item.status === 'active');

  if (source) {
    result = result.filter(
      item => itemMatchesSource(item, source)
    );
  }

  if (category) {
    result = result.filter(
      item =>
        normalize(item.category) === category
    );
  }

  return result.slice(0, limit);
}

function sendItemsResponse(
  res,
  database,
  items
) {
  res.json({
    success: true,
    count: items.length,
    updatedAt: database.updatedAt,
    opportunities: items,
    products: items,
    items,
    data: items
  });
}

router.get('/', (req, res) => {
  try {
    const database = readDatabase();

    const source = normalizeStoreKey(
      req.query.source
    );

    const category = normalize(
      req.query.category
    );

    const limit = parseLimit(
      req.query.limit,
      100
    );

    const items = filterAndLimitItems(
      database.items,
      {
        source,
        category,
        limit
      }
    );

    sendItemsResponse(
      res,
      database,
      items
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message:
        'Fırsatlar okunamadı.',
      error: error.message
    });
  }
});

/*
  BİM ürünlerini hemen yeniler:
  /api/opportunities/bim/refresh
*/
router.get('/bim/refresh', async (req, res) => {
  try {
    const bimItems =
      await bimUrunleriniGetir();

    if (bimItems.length === 0) {
      return res.status(502).json({
        success: false,
        message:
          'BİM sayfasına ulaşıldı ancak ürünler ayrıştırılamadı.',
        count: 0
      });
    }

    const database = readDatabase();

    const otherSources =
      database.items.filter(
        item =>
          detectStore(item) !== 'bim'
      );

    const newDatabase = writeDatabase([
      ...otherSources,
      ...bimItems
    ]);

    const preparedBimItems =
      bimItems.map(prepareItem);

    res.json({
      success: true,
      message:
        'BİM ürünleri yenilendi.',
      count: preparedBimItems.length,
      updatedAt: newDatabase.updatedAt,
      opportunities: preparedBimItems,
      products: preparedBimItems,
      items: preparedBimItems,
      data: preparedBimItems
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message:
        'BİM ürünleri alınamadı.',
      error: error.message
    });
  }
});

router.get('/:source', (req, res) => {
  try {
    const database = readDatabase();

    const source = normalizeStoreKey(
      req.params.source
    );

    const category = normalize(
      req.query.category
    );

    const limit = parseLimit(
      req.query.limit,
      100
    );

    const items = filterAndLimitItems(
      database.items,
      {
        source,
        category,
        limit
      }
    );

    sendItemsResponse(
      res,
      database,
      items
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message:
        'Kaynak fırsatları okunamadı.',
      error: error.message
    });
  }
});

module.exports = router;