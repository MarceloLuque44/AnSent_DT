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
const esHora = (v) => typeof v === 'string' && /^\d{2}:\d{2}:\d{2}$/.test(v);

/** POST /api/bitacora/ejecuciones — inserta cabecera de ejecucion de bitacora, devuelve id_ejecucion. */
router.post('/ejecuciones', requireApiKey, async (req, res, next) => {
  try {
    const b = req.body ?? {};

    const fecha = esFecha(b.fecha) ? b.fecha : null;
    const hora_inicio = esHora(b.hora_inicio) ? b.hora_inicio : null;
    const hora_fin = esHora(b.hora_fin) ? b.hora_fin : null;
    const duracion_seg = aNumero(b.duracion_seg);
    const responsable = String(b.responsable ?? '').trim();
    const archivo = String(b.archivo ?? '').trim();
    const archivo_md5 = String(b.archivo_md5 ?? '').trim();
    const evento = String(b.evento ?? '').trim();
    const parametros =
      b.parametros == null
        ? null
        : typeof b.parametros === 'string'
          ? b.parametros
          : JSON.stringify(b.parametros);
    const estado = String(b.estado ?? '').trim();
    const paso_donde_paro = String(b.paso_donde_paro ?? '').trim();
    const mensaje_error = String(b.mensaje_error ?? '').trim();
    const pasos_registrados = aNumero(b.pasos_registrados);
    const registros_leidos = aNumero(b.registros_leidos);
    const mensajes_limpios = aNumero(b.mensajes_limpios);
    const mensajes_excluidos = aNumero(b.mensajes_excluidos);
    const emojis_pendientes = aNumero(b.emojis_pendientes);
    const cambios_detectados = String(b.cambios_detectados ?? '').trim();

    const params = [
      fecha, responsable, archivo, archivo_md5, evento, parametros,
      estado, paso_donde_paro, mensaje_error, pasos_registrados,
      registros_leidos, mensajes_limpios, mensajes_excluidos,
      emojis_pendientes, cambios_detectados,
    ];

    const result = await query(
      `INSERT INTO public.ejecuciones
        (fecha, responsable, archivo, archivo_md5, evento, parametros,
         estado, paso_donde_paro, mensaje_error, pasos_registrados,
         registros_leidos, mensajes_limpios, mensajes_excluidos,
         emojis_pendientes, cambios_detectados)
       VALUES (
        $1::timestamp, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11, $12, $13, $14, $15
       )
       RETURNING id_ejecucion`,
      params
    );

    res.status(201).json({ ok: true, id_ejecucion: result.rows[0].id_ejecucion });
  } catch (err) {
    console.error('[bitacora/ejecuciones] ERROR:', err.message);
    console.error('[bitacora/ejecuciones] ERROR stack:', err.stack);
    console.error('[bitacora/ejecuciones] ERROR code:', err.code);
    console.error('[bitacora/ejecuciones] ERROR detail:', err.detail);
    console.error('[bitacora/ejecuciones] ERROR hint:', err.hint);
    next(err);
  }
});

/** POST /api/bitacora/ejecuciones/:id/pasos — DELETE WHERE ejecucion_id + INSERT masivo de pasos. */
router.post('/ejecuciones/:id/pasos', requireApiKey, async (req, res, next) => {
  try {
    const idEjecucion = parseInt(req.params.id, 10);
    if (!Number.isInteger(idEjecucion) || idEjecucion <= 0) {
      return res.status(400).json({ error: 'id de ejecucion invalido' });
    }

    const body = req.body ?? {};
    const pasos = Array.isArray(body.pasos) ? body.pasos : [];
    if (pasos.length === 0) {
      return res.status(400).json({ error: 'pasos debe ser un array no vacio' });
    }

    await query(`DELETE FROM public.ejecucion_pasos WHERE ejecucion_id = $1`, [idEjecucion]);

    const columnas = [
      'id_instancia', 'id_paso', 'etapa', 'campo_columna',
      'tipo_problema', 'accion_realizada', 'filas_antes', 'filas_despues',
      'filas_afectadas', 'impacto_dataset', 'ejemplo_antes', 'ejemplo_despues',
      'mensaje_error', 'script',
    ];
    const tipos = [
      'text', 'text', 'text', 'text', 'text', 'text',
      'int', 'int', 'int', 'text', 'text', 'text', 'text', 'text',
    ];
    const params = tipos.map((t, i) => `$${i + 2}::${t}[]`).join(', ');
    const values = [idEjecucion, ...columnas.map((c) => pasos.map((p) => p[c] ?? null))];

    await query(
      `INSERT INTO public.ejecucion_pasos (ejecucion_id, ${columnas.join(', ')})
       SELECT $1, * FROM unnest(${params})`,
      values
    );

    res.status(201).json({ ok: true, id_ejecucion, filas: pasos.length });
  } catch (err) {
    console.error('[bitacora/ejecuciones/:id/pasos] ERROR:', err.message);
    console.error('[bitacora/ejecuciones/:id/pasos] ERROR stack:', err.stack);
    console.error('[bitacora/ejecuciones/:id/pasos] ERROR code:', err.code);
    console.error('[bitacora/ejecuciones/:id/pasos] ERROR detail:', err.detail);
    console.error('[bitacora/ejecuciones/:id/pasos] ERROR hint:', err.hint);
    next(err);
  }
});

/** POST /api/bitacora/experimentos — inserta experimento de bitacora. */
router.post('/experimentos', requireApiKey, async (req, res, next) => {
  try {
    const b = req.body ?? {};

    const fecha = esFecha(b.fecha) ? b.fecha : null;
    const hora = esHora(b.hora) ? b.hora : null;
    const id_ejecucion_preprocesamiento = aNumero(b.id_ejecucion_preprocesamiento);
    const dataset = String(b.dataset ?? '').trim();
    const dataset_md5 = String(b.dataset_md5 ?? '').trim();
    const metodo = String(b.metodo ?? '').trim();
    const parametros = String(b.parametros ?? '').trim();
    const n_documentos = aNumero(b.n_documentos);
    const tamano_vocabulario = aNumero(b.tamano_vocabulario);
    const resultado_principal = String(b.resultado_principal ?? '').trim();
    const archivo_resultado = String(b.archivo_resultado ?? '').trim();
    const notas = String(b.notas ?? '').trim();
    const responsable = String(b.responsable ?? '').trim();

    const params = [
      fecha, hora, id_ejecucion_preprocesamiento, dataset, dataset_md5,
      metodo, parametros, n_documentos, tamano_vocabulario,
      resultado_principal, archivo_resultado, notas, responsable,
    ];

    const result = await query(
      `INSERT INTO public.experimentos
        (fecha, hora, id_ejecucion_preprocesamiento, dataset, dataset_md5,
         metodo, parametros, n_documentos, tamano_vocabulario,
         resultado_principal, archivo_resultado, notas, responsable)
       VALUES (
        $1::date, $2::time, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
       )
       RETURNING id`,
      params
    );

    res.status(201).json({ ok: true, id: result.rows[0].id });
  } catch (err) {
    console.error('[bitacora/experimentos] ERROR:', err.message);
    console.error('[bitacora/experimentos] ERROR stack:', err.stack);
    console.error('[bitacora/experimentos] ERROR code:', err.code);
    console.error('[bitacora/experimentos] ERROR detail:', err.detail);
    console.error('[bitacora/experimentos] ERROR hint:', err.hint);
    next(err);
  }
});

/** GET /api/bitacora/bitacora — listado paginado de pasos de la bitacora limpia. */
router.get('/bitacora', async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const where = [];
    const params = [];

    const esFecha = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);
    if (esFecha(req.query.fecha_desde)) {
      params.push(req.query.fecha_desde);
      where.push(`fecha >= $${params.length}::date`);
    }
    if (esFecha(req.query.fecha_hasta)) {
      params.push(req.query.fecha_hasta);
      where.push(`fecha <= $${params.length}::date`);
    }
    if (req.query.responsable) {
      params.push(`%${req.query.responsable}%`);
      where.push(`responsable ILIKE $${params.length}`);
    }
    if (req.query.id_paso) {
      params.push(`%${req.query.id_paso}%`);
      where.push(`id_paso ILIKE $${params.length}`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const total = await query(
      `SELECT count(*)::int AS total FROM public.bitacora ${whereSql}`,
      params
    );

    const filas = await query(
      `SELECT id,
              to_char(fecha, 'YYYY-MM-DD') AS fecha,
              to_char(hora, 'HH24:MI:SS') AS hora,
              campo_columna, id_paso, atributo, tipo_problema, metodologia,
              accion_realizada, justificacion, filas_afectadas, impacto_dataset,
              script, filas_antes, filas_despues, ejemplo_antes, ejemplo_despues,
              id_mensaje_ejemplo, responsable,
              to_char(creado_en, 'YYYY-MM-DD"T"HH24:MI:SS') AS creado_en
       FROM public.bitacora
       ${whereSql}
       ORDER BY fecha DESC NULLS LAST, id DESC
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
    console.error('[bitacora/bitacora] ERROR:', err.message);
    next(err);
  }
});

/** POST /api/bitacora/bitacora — inserta masivamente filas de la bitacora limpia.
 * Body: { filas: [{ campo_columna, id_paso, fecha, hora, ... }] } */
router.post('/bitacora', requireApiKey, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const filas = Array.isArray(body.filas) ? body.filas : [];
    if (filas.length === 0) {
      return res.status(400).json({ error: 'filas debe ser un array no vacio' });
    }

    const columnas = [
      'campo_columna', 'id_paso', 'fecha', 'hora', 'atributo', 'tipo_problema',
      'metodologia', 'accion_realizada', 'justificacion', 'filas_afectadas',
      'impacto_dataset', 'script', 'filas_antes', 'filas_despues',
      'ejemplo_antes', 'ejemplo_despues', 'id_mensaje_ejemplo', 'responsable',
    ];
    const tipos = [
      'text', 'text', 'date', 'time', 'text', 'text',
      'text', 'text', 'text', 'int', 'text', 'text',
      'int', 'int', 'text', 'text', 'text', 'text',
    ];
    const params = tipos.map((t, i) => `$${i + 1}::${t}[]`).join(', ');
    const values = columnas.map((c) => filas.map((f) => f[c] ?? null));

    await query(
      `INSERT INTO public.bitacora (${columnas.join(', ')})
       SELECT * FROM unnest(${params})`,
      values
    );

    res.status(201).json({ ok: true, filas: filas.length });
  } catch (err) {
    console.error('[bitacora/bitacora POST] ERROR:', err.message);
    next(err);
  }
});

export default router;
