import { useCallback, useEffect, useRef, useState } from 'react';
import { apiGet } from '../api.js';

const ICONOS_POR_TIPO = {
  csv: '📄',
  json: '🧾',
  txt: '📝',
};

const aTexto = (v) => {
  if (Array.isArray(v)) return String(v[0] ?? '');
  return v == null ? '' : String(v);
};

/** Parseo simple de CSV con encabezado. */
const parsearCSV = (texto) => {
  if (!texto || !texto.trim()) return { columnas: [], filas: [] };
  const lineas = texto.split(/\r?\n/).filter((l) => l.trim().length > 0);
  if (lineas.length === 0) return { columnas: [], filas: [] };
  const separador = lineas[0].includes(';') ? ';' : ',';
  const columnas = lineas[0].split(separador).map((c) => c.trim().replace(/"/g, ''));
  const filas = lineas.slice(1).map((linea) => {
    const valores = linea.split(separador).map((v) => v.trim().replace(/"/g, ''));
    const obj = {};
    columnas.forEach((col, i) => {
      obj[col] = valores[i] ?? '';
    });
    return obj;
  });
  return { columnas, filas };
};

/**
 * Pantalla "Sentimientos": lista los archivos de configuracion en r/config/
 * (diccionarios, stopwords, emojis, periodos, etc.) via
 * GET /api/sentimientos de la API de Express.
 * Cada archivo se muestra como un toggle que al activarse despliega su contenido.
 */
export default function Sentimientos() {
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
      const data = await apiGet('/api/sentimientos');
      const lista = Array.isArray(data.archivos) ? data.archivos : [];
      setArchivos(lista);
      setCarpeta(data.carpeta ? aTexto(data.carpeta) : null);
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

  const cargarContenido = useCallback(async (nombre) => {
    if (!nombre) return;
    setContenidos((prev) => ({
      ...prev,
      [nombre]: { cargando: true, datos: null, error: null },
    }));
    try {
      const datos = await apiGet(`/api/sentimientos/${encodeURIComponent(nombre)}`);
      if (!datos.ok) throw new Error(datos.error || 'Respuesta no valida');
      setContenidos((prev) => ({
        ...prev,
        [nombre]: { cargando: false, datos, error: null },
      }));
    } catch (err) {
      setContenidos((prev) => ({
        ...prev,
        [nombre]: { cargando: false, datos: null, error: err.message },
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
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Sentimientos y configuración</h1>
          <p className="page-desc">
            Archivos de configuracion en <code>{carpeta ?? 'r/config'}</code>.
            Activa un archivo para leer su contenido aqui mismo.
          </p>
        </div>
        <button className="btn" onClick={cargar} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Refrescar'}
        </button>
      </header>

      {error && <p className="estado-error">Error: {error}</p>}

      {!error && !cargando && archivos.length === 0 && (
        <p className="placeholder">No hay archivos en r/config todavía.</p>
      )}

      {archivos.length > 0 && (
        <>
          <p className="resumen-chips">
            <span className="chip">{archivos.length} archivos</span>
            <span className="chip chip-activo">{contarActivos()} abiertos</span>
            <span className="chip chip-tenue">
              {archivos.length - contarActivos()} cerrados
            </span>
          </p>

          <div className="lista-salida">
            {archivos.map((a) => (
              <div
                key={a.nombre}
                className={`archivo-item${activos[a.nombre] ? ' activo' : ''}`}
              >
                <div className="archivo-fila">
                  <span className="archivo-icono" aria-hidden="true">
                    {ICONOS_POR_TIPO[a.tipo] ?? '🗎'}
                  </span>
                  <div className="archivo-identidad">
                    <span className="archivo-nombre">{a.nombre}</span>
                    <span className="archivo-datos">
                      {(a.tamano_bytes / 1024).toFixed(1)} KB ·{' '}
                      {new Date(a.modificado).toLocaleString()}
                    </span>
                  </div>
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
                        <>
                          {contenidos[a.nombre].datos.tipo === 'json' ? (
                            <div className="archivo-contenido-json">
                              <pre>{JSON.stringify(contenidos[a.nombre].datos.contenido, null, 2)}</pre>
                            </div>
                          ) : (
                            <>
                              <p className="archivo-contenido-meta">
                                Archivo: <strong>{contenidos[a.nombre].datos.archivo}</strong>
                              </p>
                              {contenidos[a.nombre].datos.tipo === 'csv' ? (
                                <>
                                  {(() => {
                                    const parsed = parsearCSV(
                                      contenidos[a.nombre].datos.contenido
                                    );
                                    if (!parsed.columnas.length) {
                                      return (
                                        <p className="estado-error">
                                          No se pudieron leer las columnas del CSV.
                                        </p>
                                      );
                                    }
                                    return (
                                      <>
                                        <p className="archivo-contenido-meta">
                                          <strong>{parsed.filas.length}</strong> fila(s) ·{' '}
                                          <strong>{parsed.columnas.length}</strong> columna(s)
                                        </p>
                                        <div className="archivo-tabla-scroll">
                                          <table className="tabla tabla-archivo">
                                            <thead>
                                              <tr>
                                                {parsed.columnas.map((col) => (
                                                  <th key={col}>{col}</th>
                                                ))}
                                              </tr>
                                            </thead>
                                            <tbody>
                                              {parsed.filas.map((fila, i) => (
                                                <tr key={i}>
                                                  {parsed.columnas.map((col) => (
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
                                    );
                                  })()}
                                </>
                              ) : (
                                <div className="archivo-contenido-txt">
                                  <pre>{contenidos[a.nombre].datos.contenido}</pre>
                                </div>
                              )}
                            </>
                          )}
                        </>
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
