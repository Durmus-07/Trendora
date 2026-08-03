'use strict';

const { detectIntent, normalizeText } = require('./trend/intentEngine');
const { matchAsset, findAssetCandidates } = require('./assets/assetMatcher');

const INTENT_WORDS = /(?:analiz\s*et|kaç\s*(?:tl|lira)|ne\s*kadar|fiyat(?:ı|i)?|analiz(?:i|ini)?|görünümü|gorunumu|hisse(?:si)?|bugün|bugun|nedir|ne\s*durumda)/giu;

function appIntent(query) {
  const normalized = normalizeText(query);
  if (/kaydettiğim|kaydetigim|favorilerim/.test(normalized)) return 'saved_items';
  if (/son dakika|son dakka|son gelişme/.test(normalized)) return 'breaking_news';
  if (/haber/.test(normalized)) return 'news_search';
  if (/fırsat|firsat|indirim|kampanya/.test(normalized)) return 'opportunities_search';
  if (/analiz|görünüm|gorunum|kısa vade|kisa vade/.test(normalized)) return 'market_analysis';
  if (/kaç\s*(?:tl|lira)|ne kadar|fiyat/.test(normalized)) return 'market_price';
  const trendIntent = detectIntent(query);
  if (trendIntent.type !== 'general_analysis') return 'market_analysis';
  if (/\?|\b(?:nedir|ne demek|nasıl|nasil|neden)\b/.test(normalized) && normalized.length >= 8) return 'general_question';
  return 'unknown';
}

function assetQuery(query) {
  return String(query || '').replace(INTENT_WORDS, ' ').replace(/[?!,;:]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function candidateCard(candidate) {
  return { ...candidate.asset, matchedBy: candidate.matchType, matchedValue: candidate.matchedValue, confidence: candidate.confidence };
}

function resolveAsset(query) {
  const extracted = assetQuery(query);
  if (!extracted) return { status: 'not_found', asset: null, candidates: [] };
  const match = matchAsset(extracted);
  if (match.matched) {
    return { status: 'matched', asset: { ...match.asset, matchedBy: match.matchType, matchedValue: extracted, confidence: match.confidence }, candidates: [] };
  }
  const candidates = (match.candidates?.length ? match.candidates : findAssetCandidates(extracted))
    .filter(item => Number(item.confidence) >= 0.88).slice(0, 5).map(candidateCard);
  return { status: candidates.length > 1 ? 'selection_required' : 'not_found', asset: null, candidates };
}

function createSmartSearchPlan(query) {
  const rawQuery = String(query || '').trim();
  const normalizedQuery = normalizeText(rawQuery);
  const requestedIntent = appIntent(rawQuery);
  const isMarket = requestedIntent === 'market_price' || requestedIntent === 'market_analysis';
  const resolution = isMarket ? resolveAsset(rawQuery) : { status: 'not_applicable', asset: null, candidates: [] };
  const intent = resolution.status === 'selection_required' ? 'asset_selection' : requestedIntent;
  const filters = {};
  if (requestedIntent === 'breaking_news') filters.breaking = true;
  if (requestedIntent === 'news_search') {
    if (/teknoloji/.test(normalizedQuery)) filters.category = 'teknoloji';
    if (/ekonomi/.test(normalizedQuery)) filters.category = 'ekonomi';
  }
  if (requestedIntent === 'opportunities_search') {
    if (/migros|migors/.test(normalizedQuery)) filters.source = 'migros';
    if (/\bbim\b/.test(normalizedQuery)) filters.source = 'bim';
  }
  return {
    success: true, rawQuery, normalizedQuery, intent, requestedIntent,
    confidence: resolution.asset?.confidence || 0,
    assetResolution: resolution.status, asset: resolution.asset, candidates: resolution.candidates, filters,
    service: requestedIntent === 'general_question' ? 'ai' :
      requestedIntent.startsWith('market_') ? 'market_board' :
      requestedIntent.includes('news') ? 'news' :
      requestedIntent.includes('opportunities') ? 'opportunities' :
      requestedIntent === 'saved_items' ? 'saved_items' : null
  };
}

module.exports = { appIntent, assetQuery, resolveAsset, createSmartSearchPlan };
