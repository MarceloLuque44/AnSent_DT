import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

const ssl = config.dbSsl
  ? {
      rejectUnauthorized: config.dbSslRejectUnauthorized,
      ...(config.dbSslCa ? { ca: config.dbSslCa } : {}),
    }
  : false;

/**
 * Supabase suele devolver la URL con ?sslmode=require. pg interpreta ese
 * parámetro y termina rechazando el certificado del pooler. Quitamos
 * sslmode para que mande la configuración SSL explícita de arriba.
 */
function normalizarConnectionString(raw) {
  if (!raw) return raw;
  try {
    const url = new URL(raw);
    url.searchParams.delete('sslmode');
    return url.toString();
  } catch {
    return raw.replace(/([?&])sslmode=[^&]*&?/i, '$1').replace(/[?&]$/, '');
  }
}

export const pool = config.databaseUrl
  ? new Pool({
      connectionString: normalizarConnectionString(config.databaseUrl),
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
