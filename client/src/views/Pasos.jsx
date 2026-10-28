/**
 * Vista de ejecucion de pasos (1-4).
 * Formularios para configurar cada paso y la API de Express ejecuta
 * el comando correspondiente en Plumber (R), devolviendo las rutas
 * en memoria de los archivos generados para renderizar imagenes/CSV.
 */
import { useEffect, useState, useCallback } from 'react';
import { apiGet, apiPost } from '../api.js';
import { useSse } from '../sse.jsx';
import ImagenPaso from '../components/ImagenPaso.jsx';
import CsvPaso from '../components/CsvPaso.jsx';

const PASOS = [
  {
    id: 1,
    nombre: 'Paso 1 — Preprocesamiento completo',
    descripcion: 'Ejecuta preprocesar() sobre el dataset de entrada (data/result.json). Genera mensajes_limpios.csv, tokens.csv, resumen.json, bitacoras, etc.',
    endpoint: '1',
    icono: '🔄',
  },
  {
    id: 2,
    nombre: 'Paso 2 — Analisis por periodo',
    descripcion: 'Ejecuta analizar_periodo() + guardar_analisis(). Filtra por fechas, calcula nivel de sentimiento, serie mensual, TF-IDF, LDA, shallow y librería. Genera CSV y PNG.',
    endpoint: '2',
    icono: '📊',
  },
  {
    id: 3,
    nombre: 'Paso 3 — Comparar dos periodos',
    descripcion: 'Ejecuta comparar_periodos() entre dos periodos y guarda resultados. Compara niveles, serie, TF-IDF y sentimientos de libreria.',
    endpoint: '3',
    icono: '⚖️',
  },
  {
    id: 4,
    nombre: 'Paso 4 — Analisis de una oracion',
    descripcion: 'Ejecuta analizar_oracion() sobre una sola oracion con el mismo preprocesamiento que el dataset.',
    endpoint: '4',
    icono: '💬',
  },
];

export default function PasosView() {
  const [configuraciones, setConfiguraciones] = useState([]);
  const [resultados, setResultados] = useState({});
  const [cargando, setCargando] = useState({});
  const [error, setError] = useState(null);
  const [archivos, setArchivos] = useState({});

  const cargarConfiguraciones = useCallback(async () => {
    try {
      const data = await apiGet('/api/configuraciones');
      setConfiguraciones(data);
    } catch (err) {
      console.error('[PasosView] No se pudieron cargar configuraciones:', err.message);
    }
  }, []);

  useEffect(() => {
    cargarConfiguraciones();
  }, [cargarConfiguraciones]);

  // Actualizar archivos disponibles cuando llega evento de dataset nuevo
  useSse('dataset:update', useCallback(() => {
    Object.keys(archivos).forEach((p) => cargarArchivosPaso(p));
  }, [archivos]));

  const cargarArchivosPaso = useCallback(async (paso) => {
    try {
      const imgs = await apiGet(`/api/pasos/${paso}/imagenes`);
      const csVs = await apiGet(`/api/pasos/${paso}/csvs`);
      setArchivos((prev) => ({ ...prev, [paso]: { imagenes: imgs, csvs: csVs } }));
    } catch (err) {
      // No es critico si aun no hay archivos
    }
  }, []);

  const ejecutarPaso = useCallback(async (paso, body) => {
    setCargando((prev) => ({ ...prev, [paso]: true }));
    setError(null);
    try {
      const resultado = await apiPost(`/api/pasos/${paso}`, body);
      setResultados((prev) => ({ ...prev, [paso]: resultado }));
      if (resultado.ok) {
        await cargarArchivosPaso(paso);
        await cargarConfiguraciones();
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando((prev) => ({ ...prev, [paso]: false }));
    }
  }, [cargarArchivosPaso, cargarConfiguraciones]);

  const guardarConfiguracion = useCallback(async (paso, nombre, parametros) => {
    try {
      await apiPost('/api/configuraciones', { nombre, paso, parametros });
      await cargarConfiguraciones();
    } catch (err) {
      setError(err.message);
    }
  }, [cargarConfiguraciones]);

  const resultadoPaso = (p) => resultados[p];

  return (
    <div>
      <div className="toolbar">
        <h2>Ejecución de pasos (API de R)</h2>
        <span className="meta">
          La API de Express ejecuta los comandos existentes en Plumber (R)
          y devuelve las rutas en memoria de los archivos generados.
        </span>
      </div>

      {error && <p className="estado-error">{error}</p>}

      <div className="grid-pasos">
        {PASOS.map((paso) => (
          <FormularioPaso
            key={paso.id}
            paso={paso}
            ejecutarPaso={ejecutarPaso}
            guardarConfiguracion={guardarConfiguracion}
            configuraciones={configuraciones.filter((c) => c.paso === paso.id)}
            resultado={resultadoPaso(paso.id)}
            cargando={cargando[paso.id]}
            archivos={archivos[paso.id]}
          />
        ))}
      </div>
    </div>
  );
}

/** Parametros iniciales de cada paso, para que los inputs tengan valor desde el primer render. */
function cuerpoInicial(id) {
  switch (id) {
    case 1:
      return {};
    case 2:
      return {
        periodo: ['2023-01-01', '2023-03-31'],
        k: 6,
        agrupar: 'dia',
        shallow: true,
        libreria: true,
      };
    case 3:
      return { periodoA: 'todo_2023', periodoB: 'todo_2024', libreria: true };
    case 4:
      return {
        texto: '',
        usar_udpipe: true,
        usar_libreria: true,
        usar_topicos: false,
      };
    default:
      return {};
  }
}

function FormularioPaso({ paso, ejecutarPaso, guardarConfiguracion, configuraciones, resultado, cargando, archivos }) {
  const [nombreCfg, setNombreCfg] = useState('');
  const [body, setBody] = useState(() => cuerpoInicial(paso.id));

  const manejarCambio = (key, valor) => {
    setBody((prev) => ({ ...prev, [key]: valor }));
  };

  const manejarEnvio = async (e) => {
    e.preventDefault();
    await ejecutarPaso(paso.id, body);
    if (nombreCfg) {
      await guardarConfiguracion(paso.id, nombreCfg, body);
      setNombreCfg('');
    }
  };

  const res = resultado;
  const imgs = archivos?.imagenes || [];
  const csVs = archivos?.csvs || [];

  return (
    <div className="card paso-card">
      <div className="paso-header">
        <span className="paso-icono">{paso.icono}</span>
        <div>
          <h3>{paso.nombre}</h3>
          <p className="paso-desc">{paso.descripcion}</p>
        </div>
      </div>

      <form onSubmit={manejarEnvio} className="form-paso">
        {paso.id === 1 && (
          <>
            <label className="campo-label">Archivo de entrada</label>
            <input
              type="text"
              className="input"
              placeholder="data/result.json"
              disabled
              title="El paso 1 usa data/result.json por defecto"
            />
            <p className="campo-ayuda">Usa data/result.json (dataset de Telegram por defecto).</p>
          </>
        )}

        {paso.id === 2 && (
          <>
            <label className="campo-label">Periodo (fecha inicio y fin)</label>
            <div className="campos-dos">
              <input
                type="date"
                className="input"
                value={Array.isArray(body.periodo) ? body.periodo[0] : ''}
                onChange={(e) => {
                  const p = Array.isArray(body.periodo) ? [...body.periodo] : [];
                  p[0] = e.target.value;
                  manejarCambio('periodo', p);
                }}
              />
              <input
                type="date"
                className="input"
                value={Array.isArray(body.periodo) ? body.periodo[1] : ''}
                onChange={(e) => {
                  const p = Array.isArray(body.periodo) ? [...body.periodo] : [];
                  p[1] = e.target.value;
                  manejarCambio('periodo', p);
                }}
              />
            </div>
            <label className="campo-label">Numero de topicos (k, LDA)</label>
            <input
              type="number"
              className="input"
              min="1"
              value={body.k}
              onChange={(e) => manejarCambio('k', parseInt(e.target.value, 10) || 6)}
            />
            <label className="campo-label">Agrupar documentos</label>
            <select
              className="input"
              value={body.agrupar}
              onChange={(e) => manejarCambio('agrupar', e.target.value)}
            >
              <option value="dia">Dia</option>
              <option value="mes">Mes</option>
            </select>
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.shallow}
                onChange={(e) => manejarCambio('shallow', e.target.checked)}
              />
              Shallow linguistic (udpipe)
            </label>
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.libreria}
                onChange={(e) => manejarCambio('libreria', e.target.checked)}
              />
              Sentimientos de libreria (syuzhet/NRC)
            </label>
          </>
        )}

        {paso.id === 3 && (
          <>
            <label className="campo-label">Periodo A</label>
            <input
              type="text"
              className="input"
              value={body.periodoA}
              onChange={(e) => manejarCambio('periodoA', e.target.value)}
              placeholder="ej: todo_2023 o 2023-01-01,2023-03-31"
            />
            <label className="campo-label">Periodo B</label>
            <input
              type="text"
              className="input"
              value={body.periodoB}
              onChange={(e) => manejarCambio('periodoB', e.target.value)}
              placeholder="ej: todo_2024 o 2024-01-01,2024-03-31"
            />
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.libreria}
                onChange={(e) => manejarCambio('libreria', e.target.checked)}
              />
              Sentimientos de libreria (syuzhet/NRC)
            </label>
          </>
        )}

        {paso.id === 4 && (
          <>
            <label className="campo-label">Oracion a analizar</label>
            <textarea
              className="input textarea"
              value={body.texto}
              onChange={(e) => manejarCambio('texto', e.target.value)}
              rows="3"
              placeholder="Ej: Hola, no entiendo el laboratorio de INF 111, ayuda por favor"
            />
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.usar_udpipe}
                onChange={(e) => manejarCambio('usar_udpipe', e.target.checked)}
              />
              Shallow linguistic (udpipe)
            </label>
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.usar_libreria}
                onChange={(e) => manejarCambio('usar_libreria', e.target.checked)}
              />
              Sentimientos de libreria (syuzhet/NRC)
            </label>
            <label className="campo-label checkbox-label">
              <input
                type="checkbox"
                checked={body.usar_topicos}
                onChange={(e) => manejarCambio('usar_topicos', e.target.checked)}
              />
              Incluir topic modeling (LDA)
            </label>
          </>
        )}

        <div className="form-actions">
          <label className="campo-label">Guardar configuracion como</label>
          <input
            type="text"
            className="input"
            value={nombreCfg}
            onChange={(e) => setNombreCfg(e.target.value)}
            placeholder="Nombre opcional para guardar esta configuracion"
          />
          <button
            type="submit"
            className="btn btn-ejecutar"
            disabled={cargando}
          >
            {cargando ? 'Ejecutando…' : `Ejecutar ${paso.nombre.split('—')[1].trim()}`}
          </button>
        </div>
      </form>

      {res && res.ok && (
        <div className="resultado-ok">
          <p className="exito">✓ {res.mensaje || 'Paso completado exitosamente'}</p>
          {res.version !== undefined && <span className="meta">Version del dataset: {res.version}</span>}
          {res.n_mensajes !== undefined && <span className="meta">Mensajes: {res.n_mensajes}</span>}
          {res.dir_analisis && (
            <p className="campo-ayuda">Directorio de analisis: {res.dir_analisis}</p>
          )}
          {res.interpretacion && (
            <div className="interpretacion">
              <strong>Interpretacion:</strong> {res.interpretacion}
            </div>
          )}
        </div>
      )}

      {res && !res.ok && (
        <div className="estado-error">
          <p>Error en el paso {paso.id}: {res.mensaje || res.error || 'Desconocido'}</p>
        </div>
      )}

      {imgs.length > 0 && (
        <div className="seccion-archivos">
          <h4>Imagenes generadas (PNG)</h4>
          <div className="grid-imagenes">
            {imgs.map((img) => (
              <ImagenPaso key={img.id} img={img} />
            ))}
          </div>
        </div>
      )}

      {csVs.length > 0 && (
        <div className="seccion-archivos">
          <h4>Archivos CSV</h4>
          <CsvPaso paso={paso.id} csvs={csVs} />
        </div>
      )}

      {configuraciones.length > 0 && (
        <div className="seccion-config">
          <h4>Configuraciones guardadas para este paso</h4>
          <ul class="lista-config">
            {configuraciones.map((c) => (
              <li key={c.id}>
                <strong>{c.nombre}</strong> — {c.parametros ? JSON.stringify(c.parametros).slice(0, 100) : ''}
                <span className="meta">actualizado {new Date(c.actualizado_en).toLocaleString()}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
