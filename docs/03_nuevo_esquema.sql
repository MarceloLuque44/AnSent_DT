-- ==============================================================================
-- 03_nuevo_esquema.sql
-- Datos del análisis (objeto `a` de analizar_periodo) para el dashboard.
--
-- Ejecuta este script en Postgres/Supabase. Es destructivo: borra las tablas
-- analisis y analisis_nivel antes de crearlas de cero.
-- ==============================================================================

DROP TABLE IF EXISTS public.analisis_nivel CASCADE;
DROP TABLE IF EXISTS public.analisis CASCADE;

-- Cabecera: un registro por periodo analizado.
CREATE TABLE public.analisis (
  id_analisis  SERIAL PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL UNIQUE,
  fecha_inicio DATE NOT NULL,
  fecha_fin    DATE NOT NULL,
  n_mensajes   INTEGER,
  responsable  VARCHAR(200),
  creado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Detalle: nivel de cada sentimiento dentro de un periodo (lo consume g_barras).
CREATE TABLE public.analisis_nivel (
  id           BIGSERIAL PRIMARY KEY,
  id_analisis  INTEGER NOT NULL REFERENCES public.analisis(id_analisis) ON DELETE CASCADE,
  sentimiento  VARCHAR(50) NOT NULL,
  nivel_pct    NUMERIC(6,3) NOT NULL CHECK (nivel_pct BETWEEN 0 AND 100),
  mensajes_pct NUMERIC(6,3),
  n_mensajes   INTEGER,
  orden        INTEGER,
  UNIQUE (id_analisis, sentimiento)
);

CREATE INDEX idx_analisis_nivel_analisis ON public.analisis_nivel(id_analisis);

COMMENT ON TABLE public.analisis IS 'Cabecera de cada análisis por periodo (objeto a de analizar_periodo).';
COMMENT ON TABLE public.analisis_nivel IS 'Nivel por sentimiento que consume el gráfico de barras del dashboard.';
