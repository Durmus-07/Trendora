'use strict';

const { marketUrunleriniGetir } = require('./marketCollectorCore');

const CONFIG = {
  source: 'migros',
  seller: 'Migros',
  url: 'https://www.migros.com.tr/tum-indirimli-urunler-dt-0',
  maxItems: 60,
  timeout: 30000
};

async function migrosUrunleriniGetir(previousState = {}) {
  return marketUrunleriniGetir(CONFIG, previousState);
}

module.exports = { migrosUrunleriniGetir };
