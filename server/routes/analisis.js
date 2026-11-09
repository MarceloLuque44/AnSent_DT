import { Router } from 'express';
import { query, pool } from '../db/pg.js';
import { requireApiKey } from '../middlewares/apiKey.js';

const router = Router();

const aNumero = (v) => {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const esFecha = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);

/**
 * Inserta/actualiza un periodo y reemplaza sus niveles usando el ejecutor
 * recibido (normalmente `client.query` dentro de una transacción).
 */
async function guardarPeriodo(ejecutar, periodo, filas, responsable) {
  const cabecera = await ejecutar(
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
      aNumero(periodo.n_mensajes),
      responsable || '',
    ]
  );

  const idAnalisis = cabecera.rows[0].id_analisis;

  await ejecutar('DELETE FROM public.analisis_nivel WHERE id_analisis = $1', [idAnalisis]);

  await ejecutar(
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

  return idAnalisis;
}

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

/**
 * POST /api/dashboard/comparaciones
 * R envía cmp$niveles (dos periodos). Guarda ambos periodos en analisis /
 * analisis_nivel y registra la cabecera en analisis_comparacion.
 *
 * Body:
 * {
 *   nombre: "A vs B",
 *   responsable: "R local",
 *   periodos: [
 *     { clave: "A", nombre, inicio: "YYYY-MM-DD", fin: "YYYY-MM-DD", n_mensajes },
 *     { clave: "B", nombre, inicio: "YYYY-MM-DD", fin: "YYYY-MM-DD", n_mensajes }
 *   ],
 *   datos: [{ sentimiento, periodo, nivel_pct, mensajes_pct, n_mensajes }, ...]
 * }
 */
router.post('/comparaciones', requireApiKey, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const periodos = Array.isArray(body.periodos) ? body.periodos : [];

    if (periodos.length !== 2) {
      return res.status(400).json({ error: 'periodos debe tener exactamente 2 elementos' });
    }

    for (const p of periodos) {
      if (!p || typeof p.nombre !== 'string' || !p.nombre.trim()) {
        return res.status(400).json({ error: 'Cada periodo requiere nombre' });
      }
      if (!esFecha(p.inicio) || !esFecha(p.fin)) {
        return res.status(400).json({
          error: `El periodo ${p.nombre} requiere inicio y fin en formato YYYY-MM-DD`,
        });
      }
    }

    if (!Array.isArray(body.datos) || body.datos.length === 0) {
      return res.status(400).json({ error: 'datos debe ser un array no vacío' });
    }
    if (body.datos.length > 600) {
      return res.status(400).json({ error: 'datos no puede tener más de 600 filas' });
    }

    // Permite que R envíe el periodo por nombre o por clave ("A"/"B").
    const mapa = new Map();
    periodos.forEach((p) => {
      mapa.set(String(p.nombre), p);
      if (p.clave != null) mapa.set(String(p.clave), p);
    });

    const grupos = new Map(periodos.map((p) => [p.nombre, []]));
    for (const d of body.datos) {
      const periodo = mapa.get(String(d.periodo ?? ''));
      if (!periodo) {
        return res.status(400).json({
          error: `Fila con periodo desconocido: ${d.periodo ?? 'sin periodo'}`,
        });
      }
      const fila = {
        sentimiento: String(d.sentimiento ?? '').trim(),
        nivel_pct: aNumero(d.nivel_pct),
        mensajes_pct: aNumero(d.mensajes_pct),
        n_mensajes: aNumero(d.n_mensajes),
      };
      if (!fila.sentimiento || fila.nivel_pct === null || fila.nivel_pct < 0 || fila.nivel_pct > 100) {
        return res.status(400).json({
          error: `Fila inválida: se requiere sentimiento y nivel_pct entre 0 y 100 (${fila.sentimiento || 'sin nombre'})`,
        });
      }
      grupos.get(periodo.nombre).push(fila);
    }

    for (const p of periodos) {
      if (grupos.get(p.nombre).length === 0) {
        return res.status(400).json({ error: `El periodo ${p.nombre} no tiene filas en datos` });
      }
    }

    if (!pool) {
      const err = new Error('DATABASE_URL no configurada');
      err.status = 503;
      throw err;
    }

    const nombre = String(
      body.nombre || `${periodos[0].nombre} vs ${periodos[1].nombre}`
    ).trim();

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const ids = [];
      for (const p of periodos) {
        const id = await guardarPeriodo(
          client.query.bind(client),
          p,
          grupos.get(p.nombre),
          body.responsable
        );
        ids.push(id);
      }

      const cabecera = await client.query(
        `INSERT INTO public.analisis_comparacion
           (nombre, id_analisis_a, id_analisis_b)
         VALUES ($1, $2, $3)
         ON CONFLICT (nombre) DO UPDATE SET
           id_analisis_a = EXCLUDED.id_analisis_a,
           id_analisis_b = EXCLUDED.id_analisis_b,
           creado_en     = CURRENT_TIMESTAMP
         RETURNING id_comparacion`,
        [nombre, ids[0], ids[1]]
      );

      await client.query('COMMIT');

      res.status(201).json({
        ok: true,
        id_comparacion: cabecera.rows[0].id_comparacion,
        filas: body.datos.length,
      });
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    next(err);
  }
});

/** GET /api/dashboard/comparaciones — listado para el selector del frontend. */
router.get('/comparaciones', async (_req, res, next) => {
  try {
    const r = await query(
      `SELECT c.id_comparacion, c.nombre, c.creado_en,
              a.nombre AS periodo_a, b.nombre AS periodo_b
       FROM public.analisis_comparacion c
       JOIN public.analisis a ON a.id_analisis = c.id_analisis_a
       JOIN public.analisis b ON b.id_analisis = c.id_analisis_b
       ORDER BY c.creado_en DESC, c.id_comparacion DESC`
    );
    res.json({ ok: true, comparaciones: r.rows });
  } catch (err) {
    next(err);
  }
});

/** GET /api/dashboard/comparaciones/:id — datos para el gráfico de barras agrupadas. */
router.get('/comparaciones/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'id de comparación inválido' });
    }

    const cabecera = await query(
      `SELECT c.id_comparacion, c.nombre, c.creado_en,
              a.id_analisis AS id_a, a.nombre AS nombre_a,
              a.fecha_inicio AS inicio_a, a.fecha_fin AS fin_a, a.n_mensajes AS n_a,
              b.id_analisis AS id_b, b.nombre AS nombre_b,
              b.fecha_inicio AS inicio_b, b.fecha_fin AS fin_b, b.n_mensajes AS n_b
       FROM public.analisis_comparacion c
       JOIN public.analisis a ON a.id_analisis = c.id_analisis_a
       JOIN public.analisis b ON b.id_analisis = c.id_analisis_b
       WHERE c.id_comparacion = $1`,
      [id]
    );

    if (cabecera.rows.length === 0) {
      return res.status(404).json({ error: 'Comparación no encontrada' });
    }

    const c = cabecera.rows[0];

    const niveles = await query(
      `SELECT id_analisis, sentimiento, nivel_pct, mensajes_pct, n_mensajes, orden
       FROM public.analisis_nivel
       WHERE id_analisis = ANY($1::int[])
       ORDER BY id_analisis, orden NULLS LAST, sentimiento`,
      [[c.id_a, c.id_b]]
    );

    const periodos = [
      {
        clave: 'A',
        nombre: c.nombre_a,
        inicio: c.inicio_a,
        fin: c.fin_a,
        n_mensajes: c.n_a,
      },
      {
        clave: 'B',
        nombre: c.nombre_b,
        inicio: c.inicio_b,
        fin: c.fin_b,
        n_mensajes: c.n_b,
      },
    ];

    const nombrePorId = new Map([
      [c.id_a, c.nombre_a],
      [c.id_b, c.nombre_b],
    ]);

    const datos = niveles.rows.map((r) => ({
      sentimiento: r.sentimiento,
      periodo: nombrePorId.get(r.id_analisis),
      nivel_pct: r.nivel_pct,
      mensajes_pct: r.mensajes_pct,
      n_mensajes: r.n_mensajes,
      orden: r.orden,
    }));

    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      comparacion: {
        id_comparacion: c.id_comparacion,
        nombre: c.nombre,
        creado_en: c.creado_en,
      },
      periodos,
      datos,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * Upsert de la cabecera de un periodo en public.analisis (por nombre).
 * Devuelve id_analisis. Se usa en POST /serie y POST /sankey.
 */
async function upsertCabecera(ejecutar, periodo, n_mensajes, responsable) {
  return ejecutar(
    `INSERT INTO public.analisis (nombre, fecha_inicio, fecha_fin, n_mensajes, responsable)
     VALUES ($1, $2::date, $3::date, $4, $5)
     ON CONFLICT (nombre) DO UPDATE SET
       fecha_inicio = EXCLUDED.fecha_inicio,
       fecha_fin    = EXCLUDED.fecha_fin,
       n_mensajes   = EXCLUDED.n_mensajes,
       responsable  = EXCLUDED.responsable,
       creado_en    = CURRENT_TIMESTAMP
     RETURNING id_analisis`,
    [periodo.nombre, periodo.inicio, periodo.fin, aNumero(n_mensajes), responsable || '']
  );
}

/**
 * Valida el bloque `periodo` común a /serie y /sankey.
 */
function validarPeriodo(periodo) {
  if (!periodo || typeof periodo.nombre !== 'string' || !periodo.nombre.trim()) {
    return 'periodo.nombre es obligatorio';
  }
  if (!esFecha(periodo.inicio) || !esFecha(periodo.fin)) {
    return 'periodo.inicio y periodo.fin deben ser YYYY-MM-DD';
  }
  return null;
}

/**
 * POST /api/dashboard/serie
 * Body: { periodo: { nombre, inicio: "YYYY-MM-DD", fin: "YYYY-MM-DD" },
 *         n_mensajes, responsable,
 *         datos: [{ anio_mes, sentimiento, pct, n_mensajes }, ...] }
 * Upsert del periodo por nombre y reemplaza las filas de serie mensual.
 */
router.post('/serie', requireApiKey, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const periodo = body.periodo ?? {};

    const errPeriodo = validarPeriodo(periodo);
    if (errPeriodo) {
      return res.status(400).json({ error: errPeriodo });
    }
    if (!Array.isArray(body.datos) || body.datos.length === 0) {
      return res.status(400).json({ error: 'datos debe ser un array no vacío' });
    }
    if (body.datos.length > 2000) {
      return res.status(400).json({ error: 'datos no puede tener más de 2000 filas' });
    }

    const filas = body.datos.map((d) => ({
      anio_mes: String(d.anio_mes ?? '').trim(),
      sentimiento: String(d.sentimiento ?? '').trim(),
      pct: aNumero(d.pct),
      n_mensajes: aNumero(d.n_mensajes),
    }));

    const invalida = filas.find(
      (f) => !f.anio_mes || !f.sentimiento || f.pct === null || f.pct < 0 || f.pct > 100
    );
    if (invalida) {
      return res.status(400).json({
        error: `Fila inválida: se requiere anio_mes, sentimiento y pct entre 0 y 100 (${invalida.sentimiento || 'sin nombre'})`,
      });
    }

    const cabecera = await upsertCabecera(query, periodo, body.n_mensajes, body.responsable);
    const idAnalisis = cabecera.rows[0].id_analisis;

    await query('DELETE FROM public.analisis_serie_mensual WHERE id_analisis = $1', [idAnalisis]);

    await query(
      `INSERT INTO public.analisis_serie_mensual
         (id_analisis, anio_mes, sentimiento, pct, n_mensajes)
       SELECT $1, * FROM unnest(
         $2::text[], $3::text[], $4::numeric[], $5::int[]
       )`,
      [
        idAnalisis,
        filas.map((f) => f.anio_mes),
        filas.map((f) => f.sentimiento),
        filas.map((f) => f.pct),
        filas.map((f) => f.n_mensajes),
      ]
    );

    res.status(201).json({ ok: true, id_analisis: idAnalisis, filas: filas.length });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/dashboard/serie?periodo=<nombre>
 * Devuelve { ok, periodo, n_mensajes, datos } con la serie mensual guardada.
 */
router.get('/serie', async (req, res, next) => {
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
    const serie = await query(
      `SELECT anio_mes, sentimiento, pct, n_mensajes
       FROM public.analisis_serie_mensual
       WHERE id_analisis = $1
       ORDER BY anio_mes, sentimiento`,
      [a.id_analisis]
    );

    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      periodo: { nombre: a.nombre, inicio: a.fecha_inicio, fin: a.fecha_fin },
      n_mensajes: a.n_mensajes,
      datos: serie.rows,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/dashboard/sankey
 * Body: { periodo: { nombre, inicio: "YYYY-MM-DD", fin: "YYYY-MM-DD" },
 *         responsable,
 *         datos: [{ topico, sentimiento_dominante, freq }, ...] }
 * Upsert del periodo por nombre y reemplaza las filas del sankey.
 */
router.post('/sankey', requireApiKey, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const periodo = body.periodo ?? {};

    const errPeriodo = validarPeriodo(periodo);
    if (errPeriodo) {
      return res.status(400).json({ error: errPeriodo });
    }
    if (!Array.isArray(body.datos) || body.datos.length === 0) {
      return res.status(400).json({ error: 'datos debe ser un array no vacío' });
    }
    if (body.datos.length > 500) {
      return res.status(400).json({ error: 'datos no puede tener más de 500 filas' });
    }

    const filas = body.datos.map((d) => ({
      topico: String(d.topico ?? '').trim(),
      sentimiento_dominante: String(d.sentimiento_dominante ?? '').trim(),
      freq: aNumero(d.freq),
    }));

    const invalida = filas.find(
      (f) => !f.topico || !f.sentimiento_dominante || f.freq === null || f.freq < 0
    );
    if (invalida) {
      return res.status(400).json({
        error: `Fila inválida: se requiere topico, sentimiento_dominante y freq >= 0 (${invalida.topico || 'sin nombre'})`,
      });
    }

    const cabecera = await upsertCabecera(query, periodo, body.n_mensajes, body.responsable);
    const idAnalisis = cabecera.rows[0].id_analisis;

    await query('DELETE FROM public.analisis_sankey WHERE id_analisis = $1', [idAnalisis]);

    await query(
      `INSERT INTO public.analisis_sankey
         (id_analisis, topico, sentimiento_dominante, freq)
       SELECT $1, * FROM unnest(
         $2::text[], $3::text[], $4::int[]
       )`,
      [
        idAnalisis,
        filas.map((f) => f.topico),
        filas.map((f) => f.sentimiento_dominante),
        filas.map((f) => f.freq),
      ]
    );

    res.status(201).json({ ok: true, id_analisis: idAnalisis, filas: filas.length });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/dashboard/sankey?periodo=<nombre>
 * Devuelve { ok, periodo, n_mensajes, datos } con el cruce tópico x sentimiento.
 */
router.get('/sankey', async (req, res, next) => {
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
    const sankey = await query(
      `SELECT topico, sentimiento_dominante, freq
       FROM public.analisis_sankey
       WHERE id_analisis = $1
       ORDER BY topico, sentimiento_dominante`,
      [a.id_analisis]
    );

    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      periodo: { nombre: a.nombre, inicio: a.fecha_inicio, fin: a.fecha_fin },
      n_mensajes: a.n_mensajes,
      datos: sankey.rows,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
