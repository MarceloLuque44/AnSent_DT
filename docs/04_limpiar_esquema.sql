-- ==============================================================================
-- 04_limpiar_esquema.sql
-- Deja en Postgres SOLO las tablas que usa el frontend actual:
--   public.cambios        (vistas Cambios y Bitácora)
--   public.analisis       (vista Dashboard)
--   public.analisis_nivel (vista Dashboard)
--
-- NO borra ni modifica los datos de esas tres tablas.
-- Borra las 36 tablas y 2 vistas que hoy no usa ninguna ruta montada.
-- Es idempotente: se puede ejecutar varias veces.
-- ==============================================================================

BEGIN;

-- 1) Vistas legacy (dependen de tablas que se van a borrar)
DROP VIEW IF EXISTS public.v_resumen_sentimientos;
DROP VIEW IF EXISTS public.v_ejecucion_resumen;

-- 2) Tablas sin uso actual
DROP TABLE IF EXISTS public.salida_emojis_en_uso          CASCADE;
DROP TABLE IF EXISTS public.salida_stopwords_aplicadas    CASCADE;
DROP TABLE IF EXISTS public.salida_mensajes_excluidos     CASCADE;
DROP TABLE IF EXISTS public.salida_resumen                CASCADE;
DROP TABLE IF EXISTS public.topicos_por_documento         CASCADE;
DROP TABLE IF EXISTS public.topicos_terminos              CASCADE;
DROP TABLE IF EXISTS public.topicos_etiquetas             CASCADE;
DROP TABLE IF EXISTS public.topicos                       CASCADE;
DROP TABLE IF EXISTS public.tfidf_resultados              CASCADE;
DROP TABLE IF EXISTS public.serie_sentimientos            CASCADE;
DROP TABLE IF EXISTS public.niveles_por_periodo           CASCADE;
DROP TABLE IF EXISTS public.comparacion_niveles           CASCADE;
DROP TABLE IF EXISTS public.libreria_sentimientos         CASCADE;
DROP TABLE IF EXISTS public.sentimientos_por_mensaje      CASCADE;
DROP TABLE IF EXISTS public.tokens                        CASCADE;
DROP TABLE IF EXISTS public.mensajes_limpios              CASCADE;
DROP TABLE IF EXISTS public.mensajes_crudos               CASCADE;
DROP TABLE IF EXISTS public.chats                         CASCADE;
DROP TABLE IF EXISTS public.sentimientos_raices           CASCADE;
DROP TABLE IF EXISTS public.sentimientos_palabras         CASCADE;
DROP TABLE IF EXISTS public.sentimientos                  CASCADE;
DROP TABLE IF EXISTS public.palabras_anuncio              CASCADE;
DROP TABLE IF EXISTS public.periodos                      CASCADE;
DROP TABLE IF EXISTS public.stopwords                     CASCADE;
DROP TABLE IF EXISTS public.justificaciones_analisis      CASCADE;
DROP TABLE IF EXISTS public.genero                        CASCADE;
DROP TABLE IF EXISTS public.emojis                        CASCADE;
DROP TABLE IF EXISTS public.emoticonos                    CASCADE;
DROP TABLE IF EXISTS public.abreviaturas                  CASCADE;
DROP TABLE IF EXISTS public.codigos_materia               CASCADE;
DROP TABLE IF EXISTS public.ejecucion_pasos               CASCADE;
DROP TABLE IF EXISTS public.ejecuciones                   CASCADE;
DROP TABLE IF EXISTS public.experimentos                  CASCADE;
DROP TABLE IF EXISTS public.bitacora_registros            CASCADE;
DROP TABLE IF EXISTS public.configuraciones               CASCADE;
DROP TABLE IF EXISTS public.graficos_info                 CASCADE;

-- 3) Crear las tablas en uso solo si faltan (nunca borra datos)
CREATE TABLE IF NOT EXISTS public.cambios (
  id SERIAL PRIMARY KEY,
  fecha DATE,
  hora TIME,
  tipo VARCHAR(20),
  archivo VARCHAR(200),
  seccion VARCHAR(100),
  problema_detectado TEXT,
  como_se_detecto TEXT,
  cambio_realizado TEXT,
  justificacion TEXT,
  resultado TEXT,
  ejecucion_prueba TEXT,
  responsable VARCHAR(200),
  estado_registro VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS public.analisis (
  id_analisis  SERIAL PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL UNIQUE,
  fecha_inicio DATE NOT NULL,
  fecha_fin    DATE NOT NULL,
  n_mensajes   INTEGER,
  responsable  VARCHAR(200),
  creado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.analisis_nivel (
  id           BIGSERIAL PRIMARY KEY,
  id_analisis  INTEGER NOT NULL REFERENCES public.analisis(id_analisis) ON DELETE CASCADE,
  sentimiento  VARCHAR(50) NOT NULL,
  nivel_pct    NUMERIC(6,3) NOT NULL CHECK (nivel_pct BETWEEN 0 AND 100),
  mensajes_pct NUMERIC(6,3),
  n_mensajes   INTEGER,
  orden        INTEGER,
  UNIQUE (id_analisis, sentimiento)
);

CREATE INDEX IF NOT EXISTS idx_analisis_nivel_analisis
  ON public.analisis_nivel(id_analisis);

COMMIT;

-- 4) Verificación: deben quedar solo estas 3 tablas
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 5) Conteos para confirmar que no se perdió nada
SELECT 'cambios'        AS tabla, count(*) FROM public.cambios
UNION ALL
SELECT 'analisis',       count(*) FROM public.analisis
UNION ALL
SELECT 'analisis_nivel', count(*) FROM public.analisis_nivel;
