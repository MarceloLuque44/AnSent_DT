import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiGet } from '../api.js';
import EChart from '../components/EChart.jsx';

const AZUL_BARRAS = '#2E75B6';
const AZUL_BARRAS_B = '#8FC3F0';

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;

/**
 * Dashboard: gráficos del análisis calculado en R.
 *  - Niveles de un periodo: GET /api/dashboard/niveles
 *  - Comparación A vs B:    GET /api/dashboard/comparaciones/:id
 * Todos los gráficos se dibujan con ECharts.
 */
export default function Dashboard() {
  const [periodos, setPeriodos] = useState([]);
  const [periodoActivo, setPeriodoActivo] = useState('');
  const [datos, setDatos] = useState([]);
  const [periodo, setPeriodo] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);

  const [comparaciones, setComparaciones] = useState([]);
  const [comparacionActiva, setComparacionActiva] = useState('');
  const [detalleComp, setDetalleComp] = useState(null);
  const [cargandoComp, setCargandoComp] = useState(false);
  const [errorComp, setErrorComp] = useState(null);

  const cargarPeriodos = useCallback(async () => {
    try {
      const resp = await apiGet('/api/dashboard/periodos');
      setPeriodos(resp.periodos ?? []);
    } catch {
      // El selector es opcional: si falla, seguimos con el último periodo.
      setPeriodos([]);
    }
  }, []);

  const cargarNiveles = useCallback(async (nombre) => {
    setCargando(true);
    setError(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/niveles?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/niveles';
      const resp = await apiGet(ruta);
      setDatos(resp.datos ?? []);
      setPeriodo(resp.periodo ?? null);
    } catch (err) {
      setError(err.message);
      setDatos([]);
      setPeriodo(null);
    } finally {
      setCargando(false);
    }
  }, []);

  const cargarComparaciones = useCallback(async () => {
    try {
      const resp = await apiGet('/api/dashboard/comparaciones');
      const lista = resp.comparaciones ?? [];
      setComparaciones(lista);
      setComparacionActiva((actual) => {
        if (actual) return actual;
        return lista.length ? String(lista[0].id_comparacion) : '';
      });
    } catch {
      setComparaciones([]);
    }
  }, []);

  const cargarDetalleComp = useCallback(async (id) => {
    if (!id) {
      setDetalleComp(null);
      return;
    }
    setCargandoComp(true);
    setErrorComp(null);
    try {
      const resp = await apiGet(`/api/dashboard/comparaciones/${id}`);
      setDetalleComp(resp);
    } catch (err) {
      setErrorComp(err.message);
      setDetalleComp(null);
    } finally {
      setCargandoComp(false);
    }
  }, []);

  useEffect(() => {
    cargarPeriodos();
    cargarComparaciones();
  }, [cargarPeriodos, cargarComparaciones]);

  useEffect(() => {
    cargarNiveles(periodoActivo);
  }, [cargarNiveles, periodoActivo]);

  useEffect(() => {
    cargarDetalleComp(comparacionActiva);
  }, [cargarDetalleComp, comparacionActiva]);

  const opcion = useMemo(() => {
    const sentimientos = datos.map((d) => d.sentimiento);
    const valores = datos.map((d) => Number(d.nivel_pct));

    return {
      backgroundColor: 'transparent',
      title: {
        text: 'Nivel de cada sentimiento',
        subtext: periodo?.nombre ? `Periodo: ${periodo.nombre}` : undefined,
        left: 0,
        top: 0,
        textStyle: {
          color: '#12263f',
          fontFamily: 'Archivo, Public Sans, sans-serif',
          fontSize: 16,
          fontWeight: 600,
        },
        subtextStyle: { color: '#5a7392', fontSize: 12 },
      },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        formatter: (params) => {
          const p = params[0];
          const fila = datos.find((d) => d.sentimiento === p.name) ?? {};
          return [
            `<b>${p.name}</b>`,
            `Nivel: ${formatearPct(p.value)}`,
            fila.mensajes_pct != null
              ? `Mensajes con el sentimiento: ${formatearPct(fila.mensajes_pct)}`
              : '',
            fila.n_mensajes != null ? `n = ${fila.n_mensajes}` : '',
          ]
            .filter(Boolean)
            .join('<br/>');
        },
      },
      grid: { left: 130, right: 70, top: 72, bottom: 34 },
      xAxis: {
        type: 'value',
        name: '% (promedio por mensaje)',
        nameTextStyle: { color: '#5a7392', fontSize: 11 },
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        inverse: true,
        data: sentimientos,
        axisTick: { show: false },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        axisLabel: { color: '#12263f' },
      },
      series: [
        {
          name: 'Nivel',
          type: 'bar',
          data: valores,
          barMaxWidth: 22,
          itemStyle: { color: AZUL_BARRAS, borderRadius: [0, 4, 4, 0] },
          label: {
            show: true,
            position: 'right',
            formatter: ({ value }) => formatearPct(value),
            color: '#12263f',
            fontWeight: 600,
          },
        },
      ],
    };
  }, [datos, periodo]);

  const { opcionComparacion, sentimientosComp } = useMemo(() => {
    if (!detalleComp) return { opcionComparacion: null, sentimientosComp: [] };

    const { periodos: periodosCmp = [], datos: datosCmp = [] } = detalleComp;
    const indice = new Map(
      datosCmp.map((d) => [`${d.sentimiento}||${d.periodo}`, d])
    );

    // Orden del primer periodo (el mismo que usa ggplot).
    const primero = periodosCmp[0]?.nombre;
    const ordenA = new Map(
      datosCmp
        .filter((d) => d.periodo === primero)
        .map((d) => [d.sentimiento, d.orden ?? 999])
    );
    const sentimientos = [...new Set(datosCmp.map((d) => d.sentimiento))].sort(
      (a, b) => (ordenA.get(a) ?? 999) - (ordenA.get(b) ?? 999)
    );

    const colores = [AZUL_BARRAS, AZUL_BARRAS_B];

    const series = periodosCmp.map((p, i) => ({
      name: p.nombre,
      type: 'bar',
      data: sentimientos.map((s) => {
        const fila = indice.get(`${s}||${p.nombre}`);
        return fila ? Number(fila.nivel_pct) : null;
      }),
      barMaxWidth: 18,
      barGap: '10%',
      itemStyle: {
        color: colores[i % colores.length],
        borderRadius: [0, 4, 4, 0],
      },
      label: {
        show: true,
        position: 'right',
        formatter: ({ value }) => (value == null ? '' : formatearPct(value)),
        color: '#12263f',
        fontSize: 10,
      },
    }));

    const opcionCmp = {
      backgroundColor: 'transparent',
      title: {
        text: 'Comparación de periodos',
        subtext: detalleComp.comparacion?.nombre,
        left: 0,
        top: 0,
        textStyle: {
          color: '#12263f',
          fontFamily: 'Archivo, Public Sans, sans-serif',
          fontSize: 16,
          fontWeight: 600,
        },
        subtextStyle: { color: '#5a7392', fontSize: 12 },
      },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        formatter: (params) => {
          const lineas = params.map((p) => {
            const fila = indice.get(`${p.name}||${p.seriesName}`);
            const extra =
              fila?.mensajes_pct != null
                ? ` · mensajes ${formatearPct(fila.mensajes_pct)}`
                : '';
            return `${p.marker} ${p.seriesName}: ${formatearPct(p.value)}${extra}`;
          });
          return [`<b>${params[0]?.name ?? ''}</b>`, ...lineas].join('<br/>');
        },
      },
      legend: {
        bottom: 0,
        data: periodosCmp.map((p) => p.nombre),
        textStyle: { color: '#5a7392' },
      },
      grid: { left: 130, right: 80, top: 72, bottom: 78 },
      xAxis: {
        type: 'value',
        name: '% (promedio por mensaje)',
        nameTextStyle: { color: '#5a7392', fontSize: 11 },
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        inverse: true,
        data: sentimientos,
        axisTick: { show: false },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        axisLabel: { color: '#12263f' },
      },
      series,
    };

    return { opcionComparacion: opcionCmp, sentimientosComp: sentimientos };
  }, [detalleComp]);

  const hayDatos = datos.length > 0;

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Dashboard</h1>
          <p className="page-desc">
            Niveles de sentimiento calculados en R y guardados en Postgres.
            {periodo && ` Periodo ${periodo.nombre} (${periodo.inicio} → ${periodo.fin}).`}
          </p>
        </div>

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
      </header>

      {error && <div className="estado-error">No se pudo cargar el dashboard: {error}</div>}

      {cargando && <p className="placeholder">Cargando datos…</p>}

      {!cargando && !error && !hayDatos && (
        <div className="lienzo-vacio">
          <p className="lienzo-vacio-titulo">Sin datos todavía</p>
          <p className="lienzo-vacio-texto">
            Ejecuta <code>enviar_niveles_api(a)</code> desde R para subir los
            niveles del periodo y dibujar el gráfico.
          </p>
        </div>
      )}

      {!cargando && !error && hayDatos && (
        <section className="panel-grafico" aria-label="Nivel por sentimiento">
          <EChart
            option={opcion}
            height={Math.max(380, datos.length * 32 + 110)}
          />
        </section>
      )}

      <section className="panel-grafico bloque-comparacion" aria-label="Comparación de periodos">
        <div className="panel-grafico-cabecera">
          <h2 className="panel-grafico-titulo">Periodo A vs periodo B</h2>

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

        {errorComp && (
          <div className="estado-error">
            No se pudo cargar la comparación: {errorComp}
          </div>
        )}

        {cargandoComp && <p className="placeholder">Cargando comparación…</p>}

        {!cargandoComp && !errorComp && comparaciones.length === 0 && (
          <p className="placeholder">
            Ejecuta <code>enviar_comparacion_api(cmp)</code> desde R para
            comparar dos periodos.
          </p>
        )}

        {!cargandoComp && !errorComp && opcionComparacion && (
          <EChart
            option={opcionComparacion}
            height={Math.max(420, sentimientosComp.length * 34 + 130)}
          />
        )}
      </section>
    </div>
  );
}
