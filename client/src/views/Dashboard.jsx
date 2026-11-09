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

  const [datosGraficos, setDatosGraficos] = useState({
    tfidf: [],
    topicos: [],
    topicos_tiempo: [],
    upos: [],
    nivel_mensaje: [],
    calor: [],
  });
  const [datosGraficosAdicionales, setDatosGraficosAdicionales] = useState({
    volumen: [],
    evolucion_anual: [],
    sent_heat: [],
    dominante: [],
    polaridad_tiempo: [],
    sent_hora_heat: [],
    correlacion: [],
    palabras: [],
    emojis: [],
    libreria_vs_propios: [],
    diferencia: [],
  });
  const [periodoGraficos, setPeriodoGraficos] = useState(null);
  const [cargandoGraficos, setCargandoGraficos] = useState(false);
  const [errorGraficos, setErrorGraficos] = useState(null);

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

  const cargarGraficos = useCallback(async (nombre) => {
    setCargandoGraficos(true);
    setErrorGraficos(null);
    try {
      const ruta = nombre
        ? `/api/dashboard/graficos?periodo=${encodeURIComponent(nombre)}`
        : '/api/dashboard/graficos';
      const resp = await apiGet(ruta);
      const g = resp.graficos ?? {};
      setDatosGraficos({
        tfidf: Array.isArray(g.tfidf) ? g.tfidf : [],
        topicos: Array.isArray(g.topicos) ? g.topicos : [],
        topicos_tiempo: Array.isArray(g.topicos_tiempo) ? g.topicos_tiempo : [],
        upos: Array.isArray(g.upos) ? g.upos : [],
        nivel_mensaje: Array.isArray(g.nivel_mensaje) ? g.nivel_mensaje : [],
        calor: Array.isArray(g.calor) ? g.calor : [],
      });
      setDatosGraficosAdicionales({
        volumen: Array.isArray(g.volumen) ? g.volumen : [],
        evolucion_anual: Array.isArray(g.evolucion_anual) ? g.evolucion_anual : [],
        sent_heat: Array.isArray(g.sent_heat) ? g.sent_heat : [],
        dominante: Array.isArray(g.dominante) ? g.dominante : [],
        polaridad_tiempo: Array.isArray(g.polaridad_tiempo) ? g.polaridad_tiempo : [],
        sent_hora_heat: Array.isArray(g.sent_hora_heat) ? g.sent_hora_heat : [],
        correlacion: Array.isArray(g.correlacion) ? g.correlacion : [],
        palabras: Array.isArray(g.palabras) ? g.palabras : [],
        emojis: Array.isArray(g.emojis) ? g.emojis : [],
        libreria_vs_propios: Array.isArray(g.libreria_vs_propios) ? g.libreria_vs_propios : [],
        diferencia: Array.isArray(g.diferencia) ? g.diferencia : [],
      });
      setPeriodoGraficos(resp.periodo ?? null);
    } catch (err) {
      setErrorGraficos(err.message);
      setDatosGraficos({ tfidf: [], topicos: [], topicos_tiempo: [], upos: [], nivel_mensaje: [], calor: [] });
      setPeriodoGraficos(null);
    } finally {
      setCargandoGraficos(false);
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
    cargarGraficos(periodoActivo);
  }, [cargarNiveles, cargarSerie, cargarSankey, cargarGraficos, periodoActivo]);

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

  // ---- g_tfidf: terminos mas distintivos (TF-IDF) ----
  const opcionTfidf = useMemo(() => {
    if (!datosGraficos.tfidf.length) return null;
    const filas = [...datosGraficos.tfidf]
      .sort((a, b) => Number(b.tf_idf) - Number(a.tf_idf))
      .slice(0, 40);
    const docs = [...new Set(filas.map((f) => f.doc))];
    const colorPorDoc = new Map(docs.map((d, i) => [d, COLORES_TIEMPO[i % COLORES_TIEMPO.length]]));
    return {
      ...opcionBase('Terminos mas distintivos (TF-IDF)', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: {
        trigger: 'item',
        formatter: (p) => {
          const f = filas[p.dataIndex];
          return [`<b>${f.token}</b> — ${f.doc}`, `TF-IDF: ${Number(f.tf_idf).toFixed(3)}`, `n: ${f.n}`, `tf: ${Number(f.tf).toFixed(3)}`, `idf: ${Number(f.idf).toFixed(3)}`].join('<br/>');
        },
      },
      xAxis: {
        type: 'value',
        name: 'TF-IDF',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => `${f.token} — ${f.doc}`),
        inverse: true,
        axisLabel: { color: '#12263f', fontSize: 10 },
        axisTick: { show: false },
      },
      series: [
        {
          type: 'bar',
          name: 'TF-IDF',
          data: filas.map((f) => ({
            value: Number(f.tf_idf),
            itemStyle: { color: colorPorDoc.get(f.doc) },
          })),
          barMaxWidth: 20,
          label: { show: true, position: 'right', formatter: ({ value }) => value.toFixed(3), color: '#12263f', fontSize: 9 },
        },
      ],
    };
  }, [datosGraficos.tfidf, periodoGraficos]);

  // ---- g_topicos: terminos de cada topico (LDA) ----
  const opcionTopicos = useMemo(() => {
    if (!datosGraficos.topicos.length) return null;
    const filas = [...datosGraficos.topicos]
      .sort((a, b) => Number(b.beta) - Number(a.beta))
      .slice(0, 40);
    const topicos = [...new Set(filas.map((f) => f.topico))];
    const colorPorTopico = new Map(topicos.map((t, i) => [t, COLORES_TIEMPO[i % COLORES_TIEMPO.length]]));
    return {
      ...opcionBase('Topicos (LDA): terminos mas probables', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: {
        trigger: 'item',
        formatter: (p) => {
          const f = filas[p.dataIndex];
          return [`<b>${f.termino}</b> — ${f.topico}: ${f.etiqueta}`, `beta: ${Number(f.beta).toFixed(4)}`].join('<br/>');
        },
      },
      xAxis: {
        type: 'value',
        name: 'beta (probabilidad)',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => v.toFixed(4), color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => `${f.termino} — ${f.topico}: ${f.etiqueta}`),
        inverse: true,
        axisLabel: { color: '#12263f', fontSize: 10 },
        axisTick: { show: false },
      },
      series: [
        {
          type: 'bar',
          name: 'beta',
          data: filas.map((f) => ({
            value: Number(f.beta),
            itemStyle: { color: colorPorTopico.get(f.topico) },
          })),
          barMaxWidth: 20,
          label: { show: true, position: 'right', formatter: ({ value }) => value.toFixed(3), color: '#12263f', fontSize: 9 },
        },
      ],
    };
  }, [datosGraficos.topicos, periodoGraficos]);

  // ---- g_topicos_tiempo: peso de cada topico en el tiempo ----
  const opcionTopicosTiempo = useMemo(() => {
    if (!datosGraficos.topicos_tiempo.length) return null;
    const paneles = [...new Set(datosGraficos.topicos_tiempo.map((d) => `${d.topico}: ${d.etiqueta}`))];
    const meses = [...new Set(datosGraficos.topicos_tiempo.map((d) => d.anio_mes))].sort();
    const porPanel = new Map(paneles.map((p) => [p, []]));
    datosGraficos.topicos_tiempo.forEach((d) => porPanel.get(`${d.topico}: ${d.etiqueta}`).push({ value: [d.anio_mes, Number(d.peso_pct)] }));
    return {
      ...opcionBase('Peso de cada topico por mes', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      legend: { bottom: 0, data: paneles, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: meses,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '% del mes',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: paneles.map((p, i) => ({
        name: p,
        type: 'line',
        smooth: true,
        showSymbol: false,
        data: porPanel.get(p),
        lineStyle: { width: 2 },
        itemStyle: { color: COLORES_TIEMPO[i % COLORES_TIEMPO.length] },
      })),
    };
  }, [datosGraficos.topicos_tiempo, periodoGraficos]);

  // ---- g_upos: categorias gramaticales (shallow linguistic) ----
  const opcionUpos = useMemo(() => {
    if (!datosGraficos.upos.length) return null;
    const filas = [...datosGraficos.upos].sort((a, b) => Number(b.pct) - Number(a.pct));
    return {
      ...opcionBase('Categorias gramaticales (shallow linguistic)', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `${p.name}: ${formatearPct(p.value)}` },
      xAxis: {
        type: 'value',
        name: '% de las palabras',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => f.clase),
        inverse: true,
        axisLabel: { color: '#12263f' },
        axisTick: { show: false },
      },
      series: [
        {
          type: 'bar',
          name: 'pct',
          data: filas.map((f) => Number(f.pct)),
          barMaxWidth: 22,
          itemStyle: { color: '#7030A0', borderRadius: [0, 4, 4, 0] },
          label: { show: true, position: 'right', formatter: ({ value }) => formatearPct(value), color: '#12263f', fontWeight: 600 },
        },
      ],
    };
  }, [datosGraficos.upos, periodoGraficos]);

  // ---- g_nivel_mensaje: mensaje representante frente a su periodo ----
  const opcionNivelMensaje = useMemo(() => {
    if (!datosGraficos.nivel_mensaje.length) return null;
    const sentimientos = datosGraficos.nivel_mensaje.map((d) => d.sentimiento);
    return {
      ...opcionBase('Nivel del mensaje frente a su periodo', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        formatter: (params) => {
          const p = params[0];
          const f = datosGraficos.nivel_mensaje.find((d) => d.sentimiento === p.name) ?? {};
          return [`<b>${p.name}</b>`, `Mensaje: ${formatearPct(p.value)}`, `Periodo: ${formatearPct(Number(f.periodo_pct))}`].join('<br/>');
        },
      },
      grid: { left: 130, right: 70, top: 72, bottom: 34 },
      xAxis: {
        type: 'value',
        name: '%',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
        max: 100,
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
          name: 'Mensaje',
          type: 'bar',
          data: datosGraficos.nivel_mensaje.map((d) => Number(d.mensaje_pct)),
          barMaxWidth: 22,
          itemStyle: { color: '#2A9D8F', borderRadius: [0, 4, 4, 0] },
          label: { show: true, position: 'right', formatter: ({ value }) => formatearPct(value), color: '#12263f', fontWeight: 600 },
        },
        {
          name: 'Periodo',
          type: 'bar',
          data: datosGraficos.nivel_mensaje.map((d) => Number(d.periodo_pct)),
          barMaxWidth: 22,
          itemStyle: { color: '#8E5572', borderRadius: [0, 4, 4, 0] },
          label: { show: true, position: 'right', formatter: ({ value }) => formatearPct(value), color: '#12263f', fontWeight: 600 },
        },
      ],
    };
  }, [datosGraficos.nivel_mensaje, periodoGraficos]);

  // ---- g_calor: mapa de calor dia de la semana x hora ----
  const ORDEN_DIAS = ['lunes', 'martes', 'miércoles', 'miercoles', 'jueves', 'viernes', 'sábado', 'sabado', 'domingo'];
  const opcionCalor = useMemo(() => {
    if (!datosGraficos.calor.length) return null;
    const diasPresentes = ORDEN_DIAS.filter((d) => datosGraficos.calor.some((c) => c.dia === d));
    const diaIndex = new Map(diasPresentes.map((d, i) => [d, i]));
    const horas = [...Array(24).keys()].map(String);
    const maxFreq = Math.max(...datosGraficos.calor.map((c) => Number(c.freq)));
    return {
      ...opcionBase('Actividad del grupo: dia de la semana x hora', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: {
        trigger: 'item',
        formatter: (p) => `Dia: ${p.value[1] === undefined ? diasPresentes[p.data[1]] : diasPresentes[p.value[1]]}<br/>Hora: ${p.value[0]}:00<br/>Mensajes: ${p.value[2]}`,
      },
      xAxis: {
        type: 'category',
        data: horas.map((h) => `${h}:00`),
        name: 'hora',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: diasPresentes,
        name: 'dia',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#12263f' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      visualMap: {
        min: 0,
        max: maxFreq,
        calculable: true,
        orient: 'horizontal',
        left: 'center',
        bottom: 10,
        inRange: { color: ['#f7fbff', '#08306b'] },
        textStyle: { color: '#5a7392' },
      },
      series: [
        {
          name: 'mensajes',
          type: 'heatmap',
          data: datosGraficos.calor.map((c) => [Number(c.hora), diaIndex.get(c.dia), Number(c.freq)]),
          label: { show: false },
          emphasis: { itemStyle: { borderWidth: 1, borderColor: '#333' } },
        },
      ],
    };
  }, [datosGraficos.calor, periodoGraficos]);

  // ---- g_volumen: volumen de mensajes en el tiempo ----
  const opcionVolumen = useMemo(() => {
    if (!datosGraficosAdicionales.volumen.length) return null;
    const filas = [...datosGraficosAdicionales.volumen].sort((a, b) => String(a.fecha).localeCompare(String(b.fecha)));
    const fechas = filas.map((f) => f.fecha);
    return {
      ...opcionBase('Volumen de mensajes en el tiempo', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'axis', formatter: (p) => `${p[0].name}: ${p[0].value} mensajes` },
      xAxis: {
        type: 'category',
        data: fechas,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: 'mensajes',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: [{
        name: 'Volumen',
        type: 'line',
        smooth: true,
        showSymbol: false,
        data: filas.map((f) => Number(f.freq)),
        areaStyle: {},
        itemStyle: { color: '#3A86FF' },
        lineStyle: { color: '#3A86FF', width: 2 },
      }],
    };
  }, [datosGraficosAdicionales.volumen, periodoGraficos]);

  // ---- g_evolucion_anual: sentimientos por ano ----
  const opcionEvolucionAnual = useMemo(() => {
    if (!datosGraficosAdicionales.evolucion_anual.length) return null;
    const sentimientos = [...new Set(datosGraficosAdicionales.evolucion_anual.map((d) => d.sentimiento))];
    const anios = [...new Set(datosGraficosAdicionales.evolucion_anual.map((d) => String(d.anio)))].sort();
    const porSent = new Map(sentimientos.map((s) => [s, []]));
    datosGraficosAdicionales.evolucion_anual.forEach((d) => porSent.get(d.sentimiento).push({ value: [String(d.anio), Number(d.pct)] }));
    return {
      ...opcionBase('Evolucion de los sentimientos por ano', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      legend: { bottom: 0, data: sentimientos, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: anios,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '% promedio por mensaje',
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
  }, [datosGraficosAdicionales.evolucion_anual, periodoGraficos]);

  // ---- g_sent_heat: mapa de calor sentimiento x tiempo ----
  const opcionSentHeat = useMemo(() => {
    if (!datosGraficosAdicionales.sent_heat.length) return null;
    const sentimientos = [...new Set(datosGraficosAdicionales.sent_heat.map((d) => d.sentimiento))];
    const fechas = [...new Set(datosGraficosAdicionales.sent_heat.map((d) => d.fecha))].sort();
    const fIdx = new Map(fechas.map((f, i) => [f, i]));
    const sIdx = new Map(sentimientos.map((s, i) => [s, i]));
    const maxPct = Math.max(...datosGraficosAdicionales.sent_heat.map((d) => Number(d.pct)));
    return {
      ...opcionBase('Mapa de calor emocional por tiempo', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `Fecha: ${p.value[0]}<br/>Sentimiento: ${p.value[1]}<br/>Promedio: ${Number(p.value[2]).toFixed(1)}%` },
      xAxis: {
        type: 'category',
        data: fechas,
        axisLabel: { color: '#5a7392', fontSize: 9 },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: sentimientos,
        axisLabel: { color: '#12263f' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      visualMap: {
        min: 0,
        max: maxPct,
        calculable: true,
        orient: 'horizontal',
        left: 'center',
        bottom: 10,
        inRange: { color: ['#f7fbff', '#08306b'] },
        textStyle: { color: '#5a7392' },
      },
      series: [{
        name: 'pct',
        type: 'heatmap',
        data: datosGraficosAdicionales.sent_heat.map((d) => [fIdx.get(d.fecha), sIdx.get(d.sentimiento), Number(d.pct)]),
        label: { show: false },
      }],
    };
  }, [datosGraficosAdicionales.sent_heat, periodoGraficos]);

  // ---- g_dominante: emocion dominante por fecha (apilada al 100 %) ----
  const opcionDominante = useMemo(() => {
    if (!datosGraficosAdicionales.dominante.length) return null;
    const filas = datosGraficosAdicionales.dominante;
    const doms = [...new Set(filas.map((d) => d.dom))];
    const fechas = [...new Set(filas.map((d) => d.fecha))].sort();
    const totales = new Map();
    filas.forEach((d) => { totales.set(d.fecha, (totales.get(d.fecha) || 0) + Number(d.freq)); });
    const indice = new Map(filas.map((d, i) => [`${d.fecha}||${d.dom}`, i]));
    const colorPorDom = new Map(doms.map((s, i) => [s, COLORES_TIEMPO[i % COLORES_TIEMPO.length]]));
    return {
      ...opcionBase('Emocion dominante por fecha', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
      legend: { bottom: 0, data: doms, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: fechas,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '%',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v.toFixed(0)}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
        max: 100,
      },
      series: doms.map((s, i) => ({
        name: s,
        type: 'bar',
        stack: 'total',
        data: fechas.map((f) => {
          const idx = indice.get(`${f}||${s}`);
          const fila = idx != null ? filas[idx] : null;
          const freq = fila ? Number(fila.freq) : 0;
          const total = totales.get(f) || 1;
          return freq / total * 100;
        }),
        itemStyle: { color: colorPorDom.get(s) },
      })),
    };
  }, [datosGraficosAdicionales.dominante, periodoGraficos]);

  // ---- g_polaridad_tiempo: polaridad por fecha (apilada al 100 %) ----
  const opcionPolaridadTiempo = useMemo(() => {
    if (!datosGraficosAdicionales.polaridad_tiempo.length) return null;
    const filas = datosGraficosAdicionales.polaridad_tiempo;
    const gatos = ['positivo', 'neutral', 'negativo', 'sin sentimiento detectado'];
    const fechas = [...new Set(filas.map((d) => d.fecha))].sort();
    const totales = new Map();
    filas.forEach((d) => { totales.set(d.fecha, (totales.get(d.fecha) || 0) + Number(d.freq)); });
    const indice = new Map(filas.map((d, i) => [`${d.fecha}||${d.cat}`, i]));
    const colores = { positivo: '#2A9D8F', neutral: '#E9C46A', negativo: '#E76F51', 'sin sentimiento detectado': '#9aa5b1' };
    return {
      ...opcionBase('Polaridad de los mensajes por fecha', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
      legend: { bottom: 0, data: gatos, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: fechas,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '%',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v.toFixed(0)}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
        max: 100,
      },
      series: gatos.map((s, i) => ({
        name: s,
        type: 'bar',
        stack: 'total',
        data: fechas.map((f) => {
          const idx = indice.get(`${f}||${s}`);
          const fila = idx != null ? filas[idx] : null;
          const freq = fila ? Number(fila.freq) : 0;
          const total = totales.get(f) || 1;
          return freq / total * 100;
        }),
        itemStyle: { color: colores[s] },
      })),
    };
  }, [datosGraficosAdicionales.polaridad_tiempo, periodoGraficos]);

  // ---- g_sent_hora_heat: mapa de calor sentimiento x hora ----
  const opcionSentHoraHeat = useMemo(() => {
    if (!datosGraficosAdicionales.sent_hora_heat.length) return null;
    const sentimientos = [...new Set(datosGraficosAdicionales.sent_hora_heat.map((d) => d.sentimiento))];
    const horas = [...Array(24).keys()].map(String);
    const hIdx = new Map(horas.map((h, i) => [h, i]));
    const sIdx = new Map(sentimientos.map((s, i) => [s, i]));
    const maxPct = Math.max(...datosGraficosAdicionales.sent_hora_heat.map((d) => Number(d.pct)));
    return {
      ...opcionBase('Sentimiento promedio por hora del dia', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `Hora: ${p.value[0]}:00<br/>Sentimiento: ${p.value[1]}<br/>Promedio: ${Number(p.value[2]).toFixed(1)}%` },
      xAxis: {
        type: 'category',
        data: horas.map((h) => `${h}:00`),
        name: 'hora',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: sentimientos,
        name: 'sentimiento',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#12263f' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      visualMap: {
        min: 0,
        max: maxPct,
        calculable: true,
        orient: 'horizontal',
        left: 'center',
        bottom: 10,
        inRange: { color: ['#f7fbff', '#08306b'] },
        textStyle: { color: '#5a7392' },
      },
      series: [{
        name: 'pct',
        type: 'heatmap',
        data: datosGraficosAdicionales.sent_hora_heat.map((d) => [hIdx.get(String(d.hora)), sIdx.get(d.sentimiento), Number(d.pct)]),
        label: { show: false },
      }],
    };
  }, [datosGraficosAdicionales.sent_hora_heat, periodoGraficos]);

  // ---- g_correlacion: correlacion entre sentimientos ----
  const opcionCorrelacion = useMemo(() => {
    if (!datosGraficosAdicionales.correlacion.length) return null;
    const sentimientos = [...new Set([...datosGraficosAdicionales.correlacion.map((d) => d.a), ...datosGraficosAdicionales.correlacion.map((d) => d.b)])];
    const sIdx = new Map(sentimientos.map((s, i) => [s, i]));
    return {
      ...opcionBase('Correlacion entre sentimientos por mensaje', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `${p.value[1]} vs ${p.value[0]}: r = ${Number(p.value[2]).toFixed(2)}` },
      xAxis: {
        type: 'category',
        data: sentimientos,
        axisLabel: { color: '#5a7392', fontSize: 9 },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: sentimientos,
        axisLabel: { color: '#12263f', fontSize: 9 },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      visualMap: {
        min: -1,
        max: 1,
        calculable: true,
        orient: 'horizontal',
        left: 'center',
        bottom: 10,
        inRange: { color: ['#3A86FF', 'white', '#E76F51'] },
        textStyle: { color: '#5a7392' },
      },
      series: [{
        name: 'r',
        type: 'heatmap',
        data: datosGraficosAdicionales.correlacion.map((d) => [sIdx.get(d.a), sIdx.get(d.b), Number(d.r)]),
        label: {
          show: true,
          formatter: ({ value }) => {
            const v = Number(value);
            return Number.isFinite(v) ? v.toFixed(2) : '—';
          },
          color: '#12263f',
          fontSize: 9,
        },
      }],
    };
  }, [datosGraficosAdicionales.correlacion, periodoGraficos]);

  // ---- g_palabras: palabras mas usadas ----
  const opcionPalabras = useMemo(() => {
    if (!datosGraficosAdicionales.palabras.length) return null;
    const filas = [...datosGraficosAdicionales.palabras].sort((a, b) => Number(b.n) - Number(a.n));
    return {
      ...opcionBase('Palabras mas usadas', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `${p.name}: ${p.value} veces` },
      xAxis: {
        type: 'value',
        name: 'veces',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => f.palabra),
        inverse: true,
        axisLabel: { color: '#12263f' },
        axisTick: { show: false },
      },
      series: [{
        name: 'n',
        type: 'bar',
        data: filas.map((f) => Number(f.n)),
        barMaxWidth: 22,
        itemStyle: { color: '#8338EC', borderRadius: [0, 4, 4, 0] },
        label: { show: true, position: 'right', formatter: ({ value }) => value, color: '#12263f', fontWeight: 600 },
      }],
    };
  }, [datosGraficosAdicionales.palabras, periodoGraficos]);

  // ---- g_emojis: emojis mas usados ----
  const opcionEmojis = useMemo(() => {
    if (!datosGraficosAdicionales.emojis.length) return null;
    const filas = [...datosGraficosAdicionales.emojis].sort((a, b) => Number(b.n) - Number(a.n));
    const colorPorSent = { positivo: '#2A9D8F', neutral: '#E9C46A', negativo: '#E76F51', 'sin dato': '#9aa5b1' };
    return {
      ...opcionBase('Emojis mas usados y su sentimiento', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `${p.name}: ${p.value} veces · ${p.marker ? '' : ''}` },
      xAxis: {
        type: 'value',
        name: 'veces',
        nameTextStyle: estiloEje,
        axisLabel: { color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => f.etiqueta || f.emoji),
        inverse: true,
        axisLabel: { color: '#12263f' },
        axisTick: { show: false },
      },
      series: [{
        name: 'n',
        type: 'bar',
        data: filas.map((f) => ({ value: Number(f.n), itemStyle: { color: colorPorSent[f.sentimiento] } })),
        barMaxWidth: 22,
        label: { show: true, position: 'right', formatter: ({ value }) => value, color: '#12263f', fontWeight: 600 },
      }],
    };
  }, [datosGraficosAdicionales.emojis, periodoGraficos]);

  // ---- g_libreria_vs_propios: polaridad propio vs libreria ----
  const opcionLibreriaVsPropios = useMemo(() => {
    if (!datosGraficosAdicionales.libreria_vs_propios.length) return null;
    const filas = datosGraficosAdicionales.libreria_vs_propios;
    const polaridades = ['positivo', 'neutral', 'negativo'];
    const fuentes = ['diccionario propio', 'libreria (syuzhet)'];
    const indice = new Map(filas.map((f, i) => [`${f.polaridad}||${f.fuente}`, i]));
    const colorPorFuente = { 'diccionario propio': '#2E75B6', 'libreria (syuzhet)': '#E76F51' };
    return {
      ...opcionBase('Polaridad: diccionario propio vs libreria', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
      legend: { bottom: 0, data: fuentes, textStyle: { color: '#5a7392' } },
      xAxis: {
        type: 'category',
        data: polaridades,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'value',
        name: '% de mensajes',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v}%`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: fuentes.map((fuente, i) => ({
        name: fuente,
        type: 'bar',
        data: polaridades.map((p) => {
          const idx = indice.get(`${p}||${fuente}`);
          return idx != null ? Number(filas[idx].pct) : 0;
        }),
        barMaxWidth: 22,
        barGap: '10%',
        itemStyle: { color: colorPorFuente[fuente], borderRadius: [0, 4, 4, 0] },
        label: { show: true, position: 'top', formatter: ({ value }) => value.toFixed(1) + '%', color: '#12263f', fontSize: 9 },
      })),
    };
  }, [datosGraficosAdicionales.libreria_vs_propios, periodoGraficos]);

  // ---- g_diferencia: diferencia entre dos periodos ----
  const opcionDiferencia = useMemo(() => {
    if (!datosGraficosAdicionales.diferencia.length) return null;
    const filas = [...datosGraficosAdicionales.diferencia].sort((a, b) => Number(b.dif) - Number(a.dif));
    return {
      ...opcionBase('Diferencia entre dos periodos', periodoGraficos?.nombre ? `Periodo: ${periodoGraficos.nombre}` : undefined),
      tooltip: { trigger: 'item', formatter: (p) => `${p.name}: ${p.value > 0 ? '+' : ''}${p.value.toFixed(1)} puntos` },
      xAxis: {
        type: 'value',
        name: 'diferencia (puntos porcentuales)',
        nameTextStyle: estiloEje,
        axisLabel: { formatter: (v) => `${v > 0 ? '+' : ''}${v}`, color: '#5a7392' },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      yAxis: {
        type: 'category',
        data: filas.map((f) => f.sentimiento),
        inverse: true,
        axisLabel: { color: '#12263f' },
        axisTick: { show: false },
      },
      series: [{
        name: 'diferencia',
        type: 'bar',
        data: filas.map((f) => ({ value: Number(f.dif), itemStyle: { color: f.sube ? '#2A9D8F' : '#E76F51' } })),
        barMaxWidth: 22,
        label: { show: true, position: 'right', formatter: ({ value }) => (value > 0 ? '+' : '') + value.toFixed(1), color: '#12263f', fontWeight: 600 },
      }],
    };
  }, [datosGraficosAdicionales.diferencia, periodoGraficos]);

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

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Terminos mas distintivos (TF-IDF)">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Terminos mas distintivos (TF-IDF)</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionTfidf && (
              <EChart option={opcionTfidf} height={520} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionTfidf && datosGraficos.tfidf.length === 0 && (
              <p className="placeholder">Sin datos de TF-IDF para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Topicos (LDA) terminos">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Topicos (LDA): terminos mas probables</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionTopicos && (
              <EChart option={opcionTopicos} height={520} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionTopicos && datosGraficos.topicos.length === 0 && (
              <p className="placeholder">Sin datos de topicos para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Peso de topicos en el tiempo">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Peso de cada topico por mes</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionTopicosTiempo && (
              <EChart option={opcionTopicosTiempo} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionTopicosTiempo && datosGraficos.topicos_tiempo.length === 0 && (
              <p className="placeholder">Sin datos de topicos en el tiempo para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Categorias gramaticales">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Categorias gramaticales (shallow linguistic)</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionUpos && (
              <EChart option={opcionUpos} height={400} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionUpos && datosGraficos.upos.length === 0 && (
              <p className="placeholder">Sin datos de shallow linguistic para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Nivel del mensaje frente al periodo">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Nivel del mensaje frente a su periodo</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionNivelMensaje && (
              <EChart option={opcionNivelMensaje} height={420} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionNivelMensaje && datosGraficos.nivel_mensaje.length === 0 && (
              <p className="placeholder">Sin datos de nivel de mensaje para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Mapa de calor actividad">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Actividad: dia de la semana x hora</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionCalor && (
              <EChart option={opcionCalor} height={420} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionCalor && datosGraficos.calor.length === 0 && (
              <p className="placeholder">Sin datos de calor para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Volumen de mensajes en el tiempo">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Volumen de mensajes en el tiempo</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionVolumen && (
              <EChart option={opcionVolumen} height={320} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionVolumen && datosGraficosAdicionales.volumen.length === 0 && (
              <p className="placeholder">Sin datos de volumen para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Evolucion de sentimientos por ano">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Evolucion de los sentimientos por ano</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionEvolucionAnual && (
              <EChart option={opcionEvolucionAnual} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionEvolucionAnual && datosGraficosAdicionales.evolucion_anual.length === 0 && (
              <p className="placeholder">Se necesitan al menos dos anos para la evolucion anual.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Mapa de calor emocional por tiempo">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Mapa de calor emocional por tiempo</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionSentHeat && (
              <EChart option={opcionSentHeat} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionSentHeat && datosGraficosAdicionales.sent_heat.length === 0 && (
              <p className="placeholder">Sin datos de calor emocional para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Emocion dominante por fecha">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Emocion dominante por fecha</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionDominante && (
              <EChart option={opcionDominante} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionDominante && datosGraficosAdicionales.dominante.length === 0 && (
              <p className="placeholder">Sin datos de emocion dominante para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Polaridad de mensajes por fecha">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Polaridad de los mensajes por fecha</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionPolaridadTiempo && (
              <EChart option={opcionPolaridadTiempo} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionPolaridadTiempo && datosGraficosAdicionales.polaridad_tiempo.length === 0 && (
              <p className="placeholder">Sin datos de polaridad para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Sentimiento por hora del dia">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Sentimiento promedio por hora del dia</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionSentHoraHeat && (
              <EChart option={opcionSentHoraHeat} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionSentHoraHeat && datosGraficosAdicionales.sent_hora_heat.length === 0 && (
              <p className="placeholder">Sin datos de sentimiento por hora para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Correlacion entre sentimientos">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Correlacion entre sentimientos</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionCorrelacion && (
              <EChart option={opcionCorrelacion} height={420} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionCorrelacion && datosGraficosAdicionales.correlacion.length === 0 && (
              <p className="placeholder">Sin datos de correlacion para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Palabras mas usadas">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Palabras mas usadas</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionPalabras && (
              <EChart option={opcionPalabras} height={480} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionPalabras && datosGraficosAdicionales.palabras.length === 0 && (
              <p className="placeholder">Sin datos de palabras para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Emojis mas usados">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Emojis mas usados y su sentimiento</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionEmojis && (
              <EChart option={opcionEmojis} height={480} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionEmojis && datosGraficosAdicionales.emojis.length === 0 && (
              <p className="placeholder">Sin datos de emojis para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Polaridad propio vs libreria">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Polaridad: diccionario propio vs libreria</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionLibreriaVsPropios && (
              <EChart option={opcionLibreriaVsPropios} height={360} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionLibreriaVsPropios && datosGraficosAdicionales.libreria_vs_propios.length === 0 && (
              <p className="placeholder">Sin datos de libreria vs propios para este periodo.</p>
            )}
          </section>
        )}

        {!cargando && !error && hayDatos && (
          <section className="panel-grafico" aria-label="Diferencia entre dos periodos">
            <div className="panel-grafico-cabecera">
              <h2 className="panel-grafico-titulo">Diferencia entre dos periodos</h2>
            </div>
            {!cargandoGraficos && !errorGraficos && opcionDiferencia && (
              <EChart option={opcionDiferencia} height={420} />
            )}
            {!cargandoGraficos && !errorGraficos && !opcionDiferencia && datosGraficosAdicionales.diferencia.length === 0 && (
              <p className="placeholder">
                Ejecuta <code>enviar_comparacion_api(cmp)</code> desde R para
                ver la diferencia entre dos periodos.
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
