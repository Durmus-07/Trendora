const { resolveEntity } = require('./entityEngine');
const { detectIntent } = require('./intentEngine');

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
      'kripto', 'bitcoin', 'fon', 'tahvil', 'faiz', 'temettü', 'yatırım'
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

function classifyQuestion(query) {
  const value = normalizeText(query);
  const entity = resolveEntity(query);
  const detectedIntent = detectIntent(query);

  let best = {
    domain: entity.found ? entity.domain : 'general',
    label: entity.found ? 'Finans' : 'Genel Analiz',
    score: entity.found ? 100 : 0,
    matchedKeywords: entity.found ? [entity.symbol || entity.name] : []
  };

  if (!entity.found) {
    for (const rule of DOMAIN_RULES) {
      const matchedKeywords = rule.keywords.filter(keyword => value.includes(keyword));

      if (matchedKeywords.length > best.score) {
        best = {
          domain: rule.domain,
          label: rule.label,
          score: matchedKeywords.length,
          matchedKeywords
        };
      }
    }
  }

  return {
    ...best,
    intent: detectedIntent.type,
    period: detectedIntent.period,
    entity,
    normalizedQuery: value
  };
}

module.exports = {
  classifyQuestion,
  normalizeText
};
