-- ==============================================================================
-- Script 01: Tablas de bitácora de ejecuciones y pasos
-- Esquema: public | Motor: PostgreSQL
-- Dependencias: ninguna (tablas base)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Tabla: ejecuciones
-- Registro de cada ejecución del pipeline preprocesar().
-- PK: id_ejecucion (secuencia ejecuciones_id_seq)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ejecuciones (
    id_ejecucion integer NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    responsable character varying(200),
    archivo character varying(200),
    archivo_md5 character varying(64),
    evento character varying(50),
    parametros text,
    estado character varying(20),
    paso_donde_paro character varying(100),
    mensaje_error text,
    pasos_registrados integer DEFAULT 0,
    registros_leidos integer,
    mensajes_limpios integer,
    mensajes_excluidos integer,
    emojis_pendientes integer DEFAULT 0,
    cambios_detectados text
);

ALTER TABLE public.ejecuciones OWNER TO postgres;

CREATE SEQUENCE IF NOT EXISTS public.ejecuciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.ejecuciones_id_seq OWNER TO postgres;
ALTER SEQUENCE public.ejecuciones_id_seq OWNED BY public.ejecuciones.id_ejecucion;

ALTER TABLE ONLY public.ejecuciones ALTER COLUMN id_ejecucion SET DEFAULT nextval('public.ejecuciones_id_seq'::regclass);

ALTER TABLE ONLY public.ejecuciones
    ADD CONSTRAINT ejecuciones_pkey PRIMARY KEY (id_ejecucion);

CREATE INDEX IF NOT EXISTS idx_ejecuciones_fecha ON public.ejecuciones (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_ejecuciones_estado ON public.ejecuciones (estado);

COMMENT ON TABLE public.ejecuciones IS 'Registro de cada ejecución del pipeline preprocesar().';

-- ------------------------------------------------------------------------------
-- Tabla: ejecucion_pasos
-- Detalle de cada paso ejecutado dentro de una ejecución (bitácora limpia).
-- PK: id (secuencia ejecucion_pasos_id_seq)
-- FK: ejecucion_id -> ejecuciones.id_ejecucion
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ejecucion_pasos (
    id integer NOT NULL,
    ejecucion_id integer NOT NULL,
    id_instancia character varying(50),
    id_paso character varying(20),
    etapa character varying(100),
    campo_columna character varying(100),
    tipo_problema character varying(100),
    accion_realizada text,
    filas_antes integer,
    filas_despues integer,
    filas_afectadas integer,
    impacto_dataset text,
    ejemplo_antes text,
    ejemplo_despues text,
    mensaje_error text,
    script text
);

ALTER TABLE public.ejecucion_pasos OWNER TO postgres;

CREATE SEQUENCE IF NOT EXISTS public.ejecucion_pasos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.ejecucion_pasos_id_seq OWNER TO postgres;
ALTER SEQUENCE public.ejecucion_pasos_id_seq OWNED BY public.ejecucion_pasos.id;

ALTER TABLE ONLY public.ejecucion_pasos ALTER COLUMN id SET DEFAULT nextval('public.ejecucion_pasos_id_seq'::regclass);

ALTER TABLE ONLY public.ejecucion_pasos
    ADD CONSTRAINT ejecucion_pasos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ejecucion_pasos
    ADD CONSTRAINT ejecucion_pasos_ejecucion_id_fkey
    FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion);

CREATE INDEX IF NOT EXISTS idx_ejecucion_pasos_ejecucion ON public.ejecucion_pasos (ejecucion_id);

COMMENT ON TABLE public.ejecucion_pasos IS 'Detalle de cada paso ejecutado dentro de una ejecución.';

-- ------------------------------------------------------------------------------
-- Datos de ejemplo (bitácora de ejecución P01 y P02)
-- ------------------------------------------------------------------------------

INSERT INTO public.ejecuciones (
    id_ejecucion, fecha, responsable, archivo, archivo_md5, evento,
    parametros, estado, paso_donde_paro, mensaje_error, pasos_registrados,
    registros_leidos, mensajes_limpios, mensajes_excluidos, emojis_pendientes, cambios_detectados
) VALUES
(
    1,
    '2026-11-04 11:25:15',
    NULL,
    'result.json',
    NULL,
    'primera ejecución',
    '{"ruta_archivo":"data/result.json","fecha_inicio":null,"fecha_fin":null,"responsable":null,"dir_config":"config","dir_salida":"salida","dir_bitacoras":"bitacoras","sentimientos_activos":null,"excluir_publicidad":true,"umbral_publicidad":4,"anonimizar_autor":true,"min_chars_duplicado":25,"nuevos_emojis":"marcar","consola":"resumen","csv_para_excel":true}',
    'ok',
    NULL,
    NULL,
    2,
    27492,
    27492,
    0,
    0,
    NULL
)
ON CONFLICT (id_ejecucion) DO NOTHING;

-- Paso P01: Auditoría y perfilado inicial (volumen y rango temporal)
INSERT INTO public.ejecucion_pasos (
    id, ejecucion_id, id_instancia, id_paso, etapa, campo_columna, tipo_problema,
    accion_realizada, justificacion, filas_afectadas, impacto_dataset, script,
    filas_antes, filas_despues, ejemplo_antes, ejemplo_despues, id_mensaje_ejemplo, responsable
) VALUES
(
    1,
    1,
    '1-P01',
    'P01',
    '1. Auditoría y perfilado inicial',
    '(todo el dataset)',
    'estructura',
    'Se leyeron 27,492 registros del archivo ''result.json''. Rango de fechas: 2022-12-17 a 2026-11-03.',
    'Todo preprocesamiento parte de conocer el tamaño y el periodo cubierto, para poder medir el impacto de cada paso y recortar por periodos.',
    27492,
    '27,492 de 27,492 (100.0%); sin modificar datos',
    'nrow(d)',
    27492,
    27492,
    NULL,
    NULL,
    NULL,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- Paso P02: Registros que no son mensajes (servicio)
INSERT INTO public.ejecucion_pasos (
    id, ejecucion_id, id_instancia, id_paso, etapa, campo_columna, tipo_problema,
    accion_realizada, justificacion, filas_afectadas, impacto_dataset, script,
    filas_antes, filas_despues, ejemplo_antes, ejemplo_despues, id_mensaje_ejemplo, responsable
) VALUES
(
    2,
    1,
    '1-P02',
    'P02',
    '1. Auditoría y perfilado inicial',
    'type / action',
    'categórica',
    'Se contaron los registros de servicio de Telegram (altas por enlace, invitaciones, fijados, cambios del grupo). Se separan más adelante.',
    'No contienen opinión ni sentimiento de los participantes; mantenerlos sesgaría las frecuencias y los periodos.',
    3994,
    '3,994 de 27,492 (14.5%); sin modificar datos',
    'sum(d$tipo_registro != "message")',
    27492,
    27492,
    NULL,
    NULL,
    NULL,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- Fin del script 01
-- ==============================================================================
