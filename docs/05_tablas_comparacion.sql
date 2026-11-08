-- ==============================================================================
-- 05_tablas_comparacion.sql
-- Cabecera de las comparaciones entre dos periodos (gráfico de barras
-- agrupadas y demás gráficos de comparación).
--
-- No borra ni modifica datos: solo crea la tabla si no existe.
-- Los niveles de cada periodo siguen viviendo en public.analisis_nivel.
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.analisis_comparacion (
  id_comparacion SERIAL PRIMARY KEY,
  nombre         VARCHAR(200) NOT NULL UNIQUE,
  id_analisis_a  INTEGER NOT NULL REFERENCES public.analisis(id_analisis),
  id_analisis_b  INTEGER NOT NULL REFERENCES public.analisis(id_analisis),
  creado_en      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CHECK (id_analisis_a <> id_analisis_b),
  UNIQUE (id_analisis_a, id_analisis_b)
);

CREATE INDEX IF NOT EXISTS idx_analisis_comparacion_a
  ON public.analisis_comparacion(id_analisis_a);

CREATE INDEX IF NOT EXISTS idx_analisis_comparacion_b
  ON public.analisis_comparacion(id_analisis_b);

COMMENT ON TABLE public.analisis_comparacion
  IS 'Cabecera de una comparación A vs B; los niveles están en analisis_nivel.';

COMMIT;

-- Verificación
SELECT id_comparacion, nombre, id_analisis_a, id_analisis_b, creado_en
FROM public.analisis_comparacion
ORDER BY creado_en DESC;
