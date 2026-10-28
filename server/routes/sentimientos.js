import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from '../config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__dirname);

/** Carpeta de configuracion del proyecto R */
const CONFIG_DIR = path.join(__dirname, '..', '..', 'r', 'config');

const EXTENSIONES = new Set(['.csv', '.json', '.txt', '.tsv']);

const router = Router();

/** Lista los archivos de r/config/ */
router.get('/', (_req, res) => {
  if (!fs.existsSync(CONFIG_DIR)) {
    return res.json({ carpetas: [], archivos: [] });
  }
  const archivos = fs
    .readdirSync(CONFIG_DIR, { withFileTypes: true })
    .filter((e) => e.isFile() && EXTENSIONES.has(path.extname(e.name).toLowerCase()))
    .map((e) => {
      const ruta = path.join(CONFIG_DIR, e.name);
      const stat = fs.statSync(ruta);
      return {
        nombre: e.name,
        tipo: path.extname(e.name).toLowerCase().slice(1),
        tamano_bytes: stat.size,
        modificado: stat.mtime.toISOString(),
      };
    })
    .sort((a, b) => a.nombre.localeCompare(b.nombre));
  res.json({ archivos, carpeta: CONFIG_DIR });
});

/** Lee el contenido de un archivo de r/config/ */
router.get('/:archivo', (req, res) => {
  const { archivo } = req.params;
  if (!archivo || archivo.includes('..') || path.isAbsolute(archivo)) {
    return res.status(400).json({ error: 'Nombre de archivo invalido' });
  }
  const ruta = path.join(CONFIG_DIR, archivo);
  if (!fs.existsSync(ruta) || !fs.statSync(ruta).isFile()) {
    return res.status(404).json({ error: 'Archivo no encontrado' });
  }
  const ext = path.extname(archivo).toLowerCase();
  if (ext === '.json') {
    try {
      const obj = JSON.parse(fs.readFileSync(ruta, 'utf8'));
      return res.json({ archivo, tipo: 'json', contenido: obj });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }
  // CSV / TXT: devolver texto plano para parsear en el frontend
  try {
    const texto = fs.readFileSync(ruta, 'utf8');
    res.json({ archivo, tipo: ext.slice(1), contenido: texto });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
