import { useEffect, useState, useCallback } from 'react';
import Chart from '../components/Chart.jsx';
import { apiGet, apiPost } from '../api.js';
import { useSse } from '../sse.jsx';

/**
 * Dashboard: consumir graficos JSON desde R via Plumber (a traves de Express)
 * y recargar automaticamente cuando llegue un evento SSE de dataset.
 */
export default function Dashboard() {
  const [charts, setCharts] = useState(null);
  const [dataset, setDataset] = useState(null);
  const [error, setError] = useState(null);
  const [cargando, setCargando] = useState(false);

  const cargar = useCallback(async () => {
    setCargando(true);
    setError(null);
    try {
      const data = await apiGet('/api/dashboard/charts');
      setCharts(data);
      const resumen = await apiGet('/api/dashboard/dataset').catch(() => null);
      setDataset(resumen);
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }, []);
  // Cargar al montar y recargar automaticamente con SSE
  useEffect(() => {
    cargar();
  }, [cargar]);

  useSse('dataset:update', useCallback(() => cargar(), [cargar]));
  useSse('bitacora:update', useCallback(() => cargar(), [cargar]));

  if (error) {
    return (
      <div className="estado-error">
        <h2>No se pudo cargar el dashboard</h2>
        <p>{error}</p>
        <p className="hint">
          ¿Está R corriendo? Inícialo con: <code>rscript r/plumber_api.R</code>
        </p>
        <button className="btn" onClick={cargar}>
          Reintentar
        </button>
      </div>
    );
  }

  if (cargando && !charts) {
    return <p className="placeholder">Cargando dashboard…</p>;
  }

  return (
    <div>
      <div className="toolbar">
        <h2>Dashboard</h2>
        {dataset && (
          <span className="meta">
            {dataset.filas ?? '?'} filas · {dataset.columnas ?? '?'} columnas
          </span>
        )}
        <button
          className="btn"
          disabled={cargando}
          onClick={async () => {
            try {
              await apiPost('/api/dashboard/preprocesar', {});
              cargar();
            } catch (err) {
              setError(err.message);
            }
          }}
        >
          {cargando ? 'Procesando…' : 'Ejecutar preprocesamiento'}
        </button>
      </div>

      <div className="grid-graficos">
        {Array.isArray(charts?.data) && charts.data.length > 0 ? (
          charts.data.map((def, i) => <Chart key={def.titulo ?? i} def={def} />)
        ) : charts?.option ?? charts?.titulo ? (
          // Si R devuelve un solo grafico, envolverlo
          <Chart def={charts} />
        ) : (
          <p className="placeholder">
            Plumber está conectado pero no entregó gráficos todavía.
          </p>
        )}
      </div>
    </div>
  );
}
