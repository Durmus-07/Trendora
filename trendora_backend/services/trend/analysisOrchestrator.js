const {
  buildPredictionFromAnalysis,
  savePrediction
} = require('./predictionMemoryService');
const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
const { fetchMarketData } = require('../marketDataService');
const { classifyQuestion } = require('./questionClassifier');
const { getUniverse } = require('./universeService');
const pLimit = require('p-limit');
const { buildSourcePlan } = require('./sourceRouter');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const { clamp, normalizeScenarios, confidenceLabel } = require('./probabilityEngine');
const { analyzeEvidence, sourceWeight, getHostname } = require('./evidenceAnalyzer');
const { buildTechnicalPlan, buildPlanSignals } = require('./technicalLevelEngine');
const environment = require('../../config/environment');

const WEB_TIMEOUT_MS = Number(process.env.TRENDORA_WEB_TIMEOUT_MS || 10000);
const FALLBACK_NEWS_TIMEOUT_MS = Number(process.env.TRENDORA_FALLBACK_NEWS_TIMEOUT_MS || 6500);

function finiteNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}
function positivePrice(value) {
  const n = finiteNumber(value);
  return n != null && n > 0 ? n : null;
}
function nonNegativeNumber(value) {
  const n = finiteNumber(value);
  return n != null && n >= 0 ? n : null;
}
function cleanText(value) {
  return String(value || '').replace(/```(?:json)?/gi, '').replace(/\*\*/g, '').trim();
}
function withTimeout(promise, timeoutMs, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} ${timeoutMs} ms iÃ§inde tamamlanamadÄ±.`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}
function cleanRange(range) {
  const low = positivePrice(range?.low);
  const mid = positivePrice(range?.mid);
  const high = positivePrice(range?.high);
  const available = Boolean(range?.available) && [low, mid, high].some(v => v != null);
  return { available, currency: available ? String(range?.currency || 'TRY') : null, low: available ? low : null, mid: available ? mid : null, high: available ? high : null, label: String(range?.label || (available ? 'Tahmini aralÄ±k' : 'AralÄ±k hesaplanamadÄ±')), basis: String(range?.basis || '') };
}
function cleanPriceBlock(raw, keys, priceKeys = []) {
  const result = { available: false, currency: null, date: raw?.date || null, source: raw?.source ? String(raw.source) : null };
  let hasValue = false;
  for (const key of keys) {
    let value;
    if (priceKeys.includes(key)) value = positivePrice(raw?.[key]);
    else if (key === 'volume') value = nonNegativeNumber(raw?.[key]);
    else value = finiteNumber(raw?.[key]);
    result[key] = value;
    if (value != null) hasValue = true;
  }
  result.available = Boolean(raw?.available) && hasValue;
  result.currency = result.available ? String(raw?.currency || 'TRY') : null;
  return result;
}
function cleanTechnical(raw) {
  if (!raw || typeof raw !== 'object') return {};
  const keys = ['currentPrice','rsi14','sma','sma20','sma50','sma100','sma200','volumeRatio','changePercent','ema20','ema50','ema100','ema200','macd','macdSignal','macdHistogram','bollingerUpper','bollingerMiddle','bollingerLower','atr14','atrPercent','support1','support2','resistance1','resistance2','technicalScore','score','confidenceScore','dataPointCount'];
  const result = {};
  for (const key of keys) result[key] = finiteNumber(raw?.[key]);
  result.direction = ['positive','negative','neutral'].includes(raw?.direction) ? raw.direction : 'neutral';
  result.assetSymbol = raw?.assetSymbol ? String(raw.assetSymbol) : null;
  result.dataTime = raw?.dataTime ? String(raw.dataTime) : null;
  const trendLabels = ['GÃ¼Ã§lÃ¼ YÃ¼kseliÅŸ','YÃ¼kseliÅŸ','Yatay','DÃ¼ÅŸÃ¼ÅŸ','GÃ¼Ã§lÃ¼ DÃ¼ÅŸÃ¼ÅŸ','Veri Yetersiz'];
  for (const key of ['shortTermTrend','mediumTermTrend','longTermTrend']) {
    result[key] = trendLabels.includes(raw?.[key]) ? raw[key] : 'Veri Yetersiz';
  }
  const confidenceLabels = ['Ã‡ok YÃ¼ksek','YÃ¼ksek','Orta','DÃ¼ÅŸÃ¼k','Veri Yetersiz'];
  result.confidenceLevel = confidenceLabels.includes(raw?.confidenceLevel)
    ? raw.confidenceLevel
    : 'Veri Yetersiz';
  result.supportLevels = Array.isArray(raw?.supportLevels)
    ? raw.supportLevels.map(finiteNumber).filter(Number.isFinite).slice(0, 4)
    : [];
  result.resistanceLevels = Array.isArray(raw?.resistanceLevels)
    ? raw.resistanceLevels.map(finiteNumber).filter(Number.isFinite).slice(0, 4)
    : [];
  result.scoreContributions = Object.fromEntries(
    Object.entries(raw?.scoreContributions || {})
      .map(([key, value]) => [key, finiteNumber(value)])
      .filter(([, value]) => value != null)
  );
  result.dataSufficiency = raw?.dataSufficiency && typeof raw.dataSufficiency === 'object'
    ? {
        status: ['sufficient','partial','insufficient'].includes(raw.dataSufficiency.status)
          ? raw.dataSufficiency.status : 'insufficient',
        label: String(raw.dataSufficiency.label || 'Yetersiz'),
        available: Math.max(0, Math.round(finiteNumber(raw.dataSufficiency.available) || 0)),
        required: Math.max(0, Math.round(finiteNumber(raw.dataSufficiency.required) || 0)),
        missingIndicators: Array.isArray(raw.dataSufficiency.missingIndicators)
          ? raw.dataSufficiency.missingIndicators.map(String).slice(0, 20) : []
      }
    : { status: 'insufficient', label: 'Yetersiz', available: 0, required: 0, missingIndicators: [] };
  result.integration = {
    technicalSnapshotId: String(raw?.integration?.technicalSnapshotId || ''),
    newsImpactReady: raw?.integration?.newsImpactReady === true,
    newsImpactIncluded: raw?.integration?.newsImpactIncluded === true
  };
  return result;
}
function cleanStatistics(raw) {
  const s = raw && typeof raw === 'object' ? raw : {};
  return { trendStrength: finiteNumber(s.trendStrength), dataConfidence: finiteNumber(s.dataConfidence), riskScore: finiteNumber(s.riskScore), newsImpact: finiteNumber(s.newsImpact), marketInterest: finiteNumber(s.marketInterest) };
}
function cleanSources(sources) {
  if (!Array.isArray(sources)) return [];
  const seen = new Set();
  return sources.map(item => {
    const url = String(item?.url || item?.link || '');
    const credibility = Math.round(clamp(item?.credibility ?? sourceWeight({ ...item, url }), 0, 100));
    const hostname = getHostname(url);
    return {
      title: String(item?.title || 'Kaynak'),
      publisher: String(item?.publisher || item?.source || hostname || 'Bilinmeyen kaynak'),
      url,
      publishedAt: item?.publishedAt || null,
      evidenceType: String(item?.evidenceType || 'web'),
      credibility,
      isOfficial: credibility >= 95
    };
  })
    .filter(item => item.url && /^https?:\/\//i.test(item.url) && !seen.has(item.url) && seen.add(item.url))
    .sort((a, b) => b.credibility - a.credibility)
    .slice(0, 16);
}
function normalizeAnalysis(raw, query, classification, sourcePlan) {
  const confidence = clamp(raw?.confidence, 0, 100);
  return {
    query, domain: classification.domain, category: classification.label, intent: classification.intent,
    period: classification.period, entity: classification.entity, sourcePlan,
    answerTitle: cleanText(raw?.answerTitle || 'Trendora Analizi'),
    directAnswer: cleanText(raw?.directAnswer || raw?.summary || ''), summary: cleanText(raw?.summary || ''),
    dailyPrice: cleanPriceBlock(raw?.dailyPrice, ['current','open','high','low','average','vwap','close','previousClose','change','changePercent','volume'], ['current','open','high','low','average','vwap','close','previousClose']),
    yearlyPrice: cleanPriceBlock(raw?.yearlyPrice, ['low52w','average52w','high52w'], ['low52w','average52w','high52w']),
    estimatedRange: cleanRange(raw?.estimatedRange), technical: cleanTechnical(raw?.technical), statistics: cleanStatistics(raw?.statistics),
    technicalPlan: raw?.technicalPlan && typeof raw.technicalPlan === 'object' ? raw.technicalPlan : { available: false },
    scenarios: normalizeScenarios(raw?.scenarios), confidence: Math.round(confidence), confidenceLabel: confidenceLabel(confidence),
    signals: Array.isArray(raw?.signals) ? raw.signals.slice(0, 10).map(item => ({ type: ['positive','negative','neutral'].includes(item?.type) ? item.type : 'neutral', title: cleanText(item?.title || 'Sinyal'), detail: cleanText(item?.detail || ''), weight: Math.round(clamp(item?.weight, 0, 100)) })) : [],
    keyFactors: Array.isArray(raw?.keyFactors) ? raw.keyFactors.map(cleanText).filter(Boolean).slice(0,10) : [],
    missingInformation: Array.isArray(raw?.missingInformation) ? raw.missingInformation.map(cleanText).filter(Boolean).slice(0,10) : [],
    nextChecks: Array.isArray(raw?.nextChecks) ? raw.nextChecks.map(cleanText).filter(Boolean).slice(0,10) : [],
    sources: cleanSources(raw?.sources),
    disclaimer: cleanText(raw?.disclaimer || 'Bu sonuÃ§ mevcut aÃ§Ä±k verilerden Ã¼retilmiÅŸ olasÄ±lÄ±k analizidir. YatÄ±rÄ±m tavsiyesi deÄŸildir.')
  };
}
function firstValidPrice(...values) {
  for (const value of values) { const n = positivePrice(value); if (n != null) return n; }
  return null;
}
function fmt(value, currency='TRY') {
  const n = positivePrice(value); if (n == null) return null;
  return `${n.toLocaleString('tr-TR',{maximumFractionDigits:2})} ${currency}`;
}
function horizonDays(classification) {
  return Math.max(1, finiteNumber(classification?.period?.days) || 90);
}
function buildMarketScenarios(marketData, classification) {
  const current = firstValidPrice(marketData?.dailyPrice?.current, marketData?.dailyPrice?.close);
  if (!current) return null;
  const days = horizonDays(classification);
  const atrPct = Math.max(0.8, Math.min(8, finiteNumber(marketData?.technical?.atrPercent) || 2.5));
  const timeScale = Math.sqrt(days / 14);
  const expectedMove = Math.min(0.38, (atrPct / 100) * timeScale);
  const score = finiteNumber(marketData?.technical?.score) ?? 50;
  const bias = Math.max(-0.12, Math.min(0.12, (score - 50) / 250));
  const center = current * (1 + bias);
  const low = center * (1 - expectedMove);
  const high = center * (1 + expectedMove);
  const pos = Math.round(clamp(33 + (score - 50) * 0.45, 18, 58));
  const neg = Math.round(clamp(33 - (score - 50) * 0.35, 18, 52));
  const neutral = 100 - pos - neg;
  const currency = marketData.currency || 'TRY';
  return {
    estimatedRange: { available: true, currency, low, mid: center, high, label: `${classification.period?.label || '3 Ay'} olasÄ± fiyat bandÄ±`, basis: `ATR oynaklÄ±ÄŸÄ±, teknik skor ve ${days} gÃ¼nlÃ¼k zaman Ã¶lÃ§eÄŸi kullanÄ±ldÄ±.` },
    scenarios: normalizeScenarios([
      { name: 'Olumlu gÃ¶rÃ¼nÃ¼m', probability: pos, description: `Teknik sinyaller gÃ¼Ã§lenirse yaklaÅŸÄ±k ${fmt(center, currency)} - ${fmt(high, currency)} bandÄ±.` },
      { name: 'Dengeli gÃ¶rÃ¼nÃ¼m', probability: neutral, description: `Ana senaryoda yaklaÅŸÄ±k ${fmt(low * 1.04, currency)} - ${fmt(high * 0.96, currency)} bandÄ±nda dalgalanma.` },
      { name: 'Olumsuz gÃ¶rÃ¼nÃ¼m', probability: neg, description: `Riskler Ã¶ne Ã§Ä±karsa yaklaÅŸÄ±k ${fmt(low, currency)} - ${fmt(center * 0.96, currency)} bandÄ±.` }
    ])
  };
}
function buildTechnicalSignals(t) {
  const out = [];
  if (t.rsi14 != null) out.push({ type: t.rsi14 > 70 ? 'negative' : t.rsi14 < 35 ? 'neutral' : t.rsi14 >= 50 ? 'positive' : 'neutral', title: 'RSI (14)', detail: `RSI ${t.rsi14.toFixed(1)} seviyesinde.`, weight: Math.round(clamp(Math.abs(t.rsi14 - 50) * 2, 10, 90)) });
  if (t.macdHistogram != null) out.push({ type: t.macdHistogram > 0 ? 'positive' : t.macdHistogram < 0 ? 'negative' : 'neutral', title: 'MACD', detail: `MACD histogramÄ± ${t.macdHistogram.toFixed(2)}.`, weight: Math.round(clamp(45 + Math.abs(t.macdHistogram) * 5, 20, 85)) });
  if (t.ema20 != null && t.ema50 != null) out.push({ type: t.ema20 >= t.ema50 ? 'positive' : 'negative', title: 'EMA eÄŸilimi', detail: `EMA20 ${t.ema20 >= t.ema50 ? 'EMA50 Ã¼zerinde' : 'EMA50 altÄ±nda'}.`, weight: 65 });
  if (t.volumeRatio != null) out.push({ type: t.volumeRatio >= 1.15 ? 'positive' : t.volumeRatio < 0.75 ? 'neutral' : 'neutral', title: 'Hacim ilgisi', detail: `20 gÃ¼nlÃ¼k ortalamaya gÃ¶re hacim oranÄ± ${t.volumeRatio.toFixed(2)}x.`, weight: Math.round(clamp(t.volumeRatio * 45, 15, 90)) });
  return out;
}

function detectScanMode(query) {
  const value = String(query || '').toLocaleLowerCase('tr-TR');
  const isStockScan = /(hisse|hisseler|borsa|bist).*(sÄ±rala|listele|bul|tara|hangileri|hangisi|yÃ¼kselebilir|yÃ¼kselecek|yÃ¼kseliÅŸe|dÃ¼ÅŸebilir|dÃ¼ÅŸecek|gerileyebilir|stabil|yatay)/i.test(value)
    || /(yÃ¼kselebilecek|yÃ¼kseliÅŸe geÃ§ebilecek|dÃ¼ÅŸebilecek|gerileyebilecek|stabil kalabilecek).*(hisse|hisseler)/i.test(value);
  if (!isStockScan) return null;
  if (/(dÃ¼ÅŸ|gerile|zayÄ±f|satÄ±ÅŸ baskÄ±sÄ±)/i.test(value)) return 'falling';
  if (/(stabil|yatay|dengeli|oynaklÄ±ÄŸÄ± dÃ¼ÅŸÃ¼k)/i.test(value)) return 'stable';
  return 'rising';
}

function calibratedRiskScore(marketData, classification) {
  const atr = Math.abs(finiteNumber(marketData?.technical?.atrPercent) || 0);
  const dailyMove = Math.abs(finiteNumber(marketData?.dailyPrice?.changePercent) || 0);
  const volumeRatio = finiteNumber(marketData?.technical?.volumeRatio);
  const score = finiteNumber(marketData?.technical?.score) ?? 50;
  const isIndex = classification?.entity?.subtype === 'index';
  let risk = isIndex ? 18 : 24;
  risk += Math.min(26, atr * (isIndex ? 3.2 : 4.2));
  risk += Math.min(12, dailyMove * 1.8);
  if (volumeRatio != null && volumeRatio < 0.45) risk += 6;
  if (volumeRatio != null && volumeRatio > 2.2) risk += 5;
  if (score >= 78 || score <= 28) risk += 4;
  return Math.round(clamp(risk, 15, 82));
}

function riskLabel(score) {
  if (score >= 68) return 'yÃ¼ksek';
  if (score >= 52) return 'orta-yÃ¼ksek';
  if (score >= 35) return 'orta';
  if (score >= 22) return 'dÃ¼ÅŸÃ¼k';
  return 'Ã§ok dÃ¼ÅŸÃ¼k';
}

function buildExpertProfile(marketData, classification) {
  const history = Array.isArray(marketData?.priceHistory) ? marketData.priceHistory : [];
  const closes = history.map(row => positivePrice(row?.close)).filter(Number.isFinite);
  const returns = [];
  for (let i = 1; i < closes.length; i += 1) {
    if (closes[i - 1] > 0) returns.push(closes[i] / closes[i - 1] - 1);
  }
  const mean = returns.length ? returns.reduce((sum, value) => sum + value, 0) / returns.length : null;
  const variance = returns.length > 1
    ? returns.reduce((sum, value) => sum + ((value - mean) ** 2), 0) / (returns.length - 1)
    : null;
  const dailyVolatility = variance != null ? Math.sqrt(Math.max(0, variance)) : null;
  const annualizedVolatility = dailyVolatility != null ? dailyVolatility * Math.sqrt(252) * 100 : null;
  const sortedReturns = [...returns].sort((a, b) => a - b);
  const var95 = sortedReturns.length
    ? Math.abs(sortedReturns[Math.max(0, Math.floor(sortedReturns.length * 0.05))]) * 100
    : null;

  let peak = null;
  let maxDrawdown = 0;
  for (const close of closes) {
    peak = peak == null ? close : Math.max(peak, close);
    maxDrawdown = Math.min(maxDrawdown, (close / peak) - 1);
  }
  const maxDrawdownPct = Math.abs(maxDrawdown) * 100;

  const t = marketData?.technical || {};
  const current = firstValidPrice(marketData?.dailyPrice?.current, marketData?.dailyPrice?.close);
  const above20 = current != null && finiteNumber(t.ema20) != null ? current >= t.ema20 : null;
  const above50 = current != null && finiteNumber(t.ema50) != null ? current >= t.ema50 : null;
  const above200 = current != null && finiteNumber(t.ema200) != null ? current >= t.ema200 : null;
  const regime = above20 === true && above50 === true && (above200 == null || above200 === true)
    ? 'yÃ¼kseliÅŸ rejimi'
    : above20 === false && above50 === false && (above200 == null || above200 === false)
      ? 'dÃ¼ÅŸÃ¼ÅŸ rejimi'
      : 'geÃ§iÅŸ/yatay rejim';

  const plan = buildTechnicalPlan(marketData);
  const invalidation = positivePrice(plan?.invalidation?.level);
  const target = positivePrice(plan?.profitTaking?.first);
  const downside = current != null && invalidation != null ? Math.max(0, current - invalidation) : null;
  const upside = current != null && target != null ? Math.max(0, target - current) : null;
  const riskReward = downside != null && downside > 0 && upside != null ? upside / downside : null;
  const horizon = horizonDays(classification);
  const dataQuality = Math.round(clamp(
    35 + Math.min(35, closes.length / 5) + (t.atrPercent != null ? 10 : 0) +
      (t.volumeRatio != null ? 8 : 0) + (marketData?.updatedAt ? 7 : 0),
    35,
    95
  ));

  return {
    observations: closes.length,
    horizon,
    regime,
    annualizedVolatility,
    var95,
    maxDrawdown: maxDrawdownPct,
    riskReward,
    dataQuality,
    plan,
    signals: [
      { type: regime === 'yÃ¼kseliÅŸ rejimi' ? 'positive' : regime === 'dÃ¼ÅŸÃ¼ÅŸ rejimi' ? 'negative' : 'neutral', title: 'Piyasa rejimi', detail: `${regime}; kÄ±sa, orta ve uzun vadeli ortalamalarÄ±n konumu birlikte deÄŸerlendirildi.`, weight: 82 },
      annualizedVolatility != null ? { type: annualizedVolatility >= 45 ? 'negative' : annualizedVolatility >= 25 ? 'neutral' : 'positive', title: 'YÄ±llÄ±klaÅŸtÄ±rÄ±lmÄ±ÅŸ oynaklÄ±k', detail: `%${annualizedVolatility.toFixed(1)}; ${returns.length} gÃ¼nlÃ¼k getiri gÃ¶zleminden hesaplandÄ±.`, weight: 78 } : null,
      closes.length > 1 ? { type: maxDrawdownPct >= 30 ? 'negative' : maxDrawdownPct >= 15 ? 'neutral' : 'positive', title: 'Maksimum dÃ¼ÅŸÃ¼ÅŸ', detail: `Ä°ncelenen seride zirveden en sert gerileme %${maxDrawdownPct.toFixed(1)}.`, weight: 84 } : null,
      var95 != null ? { type: var95 >= 4 ? 'negative' : var95 >= 2 ? 'neutral' : 'positive', title: 'GÃ¼nlÃ¼k aÅŸaÄŸÄ± yÃ¶nlÃ¼ risk', detail: `Tarihsel %95 VaR yaklaÅŸÄ±k %${var95.toFixed(2)}; daha kÃ¶tÃ¼ gÃ¼nler yine mÃ¼mkÃ¼ndÃ¼r.`, weight: 80 } : null,
      riskReward != null ? { type: riskReward >= 2 ? 'positive' : riskReward >= 1 ? 'neutral' : 'negative', title: 'Risk/getiri oranÄ±', detail: `Ä°lk teknik hedef ve geÃ§ersizlik seviyesine gÃ¶re yaklaÅŸÄ±k ${riskReward.toFixed(2)}x.`, weight: 86 } : null
    ].filter(Boolean),
    factors: [
      `${closes.length} doÄŸrulanmÄ±ÅŸ fiyat gÃ¶zlemi`,
      `Piyasa rejimi: ${regime}`,
      annualizedVolatility != null ? `YÄ±llÄ±klaÅŸtÄ±rÄ±lmÄ±ÅŸ oynaklÄ±k: %${annualizedVolatility.toFixed(1)}` : null,
      closes.length > 1 ? `Maksimum dÃ¼ÅŸÃ¼ÅŸ: %${maxDrawdownPct.toFixed(1)}` : null,
      riskReward != null ? `Risk/getiri: ${riskReward.toFixed(2)}x` : null
    ].filter(Boolean),
    invalidationText: invalidation != null
      ? `${fmt(invalidation, marketData.currency)} altÄ±nda kalÄ±cÄ±lÄ±k mevcut teknik senaryoyu geÃ§ersiz kÄ±lar.`
      : 'GeÃ§ersizlik seviyesi iÃ§in yeterli destek verisi oluÅŸmadÄ±.'
  };
}

function scanScore(data, mode) {
  const tech = finiteNumber(data?.technical?.score) ?? 50;
  const rsi = finiteNumber(data?.technical?.rsi14) ?? 50;
  const atr = Math.abs(finiteNumber(data?.technical?.atrPercent) || 3);
  const volume = finiteNumber(data?.technical?.volumeRatio) ?? 1;
  const change = finiteNumber(data?.dailyPrice?.changePercent) ?? 0;
  if (mode === 'falling') {
    return Math.round(clamp((100 - tech) * 0.68 + Math.max(0, -change) * 5 + (rsi < 45 ? 10 : 0), 0, 100));
  }
  if (mode === 'stable') {
    return Math.round(clamp(100 - Math.abs(tech - 50) * 1.25 - atr * 7 - Math.abs(change) * 3 - Math.abs(rsi - 50) * 0.7, 0, 100));
  }
  return Math.round(clamp(tech * 0.72 + Math.min(12, Math.max(0, volume - 1) * 12) + Math.max(-8, Math.min(8, change * 2)) + (rsi >= 48 && rsi <= 68 ? 8 : 0), 0, 100));
}

async function runBistScanner(query, classification, sourcePlan, mode) {
  const universe = await getUniverse({ market: 'BIST' });
  console.log('[Scanner] Universe size:', universe.length);
  const results = [];
  // TÃ¼m istekler paralel baÅŸlar; bÃ¶ylece Render isteÄŸi seri 12 saniyelik
  // beklemeler yÃ¼zÃ¼nden uzamaz. BaÅŸarÄ±sÄ±z semboller diÄŸerlerini durdurmaz.
  const scannerLimit = pLimit(Number(process.env.TRENDORA_SCANNER_CONCURRENCY || 10));
  const settled = await Promise.allSettled(universe.map(item => scannerLimit(() => fetchMarketData(item.symbol, {
    domain: 'finance', label: 'Finans', intent: 'scan', period: classification.period,
    entity: { found: true, domain: 'finance', subtype: 'bist_stock', market: 'BIST', symbol: item.symbol, name: item.name }
  }))));
  settled.forEach((entry, index) => {
    if (entry.status !== 'fulfilled' || !entry.value) return;
    const data = entry.value;
    results.push({
      symbol: universe[index].symbol, name: universe[index].name, data,
      scanScore: scanScore(data, mode),
      riskScore: calibratedRiskScore(data, { entity: { subtype: 'bist_stock' } })
    });
  });

  const ranked = results
    .sort((a, b) => b.scanScore - a.scanScore)
    .slice(0, 10)
    .map(item => ({ ...item, technicalPlan: buildTechnicalPlan(item.data) }));
  const labels = { rising: 'yÃ¼kseliÅŸ eÄŸilimi', falling: 'zayÄ±flama eÄŸilimi', stable: 'dengeli/yatay eÄŸilim' };
  const headline = labels[mode] || labels.rising;
  const confidence = Math.round(clamp(58 + Math.min(22, ranked.length * 2), 58, 82));
  const avgTrend = ranked.length ? Math.round(ranked.reduce((s, x) => s + x.scanScore, 0) / ranked.length) : 0;
  const signals = ranked.map((item, idx) => {
    const t = item.data.technical || {};
    const current = firstValidPrice(item.data.dailyPrice?.current, item.data.dailyPrice?.close);
    const type = mode === 'falling' ? 'negative' : mode === 'stable' ? 'neutral' : 'positive';
    return {
      type,
      title: `#${idx + 1} ${item.symbol} â€” ${item.scanScore}/100`,
      detail: `${item.name}; fiyat ${fmt(current, item.data.currency)}. RSI ${finiteNumber(t.rsi14)?.toFixed(1) || '-'}, EMA20 ${t.ema20 != null && t.ema50 != null ? (t.ema20 >= t.ema50 ? 'EMA50 Ã¼zerinde' : 'EMA50 altÄ±nda') : 'Ã¶lÃ§Ã¼lemedi'}, hacim ${finiteNumber(t.volumeRatio)?.toFixed(2) || '-'}x, risk ${riskLabel(item.riskScore)}. KÄ±rÄ±lÄ±m ${fmt(item.technicalPlan?.breakout?.level, item.data.currency)}, takip ${fmt(item.technicalPlan?.followZone?.low, item.data.currency)} - ${fmt(item.technicalPlan?.followZone?.high, item.data.currency)}, kÃ¢r alma ${fmt(item.technicalPlan?.profitTaking?.first, item.data.currency)} / ${fmt(item.technicalPlan?.profitTaking?.second, item.data.currency)}, geÃ§ersizlik ${fmt(item.technicalPlan?.invalidation?.level, item.data.currency)}.`,
      weight: item.scanScore
    };
  });
  const topText = ranked.slice(0, 5).map((x, i) => `${i + 1}. ${x.symbol} (${x.scanScore})`).join(', ');
  const raw = {
    answerTitle: `BIST piyasa taramasÄ± â€” ${headline}`,
    directAnswer: ranked.length ? `CanlÄ± teknik taramada Ã¶ne Ã§Ä±kan ilk hisseler: ${topText}. Bu sÄ±ralama fiyat serisi, RSI, EMA, MACD, hacim ve oynaklÄ±k Ã¶lÃ§Ã¼mlerine dayanÄ±r.` : 'Tarama sÄ±rasÄ±nda yeterli canlÄ± piyasa verisi alÄ±namadÄ±.',
    summary: `Trendora, BIST evrenindeki ${results.length} hisseden canlÄ± verisi alÄ±nabilenleri karÅŸÄ±laÅŸtÄ±rdÄ± ve ${headline} aÃ§Ä±sÄ±ndan puanladÄ±. Liste kesin getiri vaadi deÄŸildir; tarama sonucu ve Ã¶nceliklendirmedir.`,
    confidence,
    statistics: { trendStrength: avgTrend, dataConfidence: confidence, riskScore: ranked.length ? Math.round(ranked.reduce((s,x)=>s+x.riskScore,0)/ranked.length) : 50, newsImpact: 20, marketInterest: 55 },
    signals,
    keyFactors: ['CanlÄ± gÃ¼nlÃ¼k fiyat serisi', 'RSI ve EMA eÄŸilimi', 'MACD yÃ¶nÃ¼', '20 gÃ¼nlÃ¼k hacim oranÄ±', 'ATR tabanlÄ± oynaklÄ±k', `${results.length} hisse karÅŸÄ±laÅŸtÄ±rÄ±ldÄ±`],
    missingInformation: ['Tarama bilanÃ§o ve KAP verilerini tÃ¼m hisselerde aynÄ± anda tam kapsamla doÄŸrulamaz'],
    nextChecks: ['Listelenen her hisseyi tek tek aÃ§arak KAP, bilanÃ§o ve haber analiziyle doÄŸrula', 'Zaman ufkunu gÃ¼n/hafta/ay olarak ayrÄ±ca belirt'],
    sources: ranked.map(x => x.data.source).filter(Boolean),
    disclaimer: 'Bu liste yatÄ±rÄ±m tavsiyesi deÄŸildir. Teknik tarama, olasÄ±lÄ±k ve Ã¶nceliklendirme amacÄ± taÅŸÄ±r.'
  };
  const normalized = normalizeAnalysis(raw, query, classification, sourcePlan);
  try {
  console.log('Prediction input:', {
  domain: normalized.domain,
  entity: normalized.entity,
  dailyPrice: normalized.dailyPrice
});  
  const prediction = buildPredictionFromAnalysis(normalized);

  if (prediction) {
    savePrediction(prediction);
  }
} catch (error) {
  console.error(
    'Tahmin hafızasına kayıt yapılamadı:',
    error.message
  );
}
  return { ...normalized, scanResults: ranked.map(x => ({ symbol:x.symbol, name:x.name, score:x.scanScore, riskScore:x.riskScore, riskLabel:riskLabel(x.riskScore), current:firstValidPrice(x.data.dailyPrice?.current,x.data.dailyPrice?.close), currency:x.data.currency, technical:x.data.technical, technicalPlan:x.technicalPlan })), engine: { version:'5.0.0', mode:'bist-market-scanner', usedLiveMarketData:true, usedLiveWebResearch:false, usedFallbackNews:false, entityRecognition:false, generatedAt:new Date().toISOString() } };
}

function removeFalseMissing(items, marketData) {
  if (!marketData) return items;
  const banned = /doÄŸrudan piyasa|geÃ§miÅŸ fiyat|fiyat serisi|piyasa verisi/i;
  return (items || []).filter(x => !banned.test(String(x)));
}

async function analyzeQuestion(query) {
  const cleanedQuery = String(query || '').trim();
  if (cleanedQuery.length < 2) { const e = new Error('Analiz iÃ§in en az 2 karakterlik bir soru yazmalÄ±sÄ±n.'); e.statusCode = 400; throw e; }
  const classification = classifyQuestion(cleanedQuery);
  const sourcePlan = buildSourcePlan(classification);
  const scanMode = detectScanMode(cleanedQuery);
  if (scanMode && classification.domain === 'finance') {
    return runBistScanner(cleanedQuery, classification, sourcePlan, scanMode);
  }
  const evidenceQuery = classification.entity?.found
    ? `${classification.entity.name} ${classification.entity.symbol || ''}`.trim()
    : cleanedQuery;
  const marketTask = classification.domain === 'finance'
    ? fetchMarketData(cleanedQuery, classification)
    : Promise.resolve(null);
  const webTask = environment.aiEnabled
    ? withTimeout(
        researchWithWeb(cleanedQuery, classification, sourcePlan),
        WEB_TIMEOUT_MS,
        'Web araÅŸtÄ±rmasÄ±'
      )
    : Promise.resolve(null);
  const evidenceTask = withTimeout(
    collectNewsEvidence(evidenceQuery, 24),
    FALLBACK_NEWS_TIMEOUT_MS,
    'Yedek haber taramasÄ±'
  );

  // Piyasa, web ve haber katmanlarÄ± paralel Ã§alÄ±ÅŸÄ±r. Bir kaynak yavaÅŸlarsa
  // diÄŸer sonuÃ§lar bekletilmez.
  const [marketResult, webResultSettled, evidenceResult] = await Promise.allSettled([
    marketTask,
    webTask,
    evidenceTask
  ]);
  const marketData = marketResult.status === 'fulfilled' ? marketResult.value : null;
  const webResult = webResultSettled.status === 'fulfilled' ? webResultSettled.value : null;
  const webError = webResultSettled.status === 'rejected' ? webResultSettled.reason : null;
  const evidence = evidenceResult.status === 'fulfilled' && Array.isArray(evidenceResult.value)
    ? evidenceResult.value
    : [];
  const evidenceProfile = analyzeEvidence(evidence);
  if (marketResult.status === 'rejected') console.error('CanlÄ± piyasa verisi alÄ±namadÄ±:', marketResult.reason?.message || marketResult.reason);
  if (webError) console.error('Trendora web araÅŸtÄ±rmasÄ±:', webError.message || webError);

  let base = webResult ? { ...webResult, dailyPrice:{...(webResult.dailyPrice||{})}, yearlyPrice:{...(webResult.yearlyPrice||{})}, estimatedRange:{...(webResult.estimatedRange||{})}, technical:{...(webResult.technical||{})}, statistics:{...(webResult.statistics||{})}, sources:[...(webResult.sources||[])] } : buildFallbackAnalysis(cleanedQuery, classification, evidence);

  if (marketData) {
    const expert = buildExpertProfile(marketData, classification);
    const current = firstValidPrice(marketData.dailyPrice?.current, marketData.dailyPrice?.close, marketData.dailyPrice?.open);
    const technicalScore = finiteNumber(marketData.technical?.score) ?? 50;
    const atrPercent = Math.abs(finiteNumber(marketData.technical?.atrPercent) || 0);
    const changePercent = Math.abs(finiteNumber(marketData.dailyPrice?.changePercent) || 0);
    const hasWeb = Boolean(webResult || evidence.length);
    const evidenceBonus = Math.min(10, Math.round((evidenceProfile.qualityScore + evidenceProfile.diversityScore) / 20));
    const rawConfidence = 60 + Math.min(16, Math.abs(technicalScore - 50) * .35) + (webResult ? 7 : 0) + evidenceBonus;
    const confidence = Math.round(clamp(Math.min(rawConfidence, expert.dataQuality + (webResult ? 3 : 0)), 45, 88));
    const riskScore = calibratedRiskScore(marketData, classification) + (hasWeb ? 0 : 3);
    const marketScenarios = buildMarketScenarios(marketData, classification);
    base.dailyPrice = { ...marketData.dailyPrice, current, close: firstValidPrice(marketData.dailyPrice?.close, current) };
    base.yearlyPrice = { ...marketData.yearlyPrice };
    base.technical = { ...(base.technical || {}), ...(marketData.technical || {}) };
    const technicalPlan = buildTechnicalPlan(marketData);
    base.technicalPlan = technicalPlan;
    base.statistics = { ...(base.statistics || {}), trendStrength: technicalScore, dataConfidence: confidence, riskScore, marketInterest: Math.round(clamp((finiteNumber(marketData.technical?.volumeRatio) || 1) * 50, 0, 100)), newsImpact: hasWeb ? Math.round(clamp((finiteNumber(base.statistics?.newsImpact) ?? evidenceProfile.newsImpact) * 0.55 + evidenceProfile.newsImpact * 0.45, 0, 100)) : 15 };
    base.confidence = confidence;
    if (marketScenarios) { base.estimatedRange = marketScenarios.estimatedRange; base.scenarios = marketScenarios.scenarios; }
    base.signals = [
      ...expert.signals,
      ...buildTechnicalSignals(marketData.technical || {}),
      ...buildPlanSignals(technicalPlan),
      ...evidenceProfile.signals,
      ...(base.signals || []).filter(s => !/haber hacmi|olumlu baÅŸlÄ±k|olumsuz baÅŸlÄ±k/i.test(String(s?.title)))
    ].slice(0,14);
    base.keyFactors = [...new Set([
      ...(base.keyFactors || []),
      ...evidenceProfile.keyFactors,
      ...(technicalPlan.reasons || []),
      ...expert.factors,
      `Teknik skor: ${technicalScore}/100`,
      marketData.technical?.volumeRatio != null ? `Hacim oranÄ±: ${Number(marketData.technical.volumeRatio).toFixed(2)}x` : null
    ].filter(Boolean))].slice(0, 10);
    base.sources = [marketData.source, ...(base.sources || []), ...evidence].filter(Boolean);
    base.missingInformation = removeFalseMissing(base.missingInformation, marketData);
    if (!hasWeb) base.missingInformation = [...new Set([...(base.missingInformation || []), 'GÃ¼ncel haber ve KAP aÃ§Ä±klamalarÄ±nÄ±n tam taramasÄ±'])];
    const periodLabel = classification.period?.label || '3 Ay';
    const priceText = fmt(current, marketData.currency);
    const direction = technicalScore >= 65 ? 'pozitif' : technicalScore <= 42 ? 'negatif' : 'temkinli-nÃ¶tr';
    base.answerTitle = `${periodLabel} finans deÄŸerlendirmesi`;
    const financeChecks = (base.nextChecks || []).filter(item =>
      !/(ilan|model, yÄ±l|paket|konum|metrekare|ekspertiz)/i.test(String(item))
    );
    base.nextChecks = [...new Set([
      expert.invalidationText,
      `Tahmin ufku ${expert.horizon} gÃ¼n; sÃ¼re deÄŸiÅŸirse olasÄ±lÄ±k ve fiyat bandÄ± yeniden hesaplanmalÄ±.`,
      'Karardan Ã¶nce gÃ¼ncel KAP aÃ§Ä±klamalarÄ±, bilanÃ§o ve Ã¶nemli haber akÄ±ÅŸÄ± ayrÄ±ca kontrol edilmeli.',
      ...financeChecks
    ])].slice(0, 10);
    const volatilityText = expert.annualizedVolatility != null ? `yÄ±llÄ±klandÄ±rÄ±lmÄ±ÅŸ oynaklÄ±k %${expert.annualizedVolatility.toFixed(1)}` : 'oynaklÄ±k Ã¶lÃ§Ã¼mÃ¼ sÄ±nÄ±rlÄ±';
    const drawdownText = Number.isFinite(expert.maxDrawdown) ? `geÃ§miÅŸ maksimum dÃ¼ÅŸÃ¼ÅŸ %${expert.maxDrawdown.toFixed(1)}` : 'maksimum dÃ¼ÅŸÃ¼ÅŸ Ã¶lÃ§Ã¼lemedi';
    const rrText = expert.riskReward != null ? `risk/getiri ${expert.riskReward.toFixed(2)}x` : 'risk/getiri Ã¶lÃ§Ã¼lemedi';
    base.directAnswer = `${marketData.displayName} gÃ¼ncel fiyatÄ± ${priceText}. ${periodLabel} iÃ§in ${expert.regime}; teknik gÃ¶rÃ¼nÃ¼m ${direction}. Veri gÃ¼veni %${confidence}, risk ${riskLabel(riskScore)}, ${volatilityText}, ${drawdownText} ve ${rrText}. OlasÄ± kÄ±rÄ±lÄ±m ${fmt(technicalPlan.breakout?.level, marketData.currency)}, takip bÃ¶lgesi ${fmt(technicalPlan.followZone?.low, marketData.currency)} - ${fmt(technicalPlan.followZone?.high, marketData.currency)}. ${expert.invalidationText}`;
    base.summary = `${periodLabel} ufkunda ${expert.observations} fiyat gÃ¶zlemi; getiri daÄŸÄ±lÄ±mÄ±, tarihsel VaR, maksimum dÃ¼ÅŸÃ¼ÅŸ, piyasa rejimi, RSI, EMA, SMA, MACD, ATR, hacim ve destek-direnÃ§ birlikte deÄŸerlendirildi. GÃ¼ven puanÄ± veri yeterliliÄŸiyle sÄ±nÄ±rlandÄ±; sonuÃ§ kesin vaat deÄŸil, Ã¶lÃ§Ã¼lebilir olasÄ±lÄ±k bandÄ±dÄ±r.`;
  }

  const normalized = normalizeAnalysis(base, cleanedQuery, classification, sourcePlan);

  try {
    console.log('Prediction input:', {
      domain: normalized.domain,
      entity: normalized.entity,
      dailyPrice: normalized.dailyPrice
    });

    const prediction = buildPredictionFromAnalysis(normalized);

    if (prediction) {
      savePrediction(prediction);
    }
  } catch (error) {
    console.error(
      'Tahmin hafızasına kayıt yapılamadı:',
      error.message
    );
  }

  return { ...normalized, engine: { version:'6.0.0', mode: marketData && webResult ? 'market-plus-web' : marketData ? 'expert-statistical-market' : webResult ? 'web-research' : 'limited-fallback', usedLiveMarketData:Boolean(marketData), usedLiveWebResearch:Boolean(webResult), usedFallbackNews:evidence.length>0, evidenceProfile, entityRecognition:classification.entity?.found||false, ai: { enabled: environment.aiEnabled, premiumOnly: environment.aiPremiumOnly, used: Boolean(webResult) }, webResearchError:webError ? webError.message : null, sourceCoverage: { planned: Array.isArray(sourcePlan?.sources) ? sourcePlan.sources.map(s => s.name) : [], returned: normalized.sources.map(s => s.publisher), autoDiscovery: sourcePlan?.discovery?.enabled === true }, generatedAt:new Date().toISOString() } };
}
module.exports = { analyzeQuestion, normalizeAnalysis };



