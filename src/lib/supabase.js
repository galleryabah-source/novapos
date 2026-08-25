const { createClient } = require('@supabase/supabase-js');
const { loadEnv } = require('../config/env');

const env = loadEnv();
const supabase = createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
});

module.exports = { supabase, env };
