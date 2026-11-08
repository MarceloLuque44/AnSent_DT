import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

const ssl = config.dbSsl
  ? {
      rejectUnauthorized: config.dbSslRejectUnauthorized,
      ...(config.dbSslCa ? { ca: config.dbSslCa } : {}),
    }
  : false;

export const pool = config.databaseUrl
  ? new Pool({
      connectionString: config.databaseUrl,
      ssl,
      max: config.dbPoolMax,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    })
  : null;

/**
 * Ejecuta una consulta parametrizada. Si no hay DATABASE_URL devuelve un
 * error 503 para que la API responda con un mensaje claro.
 */
export async function query(text, params = []) {
  if (!pool) {
    const err = new Error('DATABASE_URL no configurada');
    err.status = 503;
    throw err;
  }
  return pool.query(text, params);
}
