'use strict';

const axios = require('axios');

const CACHE_TTL_MS = 15 * 60 * 1000;
const MAX_CACHE_ITEMS = 200;
const cache = new Map();

function enabled(value) {
  return String(value || '').trim().toLowerCase() === 'true';
}

function normalizeQuery(value) {
  return String(value || '').trim().replace(/\s+/g, ' ');
}

function cacheKey(query) {
  return normalizeQuery(query).toLocaleLowerCase('tr-TR');
}

function getCached(query) {
  const item = cache.get(cacheKey(query));
  if (!item) return null;
  if (Date.now() - item.savedAt > CACHE_TTL_MS) {
    cache.delete(cacheKey(query));
    return null;
  }
  return { ...item.result, mode: 'cached', fallbackReason: 'providers_unavailable' };
}

function setCached(query, result) {
  if (cache.size >= MAX_CACHE_ITEMS) {
    const oldest = cache.keys().next().value;
    if (oldest) cache.delete(oldest);
  }
  cache.set(cacheKey(query), { savedAt: Date.now(), result });
}

function safeError(error) {
  const status = Number(error?.response?.status || 0);
  if (status === 429) return 'quota_exceeded';
  if (error?.code === 'ECONNABORTED') return 'timeout';
  return status >= 500 ? 'provider_unavailable' : 'request_failed';
}

async function askGemini(query) {
  if (!enabled(process.env.GEMINI_SEARCH_ENABLED)) return null;
  const apiKey = String(process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) return null;
  const model = String(process.env.GEMINI_MODEL || 'gemini-2.5-flash').trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const response = await axios.post(url, {
    systemInstruction: {
      parts: [{ text: 'Sen Trendora Arama Motorusun. Türkçe, kısa, dürüst ve anlaşılır cevap ver. Güncel veya kesin olmayan bilgileri kesinmiş gibi sunma. Kullanıcının aradığı şeyi doğrudan cevapla.' }]
    },
    contents: [{ role: 'user', parts: [{ text: query }] }],
    generationConfig: { temperature: 0.25, maxOutputTokens: 900 }
  }, {
    params: { key: apiKey },
    timeout: 12000,
    maxContentLength: 1_000_000
  });
  const answer = response.data?.candidates?.[0]?.content?.parts
    ?.map(part => String(part?.text || ''))
    .join('\n')
    .trim();
  if (!answer) throw new Error('empty_gemini_answer');
  return { success: true, mode: 'answer', provider: 'gemini', answer, results: [], fallbackReason: null };
}

async function searchBrave(query) {
  const apiKey = String(process.env.BRAVE_SEARCH_API_KEY || '').trim();
  if (!enabled(process.env.BRAVE_SEARCH_ENABLED) || !apiKey) return null;
  const response = await axios.get('https://api.search.brave.com/res/v1/web/search', {
    params: { q: query, count: 8, country: 'TR', search_lang: 'tr', safesearch: 'moderate' },
    headers: { Accept: 'application/json', 'X-Subscription-Token': apiKey },
    timeout: 10000,
    maxContentLength: 1_000_000
  });
  const results = (response.data?.web?.results || []).slice(0, 8).map(item => ({
    title: String(item?.title || 'Web sonucu'),
    snippet: String(item?.description || ''),
    url: String(item?.url || ''),
    source: (() => { try { return new URL(item?.url || '').hostname.replace(/^www\./, ''); } catch (_) { return 'Web'; } })()
  })).filter(item => /^https?:\/\//i.test(item.url));
  if (!results.length) throw new Error('empty_brave_results');
  return { success: true, mode: 'web_results', provider: 'brave', answer: 'Güncel web sonuçlarına göre bulduğum seçenekler:', results, fallbackReason: null };
}

async function searchTavily(query) {
  const apiKey = String(process.env.TAVILY_API_KEY || '').trim();
  if (!enabled(process.env.TAVILY_SEARCH_ENABLED) || !apiKey) return null;
  const response = await axios.post('https://api.tavily.com/search', {
    api_key: apiKey,
    query,
    search_depth: 'basic',
    max_results: 8,
    include_answer: true,
    include_raw_content: false
  }, { timeout: 10000, maxContentLength: 1_000_000 });
  const results = (response.data?.results || []).slice(0, 8).map(item => ({
    title: String(item?.title || 'Web sonucu'),
    snippet: String(item?.content || ''),
    url: String(item?.url || ''),
    source: (() => { try { return new URL(item?.url || '').hostname.replace(/^www\./, ''); } catch (_) { return 'Web'; } })()
  })).filter(item => /^https?:\/\//i.test(item.url));
  if (!results.length) throw new Error('empty_tavily_results');
  return {
    success: true,
    mode: 'web_results',
    provider: 'tavily',
    answer: String(response.data?.answer || 'Güncel web sonuçlarına göre bulduğum seçenekler:'),
    results,
    fallbackReason: null
  };
}

async function answerSmartSearch(query) {
  const normalized = normalizeQuery(query);
  if (!normalized) return { success: false, status: 400, errorType: 'invalid_query' };
  if (normalized.length > 500) return { success: false, status: 413, errorType: 'query_too_long' };

  let fallbackReason = null;
  for (const provider of [askGemini, searchBrave, searchTavily]) {
    try {
      const result = await provider(normalized);
      if (!result) continue;
      const complete = { ...result, fallbackReason };
      setCached(normalized, complete);
      return complete;
    } catch (error) {
      fallbackReason = safeError(error);
    }
  }

  const cached = getCached(normalized);
  if (cached) return { success: true, ...cached };
  return {
    success: false,
    status: 503,
    errorType: 'search_unavailable',
    message: 'Trendora Arama şu anda güncel sonuçlara ulaşamıyor.'
  };
}

module.exports = { answerSmartSearch, _test: { cache, normalizeQuery, safeError } };
