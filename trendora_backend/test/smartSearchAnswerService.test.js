'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { answerSmartSearch, _test } = require('../services/smartSearchAnswerService');

function clearEnv() {
  for (const key of [
    'GEMINI_SEARCH_ENABLED', 'GEMINI_API_KEY', 'GEMINI_MODEL',
    'BRAVE_SEARCH_ENABLED', 'BRAVE_SEARCH_API_KEY',
    'TAVILY_SEARCH_ENABLED', 'TAVILY_API_KEY'
  ]) delete process.env[key];
  _test.cache.clear();
}

test.afterEach(clearEnv);

test('empty and oversized queries are rejected', async () => {
  assert.equal((await answerSmartSearch(' ')).status, 400);
  assert.equal((await answerSmartSearch('a'.repeat(501))).status, 413);
});

test('returns safe unavailable response when no provider is configured', async () => {
  const result = await answerSmartSearch('Antalya uygun oteller');
  assert.equal(result.success, false);
  assert.equal(result.status, 503);
  assert.equal(result.errorType, 'search_unavailable');
});

test('normalizes repeated whitespace', () => {
  assert.equal(_test.normalizeQuery('  Antalya   otel '), 'Antalya otel');
});

test('uses simple query mode for short keyword searches', () => {
  assert.equal(_test.needsAiSummary('Antalya'), false);
  assert.equal(_test.needsAiSummary('Antalya otelleri'), false);
});

test('uses AI summary mode for explanation and comparison searches', () => {
  assert.equal(_test.needsAiSummary('Antalya’da en uygun otelleri sırala'), true);
  assert.equal(_test.needsAiSummary('Bu seçeneklerden hangisi daha iyi'), true);
});

test('merges and deduplicates web results', () => {
  const merged = _test.mergeResults(
    [{ title: 'A', url: 'https://a.com/' }],
    [{ title: 'A2', url: 'https://a.com' }, { title: 'B', url: 'https://b.com' }]
  );
  assert.equal(merged.length, 2);
  assert.equal(merged[1].title, 'B');
});

test('maps rate limit and timeout errors safely', () => {
  assert.equal(_test.safeError({ response: { status: 429 } }), 'quota_exceeded');
  assert.equal(_test.safeError({ code: 'ECONNABORTED' }), 'timeout');
});

test('extracts text from Gemini Interactions response', () => {
  const text = _test.extractInteractionText({
    steps: [
      { type: 'thought' },
      { type: 'model_output', content: [{ type: 'text', text: 'Merhaba' }] }
    ]
  });
  assert.equal(text, 'Merhaba');
});

test('short search returns web cards without calling Gemini', async () => {
  const axios = require('axios');
  const originalGet = axios.get;
  const originalPost = axios.post;
  let geminiCalls = 0;
  axios.get = async () => ({
    data: { web: { results: [
      { title: 'Antalya', description: 'Şehir rehberi', url: 'https://example.com/antalya' }
    ] } }
  });
  axios.post = async () => {
    geminiCalls += 1;
    throw new Error('Gemini should not run');
  };

  try {
    process.env.BRAVE_SEARCH_ENABLED = 'true';
    process.env.BRAVE_SEARCH_API_KEY = 'brave-key';
    const result = await answerSmartSearch('Antalya');
    assert.equal(result.success, true);
    assert.equal(result.mode, 'web_results');
    assert.equal(result.results.length, 1);
    assert.equal(geminiCalls, 0);
  } finally {
    axios.get = originalGet;
    axios.post = originalPost;
  }
});

test('complex search returns web cards with Gemini summary', async () => {
  const axios = require('axios');
  const originalGet = axios.get;
  const originalPost = axios.post;
  const calls = [];
  axios.get = async () => ({
    data: { web: { results: [
      { title: 'Otel A', description: 'Uygun otel', url: 'https://example.com/a' }
    ] } }
  });
  axios.post = async (url, body, config) => {
    calls.push({ url, body, config });
    if (url.includes('/interactions')) {
      return { data: { steps: [{ type: 'model_output', content: [{ type: 'text', text: 'Otel A öne çıkıyor.' }] }] } };
    }
    return { data: { results: [] } };
  };

  try {
    process.env.BRAVE_SEARCH_ENABLED = 'true';
    process.env.BRAVE_SEARCH_API_KEY = 'brave-key';
    process.env.GEMINI_SEARCH_ENABLED = 'true';
    process.env.GEMINI_API_KEY = 'gemini-key';
    const result = await answerSmartSearch('Antalya’da en uygun otelleri sırala');
    assert.equal(result.success, true);
    assert.equal(result.mode, 'answer_with_results');
    assert.equal(result.answer, 'Otel A öne çıkıyor.');
    assert.equal(result.results.length, 1);
    assert.equal(calls.some(call => call.url.includes('/interactions')), true);
  } finally {
    axios.get = originalGet;
    axios.post = originalPost;
  }
});
