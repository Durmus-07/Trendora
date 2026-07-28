const express = require('express');
const { requireAiEnabled } = require('../middleware/security');
const {
  PremiumAiSummaryError,
  premiumAiSummaryService
} = require('../services/premiumAiSummary');

const router = express.Router();

router.get('/status', (req, res) => {
  res.set('Cache-Control', 'no-store');
  return res.json({
    success: true,
    authenticated: true,
    premium: true
  });
});

router.post('/ai-summary', requireAiEnabled, async (req, res) => {
  res.set('Cache-Control', 'no-store');

  try {
    const result = await premiumAiSummaryService.summarize({
      uid: req.firebaseUser?.uid,
      digest: req.body?.digest
    });
    const { usage, ...summary } = result;
    return res.json({ success: true, summary });
  } catch (error) {
    if (error instanceof PremiumAiSummaryError) {
      if (error.retryAfterSeconds) {
        res.set('Retry-After', String(error.retryAfterSeconds));
      }
      return res.status(error.statusCode).json({
        success: false,
        code: error.code,
        message: errorMessage(error.code)
      });
    }

    return res.status(500).json({
      success: false,
      code: 'AI_SUMMARY_FAILED',
      message: 'Premium özet şu anda oluşturulamadı.'
    });
  }
});

function errorMessage(code) {
  return {
    PREMIUM_REQUIRED: 'Bu işlem için Premium yetkisi gerekli.',
    AI_NOT_CONFIGURED: 'Premium Yapay Zekâ sunucuda yapılandırılmamış.',
    INSUFFICIENT_DATA: 'Özet için yeterli güncel veri bulunamadı.',
    RATE_LIMITED: 'Çok fazla özet isteği gönderildi. Lütfen daha sonra tekrar deneyin.',
    AI_QUOTA_EXCEEDED: 'Premium Yapay Zekâ kotası şu anda kullanılamıyor.',
    AI_TIMEOUT: 'Premium Yapay Zekâ isteği zaman aşımına uğradı.',
    INVALID_AI_RESPONSE: 'Premium Yapay Zekâ güvenli bir cevap üretemedi.',
    AI_PROVIDER_ERROR: 'Premium Yapay Zekâ sağlayıcısına ulaşılamadı.'
  }[code] || 'Premium özet şu anda oluşturulamadı.';
}

module.exports = router;
