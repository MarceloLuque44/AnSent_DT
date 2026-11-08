import { useCallback, useEffect, useState } from 'react';
import { apiGet } from '../api.js';
import TablaCambios from '../components/TablaCambios.jsx';

/**
 * Fase 1: la bitácora se alimenta del nuevo backend (/api/cambios).
 * Los archivos XLSX/JSON que antes exponía Plumber quedan para la Fase 2.
 * Sin polling ni SSE: solo carga inicial y botón "Actualizar".
 */
export default function Bitacoras() {
  const [filas, setFilas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);
  const [actualizado, setActualizado] = useState(null);

  const cargar = useCallback(async () => {
    setCargando(true);
    setError(null);
    try {
      const resp = await apiGet('/api/cambios?limit=100');
      setFilas(resp.data ?? []);
      setActualizado(new Date());
    } catch (err) {
      setError(err.message);
      setFilas([]);
    } finally {
      setCargando(false);
    }
  }, []);

  useEffect(() => {
    cargar();
  }, [cargar]);

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Bitácora</h1>
          <p className="page-desc">
            Historial de cambios registrado en Supabase. Los archivos XLSX/JSON
            se habilitarán en la Fase 2.
          </p>
        </div>
        <button type="button" className="btn" onClick={cargar} disabled={cargando}>
          {cargando ? 'Actualizando…' : 'Actualizar'}
        </button>
      </header>

      {error && <div className="estado-error">{error}</div>}

      {actualizado && !error && (
        <p className="page-desc">
          Última actualización: {actualizado.toLocaleString()}
        </p>
      )}

      {!error && !cargando && filas.length === 0 && (
        <p className="placeholder">No hay cambios registrados todavía.</p>
      )}

      {filas.length > 0 && <TablaCambios filas={filas} />}
    </div>
  );
}
