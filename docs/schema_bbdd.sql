-- ==============================================================================
-- Esquema de Base de Datos — AnSent (Análisis de Sentimientos)
-- Compatible con PostgreSQL (pgAdmin, ERD)
-- Modela: configuración/diccionarios, datos del dataset, análisis, bitácoras
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABLAS DE CONFIGURACIÓN Y DICCIONARIOS (desde r/config/)
-- ------------------------------------------------------------------------------

-- Códigos de materia (prefijos como INF, MAT, LAB...)
CREATE TABLE IF NOT EXISTS codigos_materia (
  prefijo VARCHAR(10) NOT NULL PRIMARY KEY,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Abreviaturas de chat y su normalización
CREATE TABLE IF NOT EXISTS abreviaturas (
  id SERIAL PRIMARY KEY,
  abreviatura VARCHAR(50) NOT NULL UNIQUE,
  normal VARCHAR(100) NOT NULL,
  categoria VARCHAR(50),
  justificacion TEXT
);

-- Emoticonos de texto y su equivalente emoji
CREATE TABLE IF NOT EXISTS emoticonos (
  id SERIAL PRIMARY KEY,
  emoticono VARCHAR(20) NOT NULL UNIQUE,
  emoji VARCHAR(20),
  justificacion TEXT
);

-- Diccionario maestro de emojis
CREATE TABLE IF NOT EXISTS emojis (
  id SERIAL PRIMARY KEY,
  emoji VARCHAR(20) NOT NULL UNIQUE,
  significado_es VARCHAR(200),
  sentimiento VARCHAR(50),
  polaridad INTEGER CHECK (polaridad IN (-1, 0, 1)),
  nombre_unicode VARCHAR(200),
  pendiente BOOLEAN DEFAULT FALSE  -- TRUE si significado_es está vacío
);

-- Diccionario de género (referencias femeninas/masculinas)
CREATE TABLE IF NOT EXISTS genero (
  id SERIAL PRIMARY KEY,
  palabra VARCHAR(100) NOT NULL,
  genero VARCHAR(20) CHECK (genero IN ('femenino', 'masculino')),
  tipo VARCHAR(50),  -- pronombre, sustantivo, etc.
  justificacion TEXT
);

-- Justificaciones teóricas del análisis
CREATE TABLE IF NOT EXISTS justificaciones_analisis (
  id VARCHAR(50) PRIMARY KEY,
  que_muestra VARCHAR(200),
  justificacion_teorica TEXT,
  referencia TEXT
);

-- Stopwords personalizadas con acción y justificación
CREATE TABLE IF NOT EXISTS stopwords (
  id SERIAL PRIMARY KEY,
  palabra VARCHAR(100) NOT NULL,
  accion VARCHAR(20) CHECK (accion IN ('eliminar', 'conservar')),
  categoria VARCHAR(50),
  justificacion TEXT
);

-- Periodos predefinidos para análisis
CREATE TABLE IF NOT EXISTS periodos (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL
);

-- Reglas de detección de publicidad/anuncios
CREATE TABLE IF NOT EXISTS palabras_anuncio (
  id SERIAL PRIMARY KEY,
  tipo VARCHAR(30) NOT NULL,  -- estructura, frase, regex
  patron VARCHAR(200) NOT NULL,
  peso INTEGER DEFAULT 1,
  parametro VARCHAR(50),
  categoria VARCHAR(50),
  justificacion TEXT
);

-- ------------------------------------------------------------------------------
-- 2. TABLA DE SENTIMIENTOS (desde r/config/sentimientos.json)
-- ------------------------------------------------------------------------------

-- Sentimientos propios del diccionario
CREATE TABLE IF NOT EXISTS sentimientos (
  id SERIAL PRIMARY KEY,
  orden INTEGER NOT NULL,
  nombre VARCHAR(50) NOT NULL UNIQUE,
  polaridad INTEGER CHECK (polaridad IN (-1, 0, 1)),
  activo BOOLEAN DEFAULT TRUE,
  definicion TEXT,
  comentario_archivo TEXT  -- _comentario del JSON
);

-- Palabras asociadas a cada sentimiento (relación muchos a muchos)
CREATE TABLE IF NOT EXISTS sentimientos_palabras (
  id SERIAL PRIMARY KEY,
  sentimiento_id INTEGER NOT NULL REFERENCES sentimientos(id) ON DELETE CASCADE,
  palabra VARCHAR(100) NOT NULL,
  UNIQUE(sentimiento_id, palabra)
);

-- Raíces asociadas a cada sentimiento (relación muchos a muchos)
CREATE TABLE IF NOT EXISTS sentimientos_raices (
  id SERIAL PRIMARY KEY,
  sentimiento_id INTEGER NOT NULL REFERENCES sentimientos(id) ON DELETE CASCADE,
  raiz VARCHAR(100) NOT NULL,
  UNIQUE(sentimiento_id, raiz)
);

-- ------------------------------------------------------------------------------
-- 3. TABLAS DEL DATASET DE ENTRADA (desde r/data/result.json)
-- ------------------------------------------------------------------------------

-- Metadata del chat de Telegram
CREATE TABLE IF NOT EXISTS chats (
  id INTEGER PRIMARY KEY,
  name VARCHAR(200),
  type VARCHAR(50),
  fecha_ingesta TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mensajes crudos leídos del archivo JSON de entrada
CREATE TABLE IF NOT EXISTS mensajes_crudos (
  id_mensaje INTEGER NOT NULL,
  chat_id INTEGER REFERENCES chats(id),
  tipo_registro VARCHAR(20),  -- message, service, etc.
  fecha_raw TEXT,             -- fecha original como texto ISO
  fecha_hora TIMESTAMP,       -- fecha parseada (hora local La Paz)
  autor_raw VARCHAR(200),
  autor_id VARCHAR(100),
  responde_a INTEGER,         -- id del mensaje al que responde
  editado BOOLEAN DEFAULT FALSE,
  reenviado_de VARCHAR(200),
  texto_raw TEXT,
  texto_era_lista BOOLEAN DEFAULT FALSE,
  tipo_contenido VARCHAR(50), -- texto, foto, video, sticker, archivo, audio, encuesta
  sticker_emoji VARCHAR(20),
  reacciones TEXT,            -- JSON o string "👍:2|👎:1"
  accion_servicio VARCHAR(100),
  PRIMARY KEY (id_mensaje, chat_id)
);

-- Índices para mensajes crudos
CREATE INDEX IF NOT EXISTS idx_mensajes_crudos_fecha ON mensajes_crudos(fecha_hora);
CREATE INDEX IF NOT EXISTS idx_mensajes_crudos_autor ON mensajes_crudos(autor_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_crudos_tipo ON mensajes_crudos(tipo_contenido);

-- ------------------------------------------------------------------------------
-- 4. TABLAS DEL DATASET LIMPIO (salida del preprocesamiento)
-- ------------------------------------------------------------------------------

-- Dataset limpio: una fila por mensaje procesado
CREATE TABLE IF NOT EXISTS mensajes_limpios (
  id_mensaje INTEGER NOT NULL,
  chat_id INTEGER REFERENCES chats(id),
  fecha_hora TIMESTAMP,
  fecha DATE,
  anio INTEGER,
  mes INTEGER,
  anio_mes VARCHAR(7),   -- YYYY-MM
  trimestre VARCHAR(10), -- YYYY-Tn
  dia_semana VARCHAR(20),
  hora INTEGER,
  autor VARCHAR(200),
  autor_id VARCHAR(100),
  tipo_contenido VARCHAR(50),
  es_respuesta BOOLEAN DEFAULT FALSE,
  responde_a INTEGER,
  editado BOOLEAN DEFAULT FALSE,
  reenviado BOOLEAN DEFAULT FALSE,
  reenviado_de VARCHAR(200),
  n_caracteres INTEGER,
  n_palabras INTEGER,
  n_tokens INTEGER,
  n_enlaces INTEGER,
  n_hashtags INTEGER,
  n_menciones INTEGER,
  tiene_telefono BOOLEAN DEFAULT FALSE,
  n_emojis INTEGER,
  emojis_lista TEXT,     -- lista separada por espacios
  sentimiento_emoji VARCHAR(50),
  polaridad_emoji NUMERIC(5,3),
  reacciones_total INTEGER DEFAULT 0,
  reacciones_pos INTEGER DEFAULT 0,
  reacciones_neg INTEGER DEFAULT 0,
  outlier_longitud BOOLEAN DEFAULT FALSE,
  outlier_rafaga BOOLEAN DEFAULT FALSE,
  puntaje_publicidad NUMERIC(5,2),
  motivo_publicidad TEXT,
  posible_publicidad BOOLEAN DEFAULT FALSE,
  n_ref_femenino INTEGER DEFAULT 0,
  n_ref_masculino INTEGER DEFAULT 0,
  n_ref_inclusivo INTEGER DEFAULT 0,
  genero_mencionado VARCHAR(20), -- femenino, masculino, ambos, inclusivo, ninguno
  texto_original TEXT,
  texto_traducido TEXT,
  texto_limpio TEXT,
  texto_tokens TEXT,     -- tokens separados por espacio
  polaridad_msg VARCHAR(20), -- positivo, negativo, neutral
  polaridad_score NUMERIC(5,3),
  sentimiento_dominante VARCHAR(50),
  hits_total INTEGER DEFAULT 0,
  n_negados INTEGER DEFAULT 0,
  PRIMARY KEY (id_mensaje, chat_id)
);

-- Índices para mensajes limpios
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_fecha ON mensajes_limpios(fecha);
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_anio_mes ON mensajes_limpios(anio_mes);
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_autor ON mensajes_limpios(autor_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_polaridad ON mensajes_limpios(polaridad_msg);
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_dominante ON mensajes_limpios(sentimiento_dominante);
CREATE INDEX IF NOT EXISTS idx_mensajes_limpios_genero ON mensajes_limpios(genero_mencionado);

-- Columnas dinámicas de sentimientos por mensaje (una fila por sentimiento activo)
CREATE TABLE IF NOT EXISTS sentimientos_por_mensaje (
  id SERIAL PRIMARY KEY,
  id_mensaje INTEGER NOT NULL,
  chat_id INTEGER NOT NULL,
  sentimiento VARCHAR(50) NOT NULL,
  pct NUMERIC(6,3),           -- 0 a 100
  hits INTEGER DEFAULT 0,
  FOREIGN KEY (id_mensaje, chat_id) REFERENCES mensajes_limpios(id_mensaje, chat_id)
);

CREATE INDEX IF NOT EXISTS idx_sentimientos_por_mensaje_msg ON sentimientos_por_mensaje(id_mensaje, chat_id);
CREATE INDEX IF NOT EXISTS idx_sentimientos_por_mensaje_sent ON sentimientos_por_mensaje(sentimiento);

-- Tokens por mensaje (salida tokens.csv)
CREATE TABLE IF NOT EXISTS tokens (
  id SERIAL PRIMARY KEY,
  id_mensaje INTEGER NOT NULL,
  chat_id INTEGER NOT NULL,
  fecha DATE,
  anio_mes VARCHAR(7),
  token VARCHAR(100) NOT NULL,
  FOREIGN KEY (id_mensaje, chat_id) REFERENCES mensajes_limpios(id_mensaje, chat_id)
);

CREATE INDEX IF NOT EXISTS idx_tokens_msg ON tokens(id_mensaje, chat_id);
CREATE INDEX IF NOT EXISTS idx_tokens_token ON tokens(token);
CREATE INDEX IF NOT EXISTS idx_tokens_anio_mes ON tokens(anio_mes);

-- ------------------------------------------------------------------------------
-- 5. TABLAS DE ANÁLISIS (salida de analizar_periodo, comparar_periodos, etc.)
-- ------------------------------------------------------------------------------

-- Nivel de sentimientos por periodo
CREATE TABLE IF NOT EXISTS niveles_por_periodo (
  id SERIAL PRIMARY KEY,
  periodo VARCHAR(100) NOT NULL,        -- nombre del periodo
  fecha_inicio DATE,
  fecha_fin DATE,
  sentimiento VARCHAR(50) NOT NULL,
  nivel_pct NUMERIC(6,3),               -- promedio de pct_*
  mensajes_pct NUMERIC(6,3),            -- % de mensajes con al menos una coincidencia
  n_mensajes INTEGER,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_niveles_periodo ON niveles_por_periodo(periodo);
CREATE INDEX IF NOT EXISTS idx_niveles_sentimiento ON niveles_por_periodo(sentimiento);

-- Serie temporal de sentimientos (por mes/semana/día)
CREATE TABLE IF NOT EXISTS serie_sentimientos (
  id SERIAL PRIMARY KEY,
  periodo VARCHAR(100) NOT NULL,
  fecha DATE NOT NULL,                  -- anio_mes como fecha (primer día del mes)
  sentimiento VARCHAR(50) NOT NULL,
  pct NUMERIC(6,3),
  n_mensajes INTEGER,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_serie_periodo ON serie_sentimientos(periodo, fecha);
CREATE INDEX IF NOT EXISTS idx_serie_sentimiento ON serie_sentimientos(sentimiento);

-- Resultados TF-IDF
CREATE TABLE IF NOT EXISTS tfidf_resultados (
  id SERIAL PRIMARY KEY,
  periodo VARCHAR(100) NOT NULL,
  doc VARCHAR(100) NOT NULL,            -- mes o periodo
  token VARCHAR(100) NOT NULL,
  n INTEGER DEFAULT 1,                  -- frecuencia en el documento
  tf NUMERIC(8,6),
  idf NUMERIC(8,6),
  tf_idf NUMERIC(10,6),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tfidf_periodo ON tfidf_resultados(periodo, doc);
CREATE INDEX IF NOT EXISTS idx_tfidf_token ON tfidf_resultados(token);

-- Tópicos LDA
CREATE TABLE IF NOT EXISTS topicos (
  id SERIAL PRIMARY KEY,
  periodo VARCHAR(100) NOT NULL,
  k INTEGER NOT NULL,                   -- número de tópicos
  agrupar VARCHAR(10) CHECK (agrupar IN ('dia', 'mes')),
  n_documentos INTEGER,
  n_terminos INTEGER,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_topicos_periodo ON topicos(periodo);

-- Etiquetas de tópicos
CREATE TABLE IF NOT EXISTS topicos_etiquetas (
  id SERIAL PRIMARY KEY,
  topico_id INTEGER NOT NULL REFERENCES topicos(id) ON DELETE CASCADE,
  topico VARCHAR(20) NOT NULL,          -- T1, T2, ...
  etiqueta VARCHAR(200)                 -- las 3 palabras más probables
);

-- Términos por tópico (beta)
CREATE TABLE IF NOT EXISTS topicos_terminos (
  id SERIAL PRIMARY KEY,
  topico_id INTEGER NOT NULL REFERENCES topicos(id) ON DELETE CASCADE,
  termino VARCHAR(100) NOT NULL,
  beta NUMERIC(10,6)
);

-- Dominante de tópico por documento
CREATE TABLE IF NOT EXISTS topicos_por_documento (
  id SERIAL PRIMARY KEY,
  topico_id INTEGER NOT NULL REFERENCES topicos(id) ON DELETE CASCADE,
  doc VARCHAR(100) NOT NULL,            -- fecha o anio_mes
  topico VARCHAR(20),
  peso NUMERIC(8,6)
);

-- Resultados de análisis de librería (syuzhet NRC)
CREATE TABLE IF NOT EXISTS libreria_sentimientos (
  id SERIAL PRIMARY KEY,
  periodo VARCHAR(100) NOT NULL,
  sentimiento VARCHAR(50) NOT NULL,     -- emoción o polaridad
  tipo VARCHAR(30),                     -- emocion (8) o polaridad
  nivel_pct NUMERIC(6,3),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_libreria_periodo ON libreria_sentimientos(periodo);

-- Comparación entre dos periodos (niveles)
CREATE TABLE IF NOT EXISTS comparacion_niveles (
  id SERIAL PRIMARY KEY,
  periodo_a VARCHAR(100) NOT NULL,
  periodo_b VARCHAR(100) NOT NULL,
  sentimiento VARCHAR(50) NOT NULL,
  nivel_a NUMERIC(6,3),
  nivel_b NUMERIC(6,3),
  diferencia NUMERIC(6,3),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 6. TABLAS DE SALIDAS GENERADAS (archivos CSV de salida/)
-- ------------------------------------------------------------------------------

-- Registro de ejecuciones del pipeline
CREATE TABLE IF NOT EXISTS ejecuciones (
  id SERIAL PRIMARY KEY,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responsable VARCHAR(200),
  archivo VARCHAR(200),                 -- nombre del archivo de entrada
  archivo_md5 VARCHAR(64),              -- hash MD5 del archivo
  evento VARCHAR(50),                   -- primera ejecución, misma dataset, dataset nuevo, etc.
  parametros TEXT,                      -- JSON con parámetros usados
  estado VARCHAR(20),                   -- ok, error, detenido
  paso_donde_paro VARCHAR(100),
  mensaje_error TEXT,
  pasos_registrados INTEGER DEFAULT 0,
  registros_leidos INTEGER,
  mensajes_limpios INTEGER,
  mensajes_excluidos INTEGER,
  emojis_pendientes INTEGER DEFAULT 0,
  cambios_detectados TEXT               -- IDs de cambios asociados
);

-- Emojis en uso (frecuencia en texto y reacciones)
CREATE TABLE IF NOT EXISTS salida_emojis_en_uso (
  id SERIAL PRIMARY KEY,
  ejecucion_id INTEGER REFERENCES ejecuciones(id),
  emoji VARCHAR(20) NOT NULL,
  en_texto INTEGER DEFAULT 0,
  en_reacciones INTEGER DEFAULT 0,
  significado_es VARCHAR(200),
  sentimiento VARCHAR(50),
  polaridad INTEGER,
  pendiente BOOLEAN DEFAULT FALSE
);

-- Stopwords aplicadas (qué se eliminó y qué se conservó)
CREATE TABLE IF NOT EXISTS salida_stopwords_aplicadas (
  id SERIAL PRIMARY KEY,
  ejecucion_id INTEGER REFERENCES ejecuciones(id),
  palabra VARCHAR(100) NOT NULL,
  decision VARCHAR(20),                 -- eliminada, conservada
  motivo VARCHAR(200),
  ocurrencias INTEGER,
  justificacion TEXT
);

-- Mensajes excluidos (motivo de exclusión)
CREATE TABLE IF NOT EXISTS salida_mensajes_excluidos (
  id SERIAL PRIMARY KEY,
  ejecucion_id INTEGER REFERENCES ejecuciones(id),
  id_mensaje INTEGER,
  fecha_hora TIMESTAMP,
  autor VARCHAR(200),
  tipo_contenido VARCHAR(50),
  motivo_exclusion TEXT,
  puntaje_publicidad NUMERIC(5,2),
  motivo_publicidad TEXT,
  texto_original TEXT
);

-- Resumen de cada ejecución
CREATE TABLE IF NOT EXISTS salida_resumen (
  id SERIAL PRIMARY KEY,
  ejecucion_id INTEGER REFERENCES ejecuciones(id),
  archivo VARCHAR(200),
  registros_leidos INTEGER,
  mensajes_limpios INTEGER,
  mensajes_excluidos INTEGER,
  rango_fechas_inicio DATE,
  rango_fechas_fin DATE,
  sentimientos_activos TEXT,            -- lista de nombres
  polaridad_distribucion TEXT,          -- JSON
  emojis_pendientes INTEGER DEFAULT 0,
  pasos_bitacora INTEGER,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 7. TABLAS DE BITÁCORAS Y EJECUCIONES (desde bitacora.R y Express)
-- ------------------------------------------------------------------------------

-- Pasos de cada ejecución (bitácora limpia)
CREATE TABLE IF NOT EXISTS ejecucion_pasos (
  id SERIAL PRIMARY KEY,
  ejecucion_id INTEGER NOT NULL REFERENCES ejecuciones(id) ON DELETE CASCADE,
  id_instancia VARCHAR(50),             -- ejecucion_id + id_paso
  id_paso VARCHAR(20),                  -- P01, P02, ...
  etapa VARCHAR(100),                   -- nombre de la metodología
  campo_columna VARCHAR(100),
  tipo_problema VARCHAR(100),
  accion_realizada TEXT,
  filas_antes INTEGER,
  filas_despues INTEGER,
  filas_afectadas INTEGER,
  impacto_dataset TEXT,
  ejemplo_antes TEXT,
  ejemplo_despues TEXT,
  mensaje_error TEXT,
  script TEXT                           -- código ejecutado
);

CREATE INDEX IF NOT EXISTS idx_ejecucion_pasos_ejecucion ON ejecucion_pasos(ejecucion_id);

-- Cambios detectados en código y diccionarios (vigilar_cambios)
CREATE TABLE IF NOT EXISTS cambios (
  id SERIAL PRIMARY KEY,
  fecha DATE,
  hora TIME,
  tipo VARCHAR(20),                     -- código, diccionario
  archivo VARCHAR(200),
  seccion VARCHAR(100),
  problema_detectado TEXT,
  como_se_detecto TEXT,
  cambio_realizado TEXT,
  justificacion TEXT,
  resultado TEXT,
  ejecucion_prueba TEXT,                -- IDs de ejecuciones donde se probó
  responsable VARCHAR(200),
  estado_registro VARCHAR(30)           -- completo, FALTA JUSTIFICAR
);

-- Experimentos (TF-IDF, shallow, LDA post-preprocesamiento)
CREATE TABLE IF NOT EXISTS experimentos (
  id SERIAL PRIMARY KEY,
  fecha DATE,
  hora TIME,
  id_ejecucion_preprocesamiento INTEGER REFERENCES ejecuciones(id),
  dataset VARCHAR(200),
  dataset_md5 VARCHAR(64),
  metodo VARCHAR(100),                  -- tfidf, topic modeling, shallow, libreria
  parametros TEXT,
  n_documentos INTEGER,
  tamano_vocabulario INTEGER,
  resultado_principal TEXT,
  archivo_resultado VARCHAR(200),
  notas TEXT,
  responsable VARCHAR(200)
);

-- ------------------------------------------------------------------------------
-- 8. TABLAS EXISTENTES DE EXPRESS (mantener compatibilidad)
-- ------------------------------------------------------------------------------

-- Bitácora de cambios del dataset (registros que Plumber/Express escriben)
CREATE TABLE IF NOT EXISTS bitacora_registros (
  id SERIAL PRIMARY KEY,
  fecha TEXT NOT NULL,                  -- ISO 8601
  tipo_cambio TEXT NOT NULL,            -- preprocesamiento, analisis_periodo, etc.
  descripcion TEXT NOT NULL,
  filas_afectadas INTEGER,
  columnas_afectadas TEXT,              -- JSON
  version_dataset INTEGER,
  resumen_estadistico TEXT,             -- JSON libre
  creado_por TEXT DEFAULT 'R-Plumber'
);

CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora_registros (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_bitacora_tipo ON bitacora_registros (tipo_cambio);

-- Configuraciones guardadas desde el frontend
CREATE TABLE IF NOT EXISTS configuraciones (
  id SERIAL PRIMARY KEY,
  nombre TEXT NOT NULL,
  paso INTEGER NOT NULL,                -- 1=preprocesar, 2=analizar-periodo, 3=comparar-periodos, 4=analizar-oracion
  parametros TEXT NOT NULL,             -- JSON
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_configuraciones_paso ON configuraciones (paso);

-- Archivos generados por cada paso
CREATE TABLE IF NOT EXISTS graficos_info (
  id SERIAL PRIMARY KEY,
  paso INTEGER NOT NULL,
  archivo TEXT NOT NULL,
  ruta TEXT NOT NULL,
  tipo TEXT NOT NULL,                   -- png, csv, json, txt
  tamaño_bytes INTEGER,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_graficos_info_paso ON graficos_info (paso);

-- ------------------------------------------------------------------------------
-- 9. VISTAS ÚTILES
-- ------------------------------------------------------------------------------

-- Vista: resumen de sentimientos por ejecución
CREATE OR REPLACE VIEW v_resumen_sentimientos AS
SELECT
  e.id AS ejecucion_id,
  e.fecha,
  e.responsable,
  s.nombre AS sentimiento,
  AVG(spm.pct) AS nivel_promedio,
  COUNT(*) AS n_mensajes_con_sentimiento
FROM ejecuciones e
JOIN sentimientos_por_mensaje spm ON spm.id_mensaje = (
  SELECT ml.id_mensaje FROM mensajes_limpios ml WHERE ml.chat_id = spm.chat_id LIMIT 1
)
JOIN sentimientos s ON s.nombre = spm.sentimiento
GROUP BY e.id, e.fecha, e.responsable, s.nombre;

-- Vista: resumen de ejecución con conteos
CREATE OR REPLACE VIEW v_ejecucion_resumen AS
SELECT
  e.id,
  e.fecha,
  e.responsable,
  e.archivo,
  e.estado,
  e.registros_leidos,
  e.mensajes_limpios,
  e.mensajes_excluidos,
  e.emojis_pendientes,
  COUNT(DISTINCT c.id) AS n_cambios
FROM ejecuciones e
LEFT JOIN cambios c ON c.ejecucion_prueba LIKE '%' || e.id || '%'
GROUP BY e.id, e.fecha, e.responsable, e.archivo, e.estado, e.registros_leidos, e.mensajes_limpios, e.mensajes_excluidos, e.emojis_pendientes;

-- ==============================================================================
-- COMENTARIOS DE TABLAS PARA DOCUMENTACIÓN (pgAdmin leerá estos comentarios)
-- ==================================================================-------------

COMMENT ON TABLE codigos_materia IS 'Prefijos de códigos de materia (INF, MAT, LAB...) para agrupar tokens por materia.';
COMMENT ON TABLE abreviaturas IS 'Abreviaturas de chat y su forma normal para normalización léxica.';
COMMENT ON TABLE emojis IS 'Diccionario maestro de emojis con significado, sentimiento y polaridad.';
COMMENT ON TABLE sentimientos IS 'Diccionario propio de 15 sentimientos con palabras, raíces y estado activo.';
COMMENT ON TABLE sentimientos_palabras IS 'Relación muchos a muchos entre sentimientos y palabras del diccionario.';
COMMENT ON TABLE sentimientos_raices IS 'Relación muchos a muchos entre sentimientos y raíces de palabras.';
COMMENT ON TABLE mensajes_limpios IS 'Dataset limpio final: una fila por mensaje procesado con todas las variables derivadas.';
COMMENT ON TABLE sentimientos_por_mensaje IS 'Nivel de sentimiento (%) por mensaje y sentimiento activo.';
COMMENT ON TABLE tokens IS 'Tokens por mensaje para TF-IDF, n-gramas y LDA.';
COMMENT ON TABLE niveles_por_periodo IS 'Nivel promedio de cada sentimiento por período de análisis.';
COMMENT ON TABLE serie_sentimientos IS 'Serie temporal de sentimientos (por mes/semana/día).';
COMMENT ON TABLE tfidf_resultados IS 'Resultados TF-IDF por documento y término.';
COMMENT ON TABLE ejecuciones IS 'Registro de cada ejecución del pipeline preprocesar().';
COMMENT ON TABLE ejecucion_pasos IS 'Detalle de cada paso ejecutado dentro de una ejecución.';
COMMENT ON TABLE cambios IS 'Cambios detectados automáticamente en código y diccionarios (vigilar_cambios).';
COMMENT ON TABLE experimentos IS 'Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería).';

-- ==============================================================================
-- EJEMPLOS DE CONSULTAS ÚTILES
-- ==============================================================================

-- Sentimientos activos en el diccionario
-- SELECT nombre, polaridad, definicion FROM sentimientos WHERE activo = TRUE ORDER BY orden;

-- Nivel de sentimientos en un periodo específico
-- SELECT sentimiento, nivel_pct, mensajes_pct FROM niveles_por_periodo WHERE periodo = '2023-01-01_a_2023-03-31' ORDER BY nivel_pct DESC;

-- Evolución de un sentimiento en el tiempo
-- SELECT fecha, pct FROM serie_sentimientos WHERE periodo = '2023' AND sentimiento = 'alegria' ORDER BY fecha;

-- Top 10 palabras más distintivas por TF-IDF en un periodo
-- SELECT doc, token, tf_idf FROM tfidf_resultados WHERE periodo = 'todo_2023' ORDER BY tf_idf DESC LIMIT 10;

-- Últimas 10 ejecuciones del pipeline
-- SELECT id, fecha, responsable, estado, registros_leidos, mensajes_limpios FROM ejecuciones ORDER BY fecha DESC LIMIT 10;

-- Cambios sin justificar en la bitácora
-- SELECT id, archivo, detalle FROM cambios WHERE estado_registro = 'FALTA JUSTIFICAR';

-- Mensajes con sentimiento dominante por periodo
-- SELECT genero_mencionado, COUNT(*) as n FROM mensajes_limpios WHERE fecha BETWEEN '2023-01-01' AND '2023-03-31' GROUP BY genero_mencionado;
