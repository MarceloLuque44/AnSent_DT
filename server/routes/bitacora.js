import { Router } from 'express';
import { config } from '../config.js';
import db from '../db/sqlite.js';
import { publish } from '../services/sseHub.js';

const router = Router();

const COLS = [
  'id',
  'fecha',
  'tipo_cambio',
  'descripcion',
  'filas_afectadas',
  'columnas_afectadas',
  'version_dataset',
  'resumen_estadistico',
  'creado_por',
];

/** GET /api/bitacora?limit=50&tipo=limpieza */
router.get('/', (req, res) => {
  const { limit = 50, tipo } = req.query;
  let sql = `SELECT ${COLS.join(',')} FROM bitacora_registros`;
  const params = [];
  if (tipo) {
    sql += ' WHERE tipo_cambio = ?';
    params.push(tipo);
  }
  sql += ' ORDER BY fecha DESC, id DESC LIMIT ?';
  params.push(Math.min(parseInt(limit, 10) || 50, 200));

  const rows = db.prepare(sql).all(...params);
  res.json(rows);
});

/** POST /api/bitacora — aqui llaman los scripts de R al terminar un lote */
router.post('/', (req, res) => {
  const {
    fecha = new Date().toISOString(),
    tipo_cambio,
    descripcion,
    filas_afectadas = null,
    columnas_afectadas = null,
    version_dataset = null,
    resumen_estadistico = null,
    creado_por = 'R-Plumber',
  } = req.body ?? {};

  if (!tipo_cambio || !descripcion) {
    return res
      .status(400)
      .json({ error: "Los campos 'tipo_cambio' y 'descripcion' son requeridos" });
  }

  const result = db
    .prepare(
      `INSERT INTO bitacora_registros
       (fecha, tipo_cambio, descripcion, filas_afectadas, columnas_afectadas,
        version_dataset, resumen_estadistico, creado_por)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      fecha,
      tipo_cambio,
      descripcion,
      filas_afectadas,
      columnas_afectadas ? JSON.stringify(columnas_afectadas) : null,
      version_dataset,
      resumen_estadistico ? JSON.stringify(resumen_estadistico) : null,
      creado_por
    );

  const registro = db
    .prepare(`SELECT ${COLS.join(',')} FROM bitacora_registros WHERE id = ?`)
    .get(result.lastInsertRowid);

  // Notificar a los frontend conectados via SSE
  publish('bitacora:update', registro);
  res.status(201).json(registro);
});

export default router;
