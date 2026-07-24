const express = require('express');

const {
  analyzeQuery,
  getTrendOverview
} = require('../services/trendEngine');

const router = express.Router();
const MAX_QUERY_LENGTH = 500;

function parseForceRefresh(value) {
  return ['1', 'true', 'yes'].includes(
    String(value || '').trim().toLowerCase()
  );
}

router.get('/', async (req, res) => {
  try {
    const forceRefresh = parseForceRefresh(req.query?.refresh);
    const result = await getTrendOverview({ forceRefresh });

    res.set('Cache-Control', 'no-store');
    return res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Trend özeti oluşturulamadı:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Trend özeti şu anda oluşturulamadı.',
      error: error.message
    });
  }
});

router.post('/analyze', async (req, res) => {
  try {
    const query = String(
      req.body?.query ||
      req.body?.question ||
      req.body?.message ||
      ''
    ).trim();

    if (query.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Analiz için en az 2 karakterlik bir soru yazmalısın.'
      });
    }

    if (query.length > MAX_QUERY_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Analiz sorusu en fazla ${MAX_QUERY_LENGTH} karakter olabilir.`
      });
    }

    const forceRefresh = parseForceRefresh(req.body?.refresh);
    const analysis = await analyzeQuery(query, { forceRefresh });

    res.set('Cache-Control', 'no-store');
    return res.json({
      success: true,
      updatedAt: new Date().toISOString(),
      analysis
    });
  } catch (error) {
    console.error('Trend analizi oluşturulamadı:', error.message);

    return res.status(error.statusCode || 500).json({
      success: false,
      message:
        error.statusCode === 400
          ? error.message
          : 'Analiz şu anda oluşturulamadı.',
      error: error.message
    });
  }
});

module.exports = router;
