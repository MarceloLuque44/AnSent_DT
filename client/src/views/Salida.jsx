import { useEffect, useState, useCallback, useRef } from 'react';
import { rGet } from '../api.js';
const iconosPorTipo = {
  csv: '📄',
  json: '🧾',
  txt: '📝',
  png: '🖼️',
  rds: '💾',
  rda: '💾',
  xlsx: '📊',
};

/**
 * Normaliza los valores que devuelve Plumber: puede venir un string,
 * un string dentro de un array (["csv"]) o null.
 */
const aTexto = (v) => {
  if (Array.isArray(v)) return String(v[0] ?? '');
  return v == null ? '' : String(v);
};
const aNumero = (v) => {
  if (Array.isArray(v)) return Number(v[0] ?? 0);
  return Number(v ?? 0);
};

/** Convierte la respuesta de /salida/archivos a una lista uniforme. */
const normalizarArchivos = (data) => {
  let crudos = data.archivos;
  if (!Array.isArray(crudos)) {
    crudos = crudos && typeof crudos === 'object' ? [crudos] : [];
  }
  return crudos
    .filter((a) => a && typeof a === 'object')
    .map((a) => ({
      nombre: aTexto(a.nombre),
      ruta: aTexto(a.ruta),
      tipo: aTexto(a.tipo).toLowerCase(),
      tamano_bytes: aNumero(a.tamano_bytes),
      modificado: aTexto(a.modificado),
    }));
};

/** Endpoint fijo de la API para cada archivo de r/salida/ */
const EXTREMOS_SALIDA = {
  'emojis_en_uso.csv': 'emojis_en_uso',
  'emojis_pendientes.csv': 'emojis_pendientes',
  'mensajes_limpios.csv': 'mensajes_incluidos',
  'mensajes_excluidos.csv': 'mensajes_excluidos',
  'stopwords_aplicadas.csv': 'stopwords_aplicadas',
  'tokens.csv': 'tokens',
  'resumen.json': 'resumen',
};

/** Archivos que se muestran con paginacion (muchas filas). */
const esPaginado = (nombre) =>
  /^(mensajes_incluidos|mensajes_excluidos)$/.test(EXTREMOS_SALIDA[aTexto(nombre)] ?? '');

/**
 * Nodo del arbol JSON: muestra "clave: valor" recursivamente.
 * - Objeto/array: la clave como titulo y los hijos indentados con regla vertical.
 * - Valor escalar: "<clave>: <valor>" en una linea.
 */
function JSONNodo({ clave, valor, nivel = 0 }) {
  if (valor && typeof valor === 'object' && (Array.isArray(valor) || Object.keys(valor).length > 0)) {
    const esArr = Array.isArray(valor);
    const entradas = esArr ? valor.map((v, i) => [String(i), v]) : Object.entries(valor);
    return (
      <div className={nivel > 0 ? 'json-nodo-bloque' : 'json-nodo-raiz'}>
        {clave && (
          <p className="json-nodo-clave">
            {clave}
            <em className="json-nodo-clase">
              {' '}
              ({esArr ? `${entradas.length} elemento(s)` : `${entradas.length} clave(s)`})
            </em>
          </p>
        )}
        <div className="json-nodo-hijos">
          {entradas.map(([k, v]) => (
            <JSONNodo key={k} clave={k} valor={v} nivel={nivel + 1} />
          ))}
        </div>
      </div>
    );
  }
  const txt = valor == null ? '—' : typeof valor === 'number' ? valor.toLocaleString('es-ES') : String(valor);
  return (
    <div className="json-nodo-fila">
      <span className="json-nodo-clave-min">{clave}</span>
      <span className="json-nodo-valor">{txt}</span>
    </div>
  );
}

/**
 * Pantalla "Salida": lista los archivos generados directamente en r/salida/
 * (solo archivos, sin carpetas) via GET /salida/archivos de la API de Plumber.
 * Cada archivo se muestra como un toggle (interruptor) que al activarse
 * despliega su detalle (ruta, tipo, tamano, fecha de modificacion).
 */
export default function Salida() {
  const [archivos, setArchivos] = useState([]);
  const [carpeta, setCarpeta] = useState(null);
  const [activos, setActivos] = useState({});
  const [contenidos, setContenidos] = useState({}); // nombre -> {cargando, datos, error}
  const [error, setError] = useState(null);
  const [cargando, setCargando] = useState(true);
  const activosRef = useRef(activos);
  activosRef.current = activos;

  const cargar = useCallback(async () => {
    setCargando(true);
    setError(null);
    try {
      const data = await rGet('/salida/archivos');
      setArchivos(normalizarArchivos(data));
      setCarpeta(data.carpeta ? aTexto(data.carpeta) : null);
      // Los archivos conservan el nombre pero cambian de datos: re-leer los que estan abiertos
      setContenidos({});
      Object.keys(activosRef.current).forEach((n) => {
        if (activosRef.current[n] && n) cargarContenido(n);
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }, []);

  useEffect(() => {
    cargar();
  }, [cargar]);

  const cargarContenido = useCallback(async (nombre, pagina = 1, tamPagina = 50) => {
    if (!nombre) return;
    setContenidos((prev) => ({
      ...prev,
      [nombre]: {
        ...prev[nombre],
        // En archivos paginados siempre se vuelve a leer la pagina pedida
        datos: esPaginado(nombre) ? null : prev[nombre]?.datos ?? null,
        cargando: true,
        error: null,
      },
    }));
    try {
      const rut = EXTREMOS_SALIDA[nombre];
      const qs = new URLSearchParams({
        pagina: String(pagina),
        por_pagina: String(tamPagina),
      });
      const url = rut
        ? `/salida/${rut}?${qs}`
        : `/salida/archivos/contenido?${new URLSearchParams({ archivo: nombre, ...Object.fromEntries(qs) })}`;
      const datos = await rGet(url);
      if (!datos.ok) throw new Error(datos.mensaje || datos.error || 'Respuesta no válida');
      setContenidos((prev) => ({
        ...prev,
        [nombre]: {
          cargando: false,
          datos,
          error: null,
          pagina: datos.pagina ?? 1,
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
  }, []);

  const alternar = (nombre) => {
    if (!nombre) return;
    const abrir = !activos[nombre];
    setActivos((prev) => ({ ...prev, [nombre]: abrir }));
    if (abrir) {
      const cache = contenidos[nombre];
      if (!cache?.datos && !cache?.cargando) {
        cargarContenido(nombre);
      }
    }
  };

  const contarActivos = () => archivos.filter((a) => activos[a.nombre]).length;

  return (
    <div>
      <div className="toolbar">
        <h2>Archivos de salida</h2>
        <span className="filtro">
          Carpeta: <code>{carpeta ?? 'r/salida'}</code>
        </span>
        <button className="btn" onClick={cargar} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Refrescar'}
        </button>
      </div>

      {error && <p className="estado-error">Error: {error}</p>}

      {!error && !cargando && archivos.length === 0 && (
        <p className="placeholder">No hay archivos en r/salida todavía.</p>
      )}

      {archivos.length > 0 && (
        <>
          <p className="archivo-total">
            {archivos.length} archivo(s) · {contarActivos()} seleccionado(s) ·{' '}
            {archivos.length - contarActivos()} sin seleccionar
          </p>

          <div className="lista-salida">
            {archivos.map((a) => (
              <div key={a.nombre} className={`archivo-item${activos[a.nombre] ? ' activo' : ''}`}>
                <div className="archivo-fila">
                  <span className="archivo-icono">{iconosPorTipo[a.tipo] ?? '🗎'}</span>
                  <span className="archivo-nombre">{a.nombre}</span>
                  <span className={`tag tag-tipo-${a.tipo || 'desconocido'}`}>
                    {a.tipo ? a.tipo.toUpperCase() : 'SIN TIPO'}
                  </span>
                  <label className="toggle" title="Seleccionar archivo">
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
                        <p className="placeholder esperando">
                          ⏳ Esperando respuesta del servidor…
                        </p>
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
                            valor={contenidos[a.nombre].datos.filas?.[0] ?? {}}
                          />
                        ) : (
                        <>
                          <p className="archivo-contenido-meta">
                            <strong>{contenidos[a.nombre].datos.n_filas}</strong> fila(s) ·{' '}
                            <strong>{contenidos[a.nombre].datos.n_columnas}</strong> columna(s)
                          </p>
                          {esPaginado(a.nombre) && (
                            <div className="paginacion">
                              <button
                                type="button"
                                className="btn btn-mini"
                                disabled={contenidos[a.nombre].cargando ||
                                  (contenidos[a.nombre].pagina ?? 1) <= 1}
                                onClick={() =>
                                  cargarContenido(
                                    a.nombre,
                                    (contenidos[a.nombre].pagina ?? 1) - 1,
                                    contenidos[a.nombre].tamPagina
                                  )
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
                                  cargarContenido(
                                    a.nombre,
                                    (contenidos[a.nombre].pagina ?? 1) + 1,
                                    contenidos[a.nombre].tamPagina
                                  )
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
                                    cargarContenido(a.nombre, 1, Number(e.target.value))
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
                          )}
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
                                {contenidos[a.nombre].datos.filas.map((fila, i) => (
                                  <tr key={i}>
                                    {contenidos[a.nombre].datos.columnas.map((col) => (
                                      <td key={col}>
                                        {fila[col] == null ? '—' : String(fila[col])}
                                      </td>
                                    ))}
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
        </>
      )}
    </div>
  );
}
