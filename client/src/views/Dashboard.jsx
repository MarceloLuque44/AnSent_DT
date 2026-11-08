import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiGet } from '../api.js';
import EChart from '../components/EChart.jsx';

const AZUL_BARRAS = '#2E75B6';

const formatearPct = (valor) => `${Number(valor).toFixed(1)}%`;

/**
 * Dashboard: gráficos del análisis calculado en R.
 * Los datos llegan de GET /api/dashboard/niveles (tablas analisis /
 * analisis_nivel) y se dibujan con ECharts.
 */
export default function Dashboard() {
  const [periodos, setPeriodos] = useState([]);
  const [periodoActivo, setPeriodoActivo] = useState('');
  const [datos, setDatos] = useState([]);
  const [periodo, setPeriodo] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);

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

  useEffect(() => {
    cargarPeriodos();
  }, [cargarPeriodos]);

  useEffect(() => {
    cargarNiveles(periodoActivo);
  }, [cargarNiveles, periodoActivo]);

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
          <EChart option={opcion} height={Math.max(380, hayDatos ? datos.length * 32 + 110 : 380)} />
        </section>
      )}
    </div>
  );
}
