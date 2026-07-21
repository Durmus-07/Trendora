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

function prepareItem(item) {
  return {
    ...item,
    imageUrl:
      item.imageUrl ||
      item.image ||
      item.thumbnail ||
      '',
    officialUrl:
      item.officialUrl ||
      item.url ||
      item.link ||
      '',
    url:
      item.officialUrl ||
      item.url ||
      item.link ||
      '',
    verified: Boolean(item.verifiedAt),
    status: isActive(item)
      ? 'active'
      : 'expired'
  };
}

function filterAndLimitItems(items, {
  source,
  category,
  limit
}) {
  let sonuc = items
    .map(prepareItem)
    .filter(item => item.status === 'active');

  if (source) {
    sonuc = sonuc.filter(
      item =>
        normalize(item.source) === source
    );
  }

  if (category) {
    sonuc = sonuc.filter(
      item =>
        normalize(item.category) === category
    );
  }

  return sonuc.slice(0, limit);
}
router.get('/', (req, res) => {
  try {
    const database = readDatabase();

    const source = normalize(
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

    res.json({
      success: true,
      count: items.length,
      updatedAt: database.updatedAt,
      opportunities: items,
      items,
      data: items
    });
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

    const digerKaynaklar =
      database.items.filter(
        item =>
          normalize(item.source) !== 'bim'
      );

    const yeniDatabase = writeDatabase([
      ...digerKaynaklar,
      ...bimItems
    ]);

    const hazirBimItems =
      bimItems.map(prepareItem);

    res.json({
      success: true,
      message:
        'BİM ürünleri yenilendi.',
      count: hazirBimItems.length,
      updatedAt: yeniDatabase.updatedAt,
      opportunities: hazirBimItems,
      items: hazirBimItems,
      data: hazirBimItems
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

    const source = normalize(
      req.params.source
    );

    const limit = parseLimit(
      req.query.limit,
      100
    );

    const items = filterAndLimitItems(
      database.items,
      {
        source,
        category: '',
        limit
      }
    );

    res.json({
      success: true,
      count: items.length,
      updatedAt: database.updatedAt,
      opportunities: items,
      items,
      data: items
    });
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