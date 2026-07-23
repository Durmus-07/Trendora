function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

const DOMAIN_RULES = [
  {
    domain: 'vehicle',
    label: 'Otomobil',
    keywords: [
      'araba', 'araç', 'otomobil', 'suv', 'sedan', 'hatchback',
      'qashqai', 'nissan', 'citroen', 'renault', 'toyota', 'honda',
      'ford', 'fiat', 'volkswagen', 'bmw', 'mercedes', 'hyundai',
      'kia', 'peugeot', 'opel', 'skoda', 'model yılı', 'kilometre',
      'km', 'boyasız', 'hatasız', 'kazasız', 'tramer', 'ekspertiz'
    ]
  },
  {
    domain: 'real_estate',
    label: 'Gayrimenkul',
    keywords: [
      'arsa', 'arazi', 'ev', 'konut', 'daire', 'villa', 'dükkan',
      'işyeri', 'emlak', 'kira', 'mahalle', 'parsel', 'ada', 'imar',
      'metrekare', 'm²', 'site', 'tapulu'
    ]
  },
  {
    domain: 'finance',
    label: 'Finans',
    keywords: [
      'hisse', 'borsa', 'bist', 'altın', 'gümüş', 'dolar', 'euro',
      'kripto', 'bitcoin', 'fon', 'tahvil', 'faiz', 'tüpraş', 'aselsan',
      'temettü', 'yatırım'
    ]
  },
  {
    domain: 'product',
    label: 'Ürün ve Fiyat',
    keywords: [
      'telefon', 'bilgisayar', 'laptop', 'tablet', 'televizyon',
      'buzdolabı', 'çamaşır makinesi', 'kulaklık', 'iphone', 'samsung',
      'ürün', 'kampanya', 'indirim', 'fiyatı düşer', 'kaç tl olmalı'
    ]
  },
  {
    domain: 'travel',
    label: 'Seyahat',
    keywords: [
      'tatil', 'otel', 'uçak', 'bilet', 'seyahat', 'tur', 'vize',
      'japonya', 'avrupa', 'sezon', 'rezervasyon'
    ]
  },
  {
    domain: 'business',
    label: 'İş ve Girişim',
    keywords: [
      'iş kurmak', 'iş fikri', 'girişim', 'dükkan açmak', 'kafe',
      'mağaza', 'e-ticaret', 'kazandırır mı', 'başarılı olur mu',
      'müşteri', 'ciro', 'kâr', 'maliyet'
    ]
  }
];

function inferIntent(query) {
  const value = normalizeText(query);

  if (/kaç\s*(tl|lira)|fiyat aralığı|piyasa değeri|kaç olmalı|ederi/.test(value)) {
    return 'valuation';
  }

  if (/alınır mı|mantıklı mı|değer mi|hangisi|karşılaştır/.test(value)) {
    return 'decision_support';
  }

  if (/yüksel|düşer|artar|azalır|devam eder|gelecek|önümüzdeki/.test(value)) {
    return 'forecast';
  }

  if (/risk|olasılık|ihtimal|başarılı olur mu/.test(value)) {
    return 'probability';
  }

  return 'general_analysis';
}

function classifyQuestion(query) {
  const value = normalizeText(query);
  let best = {
    domain: 'general',
    label: 'Genel Analiz',
    score: 0,
    matchedKeywords: []
  };

  for (const rule of DOMAIN_RULES) {
    const matchedKeywords = rule.keywords.filter(keyword =>
      value.includes(keyword)
    );

    if (matchedKeywords.length > best.score) {
      best = {
        domain: rule.domain,
        label: rule.label,
        score: matchedKeywords.length,
        matchedKeywords
      };
    }
  }

  return {
    ...best,
    intent: inferIntent(query),
    normalizedQuery: value
  };
}

module.exports = {
  classifyQuestion,
  normalizeText
};
