const crypto = require('crypto');
const environment = require('../config/environment');

function securityHeaders(req, res, next) {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()'
  });

  next();
}

function createRateLimiter({
  windowMs = environment.requestWindowMs,
  limit = environment.requestLimit
} = {}) {
  const clients = new Map();

  const cleanup = setInterval(() => {
    const now = Date.now();

    for (const [key, entry] of clients) {
      if (entry.resetAt <= now) clients.delete(key);
    }
  }, windowMs);

  cleanup.unref();

  return (req, res, next) => {
    const key = req.ip || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    let entry = clients.get(key);

    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      clients.set(key, entry);
    }

    entry.count += 1;
    res.set('RateLimit-Limit', String(limit));
    res.set('RateLimit-Remaining', String(Math.max(0, limit - entry.count)));

    if (entry.count > limit) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return res.status(429).json({
        success: false,
        message: 'Çok fazla istek gönderildi. Lütfen kısa süre sonra tekrar deneyin.'
      });
    }

    next();
  };
}

function safeEqual(left, right) {
  const leftBuffer = Buffer.from(String(left));
  const rightBuffer = Buffer.from(String(right));

  return leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function requireAdminApiKey(req, res, next) {
  if (!environment.adminApiKey) {
    return res.status(503).json({
      success: false,
      message: 'Yönetici işlemleri sunucuda yapılandırılmamış.'
    });
  }

  const providedKey = req.get('x-admin-api-key') || '';

  if (!safeEqual(providedKey, environment.adminApiKey)) {
    return res.status(401).json({
      success: false,
      message: 'Bu işlem için geçerli bir yönetici anahtarı gerekli.'
    });
  }

  next();
}

function requireAiEnabled(req, res, next) {
  if (!environment.aiEnabled) {
    return res.status(503).json({
      success: false,
      code: 'AI_DISABLED',
      message: 'Trendora AI şu anda kullanıma kapalı.'
    });
  }

  next();
}

function requirePremiumAiSummaryEnabled(req, res, next) {
  if (!environment.premiumAiSummaryEnabled) {
    return res.status(503).json({
      success: false,
      code: 'AI_DISABLED',
      message: 'Premium Yapay Zekâ özeti şu anda kullanıma kapalı.'
    });
  }

  next();
}

module.exports = {
  createRateLimiter,
  requireAiEnabled,
  requireAdminApiKey,
  requirePremiumAiSummaryEnabled,
  securityHeaders
};
