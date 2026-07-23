const {
  normalizeScenarios,
  confidenceLabel
} = require('./probabilityEngine');

const POSITIVE_WORDS = [
  'artış', 'yükseliş', 'rekor', 'güçlü', 'büyüme', 'talep',
  'kazanç', 'olumlu', 'destek', 'canlandı', 'hızlandı'
];

const NEGATIVE_WORDS = [
  'düşüş', 'gerileme', 'kayıp', 'risk', 'zayıf', 'daralma',
  'azaldı', 'kriz', 'baskı', 'yavaşladı', 'uyarı'
];

function normalize(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

function countSentiment(items) {
  let positive = 0;
  let negative = 0;

  for (const item of items) {
    const title = normalize(item.title);

    for (const word of POSITIVE_WORDS) {
      if (title.includes(word)) positive += 1;
    }

    for (const word of NEGATIVE_WORDS) {
      if (title.includes(word)) negative += 1;
    }
  }

  return { positive, negative };
}

function buildFallbackAnalysis(query, classification, evidence) {
  const sentiment = countSentiment(evidence);
  const totalSignals = sentiment.positive + sentiment.negative;
  const bias = totalSignals > 0
    ? (sentiment.positive - sentiment.negative) / totalSignals
    : 0;

  const positiveProbability = Math.round(38 + bias * 22);
  const negativeProbability = Math.round(30 - bias * 18);
  const neutralProbability = 100 - positiveProbability - negativeProbability;

  const confidence = Math.min(
    58,
    22 + Math.min(evidence.length, 20) * 1.8
  );

  return {
    answerTitle: `${classification.label} değerlendirmesi`,
    directAnswer:
      'Şu anda yalnızca açık haber sinyallerine ulaşılabildiği için ' +
      'kesin fiyat veya güçlü karar sonucu üretmek güvenilir olmaz.',
    summary:
      `${query} hakkında ${evidence.length} benzersiz güncel içerik ` +
      `incelendi. Bu yedek analiz yalnızca haber yoğunluğu ve başlık ` +
      `eğiliminden oluşur; piyasa ilanı, fiyat geçmişi veya alan verisi ` +
      `bulunmadığında sonuç sınırlıdır.`,
    estimatedRange: {
      available: false,
      currency: null,
      low: null,
      mid: null,
      high: null,
      label: 'Fiyat aralığı hesaplanamadı',
      basis: 'Doğrulanabilir fiyat örnekleri bulunmadı.'
    },
    scenarios: normalizeScenarios([
      {
        name: 'Olumlu görünüm',
        probability: positiveProbability,
        description: 'Olumlu başlık ve ilgi sinyallerinin güçlenmesi.'
      },
      {
        name: 'Dengeli görünüm',
        probability: neutralProbability,
        description: 'Mevcut sinyallerin yön belirlemek için yetersiz kalması.'
      },
      {
        name: 'Olumsuz görünüm',
        probability: negativeProbability,
        description: 'Risk ve zayıflama sinyallerinin öne çıkması.'
      }
    ]),
    confidence: Math.round(confidence),
    confidenceLabel: confidenceLabel(confidence),
    signals: [
      {
        type: 'neutral',
        title: 'Haber hacmi',
        detail: `${evidence.length} benzersiz içerik bulundu.`,
        weight: Math.min(100, evidence.length * 4)
      },
      {
        type: 'positive',
        title: 'Olumlu başlık sinyali',
        detail: `${sentiment.positive} olumlu ifade tespit edildi.`,
        weight: Math.min(100, sentiment.positive * 10)
      },
      {
        type: 'negative',
        title: 'Olumsuz başlık sinyali',
        detail: `${sentiment.negative} risk ifadesi tespit edildi.`,
        weight: Math.min(100, sentiment.negative * 10)
      }
    ],
    keyFactors: [
      'Güncel içerik yoğunluğu',
      'Başlıklardaki olumlu ve olumsuz ifadeler',
      'Kaynak çeşitliliği'
    ],
    missingInformation: [
      'Doğrudan piyasa/ilan verisi',
      'Geçmiş fiyat serisi',
      'Sorunun alanına özel nicel ölçütler'
    ],
    nextChecks: [
      'Karar vermeden önce gerçek fiyat, ilan veya resmi veri örneklerini kontrol et.',
      'Model, yıl, paket, konum, tarih ve bütçe gibi ayrıntıları soruya ekle.'
    ],
    sources: evidence.slice(0, 8),
    disclaimer:
      'Bu değerlendirme sınırlı açık haber sinyallerinden üretilmiştir; ' +
      'kesin sonuç, yatırım, alım veya satım tavsiyesi değildir.'
  };
}

module.exports = {
  buildFallbackAnalysis
};
