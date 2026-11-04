/**
 * Servicio de configuraciones y graficos.
 * Gestiona las configuraciones que el frontend envia para cada paso
 * y la informacion de los archivos generados (rutas en memoria)
 * para que el frontend pueda renderizar imagenes y CSV.
 */
import db from '../db/sqlite.js';
import { config } from '../config.js';
import * as rService from './rService.js';
import { publish } from './sseHub.js';

const NOW = () => new Date().toISOString();

/** Listar todas las configuraciones guardadas */
export function listarConfiguraciones() {
  return db.prepare('SELECT * FROM configuraciones ORDER BY actualizado_en DESC').all();
}

/** Obtener una configuracion por id */
export function obtenerConfiguracion(id) {
  return db.prepare('SELECT * FROM configuraciones WHERE id = ?').get(id);
}

/** Crear o actualizar una configuracion */
export function guardarConfiguracion({ nombre, paso, parametros }) {
  const existente = db.prepare('SELECT id FROM configuraciones WHERE nombre = ? AND paso = ?').get(nombre, paso);
  const ahora = NOW();
  if (existente) {
    db.prepare(
      `UPDATE configuraciones SET parametros = ?, actualizado_en = ? WHERE id = ?`
    ).run(JSON.stringify(parametros), ahora, existente.id);
    return { id: existente.id, nombre, paso, parametros, actualizado_en: ahora };
  }
  const result = db.prepare(
    `INSERT INTO configuraciones (nombre, paso, parametros, creado_en, actualizado_en)
     VALUES (?, ?, ?, ?, ?)`
  ).run(nombre, paso, JSON.stringify(parametros), ahora, ahora);
  return { id: result.lastInsertRowid, nombre, paso, parametros, creado_en: ahora, actualizado_en: ahora };
}

/** Eliminar una configuracion */
export function eliminarConfiguracion(id) {
  return db.prepare('DELETE FROM configuraciones WHERE id = ?').run(id);
}

/** Guardar informacion de un archivo generado (ruta en memoria) */
export function registrarArchivoGenerado({ paso, archivo, ruta, tipo, tamaño_bytes }) {
  const ahora = NOW();
  const result = db.prepare(
    `INSERT INTO graficos_info (paso, archivo, ruta, tipo, tamaño_bytes, creado_en)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).run(paso, archivo, ruta, tipo, tamaño_bytes ?? null, ahora);
  const fila = db.prepare('SELECT * FROM graficos_info WHERE id = ?').get(result.lastInsertRowid);
  publish('grafico:nuevo', fila);
  return fila;
}

/** Listar archivos generados por paso */
export function listarArchivosGenerados(paso = null) {
  if (paso !== null) {
    return db.prepare('SELECT * FROM graficos_info WHERE paso = ? ORDER BY creado_en DESC').all(paso);
  }
  return db.prepare('SELECT * FROM graficos_info ORDER BY creado_en DESC').all();
}

/** Obtener archivos de imagen (PNG) por paso para renderizar en el frontend */
export function obtenerImagenesPaso(paso) {
  return db.prepare(
    "SELECT * FROM graficos_info WHERE paso = ? AND tipo IN ('png', 'jpg', 'jpeg') ORDER BY creado_en DESC"
  ).all(paso);
}

/** Obtener archivos CSV por paso */
export function obtenerCsvsPaso(paso) {
  return db.prepare(
    "SELECT * FROM graficos_info WHERE paso = ? AND tipo = 'csv' ORDER BY creado_en DESC"
  ).all(paso);
}

/** Proxy: ejecutar un paso en Plumber y registrar los archivos devueltos */
export async function ejecutarPaso(paso, body = {}) {
  let endpoint;
  switch (paso) {
    case 1: endpoint = '/paso/preprocesar'; break;
    case 2: endpoint = '/paso/analizar-periodo'; break;
    case 3: endpoint = '/paso/comparar-periodos'; break;
    case 4: endpoint = '/paso/analizar-oracion'; break;
    default: throw new Error(`Paso invalido: ${paso}`);
  }

  // El paso 1 recorre todo el chat y los pasos 2/3 entrenan LDA, corren udpipe
  // y syuzhet y generan ~25 gráficos: pueden tardar varios minutos. Con 120 s
  // el proxy cortaba la peticion y el navegador mostraba ECONNRESET/“se queda
  // cargando” aunque R siguiera trabajando.
  const timeoutMs = paso <= 3 ? 900000 : 300000;
  const resultado = await rService.rFetchRaw(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }, timeoutMs);

  if (resultado === null) {
    throw new Error('Plumber no disponible. Inicia Rscript r/plumber_api.R');
  }

  // Registrar archivos devueltos por Plumber en la base de datos
  const archivos = resultado.archivos || [];
  const archivosAnalisis = resultado.archivos_analisis || [];
  const todosLosArchivos = [...archivos, ...archivosAnalisis];

  for (const arch of todosLosArchivos) {
    if (arch.ruta) {
      registrarArchivoGenerado({
        paso,
        archivo: arch.nombre,
        ruta: arch.ruta,
        tipo: arch.tipo,
        tamaño_bytes: null,
      });
    }
  }

  // Si el resultado trae dir_analisis, listar sus archivos PNG/CSV para registro
  if (resultado.dir_analisis) {
    // Los archivos ya se registraron arriba si Plumber los retorno.
    // El frontend puede solicilar listado por paso.
  }

  return resultado;
}

/** Ejecutar preprocesamiento (endpoint existente, compatibilidad) */
export async function ejecutarPreprocesamiento(body = {}) {
  try {
    return await rService.rFetchRaw('/preprocesar', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, 900000);
  } catch (err) {
    console.error('[configService] Error en ejecutarPreprocesamiento:', err.message);
    return null;
  }
}
