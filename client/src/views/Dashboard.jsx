import { useState, useRef, useEffect, useCallback } from 'react';
import * as echarts from 'echarts';
import { apiGet } from '../api';
import { useSse } from '../sse';

/** Construye la URL de una imagen servida por Express. */
const urlImagen = (carpeta, nombre) =>
  `/salida-cliente/analisis/${encodeURIComponent(carpeta)}/${encodeURIComponent(nombre)}`;

/**
 * Dashboard: muestra las imagenes de los graficos (PNG) agrupados por carpeta.
 * - Los botones flotantes se generan con las carpetas que existen en
 *   client/src/views/salida/analisis y se actualizan en tiempo real (SSE + poll).
 * - Cada carpeta seleccionada genera una columna; las columnas se reparten
 *   el ancho equitativamente.
 * - Con una sola columna, las imagenes se muestran dos por fila.
 * - Con mas de una columna, cada imagen ocupa el 100% del ancho de su columna.
 */
export default function Dashboard() {
  const [imagenAmpliada, setImagenAmpliada] = useState(null);
  const [carpetas, setCarpetas] = useState({});
  const [carpetasActivas, setCarpetasActivas] = useState(new Set());
  /** Por carpeta: Set de graficos descheckeados (ausente = todos visibles) */
  const [graficosOcultos, setGraficosOcultos] = useState({});
  const polarRef = useRef(null);
  const polarChart = useRef(null);

  const cargarCarpetas = useCallback(async () => {
    try {
      const { carpetas: lista } = await apiGet(
        '/api/dashboard/carpetas-imagenes'
      );
      if (!Array.isArray(lista)) return;
      setCarpetas((prev) => {
        const siguiente = {};
        for (const c of lista) {
          siguiente[c.carpeta] = c.imagenes.map((nombre) => ({
            nombre,
            ruta: urlImagen(c.carpeta, nombre),
          }));
        }
        // Conservar carpetas cargadas anteriormente que ya no existen,
        // para que las columnas activas no desaparezcan de golpe.
        for (const nombre of Object.keys(prev)) {
          if (!(nombre in siguiente)) siguiente[nombre] = prev[nombre];
        }
        return siguiente;
      });
      // Quitar del estado activo las carpetas que ya no existen
      setCarpetasActivas((prev) => {
        const nombres = new Set(lista.map((c) => c.carpeta));
        const siguiente = new Set([...prev].filter((n) => nombres.has(n)));
        return siguiente.size === prev.size ? prev : siguiente;
      });
    } catch {
      // Sin servidor disponible: se reintenta en el siguiente evento/poll
    }
  }, []);

  // Carga inicial y refresco periodico (fallback del SSE)
  useEffect(() => {
    cargarCarpetas();
    const interval = setInterval(cargarCarpetas, 30000);
    return () => clearInterval(interval);
  }, [cargarCarpetas]);

  // Actualizacion en tiempo real: el servidor notifica cambios en la carpeta
  useSse('dashboard-imagenes', cargarCarpetas);

  // Si las carpetas activas dejan de existir, limpiar
  useEffect(() => {
    for (const nombre of carpetasActivas) {
      if (!carpetas[nombre]) {
        setCarpetasActivas((prev) => {
          const siguiente = new Set(prev);
          siguiente.delete(nombre);
          return siguiente;
        });
      }
    }
  }, [carpetas, carpetasActivas]);

  const toggleCarpeta = (nombre) => {
    setCarpetasActivas((prev) => {
      const siguiente = new Set(prev);
      if (siguiente.has(nombre)) siguiente.delete(nombre);
      else siguiente.add(nombre);
      return siguiente;
    });
  };

  const estaActivo = (nombre) => carpetasActivas.has(nombre);

  /** Check / uncheck de un grafico concreto dentro de una carpeta */
  const alternarGrafico = (carpeta, grafico, visible) => {
    setGraficosOcultos((prev) => {
      const actuales = new Set(prev[carpeta] ?? []);
      if (visible) actuales.delete(grafico);
      else actuales.add(grafico);
      return { ...prev, [carpeta]: actuales };
    });
  };

  // Inicializar el grafico polar
  useEffect(() => {
    if (!polarRef.current) return;
    polarChart.current = echarts.init(polarRef.current);
    return () => {
      polarChart.current?.dispose();
      polarChart.current = null;
    };
  }, []);

  const dibujarPolar = () => {
    if (!polarChart.current) return;
    const option = {
      backgroundColor: 'transparent',
      tooltip: { trigger: 'item' },
      legend: {
        orient: 'vertical',
        left: 'left',
        top: 'middle',
        textStyle: { color: '#e5e9f2' },
      },
      polar: {
        center: ['55%', '55%'],
        radius: [0, '60%'],
      },
      angleAxis: {
        type: 'category',
        data: ['Alegría', 'Enojo', 'Tristeza', 'Miedo', 'Sorpresa', 'Repugnancia', 'Neutral'],
        axisLabel: { color: '#93a0b8' },
        axisLine: { lineStyle: { color: '#26304a' } },
      },
      radiusAxis: {
        type: 'value',
        max: 100,
        axisLabel: { color: '#93a0b8' },
        axisLine: { lineStyle: { color: '#26304a' } },
      },
      series: [
        {
          type: 'bar',
          data: [35, 12, 18, 8, 10, 5, 45],
          coordinateSystem: 'polar',
          roundCap: true,
          itemStyle: {
            color: '#4f8cff',
            borderRadius: [0, 0, 4, 4],
          },
        },
      ],
    };
    polarChart.current.setOption(option, true);
  };

  useEffect(() => {
    dibujarPolar();
  }, []);

  useEffect(() => {
    if (!polarRef.current || !polarChart.current) return;
    polarChart.current.resize();
  }, []);

  // Carpetas existentes para los botones flotantes
  const nombresCarpetas = Object.keys(carpetas);

  // Una sola columna: imagenes dos por fila; mas de una: imagen a 100% del ancho
  const modoInterno = carpetasActivas.size === 1 ? 'doble' : 'sencilla';

  return (
    <div>
      <div className="toolbar">
        <h2>Dashboard</h2>
        <span className="meta">
          Graficos de salida — {nombresCarpetas.length}{' '}
          {nombresCarpetas.length === 1 ? 'carpeta' : 'carpetas'} disponibles
        </span>
      </div>

      <div className="toolbar-toggle">
        {nombresCarpetas.map((nombre) => {
          const ocultos = graficosOcultos[nombre] ?? new Set();
          return (
            <div key={nombre} className="fila-carpeta">
              <button
                className={`btn-toggle ${estaActivo(nombre) ? 'activo' : ''}`}
                onClick={() => toggleCarpeta(nombre)}
              >
                <span className="btn-toggle-indicador">
                  {carpetas[nombre]?.length ?? 0}
                </span>
                {nombre}
              </button>
              {/* Checks por grafico (todos checkeados por defecto) */}
              <div className="checks-carpeta">
                {(carpetas[nombre] ?? []).map((img) => (
                  <label key={img.nombre} className="check-grafico">
                    <input
                      type="checkbox"
                      checked={!ocultos.has(img.nombre)}
                      onChange={(e) =>
                        alternarGrafico(nombre, img.nombre, e.target.checked)
                      }
                    />
                    <span>{img.nombre}</span>
                  </label>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      {carpetasActivas.size > 0 && (
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
                  .filter((img) => !(graficosOcultos[nombre] ?? new Set()).has(img.nombre))
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
                    style={{ cursor: 'pointer' }}
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
      )}

      <section className="seccion-carpeta">
        <h3 className="titulo-carpeta">Rosa de los sentimientos (Polar)</h3>
        <div ref={polarRef} className="chart-polar" />
      </section>

      {imagenAmpliada && (
        <div
          className="overlay-imagen"
          onClick={() => setImagenAmpliada(null)}
        >
          <div className="overlay-contenido">
            <img src={imagenAmpliada.ruta} alt={imagenAmpliada.nombre} />
            <div className="overlay-cerrar">Cerrar (X)</div>
          </div>
        </div>
      )}
    </div>
  );
}
