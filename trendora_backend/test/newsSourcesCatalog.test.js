'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { NEWS_SOURCES } = require('../services/newsCollector');

const names = NEWS_SOURCES.map(source => source.name);

function sourceNamed(name) {
  return NEWS_SOURCES.find(source => source.name === name);
}

test('haber kaynakları sadeleştirilir ve adlar benzersiz kalır', () => {
  assert.equal(NEWS_SOURCES.length, 100);
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

test('şehir bazlı yerel kaynaklar Türkiye bölgelerini temsil eder', () => {
  const expectedCities = [
    'Antalya', 'Isparta', 'Burdur', 'Kahramanmaraş', 'Adana', 'Mersin',
    'Hatay', 'Gaziantep', 'Ankara', 'İstanbul', 'İzmir', 'Bursa', 'Konya',
    'Kayseri', 'Eskişehir', 'Samsun', 'Trabzon', 'Diyarbakır', 'Şanlıurfa',
    'Muğla'
  ];

  for (const city of expectedCities) {
    const source = sourceNamed(`Yerel - ${city}`);
    assert.ok(source, `${city} yerel kaynağı bulunmalı`);
    assert.equal(source.category, 'gundem');
    assert.equal(source.region, 'tr');
    assert.equal(source.city, city);
    assert.ok(source.area);
    assert.match(source.googleQuery, new RegExp(city, 'i'));
  }

  const representedAreas = new Set(
    NEWS_SOURCES.filter(source => source.city).map(source => source.area)
  );
  for (const area of ['Akdeniz', 'Marmara', 'Ege', 'İç Anadolu', 'Karadeniz', 'Güneydoğu Anadolu']) {
    assert.ok(representedAreas.has(area), `${area} temsil edilmeli`);
  }
});

test('yerel kaynaklar doğrudan site kazımak yerine Google News açık indeksini kullanır', () => {
  const localSources = NEWS_SOURCES.filter(source => source.city);
  assert.equal(localSources.length, 20);
  assert.ok(localSources.every(source => source.googleQuery && !source.url));
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
