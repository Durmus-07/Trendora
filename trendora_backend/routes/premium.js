const express = require('express');

const router = express.Router();

router.get('/status', (req, res) => {
  res.set('Cache-Control', 'no-store');
  return res.json({
    success: true,
    authenticated: true,
    premium: true
  });
});

module.exports = router;
