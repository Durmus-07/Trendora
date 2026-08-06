'use strict';
const express = require('express');
const { createSmartSearchPlan } = require('../services/smartSearchService');
const { answerSmartSearch } = require('../services/smartSearchAnswerService');
const router = express.Router();
router.post('/', (req, res) => {
  const query = String(req.body?.query || '').trim();
  if (!query) return res.status(400).json({ success: false, errorType: 'invalid_query' });
  if (query.length > 500) {
    return res.status(413).json({ success: false, errorType: 'query_too_long' });
  }
  return res.json(createSmartSearchPlan(query));
});

router.post('/answer', async (req, res) => {
  try {
    const result = await answerSmartSearch(req.body?.query);
    if (!result.success) return res.status(result.status || 500).json(result);
    return res.json(result);
  } catch (_) {
    return res.status(503).json({
      success: false,
      errorType: 'search_unavailable',
      message: 'Trendora Arama şu anda güncel sonuçlara ulaşamıyor.'
    });
  }
});

module.exports = router;
