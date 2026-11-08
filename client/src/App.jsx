/**
 * Fase 1: Render + Postgres + /api/cambios.
 * Solo se montan las vistas conectadas al nuevo backend.
 */
import { useEffect, useState } from 'react';
import Cambios from './views/Cambios.jsx';
import Bitacoras from './views/Bitacoras.jsx';

const VISTAS = {
  cambios: Cambios,
  bitacoras: Bitacoras,
};

const NAVEGACION = [
  { id: 'cambios', etiqueta: 'Cambios', descripcion: 'Registros desde R' },
  { id: 'bitacoras', etiqueta: 'Bitácora', descripcion: 'Historial de cambios' },
];

function obtenerRutaActual() {
  const hash = window.location.hash.replace(/^#\/?/, '') || 'cambios';
  return VISTAS[hash] ? hash : 'cambios';
}

export default function App() {
  const [ruta, setRuta] = useState(obtenerRutaActual);

  useEffect(() => {
    const onChange = () => setRuta(obtenerRutaActual());
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);

  const Vista = VISTAS[ruta];

  return (
    <div className="app">
      <header className="topbar">
        <span className="brand">Análisis de Sentimientos</span>
        <span className="page-chip">Fase 1 · Render</span>
      </header>

      <div className="shell">
        <nav className="nav" aria-label="Secciones">
          {NAVEGACION.map((vista) => (
            <a
              key={vista.id}
              href={`#/${vista.id}`}
              className={ruta === vista.id ? 'activo' : ''}
              aria-current={ruta === vista.id ? 'page' : undefined}
            >
              <span className="nav-titulo">{vista.etiqueta}</span>
              <span className="nav-desc">{vista.descripcion}</span>
            </a>
          ))}
        </nav>

        <main className="contenido">
          <Vista />
        </main>
      </div>
    </div>
  );
}
