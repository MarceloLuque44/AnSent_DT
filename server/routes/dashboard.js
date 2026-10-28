import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from '../config.js';
import * as rService from '../services/rService.js';
import * as sseHub from '../services/sseHub.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/** Carpeta donde el generador escribe las imagenes del dashboard */
const ANALISIS_DIR = path.join(
  __dirname,
  '..',
  '..',
  'client',
  'src',
  'views',
  'salida',
  'analisis'
);

const router = Router();

const EXTENSIONES_IMAGEN = new Set(['.png', '.jpg', '.jpeg', '.svg', '.gif']);

/**
 * Escanea ANALISIS_DIR y devuelve las carpetas con sus imagenes.
 * Formato: [{ carpeta: string, imagenes: string[] }]
 */
export function escanearCarpetas() {
  if (!fs.existsSync(ANALISIS_DIR)) return [];
  const resultado = [];
  for (const entrada of fs.readdirSync(ANALISIS_DIR, { withFileTypes: true })) {
    if (!entrada.isDirectory()) continue;
    const imagenes = fs
      .readdirSync(path.join(ANALISIS_DIR, entrada.name))
      .filter((f) => EXTENSIONES_IMAGEN.has(path.extname(f).toLowerCase()))
      .sort();
    if (imagenes.length > 0) {
      resultado.push({ carpeta: entrada.name, imagenes });
    }
  }
  return resultado.sort((a, b) => a.carpeta.localeCompare(b.carpeta));
}

/**
 * Vigila cambios en la carpeta analisis y publica un evento SSE
 * para que el dashboard se actualice en tiempo real.
 */
let watcher = null;
let debounce = null;
let ultimoFingerprint = null;

function fingerprint() {
  try {
    let fp = '';
    for (const c of escanearCarpetas()) {
      fp += `${c.carpeta}:${c.imagenes.join(',')}|`;
    }
    return fp;
  } catch {
    return null;
  }
}

function iniciarWatcher() {
  if (!fs.existsSync(ANALISIS_DIR) || watcher) return;
  ultimoFingerprint = fingerprint();
  try {
    watcher = fs.watch(ANALISIS_DIR, { recursive: true }, () => {
      clearTimeout(debounce);
      debounce = setTimeout(() => {
        const fp = fingerprint();
        if (fp !== ultimoFingerprint) {
          ultimoFingerprint = fp;
          sseHub.publish('dashboard-imagenes', {});
        }
      }, 300);
    });
  } catch (err) {
    console.warn('[Dashboard] No se pudo vigilar la carpeta analisis:', err.message);
  }
}
iniciarWatcher();

/** Carpetas con imagenes para el dashboard (escaneo en vivo) */
router.get('/carpetas-imagenes', (_req, res) => {
  res.json({ carpetas: escanearCarpetas() });
});

/** Estado general del pipeline R y Express */
router.get('/status', async (_req, res) => {
  res.json({
    plumberOnline: (await rService.healthCheck()) !== null,
    plumberUrl: config.plumberUrl,
  });
});

/** Resumen del dataset */
router.get('/dataset', async (_req, res) => {
  const summary = await rService.getDatasetSummary();
  if (summary === null) {
    return res.status(503).json({ error: 'R/Plumber no disponible' });
  }
  res.json(summary);
});

/** Imagenes del dashboard agrupadas por carpeta (proxy a Plumber) */
router.get('/graficos', async (_req, res) => {
  const graficos = await rService.getGraficosDashboard();
  if (graficos === null) {
    return res.status(503).json({ error: 'R/Plumber no disponible' });
  }
  res.json(graficos);
});

export default router;
