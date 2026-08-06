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

test('maps rate limit and timeout errors safely', () => {
  assert.equal(_test.safeError({ response: { status: 429 } }), 'quota_exceeded');
  assert.equal(_test.safeError({ code: 'ECONNABORTED' }), 'timeout');
});
