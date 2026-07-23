const { analyzeQuestion } = require('./trend/analysisOrchestrator');

const DEFAULT_QUESTIONS = [
  'Türkiye’de ikinci el otomobil fiyatlarında genel eğilim nedir?',
  'Gram altının kısa vadeli görünümü nasıl?',
  'Türkiye’de konut ve arsa piyasasının genel eğilimi nedir?',
  'Teknoloji ürünlerinde fiyatların düşme olasılığı var mı?'
];

async function analyzeQuery(query) {
  return analyzeQuestion(query);
}

async function getTrendOverview() {
  const results = await Promise.allSettled(
    DEFAULT_QUESTIONS.map(question => analyzeQuestion(question))
  );

  const trends = results
    .filter(result => result.status === 'fulfilled')
    .map(result => result.value);

  return {
    updatedAt: new Date().toISOString(),
    methodology: {
      version: '2.0.0',
      title: 'Trendora Karar Destek Motoru',
      description:
        'Soruyu alanına ve niyetine göre sınıflandırır; canlı web araştırması, ' +
        'kaynak karşılaştırması, senaryo olasılıkları, güven puanı, olumlu ' +
        'sinyaller, riskler ve eksik bilgiler üretir. Verinin yetmediği yerde ' +
        'sahte kesinlik oluşturmaz.'
    },
    trends
  };
}

module.exports = {
  analyzeQuery,
  getTrendOverview
};
