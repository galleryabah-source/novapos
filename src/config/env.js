const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];

function loadEnv() {
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  return {
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    port: Number(process.env.PORT || 5000),
    corsOrigin: process.env.CORS_ORIGIN || '',
    bodyLimit: process.env.BODY_LIMIT || '256kb',
  };
}

module.exports = { loadEnv };
