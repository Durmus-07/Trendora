'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { isActive } = require('../routes/opportunities');

function daysAgo(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

test('store offers transported by Telegram keep the store freshness window', () => {
  assert.equal(isActive({
    source: 'telegram',
    store: 'Migros',
    title: 'Farklı Migros ürünü',
    updatedAt: daysAgo(10),
    active: true
  }), true);
  assert.equal(isActive({
    source: 'telegram',
    url: 'https://www.trendyol.com/urun/1',
    updatedAt: daysAgo(10),
    active: true
  }), true);
});

test('generic Telegram posts retain the bounded 72-hour freshness window', () => {
  assert.equal(isActive({
    source: 'telegram',
    title: 'Genel kanal paylaşımı',
    updatedAt: daysAgo(10),
    active: true
  }), false);
});
