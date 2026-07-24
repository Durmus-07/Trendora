const { buildFallbackAnalysis } = require('./fallbackAnalyzer');
const { fetchMarketData } = require('../marketDataService');
const { classifyQuestion } = require('./questionClassifier');
const { BIST_ENTITIES } = require('./entityEngine');
const { buildSourcePlan } = require('./sourceRouter');
const { collectNewsEvidence } = require('./newsEvidenceCollector');
const { researchWithWeb } = require('./webResearchService');
const { clamp, normalizeScenarios, confidenceLabel } = require('./probabilityEngine');
const { analyzeEvidence, sourceWeight, getHostname } = require('./evidenceAnalyzer');

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

function detectScanMode(query) {
  const value = String(query || '').toLocaleLowerCase('tr-TR');
  const isStockScan = /(hisse|hisseler|borsa|bist).*(sırala|listele|bul|tara|hangileri|hangisi|yükselebilir|yükselecek|yükselişe|düşebilir|düşecek|gerileyebilir|stabil|yatay)/i.test(value)
    || /(yükselebilecek|yükselişe geçebilecek|düşebilecek|gerileyebilecek|stabil kalabilecek).*(hisse|hisseler)/i.test(value);
  if (!isStockScan) return null;
  if (/(düş|gerile|zayıf|satış baskısı)/i.test(value)) return 'falling';
  if (/(stabil|yatay|dengeli|oynaklığı düşük)/i.test(value)) return 'stable';
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
  if (score >= 68) return 'yüksek';
  if (score >= 52) return 'orta-yüksek';
  if (score >= 35) return 'orta';
  if (score >= 22) return 'düşük';
  return 'çok düşük';
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
  const universe = BIST_ENTITIES.filter(item => !item.symbol.endsWith('.S1')).slice(0, 42);
  const results = [];
  // Tüm istekler paralel başlar; böylece Render isteği seri 12 saniyelik
  // beklemeler yüzünden uzamaz. Başarısız semboller diğerlerini durdurmaz.
  const settled = await Promise.allSettled(universe.map(item => fetchMarketData(item.symbol, {
    domain: 'finance', label: 'Finans', intent: 'scan', period: classification.period,
    entity: { found: true, domain: 'finance', subtype: 'bist_stock', market: 'BIST', symbol: item.symbol, name: item.name }
  })));
  settled.forEach((entry, index) => {
    if (entry.status !== 'fulfilled' || !entry.value) return;
    const data = entry.value;
    results.push({
      symbol: universe[index].symbol, name: universe[index].name, data,
      scanScore: scanScore(data, mode),
      riskScore: calibratedRiskScore(data, { entity: { subtype: 'bist_stock' } })
    });
  });

  const ranked = results.sort((a, b) => b.scanScore - a.scanScore).slice(0, 10);
  const labels = { rising: 'yükseliş eğilimi', falling: 'zayıflama eğilimi', stable: 'dengeli/yatay eğilim' };
  const headline = labels[mode] || labels.rising;
  const confidence = Math.round(clamp(58 + Math.min(22, ranked.length * 2), 58, 82));
  const avgTrend = ranked.length ? Math.round(ranked.reduce((s, x) => s + x.scanScore, 0) / ranked.length) : 0;
  const signals = ranked.map((item, idx) => {
    const t = item.data.technical || {};
    const current = firstValidPrice(item.data.dailyPrice?.current, item.data.dailyPrice?.close);
    const type = mode === 'falling' ? 'negative' : mode === 'stable' ? 'neutral' : 'positive';
    return {
      type,
      title: `#${idx + 1} ${item.symbol} — ${item.scanScore}/100`,
      detail: `${item.name}; fiyat ${fmt(current, item.data.currency)}. RSI ${finiteNumber(t.rsi14)?.toFixed(1) || '-'}, EMA20 ${t.ema20 != null && t.ema50 != null ? (t.ema20 >= t.ema50 ? 'EMA50 üzerinde' : 'EMA50 altında') : 'ölçülemedi'}, hacim ${finiteNumber(t.volumeRatio)?.toFixed(2) || '-'}x, risk ${riskLabel(item.riskScore)}.`,
      weight: item.scanScore
    };
  });
  const topText = ranked.slice(0, 5).map((x, i) => `${i + 1}. ${x.symbol} (${x.scanScore})`).join(', ');
  const raw = {
    answerTitle: `BIST piyasa taraması — ${headline}`,
    directAnswer: ranked.length ? `Canlı teknik taramada öne çıkan ilk hisseler: ${topText}. Bu sıralama fiyat serisi, RSI, EMA, MACD, hacim ve oynaklık ölçümlerine dayanır.` : 'Tarama sırasında yeterli canlı piyasa verisi alınamadı.',
    summary: `Trendora, BIST evrenindeki ${results.length} hisseden canlı verisi alınabilenleri karşılaştırdı ve ${headline} açısından puanladı. Liste kesin getiri vaadi değildir; tarama sonucu ve önceliklendirmedir.`,
    confidence,
    statistics: { trendStrength: avgTrend, dataConfidence: confidence, riskScore: ranked.length ? Math.round(ranked.reduce((s,x)=>s+x.riskScore,0)/ranked.length) : 50, newsImpact: 20, marketInterest: 55 },
    signals,
    keyFactors: ['Canlı günlük fiyat serisi', 'RSI ve EMA eğilimi', 'MACD yönü', '20 günlük hacim oranı', 'ATR tabanlı oynaklık', `${results.length} hisse karşılaştırıldı`],
    missingInformation: ['Tarama bilanço ve KAP verilerini tüm hisselerde aynı anda tam kapsamla doğrulamaz'],
    nextChecks: ['Listelenen her hisseyi tek tek açarak KAP, bilanço ve haber analiziyle doğrula', 'Zaman ufkunu gün/hafta/ay olarak ayrıca belirt'],
    sources: ranked.map(x => x.data.source).filter(Boolean),
    disclaimer: 'Bu liste yatırım tavsiyesi değildir. Teknik tarama, olasılık ve önceliklendirme amacı taşır.'
  };
  const normalized = normalizeAnalysis(raw, query, classification, sourcePlan);
  return { ...normalized, scanResults: ranked.map(x => ({ symbol:x.symbol, name:x.name, score:x.scanScore, riskScore:x.riskScore, riskLabel:riskLabel(x.riskScore), current:firstValidPrice(x.data.dailyPrice?.current,x.data.dailyPrice?.close), currency:x.data.currency, technical:x.data.technical })), engine: { version:'4.4.0', mode:'bist-market-scanner', usedLiveMarketData:true, usedLiveWebResearch:false, usedFallbackNews:false, entityRecognition:false, generatedAt:new Date().toISOString() } };
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
  const webTask = withTimeout(
    researchWithWeb(cleanedQuery, classification, sourcePlan),
    WEB_TIMEOUT_MS,
    'Web araştırması'
  );
  const evidenceTask = withTimeout(
    collectNewsEvidence(evidenceQuery, 24),
    FALLBACK_NEWS_TIMEOUT_MS,
    'Yedek haber taraması'
  );

  // Piyasa, web ve haber katmanları paralel çalışır. Bir kaynak yavaşlarsa
  // diğer sonuçlar bekletilmez.
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
  if (marketResult.status === 'rejected') console.error('Canlı piyasa verisi alınamadı:', marketResult.reason?.message || marketResult.reason);
  if (webError) console.error('Trendora web araştırması:', webError.message || webError);

  let base = webResult ? { ...webResult, dailyPrice:{...(webResult.dailyPrice||{})}, yearlyPrice:{...(webResult.yearlyPrice||{})}, estimatedRange:{...(webResult.estimatedRange||{})}, technical:{...(webResult.technical||{})}, statistics:{...(webResult.statistics||{})}, sources:[...(webResult.sources||[])] } : buildFallbackAnalysis(cleanedQuery, classification, evidence);

  if (marketData) {
    const current = firstValidPrice(marketData.dailyPrice?.current, marketData.dailyPrice?.close, marketData.dailyPrice?.open);
    const technicalScore = finiteNumber(marketData.technical?.score) ?? 50;
    const atrPercent = Math.abs(finiteNumber(marketData.technical?.atrPercent) || 0);
    const changePercent = Math.abs(finiteNumber(marketData.dailyPrice?.changePercent) || 0);
    const hasWeb = Boolean(webResult || evidence.length);
    const evidenceBonus = Math.min(10, Math.round((evidenceProfile.qualityScore + evidenceProfile.diversityScore) / 20));
    const confidence = Math.round(clamp(60 + Math.min(16, Math.abs(technicalScore - 50) * .35) + (webResult ? 7 : 0) + evidenceBonus, 55, 90));
    const riskScore = calibratedRiskScore(marketData, classification) + (hasWeb ? 0 : 3);
    const marketScenarios = buildMarketScenarios(marketData, classification);
    base.dailyPrice = { ...marketData.dailyPrice, current, close: firstValidPrice(marketData.dailyPrice?.close, current) };
    base.yearlyPrice = { ...marketData.yearlyPrice };
    base.technical = { ...(base.technical || {}), ...(marketData.technical || {}) };
    base.statistics = { ...(base.statistics || {}), trendStrength: technicalScore, dataConfidence: confidence, riskScore, marketInterest: Math.round(clamp((finiteNumber(marketData.technical?.volumeRatio) || 1) * 50, 0, 100)), newsImpact: hasWeb ? Math.round(clamp((finiteNumber(base.statistics?.newsImpact) ?? evidenceProfile.newsImpact) * 0.55 + evidenceProfile.newsImpact * 0.45, 0, 100)) : 15 };
    base.confidence = confidence;
    if (marketScenarios) { base.estimatedRange = marketScenarios.estimatedRange; base.scenarios = marketScenarios.scenarios; }
    base.signals = [
      ...buildTechnicalSignals(marketData.technical || {}),
      ...evidenceProfile.signals,
      ...(base.signals || []).filter(s => !/haber hacmi|olumlu başlık|olumsuz başlık/i.test(String(s?.title)))
    ].slice(0,10);
    base.keyFactors = [...new Set([
      ...(base.keyFactors || []),
      ...evidenceProfile.keyFactors,
      `Teknik skor: ${technicalScore}/100`,
      marketData.technical?.volumeRatio != null ? `Hacim oranı: ${Number(marketData.technical.volumeRatio).toFixed(2)}x` : null
    ].filter(Boolean))].slice(0, 10);
    base.sources = [marketData.source, ...(base.sources || []), ...evidence].filter(Boolean);
    base.missingInformation = removeFalseMissing(base.missingInformation, marketData);
    if (!hasWeb) base.missingInformation = [...new Set([...(base.missingInformation || []), 'Güncel haber ve KAP açıklamalarının tam taraması'])];
    const periodLabel = classification.period?.label || '3 Ay';
    const priceText = fmt(current, marketData.currency);
    const direction = technicalScore >= 65 ? 'pozitif' : technicalScore <= 42 ? 'negatif' : 'temkinli-nötr';
    base.answerTitle = `${periodLabel} finans değerlendirmesi`;
    base.directAnswer = `${marketData.displayName} güncel fiyatı ${priceText}. ${periodLabel} için teknik görünüm ${direction}; veri güveni %${confidence}, risk seviyesi ${riskLabel(riskScore)}.`;
    base.summary = `${periodLabel} ufku; canlı fiyat serisi, RSI, EMA, SMA, MACD, ATR, hacim, destek-direnç ve erişilebilen haber sinyalleri birlikte değerlendirilerek hesaplandı. Sonuç kesin fiyat tahmini değil, olasılık bandıdır.`;
  }

  const normalized = normalizeAnalysis(base, cleanedQuery, classification, sourcePlan);
  return { ...normalized, engine: { version:'4.4.0', mode: marketData && webResult ? 'market-plus-web' : marketData ? 'market-data' : webResult ? 'web-research' : 'limited-fallback', usedLiveMarketData:Boolean(marketData), usedLiveWebResearch:Boolean(webResult), usedFallbackNews:evidence.length>0, evidenceProfile, entityRecognition:classification.entity?.found||false, webResearchError:webError ? webError.message : null, sourceCoverage: { planned: Array.isArray(sourcePlan?.sources) ? sourcePlan.sources.map(s => s.name) : [], returned: normalized.sources.map(s => s.publisher), autoDiscovery: sourcePlan?.discovery?.enabled === true }, generatedAt:new Date().toISOString() } };
}
module.exports = { analyzeQuestion, normalizeAnalysis };
