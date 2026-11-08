import 'dotenv/config';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),

  // Postgres / Supabase
  databaseUrl: process.env.DATABASE_URL || '',
  dbSsl: process.env.DB_SSL !== 'false',
  dbSslRejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
  dbSslCa: process.env.DB_SSL_CA || '',
  dbPoolMax: parseInt(process.env.DB_POOL_MAX || '3', 10),

  // API para R
  apiKey: process.env.R_API_KEY || '',
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),

  isProduction: process.env.NODE_ENV === 'production',

  // Legado: rutas antiguas de Plumber/SQLite
  plumberUrl: process.env.PLUMBER_URL || 'http://localhost:8765',
  dbFile: process.env.DB_FILE || './server/db/analisis.db',
};
