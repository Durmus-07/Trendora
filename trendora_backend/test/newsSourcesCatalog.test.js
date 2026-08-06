'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { NEWS_SOURCES } = require('../services/newsCollector');

const names = NEWS_SOURCES.map(source => source.name);

function sourceNamed(name) {
  return NEWS_SOURCES.find(source => source.name === name);
}

test('haber kaynakları sadeleştirilir ve adlar benzersiz kalır', () => {
  assert.equal(NEWS_SOURCES.length, 80);
  assert.equal(new Set(names).size, names.length);
  assert.ok(NEWS_SOURCES.every(source => source.name && source.category));
});

test('temel ulusal ve uluslararası kaynaklar korunur', () => {
  for (const name of [
    'TRT Haber - Son Dakika',
    'Türkiye - Anadolu Ajansı',
    'Türkiye - NTV',
    'World - Reuters',
    'World - Associated Press',
    'World - Bloomberg',
    'BBC News - World RSS',
    'France 24 - English RSS',
    'DW - Top Stories RSS'
  ]) {
    assert.ok(sourceNamed(name), `${name} korunmalı`);
  }
});

test('tam metni belirsiz şehir bazlı Google News akışları otomatik turdan çıkarılır', () => {
  assert.equal(NEWS_SOURCES.some(source => source.city), false);
  assert.equal(NEWS_SOURCES.some(source => source.name.startsWith('Yerel - ')), false);
});

test('yabancı kaynaklar yalnızca Dünya kategorisinde yer alır', () => {
  const foreignSources = NEWS_SOURCES.filter(source => source.region === 'world');
  assert.ok(foreignSources.length > 0);
  assert.ok(foreignSources.every(source => source.category === 'dunya'));
});

test('tekrarlayan düşük öncelikli yabancı kaynaklar otomatik turdan çıkarılır', () => {
  for (const name of [
    'World - Europe',
    'World - United States',
    'World - BBC News',
    'World - The Guardian',
    'World - ESPN',
    'The Guardian - World RSS'
  ]) {
    assert.equal(sourceNamed(name), undefined, `${name} çıkarılmış olmalı`);
  }
});

test('tüm haber kategorilerinde kaynak kalır', () => {
  for (const category of ['son_dakika', 'gundem', 'dunya', 'ekonomi', 'spor', 'teknoloji']) {
    assert.ok(
      NEWS_SOURCES.some(source => source.category === category),
      `${category} kategorisi boş kalmamalı`
    );
  }
});
