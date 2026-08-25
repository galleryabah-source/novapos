const express = require('express');
const { supabase } = require('../lib/supabase');

const router = express.Router();

router.get('/', async (req, res, next) => {
  const { data, error } = await supabase
    .from('products')
    .select('id, sku, barcode, name, description, unit, sell_price, cost_price, is_active, category_id, created_at, updated_at')
    .eq('organization_id', req.organization.id)
    .order('name', { ascending: true });

  if (error) return next(error);
  res.json({ data });
});

router.get('/:productId', async (req, res, next) => {
  const { data, error } = await supabase
    .from('products')
    .select('id, sku, barcode, name, description, unit, sell_price, cost_price, is_active, category_id, created_at, updated_at')
    .eq('organization_id', req.organization.id)
    .eq('id', req.params.productId)
    .maybeSingle();

  if (error) return next(error);
  if (!data) return res.status(404).json({ error: { code: 'PRODUCT_NOT_FOUND', message: 'Product not found' } });
  res.json({ data });
});

module.exports = router;
