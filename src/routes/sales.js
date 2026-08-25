const express = require('express');
const { supabase } = require('../lib/supabase');

const router = express.Router();

router.post('/', async (req, res, next) => {
  const { customer_id, idempotency_key, items, payment_method, payment_amount } = req.body || {};

  if (!idempotency_key || !Array.isArray(items) || items.length === 0 || !payment_method) {
    return res.status(400).json({
      error: {
        code: 'INVALID_SALE_REQUEST',
        message: 'idempotency_key, items and payment_method are required',
      },
    });
  }

  const { data, error } = await supabase.rpc('create_sale_transaction', {
    p_organization_id: req.organization.id,
    p_outlet_id: req.outlet.id,
    p_cashier_id: req.user.id,
    p_customer_id: customer_id || null,
    p_idempotency_key: idempotency_key,
    p_items: items,
    p_payment_method: payment_method,
    p_payment_amount: payment_amount,
  });

  if (error) return next(error);
  res.status(data?.idempotent ? 200 : 201).json(data);
});

module.exports = router;
