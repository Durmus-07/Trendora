const fs = require('fs');
const path = require('path');

const {
  bankaKampanyalariniGetir,
  otomobilKampanyalariniGetir,
  tumKampanyalariGetir
} = require('./campaignCollector');

const dataFilePath = path.join(
  __dirname,
  '..',
  'database',
  'opportunities.json'
);

function readDatabase() {
  try {
    if (!fs.existsSync(dataFilePath)) {
      return { updatedAt: null, items: [] };
    }

    const parsed = JSON.parse(fs.readFileSync(dataFilePath, 'utf8'));
    return {
      updatedAt: parsed.updatedAt || null,
      items: Array.isArray(parsed.items) ? parsed.items : []
    };
  } catch (error) {
    console.error('Kampanya senkronizasyonu veritabanını okuyamadı:', error.message);
    return { updatedAt: null, items: [] };
  }
}

function writeDatabase(items) {
  fs.mkdirSync(path.dirname(dataFilePath), { recursive: true });

  const database = {
    updatedAt: new Date().toISOString(),
    items
  };

  const temporaryPath = `${dataFilePath}.tmp`;
  fs.writeFileSync(temporaryPath, JSON.stringify(database, null, 2), 'utf8');
  fs.renameSync(temporaryPath, dataFilePath);

  return database;
}

function normalizeCategory(value) {
  return String(value || '').trim().toLowerCase();
}

function mergeCategoryItems(existingItems, newItems, categories) {
  const categorySet = new Set(categories);
  const preservedItems = existingItems.filter(
    item => !categorySet.has(normalizeCategory(item.category))
  );

  return [...newItems, ...preservedItems];
}

async function bankaKampanyalariniYenile() {
  const result = await bankaKampanyalariniGetir();
  const database = readDatabase();

  if (result.items.length === 0) {
    return {
      success: false,
      message: 'Banka kaynaklarından yeni kampanya alınamadı; mevcut kayıtlar korundu.',
      count: 0,
      sourceResults: result.sourceResults,
      updatedAt: database.updatedAt,
      items: []
    };
  }

  const newDatabase = writeDatabase(
    mergeCategoryItems(database.items, result.items, ['bank'])
  );

  return {
    success: true,
    message: 'Banka kampanyaları yenilendi.',
    count: result.items.length,
    sourceResults: result.sourceResults,
    updatedAt: newDatabase.updatedAt,
    items: result.items
  };
}

async function otomobilKampanyalariniYenile() {
  const result = await otomobilKampanyalariniGetir();
  const database = readDatabase();

  if (result.items.length === 0) {
    return {
      success: false,
      message: 'Otomobil kaynaklarından yeni kampanya alınamadı; mevcut kayıtlar korundu.',
      count: 0,
      sourceResults: result.sourceResults,
      updatedAt: database.updatedAt,
      items: []
    };
  }

  const newDatabase = writeDatabase(
    mergeCategoryItems(database.items, result.items, ['automotive'])
  );

  return {
    success: true,
    message: 'Otomobil kampanyaları yenilendi.',
    count: result.items.length,
    sourceResults: result.sourceResults,
    updatedAt: newDatabase.updatedAt,
    items: result.items
  };
}

async function tumKampanyalariYenile() {
  const result = await tumKampanyalariGetir();
  const database = readDatabase();

  if (result.items.length === 0) {
    return {
      success: false,
      message: 'Yeni banka veya otomobil kampanyası alınamadı; mevcut kayıtlar korundu.',
      count: 0,
      bank: result.bank.sourceResults,
      automotive: result.automotive.sourceResults,
      updatedAt: database.updatedAt,
      items: []
    };
  }

  const categoriesToReplace = [];
  if (result.bank.items.length > 0) categoriesToReplace.push('bank');
  if (result.automotive.items.length > 0) categoriesToReplace.push('automotive');

  const newDatabase = writeDatabase(
    mergeCategoryItems(database.items, result.items, categoriesToReplace)
  );

  return {
    success: true,
    message: 'Banka ve otomobil kampanyaları yenilendi.',
    count: result.items.length,
    bankCount: result.bank.items.length,
    automotiveCount: result.automotive.items.length,
    bank: result.bank.sourceResults,
    automotive: result.automotive.sourceResults,
    updatedAt: newDatabase.updatedAt,
    items: result.items
  };
}

module.exports = {
  bankaKampanyalariniYenile,
  otomobilKampanyalariniYenile,
  tumKampanyalariYenile
};
