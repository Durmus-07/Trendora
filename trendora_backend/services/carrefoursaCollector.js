'use strict';

const { marketUrunleriniGetir } = require('./marketCollectorCore');

const CONFIG = {
  source: 'carrefoursa',
  seller: 'CarrefourSA',
  url: 'https://www.carrefoursa.com/firsatlar/c/9002',
  maxItems: 60,
  timeout: 30000
};

async function carrefoursaUrunleriniGetir(previousState = {}) {
  return marketUrunleriniGetir(CONFIG, previousState);
}

module.exports = { carrefoursaUrunleriniGetir };
