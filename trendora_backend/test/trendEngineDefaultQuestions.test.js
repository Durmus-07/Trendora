'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  DEFAULT_QUESTIONS,
  analyzeQuery
} = require('../services/trendEngine');

test('otomatik trend turu yalnızca finans odaklı gram altın sorgusunu çalıştırır', () => {
  assert.deepEqual(DEFAULT_QUESTIONS, [
    'Gram altının kısa vadeli görünümü nasıl?'
  ]);
});

test('manuel analiz API işlevi korunur', () => {
  assert.equal(typeof analyzeQuery, 'function');
});
