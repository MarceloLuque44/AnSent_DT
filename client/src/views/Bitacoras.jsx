import { useEffect, useState, useCallback } from 'react';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';
import { rGet } from '../api.js';
import JSONNodo from '../components/JSONNodo.jsx';

const iconosPorTipo = {
  xlsx: '📗',
  json: '🧾',
};

/**
 * Normaliza los valores que devuelve Plumber (unboxed con [] vacias como {},
 * boxed con valores como ["valor"], null).
 */
const aTexto = (v) => {
  if (Array.isArray(v)) return v.length ? String(aTexto(v[0])) : '';
  if (v == null) return '';
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
};
const aNumero = (v, def = 0) => {
  if (Array.isArray(v)) return aNumero(v[0], def);
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
};
const aLista = (v) => {
  if (Array.isArray(v)) return v;
  if (v == null) return [];
  if (typeof v === 'object' && Object.keys(v).length === 0) return []; // unboxed vacio
  if (typeof v === 'object') return Object.values(v);
  return [v];
};

const normalizarBitacoras = (data) => {
  let crudos = data?.archivos;
  if (!Array.isArray(crudos)) {
    crudos = crudos && typeof crudos === 'object' ? Object.values(crudos) : [];
  }
  return crudos
    .filter((a) => a && typeof a === 'object')
    .map((a) => {
      const nombre = aTexto(a.nombre);
      return {
        nombre,
        ruta: aTexto(a.ruta),
        rutaApi: aTexto(a.ruta_api) || `/bitacoras/${nombre.replace(/\.[^.]+$/, '')}`,
        tipo: aTexto(a.tipo).toLowerCase(),
        tamano_bytes: aNumero(a.tamano_bytes),
        modificado: aTexto(a.modificado),
        hojas: aLista(a.hojas).map((h) => aTexto(h)).filter(Boolean),
      };
    })
    .filter((a) => a.nombre && !a.nombre.startsWith('~$'));
};

/**
 * Pantalla "Bitacoras": selector de bitacora (xlsx/json de r/bitacoras/),
 * luego selector de hoja (para xlsx) y contenido paginado via
 * GET /bitacoras/<archivo>?hoja=&pagina=&por_pagina=
 */
export default function Bitacoras() {
  const [archivos, setArchivos] = useState([]);
  const [carpeta, setCarpeta] = useState(null);
  const [seleccion, setSeleccion] = useState(null); // nombre del archivo elegido
  const [hoja, setHoja] = useState(null); // hoja elegida del xlsx seleccionado
  const [carga, setCarga] = useState({ estado: 'inicial', error: null }); // estado de la lista
  const [datos, setDatos] = useState(null); // respuesta de contenido
  const [pagina, setPagina] = useState(1);
  const [tamPagina, setTamPagina] = useState(50);
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState(null);

  // Lista de bitacoras
  const cargarLista = useCallback(async () => {
    setCarga({ estado: 'cargando', error: null });
    try {
      const data = await rGet('/bitacoras');
      const lista = normalizarBitacoras(data);
      setArchivos(lista);
      setCarpeta(data?.carpeta ? aTexto(data.carpeta) : null);
      setSeleccion((sel) => sel ?? lista.find((a) => a.nombre === 'bitacora_limpia.xlsx')?.nombre ?? lista[0]?.nombre ?? null);
      setCarga({ estado: 'lista', error: null });
    } catch (err) {
      setCarga({ estado: 'error', error: err.message });
    }
  }, []);

  useEffect(() => {
    cargarLista();
  }, [cargarLista]);

  const archivo = archivos.find((a) => a.nombre === seleccion) ?? null;

  // Hoja por defecto cuando cambia el archivo seleccionado
  useEffect(() => {
    if (!archivo) {
      setHoja(null);
      return;
    }
    if (archivo.tipo !== 'xlsx') {
      setHoja(null);
      return;
    }
    setHoja((h) => (h && archivo.hojas.includes(h) ? h : archivo.hojas[0] ?? null));
  }, [archivo]);

  // Cargar contenido cuando cambian archivo / hoja / pagina / tamPagina
  const cargarContenido = useCallback(async () => {
    if (!archivo) return;
    setCargando(true);
    setError(null);
    try {
      const qs = new URLSearchParams({
        pagina: String(pagina),
        por_pagina: String(tamPagina),
      });
      if (hoja) qs.set('hoja', hoja);
      const resp = await rGet(`${archivo.rutaApi}?${qs}`);
      if (!resp?.ok) throw new Error(resp?.mensaje || resp?.error || 'Respuesta no valida');
      setDatos({
        tipo: resp.tipo === 'json' ? 'json' : (hoja ? 'hoja' : 'tabla'),
        columnas: aLista(resp.columnas).map(aTexto),
        filas: aLista(resp.filas), // cada fila es {<columna>: valor}
        nFilas: aNumero(resp.n_filas, 0),
        nColumnas: aNumero(resp.n_columnas, 0),
        pagina: aNumero(resp.pagina, pagina) || pagina,
        totalPaginas: aNumero(resp.total_paginas, 1),
        tamPagina: aNumero(resp.tam_pagina, tamPagina) || tamPagina,
        hojaUsada: resp.hoja ? aTexto(resp.hoja) : hoja,
      });
      if (resp.pagina) setPagina(aNumero(resp.pagina, pagina));
    } catch (err) {
      setDatos(null);
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }, [archivo, hoja, pagina, tamPagina]);

  useEffect(() => {
    cargarContenido();
  }, [cargarContenido]);

  // ----- Grafico de dispersion con lineas (recharts) -----
  // Muestra "filas_despues" de cada registro, solo de bitacora_limpia.xlsx.
  const [serie, setSerie] = useState(null); // [{registro, filas}]
  const [serieCargando, setSerieCargando] = useState(false);
  const [serieError, setSerieError] = useState(null);

  useEffect(() => {
    let vivo = true;
    const esLimpia = archivo?.nombre === 'bitacora_limpia.xlsx';
    if (!esLimpia) {
      setSerie(null);
      setSerieError(null);
      return undefined;
    }
    (async () => {
      setSerieCargando(true);
      setSerieError(null);
      try {
        const puntos = [];
        let numeroPagina = 1;
        // Hoja "Bitacora": traer todas las paginas (52 registros, caben en pocas)
        for (;;) {
          const resp = await rGet(
            `${archivo.rutaApi}?hoja=Bitacora&pagina=${numeroPagina}&por_pagina=200`
          );
          if (!resp?.ok) throw new Error(resp?.mensaje || resp?.error || 'Respuesta no valida');
          const columnas = aLista(resp.columnas).map(aTexto);
          const idxReg = columnas.includes('id_paso') ? 'id_paso' : null;
          aLista(resp.filas).forEach((fila, i) => {
            const bruto = fila?.filas_despues;
            const n = bruto == null ? NaN : aNumero(bruto, NaN);
            puntos.push({
              registro: idxReg ? aTexto(fila[idxReg]) || String(puntos.length + 1) : String(puntos.length + 1),
              filas: Number.isFinite(n) ? n : null,
              tipo: aTexto(fila?.tipo_problema) || aTexto(fila?.accion_realizada) || '',
            });
          });
          const total = aNumero(resp.total_paginas, 1) || 1;
          if (numeroPagina >= total) break;
          numeroPagina += 1;
        }
        if (vivo) setSerie(puntos);
      } catch (err) {
        if (vivo) {
          setSerie(null);
          setSerieError(err.message);
        }
      } finally {
        if (vivo) setSerieCargando(false);
      }
    })();
    return () => {
      vivo = false;
    };
  }, [archivo]);

  // Al cambiar de archivo u hoja, reiniciar la paginacion
  const elegirArchivo = (nombre) => {
    setSeleccion(nombre);
    setPagina(1);
    setDatos(null);
    setError(null);
  };
  const elegirHoja = (h) => {
    setHoja(h);
    setPagina(1);
    setDatos(null);
    setError(null);
  };

  // El contenido JSON (_copia_de_control) se saca de la primera fila
  const jsonValor =
    archivo?.tipo === 'json' && datos?.filas?.length
      ? datos.filas[0]
      : null;

  return (
    <div>
      <div className="toolbar">
        <h2>Bitácoras (r/bitacoras)</h2>
        <span className="filtro">
          Carpeta: <code>{carpeta ?? 'r/bitacoras'}</code>
        </span>
        <button className="btn" onClick={cargarLista} disabled={carga.estado === 'cargando'}>
          {carga.estado === 'cargando' ? 'Cargando…' : 'Refrescar'}
        </button>
      </div>

      {carga.estado === 'error' && <p className="estado-error">Error listando bitacoras: {carga.error}</p>}
      {carga.estado === 'lista' && archivos.length === 0 && (
        <p className="placeholder">No hay archivos en r/bitacoras todavía.</p>
      )}

      {/* Selector 1: bitacora (archivo) */}
      {archivos.length > 0 && (
        <div className="toolbar bitacora-selectores">
          <label className="filtro">
            Bitácora:
            <select
              value={seleccion ?? ''}
              onChange={(e) => elegirArchivo(e.target.value)}
              disabled={cargando}
            >
              {archivos.map((a) => (
                <option key={a.nombre} value={a.nombre}>
                  {iconosPorTipo[a.tipo] ?? '🗎'} {a.nombre}
                </option>
              ))}
            </select>
          </label>

          {/* Selector 2: hoja del xlsx */}
          {archivo?.tipo === 'xlsx' && archivo.hojas.length > 0 && (
            <label className="filtro">
              Hoja:
              <select
                value={hoja ?? ''}
                onChange={(e) => elegirHoja(e.target.value)}
                disabled={cargando}
              >
                {archivo.hojas.map((h) => (
                  <option key={h} value={h}>
                    {h}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
      )}

      {archivo && (
        <p className="archivo-contenido-meta">
          <strong>{iconosPorTipo[archivo.tipo] ?? '🗎'} {archivo.nombre}</strong> ·{' '}
          {(archivo.tamano_bytes / 1024).toFixed(1)} KB · modificado: {archivo.modificado}
          {datos && (
            <>
              {' '}· <strong>{datos.nFilas}</strong> fila(s) · <strong>{datos.nColumnas}</strong> columna(s)
              {datos.hojaUsada && <> · hoja: <strong>{datos.hojaUsada}</strong></>}
            </>
          )}
        </p>
      )}

      {cargando && <p className="placeholder esperando">⏳ Esperando respuesta del servidor…</p>}
      {error && <p className="estado-error">No se pudo leer el contenido: {error}</p>}

      {datos && archivo?.tipo === 'json' && (
        <JSONNodo clave="Contenido JSON" valor={jsonValor?.valor ?? jsonValor ?? {}} />
      )}

      {datos && archivo?.tipo === 'xlsx' && (
        <>
          <div className="paginacion">
            <button
              type="button"
              className="btn btn-mini"
              disabled={cargando || datos.pagina <= 1}
              onClick={() => setPagina(datos.pagina - 1)}
            >
              ◂ Anterior
            </button>
            <span className="paginacion-datos">
              Página <strong>{datos.pagina}</strong> de <strong>{datos.totalPaginas}</strong>
            </span>
            <button
              type="button"
              className="btn btn-mini"
              disabled={cargando || datos.pagina >= datos.totalPaginas}
              onClick={() => setPagina(datos.pagina + 1)}
            >
              Siguiente ▸
            </button>
            <label className="paginacion-size">
              filas:
              <select
                value={datos.tamPagina}
                disabled={cargando}
                onChange={(e) => {
                  setTamPagina(Number(e.target.value));
                  setPagina(1);
                }}
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
                  {datos.columnas.map((col) => (
                    <th key={col}>{col}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {datos.columnas.length > 0 &&
                  datos.filas.map((fila, i) => (
                    <tr key={i}>
                      {datos.columnas.map((col) => {
                        const txt = fila?.[col] == null ? '—' : String(aTexto(fila[col]));
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
          {datos.filas.length === 0 && (
            <p className="placeholder">La hoja está vacía.</p>
          )}
        </>
      )}

      {/* Grafico de dispersion con lineas: filas_despues por registro (solo bitacora limpia) */}
      {archivo?.nombre === 'bitacora_limpia.xlsx' && (
        <div className="bitacora-grafico">
          <h3>Filas después de cada registro (hoja “Bitacora”)</h3>
          {serieCargando && <p className="placeholder esperando">⏳ Cargando serie…</p>}
          {serieError && <p className="estado-error">No se pudo generar el gráfico: {serieError}</p>}
          {serie && serie.length > 0 && (
            <ResponsiveContainer width="100%" height={340}>
              <LineChart data={serie} margin={{ top: 12, right: 24, bottom: 8, left: 12 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#8884" />
                <XAxis
                  dataKey="registro"
                  tick={{ fontSize: 11 }}
                  interval="preserveStartEnd"
                  angle={-45}
                  textAnchor="end"
                  height={60}
                  label={{ value: 'Registro (id_paso)', position: 'insideBottomRight', offset: -4, fontSize: 11 }}
                />
                <YAxis
                  tick={{ fontSize: 11 }}
                  label={{ value: 'Filas después', angle: -90, position: 'insideLeft', fontSize: 11 }}
                />
                <Tooltip
                  formatter={(v) => [v, 'Filas después']}
                  labelFormatter={(l, p) =>
                    `Registro ${l}${p?.[0]?.payload?.tipo ? ` — ${p[0].payload.tipo}` : ''}`
                  }
                />
                <Line
                  type="linear"
                  dataKey="filas"
                  name="Filas después"
                  stroke="#2563eb"
                  strokeWidth={2}
                  dot={{ r: 3, fill: '#2563eb' }}
                  activeDot={{ r: 5 }}
                  connectNulls
                  isAnimationActive={false}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
          {serie && serie.length === 0 && !serieCargando && (
            <p className="placeholder">Sin registros para graficar.</p>
          )}
        </div>
      )}
    </div>
  );
}
