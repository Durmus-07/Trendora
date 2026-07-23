const { classifyQuestion } = require('./questionClassifier');
const { buildSourcePlan } = require('./sourceRouter');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
const { fetchMarketData } = require('./marketDataService');
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
    low: available && Number.isFinite(Number(range?.low)) ? Number(range.low) : null,
    mid: available && Number.isFinite(Number(range?.mid)) ? Number(range.mid) : null,
    high: available && Number.isFinite(Number(range?.high)) ? Number(range.high) : null,
    label: String(range?.label || (available ? 'Tahmini aralık' : 'Aralık hesaplanamadı')),
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

function numberOrNull(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function marketSentence(market) {
  const p = market?.dailyPrice;
  if (!p?.available) return '';
  const fmt = (value) => Number.isFinite(Number(value))
    ? Number(value).toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    : '-';
  const changeText = Number.isFinite(Number(p.changePercent))
    ? ` Günlük değişim %${fmt(p.changePercent)}.`
    : '';
  return `${market.displayName} için son fiyat ${fmt(p.current ?? p.close)} ${p.currency || ''}; açılış ${fmt(p.open)}, gün içi düşük ${fmt(p.low)}, yüksek ${fmt(p.high)} ve VWAP ${fmt(p.vwap)} seviyesindedir.${changeText}`;
}

function enrichWithMarketData(raw, market) {
  if (!market) return raw;

  const technicalScore = market.technical?.score ?? 50;
  const direction = market.technical?.direction || 'neutral';
  const marketConfidence = 72;
  const baseConfidence = numberOrNull(raw?.confidence) ?? 45;
  const confidence = Math.round(clamp((baseConfidence * 0.55) + (marketConfidence * 0.45), 0, 100));
  const summary = marketSentence(market);
  const directionText = direction === 'positive'
    ? 'Teknik görünüm kısa vadede olumlu eğilim gösteriyor.'
    : direction === 'negative'
      ? 'Teknik görünüm kısa vadede temkinli bir eğilim gösteriyor.'
      : 'Teknik görünüm kısa vadede dengeli ve kararsız seyrediyor.';

  const technicalSignals = [
    {
      type: direction,
      title: 'Canlı fiyat ve teknik görünüm',
      detail: `${directionText} Teknik skor ${technicalScore}/100.`,
      weight: technicalScore
    }
  ];

  if (market.technical?.rsi14 != null) {
    technicalSignals.push({
      type: market.technical.rsi14 > 70 ? 'negative' : market.technical.rsi14 >= 45 ? 'positive' : 'neutral',
      title: 'RSI (14)',
      detail: `RSI değeri ${market.technical.rsi14.toFixed(1)} seviyesinde.`,
      weight: Math.round(clamp(market.technical.rsi14, 0, 100))
    });
  }

  const existingSources = Array.isArray(raw?.sources) ? raw.sources : [];
  const existingFactors = Array.isArray(raw?.keyFactors) ? raw.keyFactors : [];
  const existingMissing = Array.isArray(raw?.missingInformation) ? raw.missingInformation : [];

  return {
    ...raw,
    answerTitle: raw?.answerTitle || `${market.displayName} finans değerlendirmesi`,
    directAnswer: `${directionText} ${summary}`.trim(),
    summary: raw?.summary && !String(raw.summary).includes('yalnızca açık haber')
      ? `${summary} ${raw.summary}`.trim()
      : summary,
    confidence,
    dailyPrice: market.dailyPrice,
    yearlyPrice: market.yearlyPrice,
    statistics: {
      ...(raw?.statistics || {}),
      trendStrength: technicalScore,
      dataConfidence: confidence,
      riskScore: Math.round(clamp(100 - technicalScore + 15, 0, 100)),
      newsImpact: numberOrNull(raw?.statistics?.newsImpact) ?? Math.round(clamp(baseConfidence, 0, 100)),
      marketInterest: market.technical?.volumeRatio != null
        ? Math.round(clamp(market.technical.volumeRatio * 50, 0, 100))
        : 50
    },
    signals: [...technicalSignals, ...(Array.isArray(raw?.signals) ? raw.signals : [])],
    keyFactors: [
      `Güncel fiyat: ${market.dailyPrice.current ?? market.dailyPrice.close} ${market.currency || ''}`,
      `Gün içi VWAP: ${market.dailyPrice.vwap ?? 'hesaplanamadı'}`,
      `RSI (14): ${market.technical?.rsi14?.toFixed?.(1) ?? 'hesaplanamadı'}`,
      `20/50/200 günlük ortalamalar: ${market.technical?.sma20?.toFixed?.(2) ?? '-'} / ${market.technical?.sma50?.toFixed?.(2) ?? '-'} / ${market.technical?.sma200?.toFixed?.(2) ?? '-'}`,
      ...existingFactors
    ],
    missingInformation: existingMissing.filter(item => !/fiyat|hacim|piyasa/i.test(String(item))),
    sources: [market.source, ...existingSources]
  };
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
    dailyPrice: cleanPriceBlock(raw?.dailyPrice, [
      'open', 'high', 'low', 'current', 'average', 'vwap', 'close',
      'previousClose', 'change', 'changePercent', 'volume'
    ]),
    yearlyPrice: cleanPriceBlock(raw?.yearlyPrice, ['low52w', 'average52w', 'high52w']),
    statistics: {
      trendStrength: Math.round(clamp(raw?.statistics?.trendStrength, 0, 100)),
      dataConfidence: Math.round(clamp(raw?.statistics?.dataConfidence ?? confidence, 0, 100)),
      riskScore: Math.round(clamp(raw?.statistics?.riskScore, 0, 100)),
      newsImpact: Math.round(clamp(raw?.statistics?.newsImpact, 0, 100)),
      marketInterest: Math.round(clamp(raw?.statistics?.marketInterest, 0, 100))
    },
    estimatedRange: cleanRange(raw?.estimatedRange),
    scenarios: normalizeScenarios(raw?.scenarios),
    confidence: Math.round(confidence),
    confidenceLabel: confidenceLabel(confidence),
    signals: Array.isArray(raw?.signals)
      ? raw.signals.slice(0, 10).map(item => ({
          type: ['positive', 'negative', 'neutral'].includes(item?.type) ? item.type : 'neutral',
          title: String(item?.title || 'Sinyal'),
          detail: String(item?.detail || ''),
          weight: Math.round(clamp(item?.weight, 0, 100))
        }))
      : [],
    keyFactors: Array.isArray(raw?.keyFactors) ? raw.keyFactors.map(String).slice(0, 10) : [],
    missingInformation: Array.isArray(raw?.missingInformation) ? raw.missingInformation.map(String).slice(0, 10) : [],
    nextChecks: Array.isArray(raw?.nextChecks) ? raw.nextChecks.map(String).slice(0, 10) : [],
    sources: cleanSources(raw?.sources),
    disclaimer: String(raw?.disclaimer || 'Bu sonuç mevcut açık verilerden üretilmiş olasılık analizidir; yatırım tavsiyesi değildir.')
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
    const base = webResult || buildFallbackAnalysis(cleanedQuery, classification, []);
    const enriched = enrichWithMarketData(base, marketData);
    const normalized = normalizeAnalysis(enriched, cleanedQuery, classification, sourcePlan);
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

  const fallback = normalizeAnalysis(
    buildFallbackAnalysis(cleanedQuery, classification, evidence),
    cleanedQuery,
    classification,
    sourcePlan
  );

  return {
    ...fallback,
    engine: {
      version: '4.0.0',
      mode: 'limited-fallback',
      usedLiveMarketData: false,
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
