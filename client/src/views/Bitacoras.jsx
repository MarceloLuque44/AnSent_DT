import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { apiGet } from '../api.js';
import TablaCambios from '../components/TablaCambios.jsx';

const PAGE_SIZE = 10;

const texto = (v) => (v == null || v === '' ? '—' : String(v));

const etiquetaSentimiento = (s) =>
  String(s)
    .replace(/_/g, ' ')
    .replace(/^./, (c) => c.toUpperCase());

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;

/** Filtra filas por rango de fechas usando la columna indicada (YYYY-MM o YYYY-MM-DD). */
const filtrarPorFechas = (filas, claveFecha, desde, hasta) => {
  if (!desde && !hasta) return filas;
  const dDesde = desde ? new Date(desde) : null;
  const dHasta = hasta ? new Date(hasta + 'T23:59:59') : null;
  return filas.filter((f) => {
    const v = f[claveFecha];
    if (v == null) return true;
    const d = new Date(String(v).includes('-') && String(v).length >= 7 ? `${String(v)}-01` : String(v));
    if (isNaN(d.getTime())) return true;
    if (dDesde && d < dDesde) return false;
    if (dHasta && d > dHasta) return false;
    return true;
  });
};

/** Extrae las claves dinámicas que viajan dentro de la columna jsonb `datos`. */
const clavesDinamicas = (filas) => {
  const claves = new Set();
  for (const f of filas) {
    if (f && f.datos && typeof f.datos === 'object' && !Array.isArray(f.datos)) {
      Object.keys(f.datos).forEach((k) => claves.add(k));
    }
  }
  return [...claves];
};

/** Panel desplegable (accordion). */
function Panel({ clave, titulo, abierto, alternar, children }) {
  return (
    <section className="panel-grafico" aria-label={clave}>
      <div
        className="panel-cabecera"
        onClick={alternar}
        onKeyDown={(e) => e.key === 'Enter' && alternar()}
        role="button"
        tabIndex={0}
        aria-expanded={abierto}
        aria-controls={clave}
      >
        <h2 className="panel-titulo">{titulo}</h2>
        <span className="panel-indicador">{abierto ? '▼' : '▶'}</span>
      </div>
      {abierto && children}
    </section>
  );
}

/** Tabla paginada (muestra PAGE_SIZE filas por página). */
function TablaPaginada({ filas, cabeceras, filasRenderer, clave, pagina, setPagina }) {
  const total = filas.length;
  const totalPaginas = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const p = Math.min(Math.max(1, pagina), totalPaginas);
  const inicio = (p - 1) * PAGE_SIZE;
  const pageRows = filas.slice(inicio, inicio + PAGE_SIZE);

  return (
    <>
      {total > 0 && (
        <div className="tabla-scroll">
          <table className="tabla">
            <thead>
              <tr>{cabeceras.map((c) => <th key={c}>{c}</th>)}</tr>
            </thead>
            <tbody>
              {pageRows.map((f, i) => filasRenderer(f, i + inicio, clave))}
            </tbody>
          </table>
        </div>
      )}
      {total > PAGE_SIZE && (
        <div className="paginacion">
          <button
            type="button"
            className="btn-pag"
            disabled={p === 1}
            onClick={() => setPagina(p - 1)}
          >
            Anterior
          </button>
          <span className="pagina-actual">Página {p} de {totalPaginas} · {total} registros</span>
          <button
            type="button"
            className="btn-pag"
            disabled={p === totalPaginas}
            onClick={() => setPagina(p + 1)}
          >
            Siguiente
          </button>
        </div>
      )}
      {total === 0 && <p className="placeholder">Sin registros para mostrar.</p>}
    </>
  );
}

/** Columnas de base para cada output (sin id, id_ejecucion ni datos jsonb). */
const BASE_COLUMNAS = {
  'mensajes-limpios': ['id_mensaje', 'fecha', 'anio_mes', 'autor', 'tipo_contenido', 'texto_limpio', 'polaridad_msg', 'sentimiento_dominante'],
  'mensajes-excluidos': ['id_mensaje', 'fecha', 'motivo_exclusion'],
  tokens: ['id_mensaje', 'fecha', 'anio_mes', 'token'],
  stopwords: ['palabra', 'accion', 'justificacion'],
  'emojis-uso': ['emoji', 'en_texto', 'en_reacciones', 'significado_es', 'sentimiento', 'polaridad', 'pendiente'],
  'emojis-pendientes': [],
  resumen: [],
};

/** Etiqueta de panel por output. */
const TITULO_OUTPUT = {
  'mensajes-limpios': 'Mensajes limpios',
  'mensajes-excluidos': 'Mensajes excluidos',
  tokens: 'Tokens',
  stopwords: 'Stopwords aplicadas',
  'emojis-uso': 'Emojis en uso',
  'emojis-pendientes': 'Emojis pendientes',
  resumen: 'Resumen',
};

const ENDPOINTS = ['mensajes-limpios', 'mensajes-excluidos', 'tokens', 'stopwords', 'emojis-uso', 'emojis-pendientes', 'resumen'];

export default function Bitacoras() {
  const [tab, setTab] = useState('cambios');

  // --- Cambios de código/diccionarios ---
  const [cambios, setCambios] = useState([]);
  const [cargandoCambios, setCargandoCambios] = useState(true);
  const [errorCambios, setErrorCambios] = useState(null);
  const [actualizadoCambios, setActualizadoCambios] = useState(null);

  // --- Ejecuciones de preprocesar ---
  const [ejecuciones, setEjecuciones] = useState([]);
  const [totalEjecuciones, setTotalEjecuciones] = useState(0);
  const [paginaEjecuciones, setPaginaEjecuciones] = useState(1);
  const [filtros, setFiltros] = useState({ fechaDesde: '', fechaHasta: '', archivo: '', responsable: '', estado: '' });
  const [cargandoEjecuciones, setCargandoEjecuciones] = useState(true);
  const [errorEjecuciones, setErrorEjecuciones] = useState(null);
  const [actualizadoEjecuciones, setActualizadoEjecuciones] = useState(null);

  // --- Detalle de ejecución ---
  const [detalleId, setDetalleId] = useState(null);
  const [cabecera, setCabecera] = useState(null);
  const [outputs, setOutputs] = useRef({});
  const [detalleCargando, setDetalleCargando] = useState(false);
  const [detalleError, setDetalleError] = useState(null);

  const cargarCambios = useCallback(async () => {
    setCargandoCambios(true);
    setErrorCambios(null);
    try {
      const resp = await apiGet('/api/cambios?limit=100');
      setCambios(resp.data ?? []);
      setActualizadoCambios(new Date());
    } catch (err) {
      setErrorCambios(err.message);
      setCambios([]);
    } finally {
      setCargandoCambios(false);
    }
  }, []);

  const qsEjecuciones = useMemo(() => {
    const qs = new URLSearchParams();
    qs.set('limit', PAGE_SIZE);
    qs.set('offset', (paginaEjecuciones - 1) * PAGE_SIZE);
    if (filtros.fechaDesde) qs.set('fecha_desde', filtros.fechaDesde);
    if (filtros.fechaHasta) qs.set('fecha_hasta', filtros.fechaHasta);
    if (filtros.archivo) qs.set('archivo', filtros.archivo);
    if (filtros.responsable) qs.set('responsable', filtros.responsable);
    if (filtros.estado) qs.set('estado', filtros.estado);
    return qs.toString();
  }, [paginaEjecuciones, filtros]);

  const cargarEjecuciones = useCallback(async () => {
    setCargandoEjecuciones(true);
    setErrorEjecuciones(null);
    try {
      const resp = await apiGet(`/api/preprocesar/ejecuciones?${qsEjecuciones}`);
      setEjecuciones(resp.data ?? []);
      setTotalEjecuciones(resp.total ?? 0);
      setActualizadoEjecuciones(new Date());
    } catch (err) {
      setErrorEjecuciones(err.message);
      setEjecuciones([]);
    } finally {
      setCargandoEjecuciones(false);
    }
  }, [qsEjecuciones]);

  useEffect(() => {
    cargarCambios();
    cargarEjecuciones();
  }, [cargarCambios, cargarEjecuciones]);

  const cargarTodo = useCallback(async () => {
    await Promise.all([cargarCambios(), cargarEjecuciones()]);
  }, [cargarCambios, cargarEjecuciones]);

  const limpiarFiltros = () => {
    setFiltros({ fechaDesde: '', fechaHasta: '', archivo: '', responsable: '', estado: '' });
    setPaginaEjecuciones(1);
  };

  const seleccionarEjecucion = (id) => {
    setDetalleId(id);
    setCabecera(null);
    outputs.current = {};
    setDetalleError(null);
    setDetalleCargando(true);
  };

  const cerrarDetalle = () => {
    setDetalleId(null);
    setCabecera(null);
    outputs.current = {};
    setDetalleError(null);
    setDetalleCargando(false);
  };

  const cargarDetalle = useCallback(async (id) => {
    if (!id) return;
    try {
      const cabResp = await apiGet(`/api/preprocesar/ejecuciones/${id}`);
      setCabecera(cabResp.data ?? null);
      await Promise.all(ENDPOINTS.map((ep) => cargarOutputPage(ep, id, 1)));
    } catch (err) {
      setDetalleError(err.message);
      setCabecera(null);
    } finally {
      setDetalleCargando(false);
    }
  }, []);

  useEffect(() => {
    if (detalleId) cargarDetalle(detalleId);
  }, [detalleId, cargarDetalle]);

  const cargarOutputPage = async (endpoint, idEjecucion, pagina) => {
    setOutputs((prev) => ({
      ...prev,
      [endpoint]: { ...prev[endpoint], cargando: true },
    }));
    try {
      const resp = await apiGet(
        `/api/preprocesar/${endpoint}?ejecucion=${encodeURIComponent(String(idEjecucion))}&limit=${PAGE_SIZE}&offset=${(pagina - 1) * PAGE_SIZE}`,
      );
      const filas = resp.data ?? [];
      setOutputs((prev) => ({
        ...prev,
        [endpoint]: {
          filas,
          total: resp.total ?? 0,
          pagina,
          cargando: false,
          error: null,
          claves: clavesDinamicas(filas),
        },
      }));
    } catch (err) {
      setOutputs((prev) => ({
        ...prev,
        [endpoint]: {
          ...prev[endpoint],
          filas: [],
          cargando: false,
          error: err.message,
          claves: [],
        },
      }));
    }
  };

  const irPaginaOutput = (endpoint, pagina) => {
    if (!detalleId) return;
    setOutputs((prev) => ({
      ...prev,
      [endpoint]: { ...prev[endpoint], pagina, cargando: true },
    }));
    cargarOutputPage(endpoint, detalleId, pagina);
  };

  const filasRendererOutput = (endpoint) => (f, i) => {
    const base = BASE_COLUMNAS[endpoint] ?? [];
    const claves = [...base];
    const datos = f.datos;
    if (endpoint === 'resumen' || endpoint === 'emojis-pendientes') {
      claves.push(...(datos && typeof datos === 'object' && !Array.isArray(datos) ? Object.keys(datos) : []));
    } else {
      const dyn = outputs.current[endpoint]?.claves ?? [];
      dyn.forEach((k) => { if (!claves.includes(k)) claves.push(k); });
    }
    return (
      <tr key={f.id ?? `${endpoint}-${i}`}>
        {claves.map((c) => {
          const v = datos && typeof datos === 'object' && !Array.isArray(datos) && c in datos ? datos[c] : f[c];
          return <td key={c}>{texto(v)}</td>;
        })}
      </tr>
    );
  };

  const cabecerasOutput = (endpoint) => {
    const estado = outputs.current[endpoint];
    const filas = estado ? estado.filas : [];
    const base = BASE_COLUMNAS[endpoint] ?? [];
    const claves = [...base];
    if (endpoint === 'resumen' || endpoint === 'emojis-pendientes') {
      filas.forEach((f) => {
        const d = f.datos;
        if (d && typeof d === 'object' && !Array.isArray(d)) Object.keys(d).forEach((k) => { if (!claves.includes(k)) claves.push(k); });
      });
    } else {
      (estado?.claves ?? []).forEach((k) => { if (!claves.includes(k)) claves.push(k); });
    }
    return claves;
  };

  const renderResumen = () => {
    const estado = outputs.current.resumen;
    const filas = estado ? estado.filas : [];
    if (filas.length === 0) return <p className="placeholder">Sin resumen para esta ejecucion.</p>;
    const d = filas[0].datos;
    if (!d || typeof d !== 'object' || Array.isArray(d)) return <p className="placeholder">Sin datos de resumen.</p>;
    return (
      <div>
        {Object.entries(d).map(([k, v]) => (
          <div key={k} style={{ marginBottom: '0.35rem' }}>
            <span style={{ fontWeight: 600, color: '#5a7392' }}>{k}</span>: {texto(v)}
          </div>
        ))}
      </div>
    );
  };

  const renderPanelOutput = (endpoint) => {
    const estado = outputs.current[endpoint];
    const filas = estado ? estado.filas : [];
    const total = estado ? estado.total : 0;
    const pagina = estado ? estado.pagina : 1;
    const cabeceras = cabecerasOutput(endpoint);

    if (endpoint === 'resumen') {
      return (
        <>
          {detalleError && <div className="estado-error">{detalleError}</div>}
          {renderResumen()}
        </>
      );
    }

    return (
      <>
        {estado?.error && <div className="estado-error">{estado.error}</div>}
        {!estado?.error && filas.length === 0 && <p className="placeholder">Sin registros para mostrar.</p>}
        {!estado?.error && filas.length > 0 && (
          <TablaPaginada
            filas={filas}
            cabeceras={cabeceras}
            filasRenderer={filasRendererOutput(endpoint)}
            clave={endpoint}
            pagina={pagina}
            setPagina={(p) => irPaginaOutput(endpoint, p)}
          />
        )}
      </>
    );
  };

  const renderCambios = () => (
    <>
      {errorCambios && <div className="estado-error">{errorCambios}</div>}
      {actualizadoCambios && !errorCambios && (
        <p className="page-desc">
          Última actualización: {actualizadoCambios.toLocaleString()}
        </p>
      )}
      {!errorCambios && !cargandoCambios && cambios.length === 0 && (
        <p className="placeholder">No hay cambios registrados todavía.</p>
      )}
      {!errorCambios && !cargandoCambios && cambios.length > 0 && <TablaCambios filas={cambios} />}
    </>
  );

  const cabecerasEjecuciones = [
    'Fecha', 'Hora inicio', 'Archivo', 'Responsable', 'Registros leídos', 'Mensajes limpios', 'Mensajes excluidos', 'Estado', 'Paso donde paró',
  ];

  const renderEjecuciones = () => {
    const filasFiltradas = filtrarPorFechas(ejecuciones, 'fecha', filtros.fechaDesde, filtros.fechaHasta);
    const totalPaginas = Math.max(1, Math.ceil(filasFiltradas.length / PAGE_SIZE));
    const p = Math.min(Math.max(1, paginaEjecuciones), totalPaginas);
    const inicio = (p - 1) * PAGE_SIZE;
    const pageRows = filasFiltradas.slice(inicio, inicio + PAGE_SIZE);

    return (
      <>
        <div className="filtros-fechas">
          <label>
            Desde
            <input
              type="date"
              value={filtros.fechaDesde}
              onChange={(e) => { setFiltros((prev) => ({ ...prev, fechaDesde: e.target.value })); setPaginaEjecuciones(1); }}
            />
          </label>
          <label>
            Hasta
            <input
              type="date"
              value={filtros.fechaHasta}
              onChange={(e) => { setFiltros((prev) => ({ ...prev, fechaHasta: e.target.value })); setPaginaEjecuciones(1); }}
            />
          </label>
          <label style={{ minWidth: '180px' }}>
            Archivo
            <input
              type="text"
              value={filtros.archivo}
              onChange={(e) => { setFiltros((prev) => ({ ...prev, archivo: e.target.value })); setPaginaEjecuciones(1); }}
              placeholder="filtrar por archivo"
            />
          </label>
          <label style={{ minWidth: '160px' }}>
            Responsable
            <input
              type="text"
              value={filtros.responsable}
              onChange={(e) => { setFiltros((prev) => ({ ...prev, responsable: e.target.value })); setPaginaEjecuciones(1); }}
              placeholder="filtrar por responsable"
            />
          </label>
          <label>
            Estado
            <select
              value={filtros.estado}
              onChange={(e) => { setFiltros((prev) => ({ ...prev, estado: e.target.value })); setPaginaEjecuciones(1); }}
            >
              <option value="">Todos</option>
              <option value="ok">ok</option>
              <option value="detenido_emojis_pendientes">detenido_emojis_pendientes</option>
              <option value="error">error</option>
            </select>
          </label>
          <button type="button" className="btn" onClick={limpiarFiltros}>
            Limpiar filtros
          </button>
        </div>

        {errorEjecuciones && <div className="estado-error">{errorEjecuciones}</div>}
        {!errorEjecuciones && !cargandoEjecuciones && ejecuciones.length === 0 && (
          <p className="placeholder">No hay ejecuciones de preprocesar registradas todavía.</p>
        )}
        {!errorEjecuciones && !cargandoEjecuciones && ejecuciones.length > 0 && (
          <div className="tabla-scroll">
            <table className="tabla">
              <thead>
                <tr>{cabecerasEjecuciones.map((c) => <th key={c}>{c}</th>)}</tr>
              </thead>
              <tbody>
                {pageRows.map((e) => (
                  <tr
                    key={e.id_ejecucion}
                    style={{ cursor: 'pointer' }}
                    onClick={() => seleccionarEjecucion(e.id_ejecucion)}
                  >
                    <td>{texto(e.fecha)}</td>
                    <td>{texto(e.hora_inicio)}</td>
                    <td title={texto(e.archivo)}>{texto(e.archivo)}</td>
                    <td>{texto(e.responsable)}</td>
                    <td>{texto(e.registros_leidos)}</td>
                    <td>{texto(e.mensajes_limpios)}</td>
                    <td>{texto(e.mensajes_excluidos)}</td>
                    <td>
                      <span className={`tag ${e.estado === 'ok' ? 'tag-limpieza' : 'tag-tipo-desconocido'}`}>{texto(e.estado)}</span>
                    </td>
                    <td title={texto(e.paso_donde_paro)}>{texto(e.paso_donde_paro)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!errorEjecuciones && !cargandoEjecuciones && ejecuciones.length > 0 && filasFiltradas.length > PAGE_SIZE && (
          <div className="paginacion">
            <button
              type="button"
              className="btn-pag"
              disabled={p === 1}
              onClick={() => setPaginaEjecuciones(p - 1)}
            >
              Anterior
            </button>
            <span className="pagina-actual">Página {p} de {totalPaginas} · {ejecuciones.length} registros</span>
            <button
              type="button"
              className="btn-pag"
              disabled={p === totalPaginas}
              onClick={() => setPaginaEjecuciones(p + 1)}
            >
              Siguiente
            </button>
          </div>
        )}
      </>
    );
  };

  const renderDetalle = () => {
    if (!detalleId) return null;
    return (
      <div style={{ marginTop: '2rem', borderTop: '1px solid var(--panel-borde)', paddingTop: '1.2rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.8rem' }}>
          <button type="button" className="btn" onClick={cerrarDetalle} style={{ padding: '0.35rem 0.9rem', fontSize: '0.85rem' }}>
            ← Volver al listado
          </button>
          <h2 style={{ margin: 0, fontSize: '1.25rem', color: '#12263f' }}>Detalle de ejecución #{texto(detalleId)}</h2>
        </div>
        {detalleError && <div className="estado-error">{detalleError}</div>}
        {detalleCargando && !cabecera && <p className="placeholder">Cargando detalle…</p>}
        {cabecera && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0.7rem', marginBottom: '1rem' }}>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Estado</div>
                <div>{texto(cabecera.estado)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Archivo</div>
                <div>{texto(cabecera.archivo)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Responsable</div>
                <div>{texto(cabecera.responsable)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Registros leídos</div>
                <div>{texto(cabecera.registros_leidos)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Limpios / Excluidos</div>
                <div>{texto(cabecera.mensajes_limpios)} / {texto(cabecera.mensajes_excluidos)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.78rem', color: '#5a7392', fontWeight: 600, marginBottom: '0.15rem' }}>Rango de fechas</div>
                <div>{texto(cabecera.rango_fechas_inicio)} → {texto(cabecera.rango_fechas_fin)}</div>
              </div>
            </div>
            {cabecera.mensaje_error && (
              <div className="estado-error" style={{ marginBottom: '0.9rem' }}>
                <div style={{ fontWeight: 600, marginBottom: '0.25rem' }}>Error</div>
                {texto(cabecera.mensaje_error)}
              </div>
            )}
            {cabecera.paso_donde_paro && (
              <div style={{ marginBottom: '0.9rem', fontSize: '0.85rem', color: '#5a7392' }}>
                <span style={{ fontWeight: 600 }}>Paso donde paró:</span> {texto(cabecera.paso_donde_paro)}
              </div>
            )}
          </>
        )}
        <h3 style={{ margin: '1.2rem 0 0.5rem', fontSize: '1rem', color: '#12263f' }}>Outputs</h3>
        {ENDPOINTS.map((endpoint) => (
          <Panel
            key={endpoint}
            clave={`detalle-${endpoint}`}
            titulo={TITULO_OUTPUT[endpoint]}
            abierto={true}
            alternar={() => {}}
          >
            {renderPanelOutput(endpoint)}
          </Panel>
        ))}
      </div>
    );
  };

  const estaCargando = cargandoCambios || cargandoEjecuciones;

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Bitácora</h1>
          <p className="page-desc">
            Historial de ejecuciones y cambios registrados en la base de datos.
          </p>
        </div>
        <button type="button" className="btn" onClick={cargarTodo} disabled={estaCargando || detalleId}>
          {estaCargando ? 'Actualizando…' : 'Actualizar'}
        </button>
      </header>

      {(errorCambios || errorEjecuciones) && (
        <div className="estado-error">
          {errorCambios && <div>Cambios: {errorCambios}</div>}
          {errorEjecuciones && <div>Ejecuciones: {errorEjecuciones}</div>}
        </div>
      )}

      {!detalleId && (
        <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', flexWrap: 'wrap' }}>
          {['cambios', 'ejecuciones'].map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              style={{
                padding: '0.45rem 1rem',
                border: '1px solid var(--panel-borde)',
                borderRadius: '8px',
                background: tab === t ? 'var(--azul-suave)' : 'var(--panel)',
                color: tab === t ? '#1746b0' : '#5a7392',
                fontWeight: 600,
                fontSize: '0.88rem',
                cursor: 'pointer',
                borderBottom: tab === t ? '2px solid var(--azul)' : 'none',
              }}
            >
              {t === 'cambios' ? 'Cambios de código/diccionarios' : 'Ejecuciones de preprocesar'}
            </button>
          ))}
        </div>
      )}

      {detalleId && renderDetalle()}

      {!detalleId && tab === 'cambios' && renderCambios()}

      {!detalleId && tab === 'ejecuciones' && renderEjecuciones()}
    </div>
  );
}
