/**
 * Router simple basado en hash: #/dashboard | #/pasos | #/salida | #/bitacoras
 * La entrada "Dashboard" de la barra lateral despliega además el árbol de
 * carpetas y gráficos, para dejar todo el ancho libre al lienzo.
 */
import { useEffect, useState } from 'react';
import Dashboard from './views/Dashboard.jsx';
import Pasos from './views/Pasos.jsx';
import Salida from './views/Salida.jsx';
import Bitacoras from './views/Bitacoras.jsx';
import LiveBadge from './LiveBadge.jsx';
import { DashboardProvider, useDashboard } from './dashboardStore.jsx';

const VISTAS = {
  dashboard: Dashboard,
  pasos: Pasos,
  salida: Salida,
  bitacoras: Bitacoras,
};

const NAVEGACION = [
  { id: 'dashboard', etiqueta: 'Dashboard', descripcion: 'Gráficos del análisis' },
  { id: 'pasos', etiqueta: 'Pasos', descripcion: 'Ejecutar el proceso' },
  { id: 'salida', etiqueta: 'Salida', descripcion: 'Archivos generados' },
  { id: 'bitacoras', etiqueta: 'Bitácora', descripcion: 'Registros del proceso' },
];

function obtenerRutaActual() {
  const hash = window.location.hash.replace(/^#\/?/, '') || 'dashboard';
  return VISTAS[hash] ? hash : 'dashboard';
}

export default function App() {
  return (
    <DashboardProvider>
      <Shell />
    </DashboardProvider>
  );
}

function Shell() {
  const [ruta, setRuta] = useState(obtenerRutaActual);
  const [menuAbierto, setMenuAbierto] = useState(false);
  const [carpetasAbiertas, setCarpetasAbiertas] = useState(() => new Set());
  const { carpetas, carpetasActivas, graficosOcultos, toggleCarpeta, alternarGrafico, eliminarCarpeta, eliminarGrafico } =
    useDashboard();

  useEffect(() => {
    const onChange = () => setRuta(obtenerRutaActual());
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);

  // Al salir del dashboard, el árbol se recoge
  useEffect(() => {
    if (ruta !== 'dashboard') setMenuAbierto(false);
  }, [ruta]);

  const alternarMenu = () => {
    setMenuAbierto((abierto) => (ruta === 'dashboard' ? !abierto : true));
  };

  const alternarCarpetaAbierta = (nombre) => {
    setCarpetasAbiertas((prev) => {
      const siguiente = new Set(prev);
      if (siguiente.has(nombre)) siguiente.delete(nombre);
      else siguiente.add(nombre);
      return siguiente;
    });
  };

  const activarCarpeta = (nombre) => {
    const seActiva = !carpetasActivas.has(nombre);
    toggleCarpeta(nombre);
    if (seActiva) {
      setCarpetasAbiertas((prev) =>
        prev.has(nombre) ? prev : new Set(prev).add(nombre)
      );
    }
  };

  const nombresCarpetas = Object.keys(carpetas);
  const Vista = VISTAS[ruta];

  return (
    <div className="app">
      <header className="topbar">
        <span className="brand">Análisis de Sentimientos</span>
        <LiveBadge />
      </header>

      <div className="shell">
        <nav className="nav" aria-label="Secciones">
          {NAVEGACION.map((vista) =>
            vista.id === 'dashboard' ? (
              <div key={vista.id} className="nav-grupo">
                <a
                  href="#/dashboard"
                  className={ruta === vista.id ? 'activo' : ''}
                  aria-current={ruta === vista.id ? 'page' : undefined}
                  aria-expanded={menuAbierto}
                  aria-controls="nav-carpetas-dashboard"
                  onClick={alternarMenu}
                >
                  <span className="nav-titulo">{vista.etiqueta}</span>
                  <span className="nav-desc">{vista.descripcion}</span>
                  <span
                    className={`nav-flecha${menuAbierto ? ' abierta' : ''}`}
                    aria-hidden="true"
                  >
                    ▸
                  </span>
                </a>

                {menuAbierto && (
                  <div className="nav-carpetas" id="nav-carpetas-dashboard">
                    {nombresCarpetas.length === 0 && (
                      <p className="nav-carpetas-vacio">
                        Aún no hay carpetas. Aparecerán aquí cuando el análisis
                        genere gráficos.
                      </p>
                    )}

                    {nombresCarpetas.map((nombre) => {
                      const lista = carpetas[nombre] ?? [];
                      const ocultos = graficosOcultos[nombre] ?? new Set();
                      const abierta = carpetasAbiertas.has(nombre);
                      const activa = carpetasActivas.has(nombre);
                      return (
                        <div
                          key={nombre}
                          className={`nav-carpeta${activa ? ' activa' : ''}`}
                        >
                          <div className="nav-carpeta-fila">
                            <button
                              type="button"
                              className="nav-carpeta-expandir"
                              onClick={() => alternarCarpetaAbierta(nombre)}
                              aria-expanded={abierta}
                              title={nombre}
                            >
                              <span
                                className={`nav-chevron${abierta ? ' abierta' : ''}`}
                                aria-hidden="true"
                              >
                                ▸
                              </span>
                              <span className="nav-carpeta-nombre">{nombre}</span>
                              <span className="nav-carpeta-cuenta">
                                {lista.length}
                              </span>
                            </button>

                            <label
                              className="toggle toggle-mini"
                              title={
                                activa
                                  ? 'Ocultar carpeta del lienzo'
                                  : 'Mostrar carpeta en el lienzo'
                              }
                            >
                              <input
                                type="checkbox"
                                checked={activa}
                                onChange={() => activarCarpeta(nombre)}
                                aria-label={`Mostrar ${nombre} en el lienzo`}
                              />
                              <span className="toggle-pista">
                                <span className="toggle-nudo" />
                              </span>
                            </label>

                            <button
                              type="button"
                              className="nav-eliminar-carpeta"
                              onClick={(e) => {
                                e.stopPropagation();
                                if (window.confirm(`¿Eliminar la carpeta '${nombre}' y todos sus gráficos?`)) {
                                  eliminarCarpeta(nombre).catch(() => {});
                                }
                              }}
                              aria-label={`Eliminar carpeta ${nombre}`}
                              title="Eliminar carpeta"
                            >
                              🗑️
                            </button>
                          </div>

                          {abierta && (
                            <div className="nav-graficos">
                              {lista.map((img) => (
                                <label
                                  key={img.nombre}
                                  className="nav-grafico"
                                  title={img.nombre}
                                >
                                  <input
                                    type="checkbox"
                                    checked={!ocultos.has(img.nombre)}
                                    onChange={(e) =>
                                      alternarGrafico(
                                        nombre,
                                        img.nombre,
                                        e.target.checked
                                      )
                                    }
                                  />
                                  <span>{img.nombre}</span>
                                  <button
                                    type="button"
                                    className="nav-eliminar-grafico"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      if (window.confirm(`¿Eliminar el gráfico '${img.nombre}'?`)) {
                                        eliminarGrafico(nombre, img.nombre).catch(() => {});
                                      }
                                    }}
                                    aria-label={`Eliminar ${img.nombre}`}
                                    title="Eliminar gráfico"
                                  >
                                    🗑️
                                  </button>
                                </label>
                              ))}
                              {lista.length === 0 && (
                                <p className="nav-carpetas-vacio">Sin gráficos.</p>
                              )}
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            ) : (
              <a
                key={vista.id}
                href={`#/${vista.id}`}
                className={ruta === vista.id ? 'activo' : ''}
                aria-current={ruta === vista.id ? 'page' : undefined}
              >
                <span className="nav-titulo">{vista.etiqueta}</span>
                <span className="nav-desc">{vista.descripcion}</span>
              </a>
            )
          )}
        </nav>

        <main className="contenido">
          <Vista />
        </main>
      </div>
    </div>
  );
}
