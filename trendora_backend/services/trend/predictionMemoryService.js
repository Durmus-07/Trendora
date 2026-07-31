const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const databasePath = path.join(
  __dirname,
  '..',
  '..',
  'database',
  'prediction_memory.json'
);

function matchPredictionAsset(value) {
  try {
    const { matchAsset } = require('../assets/assetMatcher');
    const match = matchAsset(value);
    if (!match?.matched || !match.asset || Number(match.confidence) < 0.9) {
      return null;
    }
    return match.asset;
  } catch (error) {
    console.warn(
      'Tahmin varlÄ±k kimliÄŸi merkezi katalogla eÅŸleÅŸtirilemedi:',
      error?.message || error
    );
    return null;
  }
}

function normalizeLegacyAssetKey(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace(/Ä°/g, 'i')
    .replace(/Ä±/g, 'i')
    .replace(/[â€™'`]/g, '')
    .replace(/[^a-z0-9Ã§ÄŸÄ±Ã¶ÅŸÃ¼\.\-\s/]/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function resolvePredictionAssetIdentity({ query, assetName, assetSymbol, entity }) {
  const directCatalogAsset = entity?.internalAssetId
    ? {
        internalAssetId: entity.internalAssetId,
        canonicalSymbol: entity.canonicalSymbol || entity.symbol || null,
        displayName: entity.displayName || entity.name || null,
        assetType: entity.assetType || entity.subtype || null,
        exchange: entity.exchange || null,
        currency: entity.currency || null
      }
    : null;
  const candidates = [
    entity?.internalAssetId,
    entity?.canonicalSymbol,
    entity?.providerSymbols?.yahoo,
    assetSymbol,
    assetName,
    query
  ].filter(value => String(value || '').trim().length > 0);

  const catalogAsset = directCatalogAsset || candidates
    .map(matchPredictionAsset)
    .find(Boolean);
  const legacyKey = normalizeLegacyAssetKey(
    assetSymbol || assetName || query
  );

  if (!catalogAsset) {
    return {
      legacyKey,
      identityKey: legacyKey
    };
  }

  return {
    legacyKey,
    identityKey: catalogAsset.internalAssetId ||
      catalogAsset.canonicalSymbol ||
      legacyKey,
    internalAssetId: catalogAsset.internalAssetId,
    canonicalSymbol: catalogAsset.canonicalSymbol,
    displayName: catalogAsset.displayName,
    assetType: catalogAsset.assetType,
    exchange: catalogAsset.exchange,
    currency: catalogAsset.currency
  };
}

function predictionIdentityKey(prediction) {
  const asset = prediction?.asset || {};
  if (asset.internalAssetId) return String(asset.internalAssetId);
  if (asset.canonicalSymbol) return String(asset.canonicalSymbol);
  return normalizeLegacyAssetKey(
    asset.symbol || asset.name || prediction?.query
  );
}

function ensureDatabaseDirectory() {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
}

function createEmptyDatabase() {
  return {
    version: 1,
    updatedAt: new Date().toISOString(),
    predictions: []
  };
}

function readDatabase() {
  ensureDatabaseDirectory();

  if (!fs.existsSync(databasePath)) {
    return createEmptyDatabase();
  }

  try {
    const raw = fs.readFileSync(databasePath, 'utf8').replace(/^\uFEFF/, '');
    const parsed = JSON.parse(raw);

    return {
      version: Number(parsed.version) || 1,
      updatedAt: parsed.updatedAt || null,
      predictions: Array.isArray(parsed.predictions)
        ? parsed.predictions
        : []
    };
  } catch (error) {
    console.error(
      'Tahmin hafızası okunamadı, boş veritabanı kullanılacak:',
      error.message
    );

    return createEmptyDatabase();
  }
}

function writeDatabase(database) {
  ensureDatabaseDirectory();

  const nextDatabase = {
    version: 1,
    updatedAt: new Date().toISOString(),
    predictions: Array.isArray(database.predictions)
      ? database.predictions
      : []
  };

  const temporaryPath = `${databasePath}.tmp`;

  fs.writeFileSync(
    temporaryPath,
    JSON.stringify(nextDatabase, null, 2),
    'utf8'
  );

  fs.renameSync(temporaryPath, databasePath);

  return nextDatabase;
}

function createPredictionId() {
  return `prediction_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

function savePrediction(prediction) {
  const database = readDatabase();

  const record = {
    id: createPredictionId(),
    createdAt: new Date().toISOString(),
    status: 'pending',
    evaluatedAt: null,
    outcome: null,
    ...prediction
  };

  const identityKey = predictionIdentityKey(record);
  const existingIndex = database.predictions.findIndex(item =>
    item?.status === 'pending' &&
    predictionIdentityKey(item) === identityKey
  );

  if (identityKey && existingIndex >= 0) {
    const existing = database.predictions[existingIndex];
    database.predictions[existingIndex] = {
      ...existing,
      ...record,
      id: existing.id,
      createdAt: existing.createdAt,
      status: existing.status,
      evaluatedAt: existing.evaluatedAt ?? null,
      outcome: existing.outcome ?? null
    };
    writeDatabase(database);
    return database.predictions[existingIndex];
  }

  database.predictions.push(record);
  writeDatabase(database);

  return record;
}

function getPredictions() {
  return readDatabase().predictions;
}

function getPendingPredictions() {
  return getPredictions().filter(
    prediction => prediction.status === 'pending'
  );
}

function getDuePredictions(referenceTime = new Date()) {
  const now = referenceTime instanceof Date
    ? referenceTime
    : new Date(referenceTime);

  if (Number.isNaN(now.getTime())) {
    throw new Error('Geçersiz referans zamanı.');
  }

  return getPendingPredictions().filter(prediction => {
    const dueAt = new Date(prediction.dueAt);

    return !Number.isNaN(dueAt.getTime())
      && dueAt.getTime() <= now.getTime();
  });
}

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function firstValidPrice(...values) {
  for (const value of values) {
    const number = finiteNumber(value);

    if (number != null && number > 0) {
      return number;
    }
  }

  return null;
}

function determineDirection(analysis) {
  const technicalScore = finiteNumber(analysis?.technical?.score);

  if (technicalScore != null) {
    if (technicalScore >= 58) return 'rising';
    if (technicalScore <= 42) return 'falling';
    return 'stable';
  }

  const scenarios = Array.isArray(analysis?.scenarios)
    ? analysis.scenarios
    : [];

  const positive = scenarios.find(item =>
    /olumlu|pozitif|yükseliş/i.test(String(item?.name || ''))
  );

  const negative = scenarios.find(item =>
    /olumsuz|negatif|düşüş/i.test(String(item?.name || ''))
  );

  const positiveProbability = finiteNumber(positive?.probability) || 0;
  const negativeProbability = finiteNumber(negative?.probability) || 0;

  if (positiveProbability > negativeProbability + 5) return 'rising';
  if (negativeProbability > positiveProbability + 5) return 'falling';

  return 'stable';
}

function buildPredictionFromAnalysis(analysis) {
  if (!analysis || analysis.domain !== 'finance') {
    return null;
  }

  const entity = analysis.entity || {};
  const assetName = String(entity.name || '').trim();
  const assetSymbol = String(entity.symbol || '').trim();
  const assetIdentity = resolvePredictionAssetIdentity({
    query: analysis.query,
    assetName,
    assetSymbol,
    entity
  });

  if (!assetName && !assetSymbol) {
    return null;
  }

  const currentPrice = firstValidPrice(
    analysis.dailyPrice?.current,
    analysis.dailyPrice?.close,
    analysis.dailyPrice?.open
  );

  if (currentPrice == null) {
    return null;
  }

  const horizonDays = Math.max(
    1,
    Math.round(finiteNumber(analysis.period?.days) || 90)
  );

  const createdAt = new Date();
  const dueAt = new Date(
    createdAt.getTime() + horizonDays * 24 * 60 * 60 * 1000
  );

  return {
    query: String(analysis.query || '').trim(),
    asset: {
      name: assetName || assetSymbol,
      symbol: assetSymbol || null,
      subtype: entity.subtype || null,
      ...(assetIdentity.internalAssetId ? { internalAssetId: assetIdentity.internalAssetId } : {}),
      ...(assetIdentity.canonicalSymbol ? { canonicalSymbol: assetIdentity.canonicalSymbol } : {}),
      ...(assetIdentity.displayName ? { displayName: assetIdentity.displayName } : {}),
      ...(assetIdentity.assetType ? { assetType: assetIdentity.assetType } : {}),
      ...(assetIdentity.exchange ? { exchange: assetIdentity.exchange } : {}),
      ...(assetIdentity.currency ? { currency: assetIdentity.currency } : {})
    },
    horizonDays,
    dueAt: dueAt.toISOString(),
    prediction: {
      direction: determineDirection(analysis),
      confidence: Math.round(
        Math.max(0, Math.min(100, finiteNumber(analysis.confidence) || 0))
      ),
      currentPrice,
      estimatedLow: finiteNumber(analysis.estimatedRange?.low),
      estimatedMid: finiteNumber(analysis.estimatedRange?.mid),
      estimatedHigh: finiteNumber(analysis.estimatedRange?.high),
      currency: analysis.estimatedRange?.currency || null
    },
    technicalSnapshot: {
      score: finiteNumber(analysis.technical?.score),
      rsi14: finiteNumber(analysis.technical?.rsi14),
      macd: finiteNumber(analysis.technical?.macd),
      macdSignal: finiteNumber(analysis.technical?.macdSignal),
      macdHistogram: finiteNumber(analysis.technical?.macdHistogram),
      ema20: finiteNumber(analysis.technical?.ema20),
      ema50: finiteNumber(analysis.technical?.ema50),
      sma20: finiteNumber(analysis.technical?.sma20),
      sma50: finiteNumber(analysis.technical?.sma50),
      atrPercent: finiteNumber(analysis.technical?.atrPercent),
      volumeRatio: finiteNumber(analysis.technical?.volumeRatio)
    },
    statisticsSnapshot: {
      trendStrength: finiteNumber(analysis.statistics?.trendStrength),
      dataConfidence: finiteNumber(analysis.statistics?.dataConfidence),
      riskScore: finiteNumber(analysis.statistics?.riskScore),
      newsImpact: finiteNumber(analysis.statistics?.newsImpact),
      marketInterest: finiteNumber(analysis.statistics?.marketInterest)
    },
    scenarios: Array.isArray(analysis.scenarios)
      ? analysis.scenarios.slice(0, 3)
      : [],
    sourceUrls: Array.isArray(analysis.sources)
      ? analysis.sources
          .map(source => source?.url)
          .filter(url => typeof url === 'string' && /^https?:\/\//i.test(url))
          .slice(0, 10)
      : []
  };
}

function updatePredictionOutcome(predictionId, outcome) {
  const database = readDatabase();

  const prediction = database.predictions.find(
    item => item.id === predictionId
  );

  if (!prediction) {
    return null;
  }

  prediction.status = 'evaluated';
  prediction.evaluatedAt = new Date().toISOString();
  prediction.outcome = outcome || null;

  writeDatabase(database);

  return prediction;
}

module.exports = {
  buildPredictionFromAnalysis,
  savePrediction,
  getPredictions,
  getPendingPredictions,
  getDuePredictions,
  updatePredictionOutcome
};
