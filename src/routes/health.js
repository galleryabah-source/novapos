const express = require('express');
const { supabase } = require('../lib/supabase');

const router = express.Router();

router.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'novapos-api', version: '2.0-foundation' });
});

router.get('/ready', async (req, res, next) => {
  const started = Date.now();
  const { error } = await supabase.from('organizations').select('id').limit(1);
  if (error) return next(error);
  res.json({ status: 'ready', database: 'ok', latency_ms: Date.now() - started });
});

module.exports = router;
