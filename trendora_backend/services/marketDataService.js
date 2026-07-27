const axios = require('axios');

const MARKET_CACHE_TTL_MS = Number(
  process.env.TRENDORA_MARKET_CACHE_TTL_MS || 5 * 60 * 1000
);
const marketCache = new Map();
const marketRequests = new Map();

function cloneMarketData(value) {
  return value ? JSON.parse(JSON.stringify(value)) : value;
}


const INDEX_ALIASES = {
  XU100: 'XU100.IS', BIST100: 'XU100.IS',
  XU030: 'XU030.IS', BIST30: 'XU030.IS',
  XBANK: 'XBANK.IS', BISTBANKA: 'XBANK.IS',
  XUSIN: 'XUSIN.IS', BISTSINAI: 'XUSIN.IS',
  XUTEK: 'XUTEK.IS', BISTTEKNOLOJI: 'XUTEK.IS',
  XUHIZ: 'XUHIZ.IS', BISTHIZMETLER: 'XUHIZ.IS'
};

const GLOBAL_MARKET_ALIASES = {
  GSPC: '^GSPC', SP500: '^GSPC',
  IXIC: '^IXIC', NASDAQ: '^IXIC',
  DJI: '^DJI', DOWJONES: '^DJI',
  GDAXI: '^GDAXI', DAX: '^GDAXI',
  FTSE: '^FTSE', FTSE100: '^FTSE',
  N225: '^N225', NIKKEI: '^N225',
  FCHI: '^FCHI', CAC40: '^FCHI',
  HSI: '^HSI', HANGSENG: '^HSI',
  TNX: '^TNX', US10YEAR: '^TNX',
  COPPER: 'HG=F', NATGAS: 'NG=F', WHEAT: 'ZW=F', COFFEE: 'KC=F'
};

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
    if (INDEX_ALIASES[candidate]) return INDEX_ALIASES[candidate];
    if (GLOBAL_MARKET_ALIASES[candidate]) return GLOBAL_MARKET_ALIASES[candidate];
    if (BIST_ALIASES[candidate]) return BIST_ALIASES[candidate];
    if (/^[A-Z]{3,6}\.IS$/.test(candidate)) return candidate;
    if (/^[A-Z]{3,6}$/.test(candidate) && classification?.entity?.subtype === 'bist_stock') {
      return `${candidate}.IS`;
    }
  }

  if (/BIST\s*100|BIST100|XU100/.test(cleanedQuery)) return 'XU100.IS';
  if (/BIST\s*30|BIST30|XU030/.test(cleanedQuery)) return 'XU030.IS';
  if (/BIST\s*BANKA|BANKA\s*ENDEKSI|XBANK/.test(cleanedQuery)) return 'XBANK.IS';

  if (/S&P\s*500|SP\s*500|SP500/.test(cleanedQuery)) return '^GSPC';
  if (/NASDAQ/.test(cleanedQuery)) return '^IXIC';
  if (/DOW\s*JONES/.test(cleanedQuery)) return '^DJI';
  if (/DAX|ALMANYA\s*BORSASI/.test(cleanedQuery)) return '^GDAXI';
  if (/FTSE|INGILTERE\s*BORSASI/.test(cleanedQuery)) return '^FTSE';
  if (/NIKKEI|JAPONYA\s*BORSASI/.test(cleanedQuery)) return '^N225';
  if (/CAC\s*40|FRANSA\s*BORSASI/.test(cleanedQuery)) return '^FCHI';
  if (/HANG\s*SENG|HONG\s*KONG\s*BORSASI/.test(cleanedQuery)) return '^HSI';
  if (/10\s*YILLIK\s*TAHVIL|US\s*10\s*YEAR|TNX/.test(cleanedQuery)) return '^TNX';

  if (/BENZIN|AKARYAKIT|GASOLINE|RBOB/.test(cleanedQuery)) return 'RB=F';
  if (/BRENT|PETROL/.test(cleanedQuery)) return 'BZ=F';
  if (/BAKIR|COPPER/.test(cleanedQuery)) return 'HG=F';
  if (/DOGAL\s*GAZ|NATURAL\s*GAS/.test(cleanedQuery)) return 'NG=F';
  if (/BUGDAY|WHEAT/.test(cleanedQuery)) return 'ZW=F';
  if (/KAHVE|COFFEE/.test(cleanedQuery)) return 'KC=F';
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

function emaSeries(values, period) {
  if (!Array.isArray(values) || values.length < period) return [];
  const clean = values.filter(Number.isFinite);
  if (clean.length < period) return [];

  const multiplier = 2 / (period + 1);
  const result = new Array(clean.length).fill(null);
  let current = average(clean.slice(0, period));
  result[period - 1] = current;

  for (let i = period; i < clean.length; i += 1) {
    current = ((clean[i] - current) * multiplier) + current;
    result[i] = current;
  }

  return result;
}

function ema(values, period) {
  const series = emaSeries(values, period);
  if (!series.length) return null;
  return finite(series[series.length - 1]);
}

function macd(values) {
  if (!Array.isArray(values) || values.length < 35) {
    return { macd: null, signal: null, histogram: null };
  }

  const fast = emaSeries(values, 12);
  const slow = emaSeries(values, 26);
  const macdSeries = [];

  for (let i = 0; i < values.length; i += 1) {
    if (fast[i] != null && slow[i] != null) {
      macdSeries.push(fast[i] - slow[i]);
    }
  }

  if (macdSeries.length < 9) {
    return { macd: null, signal: null, histogram: null };
  }

  const signalSeries = emaSeries(macdSeries, 9);
  const macdValue = finite(macdSeries[macdSeries.length - 1]);
  const signalValue = finite(signalSeries[signalSeries.length - 1]);

  return {
    macd: macdValue,
    signal: signalValue,
    histogram: macdValue != null && signalValue != null
      ? macdValue - signalValue
      : null
  };
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

function atr(rows, period = 14) {
  if (!Array.isArray(rows) || rows.length <= period) return null;

  const trueRanges = [];
  for (let i = 1; i < rows.length; i += 1) {
    const high = finite(rows[i]?.high);
    const low = finite(rows[i]?.low);
    const previousClose = finite(rows[i - 1]?.close);
    if (high == null || low == null || previousClose == null) continue;

    trueRanges.push(Math.max(
      high - low,
      Math.abs(high - previousClose),
      Math.abs(low - previousClose)
    ));
  }

  if (trueRanges.length < period) return null;
  return average(trueRanges.slice(-period));
}

function calculateSupportResistance(rows, lookback = 60) {
  if (!Array.isArray(rows) || !rows.length) {
    return { support1: null, support2: null, resistance1: null, resistance2: null };
  }

  const recent = rows.slice(-lookback);
  const lows = recent.map((row) => finite(row.low)).filter(Number.isFinite);
  const highs = recent.map((row) => finite(row.high)).filter(Number.isFinite);
  const closes = recent.map((row) => finite(row.close)).filter(Number.isFinite);

  if (!lows.length || !highs.length || !closes.length) {
    return { support1: null, support2: null, resistance1: null, resistance2: null };
  }

  const sortedLows = [...lows].sort((a, b) => a - b);
  const sortedHighs = [...highs].sort((a, b) => b - a);
  const current = closes[closes.length - 1];

  const supports = sortedLows
    .filter((value) => value <= current)
    .filter((value, index, list) => index === 0 || Math.abs(value - list[index - 1]) / current > 0.01);

  const resistances = sortedHighs
    .filter((value) => value >= current)
    .filter((value, index, list) => index === 0 || Math.abs(value - list[index - 1]) / current > 0.01);

  return {
    support1: finite(supports[0]),
    support2: finite(supports[1]),
    resistance1: finite(resistances[0]),
    resistance2: finite(resistances[1])
  };
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


function choosePreviousClose({ current, latestOpen, previousRowClose, metaPreviousClose, chartPreviousClose }) {
  const candidates = [metaPreviousClose, previousRowClose, chartPreviousClose]
    .map(finite)
    .filter((value) => value != null && value > 0);

  const plausible = candidates.find((value) => {
    if (current == null || current <= 0) return true;
    return Math.abs((current - value) / value) <= 0.25;
  });

  if (plausible != null) return plausible;

  const open = finite(latestOpen);
  if (open != null && open > 0) return open;
  return candidates[0] ?? null;
}

function signalFromScore(score) {
  if (score >= 67) return 'positive';
  if (score <= 43) return 'negative';
  return 'neutral';
}

async function fetchMarketData(query, classification, options = {}) {
  if (classification?.domain !== 'finance') return null;

  const derivedGold = {
    GRAM_ALTIN: { factor: 1, name: '24 Ayar Gram Altın' },
    GRAM_22_ALTIN: { factor: 22 / 24, name: '22 Ayar Gram Altın' },
    CEYREK_ALTIN: { factor: 1.6065, name: 'Çeyrek Ziynet Altın' },
    YARIM_ALTIN: { factor: 3.213, name: 'Yarım Ziynet Altın' },
    TAM_ALTIN: { factor: 6.426, name: 'Tam Ziynet Altın' },
    CUMHURIYET_ALTINI: { factor: 6.608, name: 'Cumhuriyet/Ata Altını' }
  };
  const goldType = derivedGold[normalizeTurkish(classification?.entity?.symbol)];
  if (goldType) return fetchDerivedGoldMarketData(goldType, options);

  const symbol = resolveYahooSymbol(query, classification);
  if (!symbol) return null;

  const forceRefresh = options.forceRefresh === true;
  const cached = marketCache.get(symbol);

  if (!forceRefresh && cached && Date.now() - cached.createdAt < MARKET_CACHE_TTL_MS) {
    return cloneMarketData(cached.value);
  }

  if (!forceRefresh && marketRequests.has(symbol)) {
    return cloneMarketData(await marketRequests.get(symbol));
  }

  const request = (async () => {
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
  // Yahoo'nun chartPreviousClose alanı bazı BIST yanıtlarında dönem başlangıcı
  // değerine kayabiliyor. Günlük değişim için öncelik daima bir önceki işlem
  // gününün kapanışıdır.
  const previousClose = choosePreviousClose({
    current,
    latestOpen: latest.open,
    previousRowClose: previous?.close,
    metaPreviousClose: meta.regularMarketPreviousClose,
    chartPreviousClose: meta.chartPreviousClose
  });
  let change = current != null && previousClose != null ? current - previousClose : null;
  let changePercent = change != null && previousClose ? (change / previousClose) * 100 : null;

  // Bölünme, geçmiş seri uyumsuzluğu veya Yahoo dönem anomalisi varsa
  // günlük açılışı güvenli referans olarak kullan. Böylece %100+ sahte günlük
  // değişimler uygulamaya taşınmaz.
  if (changePercent != null && Math.abs(changePercent) > 25) {
    const safeOpen = finite(latest.open);
    if (safeOpen != null && safeOpen > 0) {
      change = current - safeOpen;
      changePercent = (change / safeOpen) * 100;
    } else {
      change = null;
      changePercent = null;
    }
  }
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

  const macdValues = macd(closes);
  const supportResistance = calculateSupportResistance(rows);
  const atr14 = atr(rows, 14);

  const indicators = {
    rsi14: rsi(closes, 14),
    sma20: sma(closes, 20),
    sma50: sma(closes, 50),
    sma200: sma(closes, 200),
    volumeRatio,
    changePercent,
    ema20: ema(closes, 20),
    ema50: ema(closes, 50),
    ema100: ema(closes, 100),
    ema200: ema(closes, 200),
    macd: macdValues.macd,
    macdSignal: macdValues.signal,
    macdHistogram: macdValues.histogram,
    atr14,
    atrPercent: atr14 != null && current ? (atr14 / current) * 100 : null,
    ...supportResistance
  };

  const technicalScore = buildTechnicalScore({ current, ...indicators });
  const yearlyLow = finite(meta.fiftyTwoWeekLow) ?? (lows.length ? Math.min(...lows) : null);
  const yearlyHigh = finite(meta.fiftyTwoWeekHigh) ?? (highs.length ? Math.max(...highs) : null);

  const value = {
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
    priceHistory: rows.slice(-260).map((row) => ({
      date: new Date(row.timestamp * 1000).toISOString(),
      open: row.open,
      high: row.high,
      low: row.low,
      close: row.close,
      volume: row.volume
    })),
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

  marketCache.set(symbol, {
    createdAt: Date.now(),
    value
  });

  return value;
  })();

  marketRequests.set(symbol, request);

  try {
    return cloneMarketData(await request);
  } finally {
    marketRequests.delete(symbol);
  }
}

async function fetchDerivedGoldMarketData(goldType, options = {}) {
  const [ounce, usdTry] = await Promise.all([
    fetchMarketData('ons altın', {
      domain: 'finance', entity: { symbol: 'XAUUSD', name: 'Ons Altın', subtype: 'commodity' }
    }, options),
    fetchMarketData('dolar tl', {
      domain: 'finance', entity: { symbol: 'USDTRY', name: 'Dolar/TL', subtype: 'fx' }
    }, options)
  ]);
  if (!ounce?.dailyPrice?.available || !usdTry?.dailyPrice?.available) return null;

  const scale = goldType.factor / 31.1034768;
  const fxByDay = new Map((usdTry.priceHistory || []).map(row => [String(row.date).slice(0, 10), row]));
  const priceHistory = (ounce.priceHistory || []).map(row => {
    const fx = fxByDay.get(String(row.date).slice(0, 10));
    if (!fx) return null;
    const product = (left, right) => finite(left) != null && finite(right) != null
      ? Number(left) * Number(right) * scale
      : null;
    return {
      date: row.date,
      open: product(row.open, fx.open), high: product(row.high, fx.high),
      low: product(row.low, fx.low), close: product(row.close, fx.close), volume: null
    };
  }).filter(row => row?.close != null);
  const convert = (goldValue, fxValue) => finite(goldValue) != null && finite(fxValue) != null
    ? Number(goldValue) * Number(fxValue) * scale
    : null;
  const current = convert(ounce.dailyPrice.current, usdTry.dailyPrice.current);
  const previousClose = priceHistory.length > 1 ? priceHistory.at(-2).close : null;
  const change = current != null && previousClose != null ? current - previousClose : null;
  const changePercent = change != null && previousClose ? change / previousClose * 100 : null;
  const closes = priceHistory.map(row => row.close).filter(Number.isFinite);

  return {
    symbol: goldType.name,
    displayName: `${goldType.name} (teorik piyasa karşılığı)`,
    exchange: 'Ons Altın × USD/TRY', currency: 'TRY', marketState: ounce.marketState,
    updatedAt: ounce.updatedAt,
    dailyPrice: {
      available: current != null, currency: 'TRY', date: ounce.dailyPrice.date,
      source: 'Yahoo Finance ons altın ve USD/TRY türevi',
      open: convert(ounce.dailyPrice.open, usdTry.dailyPrice.open),
      high: convert(ounce.dailyPrice.high, usdTry.dailyPrice.high),
      low: convert(ounce.dailyPrice.low, usdTry.dailyPrice.low),
      current, close: current, previousClose, average: average(closes.slice(-5)),
      vwap: null, change, changePercent, volume: null
    },
    yearlyPrice: {
      available: closes.length > 0, currency: 'TRY', date: ounce.dailyPrice.date,
      source: 'Yahoo Finance ons altın ve USD/TRY türevi',
      low52w: closes.length ? Math.min(...closes) : null,
      average52w: average(closes), high52w: closes.length ? Math.max(...closes) : null
    },
    priceHistory,
    technical: ounce.technical,
    source: {
      title: `${goldType.name} teorik piyasa karşılığı`, publisher: 'Trendora / Yahoo Finance',
      url: 'https://finance.yahoo.com/quote/GC=F', publishedAt: new Date().toISOString(),
      evidenceType: 'derived-market-data'
    }
  };
}

module.exports = {
  fetchMarketData,
  resolveYahooSymbol
};
