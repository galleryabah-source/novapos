const express = require('express');
const { supabase } = require('../lib/supabase');

const router = express.Router();
const ALLOWED_PAYMENT_METHODS = new Set(['cash', 'card', 'bank_transfer', 'qris', 'ewallet', 'other']);

function validateCheckoutBody(body) {
  const { customer_id, idempotency_key, items, payment_method, payment_amount } = body || {};

  if (typeof idempotency_key !== 'string' || idempotency_key.trim().length < 8 || idempotency_key.length > 128) {
    return 'idempotency_key must be 8-128 characters';
  }
  if (!Array.isArray(items) || items.length === 0 || items.length > 200) {
    return 'items must contain between 1 and 200 entries';
  }
  if (!ALLOWED_PAYMENT_METHODS.has(payment_method)) {
    return 'invalid payment_method';
  }
  if (typeof payment_amount !== 'number' || !Number.isFinite(payment_amount) || payment_amount <= 0) {
    return 'payment_amount must be a positive number';
  }

  const productIds = new Set();
  for (const item of items) {
    if (!item || typeof item.product_id !== 'string' || productIds.has(item.product_id)) {
      return 'each item must have a unique product_id';
    }
    if (typeof item.quantity !== 'number' || !Number.isFinite(item.quantity) || item.quantity <= 0 || item.quantity > 100000) {
      return `invalid quantity for product ${item.product_id}`;
    }
    productIds.add(item.product_id);
  }

  if (customer_id !== undefined && customer_id !== null && typeof customer_id !== 'string') {
    return 'customer_id must be a string or null';
  }

  return null;
}

router.post('/', async (req, res, next) => {
  const validationError = validateCheckoutBody(req.body);
  if (validationError) {
    return res.status(400).json({
      error: { code: 'INVALID_SALE_REQUEST', message: validationError },
    });
  }

  const { customer_id, idempotency_key, items, payment_method, payment_amount } = req.body;

  const { data, error } = await supabase.rpc('create_sale_transaction', {
    p_organization_id: req.organization.id,
    p_outlet_id: req.outlet.id,
    p_cashier_id: req.user.id,
    p_customer_id: customer_id || null,
    p_idempotency_key: idempotency_key.trim(),
    p_items: items,
    p_payment_method: payment_method,
    p_payment_amount: payment_amount,
  });

  if (error) return next(error);
  res.status(data?.idempotent ? 200 : 201).json(data);
});

module.exports = router;
