'use strict';
const express = require('express');
const { createSmartSearchPlan } = require('../services/smartSearchService');
const router = express.Router();
router.post('/', (req, res) => {
  const query = String(req.body?.query || '').trim();
  if (!query) return res.status(400).json({ success: false, errorType: 'invalid_query' });
  if (query.length > 500) {
    return res.status(413).json({ success: false, errorType: 'query_too_long' });
  }
  return res.json(createSmartSearchPlan(query));
});
module.exports = router;
