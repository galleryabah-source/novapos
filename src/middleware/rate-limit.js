function createRateLimiter({ windowMs = 60_000, max = 120 } = {}) {
  const buckets = new Map();

  return function rateLimiter(req, res, next) {
    const key = req.ip || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    let bucket = buckets.get(key);

    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + windowMs };
      buckets.set(key, bucket);
    }

    bucket.count += 1;
    res.setHeader('x-ratelimit-limit', max);
    res.setHeader('x-ratelimit-remaining', Math.max(0, max - bucket.count));

    if (bucket.count > max) {
      res.setHeader('retry-after', Math.ceil((bucket.resetAt - now) / 1000));
      return res.status(429).json({
        error: { code: 'RATE_LIMITED', message: 'Too many requests' },
        request_id: req.requestId,
      });
    }

    if (buckets.size > 10_000) {
      for (const [entryKey, entry] of buckets) {
        if (entry.resetAt <= now) buckets.delete(entryKey);
      }
    }
    next();
  };
}

module.exports = { createRateLimiter };
