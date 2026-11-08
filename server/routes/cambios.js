import { Router } from 'express';
import crypto from 'node:crypto';
import { config } from '../config.js';
import { query } from '../db/pg.js';

const router = Router();

const COLS = `
  id,
  to_char(fecha, 'YYYY-MM-DD') AS fecha,
  to_char(hora, 'HH24:MI:SS') AS hora,
  tipo, archivo, seccion, problema_detectado, como_se_detecto,
  cambio_realizado, justificacion, resultado, ejecucion_prueba,
  responsable, estado_registro
`;

function requireApiKey(req, res, next) {
  if (!config.apiKey) {
    return res.status(503).json({ error: 'R_API_KEY no configurada en el servidor' });
  }
  const enviada = req.get('x-api-key') || '';
  const esperada = config.apiKey;
  const a = Buffer.from(enviada);
  const b = Buffer.from(esperada);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return res.status(401).json({ error: 'API key inválida' });
  }
  next();
}

/** GET /api/cambios?limit=100&offset=0&tipo=&estado=&archivo=&responsable=&q= */
router.get('/', async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const where = [];
    const params = [];

    if (req.query.tipo) {
      params.push(req.query.tipo);
      where.push(`tipo = $${params.length}`);
    }
    if (req.query.estado) {
      params.push(req.query.estado);
      where.push(`estado_registro = $${params.length}`);
    }
    if (req.query.archivo) {
      params.push(`%${req.query.archivo}%`);
      where.push(`archivo ILIKE $${params.length}`);
    }
    if (req.query.responsable) {
      params.push(`%${req.query.responsable}%`);
      where.push(`responsable ILIKE $${params.length}`);
    }
    if (req.query.q) {
      params.push(`%${req.query.q}%`);
      const p = `$${params.length}`;
      where.push(`(
        problema_detectado ILIKE ${p} OR
        cambio_realizado ILIKE ${p} OR
        justificacion ILIKE ${p} OR
        archivo ILIKE ${p}
      )`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const total = await query(
      `SELECT count(*)::int AS total FROM public.cambios ${whereSql}`,
      params
    );

    const filas = await query(
      `SELECT ${COLS}
       FROM public.cambios
       ${whereSql}
       ORDER BY fecha DESC NULLS LAST, hora DESC NULLS LAST, id DESC
       LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset]
    );

    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      data: filas.rows,
      total: total.rows[0].total,
      limit,
      offset,
    });
  } catch (err) {
    next(err);
  }
});

/** POST /api/cambios — lo usa R para registrar cambios o probar la conexión */
router.post('/', requireApiKey, async (req, res, next) => {
  try {
    const b = req.body ?? {};

    if (!b.tipo || !b.archivo) {
      return res.status(400).json({ error: 'tipo y archivo son obligatorios' });
    }

    const estado =
      b.estado_registro ||
      (String(b.justificacion || '').trim() ? 'completo' : 'FALTA JUSTIFICAR');

    const result = await query(
      `INSERT INTO public.cambios
        (fecha, hora, tipo, archivo, seccion, problema_detectado,
         como_se_detecto, cambio_realizado, justificacion, resultado,
         ejecucion_prueba, responsable, estado_registro)
       VALUES (
         COALESCE($1::date, CURRENT_DATE),
         COALESCE($2::time, CURRENT_TIME),
         $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
       )
       RETURNING ${COLS}`,
      [
        b.fecha || null,
        b.hora || null,
        b.tipo,
        b.archivo,
        b.seccion || '',
        b.problema_detectado || '',
        b.como_se_detecto || '',
        b.cambio_realizado || '',
        b.justificacion || '',
        b.resultado || '',
        b.ejecucion_prueba || '',
        b.responsable || '',
        estado,
      ]
    );

    res.status(201).json({ ok: true, data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

export default router;
