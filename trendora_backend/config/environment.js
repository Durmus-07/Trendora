function parseCsv(value) {
  return String(value || '')
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number(value);

  return Number.isInteger(parsed) && parsed > 0
    ? parsed
    : fallback;
}

function parseBoolean(value, fallback = false) {
  if (value == null || String(value).trim() === '') return fallback;

  return ['1', 'true', 'yes', 'on'].includes(
    String(value).trim().toLowerCase()
  );
}

const nodeEnv = process.env.NODE_ENV || 'development';

module.exports = {
  nodeEnv,
  isProduction: nodeEnv === 'production',
  port: parsePositiveInteger(process.env.PORT, 3000),
  allowedOrigins: parseCsv(process.env.ALLOWED_ORIGINS),
  adminApiKey: String(process.env.ADMIN_API_KEY || '').trim(),
  analysisEnabled: parseBoolean(process.env.ENABLE_ANALYSIS, true),
  aiEnabled: parseBoolean(process.env.ENABLE_AI, false),
  premiumAiSummaryEnabled: parseBoolean(
    process.env.ENABLE_PREMIUM_AI_SUMMARY,
    false
  ),
  newsTranslationEnabled: parseBoolean(
    process.env.ENABLE_NEWS_TRANSLATION,
    false
  ),
  aiPremiumOnly: parseBoolean(process.env.AI_PREMIUM_ONLY, true),
  analysisModel:
    String(process.env.TRENDORA_ANALYSIS_MODEL || '').trim() ||
    'gpt-4.1-mini',
  translationModel:
    String(process.env.TRENDORA_TRANSLATION_MODEL || '').trim() ||
    String(process.env.TRENDORA_ANALYSIS_MODEL || '').trim() ||
    'gpt-4.1-mini',
  jsonLimit: process.env.JSON_BODY_LIMIT || '256kb',
  requestWindowMs: parsePositiveInteger(
    process.env.REQUEST_WINDOW_MS,
    60 * 1000
  ),
  requestLimit: parsePositiveInteger(process.env.REQUEST_LIMIT, 120)
};
