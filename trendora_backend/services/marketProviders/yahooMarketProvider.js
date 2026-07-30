const axios = require('axios');

const PROVIDER_ID = 'yahoo';
const PROVIDER_NAME = 'Yahoo Finance';

function isEnabled() {
  return String(process.env.TRENDORA_MARKET_PROVIDER_YAHOO_ENABLED || 'true').toLowerCase() !== 'false';
}

async function fetchChart(symbol, options = {}) {
  const range = options.range || '1y';
  const interval = options.interval || '1d';
  const timeout = Number(options.timeout || process.env.TRENDORA_MARKET_PROVIDER_TIMEOUT_MS || 12000);
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}`;

  const response = await axios.get(url, {
    params: {
      range,
      interval,
      includePrePost: false,
      events: 'div,splits'
    },
    timeout,
    headers: {
      'User-Agent': 'Mozilla/5.0 Trendora/1.0',
      Accept: 'application/json'
    }
  });

  const result = response?.data?.chart?.result?.[0];
  if (!result) {
    const error = new Error(`Yahoo Finance veri döndürmedi: ${symbol}`);
    error.code = 'MARKET_PROVIDER_EMPTY_RESULT';
    throw error;
  }

  return {
    providerId: PROVIDER_ID,
    providerName: PROVIDER_NAME,
    providerUrl: `https://finance.yahoo.com/quote/${encodeURIComponent(symbol)}`,
    result
  };
}

module.exports = {
  id: PROVIDER_ID,
  name: PROVIDER_NAME,
  isEnabled,
  fetchChart
};
