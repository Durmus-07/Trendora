const express = require('express');
const fs = require('fs');
const path = require('path');
const environment = require('../config/environment');

const {
  analyzeQuery
} = require('../services/trendEngine');
const { classifyQuestion } = require('../services/trend/questionClassifier');
const { BIST_ENTITIES } = require('../services/trend/entityEngine');
const { fetchMarketData } = require('../services/marketDataService');
const { normalizeFinancial } = require('../services/dataModels');

const router = express.Router();
const MAX_QUERY_LENGTH = 500;
const CHART_LIMITS = { '1w': 5, '1m': 22, '3m': 66, '6m': 132, '1y': 260 };
let marketBoardCache = { createdAt: 0, value: null };

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

function mojibakeScore(value) {
  const matches = String(value || '').match(/[ÃÅÄÂâ]/g);
  return matches ? matches.length : 0;
}

function repairMojibakeString(value) {
  let current = String(value || '');

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const currentScore = mojibakeScore(current);
    if (currentScore === 0) break;

    const repaired = Buffer
      .from(current, 'latin1')
      .toString('utf8');

    if (
      repaired.includes('\uFFFD') ||
      mojibakeScore(repaired) >= currentScore
    ) {
      break;
    }

    current = repaired;
  }

  return current;
}

function repairMojibake(value) {
  if (typeof value === 'string') {
    return repairMojibakeString(value);
  }

  if (Array.isArray(value)) {
    return value.map(repairMojibake);
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(
        ([key, item]) => [key, repairMojibake(item)]
      )
    );
  }

  return value;
}

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

router.get('/chart', async (req, res) => {
  const query = String(req.query?.query || '').trim();
  const range = String(req.query?.range || '1y').toLowerCase();

  if (query.length < 2 || query.length > MAX_QUERY_LENGTH) {
    return res.status(400).json({
      success: false,
      message: 'Grafik için geçerli bir varlık veya sembol gerekli.'
    });
  }

  try {
    const classification = classifyQuestion(query);
    const marketData = await fetchMarketData(query, classification, {
      forceRefresh: String(req.query?.refresh || '') === '1'
    });
    const history = Array.isArray(marketData?.priceHistory)
      ? marketData.priceHistory
      : [];

    if (!history.length) {
      return res.status(404).json({
        success: false,
        code: 'CHART_DATA_UNAVAILABLE',
        message: 'Bu varlık için doğrulanmış piyasa grafiği bulunamadı.'
      });
    }

    const limit = CHART_LIMITS[range] || CHART_LIMITS['1y'];
    res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=60');
    return res.json({
      success: true,
      symbol: marketData.symbol,
      title: marketData.displayName,
      currency: marketData.currency,
      updatedAt: marketData.updatedAt,
      range: CHART_LIMITS[range] ? range : '1y',
      candles: history.slice(-limit)
    });
  } catch (error) {
    console.error('Grafik verisi alınamadı:', error?.message || error);
    return res.status(502).json({
      success: false,
      message: 'Piyasa veri kaynağına şu anda ulaşılamıyor.'
    });
  }
});

router.get('/market-board', async (req, res) => {
  if (marketBoardCache.value && Date.now() - marketBoardCache.createdAt < 2 * 60 * 1000) {
    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=120');
    return res.json({ ...marketBoardCache.value, cached: true });
  }
  const primaryInstruments = [
    ['Gram Altın', 'gram altın'], ['USD/TRY', 'dolar tl'], ['EUR/TRY', 'euro tl'],
    ['BIST 100', 'bist 100'], ['ASELS', 'ASELS'], ['THYAO', 'THYAO'],
    ['TUPRS', 'TUPRS'], ['GARAN', 'GARAN'], ['EREGL', 'EREGL'], ['BIMAS', 'BIMAS'],
    ['AKBNK', 'AKBNK'], ['KCHOL', 'KCHOL'], ['ISCTR', 'ISCTR'], ['SISE', 'SISE'],
    ['SAHOL', 'SAHOL'], ['PETKM', 'PETKM'], ['FROTO', 'FROTO'], ['TCELL', 'TCELL'],
    ['ENKAI', 'ENKAI'], ['YKBNK', 'YKBNK'], ['SASA', 'SASA'], ['PGSUS', 'PGSUS'],
    ['TOASO', 'TOASO'], ['TTKOM', 'TTKOM'], ['MGROS', 'MGROS'], ['VESTL', 'VESTL']
  ];
  const instrumentMap = new Map(primaryInstruments.map(item => [item[1], item]));
  for (const entity of BIST_ENTITIES) {
    if (!entity.symbol.endsWith('.S1')) instrumentMap.set(entity.symbol, [entity.symbol, entity.symbol]);
  }
  const instruments = [...instrumentMap.values()];
  try {
    const settled = await Promise.allSettled(instruments.map(async ([label, query]) => {
      const data = await fetchMarketData(query, classifyQuestion(query));
      const price = data?.dailyPrice?.current ?? data?.dailyPrice?.close;
      if (!Number.isFinite(Number(price))) return null;
      return normalizeFinancial({
        label,
        symbol: data.symbol,
        price: Number(price),
        changePercent: Number.isFinite(Number(data?.dailyPrice?.changePercent))
          ? Number(data.dailyPrice.changePercent) : null,
        currency: data.currency,
        updatedAt: data.updatedAt,
        technicalScore: data?.technical?.score != null && Number.isFinite(Number(data.technical.score)) ? Number(data.technical.score) : null,
        direction: data?.technical?.direction || 'neutral',
        rsi14: data?.technical?.rsi14 != null && Number.isFinite(Number(data.technical.rsi14)) ? Number(data.technical.rsi14) : null,
        atrPercent: data?.technical?.atrPercent != null && Number.isFinite(Number(data.technical.atrPercent)) ? Number(data.technical.atrPercent) : null,
        support: data?.technical?.support1 != null && Number.isFinite(Number(data.technical.support1)) ? Number(data.technical.support1) : null,
        resistance: data?.technical?.resistance1 != null && Number.isFinite(Number(data.technical.resistance1)) ? Number(data.technical.resistance1) : null,
        history: Array.isArray(data?.priceHistory)
          ? data.priceHistory.slice(-60).map(row => Number(row.close)).filter(Number.isFinite)
          : [],
        candles: Array.isArray(data?.priceHistory)
          ? data.priceHistory.slice(-60).map(row => ({
              date: row.date, open: row.open, high: row.high, low: row.low, close: row.close, volume: row.volume
            })).filter(row => Number.isFinite(Number(row.close)))
          : [],
        volume: data?.dailyPrice?.volume ?? null
      }, { source: 'Yahoo Finance', updatedAt: data.updatedAt });
    }));
    const items = settled.filter(x => x.status === 'fulfilled' && x.value).map(x => x.value);
    const value = { success: true, items, updatedAt: new Date().toISOString(), cached: false };
    marketBoardCache = { createdAt: Date.now(), value };
    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=120');
    return res.json(value);
  } catch (error) {
    return res.status(502).json({ success: false, message: 'Piyasa bandı şu anda güncellenemedi.' });
  }
});

/*
  Canlı kullanıcı sorusu korunur.
  Sadece genel trend özeti collector mimarisine taşındı.
*/
router.post('/analyze', async (req, res) => {
  if (!environment.analysisEnabled) {
    return res.status(503).json({
      success: false,
      code: 'ANALYSIS_DISABLED',
      message: 'İstatistiksel analiz motoru geçici olarak kullanılamıyor.'
    });
  }

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

    console.log('[TRENDS ANALYZE] Request received:', {
      query,
      receivedAt: new Date().toISOString()
    });

    const forceRefresh = [
      '1',
      'true',
      'yes'
    ].includes(
      String(
        req.body?.refresh || ''
      ).trim().toLowerCase()
    );

    const rawAnalysis = await analyzeQuery(
      query,
      { forceRefresh }
    );

    // Backend'in eski kayıtlarında oluşmuş UTF-8/Latin-1
    // karakter bozulmalarını yalnızca API cevabında güvenle düzeltir.
    // Analiz motoruna, cache'e veya kayıt dosyalarına müdahale etmez.
    const analysis = repairMojibake(rawAnalysis);

    res.set('Cache-Control', 'no-store');
    res.set('Content-Type', 'application/json; charset=utf-8');

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
    capabilities: {
      statisticalAnalysis: environment.analysisEnabled,
      liveMarketData: true,
      newsEvidence: true,
      ai: environment.aiEnabled,
      aiPremiumOnly: environment.aiPremiumOnly
    },
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