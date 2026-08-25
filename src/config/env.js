const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];

function loadEnv() {
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const port = Number(process.env.PORT || 5000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be a valid TCP port');
  }

  const rateLimitPerMinute = Number(process.env.RATE_LIMIT_PER_MINUTE || 120);
  if (!Number.isInteger(rateLimitPerMinute) || rateLimitPerMinute < 10 || rateLimitPerMinute > 10_000) {
    throw new Error('RATE_LIMIT_PER_MINUTE must be an integer between 10 and 10000');
  }

  return {
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    port,
    corsOrigin: process.env.CORS_ORIGIN || '',
    bodyLimit: process.env.BODY_LIMIT || '256kb',
    rateLimitPerMinute,
  };
}

module.exports = { loadEnv };
