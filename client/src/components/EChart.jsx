import { useEffect, useRef } from 'react';
import * as echarts from 'echarts';

/**
 * Envoltura mínima de ECharts: inicializa el gráfico, aplica la opción y
 * se adapta al tamaño del contenedor. Todas las vistas deben usarla en vez
 * de instanciar `echarts.init` por su cuenta.
 */
export default function EChart({ option, height = 420, className = '' }) {
  const contenedor = useRef(null);
  const grafico = useRef(null);

  useEffect(() => {
    if (!contenedor.current) return undefined;

    grafico.current = echarts.init(contenedor.current);
    const alRedimensionar = () => grafico.current?.resize();
    window.addEventListener('resize', alRedimensionar);

    const observador = new ResizeObserver(alRedimensionar);
    observador.observe(contenedor.current);

    return () => {
      window.removeEventListener('resize', alRedimensionar);
      observador.disconnect();
      grafico.current?.dispose();
      grafico.current = null;
    };
  }, []);

  useEffect(() => {
    grafico.current?.setOption(option ?? {}, true);
  }, [option]);

  return (
    <div
      ref={contenedor}
      className={className}
      style={{ width: '100%', height }}
    />
  );
}
