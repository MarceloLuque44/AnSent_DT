/**
 * Fase 1: despliegue en Render + Postgres + /api/cambios.
 * Las vistas antiguas (Plumber, SQLite, SSE) quedan en el repositorio,
 * pero no se montan hasta las siguientes fases.
 */
import Cambios from './views/Cambios.jsx';

export default function App() {
  return (
    <div className="app">
      <header className="topbar">
        <span className="brand">Análisis de Sentimientos</span>
        <span className="page-chip">Fase 1 · Render</span>
      </header>

      <div className="shell">
        <nav className="nav" aria-label="Secciones">
          <a href="#/cambios" className="activo" aria-current="page">
            <span className="nav-titulo">Cambios</span>
            <span className="nav-desc">Registros desde R</span>
          </a>
        </nav>

        <main className="contenido">
          <Cambios />
        </main>
      </div>
    </div>
  );
}
