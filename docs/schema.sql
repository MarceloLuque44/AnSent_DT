-- ==============================================================================
-- Esquema de base de datos para el backend Express de AnSent
-- Se aplica automaticamente al iniciar el servidor (server/db/sqlite.js)
-- ==============================================================================

-- Tabla de bitacora de cambios del dataset (registros que Plumber/Express escriben)
CREATE TABLE IF NOT EXISTS bitacora_registros (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,                 -- ISO 8601
  tipo_cambio TEXT NOT NULL,           -- ej: 'preprocesamiento', 'analisis_periodo', 'comparacion_periodos', 'analisis_oracion'
  descripcion TEXT NOT NULL,
  filas_afectadas INTEGER,
  columnas_afectadas TEXT,             -- JSON de nombres de columnas
  version_dataset INTEGER,             -- contador de versiones del dataset
  resumen_estadistico TEXT,            -- JSON libre (medias, nulos, niveles, interpretacion, etc.)
  creado_por TEXT DEFAULT 'R-Plumber'
);

CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora_registros (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_bitacora_tipo ON bitacora_registros (tipo_cambio);

-- Tabla de configuraciones guardadas desde el frontend (formularios de los 4 pasos)
CREATE TABLE IF NOT EXISTS configuraciones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,                -- nombre dado por el usuario
  paso INTEGER NOT NULL,               -- 1=preprocesar, 2=analizar-periodo, 3=comparar-periodos, 4=analizar-oracion
  parametros TEXT NOT NULL,            -- JSON con los parametros del formulario
  creado_en TEXT NOT NULL,             -- ISO 8601
  actualizado_en TEXT NOT NULL         -- ISO 8601
);

CREATE INDEX IF NOT EXISTS idx_configuraciones_paso ON configuraciones (paso);
CREATE INDEX IF NOT EXISTS idx_configuraciones_actualizado ON configuraciones (actualizado_en DESC);

-- Tabla de archivos generados por cada paso (rutas en memoria para el frontend)
CREATE TABLE IF NOT EXISTS graficos_info (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paso INTEGER NOT NULL,               -- paso al que pertenece el archivo
  archivo TEXT NOT NULL,               -- nombre del archivo
  ruta TEXT NOT NULL,                  -- ruta en memoria (sistema de archivos del servidor)
  tipo TEXT NOT NULL,                  -- 'png', 'csv', 'json', 'txt', etc.
  tamaño_bytes INTEGER,                -- tamaño en bytes (opcional)
  creado_en TEXT NOT NULL              -- ISO 8601
);

CREATE INDEX IF NOT EXISTS idx_graficos_info_paso ON graficos_info (paso);
CREATE INDEX IF NOT EXISTS idx_graficos_info_tipo ON graficos_info (tipo);

-- ==============================================================================
-- Ejemplos de consultas utiles
-- ==============================================================================

-- Listar configuraciones de un paso
-- SELECT * FROM configuraciones WHERE paso = 2 ORDER BY actualizado_en DESC;

-- Listar imagenes PNG de un paso para renderizar en el frontend
-- SELECT * FROM graficos_info WHERE paso = 2 AND tipo = 'png' ORDER BY creado_en DESC;

-- Listar CSV de un paso
-- SELECT * FROM graficos_info WHERE paso = 2 AND tipo = 'csv' ORDER BY creado_en DESC;

-- Ultimo registro de bitacora
-- SELECT * FROM bitacora_registros ORDER BY fecha DESC, id DESC LIMIT 1;

-- ==============================================================================
