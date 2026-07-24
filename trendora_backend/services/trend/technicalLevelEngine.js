function finite(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function positive(value) {
  const n = finite(value);
  return n != null && n > 0 ? n : null;
}

function clamp(value, min, max) {
  const n = finite(value);
  if (n == null) return min;
  return Math.max(min, Math.min(max, n));
}

function roundPrice(value, current) {
  const n = positive(value);
  if (n == null) return null;
  const c = positive(current) || n;
  const digits = c >= 1000 ? 1 : c >= 100 ? 2 : c >= 10 ? 2 : 3;
  return Number(n.toFixed(digits));
}

function range(low, high, current) {
  const a = positive(low);
  const b = positive(high);
  if (a == null || b == null) return { available: false, low: null, high: null };
  return {
    available: true,
    low: roundPrice(Math.min(a, b), current),
    high: roundPrice(Math.max(a, b), current)
  };
}

function probabilityForHorizon(score, days) {
  const technicalScore = clamp(score ?? 50, 0, 100);
  const base = days <= 7 ? 72 : days <= 30 ? 64 : 54;
  const conviction = Math.abs(technicalScore - 50) * (days <= 7 ? 0.22 : days <= 30 ? 0.18 : 0.12);
  return Math.round(clamp(base + conviction, 42, 82));
}

function buildHorizonBand({ current, atrPercent, technicalScore, days, currency }) {
  const atrPct = clamp(Math.abs(finite(atrPercent) || 2.5), 0.7, 7.5);
  const score = clamp(technicalScore ?? 50, 0, 100);
  const timeScale = Math.sqrt(days / 14);
  const rawMove = (atrPct / 100) * timeScale;
  const maxMove = days <= 7 ? 0.10 : days <= 30 ? 0.20 : 0.32;
  const move = clamp(rawMove, 0.018, maxMove);
  const biasCap = days <= 7 ? 0.025 : days <= 30 ? 0.06 : 0.11;
  const bias = clamp((score - 50) / 400, -biasCap, biasCap);
  const center = current * (1 + bias);
  const low = center * (1 - move);
  const high = center * (1 + move);

  return {
    days,
    label: `${days} Gün`,
    available: true,
    currency,
    low: roundPrice(low, current),
    mid: roundPrice(center, current),
    high: roundPrice(high, current),
    probability: probabilityForHorizon(score, days),
    basis: 'ATR oynaklığı, teknik skor ve karekök zaman ölçeğiyle kalibre edildi.'
  };
}

function buildTechnicalPlan(marketData) {
  const daily = marketData?.dailyPrice || {};
  const technical = marketData?.technical || {};
  const current = positive(daily.current) || positive(daily.close) || positive(daily.open);
  if (!current) return { available: false };

  const currency = String(marketData?.currency || daily.currency || 'TRY');
  const atr = positive(technical.atr14) || current * 0.025;
  const atrPercent = positive(technical.atrPercent) || (atr / current) * 100;
  const score = clamp(technical.score ?? 50, 0, 100);
  const support1 = positive(technical.support1) || current - atr;
  const support2 = positive(technical.support2) || current - atr * 2;
  const resistance1 = positive(technical.resistance1) || current + atr;
  const resistance2 = positive(technical.resistance2) || current + atr * 2;

  const breakoutBuffer = Math.max(current * 0.0035, atr * 0.12);
  const breakoutLevel = Math.max(resistance1, current) + breakoutBuffer;
  const breakoutConfirmation = breakoutLevel + Math.max(current * 0.004, atr * 0.18);

  const pullbackLow = Math.max(support1, current - atr * 0.65);
  const pullbackHigh = Math.min(current, current - atr * 0.12);
  const followZone = range(pullbackLow, pullbackHigh, current);

  const profit1 = Math.max(resistance1, current + atr * 0.9);
  const profit2 = Math.max(resistance2, breakoutConfirmation + atr * 1.15);
  const invalidation = Math.min(support1 - Math.max(current * 0.003, atr * 0.12), current - atr * 0.85);

  const volumeRatio = finite(technical.volumeRatio);
  const breakoutConfirmed = current >= breakoutLevel && volumeRatio != null && volumeRatio >= 1.15;
  const trendState = score >= 67 ? 'pozitif' : score <= 43 ? 'negatif' : 'temkinli-nötr';

  return {
    available: true,
    currency,
    current: roundPrice(current, current),
    trendState,
    support: {
      first: roundPrice(support1, current),
      second: roundPrice(support2, current)
    },
    resistance: {
      first: roundPrice(resistance1, current),
      second: roundPrice(resistance2, current)
    },
    breakout: {
      level: roundPrice(breakoutLevel, current),
      confirmation: roundPrice(breakoutConfirmation, current),
      volumeThreshold: 1.15,
      confirmed: breakoutConfirmed,
      note: breakoutConfirmed
        ? 'Fiyat kırılım seviyesinin üzerinde ve hacim teyidi mevcut.'
        : 'Kırılım için seviye üzerindeki kapanışın hacim artışıyla teyit edilmesi beklenir.'
    },
    followZone,
    profitTaking: {
      first: roundPrice(profit1, current),
      second: roundPrice(profit2, current)
    },
    invalidation: {
      level: roundPrice(invalidation, current),
      note: 'Bu seviyenin altındaki kapanış teknik senaryoyu zayıflatır; otomatik al-sat emri değildir.'
    },
    forecastBands: [7, 30, 90].map(days => buildHorizonBand({
      current,
      atrPercent,
      technicalScore: score,
      days,
      currency
    })),
    reasons: [
      `Teknik skor ${Math.round(score)}/100`,
      technical.rsi14 != null ? `RSI(14) ${Number(technical.rsi14).toFixed(1)}` : null,
      technical.ema20 != null && technical.ema50 != null
        ? `EMA20 ${technical.ema20 >= technical.ema50 ? 'EMA50 üzerinde' : 'EMA50 altında'}`
        : null,
      technical.macdHistogram != null
        ? `MACD histogramı ${Number(technical.macdHistogram).toFixed(2)}`
        : null,
      volumeRatio != null ? `Hacim oranı ${volumeRatio.toFixed(2)}x` : null,
      `ATR oynaklığı %${Number(atrPercent).toFixed(2)}`
    ].filter(Boolean),
    disclaimer: 'Seviyeler teknik karar desteğidir; kesin fiyat, doğrudan alım-satım emri veya yatırım tavsiyesi değildir.'
  };
}

function formatPrice(value, currency) {
  const n = positive(value);
  if (n == null) return '-';
  return `${n.toLocaleString('tr-TR', { maximumFractionDigits: 3 })} ${currency || 'TRY'}`;
}

function buildPlanSignals(plan) {
  if (!plan?.available) return [];
  const c = plan.currency;
  const bands = Object.fromEntries((plan.forecastBands || []).map(item => [item.days, item]));
  const band30 = bands[30];
  const band90 = bands[90];

  return [
    {
      type: 'neutral',
      title: 'Destek ve direnç seviyeleri',
      detail: `Destekler ${formatPrice(plan.support?.first, c)} / ${formatPrice(plan.support?.second, c)}; dirençler ${formatPrice(plan.resistance?.first, c)} / ${formatPrice(plan.resistance?.second, c)}.`,
      weight: 72
    },
    {
      type: plan.breakout?.confirmed ? 'positive' : 'neutral',
      title: 'Kırılım ve teyit',
      detail: `Kırılım ${formatPrice(plan.breakout?.level, c)}, hacimli teyit ${formatPrice(plan.breakout?.confirmation, c)}. ${plan.breakout?.note || ''}`,
      weight: plan.breakout?.confirmed ? 82 : 68
    },
    {
      type: 'neutral',
      title: 'Olası takip ve kâr alma bölgeleri',
      detail: `Takip bölgesi ${formatPrice(plan.followZone?.low, c)} - ${formatPrice(plan.followZone?.high, c)}; kâr alma referansları ${formatPrice(plan.profitTaking?.first, c)} / ${formatPrice(plan.profitTaking?.second, c)}.`,
      weight: 65
    },
    {
      type: 'negative',
      title: 'Teknik geçersizlik seviyesi',
      detail: `${formatPrice(plan.invalidation?.level, c)} altındaki kapanış teknik görünümü zayıflatır.`,
      weight: 76
    },
    ...(band30 ? [{
      type: 'neutral',
      title: '30 günlük olası fiyat bandı',
      detail: `${formatPrice(band30.low, c)} - ${formatPrice(band30.high, c)}; merkez ${formatPrice(band30.mid, c)}, model olasılığı %${band30.probability}.`,
      weight: band30.probability
    }] : []),
    ...(band90 ? [{
      type: 'neutral',
      title: '90 günlük olası fiyat bandı',
      detail: `${formatPrice(band90.low, c)} - ${formatPrice(band90.high, c)}; merkez ${formatPrice(band90.mid, c)}, model olasılığı %${band90.probability}.`,
      weight: band90.probability
    }] : [])
  ];
}

module.exports = {
  buildTechnicalPlan,
  buildPlanSignals
};
