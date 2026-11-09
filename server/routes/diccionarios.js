import { Router } from 'express';
import { query } from '../db/pg.js';
import { requireApiKey } from '../middlewares/apiKey.js';

const router = Router();

/** Tipos de diccionario soportados y su tabla/columnas en Postgres. */
const SCHEMAS = {
  sentimientos: {
    tabla: 'public.config_diccionario_sentimientos',
    idCol: 'id',
    columnas: ['orden', 'nombre', 'polaridad', 'activo', 'definicion', 'palabras', 'raices'],
    requeridas: ['nombre', 'polaridad'],
    unicos: ['nombre'],
  },
  emojis: {
    tabla: 'public.config_diccionario_emojis',
    idCol: 'id',
    columnas: ['emoji', 'significado_es', 'sentimiento', 'polaridad', 'nombre_unicode'],
    requeridas: ['emoji', 'significado_es', 'sentimiento', 'polaridad', 'nombre_unicode'],
    unicos: ['emoji'],
  },
  stopwords: {
    tabla: 'public.config_diccionario_stopwords',
    idCol: 'id',
    columnas: ['palabra', 'accion', 'categoria', 'justificacion'],
    requeridas: ['palabra', 'accion', 'categoria'],
    unicos: [],
  },
  palabras_anuncio: {
    tabla: 'public.config_diccionario_palabras_anuncio',
    idCol: 'id',
    columnas: ['tipo', 'patron', 'peso', 'parametro', 'categoria', 'justificacion'],
    requeridas: ['tipo', 'patron'],
    unicos: [],
  },
  genero: {
    tabla: 'public.config_diccionario_genero',
    idCol: 'id',
    columnas: ['palabra', 'genero', 'tipo', 'justificacion'],
    requeridas: ['palabra', 'genero', 'tipo'],
    unicos: [],
  },
  abreviaturas: {
    tabla: 'public.config_diccionario_abreviaturas',
    idCol: 'id',
    columnas: ['abreviatura', 'normal', 'categoria', 'justificacion'],
    requeridas: ['abreviatura', 'normal', 'categoria'],
    unicos: ['abreviatura'],
  },
  emoticonos: {
    tabla: 'public.config_diccionario_emoticonos',
    idCol: 'id',
    columnas: ['emoticono', 'emoji', 'justificacion'],
    requeridas: ['emoticono', 'emoji'],
    unicos: [],
  },
  codigos_materia: {
    tabla: 'public.config_diccionario_codigos_materia',
    idCol: 'id',
    columnas: ['prefijo'],
    requeridas: ['prefijo'],
    unicos: ['prefijo'],
  },
};

const COLS_POR_TABLA = {};
for (const [tipo, s] of Object.entries(SCHEMAS)) {
  COLS_POR_TABLA[s.tabla] = [
    'id',
    ...s.columnas,
    'to_char(creado_en, \'YYYY-MM-DD HH24:MI:SS\') AS creado_en',
    'to_char(actualizado_en, \'YYYY-MM-DD HH24:MI:SS\') AS actualizado_en',
  ];
}

/** GET /api/diccionarios — listar tipos disponibles */
router.get('/', (_req, res) => {
  console.log('[diccionarios] GET /api/diccionarios');
  res.json({
    ok: true,
    tipos: Object.keys(SCHEMAS).map((tipo) => ({
      tipo,
      tabla: SCHEMAS[tipo].tabla,
      columnas: SCHEMAS[tipo].columnas,
      requeridas: SCHEMAS[tipo].requeridas,
    })),
  });
});

/** GET /api/diccionarios/:tipo — listar filas de un diccionario */
router.get('/:tipo', async (req, res, next) => {
  console.log(`[diccionarios] GET /api/diccionarios/${req.params.tipo}`);
  try {
    const s = SCHEMAS[req.params.tipo];
    if (!s) {
      console.log(`[diccionarios] 404 tipo desconocido: ${req.params.tipo}`);
      return res.status(404).json({ error: `Tipo de diccionario desconocido: ${req.params.tipo}` });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    console.log(`[diccionarios] consultando tabla ${s.tabla} (limit=${limit}, offset=${offset})`);
    const total = await query(
      `SELECT count(*)::int AS total FROM ${s.tabla}`,
      []
    );

    const filas = await query(
      `SELECT ${COLS_POR_TABLA[s.tabla].join(', ')}
       FROM ${s.tabla}
       ORDER BY id ASC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    console.log(`[diccionarios] ${s.tabla}: ${filas.rows.length} filas, total=${total.rows[0].total}`);
    res.set('Cache-Control', 'no-store');
    res.json({
      ok: true,
      tipo: req.params.tipo,
      data: filas.rows,
      total: total.rows[0].total,
      limit,
      offset,
    });
  } catch (err) {
    console.error(`[diccionarios] ERROR GET /api/diccionarios/${req.params.tipo}:`, err.message);
    next(err);
  }
});

/** GET /api/diccionarios/:tipo/:id — una fila */
router.get('/:tipo/:id', async (req, res, next) => {
  console.log(`[diccionarios] GET /api/diccionarios/${req.params.tipo}/${req.params.id}`);
  try {
    const s = SCHEMAS[req.params.tipo];
    if (!s) {
      console.log(`[diccionarios] 404 tipo desconocido: ${req.params.tipo}`);
      return res.status(404).json({ error: `Tipo de diccionario desconocido: ${req.params.tipo}` });
    }

    const filas = await query(
      `SELECT ${COLS_POR_TABLA[s.tabla].join(', ')}
       FROM ${s.tabla}
       WHERE ${s.idCol} = $1`,
      [req.params.id]
    );

    if (!filas.rows.length) return res.status(404).json({ error: 'Fila no encontrada' });
    res.json({ ok: true, tipo: req.params.tipo, data: filas.rows[0] });
  } catch (err) {
    console.error(`[diccionarios] ERROR GET /api/diccionarios/${req.params.tipo}/${req.params.id}:`, err.message);
    next(err);
  }
});

/** Convierte campos que son arrays (jsonb en Postgres) a string JSON valido.
 *  httr2 desde R ya envía JSON serializado, pero por seguridad garantizamos
 *  que palabras/raices lleguen como texto con corchetes [] y no como objetos {}. */
const normalizarParametros = (s, b) => {
  return s.columnas.map((c) => normalizarUno(b[c]));
};

/** Convierte un valor individual a texto JSON valido si es array u objeto.
 *  Evita que Postgres reciba {"a","b"} en lugar de ["a","b"] en columnas jsonb. */
const normalizarUno = (v) => {
  if (Array.isArray(v)) return JSON.stringify(v);
  if (v !== null && v !== undefined && typeof v === 'object') return JSON.stringify(v);
  return v;
};

/** POST /api/diccionarios/:tipo — insertar fila */
router.post('/:tipo', requireApiKey, async (req, res, next) => {
  console.log(`[diccionarios] POST /api/diccionarios/${req.params.tipo}`, JSON.stringify(req.body ?? {}));
  try {
    const s = SCHEMAS[req.params.tipo];
    if (!s) {
      console.log(`[diccionarios] 404 tipo desconocido: ${req.params.tipo}`);
      return res.status(404).json({ error: `Tipo de diccionario desconocido: ${req.params.tipo}` });
    }

    const b = req.body ?? {};
    const faltan = s.requeridas.filter((c) => b[c] === undefined || b[c] === null || b[c] === '');
    if (faltan.length) {
      return res.status(400).json({ error: `Campos requeridos faltantes: ${faltan.join(', ')}` });
    }

    const cols = s.columnas;
    const params = normalizarParametros(s, b);
    const placeholders = cols.map((_, i) => `$${i + 1}`).join(', ');

    const result = await query(
      `INSERT INTO ${s.tabla} (${cols.join(', ')})
       VALUES (${placeholders})
       RETURNING ${COLS_POR_TABLA[s.tabla].join(', ')}`,
      params
    );

    console.log(`[diccionarios] INSERT ${s.tabla} id=${result.rows[0].id}`);
    res.status(201).json({ ok: true, tipo: req.params.tipo, data: result.rows[0] });
  } catch (err) {
    console.error(`[diccionarios] ERROR POST /api/diccionarios/${req.params.tipo}:`, err.message);
    next(err);
  }
});

/** PUT /api/diccionarios/:tipo/:id — actualizar fila */
router.put('/:tipo/:id', requireApiKey, async (req, res, next) => {
  console.log(`[diccionarios] PUT /api/diccionarios/${req.params.tipo}/${req.params.id}`, JSON.stringify(req.body ?? {}));
  try {
    const s = SCHEMAS[req.params.tipo];
    if (!s) {
      console.log(`[diccionarios] 404 tipo desconocido: ${req.params.tipo}`);
      return res.status(404).json({ error: `Tipo de diccionario desconocido: ${req.params.tipo}` });
    }

    const b = req.body ?? {};
    const sets = [];
    const params = [];
    let i = 1;
    for (const c of s.columnas) {
      if (c in b) {
        sets.push(`${c} = $${i}`);
        params.push(normalizarUno(b[c]));
        i++;
      }
    }
    if (!sets.length) {
      return res.status(400).json({ error: 'No hay columnas para actualizar' });
    }
    sets.push(`actualizado_en = CURRENT_TIMESTAMP`);
    params.push(req.params.id);

    const result = await query(
      `UPDATE ${s.tabla}
       SET ${sets.join(', ')}
       WHERE ${s.idCol} = $${i}
       RETURNING ${COLS_POR_TABLA[s.tabla].join(', ')}`,
      params
    );

    if (!result.rows.length) return res.status(404).json({ error: 'Fila no encontrada' });
    console.log(`[diccionarios] UPDATE ${s.tabla} id=${req.params.id}`);
    res.json({ ok: true, tipo: req.params.tipo, data: result.rows[0] });
  } catch (err) {
    console.error(`[diccionarios] ERROR PUT /api/diccionarios/${req.params.tipo}/${req.params.id}:`, err.message);
    next(err);
  }
});

/** DELETE /api/diccionarios/:tipo/:id — borrar fila */
router.delete('/:tipo/:id', requireApiKey, async (req, res, next) => {
  console.log(`[diccionarios] DELETE /api/diccionarios/${req.params.tipo}/${req.params.id}`);
  try {
    const s = SCHEMAS[req.params.tipo];
    if (!s) {
      console.log(`[diccionarios] 404 tipo desconocido: ${req.params.tipo}`);
      return res.status(404).json({ error: `Tipo de diccionario desconocido: ${req.params.tipo}` });
    }

    const result = await query(
      `DELETE FROM ${s.tabla} WHERE ${s.idCol} = $1 RETURNING id`,
      [req.params.id]
    );

    if (!result.rows.length) return res.status(404).json({ error: 'Fila no encontrada' });
    console.log(`[diccionarios] DELETE ${s.tabla} id=${req.params.id}`);
    res.json({ ok: true, tipo: req.params.tipo, id: result.rows[0].id });
  } catch (err) {
    console.error(`[diccionarios] ERROR DELETE /api/diccionarios/${req.params.tipo}/${req.params.id}:`, err.message);
    next(err);
  }
});

export default router;
