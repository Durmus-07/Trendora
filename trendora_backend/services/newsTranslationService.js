'use strict';

const crypto = require('node:crypto');
const { normalizeUrl } = require('./newsContentService');
const { translateNewsFields } = require('./openai_service');

const TRANSLATION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_CACHE_ITEMS = 300;

function clean(value) {
  return String(value || '').trim();
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

function createNewsTranslationService(options = {}) {
  const translate = options.translate || translateNewsFields;
  const now = options.now || (() => Date.now());
  const cache = new Map();
  const inFlight = new Map();

  async function resolve(record, contentResult) {
    if (clean(record.language).toLowerCase() !== 'en') {
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
      const translated = await translate(fields);
      const timestamp = now();
      const result = {
        title: clean(translated.title),
        summary: clean(translated.summary),
        content: clean(translated.content),
        sourceLanguage: 'en',
        targetLanguage: 'tr',
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

module.exports = { createNewsTranslationService, translationKey };
