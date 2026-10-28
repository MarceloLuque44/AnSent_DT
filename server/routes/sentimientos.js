import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from '../config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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

/** Activa/desactiva sentimientos en r/config/sentimientos.json.
 * Acepta { nombre, activo } para un item, o { sentimientos: [...] } para escribir la lista completa. */
router.put('/sentimientos.json', (req, res) => {
  const ruta = path.join(CONFIG_DIR, 'sentimientos.json');
  if (!fs.existsSync(ruta) || !fs.statSync(ruta).isFile()) {
    return res.status(404).json({ error: 'Archivo de sentimientos no encontrado' });
  }
  try {
    const obj = JSON.parse(fs.readFileSync(ruta, 'utf8'));
    if (!Array.isArray(obj.sentimientos)) {
      return res.status(400).json({ error: 'El archivo no contiene un arreglo de sentimientos' });
    }

    const { sentimientos, nombre, activo } = req.body;

    if (Array.isArray(sentimientos)) {
      // Escribir lista completa
      const porNombre = new Map(obj.sentimientos.map((s) => [s.nombre, s]));
      for (const s of sentimientos) {
        const existente = porNombre.get(s.nombre);
        if (existente) {
          existente.activo = s.activo === true || s.activo === 'true';
        }
      }
      fs.writeFileSync(ruta, JSON.stringify(obj, null, 2), 'utf8');
      return res.json({ ok: true, archivo: 'sentimientos.json', actualizados: sentimientos.length });
    }

    if (nombre == null) {
      return res.status(400).json({ error: 'Se requiere el campo nombre o sentimientos' });
    }
    const idx = obj.sentimientos.findIndex((s) => s.nombre === nombre);
    if (idx === -1) {
      return res.status(404).json({ error: `Sentimiento no encontrado: ${nombre}` });
    }
    obj.sentimientos[idx].activo = activo === true || activo === 'true';
    fs.writeFileSync(ruta, JSON.stringify(obj, null, 2), 'utf8');
    return res.json({ ok: true, archivo: 'sentimientos.json', nombre, activo: obj.sentimientos[idx].activo });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
