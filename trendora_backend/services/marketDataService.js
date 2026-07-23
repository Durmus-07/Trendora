const axios = require('axios');

const BIST_ALIASES = {
  ASELS: 'ASELS.IS', ASELSAN: 'ASELS.IS',
  TUPRS: 'TUPRS.IS', TUPRAS: 'TUPRS.IS', TÜPRAŞ: 'TUPRS.IS',
  THYAO: 'THYAO.IS', THY: 'THYAO.IS',
  BIMAS: 'BIMAS.IS', BIM: 'BIMAS.IS',
  GARAN: 'GARAN.IS', GARANTI: 'GARAN.IS',
  KCHOL: 'KCHOL.IS', KOC: 'KCHOL.IS', KOÇ: 'KCHOL.IS',
  ISCTR: 'ISCTR.IS', ISBANK: 'ISCTR.IS',
  EREGL: 'EREGL.IS', EREGLI: 'EREGL.IS', EREĞLİ: 'EREGL.IS',
  SISE: 'SISE.IS', ŞİŞE: 'SISE.IS',
  AKBNK: 'AKBNK.IS', YKBNK: 'YKBNK.IS', SAHOL: 'SAHOL.IS',
  PETKM: 'PETKM.IS', FROTO: 'FROTO.IS', TOASO: 'TOASO.IS',
  TCELL: 'TCELL.IS', ENKAI: 'ENKAI.IS', HEKTS: 'HEKTS.IS'
};

function normalizeTurkish(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/İ/g, 'I')
    .replace(/Ş/g, 'S')
    .replace(/Ğ/g, 'G')
    .replace(/Ü/g, 'U')
    .replace(/Ö/g, 'O')
    .replace(/Ç/g, 'C');
}

function resolveYahooSymbol(query, classification) {
  const entitySymbol = normalizeTurkish(classification?.entity?.symbol);
  const entityName = normalizeTurkish(classification?.entity?.name);
  const cleanedQuery = normalizeTurkish(query);

  const candidates = [entitySymbol, entityName, cleanedQuery]
    .filter(Boolean)
    .flatMap((item) => item.split(/[^A-Z0-9.]+/).filter(Boolean));

  for (const candidate of candidates) {
    if (BIST_ALIASES[candidate]) return BIST_ALIASES[candidate];
    if (/^[A-Z]{3,6}\.IS$/.test(candidate)) return candidate;
    if (/^[A-Z]{3,6}$/.test(candidate) && cleanedQuery.includes('HISSE')) {
      return `${candidate}.IS`;
    }
  }

  if (/ALTIN|GOLD/.test(cleanedQuery)) return 'GC=F';
  if (/GUMUS|SILVER/.test(cleanedQuery)) return 'SI=F';
  if (/BITCOIN|BTC/.test(cleanedQuery)) return 'BTC-USD';
  if (/ETHEREUM|ETH/.test(cleanedQuery)) return 'ETH-USD';
  if (/DOLAR|USDTRY|USD\/TRY/.test(cleanedQuery)) return 'TRY=X';
  if (/EURO|EURTRY|EUR\/TRY/.test(cleanedQuery)) return 'EURTRY=X';

  return null;
}

function finite(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function average(values) {
  const clean = values.filter(Number.isFinite);
  if (!clean.length) return null;
  return clean.reduce((sum, value) => sum + value, 0) / clean.length;
}

function sma(values, period) {
  if (!Array.isArray(values) || values.length < period) return null;
  return average(values.slice(-period));
}

function rsi(values, period = 14) {
  if (!Array.isArray(values) || values.length <= period) return null;
  const window = values.slice(-(period + 1));
  let gains = 0;
  let losses = 0;
  for (let i = 1; i < window.length; i += 1) {
    const change = window[i] - window[i - 1];
    if (change >= 0) gains += change;
    else losses += Math.abs(change);
  }
  if (losses === 0) return 100;
  const rs = (gains / period) / (losses / period);
  return 100 - (100 / (1 + rs));
}

function calculateVwap(high, low, close, volume) {
  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < close.length; i += 1) {
    const h = finite(high[i]);
    const l = finite(low[i]);
    const c = finite(close[i]);
    const v = finite(volume[i]);
    if (h == null || l == null || c == null || v == null || v <= 0) continue;
    numerator += ((h + l + c) / 3) * v;
    denominator += v;
  }
  return denominator > 0 ? numerator / denominator : average(close);
}

function buildTechnicalScore({ current, sma20, sma50, sma200, rsi14, volumeRatio, changePercent }) {
  let score = 50;
  if (current != null && sma20 != null) score += current >= sma20 ? 8 : -8;
  if (current != null && sma50 != null) score += current >= sma50 ? 8 : -8;
  if (current != null && sma200 != null) score += current >= sma200 ? 10 : -10;
  if (sma20 != null && sma50 != null) score += sma20 >= sma50 ? 7 : -7;
  if (rsi14 != null) {
    if (rsi14 >= 50 && rsi14 <= 70) score += 7;
    else if (rsi14 > 75) score -= 7;
    else if (rsi14 < 35) score -= 6;
  }
  if (volumeRatio != null) score += volumeRatio >= 1.2 ? 5 : volumeRatio < 0.7 ? -3 : 0;
  if (changePercent != null) score += Math.max(-7, Math.min(7, changePercent * 1.5));
  return Math.max(0, Math.min(100, Math.round(score)));
}

function signalFromScore(score) {
  if (score >= 67) return 'positive';
  if (score <= 43) return 'negative';
  return 'neutral';
}

async function fetchMarketData(query, classification) {
  if (classification?.domain !== 'finance') return null;

  const symbol = resolveYahooSymbol(query, classification);
  if (!symbol) return null;

  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}`;
  const response = await axios.get(url, {
    params: {
      range: '1y',
      interval: '1d',
      includePrePost: false,
      events: 'div,splits'
    },
    timeout: 12000,
    headers: {
      'User-Agent': 'Mozilla/5.0 Trendora/1.0',
      Accept: 'application/json'
    }
  });

  const result = response?.data?.chart?.result?.[0];
  if (!result) return null;

  const meta = result.meta || {};
  const quote = result.indicators?.quote?.[0] || {};
  const timestamps = Array.isArray(result.timestamp) ? result.timestamp : [];
  const rows = timestamps.map((timestamp, index) => ({
    timestamp,
    open: finite(quote.open?.[index]),
    high: finite(quote.high?.[index]),
    low: finite(quote.low?.[index]),
    close: finite(quote.close?.[index]),
    volume: finite(quote.volume?.[index])
  })).filter((row) => row.close != null);

  if (!rows.length) return null;

  const latest = rows[rows.length - 1];
  const previous = rows.length > 1 ? rows[rows.length - 2] : null;
  const closes = rows.map((row) => row.close).filter(Number.isFinite);
  const highs = rows.map((row) => row.high).filter(Number.isFinite);
  const lows = rows.map((row) => row.low).filter(Number.isFinite);
  const volumes = rows.map((row) => row.volume).filter(Number.isFinite);
  const recent20Volumes = volumes.slice(-20);

  const current = finite(meta.regularMarketPrice) ?? latest.close;
  const previousClose = finite(meta.chartPreviousClose) ?? previous?.close ?? null;
  const change = current != null && previousClose != null ? current - previousClose : null;
  const changePercent = change != null && previousClose ? (change / previousClose) * 100 : null;
  const vwap = calculateVwap(
    rows.slice(-20).map((row) => row.high),
    rows.slice(-20).map((row) => row.low),
    rows.slice(-20).map((row) => row.close),
    rows.slice(-20).map((row) => row.volume)
  );
  const averageVolume20 = average(recent20Volumes);
  const volumeRatio = latest.volume != null && averageVolume20
    ? latest.volume / averageVolume20
    : null;

  const indicators = {
    rsi14: rsi(closes, 14),
    sma20: sma(closes, 20),
    sma50: sma(closes, 50),
    sma200: sma(closes, 200),
    volumeRatio,
    changePercent
  };

  const technicalScore = buildTechnicalScore({ current, ...indicators });
  const yearlyLow = finite(meta.fiftyTwoWeekLow) ?? (lows.length ? Math.min(...lows) : null);
  const yearlyHigh = finite(meta.fiftyTwoWeekHigh) ?? (highs.length ? Math.max(...highs) : null);

  return {
    symbol,
    displayName: meta.longName || meta.shortName || classification?.entity?.name || symbol,
    exchange: meta.exchangeName || meta.fullExchangeName || null,
    currency: meta.currency || (symbol.endsWith('.IS') ? 'TRY' : null),
    marketState: meta.marketState || null,
    updatedAt: meta.regularMarketTime
      ? new Date(meta.regularMarketTime * 1000).toISOString()
      : new Date(latest.timestamp * 1000).toISOString(),
    dailyPrice: {
      available: true,
      currency: meta.currency || (symbol.endsWith('.IS') ? 'TRY' : null),
      date: new Date(latest.timestamp * 1000).toISOString(),
      source: 'Yahoo Finance chart',
      open: latest.open,
      high: latest.high,
      low: latest.low,
      current,
      close: latest.close,
      previousClose,
      average: average([latest.open, latest.high, latest.low, latest.close].filter(Number.isFinite)),
      vwap,
      change,
      changePercent,
      volume: latest.volume
    },
    yearlyPrice: {
      available: yearlyLow != null || yearlyHigh != null,
      currency: meta.currency || (symbol.endsWith('.IS') ? 'TRY' : null),
      date: new Date(latest.timestamp * 1000).toISOString(),
      source: 'Yahoo Finance chart',
      low52w: yearlyLow,
      average52w: average(closes),
      high52w: yearlyHigh
    },
    technical: {
      ...indicators,
      score: technicalScore,
      direction: signalFromScore(technicalScore)
    },
    source: {
      title: `${meta.shortName || symbol} piyasa verisi`,
      publisher: 'Yahoo Finance',
      url: `https://finance.yahoo.com/quote/${encodeURIComponent(symbol)}`,
      publishedAt: new Date().toISOString(),
      evidenceType: 'market-data'
    }
  };
}

module.exports = {
  fetchMarketData,
  resolveYahooSymbol
};
