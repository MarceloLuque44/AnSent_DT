import { useEffect, useRef, useState } from 'react';
import * as echarts from 'echarts';
import { useDashboard } from '../dashboardStore.jsx';

/**
 * Dashboard: lienzo de graficos (PNG) agrupados por carpeta.
 * - Las carpetas y sus graficos se activan desde el arbol del menu
 *   "Dashboard" en la barra lateral (dashboardStore).
 * - Cada carpeta activa genera una columna; con una sola columna las
 *   imagenes se muestran dos por fila y con varias, a ancho completo.
 * - El lienzo ocupa todo el ancho disponible.
 */
export default function Dashboard() {
  const [imagenAmpliada, setImagenAmpliada] = useState(null);
  const { carpetas, carpetasActivas, graficosOcultos } = useDashboard();
  const polarRef = useRef(null);
  const polarChart = useRef(null);

  // Inicializar el grafico polar
  useEffect(() => {
    if (!polarRef.current) return;
    polarChart.current = echarts.init(polarRef.current);
    return () => {
      polarChart.current?.dispose();
      polarChart.current = null;
    };
  }, []);

  useEffect(() => {
    if (!polarChart.current) return;
    const COLORES_EMOCION = {
      'Alegría': '#4f9df7',
      'Enojo': '#2f64c8',
      'Tristeza': '#6c8fe0',
      'Miedo': '#8a86e6',
      'Sorpresa': '#35b6d9',
      'Repugnancia': '#5fa6bd',
      'Neutral': '#9bb4cf',
    };
    const emociones = ['Alegría', 'Enojo', 'Tristeza', 'Miedo', 'Sorpresa', 'Repugnancia', 'Neutral'];
    const valores = [35, 12, 18, 8, 10, 5, 45];
    const option = {
      backgroundColor: 'transparent',
      tooltip: { trigger: 'item' },
      polar: {
        center: ['50%', '52%'],
        radius: [0, '68%'],
      },
      angleAxis: {
        type: 'category',
        data: emociones,
        axisLabel: {
          fontFamily: 'Public Sans, sans-serif',
          formatter: (valor) => `{${valor
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')}|${valor}}`,
          rich: {
            alegria: { color: '#4f9df7' },
            enojo: { color: '#2f64c8' },
            tristeza: { color: '#6c8fe0' },
            miedo: { color: '#8a86e6' },
            sorpresa: { color: '#35b6d9' },
            repugnancia: { color: '#5fa6bd' },
            neutral: { color: '#7f96b3' },
          },
        },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
      },
      radiusAxis: {
        type: 'value',
        max: 100,
        axisLabel: { color: '#5a7392' },
        axisLine: { lineStyle: { color: '#d8e6f7' } },
        splitLine: { lineStyle: { color: '#e7f0fb' } },
      },
      series: [
        {
          type: 'bar',
          data: valores.map((v, i) => ({
            value: v,
            itemStyle: { color: COLORES_EMOCION[emociones[i]] ?? '#2563eb' },
          })),
          coordinateSystem: 'polar',
          roundCap: true,
          itemStyle: {
            borderRadius: [0, 0, 4, 4],
          },
        },
      ],
    };
    polarChart.current.setOption(option, true);
  }, []);

  useEffect(() => {
    const alRedimensionar = () => polarChart.current?.resize();
    window.addEventListener('resize', alRedimensionar);
    return () => window.removeEventListener('resize', alRedimensionar);
  }, []);

  // Resize al cambiar el numero de columnas
  useEffect(() => {
    const id = setTimeout(() => polarChart.current?.resize(), 60);
    return () => clearTimeout(id);
  }, [carpetasActivas.size]);

  const nombresCarpetas = Object.keys(carpetas);
  const totalGraficos = Object.values(carpetas).reduce(
    (n, imgs) => n + imgs.length,
    0
  );
  // Una sola columna: imagenes dos por fila; mas de una: imagen a 100% del ancho
  const modoInterno = carpetasActivas.size === 1 ? 'doble' : 'sencilla';

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Dashboard</h1>
          <p className="page-desc">
            Gráficos de salida del análisis. Abre el menú Dashboard de la
            navegación para activar carpetas y elegir sus gráficos.
          </p>
        </div>
        <span className="page-chip">
          {nombresCarpetas.length}{' '}
          {nombresCarpetas.length === 1 ? 'carpeta' : 'carpetas'} · {totalGraficos}{' '}
          {totalGraficos === 1 ? 'gráfico' : 'gráficos'}
        </span>
      </header>

      <section className="lienzo" aria-label="Gráficos seleccionados">
        {carpetasActivas.size > 0 ? (
          <div
            className="columnas-carpetas"
            style={{
              gridTemplateColumns: `repeat(${carpetasActivas.size}, minmax(0, 1fr))`,
            }}
          >
            {[...carpetasActivas].map((nombre) => (
              <div key={nombre} className="columna-imagenes">
                <div className="titulo-columna">{nombre}</div>
                <div className={`imagenes-interno ${modoInterno}`}>
                  {(carpetas[nombre] ?? [])
                    .filter(
                      (img) =>
                        !(graficosOcultos[nombre] ?? new Set()).has(img.nombre)
                    )
                    .map((img) => (
                      <figure
                        key={img.nombre}
                        className="tarjeta-imagen"
                        onClick={() =>
                          setImagenAmpliada({
                            nombre: img.nombre,
                            carpeta: nombre,
                            ruta: img.ruta,
                          })
                        }
                      >
                        <img
                          src={img.ruta}
                          alt={img.nombre}
                          loading="lazy"
                          className="imagen-llena"
                        />
                        <figcaption>{img.nombre}</figcaption>
                      </figure>
                    ))}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="lienzo-vacio">
            <p className="lienzo-vacio-titulo">Sin gráficos en pantalla</p>
            <p className="lienzo-vacio-texto">
              {nombresCarpetas.length > 0
                ? 'Abre el menú Dashboard y activa una carpeta con su interruptor para ver sus gráficos aquí.'
                : 'Cuando el análisis genere gráficos, aparecerán en el menú Dashboard.'}
            </p>
          </div>
        )}

      </section>

      {imagenAmpliada && (
        <div className="overlay-imagen" onClick={() => setImagenAmpliada(null)}>
          <div className="overlay-contenido">
            <button
              type="button"
              className="overlay-cerrar"
              onClick={() => setImagenAmpliada(null)}
            >
              Cerrar
            </button>
            <img src={imagenAmpliada.ruta} alt={imagenAmpliada.nombre} />
          </div>
        </div>
      )}
    </div>
  );
}
