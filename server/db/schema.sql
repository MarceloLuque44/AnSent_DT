-- Esquema inicial de la bitacora
CREATE TABLE IF NOT EXISTS bitacora_registros (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,                 -- ISO 8601
  tipo_cambio TEXT NOT NULL,           -- ej: 'preprocesamiento', 'limpieza', 'ingesta'
  descripcion TEXT NOT NULL,
  filas_afectadas INTEGER,
  columnas_afectadas TEXT,             -- CSV o JSON de nombres de columnas
  version_dataset INTEGER,             -- contador de versiones del dataset
  resumen_estadistico TEXT,            -- JSON libre (medias, nulos, etc.)
  creado_por TEXT DEFAULT 'R-Plumber'
);

CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora_registros (fecha DESC);
