const { analyzeQuestion } = require('./trend/analysisOrchestrator');

const DEFAULT_QUESTIONS = [
  'Türkiye’de ikinci el otomobil fiyatlarında genel eğilim nedir?',
  'Gram altının kısa vadeli görünümü nasıl?',
  'Türkiye’de konut ve arsa piyasasının genel eğilimi nedir?',
  'Teknoloji ürünlerinde fiyatların düşme olasılığı var mı?'
];

const ANALYSIS_CACHE_TTL_MS = Number(
  process.env.TRENDORA_ANALYSIS_CACHE_TTL_MS || 10 * 60 * 1000
);
const OVERVIEW_CACHE_TTL_MS = Number(
  process.env.TRENDORA_OVERVIEW_CACHE_TTL_MS || 10 * 60 * 1000
);
const MAX_ANALYSIS_CACHE_ITEMS = Number(
  process.env.TRENDORA_ANALYSIS_CACHE_MAX_ITEMS || 100
);

const analysisCache = new Map();
const inFlightAnalyses = new Map();
let overviewCache = null;
let overviewInFlight = null;

function normalizeCacheKey(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ');
}

function isFresh(entry, ttlMs) {
  return Boolean(
    entry &&
    Number.isFinite(entry.createdAt) &&
    Date.now() - entry.createdAt < ttlMs
  );
}

function pruneAnalysisCache() {
  const now = Date.now();

  for (const [key, entry] of analysisCache.entries()) {
    if (!entry || now - entry.createdAt >= ANALYSIS_CACHE_TTL_MS) {
      analysisCache.delete(key);
    }
  }

  if (analysisCache.size <= MAX_ANALYSIS_CACHE_ITEMS) return;

  const oldest = [...analysisCache.entries()]
    .sort((a, b) => a[1].createdAt - b[1].createdAt)
    .slice(0, analysisCache.size - MAX_ANALYSIS_CACHE_ITEMS);

  for (const [key] of oldest) analysisCache.delete(key);
}

async function analyzeQuery(query, options = {}) {
  const cleanedQuery = String(query || '').trim();
  const key = normalizeCacheKey(cleanedQuery);
  const forceRefresh = options.forceRefresh === true;

  if (!forceRefresh) {
    const cached = analysisCache.get(key);
    if (isFresh(cached, ANALYSIS_CACHE_TTL_MS)) {
      console.log('[TREND ENGINE] Cache hit:', { query: cleanedQuery });
      return {
        ...cached.value,
        engine: {
          ...(cached.value.engine || {}),
          cache: 'hit'
        }
      };
    }

    if (inFlightAnalyses.has(key)) {
      console.log('[TREND ENGINE] Existing analysis awaited:', { query: cleanedQuery });
      return inFlightAnalyses.get(key);
    }
  }

  console.log('[TREND ENGINE] Fresh analysis started:', {
    query: cleanedQuery,
    forceRefresh
  });

  const task = analyzeQuestion(cleanedQuery)
    .then(result => {
      analysisCache.set(key, {
        createdAt: Date.now(),
        value: result
      });
      pruneAnalysisCache();
      return {
        ...result,
        engine: {
          ...(result.engine || {}),
          cache: 'miss'
        }
      };
    })
    .finally(() => {
      inFlightAnalyses.delete(key);
    });

  inFlightAnalyses.set(key, task);
  return task;
}

async function buildTrendOverview() {
  const results = await Promise.allSettled(
    DEFAULT_QUESTIONS.map(question => analyzeQuery(question))
  );

  const trends = results
    .filter(result => result.status === 'fulfilled')
    .map(result => result.value);

  return {
    updatedAt: new Date().toISOString(),
    methodology: {
      version: '2.1.0',
      title: 'Trendora Karar Destek Motoru',
      description:
        'Soruyu alanına ve niyetine göre sınıflandırır; canlı web araştırması, ' +
        'kaynak karşılaştırması, piyasa verisi, senaryo olasılıkları, güven puanı, ' +
        'olumlu sinyaller, riskler ve eksik bilgiler üretir. Aynı sorgular kısa ' +
        'süreli önbellekle sunucu yükü artırılmadan tekrar kullanılabilir.'
    },
    trends
  };
}

async function getTrendOverview(options = {}) {
  const forceRefresh = options.forceRefresh === true;

  if (!forceRefresh && isFresh(overviewCache, OVERVIEW_CACHE_TTL_MS)) {
    return {
      ...overviewCache.value,
      cache: 'hit'
    };
  }

  if (!forceRefresh && overviewInFlight) return overviewInFlight;

  overviewInFlight = buildTrendOverview()
    .then(result => {
      overviewCache = {
        createdAt: Date.now(),
        value: result
      };
      return {
        ...result,
        cache: 'miss'
      };
    })
    .finally(() => {
      overviewInFlight = null;
    });

  return overviewInFlight;
}

module.exports = {
  analyzeQuery,
  getTrendOverview
};
