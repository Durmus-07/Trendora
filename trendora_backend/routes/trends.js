const express = require('express');
const fs = require('fs');
const path = require('path');

const {
  analyzeQuery
} = require('../services/trendEngine');

const router = express.Router();
const MAX_QUERY_LENGTH = 500;

const TRENDS_DATABASE_FILE = path.join(
  __dirname,
  '..',
  'database',
  'trends_database.json'
);

const TRENDS_STATUS_FILE = path.join(
  __dirname,
  '..',
  'database',
  'trends_status.json'
);

function readJsonFile(filePath, fallbackValue) {
  try {
    if (!fs.existsSync(filePath)) {
      return fallbackValue;
    }

    const raw = fs.readFileSync(
      filePath,
      'utf8'
    );

    return JSON.parse(raw);
  } catch (error) {
    console.error(
      `[TRENDS API] ${path.basename(filePath)} okunamadı:`,
      error?.message || error
    );

    return fallbackValue;
  }
}

function readTrendDatabase() {
  const data = readJsonFile(
    TRENDS_DATABASE_FILE,
    null
  );

  if (!data || !Array.isArray(data.trends)) {
    return {
      ready: false,
      createdAt: 0,
      updatedAt: null,
      methodology: null,
      trendCount: 0,
      trends: []
    };
  }

  return {
    ready: true,
    createdAt: Number(data.createdAt || 0),
    updatedAt: data.updatedAt || null,
    methodology: data.methodology || null,
    trendCount: Number(
      data.trendCount || data.trends.length
    ),
    trends: data.trends
  };
}

function getCollectorStatus() {
  return readJsonFile(
    TRENDS_STATUS_FILE,
    {
      running: false,
      phase: 'not_started',
      completedAt: null,
      error: null
    }
  );
}

/*
  GET /api/trends artık canlı analiz başlatmaz.
  Hazır trends_database.json dosyasını anında döndürür.
*/
router.get('/', (req, res) => {
  try {
    const database = readTrendDatabase();
    const collector = getCollectorStatus();

    res.set('Cache-Control', 'no-store');

    return res.json({
      success: true,
      ready: database.ready,
      message: database.ready
        ? 'Trendora trend özeti hazır.'
        : 'Trend collector ilk analizi henüz tamamlamadı.',
      updatedAt: database.updatedAt,
      methodology: database.methodology,
      trendCount: database.trends.length,
      trends: database.trends,
      cache: 'disk',
      collector: {
        running: collector.running === true,
        phase: collector.phase || 'unknown',
        completedAt: collector.completedAt || null,
        error: collector.error || null
      }
    });
  } catch (error) {
    console.error(
      'Trend özeti okunamadı:',
      error?.message || error
    );

    return res.status(500).json({
      success: false,
      message:
        'Trend özeti şu anda okunamadı.',
      error:
        process.env.NODE_ENV === 'development'
          ? error?.message
          : undefined
    });
  }
});

/*
  Canlı kullanıcı sorusu korunur.
  Sadece genel trend özeti collector mimarisine taşındı.
*/
router.post('/analyze', async (req, res) => {
  try {
    const query = String(
      req.body?.query ||
      req.body?.question ||
      req.body?.message ||
      ''
    ).trim();

    if (query.length < 2) {
      return res.status(400).json({
        success: false,
        message:
          'Analiz için en az 2 karakterlik bir soru yazmalısın.'
      });
    }

    if (query.length > MAX_QUERY_LENGTH) {
      return res.status(400).json({
        success: false,
        message:
          `Analiz sorusu en fazla ${MAX_QUERY_LENGTH} karakter olabilir.`
      });
    }

    const forceRefresh = [
      '1',
      'true',
      'yes'
    ].includes(
      String(
        req.body?.refresh || ''
      ).trim().toLowerCase()
    );

    const analysis = await analyzeQuery(
      query,
      { forceRefresh }
    );

    res.set('Cache-Control', 'no-store');

    return res.json({
      success: true,
      updatedAt: new Date().toISOString(),
      analysis
    });
  } catch (error) {
    console.error(
      'Trend analizi oluşturulamadı:',
      error?.message || error
    );

    return res
      .status(error.statusCode || 500)
      .json({
        success: false,
        message:
          error.statusCode === 400
            ? error.message
            : 'Analiz şu anda oluşturulamadı.',
        error: error.message
      });
  }
});

router.get('/health', (req, res) => {
  const database = readTrendDatabase();
  const collector = getCollectorStatus();

  res.set('Cache-Control', 'no-store');

  res.json({
    success: true,
    service: 'Trendora Trend Collector',
    ready: database.ready,
    trendCount: database.trends.length,
    updatedAt: database.updatedAt,
    collector
  });
});

async function getTrendStatus() {
  const database = readTrendDatabase();
  const collector = getCollectorStatus();

  return {
    trends: database.trends,
    trendCount: database.trends.length,
    updatedAt: database.updatedAt,
    ready: database.ready,
    fromCache: true,
    collectorRunning:
      collector.running === true,
    collectorPhase:
      collector.phase || 'unknown',
    error:
      database.ready
        ? null
        : collector.error || null
  };
}

module.exports = router;
module.exports.getTrendStatus = getTrendStatus;
