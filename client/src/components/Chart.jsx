/**
 * Renderiza un grafico ECharts a partir de la definicion JSON
 * generada en R (en este proyecto, desde r/graficos.R).
 */
import React, { useEffect, useRef, useCallback } from 'react';
import * as echarts from 'echarts';

export default function Chart({ def }) {
  const ref = useRef(null);
  const chartRef = useRef(null);

  const build = useCallback(() => {
    if (!ref.current || !def?.option) return;
    if (!chartRef.current) {
      chartRef.current = echarts.init(ref.current);
    }
    chartRef.current.setOption(
      { backgroundColor: 'transparent', tooltip: {}, ...def.option },
      true
    );
  }, [def]);

  useEffect(() => {
    build();
    const onResize = () => chartRef.current?.resize();
    window.addEventListener('resize', onResize);
    return () => {
      window.removeEventListener('resize', onResize);
      chartRef.current?.dispose();
      chartRef.current = null;
    };
  }, [build]);

  useEffect(() => build(), [def]);

  return (
    <div className="card">
      <h3 className="card-titulo">{def?.option?.title?.text ?? def?.titulo ?? ''}</h3>
      {def?.option ? (
        <div ref={ref} className="chart" />
      ) : (
        <p className="placeholder">Sin gráfico definido</p>
      )}
    </div>
  );
}
