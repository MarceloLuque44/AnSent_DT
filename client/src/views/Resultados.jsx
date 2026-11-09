import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiGet } from '../api.js';

const PAGE_SIZE = 10;

const etiquetaSentimiento = (s) =>
  String(s)
    .replace(/_/g, ' ')
    .replace(/^./, (c) => c.toUpperCase());

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;
const texto = (v) => (v == null || v === '' ? '—' : String(v));

/**
 * Filtra filas por rango de fechas usando la columna indicada (YYYY-MM o YYYY-MM-DD).
 */
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

/**
 * Resultados análisis: lee de Postgres lo que guardar_analisis() envió desde R.
 * Sin polling ni SSE: carga inicial + botón "Actualizar".
 * Consume:
 *   GET /api/dashboard/periodos
 *   GET /api/dashboard/niveles?periodo=<nombre>
 *   GET /api/dashboard/serie?periodo=<nombre>
 *   GET /api/dashboard/comparaciones
 *   GET /api/dashboard/comparaciones/:id
 */
export default function Resultados() {
  const [periodos, setPeriodos] = useState([]);
  const [periodoActivo, setPeriodoActivo] = useState('');
  const [periodoInfo, setPeriodoInfo] = useState(null);
  const [datosNiveles, setDatosNiveles] = useState([]);
  const [datosSerie, setDatosSerie] = useState([]);
  const [comparaciones, setComparaciones] = useState([]);
  const [comparacionActiva, setComparacionActiva] = useState('');
  const [detalleComp, setDetalleComp] = useState(null);

  const [abiertos, setAbiertos] = useState(new Set(['niveles']));
  const [paginaNiveles, setPaginaNiveles] = useState(1);
  const [paginaSerie, setPaginaSerie] = useState(1);
  const [paginaComp, setPaginaComp] = useState(1);

  const [fechaDesde, setFechaDesde] = useState('');
  const [fechaHasta, setFechaHasta] = useState('');

  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);
  const [errorNiveles, setErrorNiveles] = useState(null);
  const [errorSerie, setErrorSerie] = useState(null);
  const [errorComp, setErrorComp] = useState(null);

  const alternarPanel = (clave) => {
    setAbiertos((prev) => {
      const next = new Set(prev);
      if (next.has(clave)) next.delete(clave);
      else next.add(clave);
      return next;
    });
  };

  const cargarPeriodos = useCallback(async () => {
    try {
      const resp = await apiGet('/api/dashboard/periodos');
      const lista = resp.periodos ?? [];
      setPeriodos(lista);
      if (!periodoActivo && lista.length) {
        setPeriodoActivo(lista[0].nombre);
      }
    } catch {
      setPeriodos([]);
    }
  }, [periodoActivo]);

  const cargarNiveles = useCallback(async (nombre) => {
    setErrorNiveles(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/niveles?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/niveles';
      const resp = await apiGet(ruta);
      setPeriodoInfo(resp.periodo ?? null);
      setDatosNiveles(resp.datos ?? []);
    } catch (err) {
      setErrorNiveles(err.message);
      setPeriodoInfo(null);
      setDatosNiveles([]);
    }
  }, []);

  const cargarSerie = useCallback(async (nombre) => {
    setErrorSerie(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/serie?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/serie';
      const resp = await apiGet(ruta);
      setDatosSerie(resp.datos ?? []);
    } catch (err) {
      setErrorSerie(err.message);
      setDatosSerie([]);
    }
  }, []);

  const cargarComparaciones = useCallback(async () => {
    setErrorComp(null);
    try {
      const resp = await apiGet('/api/dashboard/comparaciones');
      const lista = resp.comparaciones ?? [];
      setComparaciones(lista);
      if (!comparacionActiva && lista.length) {
        setComparacionActiva(String(lista[0].id_comparacion));
      }
    } catch (err) {
      setErrorComp(err.message);
      setComparaciones([]);
    }
  }, [comparacionActiva]);

  const cargarDetalleComp = useCallback(async (id) => {
    if (!id) {
      setDetalleComp(null);
      return;
    }
    try {
      const resp = await apiGet(`/api/dashboard/comparaciones/${id}`);
      setDetalleComp(resp);
    } catch (err) {
      setErrorComp(err.message);
      setDetalleComp(null);
    }
  }, []);

  useEffect(() => {
    cargarPeriodos();
    cargarComparaciones();
  }, [cargarPeriodos, cargarComparaciones]);

  useEffect(() => {
    cargarNiveles(periodoActivo);
    cargarSerie(periodoActivo);
  }, [cargarNiveles, cargarSerie, periodoActivo]);

  useEffect(() => {
    cargarDetalleComp(comparacionActiva);
  }, [cargarDetalleComp, comparacionActiva]);

  const filasComparacion = useMemo(() => {
    if (!detalleComp) return null;
    const { periodos: periodosCmp = [], datos: datosCmp = [] } = detalleComp;
    const sentimientos = [...new Set(datosCmp.map((d) => d.sentimiento))];
    const indice = new Map(datosCmp.map((d) => [`${d.sentimiento}||${d.periodo}`, d]));
    return {
      periodos: periodosCmp,
      filas: sentimientos.map((s) => {
        const fa = indice.get(`${s}||${periodosCmp[0]?.nombre}`);
        const fb = indice.get(`${s}||${periodosCmp[1]?.nombre}`);
        return {
          sentimiento: s,
          a: fa != null ? Number(fa.nivel_pct) : null,
          b: fb != null ? Number(fb.nivel_pct) : null,
        };
      }),
    };
  }, [detalleComp]);

  const nivelesFiltrados = datosNiveles;

  const serieFiltrada = useMemo(
    () => filtrarPorFechas(datosSerie, 'anio_mes', fechaDesde, fechaHasta),
    [datosSerie, fechaDesde, fechaHasta]
  );

  const comparacionesFiltradas = useMemo(
    () => filtrarPorFechas(comparaciones, 'creado_en', fechaDesde, fechaHasta),
    [comparaciones, fechaDesde, fechaHasta]
  );

  const cargarTodo = useCallback(async () => {
    setCargando(true);
    setError(null);
    try {
      await Promise.all([cargarPeriodos(), cargarComparaciones()]);
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }, [cargarPeriodos, cargarComparaciones]);

  const hayDatos = datosNiveles.length > 0 || datosSerie.length > 0 || comparaciones.length > 0;

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Resultados análisis</h1>
          <p className="page-desc">
            Niveles de sentimientos y serie mensual leídos de Postgres.
          </p>
        </div>
        <button type="button" className="btn" onClick={cargarTodo} disabled={cargando}>
          {cargando ? 'Actualizando…' : 'Actualizar'}
        </button>
      </header>

      {error && <div className="estado-error">No se pudieron cargar los resultados: {error}</div>}

      {!cargando && !error && periodos.length === 0 && comparaciones.length === 0 && (
        <p className="placeholder">
          No hay resultados guardados todavía. Ejecuta{' '}
          <code>guardar_analisis(a)</code> desde R con{' '}
          <code>ANSENT_API_URL</code> y <code>ANSENT_API_KEY</code> definidos.
        </p>
      )}

      {periodos.length > 1 && (
        <label className="selector-periodo">
          <span>Periodo</span>
          <select
            value={periodoActivo}
            onChange={(e) => setPeriodoActivo(e.target.value)}
          >
            <option value="">Último análisis</option>
            {periodos.map((p) => (
              <option key={p.nombre} value={p.nombre}>
                {p.nombre}
              </option>
            ))}
          </select>
        </label>
      )}

      <div className="filtros-fechas">
        <label>
          Desde
          <input
            type="date"
            value={fechaDesde}
            onChange={(e) => setFechaDesde(e.target.value)}
          />
        </label>
        <label>
          Hasta
          <input
            type="date"
            value={fechaHasta}
            onChange={(e) => setFechaHasta(e.target.value)}
          />
        </label>
        <button type="button" className="btn" onClick={() => { setFechaDesde(''); setFechaHasta(''); }}>
          Limpiar filtros
        </button>
      </div>

      {/* Niveles de sentimientos por periodo */}
      <Panel
        clave="niveles"
        titulo={`Nivel de sentimientos (${texto(periodoInfo?.nombre) || 'último análisis'})`}
        abierto={abiertos.has('niveles')}
        alternar={() => alternarPanel('niveles')}
      >
        {periodoInfo && (
          <p className="page-desc">
            {periodoInfo.inicio} → {periodoInfo.fin} · {texto(periodoInfo.n_mensajes)} mensajes
          </p>
        )}
        {errorNiveles && <div className="estado-error">No se pudieron cargar los niveles: {errorNiveles}</div>}
        {!errorNiveles && nivelesFiltrados.length === 0 && (
          <p className="placeholder">Sin niveles de sentimientos para este periodo.</p>
        )}
        {!errorNiveles && nivelesFiltrados.length > 0 && (
          <TablaPaginada
            filas={nivelesFiltrados}
            cabeceras={['Sentimiento', 'Nivel', 'Mensajes con el sentimiento', 'n mensajes']}
            filasRenderer={(f) => (
              <tr key={`${f.sentimiento}||${periodoActivo}`}>
                <td>{etiquetaSentimiento(f.sentimiento)}</td>
                <td>{formatearPct(f.nivel_pct)}</td>
                <td>{formatearPct(f.mensajes_pct)}</td>
                <td>{texto(f.n_mensajes)}</td>
              </tr>
            )}
            clave="niveles"
            pagina={paginaNiveles}
            setPagina={setPaginaNiveles}
          />
        )}
      </Panel>

      {/* Serie mensual de sentimientos */}
      <Panel
        clave="serie"
        titulo="Serie mensual de sentimientos"
        abierto={abiertos.has('serie')}
        alternar={() => alternarPanel('serie')}
      >
        {errorSerie && <div className="estado-error">No se pudo cargar la serie: {errorSerie}</div>}
        {!errorSerie && serieFiltrada.length === 0 && (
          <p className="placeholder">Sin serie mensual para este periodo.</p>
        )}
        {!errorSerie && serieFiltrada.length > 0 && (
          <TablaPaginada
            filas={serieFiltrada}
            cabeceras={['Mes', 'Sentimiento', '%', 'n mensajes']}
            filasRenderer={(f) => (
              <tr key={`${f.anio_mes}||${f.sentimiento}`}>
                <td>{texto(f.anio_mes)}</td>
                <td>{etiquetaSentimiento(f.sentimiento)}</td>
                <td>{formatearPct(f.pct)}</td>
                <td>{texto(f.n_mensajes)}</td>
              </tr>
            )}
            clave="serie"
            pagina={paginaSerie}
            setPagina={setPaginaSerie}
          />
        )}
      </Panel>

      {/* Comparación de periodos */}
      <Panel
        clave="comparacion"
        titulo="Comparación de periodos"
        abierto={abiertos.has('comparacion')}
        alternar={() => alternarPanel('comparacion')}
      >
        {comparacionesFiltradas.length > 0 && (
          <label className="selector-periodo">
            <span>Comparación</span>
            <select
              value={comparacionActiva}
              onChange={(e) => setComparacionActiva(e.target.value)}
            >
              {comparacionesFiltradas.map((c) => (
                <option key={c.id_comparacion} value={String(c.id_comparacion)}>
                  {c.nombre}
                </option>
              ))}
            </select>
          </label>
        )}
        {errorComp && comparacionActiva && (
          <div className="estado-error">No se pudo cargar la comparación: {errorComp}</div>
        )}
        {!errorComp && comparacionesFiltradas.length === 0 && (
          <p className="placeholder">
            Ejecuta <code>enviar_comparacion_api(cmp)</code> desde R para comparar
            dos periodos.
          </p>
        )}
        {!errorComp && detalleComp && filasComparacion && (
          <>
            <p className="page-desc">
              {detalleComp.comparacion.nombre} · {texto(detalleComp.creado_en)}
            </p>
            <TablaPaginada
              filas={filasComparacion.filas}
              cabeceras={[
                'Sentimiento',
                filasComparacion.periodos[0]?.nombre || 'A',
                filasComparacion.periodos[1]?.nombre || 'B',
                'Diferencia (B - A)',
              ]}
              filasRenderer={(f) => (
                <tr key={f.sentimiento}>
                  <td>{etiquetaSentimiento(f.sentimiento)}</td>
                  <td>{f.a != null ? formatearPct(f.a) : '—'}</td>
                  <td>{f.b != null ? formatearPct(f.b) : '—'}</td>
                  <td>
                    {f.a != null && f.b != null ? (f.b - f.a).toFixed(1) : '—'}
                  </td>
                </tr>
              )}
              clave="comparacion"
              pagina={paginaComp}
              setPagina={setPaginaComp}
            />
          </>
        )}
      </Panel>
    </div>
  );
}
