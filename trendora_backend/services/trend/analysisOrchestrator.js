const { classifyQuestion } = require('./questionClassifier');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
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

function normalizeAnalysis(raw, query, classification) {
  const confidence = clamp(raw?.confidence, 0, 100);

  return {
    query,
    domain: classification.domain,
    category: classification.label,
    intent: classification.intent,
    answerTitle: String(raw?.answerTitle || 'Trendora Analizi'),
    directAnswer: String(raw?.directAnswer || raw?.summary || ''),
    summary: String(raw?.summary || ''),
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

  if (cleanedQuery.length < 3) {
    const error = new Error('Analiz için en az 3 karakterlik bir soru yazmalısın.');
    error.statusCode = 400;
    throw error;
  }

  const classification = classifyQuestion(cleanedQuery);

  let webResult = null;
  let webError = null;

  try {
    webResult = await researchWithWeb(cleanedQuery, classification);
  } catch (error) {
    webError = error;
    console.error('Trendora web araştırması başarısız:', error.message);
  }

  if (webResult) {
    const normalized = normalizeAnalysis(
      webResult,
      cleanedQuery,
      classification
    );

    return {
      ...normalized,
      engine: {
        version: '2.0.0',
        mode: 'web-research',
        usedLiveWebResearch: true,
        generatedAt: new Date().toISOString()
      }
    };
  }

  let evidence = [];

  try {
    evidence = await collectNewsEvidence(cleanedQuery, 30);
  } catch (error) {
    console.error('Yedek haber kanıtları alınamadı:', error.message);
  }

  const fallback = normalizeAnalysis(
    buildFallbackAnalysis(cleanedQuery, classification, evidence),
    cleanedQuery,
    classification
  );

  return {
    ...fallback,
    engine: {
      version: '2.0.0',
      mode: 'limited-fallback',
      usedLiveWebResearch: false,
      webResearchError: webError ? webError.message : null,
      generatedAt: new Date().toISOString()
    }
  };
}

module.exports = {
  analyzeQuestion,
  normalizeAnalysis
};
