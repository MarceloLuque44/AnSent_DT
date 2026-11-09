import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  listarDiccionario,
  obtenerDiccionario,
  guardarDiccionario,
  actualizarDiccionario,
  eliminarDiccionario,
} from '../api.js';

const TIPOS = [
  { id: 'sentimientos', etiqueta: 'Sentimientos', descripcion: 'Diccionario propio de sentimientos' },
  { id: 'emojis', etiqueta: 'Emojis', descripcion: 'Emojis y su sentimiento asociado' },
  { id: 'stopwords', etiqueta: 'Stopwords', descripcion: 'Palabras vacias y accion aplicada' },
  { id: 'palabras_anuncio', etiqueta: 'Anuncios', descripcion: 'Patrones para detectar publicidad' },
  { id: 'genero', etiqueta: 'Genero', descripcion: 'Genero asignado a cada palabra' },
  { id: 'abreviaturas', etiqueta: 'Abreviaturas', descripcion: 'Abreviaturas de chat y forma normal' },
  { id: 'emoticonos', etiqueta: 'Emoticonos', descripcion: 'Emoticonos de texto y emoji equivalente' },
  { id: 'codigos_materia', etiqueta: 'Codigos materia', descripcion: 'Prefijos de materia' },
];

const TIPO_POR_ID = Object.fromEntries(TIPOS.map((t) => [t.id, t]));

const texto = (v) => (v == null || v === '' ? '—' : String(v));

const esArrayJson = (c) => c === 'palabras' || c === 'raices';

/** Vista Configuracion: CRUD de diccionarios via /api/diccionarios/:tipo. */
export default function Configuracion() {
  const [tipos, setTipos] = useState([]);
  const [tipoActivo, setTipoActivo] = useState('');
  const [filas, setFilas] = useState([]);
  const [columnas, setColumnas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);

  // Formulario crear/editar
  const [editando, setEditando] = useState(null); // { id, datos } | null
  const [datosForm, setDatosForm] = useState({});
  const [guardando, setGuardando] = useState(false);
  const [errorForm, setErrorForm] = useState(null);

  const cargarTipos = useCallback(async () => {
    try {
      const resp = await (async () => {
        const res = await fetch(`/api/diccionarios`);
        if (!res.ok) throw new Error(`Error ${res.status}`);
        return res.json();
      })();
      const lista = resp.tipos ?? [];
      setTipos(lista);
      if (!tipoActivo && lista.length) setTipoActivo(lista[0].tipo);
    } catch (err) {
      setError(`No se pudieron cargar los tipos de diccionario: ${err.message}`);
      setTipos([]);
    }
  }, [tipoActivo]);

  const cargarFilas = useCallback(async (tipo) => {
    setCargando(true);
    setError(null);
    setFilas([]);
    setColumnas([]);
    try {
      const resp = await listarDiccionario(tipo, { limit: 200, offset: 0 });
      const data = resp.data ?? [];
      setFilas(data);
      setColumnas(tipos.find((t) => t.tipo === tipo)?.columnas ?? []);
    } catch (err) {
      setError(`No se pudieron cargar las filas de ${tipo}: ${err.message}`);
      setFilas([]);
    } finally {
      setCargando(false);
    }
  }, [tipos]);

  useEffect(() => {
    cargarTipos();
  }, [cargarTipos]);

  useEffect(() => {
    if (tipoActivo) cargarFilas(tipoActivo);
  }, [cargarFilas, tipoActivo]);

  const tipoSeleccionado = TIPO_POR_ID[tipoActivo] ?? null;

  const iniciarNuevo = () => {
    setEditando(null);
    setDatosForm({});
    setErrorForm(null);
  };

  const iniciarEdicion = (fila) => {
    setEditando({ id: fila.id, datos: { ...fila } });
    setDatosForm({ ...fila });
    setErrorForm(null);
  };

  const manejarCambioForm = (clave, valor) => {
    setDatosForm((prev) => ({ ...prev, [clave]: valor }));
    setErrorForm(null);
  };

  const guardarForm = async (e) => {
    e.preventDefault();
    setGuardando(true);
    setErrorForm(null);
    try {
      const payload = { ...datosForm };
      // Las columnas jsonb se envían como arrays/objetos; las demás como strings.
      if (editando) {
        await actualizarDiccionario(tipoActivo, editando.id, payload);
        setEditando(null);
        setDatosForm({});
      } else {
        await guardarDiccionario(tipoActivo, payload);
        setDatosForm({});
      }
      await cargarFilas(tipoActivo);
    } catch (err) {
      setErrorForm(err.message);
    } finally {
      setGuardando(false);
    }
  };

  const eliminarFila = async (id) => {
    if (!window.confirm('¿Eliminar esta fila del diccionario?')) return;
    try {
      await eliminarDiccionario(tipoActivo, id);
      await cargarFilas(tipoActivo);
    } catch (err) {
      setError(`No se pudo eliminar la fila: ${err.message}`);
    }
  };

  const cancelarForm = () => {
    setEditando(null);
    setDatosForm({});
    setErrorForm(null);
  };

  const renderInput = (clave) => {
    const valor = datosForm[clave] == null ? '' : datosForm[clave];
    if (esArrayJson(clave)) {
      return (
        <textarea
          className="input textarea"
          key={clave}
          value={Array.isArray(valor) ? JSON.stringify(valor, null, 2) : String(valor ?? '')}
          onChange={(e) => {
            try {
              manejarCambioForm(clave, e.target.value ? JSON.parse(e.target.value) : []);
            } catch {
              manejarCambioForm(clave, e.target.value ? [e.target.value] : []);
            }
          }}
          rows="3"
          placeholder='ej: ["alegre", "feliz"]'
        />
      );
    }
    if (clave === 'activo') {
      return (
        <label className="campo-label checkbox-label">
          <input
            type="checkbox"
            checked={Boolean(valor)}
            onChange={(e) => manejarCambioForm(clave, e.target.checked)}
          />
          Activo
        </label>
      );
    }
    const tipoInput = clave === 'peso' || clave === 'orden' || clave === 'polaridad' ? 'number' : 'text';
    return (
      <input
        className="input"
        key={clave}
        type={tipoInput}
        value={String(valor ?? '')}
        onChange={(e) => manejarCambioForm(clave, e.target.value)}
        placeholder={clave}
      />
    );
  };

  const filasVacias = !cargando && !error && filas.length === 0;

  return (
    <div>
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Configuracion</h1>
          <p className="page-desc">
            CRUD de diccionarios de configuracion almacenados en PostgreSQL.
          </p>
        </div>
        <button type="button" className="btn" onClick={() => { setTipoActivo(tipos[0]?.tipo || ''); cargarTipos(); }} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Actualizar'}
        </button>
      </header>

      {error && <div className="estado-error">{error}</div>}

      {!tipoActivo && (
        <p className="placeholder">Selecciona un diccionario para gestionar sus filas.</p>
      )}

      {tipoActivo && (
        <>
          <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <label style={{ fontWeight: 600, fontSize: '0.85rem', color: '#5a7392', margin: 0 }}>Diccionario</label>
            <select
              className="input"
              value={tipoActivo}
              onChange={(e) => setTipoActivo(e.target.value)}
              style={{ minWidth: '220px' }}
            >
              {tipos.map((t) => (
                <option key={t.tipo} value={t.tipo}>
                  {t.etiqueta} ({t.descripcion})
                </option>
              ))}
            </select>
            <button
              type="button"
              className="btn"
              onClick={iniciarNuevo}
              disabled={cargando || guardando}
              style={{ marginLeft: 'auto' }}
            >
              {editando ? 'Cancelar' : 'Nueva fila'}
            </button>
          </div>

          {errorForm && <div className="estado-error">{errorForm}</div>}

          {editando && (
            <section style={{ border: '1px solid var(--panel-borde)', borderRadius: '8px', padding: '1rem', marginBottom: '1rem', background: 'var(--panel)' }}>
              <div style={{ marginBottom: '0.8rem' }}>
                <span style={{ fontWeight: 600, color: '#5a7392', fontSize: '0.85rem' }}>
                  {editando.id ? 'Editar fila #' : 'Nueva fila'} de {tipoSeleccionado?.etiqueta}
                </span>
              </div>
              <form onSubmit={guardarForm} className="form-paso" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0.7rem' }}>
                {columnas.map((c) => (
                  <div key={c} className="campo campo-ancho">
                    <label className="campo-label" htmlFor={`form-${c}`}>{c}</label>
                    <div>{renderInput(c)}</div>
                  </div>
                ))}
                <div className="campo campo-ancho" style={{ gridColumn: 'span 2' }}>
                  <button type="submit" className="btn btn-ejecutar" disabled={guardando}>
                    {guardando ? 'Guardando…' : editando.id ? 'Guardar cambios' : 'Crear fila'}
                  </button>
                  <button type="button" className="btn" onClick={cancelarForm} style={{ marginLeft: '0.5rem' }}>
                    Cancelar
                  </button>
                </div>
              </form>
            </section>
          )}

          {!cargando && !error && columnas.length > 0 && (
            <>
              {filasVacias && <p className="placeholder">No hay filas para mostrar en este diccionario.</p>}
              {filas.length > 0 && (
                <div className="tabla-scroll">
                  <table className="tabla">
                    <thead>
                      <tr>
                        <th>ID</th>
                        {columnas.map((c) => <th key={c}>{c}</th>)}
                        <th style={{ width: '150px' }}>Acciones</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filas.map((f) => (
                        <tr key={f.id}>
                          <td>{texto(f.id)}</td>
                          {columnas.map((c) => {
                            const v = f[c];
                            return (
                              <td key={c} title={texto(v)}>
                                {esArrayJson(c) && Array.isArray(v) ? `[${v.length}]` : texto(v)}
                              </td>
                            );
                          })}
                          <td>
                            <button
                              type="button"
                              className="btn"
                              onClick={() => iniciarEdicion(f)}
                              style={{ padding: '0.25rem 0.6rem', fontSize: '0.8rem', marginRight: '0.3rem' }}
                            >
                              Editar
                            </button>
                            <button
                              type="button"
                              className="btn"
                              onClick={() => eliminarFila(f.id)}
                              style={{ padding: '0.25rem 0.6rem', fontSize: '0.8rem' }}
                            >
                              Eliminar
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
        </>
      )}
    </div>
  );
}
