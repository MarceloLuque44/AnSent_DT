import { config } from '../config.js';

/**
 * Cliente HTTP hacia la API de Plumber (R).
 * Todos los métodos devuelven null si R no está disponible, para que
 * el dashboard degrada con gracia.
 *
 * Diagnóstico:
 *   - healthCheck() reintenta 2 veces con timeout corto (3000 ms).
 *   - rFetch() reporta el error exacto (conexión rechazada, timeout, etc.).
 */

async function rFetch(path, options = {}, timeoutMs = 10000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${config.plumberUrl}${path}`, {
      signal: controller.signal,
      ...options,
    });
    if (!res.ok) {
      console.error(`[rService] Plumber respondio ${res.status} en ${path}`);
      return null;
    }
    return await res.json();
  } catch (err) {
    let motivo = err.message;
    if (err.name === 'AbortError') {
      motivo = `Timeout después de ${timeoutMs} ms`;
    } else if (err.message.includes('fetch failed')) {
      motivo = `Conexión rechazada — ¿Está Plumber corriendo en ${config.plumberUrl}?`;
    }
    console.error(`[rService] Error contactando Plumber (${path}):`, motivo);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/** Como rFetch pero lanza error si Plumber no responde (para pasos criticos) */
export async function rFetchRaw(path, options = {}, timeoutMs = 120000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${config.plumberUrl}${path}`, {
      signal: controller.signal,
      ...options,
    });
    const body = await res.json();
    if (!res.ok) {
      throw new Error(body.error || `Plumber respondio ${res.status} en ${path}`);
    }
    return body;
  } catch (err) {
    let motivo = err.message;
    if (err.name === 'AbortError') {
      motivo = `Timeout después de ${timeoutMs} ms`;
    } else if (err.message.includes('fetch failed')) {
      motivo = `Conexión rechazada — ¿Está Plumber corriendo en ${config.plumberUrl}?`;
    }
    console.error(`[rService] Error contactando Plumber (${path}):`, motivo);
    throw new Error(motivo);
  } finally {
    clearTimeout(timer);
  }
}

/** GET /charts de Plumber: definición JSON de los gráficos */
export const getCharts = () => rFetch('/charts');

/** GET /dataset/summary: resumen del dataset actual */
export const getDatasetSummary = () => rFetch('/dataset/summary');

/** GET /dashboard/graficos: imagenes agrupadas por carpeta desde Plumber */
export const getGraficosDashboard = () => rFetch('/dashboard/graficos');

/** POST /preprocesar: ejecuta el preprocesamiento en R */
export const runPreprocesamiento = (body = {}) =>
  rFetch('/preprocesar', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

/** Chequeo rápido de que Plumber está vivo (con reintento) */
export const healthCheck = async () => {
  for (let i = 0; i < 2; i++) {
    const resultado = await rFetch('/__ping__', {}, 3000);
    if (resultado !== null) return resultado;
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  return null;
};
