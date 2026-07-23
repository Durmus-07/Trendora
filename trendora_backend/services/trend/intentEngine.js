function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

function detectPeriod(value) {
  const text = normalizeText(value);

  const dayMatch = text.match(/(?:son\s*)?(\d{1,4})\s*gün/);
  if (dayMatch) return { key: `${dayMatch[1]}d`, label: `${dayMatch[1]} Gün`, days: Number(dayMatch[1]) };

  const weekMatch = text.match(/(?:son\s*)?(\d{1,3})\s*hafta/);
  if (weekMatch) return { key: `${weekMatch[1]}w`, label: `${weekMatch[1]} Hafta`, days: Number(weekMatch[1]) * 7 };

  const monthMatch = text.match(/(?:son\s*)?(\d{1,3})\s*ay/);
  if (monthMatch) return { key: `${monthMatch[1]}mo`, label: `${monthMatch[1]} Ay`, days: Number(monthMatch[1]) * 30 };

  const yearMatch = text.match(/(?:son\s*)?(\d{1,2})\s*yıl/);
  if (yearMatch) return { key: `${yearMatch[1]}y`, label: `${yearMatch[1]} Yıl`, days: Number(yearMatch[1]) * 365 };

  if (/bugün|günlük|gün içi/.test(text)) return { key: '1d', label: 'Günlük', days: 1 };
  if (/kısa vade|kısa vadeli/.test(text)) return { key: '30d', label: 'Kısa Vade', days: 30 };
  if (/orta vade|orta vadeli/.test(text)) return { key: '180d', label: 'Orta Vade', days: 180 };
  if (/uzun vade|uzun vadeli/.test(text)) return { key: '1y', label: 'Uzun Vade', days: 365 };
  if (/52\s*hafta/.test(text)) return { key: '52w', label: '52 Hafta', days: 364 };

  return { key: 'general', label: 'Genel', days: null };
}

function detectIntent(query) {
  const value = normalizeText(query);
  let type = 'general_analysis';

  if (/neden\s+(düştü|düşüyor|geriledi|yükseldi|yükseliyor|arttı)|düşüş nedeni|yükseliş nedeni|sebebi ne/.test(value)) {
    type = 'cause_analysis';
  } else if (/haberleri|haber etkisi|kap açıklaması|kap haberi|gündem/.test(value)) {
    type = 'news_impact';
  } else if (/riskleri|risk nedir|ne kadar riskli|risk analizi/.test(value)) {
    type = 'risk_analysis';
  } else if (/karşılaştır|kıyasla|hangisi daha/.test(value)) {
    type = 'comparison';
  } else if (/kaç\s*(tl|lira)|fiyat aralığı|piyasa değeri|kaç olmalı|ederi/.test(value)) {
    type = 'valuation';
  } else if (/alınır mı|mantıklı mı|değer mi|almak mantıklı/.test(value)) {
    type = 'decision_support';
  } else if (/temettü|kar payı|kâr payı/.test(value)) {
    type = 'dividend_analysis';
  } else if (/bilanço|gelir tablosu|finansal sonuç|net kâr|ciro/.test(value)) {
    type = 'fundamental_analysis';
  } else if (/destek|direnç|teknik analiz|rsi|macd|hareketli ortalama/.test(value)) {
    type = 'technical_analysis';
  } else if (/yükselir mi|düşer mi|artar mı|azalır mı|gelecek|önümüzdeki|tahmin|beklenti/.test(value)) {
    type = 'forecast';
  } else if (/risk|olasılık|ihtimal|başarılı olur mu/.test(value)) {
    type = 'probability';
  }

  return {
    type,
    period: detectPeriod(value),
    normalizedQuery: value
  };
}

module.exports = {
  detectIntent,
  detectPeriod,
  normalizeText
};
