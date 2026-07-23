const OpenAI = require('openai');

function getClient() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;
  return new OpenAI({ apiKey });
}

function stripCodeFences(value) {
  return String(value || '')
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
}

function extractFirstJsonObject(value) {
  const text = stripCodeFences(value);
  const start = text.indexOf('{');
  if (start < 0) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < text.length; index += 1) {
    const char = text[index];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') depth += 1;

    if (char === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(start, index + 1);
    }
  }

  return null;
}

function safeJsonParse(text) {
  const raw = stripCodeFences(text);
  if (!raw) return null;

  try {
    return JSON.parse(raw);
  } catch (_) {
    const extracted = extractFirstJsonObject(raw);
    if (!extracted) return null;

    try {
      return JSON.parse(extracted);
    } catch (_) {
      return null;
    }
  }
}

function buildInstructions(classification, sourcePlan) {
  const entity = classification?.entity?.found
    ? `${classification.entity.name} (${classification.entity.symbol})`
    : 'Belirli bir varlık eşleşmedi';

  return `
Sen Trendora'nın araştırma ve karar destek motorusun.
Türkçe yanıt ver.

SINIFLANDIRMA:
- Alan: ${classification.label}
- Niyet: ${classification.intent}
- Dönem: ${classification.period?.label || 'Genel'}
- Tanınan varlık: ${entity}
- Varlık türü: ${classification.entity?.subtype || 'belirsiz'}

KAYNAK PLANI:
- Gerekli kanıtlar: ${(sourcePlan?.required || []).join(' | ')}
- Tercih edilen alan adları: ${(sourcePlan?.preferredDomains || []).join(' | ')}
- Notlar: ${(sourcePlan?.notes || []).join(' | ')}

GÖREV:
1. Web araması yap ve güncel, açık, güvenilir kaynaklardan somut veri topla.
2. Kullanıcı hisseyi kısa koduyla yazmışsa kodu doğru şirketle eşleştir. Örnek: BIMAS=BİM, ASELS=ASELSAN, THYAO=Türk Hava Yolları, TUPRS=Tüpraş.
3. Sorunun türüne göre doğru ölçütleri kullan. Her soruya aynı şablonu uygulama.
4. Finansal varlıklarda günlük ve 52 haftalık verileri ASLA birbirine karıştırma.
5. dailyPrice yalnızca günlük piyasa verilerini içerir.
6. yearlyPrice yalnızca 52 haftalık en düşük, 52 haftalık ortalama ve 52 haftalık en yüksek içerir.
7. Bir fiyatı güvenilir kaynaktan doğrulayamazsan sayı uydurma. 0 yazma; null kullan ve ilgili available alanını false yap.
8. Gelecek/olasılık sorularında en az 3 senaryo üret. Yüzdeler toplamı tam 100 olsun.
9. Yüzdeleri keyfi verme. Veri zayıfsa güven puanını düşür ve bunu açıkça söyle.
10. Kesin emir verme. "Al", "sat", "kesin yükselir" deme.
11. Kaynakların başlık, site adı ve gerçek URL bilgisini döndür.
12. Günlük ortalama doğrudan güvenilir kaynaktan bulunamıyorsa, gün içi yüksek ve düşükten hesaplanmış gibi davranma.
13. JSON dışında hiçbir karakter, açıklama, Markdown, kod bloğu veya kaynakça metni yazma.
14. Sayısal veri yoksa 0 yerine null kullan.
15. directAnswer ve summary alanlarının içine Markdown işaretleri ekleme.

SADECE geçerli JSON döndür.
Şema:
{
  "answerTitle": "kısa başlık",
  "directAnswer": "soruya doğrudan, somut cevap",
  "summary": "analitik özet",
  "dailyPrice": {
    "available": false,
    "currency": "TRY",
    "current": null,
    "open": null,
    "high": null,
    "low": null,
    "average": null,
    "vwap": null,
    "close": null,
    "previousClose": null,
    "change": null,
    "changePercent": null,
    "volume": null,
    "date": null,
    "source": null
  },
  "yearlyPrice": {
    "available": false,
    "currency": "TRY",
    "low52w": null,
    "average52w": null,
    "high52w": null,
    "date": null,
    "source": null
  },
  "estimatedRange": {
    "available": false,
    "currency": "TRY",
    "low": null,
    "mid": null,
    "high": null,
    "label": "Makul piyasa aralığı",
    "basis": "aralığın nasıl çıkarıldığı"
  },
  "scenarios": [
    {"name":"Olumlu senaryo","probability":0,"description":"..."},
    {"name":"Ana senaryo","probability":0,"description":"..."},
    {"name":"Olumsuz senaryo","probability":0,"description":"..."}
  ],
  "confidence": 0,
  "statistics": {
    "trendStrength": null,
    "dataConfidence": null,
    "riskScore": null,
    "newsImpact": null,
    "marketInterest": null
  },
  "signals": [
    {"type":"positive|negative|neutral","title":"...","detail":"...","weight":0}
  ],
  "keyFactors": ["..."],
  "missingInformation": ["..."],
  "nextChecks": ["..."],
  "sources": [
    {"title":"...","publisher":"...","url":"https://...","publishedAt":null,"evidenceType":"web"}
  ],
  "disclaimer": "..."
}

Finans dışı sorularda dailyPrice ve yearlyPrice available=false olmalı.
estimatedRange uygun değilse available=false ve low/mid/high null olmalı.
confidence ve signals weight 0-100 arasında olmalı.
Kaynak sayısı mümkünse 4-10 arasında olsun.
`;
}

async function requestResearch(client, query, classification, sourcePlan, retry = false) {
  const instructions = buildInstructions(classification, sourcePlan) +
    (retry
      ? '\nÖNEMLİ: Önceki yanıt geçerli JSON değildi. Bu kez yalnızca tek bir geçerli JSON nesnesi döndür.'
      : '');

  return client.responses.create({
    model: process.env.TRENDORA_ANALYSIS_MODEL || 'gpt-4.1-mini',
    instructions,
    input: query,
    tools: [
      {
        type: 'web_search_preview',
        search_context_size: 'medium'
      }
    ]
  });
}

async function researchWithWeb(query, classification, sourcePlan) {
  const client = getClient();
  if (!client) return null;

  let response = await requestResearch(
    client,
    query,
    classification,
    sourcePlan,
    false
  );

  let parsed = safeJsonParse(response.output_text);

  if (!parsed) {
    console.warn('Trendora web araştırması ilk yanıtta geçerli JSON üretmedi; ikinci deneme yapılıyor.');

    response = await requestResearch(
      client,
      query,
      classification,
      sourcePlan,
      true
    );

    parsed = safeJsonParse(response.output_text);
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Web araştırma sonucu iki denemede de geçerli JSON olarak çözülemedi.');
  }

  return parsed;
}

module.exports = {
  researchWithWeb,
  safeJsonParse
};