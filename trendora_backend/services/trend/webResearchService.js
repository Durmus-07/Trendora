const OpenAI = require('openai');

function getClient() {
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) return null;

  return new OpenAI({ apiKey });
}

function safeJsonParse(text) {
  const raw = String(text || '').trim();

  try {
    return JSON.parse(raw);
  } catch (_) {
    const match = raw.match(/\{[\s\S]*\}/);
    if (!match) return null;

    try {
      return JSON.parse(match[0]);
    } catch (_) {
      return null;
    }
  }
}

function buildInstructions(classification) {
  return `
Sen Trendora'nın araştırma ve karar destek motorusun.
Türkçe yanıt ver.
Kullanıcının sorusu ${classification.label} alanında ve niyeti ${classification.intent}.

GÖREV:
1. Web araması yap ve güncel, açık, güvenilir kaynaklardan somut veri topla.
2. Sorunun türüne göre doğru ölçütleri kullan. Her soruya aynı şablonu uygulama.
3. Fiyat sorularında mümkünse makul fiyat aralığı, ortanca/ortalama, alt-üst bant ve fiyatı değiştiren unsurları ver.
4. Gelecek/olasılık sorularında en az 3 senaryo üret. Yüzdeler toplamı tam 100 olsun.
5. Yüzdeleri keyfi verme. Veri zayıfsa güven puanını düşür ve bunu açıkça söyle.
6. Kesin emir verme. "Al", "sat", "kesin yükselir" deme. Kullanıcının nihai kararı kendisinin vereceğini belirt.
7. Kaynakların başlık, site adı ve gerçek URL bilgisini döndür.
8. Sağlık, hukuk veya güvenlik gibi yüksek riskli konularda yalnızca genel bilgi ver; profesyonel desteğin gerekli olabileceğini belirt.

SADECE geçerli JSON döndür. Markdown kullanma.
Şema:
{
  "answerTitle": "kısa başlık",
  "directAnswer": "soruya doğrudan, somut cevap",
  "summary": "analitik özet",
  "estimatedRange": {
    "available": true,
    "currency": "TRY",
    "low": 0,
    "mid": 0,
    "high": 0,
    "label": "Makul piyasa aralığı",
    "basis": "aralığın nasıl çıkarıldığı"
  },
  "scenarios": [
    {"name":"Olumlu senaryo","probability":0,"description":"..."},
    {"name":"Ana senaryo","probability":0,"description":"..."},
    {"name":"Olumsuz senaryo","probability":0,"description":"..."}
  ],
  "confidence": 0,
  "confidenceLabel": "Düşük|Orta|Yüksek",
  "signals": [
    {"type":"positive|negative|neutral","title":"...","detail":"...","weight":0}
  ],
  "keyFactors": ["..."],
  "missingInformation": ["..."],
  "nextChecks": ["kullanıcının karar vermeden önce kontrol etmesi gerekenler"],
  "sources": [
    {"title":"...","publisher":"...","url":"https://...","publishedAt":null,"evidenceType":"web"}
  ],
  "disclaimer": "..."
}

estimatedRange uygun değilse available=false ve low/mid/high değerlerini null yap.
confidence 0-100 arasında olmalı.
signals weight 0-100 arasında olmalı.
Kaynak sayısı mümkünse 4-10 arasında olsun.
`;
}

async function researchWithWeb(query, classification) {
  const client = getClient();
  if (!client) return null;

  const response = await client.responses.create({
    model: process.env.TRENDORA_ANALYSIS_MODEL || 'gpt-4.1-mini',
    instructions: buildInstructions(classification),
    input: query,
    tools: [
      {
        type: 'web_search_preview',
        search_context_size: 'medium'
      }
    ]
  });

  const parsed = safeJsonParse(response.output_text);

  if (!parsed) {
    throw new Error('Web araştırma sonucu geçerli JSON olarak çözülemedi.');
  }

  return parsed;
}

module.exports = {
  researchWithWeb
};
