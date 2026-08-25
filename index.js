require('dotenv').config();

const app = require('./src/app');
const { env } = require('./src/lib/supabase');

const server = app.listen(env.port, () => {
  console.log(`NovaPOS API listening on port ${env.port}`);
});

function shutdown(signal) {
  console.log(`${signal} received; shutting down`);
  server.close((error) => {
    if (error) {
      console.error(error);
      process.exit(1);
    }
    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
