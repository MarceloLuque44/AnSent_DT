--
-- Script de corrección de constraints FK con ON UPDATE CASCADE ON DELETE CASCADE
-- Generado a partir de docs/Esquemas/Esquema10.sql
-- Solo se modifican las FK que no tenían cascade en update y delete.
--
-- Tablas afectadas:
--   public.analisis_comparacion (id_analisis_a, id_analisis_b)
--
-- Las demás FK ya poseen ON DELETE CASCADE; estas dos no poseían acción alguna.
 --
 --
 -- FK: analisis_comparacion_id_analisis_a_fkey
 -- Referencia: public.analisis(id_analisis)
 --
 ALTER TABLE ONLY public.analisis_comparacion
     DROP CONSTRAINT analisis_comparacion_id_analisis_a_fkey,
     ADD CONSTRAINT analisis_comparacion_id_analisis_a_fkey
     FOREIGN KEY (id_analisis_a) REFERENCES public.analisis(id_analisis)
     ON UPDATE CASCADE
     ON DELETE CASCADE;
 --
 -- FK: analisis_comparacion_id_analisis_b_fkey
 -- Referencia: public.analisis(id_analisis)
 --
 ALTER TABLE ONLY public.analisis_comparacion
     DROP CONSTRAINT analisis_comparacion_id_analisis_b_fkey,
     ADD CONSTRAINT analisis_comparacion_id_analisis_b_fkey
     FOREIGN KEY (id_analisis_b) REFERENCES public.analisis(id_analisis)
     ON UPDATE CASCADE
     ON DELETE CASCADE;
