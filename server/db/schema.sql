-- Esquema de la bitacora y configuraciones del frontend
CREATE TABLE IF NOT EXISTS bitacora_registros (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,
  tipo_cambio TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  filas_afectadas INTEGER,
  columnas_afectadas TEXT,
  version_dataset INTEGER,
  resumen_estadistico TEXT,
  creado_por TEXT DEFAULT 'R-Plumber'
);

CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora_registros (fecha DESC);

CREATE TABLE IF NOT EXISTS configuraciones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  paso INTEGER NOT NULL,
  parametros TEXT NOT NULL,
  creado_en TEXT NOT NULL,
  actualizado_en TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_configuraciones_paso ON configuraciones (paso);

CREATE TABLE IF NOT EXISTS graficos_info (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paso INTEGER NOT NULL,
  archivo TEXT NOT NULL,
  ruta TEXT NOT NULL,
  tipo TEXT NOT NULL,
  tamaño_bytes INTEGER,
  creado_en TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_graficos_info_paso ON graficos_info (paso);
