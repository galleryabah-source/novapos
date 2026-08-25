const { supabase } = require('../lib/supabase');

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return res.status(401).json({ error: { code: 'AUTH_REQUIRED', message: 'Authentication required' } });

  const { data, error } = await supabase.auth.getUser(match[1]);
  if (error || !data.user) {
    return res.status(401).json({ error: { code: 'AUTH_INVALID', message: 'Invalid authentication token' } });
  }

  req.user = data.user;
  next();
}

module.exports = { requireAuth };
