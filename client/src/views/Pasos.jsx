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
    nombre: 'Preprocesamiento completo',
    descripcion: 'Ejecuta preprocesar() sobre el dataset de entrada (data/result.json). Genera mensajes_limpios.csv, tokens.csv, resumen.json, bitacoras, etc.',
    endpoint: '1',
  },
  {
    id: 2,
    nombre: 'Análisis por periodo',
    descripcion: 'Ejecuta analizar_periodo() + guardar_analisis(). Filtra por fechas, calcula nivel de sentimiento, serie mensual, TF-IDF, LDA, shallow y librería. Genera CSV y PNG.',
    endpoint: '2',
  },
  {
    id: 3,
    nombre: 'Comparar dos periodos',
    descripcion: 'Ejecuta comparar_periodos() entre dos periodos y guarda resultados. Compara niveles, serie, TF-IDF y sentimientos de libreria.',
    endpoint: '3',
  },
  {
    id: 4,
    nombre: 'Análisis de una oración',
    descripcion: 'Ejecuta analizar_oracion() sobre una sola oracion con el mismo preprocesamiento que el dataset.',
    endpoint: '4',
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
      <header className="page-head">
        <div className="page-head-texto">
          <h1 className="page-title">Pasos del análisis</h1>
          <p className="page-desc">
            La API de Express ejecuta los comandos existentes en Plumber (R) y
            devuelve las rutas en memoria de los archivos generados.
          </p>
        </div>
        <span className="page-chip">4 pasos</span>
      </header>

      {error && <p className="estado-error">{error}</p>}

      <ol className="lista-pasos">
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
      </ol>
    </div>
  );
}

/** Parametros iniciales de cada paso, para que los inputs tengan valor desde el primer render. */
function cuerpoInicial(id) {
  switch (id) {
    case 1:
      return {
        fecha_inicio: '',
        fecha_fin: '',
        responsable: '',
        excluir_publicidad: true,
        umbral_publicidad: 4,
        anonimizar_autor: true,
        min_chars_duplicado: 25,
        consola: 'silencioso',
        csv_para_excel: false,
        preguntar_cambios: false,
      };
    case 2:
      return {
        fecha_inicio: '2023-01-01',
        fecha_fin: '2023-03-31',
        k: 6,
        agrupar: 'dia',
        shallow: true,
        libreria: true,
      };
    case 3:
      return { fecha_inicio_a: '2023-01-01', fecha_fin_a: '2023-03-31', fecha_inicio_b: '2024-01-01', fecha_fin_b: '2024-03-31', libreria: true };
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
  const completado = Boolean(res && res.ok);

  return (
    <li className={`paso-card${completado ? ' completado' : ''}`} style={paso.id === 1 ? { display: 'none' } : undefined}>
      <div className="paso-riel" aria-hidden="true">
        <span className="paso-numero">{paso.id}</span>
      </div>

      <div className="paso-cuerpo">
        <header className="paso-header">
          <div>
            <span className="paso-etiqueta">Paso {paso.id}</span>
            <h2 className="paso-titulo">{paso.nombre}</h2>
            <p className="paso-desc">{paso.descripcion}</p>
          </div>
          {completado && <span className="paso-estado">Completado</span>}
        </header>

        <form onSubmit={manejarEnvio} className="form-paso">
          <div className="form-campos">
            {paso.id === 1 && (
              <>
                <div className="campo campo-ancho">
                  <label className="campo-label" htmlFor={`entrada-${paso.id}`}>
                    Archivo de entrada
                  </label>
                  <input
                    id={`entrada-${paso.id}`}
                    type="text"
                    className="input"
                    placeholder="data/result.json"
                    disabled
                    title="El paso 1 usa data/result.json por defecto"
                  />
                  <p className="campo-ayuda">Usa data/result.json (dataset de Telegram por defecto).</p>
                </div>

                <div className="campo campo-ancho">
                  <label className="campo-label" htmlFor={`fecha-inicio-${paso.id}`}>
                    Fecha de inicio (YYYY-MM-DD)
                  </label>
                  <input
                    id={`fecha-inicio-${paso.id}`}
                    type="text"
                    className="input"
                    value={body.fecha_inicio}
                    onChange={(e) => manejarCambio('fecha_inicio', e.target.value)}
                    placeholder="2023-01-01"
                  />
                  <p className="campo-ayuda">Filtra mensajes desde esta fecha (opcional).</p>
                </div>

                <div className="campo campo-ancho">
                  <label className="campo-label" htmlFor={`fecha-fin-${paso.id}`}>
                    Fecha de fin (YYYY-MM-DD)
                  </label>
                  <input
                    id={`fecha-fin-${paso.id}`}
                    type="text"
                    className="input"
                    value={body.fecha_fin}
                    onChange={(e) => manejarCambio('fecha_fin', e.target.value)}
                    placeholder="2023-12-31"
                  />
                  <p className="campo-ayuda">Filtra mensajes hasta esta fecha (opcional).</p>
                </div>

                <div className="campo campo-ancho">
                  <label className="campo-label" htmlFor={`responsable-${paso.id}`}>
                    Responsable
                  </label>
                  <input
                    id={`responsable-${paso.id}`}
                    type="text"
                    className="input"
                    value={body.responsable}
                    onChange={(e) => manejarCambio('responsable', e.target.value)}
                    placeholder="Nombre del responsable"
                  />
                  <p className="campo-ayuda">Nombre que se registra en la bitácora.</p>
                </div>

                <div className="campo-checks campo-ancho">
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.excluir_publicidad}
                      onChange={(e) => manejarCambio('excluir_publicidad', e.target.checked)}
                    />
                    Excluir publicidad/anuncios
                  </label>
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.anonimizar_autor}
                      onChange={(e) => manejarCambio('anonimizar_autor', e.target.checked)}
                    />
                    Anonimizar autor
                  </label>
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.csv_para_excel}
                      onChange={(e) => manejarCambio('csv_para_excel', e.target.checked)}
                    />
                    CSV con BOM para Excel
                  </label>
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.preguntar_cambios}
                      onChange={(e) => manejarCambio('preguntar_cambios', e.target.checked)}
                    />
                    Preguntar cambios de código/diccionarios
                  </label>
                </div>

                <div className="campo">
                  <label className="campo-label" htmlFor={`umbral-${paso.id}`}>
                    Umbral publicidad
                  </label>
                  <input
                    id={`umbral-${paso.id}`}
                    type="number"
                    className="input"
                    min="0"
                    value={body.umbral_publicidad}
                    onChange={(e) => manejarCambio('umbral_publicidad', parseInt(e.target.value, 10) || 4)}
                  />
                </div>

                <div className="campo">
                  <label className="campo-label" htmlFor={`minchars-${paso.id}`}>
                    Mínimo caracteres duplicado
                  </label>
                  <input
                    id={`minchars-${paso.id}`}
                    type="number"
                    className="input"
                    min="0"
                    value={body.min_chars_duplicado}
                    onChange={(e) => manejarCambio('min_chars_duplicado', parseInt(e.target.value, 10) || 25)}
                  />
                </div>

                <div className="campo">
                  <label className="campo-label" htmlFor={`consola-${paso.id}`}>
                    Modo de consola
                  </label>
                  <select
                    id={`consola-${paso.id}`}
                    className="input"
                    value={body.consola}
                    onChange={(e) => manejarCambio('consola', e.target.value)}
                  >
                    <option value="silencioso">Silencioso</option>
                    <option value="resumen">Resumen</option>
                    <option value="didactico">Didáctico</option>
                  </select>
                </div>
              </>
            )}

            {paso.id === 2 && (
              <>
                <div className="campo campo-ancho">
                  <span className="campo-label">Periodo (fecha inicio y fin)</span>
                  <div className="campos-dos">
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de inicio del periodo"
                      value={body.fecha_inicio}
                      onChange={(e) => manejarCambio('fecha_inicio', e.target.value)}
                    />
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de fin del periodo"
                      value={body.fecha_fin}
                      onChange={(e) => manejarCambio('fecha_fin', e.target.value)}
                    />
                  </div>
                  <p className="campo-ayuda">Define el rango de fechas de los mensajes a analizar.</p>
                </div>

                <div className="campo">
                  <label className="campo-label" htmlFor="k-topicos">
                    Número de tópicos (k, LDA)
                  </label>
                  <input
                    id="k-topicos"
                    type="number"
                    className="input"
                    min="1"
                    value={body.k}
                    onChange={(e) => manejarCambio('k', parseInt(e.target.value, 10) || 6)}
                  />
                  <p className="campo-ayuda">Cuántos temas (clusters) identificar con LDA en los mensajes del periodo.</p>
                </div>

                <div className="campo">
                  <label className="campo-label" htmlFor="agrupar">
                    Agrupar documentos
                  </label>
                  <select
                    id="agrupar"
                    className="input"
                    value={body.agrupar}
                    onChange={(e) => manejarCambio('agrupar', e.target.value)}
                  >
                    <option value="dia">Día</option>
                    <option value="mes">Mes</option>
                  </select>
                  <p className="campo-ayuda">Intervalo de tiempo para agrupar la serie de sentimientos.</p>
                </div>

                <div className="campo-checks campo-ancho">
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.shallow}
                      onChange={(e) => manejarCambio('shallow', e.target.checked)}
                    />
                    Shallow linguistic (udpipe)
                  </label>
                  <p className="campo-ayuda">Análisis morfosintáctico (partes del discurso, lemas) con UDPipe.</p>
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.libreria}
                      onChange={(e) => manejarCambio('libreria', e.target.checked)}
                    />
                    Sentimientos de librería (syuzhet/NRC)
                  </label>
                  <p className="campo-ayuda">Usar diccionarios externos (syuzhet/NRC) además del diccionario propio.</p>
                </div>
              </>
            )}

            {paso.id === 3 && (
              <>
                <div className="campo campo-ancho">
                  <span className="campo-label">Periodo A (fecha inicio y fin)</span>
                  <div className="campos-dos">
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de inicio del periodo A"
                      value={body.fecha_inicio_a}
                      onChange={(e) => manejarCambio('fecha_inicio_a', e.target.value)}
                    />
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de fin del periodo A"
                      value={body.fecha_fin_a}
                      onChange={(e) => manejarCambio('fecha_fin_a', e.target.value)}
                    />
                  </div>
                  <p className="campo-ayuda">Rango de fechas del primer periodo a comparar.</p>
                </div>

                <div className="campo campo-ancho">
                  <span className="campo-label">Periodo B (fecha inicio y fin)</span>
                  <div className="campos-dos">
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de inicio del periodo B"
                      value={body.fecha_inicio_b}
                      onChange={(e) => manejarCambio('fecha_inicio_b', e.target.value)}
                    />
                    <input
                      type="date"
                      className="input"
                      aria-label="Fecha de fin del periodo B"
                      value={body.fecha_fin_b}
                      onChange={(e) => manejarCambio('fecha_fin_b', e.target.value)}
                    />
                  </div>
                  <p className="campo-ayuda">Rango de fechas del segundo periodo a comparar.</p>
                </div>

                <div className="campo-checks campo-ancho">
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.libreria}
                      onChange={(e) => manejarCambio('libreria', e.target.checked)}
                    />
                    Sentimientos de librería (syuzhet/NRC)
                  </label>
                  <p className="campo-ayuda">Usar diccionarios externos (syuzhet/NRC) además del diccionario propio.</p>
                </div>
              </>
            )}

            {paso.id === 4 && (
              <>
                <div className="campo campo-ancho">
                  <label className="campo-label" htmlFor="oracion">
                    Oración a analizar
                  </label>
                  <textarea
                    id="oracion"
                    className="input textarea"
                    value={body.texto}
                    onChange={(e) => manejarCambio('texto', e.target.value)}
                    rows="3"
                    placeholder="Ej: Hola, no entiendo el laboratorio de INF 111, ayuda por favor"
                  />
                </div>

                <div className="campo-checks campo-ancho">
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
                    Sentimientos de librería (syuzhet/NRC)
                  </label>
                  <label className="campo-label checkbox-label">
                    <input
                      type="checkbox"
                      checked={body.usar_topicos}
                      onChange={(e) => manejarCambio('usar_topicos', e.target.checked)}
                    />
                    Incluir topic modeling (LDA)
                  </label>
                </div>
              </>
            )}
          </div>

          <div className="form-acciones">
            <div className="campo campo-guardar">
              <label className="campo-label" htmlFor={`guardar-${paso.id}`}>
                Guardar configuración como <span className="campo-opcional">(opcional)</span>
              </label>
              <input
                id={`guardar-${paso.id}`}
                type="text"
                className="input"
                value={nombreCfg}
                onChange={(e) => setNombreCfg(e.target.value)}
                placeholder="Nombre de esta configuración"
              />
            </div>
            <button
              type="submit"
              className="btn btn-ejecutar"
              disabled={cargando}
            >
              {cargando ? 'Ejecutando…' : `Ejecutar paso ${paso.id}`}
            </button>
          </div>
        </form>

        {res && res.ok && (
          <div className="resultado-ok">
            <p className="exito">{res.mensaje || 'Paso completado exitosamente'}</p>
            {(res.version !== undefined || res.n_mensajes !== undefined) && (
              <div className="resultado-datos">
                {res.version !== undefined && (
                  <span className="dato">
                    <span className="dato-etiqueta">Versión del dataset</span>
                    <span className="dato-valor">{res.version}</span>
                  </span>
                )}
                {res.n_mensajes !== undefined && (
                  <span className="dato">
                    <span className="dato-etiqueta">Mensajes</span>
                    <span className="dato-valor">{res.n_mensajes}</span>
                  </span>
                )}
                {res.parametros_usados && (
                  <div className="resultado-parametros">
                    <h4 className="resultado-titulo">Parámetros usados</h4>
                    <pre className="resultado-json">{JSON.stringify(res.parametros_usados, null, 2)}</pre>
                  </div>
                )}
              </div>
            )}
            {res.dir_analisis && (
              <p className="campo-ayuda">Directorio de análisis: {res.dir_analisis}</p>
            )}
            {res.interpretacion && (
              <div className="interpretacion">
                <strong>Interpretación:</strong> {res.interpretacion}
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
            <h3 className="seccion-titulo">Imágenes generadas (PNG)</h3>
            <div className="grid-imagenes">
              {imgs.map((img) => (
                <ImagenPaso key={img.id} img={img} />
              ))}
            </div>
          </div>
        )}

        {csVs.length > 0 && (
          <div className="seccion-archivos">
            <h3 className="seccion-titulo">Archivos CSV</h3>
            <CsvPaso paso={paso.id} csvs={csVs} />
          </div>
        )}

        {configuraciones.length > 0 && (
          <div className="seccion-config">
            <h3 className="seccion-titulo">Configuraciones guardadas</h3>
            <ul className="lista-config">
              {configuraciones.map((c) => (
                <li key={c.id}>
                  <strong>{c.nombre}</strong>
                  <span className="config-parametros">
                    {c.parametros ? JSON.stringify(c.parametros).slice(0, 100) : ''}
                  </span>
                  <span className="config-fecha">
                    actualizado {new Date(c.actualizado_en).toLocaleString()}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </li>
  );
}
