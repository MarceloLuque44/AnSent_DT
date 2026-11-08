import { Router } from 'express';
import { query } from '../db/pg.js';
import { requireApiKey } from '../middlewares/apiKey.js';

const router = Router();

const aNumero = (v) => {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const esFecha = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);

/**
 * POST /api/dashboard/niveles
 * R envía a$nivel. Hace upsert del periodo por nombre y reemplaza sus niveles.
 *
 * Body:
 * {
 *   periodo: { nombre, inicio: "YYYY-MM-DD", fin: "YYYY-MM-DD" },
 *   n_mensajes: 19148,
 *   responsable: "R local",
 *   datos: [{ sentimiento, nivel_pct, mensajes_pct, n_mensajes }, ...]
 * }
 */
router.post('/niveles', requireApiKey, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const periodo = body.periodo ?? {};

    if (!periodo.nombre || typeof periodo.nombre !== 'string') {
      return res.status(400).json({ error: 'periodo.nombre es obligatorio' });
    }
    if (!esFecha(periodo.inicio) || !esFecha(periodo.fin)) {
      return res.status(400).json({ error: 'periodo.inicio y periodo.fin deben ser YYYY-MM-DD' });
    }
    if (!Array.isArray(body.datos) || body.datos.length === 0) {
      return res.status(400).json({ error: 'datos debe ser un array no vacío' });
    }
    if (body.datos.length > 200) {
      return res.status(400).json({ error: 'datos no puede tener más de 200 filas' });
    }

    const filas = body.datos.map((d) => ({
      sentimiento: String(d.sentimiento ?? '').trim(),
      nivel_pct: aNumero(d.nivel_pct),
      mensajes_pct: aNumero(d.mensajes_pct),
      n_mensajes: aNumero(d.n_mensajes),
    }));

    const invalida = filas.find(
      (f) => !f.sentimiento || f.nivel_pct === null || f.nivel_pct < 0 || f.nivel_pct > 100
    );
    if (invalida) {
      return res.status(400).json({
        error: `Fila inválida: se requiere sentimiento y nivel_pct entre 0 y 100 (${invalida.sentimiento || 'sin nombre'})`,
      });
    }

    const cabecera = await query(
      `INSERT INTO public.analisis (nombre, fecha_inicio, fecha_fin, n_mensajes, responsable)
       VALUES ($1, $2::date, $3::date, $4, $5)
       ON CONFLICT (nombre) DO UPDATE SET
         fecha_inicio = EXCLUDED.fecha_inicio,
         fecha_fin    = EXCLUDED.fecha_fin,
         n_mensajes   = EXCLUDED.n_mensajes,
         responsable  = EXCLUDED.responsable,
         creado_en    = CURRENT_TIMESTAMP
       RETURNING id_analisis`,
      [
        periodo.nombre,
        periodo.inicio,
        periodo.fin,
        aNumero(body.n_mensajes),
        body.responsable || '',
      ]
    );

    const idAnalisis = cabecera.rows[0].id_analisis;

    await query('DELETE FROM public.analisis_nivel WHERE id_analisis = $1', [idAnalisis]);

    await query(
      `INSERT INTO public.analisis_nivel
         (id_analisis, sentimiento, nivel_pct, mensajes_pct, n_mensajes, orden)
       SELECT $1, * FROM unnest(
         $2::text[], $3::numeric[], $4::numeric[], $5::int[], $6::int[]
       )`,
      [
        idAnalisis,
        filas.map((f) => f.sentimiento),
        filas.map((f) => f.nivel_pct),
        filas.map((f) => f.mensajes_pct),
        filas.map((f) => f.n_mensajes),
        filas.map((_, i) => i),
      ]
    );

    res.status(201).json({ ok: true, id_analisis: idAnalisis, filas: filas.length });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/dashboard/niveles?periodo=<nombre>
 * Devuelve el periodo pedido o, si no se indica, el último analizado.
 */
router.get('/niveles', async (req, res, next) => {
  try {
    const { periodo } = req.query;

    const cabecera = await query(
      `SELECT id_analisis, nombre, fecha_inicio, fecha_fin, n_mensajes
       FROM public.analisis
       ${periodo ? 'WHERE nombre = $1' : ''}
       ORDER BY creado_en DESC, id_analisis DESC
       LIMIT 1`,
      periodo ? [String(periodo)] : []
    );

    if (cabecera.rows.length === 0) {
      return res.json({ ok: true, periodo: null, n_mensajes: null, datos: [] });
    }

    const a = cabecera.rows[0];
    const niveles = await query(
      `SELECT sentimiento, nivel_pct, mensajes_pct, n_mensajes, orden
       FROM public.analisis_nivel
       WHERE id_analisis = $1
       ORDER BY nivel_pct DESC`,
      [a.id_analisis]
    );

    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      periodo: {
        nombre: a.nombre,
        inicio: a.fecha_inicio,
        fin: a.fecha_fin,
      },
      n_mensajes: a.n_mensajes,
      datos: niveles.rows,
    });
  } catch (err) {
    next(err);
  }
});

/** GET /api/dashboard/periodos — selector de periodos en el frontend. */
router.get('/periodos', async (_req, res, next) => {
  try {
    const r = await query(
      `SELECT nombre, fecha_inicio, fecha_fin, n_mensajes, creado_en
       FROM public.analisis
       ORDER BY creado_en DESC, id_analisis DESC`
    );
    res.json({ ok: true, periodos: r.rows });
  } catch (err) {
    next(err);
  }
});

export default router;
