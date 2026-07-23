const express = require('express');

const {
  analyzeQuery,
  getTrendOverview
} = require('../services/trendEngine');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const result = await getTrendOverview();

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

    const analysis = await analyzeQuery(query);

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
