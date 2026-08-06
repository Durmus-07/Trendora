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

function needsAiSummary(query) {
  const normalized = normalizeQuery(query).toLocaleLowerCase('tr-TR');
  const words = normalized.split(' ').filter(Boolean);
  if (words.length >= 5) return true;
  return /\b(neden|nasıl|nasil|hangisi|karşılaştır|karsilastir|öner|oner|en iyi|en uygun|planla|açıkla|acikla|yorumla|sırala|sirala)\b/i.test(normalized);
}

function extractInteractionText(data) {
  const texts = [];
  for (const step of Array.isArray(data?.steps) ? data.steps : []) {
    const contents = step?.content || step?.model_output?.content || step?.modelOutput?.content;
    for (const item of Array.isArray(contents) ? contents : []) {
      if (typeof item?.text === 'string') texts.push(item.text);
      else if (typeof item?.text?.text === 'string') texts.push(item.text.text);
    }
  }
  if (typeof data?.output_text === 'string') texts.push(data.output_text);
  if (typeof data?.outputText === 'string') texts.push(data.outputText);
  return texts.map(text => String(text).trim()).filter(Boolean).join('\n').trim();
}

function logProviderError(provider, error) {
  const status = Number(error?.response?.status || 0);
  const payload = error?.response?.data?.error || error?.response?.data || {};
  const message = String(payload?.message || error?.message || 'provider_error').slice(0, 300);
  const reason = String(payload?.status || payload?.reason || '').slice(0, 80);
  console.warn(JSON.stringify({
    level: 'warn',
    event: 'smart_search_provider_error',
    provider,
    status,
    reason,
    message
  }));
}

async function requestGeminiInteraction(apiKey, model, input) {
  return axios.post('https://generativelanguage.googleapis.com/v1beta/interactions', {
    model,
    input,
    system_instruction: 'Sen Trendora Arama Motorusun. Yalnızca verilen web sonuçlarına dayan. Türkçe, kısa, dürüst ve anlaşılır cevap ver. Sonuçları karşılaştır, kullanıcının isteğine göre sırala; kaynaklarda bulunmayan fiyat, puan veya ayrıntıyı uydurma. Sağlayıcı adlarından bahsetme.'
  }, {
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey
    },
    timeout: 12000,
    maxContentLength: 1_000_000
  });
}

async function askGemini(query, results = []) {
  if (!enabled(process.env.GEMINI_SEARCH_ENABLED)) return null;
  const apiKey = String(process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) return null;

  const configuredModel = String(process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite').trim();
  const models = [...new Set([configuredModel, 'gemini-3.1-flash-lite'].filter(Boolean))];
  const context = results.length
    ? results.slice(0, 8).map((item, index) => [
        `${index + 1}. ${item.title}`,
        item.snippet,
        `Kaynak: ${item.source}`,
        `URL: ${item.url}`
      ].filter(Boolean).join('\n')).join('\n\n')
    : 'Güncel web sonucu bulunamadı.';
  const input = `Kullanıcı sorgusu: ${query}\n\nGüncel web sonuçları:\n${context}\n\nKullanıcıya doğrudan yararlı bir Trendora özeti hazırla.`;
  let lastError = null;

  for (const model of models) {
    try {
      const response = await requestGeminiInteraction(apiKey, model, input);
      const answer = extractInteractionText(response.data);
      if (!answer) throw new Error('empty_gemini_answer');
      return answer;
    } catch (error) {
      lastError = error;
      logProviderError('gemini', error);
      if (Number(error?.response?.status || 0) !== 404) break;
    }
  }

  throw lastError || new Error('gemini_request_failed');
}

async function searchBrave(query) {
  const apiKey = String(process.env.BRAVE_SEARCH_API_KEY || '').trim();
  if (!enabled(process.env.BRAVE_SEARCH_ENABLED) || !apiKey) return [];
  const response = await axios.get('https://api.search.brave.com/res/v1/web/search', {
    params: { q: query, count: 8, country: 'TR', search_lang: 'tr', safesearch: 'moderate' },
    headers: { Accept: 'application/json', 'X-Subscription-Token': apiKey },
    timeout: 10000,
    maxContentLength: 1_000_000
  });
  return (response.data?.web?.results || []).slice(0, 8).map(item => ({
    title: String(item?.title || 'Web sonucu'),
    snippet: String(item?.description || ''),
    url: String(item?.url || ''),
    source: (() => { try { return new URL(item?.url || '').hostname.replace(/^www\./, ''); } catch (_) { return 'Web'; } })()
  })).filter(item => /^https?:\/\//i.test(item.url));
}

async function searchTavily(query) {
  const apiKey = String(process.env.TAVILY_API_KEY || '').trim();
  if (!enabled(process.env.TAVILY_SEARCH_ENABLED) || !apiKey) return [];
  const response = await axios.post('https://api.tavily.com/search', {
    api_key: apiKey,
    query,
    search_depth: 'basic',
    max_results: 8,
    include_answer: false,
    include_raw_content: false
  }, { timeout: 10000, maxContentLength: 1_000_000 });
  return (response.data?.results || []).slice(0, 8).map(item => ({
    title: String(item?.title || 'Web sonucu'),
    snippet: String(item?.content || ''),
    url: String(item?.url || ''),
    source: (() => { try { return new URL(item?.url || '').hostname.replace(/^www\./, ''); } catch (_) { return 'Web'; } })()
  })).filter(item => /^https?:\/\//i.test(item.url));
}

function mergeResults(...groups) {
  const seen = new Set();
  const merged = [];
  for (const item of groups.flat()) {
    const key = String(item?.url || '').replace(/\/$/, '').toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    merged.push(item);
    if (merged.length >= 8) break;
  }
  return merged;
}

async function collectWebResults(query) {
  let brave = [];
  let tavily = [];
  let fallbackReason = null;

  try {
    brave = await searchBrave(query);
  } catch (error) {
    logProviderError('brave', error);
    fallbackReason = safeError(error);
  }

  if (brave.length < 5) {
    try {
      tavily = await searchTavily(query);
    } catch (error) {
      logProviderError('tavily', error);
      fallbackReason = fallbackReason || safeError(error);
    }
  }

  return { results: mergeResults(brave, tavily), fallbackReason };
}

async function answerSmartSearch(query) {
  const normalized = normalizeQuery(query);
  if (!normalized) return { success: false, status: 400, errorType: 'invalid_query' };
  if (normalized.length > 500) return { success: false, status: 413, errorType: 'query_too_long' };

  const web = await collectWebResults(normalized);
  if (web.results.length) {
    let answer = 'Trendora’nın bulduğu güncel sonuçlar:';
    let mode = 'web_results';
    let provider = 'web';
    let fallbackReason = web.fallbackReason;

    if (needsAiSummary(normalized)) {
      try {
        const summary = await askGemini(normalized, web.results);
        if (summary) {
          answer = summary;
          mode = 'answer_with_results';
          provider = 'trendora';
        }
      } catch (error) {
        fallbackReason = fallbackReason || safeError(error);
      }
    }

    const result = {
      success: true,
      mode,
      provider,
      answer,
      results: web.results,
      fallbackReason
    };
    setCached(normalized, result);
    return result;
  }

  try {
    const answer = await askGemini(normalized);
    if (answer) {
      const result = {
        success: true,
        mode: 'answer',
        provider: 'trendora',
        answer,
        results: [],
        fallbackReason: web.fallbackReason
      };
      setCached(normalized, result);
      return result;
    }
  } catch (error) {
    logProviderError('gemini', error);
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

module.exports = {
  answerSmartSearch,
  _test: {
    cache,
    normalizeQuery,
    safeError,
    needsAiSummary,
    mergeResults,
    extractInteractionText
  }
};
