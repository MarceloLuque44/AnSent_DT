import { useEffect, useState, useCallback, useRef } from 'react';
import { rGet } from '../api.js';
import JSONNodo from '../components/JSONNodo.jsx';

const iconosPorTipo = {
  xlsx: '📗',
  json: '🧾',
};

/**
 * Normaliza los valores que devuelve Plumber (string, ["string"], null).
 */
const aTexto = (v) => {
  if (Array.isArray(v)) return String(v[0] ?? '');
  return v == null ? '' : String(v);
};
const aNumero = (v) => {
  if (Array.isArray(v)) return Number(v[0] ?? 0);
  return Number(v ?? 0);
};

const normalizarBitacoras = (data) => {
  let crudos = data.archivos;
  if (!Array.isArray(crudos)) {
    crudos = crudos && typeof crudos === 'object' ? [crudos] : [];
  }
  return crudos
    .filter((a) => a && typeof a === 'object')
    .map((a) => ({
      nombre: aTexto(a.nombre),
      ruta: aTexto(a.ruta),
      rutaApi: aTexto(a.ruta_api) || `/bitacoras/${aTexto(a.nombre).replace(/\.[^.]+$/, '')}`,
      tipo: aTexto(a.tipo).toLowerCase(),
      tamano_bytes: aNumero(a.tamano_bytes),
      modificado: aTexto(a.modificado),
      hojas: Array.isArray(a.hojas) ? a.hojas.map(aTexto) : a.hojas == null ? [] : [aTexto(a.hojas)],
    }));
};

/**
 * Pantalla "Bitacoras": lista los archivos de r/bitacoras/ (xlsx/json)
 * via GET /bitacoras. Cada archivo es un toggle que carga su contenido
 * paginado desde su endpoint fijo /bitacoras/<archivo>.
 */
export default function Bitacoras() {
  const [archivos, setArchivos] = useState([]);
  const [carpeta, setCarpeta] = useState(null);
  const [activos, setActivos] = useState({});
  const [contenidos, setContenidos] = useState({}); // nombre -> {cargando, datos, error, pagina, ...}
  const [error, setError] = useState(null);
  const [cargando, setCargando] = useState(true);
  const activosRef = useRef(activos);
  activosRef.current = activos;

  const cargarContenido = useCallback(async (nombre, opts = {}) => {
    const archivo = archivos.find((a) => a.nombre === nombre);
    if (!archivo) return;
    const hoja = opts.hoja ?? contenidos[nombre]?.hoja ?? archivo.hojas[0] ?? '';
    const pagina = opts.pagina ?? 1;
    const tamPagina = opts.tamPagina ?? contenidos[nombre]?.tamPagina ?? 50;
    setContenidos((prev) => ({
      ...prev,
      [nombre]: { ...prev[nombre], cargando: true, error: null, datos: null, hoja, pagina, tamPagina },
    }));
    try {
      const qs = new URLSearchParams({
        pagina: String(pagina),
        por_pagina: String(tamPagina),
      });
      if (hoja) qs.set('hoja', hoja);
      const datos = await rGet(`${archivo.rutaApi}?${qs}`);
      if (!datos.ok) throw new Error(datos.mensaje || datos.error || 'Respuesta no válida');
      setContenidos((prev) => ({
        ...prev,
        [nombre]: {
          cargando: false,
          datos,
          error: null,
          hoja,
          pagina: datos.pagina ?? pagina,
          totalPaginas: datos.total_paginas ?? 1,
          tamPagina: datos.tam_pagina ?? tamPagina,
        },
      }));
    } catch (err) {
      setContenidos((prev) => ({
        ...prev,
        [nombre]: { ...prev[nombre], cargando: false, datos: null, error: err.message },
      }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [archivos]);

  const cargar = useCallback(async () => {
    setCargando(true);
    setError(null);
    try {
      const data = await rGet('/bitacoras');
      setArchivos(normalizarBitacoras(data));
      setCarpeta(data.carpeta ? aTexto(data.carpeta) : null);
      // Re-leer los archivos que estan abiertos (los datos cambian con el tiempo)
      Object.keys(activosRef.current).forEach((n) => {
        if (activosRef.current[n] && n) cargarContenido(n, { pagina: 1 });
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }, [cargarContenido]);

  useEffect(() => {
    cargar();
  }, [cargar]);

  const alternar = (nombre) => {
    if (!nombre) return;
    const abrir = !activos[nombre];
    setActivos((prev) => ({ ...prev, [nombre]: abrir }));
    if (abrir) {
      const cache = contenidos[nombre];
      if (!cache?.datos && !cache?.cargando) {
        cargarContenido(nombre, { pagina: 1 });
      }
    }
  };

  // La hoja del xlsx activa se guarda en el estado de contenidos:
  const hojaDe = (a) => contenidos[a.nombre]?.hoja ?? a.hojas[0] ?? '';

  return (
    <div>
      <div className="toolbar">
        <h2>Bitácoras (r/bitacoras)</h2>
        <span className="filtro">
          Carpeta: <code>{carpeta ?? 'r/bitacoras'}</code>
        </span>
        <button className="btn" onClick={cargar} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Refrescar'}
        </button>
      </div>

      {error && <p className="estado-error">Error: {error}</p>}
      {!error && !cargando && archivos.length === 0 && (
        <p className="placeholder">No hay archivos en r/bitacoras todavía.</p>
      )}

      <div className="lista-salida">
        {archivos.map((a) => (
          <div key={a.nombre} className={`archivo-item${activos[a.nombre] ? ' activo' : ''}`}>
            <div className="archivo-fila">
              <span className="archivo-icono">{iconosPorTipo[a.tipo] ?? '🗎'}</span>
              <span className="archivo-nombre">{a.nombre}</span>
              <span className={`tag tag-tipo-${a.tipo || 'desconocido'}`}>
                {a.tipo ? a.tipo.toUpperCase() : 'SIN TIPO'}
              </span>
              <label className="toggle" title="Ver bitacora">
                <input
                  type="checkbox"
                  checked={!!activos[a.nombre]}
                  onChange={() => alternar(a.nombre)}
                />
                <span className="toggle-pista">
                  <span className="toggle-nudo" />
                </span>
              </label>
            </div>

            {activos[a.nombre] && (
              <div className="archivo-detalle">
                <p>
                  <strong>Ruta:</strong> <code>{a.ruta}</code>
                </p>
                <p>
                  <strong>Tamaño:</strong> {(a.tamano_bytes / 1024).toFixed(1)} KB ·{' '}
                  <strong>Modificado:</strong> {a.modificado}
                </p>

                <div className="archivo-contenido">
                  {contenidos[a.nombre]?.cargando && (
                    <p className="placeholder esperando">⏳ Esperando respuesta del servidor…</p>
                  )}
                  {contenidos[a.nombre]?.error && (
                    <p className="estado-error">
                      No se pudo leer el contenido: {contenidos[a.nombre].error}
                    </p>
                  )}
                  {contenidos[a.nombre]?.datos && (
                    contenidos[a.nombre].datos.tipo === 'json' ? (
                      <JSONNodo
                        clave="Contenido JSON"
                        valor={contenidos[a.nombre].datos.filas?.[0]?.valor ?? {}}
                      />
                    ) : (
                      <>
                        {a.hojas.length > 1 && (
                          <div className="bitacora-hojas">
                            <label className="filtro">
                              Hoja:
                              <select
                                value={hojaDe(a)}
                                disabled={contenidos[a.nombre].cargando}
                                onChange={(e) =>
                                  cargarContenido(a.nombre, { hoja: e.target.value, pagina: 1 })
                                }
                              >
                                {a.hojas.map((h) => (
                                  <option key={h} value={h}>
                                    {h}
                                  </option>
                                ))}
                              </select>
                            </label>
                          </div>
                        )}
                        <p className="archivo-contenido-meta">
                          <strong>{contenidos[a.nombre].datos.n_filas}</strong> fila(s) ·{' '}
                          <strong>{contenidos[a.nombre].datos.n_columnas}</strong> columna(s)
                          {contenidos[a.nombre].datos.hoja && <> · hoja: {contenidos[a.nombre].datos.hoja}</>}
                        </p>
                        <div className="paginacion">
                          <button
                            type="button"
                            className="btn btn-mini"
                            disabled={contenidos[a.nombre].cargando ||
                              (contenidos[a.nombre].pagina ?? 1) <= 1}
                            onClick={() =>
                              cargarContenido(a.nombre, {
                                hoja: hojaDe(a),
                                pagina: (contenidos[a.nombre].pagina ?? 1) - 1,
                                tamPagina: contenidos[a.nombre].tamPagina,
                              })
                            }
                          >
                            ◂ Anterior
                          </button>
                          <span className="paginacion-datos">
                            Página <strong>{contenidos[a.nombre].pagina ?? 1}</strong> de{' '}
                            <strong>{contenidos[a.nombre].totalPaginas ?? 1}</strong>
                          </span>
                          <button
                            type="button"
                            className="btn btn-mini"
                            disabled={contenidos[a.nombre].cargando ||
                              (contenidos[a.nombre].pagina ?? 1) >=
                                (contenidos[a.nombre].totalPaginas ?? 1)}
                            onClick={() =>
                              cargarContenido(a.nombre, {
                                hoja: hojaDe(a),
                                pagina: (contenidos[a.nombre].pagina ?? 1) + 1,
                                tamPagina: contenidos[a.nombre].tamPagina,
                              })
                            }
                          >
                            Siguiente ▸
                          </button>
                          <label className="paginacion-size">
                            filas:
                            <select
                              value={contenidos[a.nombre].tamPagina ?? 50}
                              disabled={contenidos[a.nombre].cargando}
                              onChange={(e) =>
                                cargarContenido(a.nombre, {
                                  hoja: hojaDe(a),
                                  pagina: 1,
                                  tamPagina: Number(e.target.value),
                                })
                              }
                            >
                              {[25, 50, 100, 200].map((n) => (
                                <option key={n} value={n}>
                                  {n}
                                </option>
                              ))}
                            </select>
                          </label>
                        </div>
                        <div className="archivo-tabla-scroll">
                          <table className="tabla tabla-archivo">
                            <thead>
                              <tr>
                                {contenidos[a.nombre].datos.columnas.map((col) => (
                                  <th key={col}>{col}</th>
                                ))}
                              </tr>
                            </thead>
                            <tbody>
                              {(contenidos[a.nombre].datos.filas ?? []).map((fila, i) => (
                                <tr key={i}>
                                  {contenidos[a.nombre].datos.columnas.map((col) => {
                                    const v = fila?.[col];
                                    const txt = v == null
                                      ? '—'
                                      : typeof v === 'object'
                                        ? JSON.stringify(v)
                                        : String(v);
                                    return (
                                      <td key={col} title={txt}>
                                        {txt}
                                      </td>
                                    );
                                  })}
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </>
                    )
                  )}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
