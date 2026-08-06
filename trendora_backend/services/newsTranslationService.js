'use strict';

const crypto = require('node:crypto');
const axios = require('axios');
const { normalizeUrl } = require('./newsContentService');
const {
  isOpenAiConfigured,
  translateNewsFields
} = require('./openai_service');

const TRANSLATION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_CACHE_ITEMS = 300;
const GOOGLE_CHUNK_BYTES = 3500;
const MYMEMORY_CHUNK_BYTES = 450;
const ENGLISH_SOURCE_HINTS = [
  'associated press',
  'al jazeera',
  'ars technica',
  'bbc news',
  'bbc.co.uk',
  'bloomberg',
  'cnbc',
  'cnn',
  'deutsche welle',
  'dw - top stories',
  'financial times',
  'france 24',
  'france24.com/en',
  'guardian',
  'marketwatch',
  'mit technology review',
  'new york times',
  'politico',
  'reuters',
  'techcrunch',
  'the economist',
  'wall street journal',
  'washington post',
  'wired',
  'apnews.com',
  'aljazeera.com',
  'arstechnica.com',
  'ft.com',
  'nytimes.com',
  'theguardian.com',
  'washingtonpost.com',
  'wsj.com'
];

function clean(value) {
  return String(value || '').trim();
}

function normalizedIdentityText(value) {
  return clean(value).toLowerCase();
}

function isEnglishNews(record = {}) {
  const language = normalizedIdentityText(record.language);
  if (language === 'en' || language.startsWith('en-') ||
      language.startsWith('en_')) {
    return true;
  }

  const sourceIdentity = [
    record.source,
    record.sourceName,
    record.feedSource,
    record.feed,
    record.url
  ].map(normalizedIdentityText).join(' ');

  return ENGLISH_SOURCE_HINTS.some(hint => sourceIdentity.includes(hint));
}

function translationKey(record, fields) {
  const identity = clean(record.id) || normalizeUrl(record.url);
  if (!identity) return '';
  const digest = crypto
    .createHash('sha256')
    .update(JSON.stringify(fields))
    .digest('hex');
  return `${identity}:${digest}`;
}

function splitUtf8(text, maxBytes = GOOGLE_CHUNK_BYTES) {
  const value = clean(text);
  if (!value) return [];

  const chunks = [];
  let current = '';

  for (const character of value) {
    const candidate = current + character;
    if (Buffer.byteLength(candidate, 'utf8') <= maxBytes) {
      current = candidate;
      continue;
    }
    if (current) chunks.push(current);
    current = character;
  }
  if (current) chunks.push(current);
  return chunks;
}

function googleTranslationText(data) {
  if (!Array.isArray(data?.[0])) return '';
  return clean(data[0]
    .map(part => Array.isArray(part) ? part[0] : '')
    .join(''));
}

async function translateChunkWithGoogle(text, options = {}) {
  const http = options.http || axios;
  const response = await http.get(
    'https://translate.googleapis.com/translate_a/single',
    {
      params: {
        client: 'gtx',
        sl: 'en',
        tl: 'tr',
        dt: 't',
        q: text
      },
      timeout: 10000,
      maxContentLength: 512 * 1024,
      validateStatus: status => status >= 200 && status < 300
    }
  );
  const translated = googleTranslationText(response?.data);
  if (!translated) {
    const error = new Error('Google temel ceviri servisi bos yanit dondurdu.');
    error.code = 'GOOGLE_TRANSLATION_EMPTY';
    throw error;
  }
  return translated;
}

async function translateChunkWithMyMemory(text, options = {}) {
  const http = options.http || axios;
  const response = await http.get(
    'https://api.mymemory.translated.net/get',
    {
      params: { q: text, langpair: 'en|tr', mt: 1 },
      timeout: 10000,
      maxContentLength: 256 * 1024,
      validateStatus: status => status >= 200 && status < 300
    }
  );
  const translated = clean(response?.data?.responseData?.translatedText);
  if (!translated) {
    const error = new Error('MyMemory temel ceviri servisi bos yanit dondurdu.');
    error.code = 'MYMEMORY_TRANSLATION_EMPTY';
    throw error;
  }
  return translated;
}

async function translateTextWithMyMemory(text, options = {}) {
  const chunks = splitUtf8(text, MYMEMORY_CHUNK_BYTES);
  const translated = [];
  for (const chunk of chunks) {
    translated.push(await translateChunkWithMyMemory(chunk, options));
  }
  return translated.join('');
}

async function translateTextWithFallback(text, options = {}) {
  const chunks = splitUtf8(text, GOOGLE_CHUNK_BYTES);
  if (chunks.length === 0) return '';

  const translated = [];
  for (const chunk of chunks) {
    try {
      translated.push(await translateChunkWithGoogle(chunk, options));
    } catch (googleError) {
      console.warn(
        '[NEWS TRANSLATION] Google temel ceviri kullanilamadi, ' +
        'MyMemory deneniyor:',
        googleError?.response?.status || googleError?.code || googleError?.message
      );
      translated.push(await translateTextWithMyMemory(chunk, options));
    }
  }
  return translated.join('');
}

async function translateNewsFieldsWithFallback(fields, options = {}) {
  const translateText = options.translateText ||
    (text => translateTextWithFallback(text, options));

  // Ücretsiz servislerde kota patlamasını önlemek için alanları sırayla çevir.
  const title = await translateText(fields.title);
  const summary = await translateText(fields.summary);
  const content = await translateText(fields.content);
  return { title, summary, content };
}

function createNewsTranslationService(options = {}) {
  const translate = options.translate || translateNewsFields;
  const fallbackTranslate = options.fallbackTranslate ||
    (fields => translateNewsFieldsWithFallback(fields, options));
  const now = options.now || (() => Date.now());
  const cache = new Map();
  const inFlight = new Map();

  async function resolve(record, contentResult) {
    if (!isEnglishNews(record)) {
      const error = new Error('Yalnizca Ingilizce haberler cevrilebilir.');
      error.code = 'UNSUPPORTED_LANGUAGE';
      throw error;
    }

    const fields = {
      title: clean(record.title),
      summary: clean(record.description || record.summary),
      content: clean(contentResult?.content || record.content)
    };
    const key = translationKey(record, fields);
    if (!key) {
      const error = new Error('Haber kimligi bulunamadi.');
      error.code = 'INVALID_NEWS';
      throw error;
    }

    const cached = cache.get(key);
    if (cached && cached.expiresAtMs > now()) {
      return { ...cached, cached: true };
    }
    if (inFlight.has(key)) return inFlight.get(key);

    const task = (async () => {
      let translated;
      let translationProvider = 'basic';

      try {
        translated = await fallbackTranslate(fields);
      } catch (basicError) {
        if (!isOpenAiConfigured()) throw basicError;

        console.warn(
          '[NEWS TRANSLATION] Temel ceviri kullanilamadi, AI deneniyor:',
          basicError?.response?.status || basicError?.code || basicError?.message
        );
        translated = await translate(fields);
        translationProvider = 'ai';
      }

      const timestamp = now();
      const result = {
        title: clean(translated.title),
        summary: clean(translated.summary),
        content: clean(translated.content),
        sourceLanguage: 'en',
        targetLanguage: 'tr',
        translationProvider,
        translatedAt: new Date(timestamp).toISOString(),
        expiresAtMs: timestamp + TRANSLATION_TTL_MS
      };
      if (!result.title || (fields.summary && !result.summary) ||
          (fields.content && !result.content)) {
        throw new Error('Ceviri yaniti eksik alan iceriyor.');
      }
      if (cache.size >= MAX_CACHE_ITEMS && !cache.has(key)) {
        cache.delete(cache.keys().next().value);
      }
      cache.set(key, result);
      return { ...result, cached: false };
    })().finally(() => inFlight.delete(key));

    inFlight.set(key, task);
    return task;
  }

  return { resolve };
}

module.exports = {
  createNewsTranslationService,
  isEnglishNews,
  splitUtf8,
  googleTranslationText,
  translateNewsFieldsWithFallback,
  translationKey
};
