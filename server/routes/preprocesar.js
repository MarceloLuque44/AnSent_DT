import { Router } from 'express';
import { query } from '../db/pg.js';
import { requireApiKey } from '../middlewares/apiKey.js';

const router = Router();

const LIMIT_MAX = 200;
const POST_MAX = 5000;
const TOKENS_POST_MAX = 100000;

const aNumero = (v) => {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};
const esFecha = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);

/**
 * Especificacion de una tabla de output: columnas (sin id_ejecucion), tipos pg
 * para el cast en unnest y el maximo de filas admitido por POST.
 */
const OUTPUTS = {
  'mensajes-limpios': {
    tabla: 'preprocesar_mensajes_limpios',
    columnas: ['id_mensaje', 'fecha', 'anio_mes', 'autor', 'tipo_contenido', 'texto_limpio', 'polaridad_msg', 'sentimiento_dominante', 'datos'],
    tipos: ['text', 'date', 'text', 'text', 'text', 'text', 'text', 'text', 'jsonb'],
    postMax: POST_MAX,
  },
  'mensajes-excluidos': {
    tabla: 'preprocesar_mensajes_excluidos',
    columnas: ['id_mensaje', 'fecha', 'motivo_exclusion', 'datos'],
    tipos: ['text', 'date', 'text', 'jsonb'],
    postMax: POST_MAX,
  },
  tokens: {
    tabla: 'preprocesar_tokens',
    columnas: ['id_mensaje', 'fecha', 'anio_mes', 'token'],
    tipos: ['text', 'date', 'text', 'text'],
    postMax: TOKENS_POST_MAX,
  },
  stopwords: {
    tabla: 'preprocesar_stopwords',
    columnas: ['palabra', 'accion', 'justificacion'],
    tipos: ['text', 'text', 'text'],
    postMax: POST_MAX,
  },
  'emojis-uso': {
    tabla: 'preprocesar_emojis_uso',
    columnas: ['emoji', 'en_texto', 'en_reacciones', 'significado_es', 'sentimiento', 'polaridad', 'pendiente'],
    tipos: ['text', 'int', 'int', 'text', 'text', 'text', 'text'],
    postMax: POST_MAX,
  },
  'emojis-pendientes': {
    tabla: 'preprocesar_emojis_pendientes',
    columnas: ['datos'],
    tipos: ['jsonb'],
    postMax: POST_MAX,
  },
  resumen: {
    tabla: 'preprocesar_resumen',
    columnas: ['datos'],
    tipos: ['jsonb'],
    postMax: 1,
  },
};

/**
 * Reemplaza todas las filas hijas de un id_ejecucion en una tabla de output
 * (DELETE + INSERT masivo via unnest). `espec` define columnas/tipos; cada
 * fila de `filas` se lee por nombre de columna.
 */
async function reemplazarOutput(idEjecucion, tabla, columnas, tipos, filas) {
  await query(`DELETE FROM public.${tabla} WHERE id_ejecucion = $1`, [idEjecucion]);
  if (filas.length === 0) return;
  const cols = columnas.join(', ');
  const params = tipos.map((t, i) => `$${i + 2}::${t}[]`).join(', ');
  const values = [idEjecucion, ...columnas.map((c) => filas.map((f) => f[c] ?? null))];
  await query(
    `INSERT INTO public.${tabla} (id_ejecucion, ${cols})
     SELECT $1, * FROM unnest(${params})`,
    values
  );
}

/** Cabecera de ejecuciones: columnas y orden de listado. */
const EJEC_COLS = `
  id_ejecucion,
  to_char(fecha, 'YYYY-MM-DD') AS fecha,
  to_char(hora_inicio, 'HH24:MI:SS') AS hora_inicio,
  to_char(hora_fin, 'HH24:MI:SS') AS hora_fin,
  duracion_seg, responsable, archivo, archivo_md5,
  registros_leidos, mensajes_limpios, mensajes_excluidos,
  to_char(rango_fechas_inicio, 'YYYY-MM-DD') AS rango_fechas_inicio,
  to_char(rango_fechas_fin, 'YYYY-MM-DD') AS rango_fechas_fin,
  polaridad, estado, paso_donde_paro, mensaje_error,
  pasos_registrados, to_char(creado_en, 'YYYY-MM-DD"T"HH24:MI:SS') AS creado_en
`;

/** GET /api/preprocesar/ejecuciones — listado paginado con filtros. */
router.get('/ejecuciones', async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, LIMIT_MAX);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const where = [];
    const params = [];

    if (esFecha(req.query.fecha_desde)) {
      params.push(req.query.fecha_desde);
      where.push(`fecha >= $${params.length}::date`);
    }
    if (esFecha(req.query.fecha_hasta)) {
      params.push(req.query.fecha_hasta);
      where.push(`fecha <= $${params.length}::date`);
    }
    if (req.query.archivo) {
      params.push(`%${req.query.archivo}%`);
      where.push(`archivo ILIKE $${params.length}`);
    }
    if (req.query.responsable) {
      params.push(`%${req.query.responsable}%`);
      where.push(`responsable ILIKE $${params.length}`);
    }
    if (req.query.estado) {
      params.push(req.query.estado);
      where.push(`estado = $${params.length}`);
    }
    if (req.query.q) {
      params.push(`%${req.query.q}%`);
      const p = `$${params.length}`;
      where.push(`(
        archivo ILIKE ${p} OR
        responsable ILIKE ${p} OR
        paso_donde_paro ILIKE ${p} OR
        mensaje_error ILIKE ${p}
      )`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const total = await query(
      `SELECT count(*)::int AS total FROM public.preprocesar_ejecuciones ${whereSql}`,
      params
    );

    const filas = await query(
      `SELECT ${EJEC_COLS}
       FROM public.preprocesar_ejecuciones
       ${whereSql}
       ORDER BY fecha DESC NULLS LAST, id_ejecucion DESC
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

/** POST /api/preprocesar/ejecuciones — inserta cabecera, devuelve id_ejecucion. */
router.post('/ejecuciones', requireApiKey, async (req, res, next) => {
  try {
    const b = req.body ?? {};
    const fecha = esFecha(b.fecha) ? b.fecha : null;
    const hora_inicio = typeof b.hora_inicio === 'string' ? b.hora_inicio : null;
    const hora_fin = typeof b.hora_fin === 'string' ? b.hora_fin : null;
    const duracion_seg = aNumero(b.duracion_seg);
    const responsable = String(b.responsable ?? '').trim();
    const archivo = String(b.archivo ?? '').trim();
    const archivo_md5 = String(b.archivo_md5 ?? '').trim();
    const registros_leidos = aNumero(b.registros_leidos);
    const mensajes_limpios = aNumero(b.mensajes_limpios);
    const mensajes_excluidos = aNumero(b.mensajes_excluidos);
    const rango_fechas_inicio = esFecha(b.rango_fechas_inicio) ? b.rango_fechas_inicio : null;
    const rango_fechas_fin = esFecha(b.rango_fechas_fin) ? b.rango_fechas_fin : null;
    const polaridad = b.polaridad != null ? JSON.stringify(b.polaridad) : null;
    const estado = String(b.estado ?? '').trim();
    const paso_donde_paro = String(b.paso_donde_paro ?? '').trim();
    const mensaje_error = String(b.mensaje_error ?? '').trim();
    const pasos_registrados = aNumero(b.pasos_registrados);

    if (!archivo) {
      return res.status(400).json({ error: 'archivo es obligatorio' });
    }

    const result = await query(
      `INSERT INTO public.preprocesar_ejecuciones
        (fecha, hora_inicio, hora_fin, duracion_seg, responsable, archivo, archivo_md5,
         registros_leidos, mensajes_limpios, mensajes_excluidos,
         rango_fechas_inicio, rango_fechas_fin, polaridad, estado, paso_donde_paro,
         mensaje_error, pasos_registrados)
       VALUES (
         $1::date, $2::time, $3::time, $4, $5, $6, $7,
         $8, $9, $10, $11::date, $12::date, $13::jsonb, $14, $15, $16, $17
       )
       RETURNING id_ejecucion`,
      [
        fecha, hora_inicio, hora_fin, duracion_seg, responsable, archivo, archivo_md5,
        registros_leidos, mensajes_limpios, mensajes_excluidos,
        rango_fechas_inicio, rango_fechas_fin, polaridad, estado, paso_donde_paro,
        mensaje_error, pasos_registrados,
      ]
    );

    res.status(201).json({ ok: true, id_ejecucion: result.rows[0].id_ejecucion });
  } catch (err) {
    next(err);
  }
});

/** GET /api/preprocesar/ejecuciones/:id — cabecera de una ejecucion. */
router.get('/ejecuciones/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'id de ejecucion invalido' });
    }

    const fila = await query(
      `SELECT ${EJEC_COLS}
       FROM public.preprocesar_ejecuciones
       WHERE id_ejecucion = $1`,
      [id]
    );

    if (fila.rows.length === 0) {
      return res.status(404).json({ error: 'Ejecucion no encontrada' });
    }

    res.set('Cache-Control', 'no-store');
    res.json({ ok: true, data: fila.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** GET /api/preprocesar/:output?ejecucion=<id>&limit=&offset= — output paginado. */
router.get('/:output', async (req, res, next) => {
  const { output } = req.params;
  const cfg = OUTPUTS[output];
  if (!cfg) return res.status(404).json({ error: 'Output no encontrado' });

  try {
    const idEjecucion = aNumero(req.query.ejecucion);
    if (!idEjecucion) {
      return res.status(400).json({ error: 'ejecucion es obligatorio' });
    }
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, LIMIT_MAX);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const cols = ['id', ...cfg.columnas].join(', ');
    const total = await query(
      `SELECT count(*)::int AS total FROM public.${cfg.tabla} WHERE id_ejecucion = $1`,
      [idEjecucion]
    );

    const filas = await query(
      `SELECT ${cols}
       FROM public.${cfg.tabla}
       WHERE id_ejecucion = $1
       ORDER BY id DESC
       LIMIT $2 OFFSET $3`,
      [idEjecucion, limit, offset]
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

/** POST /api/preprocesar/:output — DELETE WHERE id_ejecucion + INSERT masivo. */
router.post('/:output', requireApiKey, async (req, res, next) => {
  const { output } = req.params;
  const cfg = OUTPUTS[output];
  if (!cfg) return res.status(404).json({ error: 'Output no encontrado' });

  try {
    const body = req.body ?? {};
    const idEjecucion = aNumero(body.id_ejecucion);
    if (!idEjecucion) {
      return res.status(400).json({ error: 'id_ejecucion es obligatorio' });
    }
    const datos = Array.isArray(body.datos) ? body.datos : [];
    if (datos.length === 0) {
      return res.status(400).json({ error: 'datos debe ser un array no vacio' });
    }
    if (datos.length > cfg.postMax) {
      return res.status(400).json({ error: `datos no puede tener mas de ${cfg.postMax} filas` });
    }

    await reemplazarOutput(idEjecucion, cfg.tabla, cfg.columnas, cfg.tipos, datos);

    res.status(201).json({ ok: true, id_ejecucion: idEjecucion, filas: datos.length });
  } catch (err) {
    next(err);
  }
});

export default router;
