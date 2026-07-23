const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
const { fetchMarketData } = require('../marketDataService');
const { classifyQuestion } = require('./questionClassifier');
const { buildSourcePlan } = require('./sourceRouter');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const {
  clamp,
  normalizeScenarios,
  confidenceLabel
} = require('./probabilityEngine');

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function positivePrice(value) {
  const number = finiteNumber(value);
  return number != null && number > 0 ? number : null;
}

function nonNegativeNumber(value) {
  const number = finiteNumber(value);
  return number != null && number >= 0 ? number : null;
}

function cleanRange(range) {
  const low = positivePrice(range?.low);
  const mid = positivePrice(range?.mid);
  const high = positivePrice(range?.high);
  const available = Boolean(range?.available) &&
    [low, mid, high].some(value => value != null);

  return {
    available,
    currency: available ? String(range?.currency || 'TRY') : null,
    low: available ? low : null,
    mid: available ? mid : null,
    high: available ? high : null,
    label: String(
      range?.label ||
      (available ? 'Tahmini aralık' : 'Aralık hesaplanamadı')
    ),
    basis: String(range?.basis || '')
  };
}

function cleanPriceBlock(raw, keys, priceKeys = []) {
  const result = {
    available: false,
    currency: null,
    date: raw?.date || null,
    source: raw?.source ? String(raw.source) : null
  };

  let hasValue = false;

  for (const key of keys) {
    let value;

    if (priceKeys.includes(key)) {
      value = positivePrice(raw?.[key]);
    } else if (key === 'volume') {
      value = nonNegativeNumber(raw?.[key]);
    } else {
      value = finiteNumber(raw?.[key]);
    }

    result[key] = value;
    if (value != null) hasValue = true;
  }

  result.available = Boolean(raw?.available) && hasValue;
  result.currency = result.available
    ? String(raw?.currency || 'TRY')
    : null;

  return result;
}

function cleanTechnical(raw) {
  if (!raw || typeof raw !== 'object') return {};

  const keys = [
    'rsi14',
    'sma20',
    'sma50',
    'sma200',
    'volumeRatio',
    'changePercent',
    'ema20',
    'ema50',
    'ema100',
    'ema200',
    'macd',
    'macdSignal',
    'macdHistogram',
    'atr14',
    'atrPercent',
    'support1',
    'support2',
    'resistance1',
    'resistance2',
    'score'
  ];

  const result = {};

  for (const key of keys) {
    const value = finiteNumber(raw?.[key]);
    result[key] = value;
  }

  result.direction = ['positive', 'negative', 'neutral'].includes(raw?.direction)
    ? raw.direction
    : 'neutral';

  return result;
}

function cleanStatistics(raw) {
  const source = raw && typeof raw === 'object' ? raw : {};

  return {
    trendStrength: finiteNumber(source.trendStrength),
    dataConfidence: finiteNumber(source.dataConfidence),
    riskScore: finiteNumber(source.riskScore),
    newsImpact: finiteNumber(source.newsImpact),
    marketInterest: finiteNumber(source.marketInterest)
  };
}

function cleanSources(sources) {
  if (!Array.isArray(sources)) return [];

  const seen = new Set();

  return sources
    .map(item => ({
      title: String(item?.title || 'Kaynak'),
      publisher: String(item?.publisher || item?.source || 'Bilinmeyen kaynak'),
      url: String(item?.url || item?.link || ''),
      publishedAt: item?.publishedAt || null,
      evidenceType: String(item?.evidenceType || 'web')
    }))
    .filter(item => {
      if (!item.url || !/^https?:\/\//i.test(item.url)) return false;
      if (seen.has(item.url)) return false;
      seen.add(item.url);
      return true;
    })
    .slice(0, 12);
}

function cleanText(value) {
  return String(value || '')
    .replace(/```(?:json)?/gi, '')
    .replace(/\*\*/g, '')
    .trim();
}

function normalizeAnalysis(raw, query, classification, sourcePlan) {
  const confidence = clamp(raw?.confidence, 0, 100);

  return {
    query,
    domain: classification.domain,
    category: classification.label,
    intent: classification.intent,
    period: classification.period,
    entity: classification.entity,
    sourcePlan,
    answerTitle: cleanText(raw?.answerTitle || 'Trendora Analizi'),
    directAnswer: cleanText(raw?.directAnswer || raw?.summary || ''),
    summary: cleanText(raw?.summary || ''),
    dailyPrice: cleanPriceBlock(
      raw?.dailyPrice,
      [
        'current',
        'open',
        'high',
        'low',
        'average',
        'vwap',
        'close',
        'previousClose',
        'change',
        'changePercent',
        'volume'
      ],
      [
        'current',
        'open',
        'high',
        'low',
        'average',
        'vwap',
        'close',
        'previousClose'
      ]
    ),
    yearlyPrice: cleanPriceBlock(
      raw?.yearlyPrice,
      ['low52w', 'average52w', 'high52w'],
      ['low52w', 'average52w', 'high52w']
    ),
    estimatedRange: cleanRange(raw?.estimatedRange),
    technical: cleanTechnical(raw?.technical),
    statistics: cleanStatistics(raw?.statistics),
    scenarios: normalizeScenarios(raw?.scenarios),
    confidence: Math.round(confidence),
    confidenceLabel: confidenceLabel(confidence),
    signals: Array.isArray(raw?.signals)
      ? raw.signals.slice(0, 10).map(item => ({
          type: ['positive', 'negative', 'neutral'].includes(item?.type)
            ? item.type
            : 'neutral',
          title: cleanText(item?.title || 'Sinyal'),
          detail: cleanText(item?.detail || ''),
          weight: Math.round(clamp(item?.weight, 0, 100))
        }))
      : [],
    keyFactors: Array.isArray(raw?.keyFactors)
      ? raw.keyFactors.map(cleanText).filter(Boolean).slice(0, 10)
      : [],
    missingInformation: Array.isArray(raw?.missingInformation)
      ? raw.missingInformation.map(cleanText).filter(Boolean).slice(0, 10)
      : [],
    nextChecks: Array.isArray(raw?.nextChecks)
      ? raw.nextChecks.map(cleanText).filter(Boolean).slice(0, 10)
      : [],
    sources: cleanSources(raw?.sources),
    disclaimer: cleanText(
      raw?.disclaimer ||
      'Bu sonuç mevcut açık verilerden üretilmiş olasılık analizidir. Nihai karar kullanıcıya aittir.'
    )
  };
}

function firstValidPrice(...values) {
  for (const value of values) {
    const number = positivePrice(value);
    if (number != null) return number;
  }
  return null;
}

function formatMarketPrice(value, currency) {
  const number = positivePrice(value);
  if (number == null) return null;

  return `${number.toLocaleString('tr-TR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  })} ${currency || 'TRY'}`;
}

async function analyzeQuestion(query) {
  const cleanedQuery = String(query || '').trim();

  if (cleanedQuery.length < 2) {
    const error = new Error('Analiz için en az 2 karakterlik bir soru yazmalısın.');
    error.statusCode = 400;
    throw error;
  }

  const classification = classifyQuestion(cleanedQuery);
  const sourcePlan = buildSourcePlan(classification);

  let marketData = null;

  if (classification.domain === 'finance') {
    try {
      marketData = await fetchMarketData(cleanedQuery, classification);
    } catch (error) {
      console.error('Canlı piyasa verisi alınamadı:', error.message);
    }
  }

  let webResult = null;
  let webError = null;

  try {
    webResult = await researchWithWeb(
      cleanedQuery,
      classification,
      sourcePlan
    );
  } catch (error) {
    webError = error;
    console.error('Trendora web araştırması başarısız:', error.message);
  }

  if (webResult || marketData) {
    const base = webResult
      ? {
          ...webResult,
          dailyPrice: { ...(webResult.dailyPrice || {}) },
          yearlyPrice: { ...(webResult.yearlyPrice || {}) },
          estimatedRange: { ...(webResult.estimatedRange || {}) },
          technical: { ...(webResult.technical || {}) },
          statistics: { ...(webResult.statistics || {}) },
          sources: [...(webResult.sources || [])]
        }
      : buildFallbackAnalysis(
          cleanedQuery,
          classification,
          []
        );

    if (marketData) {
      const marketCurrent = firstValidPrice(
        marketData.dailyPrice?.current,
        marketData.dailyPrice?.close,
        marketData.dailyPrice?.open,
        marketData.dailyPrice?.vwap,
        marketData.dailyPrice?.average
      );

      base.dailyPrice = {
        ...(marketData.dailyPrice || {}),
        current: marketCurrent,
        close: firstValidPrice(
          marketData.dailyPrice?.close,
          marketCurrent
        )
      };

      base.yearlyPrice = {
        ...(marketData.yearlyPrice || {})
      };

      base.technical = {
        ...(base.technical || {}),
        ...(marketData.technical || {})
      };

      base.sources = [
        marketData.source,
        ...(base.sources || [])
      ].filter(Boolean);

      const displayedPrice = formatMarketPrice(
        marketCurrent,
        marketData.currency
      );

      if (displayedPrice) {
        base.directAnswer =
          `${marketData.displayName} güncel fiyatı ${displayedPrice}. ` +
          (base.directAnswer || '');
      }

      base.summary =
        `${marketData.displayName} için canlı piyasa verisi başarıyla alındı. ` +
        (base.summary || '');
    }

    const normalized = normalizeAnalysis(
      base,
      cleanedQuery,
      classification,
      sourcePlan
    );

    return {
      ...normalized,
      engine: {
        version: '4.0.1',
        mode: marketData && webResult
          ? 'market-plus-web'
          : marketData
            ? 'market-data'
            : 'web-research',
        usedLiveMarketData: Boolean(marketData),
        usedLiveWebResearch: Boolean(webResult),
        entityRecognition: classification.entity?.found || false,
        webResearchError: webError ? webError.message : null,
        generatedAt: new Date().toISOString()
      }
    };
  }

  let evidence = [];
  const evidenceQuery = classification.entity?.found
    ? `${classification.entity.name} ${classification.entity.symbol || ''}`.trim()
    : cleanedQuery;

  try {
    evidence = await collectNewsEvidence(evidenceQuery, 30);
  } catch (error) {
    console.error('Yedek haber kanıtları alınamadı:', error.message);
  }

  const fallbackRaw = buildFallbackAnalysis(
    cleanedQuery,
    classification,
    evidence
  );

  const fallback = normalizeAnalysis(
    {
      ...fallbackRaw,
      dailyPrice: { available: false },
      yearlyPrice: { available: false }
    },
    cleanedQuery,
    classification,
    sourcePlan
  );

  return {
    ...fallback,
    engine: {
      version: '4.0.1',
      usedLiveMarketData: false,
      mode: 'limited-fallback',
      usedLiveWebResearch: false,
      entityRecognition: classification.entity?.found || false,
      webResearchError: webError ? webError.message : null,
      generatedAt: new Date().toISOString()
    }
  };
}

module.exports = {
  analyzeQuestion,
  normalizeAnalysis
};