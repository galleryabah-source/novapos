function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
}

function errorHandler(err, req, res, next) {
  console.error({ requestId: req.requestId, error: err });
  if (res.headersSent) return next(err);

  const message = process.env.NODE_ENV === 'production'
    ? 'Internal server error'
    : (err.message || 'Internal server error');

  res.status(err.statusCode || 500).json({
    error: { code: err.code || 'INTERNAL_ERROR', message },
    request_id: req.requestId,
  });
}

module.exports = { notFound, errorHandler };
