import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiGet } from '../api.js';
import EChart from '../components/EChart.jsx';

const AZUL_BARRAS = '#2E75B6';
const AZUL_BARRAS_B = '#8FC3F0';

const COLORES_TIEMPO = [
  '#2E75B6', '#2A9D8F', '#E9C46A', '#F4A261', '#E76F51', '#8E5572', '#3A86FF', '#8338EC',
  '#FF006E', '#06D6A0', '#6D597A', '#B56576', '#355070', '#00B4D8', '#90BE6D',
];

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;

const estiloTexto = {
  color: '#12263f',
  fontFamily: 'Archivo, Public Sans, sans-serif',
};
const estiloSubtexto = { color: '#5a7392', fontSize: 12 };
const estiloEje = { color: '#5a7392', fontSize: 11 };

/**
 * Opción base compartida por los gráficos de la serie mensual.
 */
const opcionBase = (titulo, subtext) => ({
  backgroundColor: 'transparent',
  title: {
    text: titulo,
    subtext,
    left: 0,
    top: 0,
    textStyle: { ...estiloTexto, fontSize: 16, fontWeight: 600 },
    subtextStyle: estiloSubtexto,
  },
  tooltip: { trigger: 'axis' },
  grid: { left: 90, right: 60, top: 70, bottom: 50 },
});

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

  const [datosSerie, setDatosSerie] = useState([]);
  const [periodoSerie, setPeriodoSerie] = useState(null);
  const [cargandoSerie, setCargandoSerie] = useState(false);
  const [errorSerie, setErrorSerie] = useState(null);

  const [datosSankey, setDatosSankey] = useState([]);
  const [periodoSankey, setPeriodoSankey] = useState(null);
  const [cargandoSankey, setCargandoSankey] = useState(false);
  const [errorSankey, setErrorSankey] = useState(null);

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

  const cargarSerie = useCallback(async (nombre) => {
    setCargandoSerie(true);
    setErrorSerie(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/serie?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/serie';
      const resp = await apiGet(ruta);
      setDatosSerie(resp.datos ?? []);
      setPeriodoSerie(resp.periodo ?? null);
    } catch (err) {
      setErrorSerie(err.message);
      setDatosSerie([]);
      setPeriodoSerie(null);
    } finally {
      setCargandoSerie(false);
    }
  }, []);

  const cargarSankey = useCallback(async (nombre) => {
    setCargandoSankey(true);
    setErrorSankey(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/sankey?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/sankey';
      const resp = await apiGet(ruta);
      setDatosSankey(resp.datos ?? []);
      setPeriodoSankey(resp.periodo ?? null);
    } catch (err) {
      setErrorSankey(err.message);
      setDatosSankey([]);
      setPeriodoSankey(null);
    } finally {
      setCargandoSankey(false);
    }
  }, []);

  useEffect(() => {
    cargarPeriodos();
    cargarComparaciones();
  }, [cargarPeriodos, cargarComparaciones]);

  useEffect(() => {
    cargarNiveles(periodoActivo);
    cargarSerie(periodoActivo);
    cargarSankey(periodoActivo);
  }, [cargarNiveles, cargarSerie, cargarSankey, periodoActivo]);

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

  // ---- g_tiempo: línea de evolución por sentimiento (serie mensual) ----
  const opcionTiempo = useMemo(() => {
    if (!datosSerie.length) return null;
    const sentimientos = [...new Set(datosSerie.map((d) => d.sentimiento))];
    const meses = [...new Set(datosSerie.map((d) => d.anio_mes))];
    const porSent = new Map(sentimientos.map((s) => [s, []]));
    datosSerie.forEach((d) => porSent.get(d.sentimiento).push({ value: [d.anio_mes, Number(d.pct)] }));

    return {
      ...opcionBase('Evolución de los sentimientos en el tiempo', periodoSerie?.nombre ? `Periodo: ${periodoSerie.nombre}` : undefined),
      legend: { bottom: 0, data: sentimientos, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: meses,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '% (promedio por mensaje)',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: sentimientos.map((s, i) => ({
        name: s,
        type: 'line',
        smooth: true,
        showSymbol: false,
        data: porSent.get(s),
        lineStyle: { width: 2 },
        itemStyle: { color: COLORES_TIEMPO[i % COLORES_TIEMPO.length] },
      })),
    };
  }, [datosSerie, periodoSerie]);

  // ---- g_apilado: áreas apiladas por sentimiento (serie mensual) ----
  const opcionApilado = useMemo(() => {
    if (!datosSerie.length) return null;
    const sentimientos = [...new Set(datosSerie.map((d) => d.sentimiento))];
    const meses = [...new Set(datosSerie.map((d) => d.anio_mes))];
    const porSent = new Map(sentimientos.map((s) => [s, []]));
    datosSerie.forEach((d) => porSent.get(d.sentimiento).push({ value: [d.anio_mes, Number(d.pct)] }));

    return {
      ...opcionBase('Composición de los sentimientos en el tiempo', periodoSerie?.nombre ? `Periodo: ${periodoSerie.nombre}` : undefined),
      legend: { bottom: 0, data: sentimientos, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: meses,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '% acumulado',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: sentimientos.map((s, i) => ({
        name: s,
        type: 'line',
        stack: 'total',
        areaStyle: {},
        emphasis: { focus: 'series' },
        data: porSent.get(s),
        itemStyle: { color: COLORES_TIEMPO[i % COLORES_TIEMPO.length] },
        lineStyle: { color: COLORES_TIEMPO[i % COLORES_TIEMPO.length] },
      })),
    };
  }, [datosSerie, periodoSerie]);

  // ---- g_polar: rosa de sentimientos (nivel) ----
  const opcionPolar = useMemo(() => {
    if (!datos.length) return null;
    const sentimientos = datos.map((d) => d.sentimiento);
    const valores = datos.map((d) => Number(d.nivel_pct));
    return {
      ...opcionBase('Sentimientos en coordenadas polares', periodo?.nombre ? `Periodo: ${periodo.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (params) => `${params.name}: ${formatearPct(params.value)}` },
      angleAxis: {
        type: 'category',
        data: sentimientos,
        axisLabel: { color: '#12263f', fontSize: 11 },
      },
      radiusAxis: { type: 'value', axisLabel: { color: '#5a7392', fontSize: 10 } },
      polar: { center: ['50%', '55%'], radius: '70%' },
      series: [
        {
          type: 'bar',
          data: valores,
          coordinateSystem: 'polar',
          barWidth: 24,
          itemStyle: { color: AZUL_BARRAS },
          label: { show: true, position: 'outside', formatter: ({ value }) => formatearPct(value), color: '#12263f', fontWeight: 600 },
        },
      ],
    };
  }, [datos, periodo]);

  // ---- g_arana: radar de perfil emocional (comparación) ----
  const opcionArana = useMemo(() => {
    if (!detalleComp) return null;
    const { periodos: periodosCmp = [], datos: datosCmp = [] } = detalleComp;
    const sentimientos = [...new Set(datosCmp.map((d) => d.sentimiento))];
    const indice = new Map(datosCmp.map((d) => [`${d.sentimiento}||${d.periodo}`, d]));
    const colores = [AZUL_BARRAS, AZUL_BARRAS_B];
    return {
      backgroundColor: 'transparent',
      title: {
        text: 'Perfil emocional (araña)',
        subtext: detalleComp.comparacion?.nombre,
        left: 0,
        top: 0,
        textStyle: { ...estiloTexto, fontSize: 16, fontWeight: 600 },
        subtextStyle: estiloSubtexto,
      },
      tooltip: { trigger: 'item' },
      radar: {
        indicator: sentimientos.map((s) => ({ name: s, max: 100 })),
        axisLabel: { color: '#5a7392', fontSize: 10 },
      },
      legend: {
        bottom: 0,
        data: periodosCmp.map((p) => p.nombre),
        textStyle: { color: '#5a7392' },
      },
      series: periodosCmp.map((p, i) => ({
        name: p.nombre,
        type: 'radar',
        data: [
          {
            value: sentimientos.map((s) => Number((indice.get(`${s}||${p.nombre}`) ?? {}).nivel_pct ?? 0)),
          },
        ],
        itemStyle: { color: colores[i % colores.length] },
        lineStyle: { color: colores[i % colores.length], width: 2 },
        areaStyle: { opacity: 0.2 },
        symbol: 'circle',
        symbolSize: 4,
      })),
    };
  }, [detalleComp]);

  // ---- g_dispersion: un sentimiento contra otro por mes (serie mensual) ----
  const opcionDispersion = useMemo(() => {
    if (!datosSerie.length) return null;
    const sentimientos = [...new Set(datosSerie.map((d) => d.sentimiento))];
    if (sentimientos.length < 2) return null;
    const [xSent, ySent] = sentimientos;
    const xMap = new Map(datosSerie.filter((d) => d.sentimiento === xSent).map((d) => [d.anio_mes, Number(d.pct)]));
    const data = datosSerie
      .filter((d) => d.sentimiento === ySent)
      .map((d) => ({ value: [xMap.get(d.anio_mes), Number(d.pct)], name: d.anio_mes }));

    return {
      ...opcionBase(`Dispersión: ${xSent} vs ${ySent}`, periodoSerie?.nombre ? `Periodo: ${periodoSerie.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (params) => `${params.name}: ${xSent} ${formatearPct(params.value[0])} · ${ySent} ${formatearPct(params.value[1])}` },
      xAxis: {
        type: 'value',
        name: `${xSent} (%)`,
        nameTextStyle: estiloEje,
        min: 0,
        max: 100,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: `${ySent} (%)`,
        nameTextStyle: estiloEje,
        min: 0,
        max: 100,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: [
        {
          name: 'Dispersión',
          type: 'scatter',
          data,
          symbolSize: 7,
          itemStyle: { color: AZUL_BARRAS },
          label: { show: true, formatter: ({ name }) => name, color: '#12263f', fontSize: 10 },
        },
      ],
    };
  }, [datosSerie, periodoSerie]);

  // ---- g_sankey: tópico -> sentimiento dominante ----
  const opcionSankey = useMemo(() => {
    if (!datosSankey.length) return null;
    const topicos = [...new Set(datosSankey.map((d) => d.topico))];
    const sentimientos = [...new Set(datosSankey.map((d) => d.sentimiento_dominante))];
    const nodos = [...topicos, ...sentimientos].map((nombre) => ({ name: nombre }));
    const enlaces = datosSankey.map((d) => ({
      source: d.topico,
      target: d.sentimiento_dominante,
      value: Number(d.freq),
    }));
    return {
      ...opcionBase('De qué se habla y qué se siente (sankey)', periodoSankey?.nombre ? `Periodo: ${periodoSankey.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (params) => (params.dataType === 'edge' ? `${params.data.source} → ${params.data.target}: ${params.data.value}` : `${params.name}`) },
      series: [
        {
          type: 'sankey',
          data: nodos,
          links: enlaces,
          emphasis: { focus: 'adjacency' },
          nodeAlign: 'justify',
          nodeGap: 10,
          layoutIterations: 0,
          lineStyle: { color: 'source', curveness: 0.5, opacity: 0.5 },
        },
      ],
    };
  }, [datosSankey, periodoSankey]);

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

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Serie de sentimientos en el tiempo">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Evolución en el tiempo</h2>
            </div>
            {errorSerie && <div className="estado-error">No se pudo cargar la serie: {errorSerie}</div>}
            {cargandoSerie && <p className="placeholder">Cargando serie…</p>}
            {!cargandoSerie && !errorSerie && opcionTiempo && (
              <EChart option={opcionTiempo} height={360} />
            )}
            {!cargandoSerie && !errorSerie && !opcionTiempo && datosSerie.length === 0 && (
              <p className="placeholder">
                Ejecuta <code>enviar_niveles_api(a)</code> desde R para subir la
                serie mensual del periodo.
              </p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Áreas apiladas por sentimiento">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Composición apilada en el tiempo</h2>
            </div>
            {!cargandoSerie && !errorSerie && opcionApilado && (
              <EChart option={opcionApilado} height={320} />
            )}
            {!cargandoSerie && !errorSerie && !opcionApilado && datosSerie.length === 0 && (
              <p className="placeholder">Sin datos de serie mensual para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Rosa de sentimientos">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Sentimientos en coordenadas polares</h2>
            </div>
            {!cargando && !error && opcionPolar && <EChart option={opcionPolar} height={420} />}
            {!cargando && !error && !opcionPolar && !hayDatos && (
              <p className="placeholder">Sin datos de nivel para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && comparaciones.length > 0 && (
          <section className="panel-grafico" aria-label="Perfil emocional (araña)">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Perfil emocional (araña)</h2>
            </div>
            {!cargandoComp && !errorComp && opcionArana && (
              <EChart option={opcionArana} height={420} />
            )}
            {!cargandoComp && !errorComp && !opcionArana && comparaciones.length > 0 && (
              <p className="placeholder">Sin datos de comparación para dibujar el radar.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Dispersión de sentimientos">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Dispersión de sentimientos</h2>
            </div>
            {!cargandoSerie && !errorSerie && opcionDispersion && (
              <EChart option={opcionDispersion} height={400} />
            )}
            {!cargandoSerie && !errorSerie && !opcionDispersion && datosSerie.length === 0 && (
              <p className="placeholder">Se necesitan al menos dos sentimientos en la serie mensual.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Sankey tópico x sentimiento">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Tópico → sentimiento dominante</h2>
            </div>
            {errorSankey && <div className="estado-error">No se pudo cargar el sankey: {errorSankey}</div>}
            {cargandoSankey && <p className="placeholder">Cargando sankey…</p>}
            {!cargandoSankey && !errorSankey && opcionSankey && (
              <EChart option={opcionSankey} height={460} />
            )}
            {!cargandoSankey && !errorSankey && !opcionSankey && datosSankey.length === 0 && (
              <p className="placeholder">
                Ejecuta <code>enviar_niveles_api(a)</code> desde R para subir el
                cruce tópico x sentimiento dominante del periodo.
              </p>
            )}
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
