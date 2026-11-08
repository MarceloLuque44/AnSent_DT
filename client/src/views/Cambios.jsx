import { useCallback, useEffect, useState } from 'react';
import { apiGet } from '../api.js';

const texto = (v) => (v == null || v === '' ? '—' : String(v));

/**
 * Fase 1: lista los registros de public.cambios.
 * Sin polling ni SSE: solo carga inicial y botón "Actualizar".
 */
export default function Cambios() {
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
          <h1 className="page-title">Cambios</h1>
          <p className="page-desc">
            Registros enviados desde R a Render. Se actualiza solo con el botón.
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

      {filas.length > 0 && (
        <div className="tabla-scroll">
          <table className="tabla">
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Hora</th>
                <th>Tipo</th>
                <th>Archivo</th>
                <th>Problema</th>
                <th>Cambio</th>
                <th>Justificación</th>
                <th>Responsable</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              {filas.map((c) => (
                <tr key={c.id}>
                  <td>{texto(c.fecha)}</td>
                  <td>{texto(c.hora)}</td>
                  <td>
                    <span className="tag">{texto(c.tipo)}</span>
                  </td>
                  <td>{texto(c.archivo)}</td>
                  <td title={texto(c.problema_detectado)}>
                    {texto(c.problema_detectado)}
                  </td>
                  <td title={texto(c.cambio_realizado)}>
                    {texto(c.cambio_realizado)}
                  </td>
                  <td title={texto(c.justificacion)}>{texto(c.justificacion)}</td>
                  <td>{texto(c.responsable)}</td>
                  <td>
                    <span className="tag">{texto(c.estado_registro)}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
