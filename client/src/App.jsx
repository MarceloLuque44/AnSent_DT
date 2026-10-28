/**
 * Router simple basado en hash: #/dashboard | #/pasos | #/bitacora
 */
import { useEffect, useState } from 'react';
import Dashboard from './views/Dashboard.jsx';
import Bitacora from './views/Bitacora.jsx';
import Pasos from './views/Pasos.jsx';
import Salida from './views/Salida.jsx';
import Bitacoras from './views/Bitacoras.jsx';
import LiveBadge from './LiveBadge.jsx';

const VISTAS = {
  dashboard: Dashboard,
  pasos: Pasos,
  bitacora: Bitacora,
  salida: Salida,
  bitacoras: Bitacoras,
};

function obtenerRutaActual() {
  const hash = window.location.hash.replace(/^#\/?/, '') || 'dashboard';
  return VISTAS[hash] ? hash : 'dashboard';
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
        <nav className="nav">
          <span className="brand">📊 Análisis de Sentimientos</span>
          <a href="#/dashboard" className={ruta === 'dashboard' ? 'activo' : ''}>
            Dashboard
          </a>
          <a href="#/pasos" className={ruta === 'pasos' ? 'activo' : ''}>
            Pasos (API R)
          </a>
          <a href="#/bitacora" className={ruta === 'bitacora' ? 'activo' : ''}>
            Bitácora
          </a>
          <a href="#/salida" className={ruta === 'salida' ? 'activo' : ''}>
            Salida
          </a>
          <a href="#/bitacoras" className={ruta === 'bitacoras' ? 'activo' : ''}>
            Bitácoras (R)
          </a>
        </nav>
        <LiveBadge />
      </header>

      <main className="contenido">
        <Vista />
      </main>
    </div>
  );
}
