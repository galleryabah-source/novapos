const express = require('express');
const cors = require('cors');
const { env } = require('./lib/supabase');
const health = require('./routes/health');
const products = require('./routes/products');
const sales = require('./routes/sales');
const { requireAuth } = require('./middleware/auth');
const { requireOrganizationMember, requireOutlet } = require('./middleware/scope');
const { requirePermission } = require('./middleware/authorize');
const { attachRequestContext } = require('./lib/request-context');
const { createRateLimiter } = require('./middleware/rate-limit');
const { notFound, errorHandler } = require('./middleware/error');

const app = express();

const allowedOrigins = env.corsOrigin
  ? env.corsOrigin.split(',').map((value) => value.trim()).filter(Boolean)
  : [];

app.disable('x-powered-by');
app.use(attachRequestContext);
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('CORS origin denied'));
  },
  credentials: true,
}));
app.use(express.json({ limit: env.bodyLimit }));
app.use(createRateLimiter({ windowMs: 60_000, max: env.rateLimitPerMinute }));

app.use('/health', health);

const scoped = [requireAuth, requireOrganizationMember, requireOutlet];
app.use('/api/products', scoped, requirePermission('product:read'), products);
app.use('/api/sales', scoped, requirePermission('sale:create'), sales);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
