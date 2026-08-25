const crypto = require('node:crypto');

function getRequestId(req) {
  const supplied = req.headers['x-request-id'];
  if (typeof supplied === 'string' && /^[A-Za-z0-9._:-]{8,128}$/.test(supplied)) return supplied;
  return crypto.randomUUID();
}

function attachRequestContext(req, res, next) {
  req.requestId = getRequestId(req);
  res.setHeader('x-request-id', req.requestId);
  next();
}

module.exports = { attachRequestContext };
