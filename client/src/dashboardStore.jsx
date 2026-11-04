import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { apiGet } from './api';
import { useSse } from './sse';

/** Construye la URL de una imagen servida por Express. */
const urlImagen = (carpeta, nombre) =>
  `/salida-cliente/analisis/${encodeURIComponent(carpeta)}/${encodeURIComponent(nombre)}`;

const DashboardContext = createContext(null);

/**
 * Estado compartido del dashboard: carpetas disponibles, carpetas visibles
 * en el lienzo y gráficos ocultos de cada carpeta. Lo consumen la barra
 * lateral (árbol de carpetas) y la vista Dashboard (lienzo de gráficos).
 */
export function DashboardProvider({ children }) {
  const [carpetas, setCarpetas] = useState({});
  const [carpetasActivas, setCarpetasActivas] = useState(new Set());
  /** Por carpeta: Set de graficos descheckeados (ausente = todos visibles) */
  const [graficosOcultos, setGraficosOcultos] = useState({});

  const cargarCarpetas = useCallback(async () => {
    try {
      const { carpetas: lista } = await apiGet('/api/dashboard/carpetas-imagenes');
      if (!Array.isArray(lista)) return;
      setCarpetas(() => {
        const siguiente = {};
        for (const c of lista) {
          siguiente[c.carpeta] = c.imagenes.map((nombre) => ({
            nombre,
            ruta: urlImagen(c.carpeta, nombre),
          }));
        }
        // Se reemplaza la lista completa: si una carpeta se elimino en disco,
        // debe desaparecer tambien del menu y del lienzo.
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

  const toggleCarpeta = useCallback((nombre) => {
    setCarpetasActivas((prev) => {
      const siguiente = new Set(prev);
      if (siguiente.has(nombre)) siguiente.delete(nombre);
      else siguiente.add(nombre);
      return siguiente;
    });
  }, []);

  /** Check / uncheck de un grafico concreto dentro de una carpeta */
  const alternarGrafico = useCallback((carpeta, grafico, visible) => {
    setGraficosOcultos((prev) => {
      const actuales = new Set(prev[carpeta] ?? []);
      if (visible) actuales.delete(grafico);
      else actuales.add(grafico);
      return { ...prev, [carpeta]: actuales };
    });
  }, []);

  /** Elimina una carpeta completa de imagenes del dashboard */
  const eliminarCarpeta = useCallback(async (nombre) => {
    try {
      const res = await fetch(`/api/dashboard/carpetas/${encodeURIComponent(nombre)}`, {
        method: 'DELETE',
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || `Error ${res.status}`);
      }
      await cargarCarpetas();
      setCarpetasActivas((prev) => {
        const siguiente = new Set(prev);
        siguiente.delete(nombre);
        return siguiente;
      });
      setGraficosOcultos((prev) => {
        const siguiente = { ...prev };
        delete siguiente[nombre];
        return siguiente;
      });
    } catch (err) {
      console.error('[Dashboard] Error eliminando carpeta:', err.message);
      throw err;
    }
  }, [cargarCarpetas]);

  /** Elimina una imagen individual de una carpeta del dashboard */
  const eliminarGrafico = useCallback(async (carpeta, nombre) => {
    try {
      const res = await fetch(
        `/api/dashboard/carpetas/${encodeURIComponent(carpeta)}/imagenes/${encodeURIComponent(nombre)}`,
        { method: 'DELETE' },
      );
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || `Error ${res.status}`);
      }
      await cargarCarpetas();
    } catch (err) {
      console.error('[Dashboard] Error eliminando imagen:', err.message);
      throw err;
    }
  }, [cargarCarpetas]);

  const valor = {
    carpetas,
    carpetasActivas,
    graficosOcultos,
    cargarCarpetas,
    toggleCarpeta,
    alternarGrafico,
    eliminarCarpeta,
    eliminarGrafico,
  };

  return (
    <DashboardContext.Provider value={valor}>
      {children}
    </DashboardContext.Provider>
  );
}

export function useDashboard() {
  const contexto = useContext(DashboardContext);
  if (!contexto) {
    throw new Error('useDashboard debe usarse dentro de DashboardProvider');
  }
  return contexto;
}
