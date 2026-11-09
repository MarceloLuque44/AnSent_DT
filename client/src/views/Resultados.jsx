import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiGet } from '../api.js';

const etiquetaSentimiento = (s) =>
  String(s)
    .replace(/_/g, ' ')
    .replace(/^./, (c) => c.toUpperCase());

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;
const texto = (v) => (v == null || v === '' ? '—' : String(v));

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

  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);
  const [errorNiveles, setErrorNiveles] = useState(null);
  const [errorSerie, setErrorSerie] = useState(null);
  const [errorComp, setErrorComp] = useState(null);

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

      {/* Niveles de sentimientos por periodo */}
      <section className="panel-grafico" aria-label="Nivel de sentimientos por periodo">
        <div className="panel-grafico-cabecera">
          <h2 className="panel-grafico-titulo">
            Nivel de sentimientos ({texto(periodoInfo?.nombre) || 'último análisis'})
          </h2>
          {periodoInfo && (
            <span className="page-desc">
              {periodoInfo.inicio} → {periodoInfo.fin} · {texto(periodoInfo.n_mensajes)} mensajes
            </span>
          )}
        </div>
        {errorNiveles && <div className="estado-error">No se pudieron cargar los niveles: {errorNiveles}</div>}
        {!errorNiveles && datosNiveles.length === 0 && (
          <p className="placeholder">Sin niveles de sentimientos para este periodo.</p>
        )}
        {datosNiveles.length > 0 && (
          <div className="tabla-scroll">
            <table className="tabla">
              <thead>
                <tr>
                  <th>Sentimiento</th>
                  <th>Nivel</th>
                  <th>Mensajes con el sentimiento</th>
                  <th>n mensajes</th>
                </tr>
              </thead>
              <tbody>
                {datosNiveles.map((f) => (
                  <tr key={`${f.sentimiento}||${periodoActivo}`}>
                    <td>{etiquetaSentimiento(f.sentimiento)}</td>
                    <td>{formatearPct(f.nivel_pct)}</td>
                    <td>{formatearPct(f.mensajes_pct)}</td>
                    <td>{texto(f.n_mensajes)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* Serie mensual de sentimientos */}
      <section className="panel-grafico" aria-label="Serie mensual de sentimientos">
        <div className="panel-grafico-cabecera">
          <h2 className="panel-grafico-titulo">Serie mensual de sentimientos</h2>
        </div>
        {errorSerie && <div className="estado-error">No se pudo cargar la serie: {errorSerie}</div>}
        {!errorSerie && datosSerie.length === 0 && (
          <p className="placeholder">Sin serie mensual para este periodo.</p>
        )}
        {datosSerie.length > 0 && (
          <div className="tabla-scroll">
            <table className="tabla">
              <thead>
                <tr>
                  <th>Mes</th>
                  <th>Sentimiento</th>
                  <th>%</th>
                  <th>n mensajes</th>
                </tr>
              </thead>
              <tbody>
                {datosSerie.map((f) => (
                  <tr key={`${f.anio_mes}||${f.sentimiento}`}>
                    <td>{texto(f.anio_mes)}</td>
                    <td>{etiquetaSentimiento(f.sentimiento)}</td>
                    <td>{formatearPct(f.pct)}</td>
                    <td>{texto(f.n_mensajes)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* Comparación de periodos */}
      <section className="panel-grafico bloque-comparacion" aria-label="Comparación de periodos">
        <div className="panel-grafico-cabecera">
          <h2 className="panel-grafico-titulo">Comparación de periodos</h2>
          {comparaciones.length > 0 && (
            <label className="selector-periodo">
              <span>Comparación</span>
              <select
                value={comparacionActiva}
                onChange={(e) => setComparacionActiva(e.target.value)}
              >
                {comparaciones.map((c) => (
                  <option key={c.id_comparacion} value={String(c.id_comparacion)}>
                    {c.nombre}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        {errorComp && comparacionActiva && (
          <div className="estado-error">No se pudo cargar la comparación: {errorComp}</div>
        )}
        {!errorComp && comparaciones.length === 0 && (
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
            <div className="tabla-scroll">
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Sentimiento</th>
                    <th>{filasComparacion.periodos[0]?.nombre || 'A'}</th>
                    <th>{filasComparacion.periodos[1]?.nombre || 'B'}</th>
                    <th>Diferencia (B - A)</th>
                  </tr>
                </thead>
                <tbody>
                  {filasComparacion.filas.map((f) => (
                    <tr key={f.sentimiento}>
                      <td>{etiquetaSentimiento(f.sentimiento)}</td>
                      <td>{f.a != null ? formatearPct(f.a) : '—'}</td>
                      <td>{f.b != null ? formatearPct(f.b) : '—'}</td>
                      <td>
                        {f.a != null && f.b != null ? (f.b - f.a).toFixed(1) : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>
    </div>
  );
}
