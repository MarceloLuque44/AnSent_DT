import { useEffect, useState, useCallback } from 'react';
import { apiGet } from '../api.js';
import { useSse } from '../sse.jsx';

const TIPOS = ['Todos', 'preprocesamiento', 'limpieza', 'ingesta', 'otro'];

/**
 * Bitacora: historial de cambios del dataset en IndexedDB-like SQLite (via Express).
 * Se actualiza automaticamente cuando R registra un cambio nuevo.
 */
export default function Bitacora() {
  const [registros, setRegistros] = useState([]);
  const [tipo, setTipo] = useState('Todos');
  const [error, setError] = useState(null);

  const cargar = useCallback(async (filtro = tipo) => {
    setError(null);
    try {
      const qs = filtro !== 'Todos' ? `?tipo=${encodeURIComponent(filtro)}` : '';
      setRegistros(await apiGet(`/api/bitacora${qs}`));
    } catch (err) {
      setError(err.message);
    }
  }, [tipo]);

  useEffect(() => {
    cargar();
  }, [tipo, cargar]);

  // Alta en vivo: cuando R inserta un registro nuevo
  useSse(
    'bitacora:update',
    useCallback(
      (nuevo) => {
        if (tipo === 'Todos' || nuevo?.tipo_cambio === tipo) {
          setRegistros((prev) => [nuevo, ...prev].slice(0, 200));
        }
      },
      [tipo]
    )
  );

  return (
    <div>
      <div className="toolbar">
        <h2>Bitácora de cambios del dataset</h2>
        <label className="filtro">
          Tipo:
          <select value={tipo} onChange={(e) => setTipo(e.target.value)}>
            {TIPOS.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </label>
        <button className="btn" onClick={() => cargar(tipo)}>
          Refrescar
        </button>
      </div>

      {error && <p className="estado-error">{error}</p>}
      {registros.length === 0 && !error && (
        <p className="placeholder">No hay registros de cambios todavía.</p>
      )}

      <table className="tabla">
        <thead>
          <tr>
            <th>Fecha</th>
            <th>Tipo</th>
            <th>Descripción</th>
            <th>Filas</th>
            <th>Versión</th>
            <th>Origen</th>
          </tr>
        </thead>
        <tbody>
          {registros.map((r) => (
            <tr key={r.id}>
              <td>{new Date(r.fecha).toLocaleString('es-ES')}</td>
              <td>
                <span className={`tag tag-${r.tipo_cambio}`}>{r.tipo_cambio}</span>
              </td>
              <td>{r.descripcion}</td>
              <td>{r.filas_afectadas ?? '—'}</td>
              <td>{r.version_dataset ?? '—'}</td>
              <td>{r.creado_por}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
