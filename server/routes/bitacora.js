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
    console.error('[bitacora/ejecuciones] body keys:', Object.keys(b));
    console.error('[bitacora/ejecuciones] body:', JSON.stringify(b));

    const fecha = esFecha(b.fecha) ? b.fecha : null;
    const hora_inicio = esHora(b.hora_inicio) ? b.hora_inicio : null;
    const hora_fin = esHora(b.hora_fin) ? b.hora_fin : null;
    const duracion_seg = aNumero(b.duracion_seg);
    const responsable = String(b.responsable ?? '').trim();
    const archivo = String(b.archivo ?? '').trim();
    const archivo_md5 = String(b.archivo_md5 ?? '').trim();
    const evento = String(b.evento ?? '').trim();
    const parametros = b.parametros != null ? JSON.stringify(b.parametros) : null;
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
    console.error('[bitacora/ejecuciones] params count:', params.length, 'params:', JSON.stringify(params));

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
    console.error('[bitacora/ejecuciones/:id/pasos] idEjecucion:', idEjecucion, 'pasos count:', pasos.length);
    console.error('[bitacora/ejecuciones/:id/pasos] body keys:', Object.keys(body));
    if (pasos.length > 0) {
      console.error('[bitacora/ejecuciones/:id/pasos] first step keys:', Object.keys(pasos[0]));
      console.error('[bitacora/ejecuciones/:id/pasos] first step:', JSON.stringify(pasos[0]));
    }
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
    console.error('[bitacora/ejecuciones/:id/pasos] columnas:', columnas);
    console.error('[bitacora/ejecuciones/:id/pasos] tipos:', tipos);
    console.error('[bitacora/ejecuciones/:id/pasos] values count:', values.length, 'values:', JSON.stringify(values));

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
    console.error('[bitacora/experimentos] body keys:', Object.keys(b));
    console.error('[bitacora/experimentos] body:', JSON.stringify(b));

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
    console.error('[bitacora/experimentos] params count:', params.length, 'params:', JSON.stringify(params));

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

export default router;
