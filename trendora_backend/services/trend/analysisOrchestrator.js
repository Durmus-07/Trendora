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

function cleanRange(range) {
  const available = Boolean(range?.available);

  return {
    available,
    currency: available ? String(range?.currency || 'TRY') : null,
    low: available && Number.isFinite(Number(range?.low))
      ? Number(range.low)
      : null,
    mid: available && Number.isFinite(Number(range?.mid))
      ? Number(range.mid)
      : null,
    high: available && Number.isFinite(Number(range?.high))
      ? Number(range.high)
      : null,
    label: String(
      range?.label ||
      (available ? 'Tahmini aralık' : 'Aralık hesaplanamadı')
    ),
    basis: String(range?.basis || '')
  };
}

function cleanPriceBlock(raw, keys) {
  const available = Boolean(raw?.available);
  const result = {
    available,
    currency: available ? String(raw?.currency || 'TRY') : null,
    date: raw?.date || null,
    source: raw?.source ? String(raw.source) : null
  };

  for (const key of keys) {
    result[key] = available && Number.isFinite(Number(raw?.[key]))
      ? Number(raw[key])
      : null;
  }

  return result;
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
    answerTitle: String(raw?.answerTitle || 'Trendora Analizi'),
    directAnswer: String(raw?.directAnswer || raw?.summary || ''),
    summary: String(raw?.summary || ''),
    dailyPrice: cleanPriceBlock(raw?.dailyPrice, ['open', 'average', 'close']),
    yearlyPrice: cleanPriceBlock(raw?.yearlyPrice, ['low52w', 'average52w', 'high52w']),
    estimatedRange: cleanRange(raw?.estimatedRange),
    scenarios: normalizeScenarios(raw?.scenarios),
    confidence: Math.round(confidence),
    confidenceLabel: confidenceLabel(confidence),
    signals: Array.isArray(raw?.signals)
      ? raw.signals.slice(0, 10).map(item => ({
          type: ['positive', 'negative', 'neutral'].includes(item?.type)
            ? item.type
            : 'neutral',
          title: String(item?.title || 'Sinyal'),
          detail: String(item?.detail || ''),
          weight: Math.round(clamp(item?.weight, 0, 100))
        }))
      : [],
    keyFactors: Array.isArray(raw?.keyFactors)
      ? raw.keyFactors.map(String).slice(0, 10)
      : [],
    missingInformation: Array.isArray(raw?.missingInformation)
      ? raw.missingInformation.map(String).slice(0, 10)
      : [],
    nextChecks: Array.isArray(raw?.nextChecks)
      ? raw.nextChecks.map(String).slice(0, 10)
      : [],
    sources: cleanSources(raw?.sources),
    disclaimer: String(
      raw?.disclaimer ||
      'Bu sonuç mevcut açık verilerden üretilmiş olasılık analizidir. Nihai karar kullanıcıya aittir.'
    )
  };
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
    webResult = await researchWithWeb(cleanedQuery, classification, sourcePlan);
  } catch (error) {
    webError = error;
    console.error('Trendora web araştırması başarısız:', error.message);
  }

  if (webResult || marketData) {
   const base = webResult || buildFallbackAnalysis(
  cleanedQuery,
  classification,
  []
);

if (marketData) {
  base.dailyPrice = marketData.dailyPrice;
  base.yearlyPrice = marketData.yearlyPrice;
  base.sources = [
    marketData.source,
    ...(base.sources || [])
  ];

  base.directAnswer =
    `${marketData.displayName} güncel fiyatı ${marketData.dailyPrice.current} ${marketData.currency}. ` +
    (base.directAnswer || '');

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
    version: '4.0.0',
    mode: marketData && webResult ? 'market-plus-web' : marketData ? 'market-data' : 'web-research',
    usedLiveMarketData: Boolean(marketData),
    usedLiveWebResearch: Boolean(webResult),
    entityRecognition: classification.entity?.found || false,
    generatedAt: new Date().toISOString()
  }
};
    return {
      ...normalized,
      engine: {
        version: '4.0.0',
        usedLiveMarketData: Boolean(marketData),
        mode: 'web-research',
        usedLiveWebResearch: true,
        entityRecognition: classification.entity?.found || false,
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
      version: '4.0.0',
      usedLiveMarketData: Boolean(marketData),
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
