'use strict';

const { marketUrunleriniGetir } = require('./marketCollectorCore');

const CONFIG = {
  source: 'a101',
  seller: 'A101',
  url: 'https://www.a101.com.tr/',
  maxItems: 60,
  timeout: 30000
};

async function a101UrunleriniGetir(previousState = {}) {
  return marketUrunleriniGetir(CONFIG, previousState);
}

module.exports = { a101UrunleriniGetir };
