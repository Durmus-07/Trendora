const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
const { fetchMarketData } = require('../marketDataService');
const { classifyQuestion } = require('./questionClassifier');
const { buildSourcePlan } = require('./sourceRouter');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const { clamp, normalizeScenarios, confidenceLabel } = require('./probabilityEngine');

const WEB_TIMEOUT_MS = Number(process.env.TRENDORA_WEB_TIMEOUT_MS || 18000);

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
    timer = setTimeout(() => reject(new Error(`${label} ${timeoutMs} ms içinde tamamlanamadı.`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}
function cleanRange(range) {
  const low = positivePrice(range?.low);
  const mid = positivePrice(range?.mid);
  const high = positivePrice(range?.high);
  const available = Boolean(range?.available) && [low, mid, high].some(v => v != null);
  return { available, currency: available ? String(range?.currency || 'TRY') : null, low: available ? low : null, mid: available ? mid : null, high: available ? high : null, label: String(range?.label || (available ? 'Tahmini aralık' : 'Aralık hesaplanamadı')), basis: String(range?.basis || '') };
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
  const keys = ['rsi14','sma20','sma50','sma200','volumeRatio','changePercent','ema20','ema50','ema100','ema200','macd','macdSignal','macdHistogram','atr14','atrPercent','support1','support2','resistance1','resistance2','score'];
  const result = {};
  for (const key of keys) result[key] = finiteNumber(raw?.[key]);
  result.direction = ['positive','negative','neutral'].includes(raw?.direction) ? raw.direction : 'neutral';
  return result;
}
function cleanStatistics(raw) {
  const s = raw && typeof raw === 'object' ? raw : {};
  return { trendStrength: finiteNumber(s.trendStrength), dataConfidence: finiteNumber(s.dataConfidence), riskScore: finiteNumber(s.riskScore), newsImpact: finiteNumber(s.newsImpact), marketInterest: finiteNumber(s.marketInterest) };
}
function cleanSources(sources) {
  if (!Array.isArray(sources)) return [];
  const seen = new Set();
  return sources.map(item => ({ title: String(item?.title || 'Kaynak'), publisher: String(item?.publisher || item?.source || 'Bilinmeyen kaynak'), url: String(item?.url || item?.link || ''), publishedAt: item?.publishedAt || null, evidenceType: String(item?.evidenceType || 'web') }))
    .filter(item => item.url && /^https?:\/\//i.test(item.url) && !seen.has(item.url) && seen.add(item.url))
    .slice(0, 12);
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
    scenarios: normalizeScenarios(raw?.scenarios), confidence: Math.round(confidence), confidenceLabel: confidenceLabel(confidence),
    signals: Array.isArray(raw?.signals) ? raw.signals.slice(0, 10).map(item => ({ type: ['positive','negative','neutral'].includes(item?.type) ? item.type : 'neutral', title: cleanText(item?.title || 'Sinyal'), detail: cleanText(item?.detail || ''), weight: Math.round(clamp(item?.weight, 0, 100)) })) : [],
    keyFactors: Array.isArray(raw?.keyFactors) ? raw.keyFactors.map(cleanText).filter(Boolean).slice(0,10) : [],
    missingInformation: Array.isArray(raw?.missingInformation) ? raw.missingInformation.map(cleanText).filter(Boolean).slice(0,10) : [],
    nextChecks: Array.isArray(raw?.nextChecks) ? raw.nextChecks.map(cleanText).filter(Boolean).slice(0,10) : [],
    sources: cleanSources(raw?.sources),
    disclaimer: cleanText(raw?.disclaimer || 'Bu sonuç mevcut açık verilerden üretilmiş olasılık analizidir. Yatırım tavsiyesi değildir.')
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
    estimatedRange: { available: true, currency, low, mid: center, high, label: `${classification.period?.label || '3 Ay'} olası fiyat bandı`, basis: `ATR oynaklığı, teknik skor ve ${days} günlük zaman ölçeği kullanıldı.` },
    scenarios: normalizeScenarios([
      { name: 'Olumlu görünüm', probability: pos, description: `Teknik sinyaller güçlenirse yaklaşık ${fmt(center, currency)} - ${fmt(high, currency)} bandı.` },
      { name: 'Dengeli görünüm', probability: neutral, description: `Ana senaryoda yaklaşık ${fmt(low * 1.04, currency)} - ${fmt(high * 0.96, currency)} bandında dalgalanma.` },
      { name: 'Olumsuz görünüm', probability: neg, description: `Riskler öne çıkarsa yaklaşık ${fmt(low, currency)} - ${fmt(center * 0.96, currency)} bandı.` }
    ])
  };
}
function buildTechnicalSignals(t) {
  const out = [];
  if (t.rsi14 != null) out.push({ type: t.rsi14 > 70 ? 'negative' : t.rsi14 < 35 ? 'neutral' : t.rsi14 >= 50 ? 'positive' : 'neutral', title: 'RSI (14)', detail: `RSI ${t.rsi14.toFixed(1)} seviyesinde.`, weight: Math.round(clamp(Math.abs(t.rsi14 - 50) * 2, 10, 90)) });
  if (t.macdHistogram != null) out.push({ type: t.macdHistogram > 0 ? 'positive' : t.macdHistogram < 0 ? 'negative' : 'neutral', title: 'MACD', detail: `MACD histogramı ${t.macdHistogram.toFixed(2)}.`, weight: Math.round(clamp(45 + Math.abs(t.macdHistogram) * 5, 20, 85)) });
  if (t.ema20 != null && t.ema50 != null) out.push({ type: t.ema20 >= t.ema50 ? 'positive' : 'negative', title: 'EMA eğilimi', detail: `EMA20 ${t.ema20 >= t.ema50 ? 'EMA50 üzerinde' : 'EMA50 altında'}.`, weight: 65 });
  if (t.volumeRatio != null) out.push({ type: t.volumeRatio >= 1.15 ? 'positive' : t.volumeRatio < 0.75 ? 'neutral' : 'neutral', title: 'Hacim ilgisi', detail: `20 günlük ortalamaya göre hacim oranı ${t.volumeRatio.toFixed(2)}x.`, weight: Math.round(clamp(t.volumeRatio * 45, 15, 90)) });
  return out;
}
function removeFalseMissing(items, marketData) {
  if (!marketData) return items;
  const banned = /doğrudan piyasa|geçmiş fiyat|fiyat serisi|piyasa verisi/i;
  return (items || []).filter(x => !banned.test(String(x)));
}

async function analyzeQuestion(query) {
  const cleanedQuery = String(query || '').trim();
  if (cleanedQuery.length < 2) { const e = new Error('Analiz için en az 2 karakterlik bir soru yazmalısın.'); e.statusCode = 400; throw e; }
  const classification = classifyQuestion(cleanedQuery);
  const sourcePlan = buildSourcePlan(classification);
  const marketTask = classification.domain === 'finance' ? fetchMarketData(cleanedQuery, classification) : Promise.resolve(null);
  const webTask = withTimeout(researchWithWeb(cleanedQuery, classification, sourcePlan), WEB_TIMEOUT_MS, 'Web araştırması');
  const [marketResult, webResultSettled] = await Promise.allSettled([marketTask, webTask]);
  const marketData = marketResult.status === 'fulfilled' ? marketResult.value : null;
  const webResult = webResultSettled.status === 'fulfilled' ? webResultSettled.value : null;
  const webError = webResultSettled.status === 'rejected' ? webResultSettled.reason : null;
  if (marketResult.status === 'rejected') console.error('Canlı piyasa verisi alınamadı:', marketResult.reason?.message || marketResult.reason);
  if (webError) console.error('Trendora web araştırması:', webError.message || webError);

  let evidence = [];
  if (!webResult) {
    const evidenceQuery = classification.entity?.found ? `${classification.entity.name} ${classification.entity.symbol || ''}`.trim() : cleanedQuery;
    try { evidence = await withTimeout(collectNewsEvidence(evidenceQuery, 20), 7000, 'Yedek haber taraması'); } catch (_) { evidence = []; }
  }

  let base = webResult ? { ...webResult, dailyPrice:{...(webResult.dailyPrice||{})}, yearlyPrice:{...(webResult.yearlyPrice||{})}, estimatedRange:{...(webResult.estimatedRange||{})}, technical:{...(webResult.technical||{})}, statistics:{...(webResult.statistics||{})}, sources:[...(webResult.sources||[])] } : buildFallbackAnalysis(cleanedQuery, classification, evidence);

  if (marketData) {
    const current = firstValidPrice(marketData.dailyPrice?.current, marketData.dailyPrice?.close, marketData.dailyPrice?.open);
    const technicalScore = finiteNumber(marketData.technical?.score) ?? 50;
    const atrPercent = Math.abs(finiteNumber(marketData.technical?.atrPercent) || 0);
    const changePercent = Math.abs(finiteNumber(marketData.dailyPrice?.changePercent) || 0);
    const hasWeb = Boolean(webResult || evidence.length);
    const confidence = Math.round(clamp(62 + Math.min(16, Math.abs(technicalScore - 50) * .35) + (hasWeb ? 8 : 0), 55, 86));
    const riskScore = Math.round(clamp(35 + atrPercent * 5 + changePercent * 2 + (hasWeb ? 0 : 8), 20, 88));
    const marketScenarios = buildMarketScenarios(marketData, classification);
    base.dailyPrice = { ...marketData.dailyPrice, current, close: firstValidPrice(marketData.dailyPrice?.close, current) };
    base.yearlyPrice = { ...marketData.yearlyPrice };
    base.technical = { ...(base.technical || {}), ...(marketData.technical || {}) };
    base.statistics = { ...(base.statistics || {}), trendStrength: technicalScore, dataConfidence: confidence, riskScore, marketInterest: Math.round(clamp((finiteNumber(marketData.technical?.volumeRatio) || 1) * 50, 0, 100)), newsImpact: hasWeb ? (finiteNumber(base.statistics?.newsImpact) ?? 45) : 15 };
    base.confidence = confidence;
    if (marketScenarios) { base.estimatedRange = marketScenarios.estimatedRange; base.scenarios = marketScenarios.scenarios; }
    base.signals = [...buildTechnicalSignals(marketData.technical || {}), ...(base.signals || []).filter(s => !/haber hacmi/i.test(String(s?.title)))].slice(0,10);
    base.sources = [marketData.source, ...(base.sources || []), ...evidence].filter(Boolean);
    base.missingInformation = removeFalseMissing(base.missingInformation, marketData);
    if (!hasWeb) base.missingInformation = [...new Set([...(base.missingInformation || []), 'Güncel haber ve KAP açıklamalarının tam taraması'])];
    const periodLabel = classification.period?.label || '3 Ay';
    const priceText = fmt(current, marketData.currency);
    const direction = technicalScore >= 65 ? 'pozitif' : technicalScore <= 42 ? 'negatif' : 'temkinli-nötr';
    base.answerTitle = `${periodLabel} finans değerlendirmesi`;
    base.directAnswer = `${marketData.displayName} güncel fiyatı ${priceText}. ${periodLabel} için teknik görünüm ${direction}; veri güveni %${confidence}, risk seviyesi ${riskScore >= 65 ? 'yüksek' : riskScore >= 45 ? 'orta' : 'düşük'}.`;
    base.summary = `${periodLabel} ufku; canlı fiyat serisi, RSI, EMA, SMA, MACD, ATR, hacim, destek-direnç ve erişilebilen haber sinyalleri birlikte değerlendirilerek hesaplandı. Sonuç kesin fiyat tahmini değil, olasılık bandıdır.`;
  }

  const normalized = normalizeAnalysis(base, cleanedQuery, classification, sourcePlan);
  return { ...normalized, engine: { version:'4.1.0', mode: marketData && webResult ? 'market-plus-web' : marketData ? 'market-data' : webResult ? 'web-research' : 'limited-fallback', usedLiveMarketData:Boolean(marketData), usedLiveWebResearch:Boolean(webResult), usedFallbackNews:evidence.length>0, entityRecognition:classification.entity?.found||false, webResearchError:webError ? webError.message : null, generatedAt:new Date().toISOString() } };
}
module.exports = { analyzeQuestion, normalizeAnalysis };
