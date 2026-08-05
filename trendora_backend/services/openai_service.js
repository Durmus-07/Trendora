const OpenAI = require("openai");
const environment = require('../config/environment');

let openai = null;

function shouldInitializeOpenAi({
  aiEnabled = environment.aiEnabled,
  premiumAiSummaryEnabled = environment.premiumAiSummaryEnabled,
  newsTranslationEnabled = environment.newsTranslationEnabled,
  apiKey = process.env.OPENAI_API_KEY
} = {}) {
  return Boolean(
    (aiEnabled || premiumAiSummaryEnabled || newsTranslationEnabled) &&
    apiKey &&
    String(apiKey).trim() !== ''
  );
}

// API anahtarı varsa OpenAI'yi başlat
if (shouldInitializeOpenAi()) {
  openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  console.log("✅ Trendora AI aktif.");
} else if (
  environment.aiEnabled ||
  environment.premiumAiSummaryEnabled ||
  environment.newsTranslationEnabled
) {
  console.warn("⚠️ Trendora AI devre dışı (OPENAI_API_KEY bulunamadı).");
}

async function askTrendora(message) {
  if (!message || message.trim() === "") {
    throw new Error("Mesaj boş olamaz.");
  }

  // AI kapalıysa sunucuyu çökertme
  if (!openai) {
    return "Trendora AI şu anda devre dışı. OpenAI API anahtarı veya bakiyesi bulunmadığı için cevap veremiyor.";
  }

  try {
    const response = await openai.responses.create({
      model: environment.analysisModel,
      instructions:
        "Sen Trendora AI'sın. Türkçe konuş. Trendleri, haberleri, teknoloji ve piyasaları anlaşılır şekilde analiz et. Bilmediğin bilgileri uydurma.",
      input: message,
    });

    return response.output_text;
  } catch (err) {
    console.error("OpenAI Hatası:", err.message);

    if (err.status === 429) {
      return "Trendora AI şu anda kullanılamıyor. OpenAI kotası veya bakiyesi tükenmiş.";
    }

    return "Trendora AI şu anda geçici olarak hizmet veremiyor.";
  }
}

function isOpenAiConfigured() {
  return Boolean(openai);
}

async function createPremiumSummary({
  instructions,
  input,
  schema,
  maxOutputTokens,
  timeoutMs
}) {
  if (!openai) {
    const error = new Error('OpenAI yapılandırılmamış.');
    error.code = 'AI_NOT_CONFIGURED';
    throw error;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  timeout.unref?.();

  try {
    const response = await openai.responses.create({
      model: environment.analysisModel,
      instructions,
      input,
      max_output_tokens: maxOutputTokens,
      store: false,
      text: {
        format: {
          type: 'json_schema',
          name: 'trendora_premium_summary',
          strict: true,
          schema
        }
      }
    }, {
      signal: controller.signal
    });

    return {
      outputText: response.output_text,
      usage: {
        inputTokens: Number(response.usage?.input_tokens || 0),
        outputTokens: Number(response.usage?.output_tokens || 0)
      }
    };
  } catch (error) {
    if (controller.signal.aborted || error?.name === 'AbortError') {
      const timeoutError = new Error('OpenAI isteği zaman aşımına uğradı.');
      timeoutError.code = 'AI_TIMEOUT';
      throw timeoutError;
    }
    if (error?.status === 429) {
      const quotaError = new Error('OpenAI kotası kullanılamıyor.');
      quotaError.code = 'AI_QUOTA_EXCEEDED';
      throw quotaError;
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function translateNewsFields({ title, summary, content, timeoutMs = 30000 }) {
  if (!openai) {
    const error = new Error('OpenAI yapilandirilmamis.');
    error.code = 'AI_NOT_CONFIGURED';
    throw error;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  timeout.unref?.();

  try {
    const response = await openai.responses.create({
      model: environment.translationModel,
      instructions:
        'Ingilizce haber metnini dogal ve tarafsiz Turkceye cevir. ' +
        'Anlami, ozel isimleri, sayilari ve paragraf yapisini koru; ' +
        'yorum, ozet veya yeni bilgi ekleme.',
      input: JSON.stringify({ title, summary, content }),
      max_output_tokens: 16000,
      store: false,
      text: {
        format: {
          type: 'json_schema',
          name: 'trendora_news_translation',
          strict: true,
          schema: {
            type: 'object',
            additionalProperties: false,
            required: ['title', 'summary', 'content'],
            properties: {
              title: { type: 'string' },
              summary: { type: 'string' },
              content: { type: 'string' }
            }
          }
        }
      }
    }, { signal: controller.signal });

    return JSON.parse(response.output_text);
  } catch (error) {
    if (controller.signal.aborted || error?.name === 'AbortError') {
      const timeoutError = new Error('Ceviri istegi zaman asimina ugradi.');
      timeoutError.code = 'AI_TIMEOUT';
      throw timeoutError;
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  askTrendora,
  createPremiumSummary,
  translateNewsFields,
  isOpenAiConfigured,
  shouldInitializeOpenAi,
};
