-- ==============================================================================
-- Script 08: Tablas de bitácora de ejecuciones, pasos y experimentos
-- Esquema: public | Motor: PostgreSQL
-- Dependencias: ninguna (tablas base).
-- Notas: se crea en documento separado para no modificar Esquema7.sql.
--        Aplicar con psql antes de ejecutar preprocesar() desde R.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Tabla: ejecuciones
-- Cabecera de cada ejecucion del pipeline preprocesar() (bitacora completa).
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

COMMENT ON TABLE public.ejecuciones IS 'Registro de cada ejecucion del pipeline preprocesar() (bitacora completa).';

-- ------------------------------------------------------------------------------
-- Tabla: ejecucion_pasos
-- Detalle de cada paso ejecutado dentro de una ejecucion (bitacora completa).
-- PK: id (secuencia ejecucion_pasos_id_seq)
-- FK: ejecucion_id -> ejecuciones.id_ejecucion (ON DELETE CASCADE)
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
    FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_ejecucion_pasos_ejecucion ON public.ejecucion_pasos (ejecucion_id);

COMMENT ON TABLE public.ejecucion_pasos IS 'Detalle de cada paso ejecutado dentro de una ejecucion (bitacora completa).';

-- ------------------------------------------------------------------------------
-- Tabla: experimentos
-- Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería).
-- PK: id (secuencia experimentos_id_seq)
-- FK: id_ejecucion_preprocesamiento -> ejecuciones.id_ejecucion (ON DELETE CASCADE)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.experimentos (
    id integer NOT NULL,
    fecha date,
    hora time without time zone,
    id_ejecucion_preprocesamiento integer,
    dataset character varying(200),
    dataset_md5 character varying(64),
    metodo character varying(100),
    parametros text,
    n_documentos integer,
    tamano_vocabulario integer,
    resultado_principal text,
    archivo_resultado character varying(200),
    notas text,
    responsable character varying(200)
);

ALTER TABLE public.experimentos OWNER TO postgres;

CREATE SEQUENCE IF NOT EXISTS public.experimentos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.experimentos_id_seq OWNER TO postgres;
ALTER SEQUENCE public.experimentos_id_seq OWNED BY public.experimentos.id;

ALTER TABLE ONLY public.experimentos ALTER COLUMN id SET DEFAULT nextval('public.experimentos_id_seq'::regclass);

ALTER TABLE ONLY public.experimentos
    ADD CONSTRAINT experimentos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.experimentos
    ADD CONSTRAINT experimentos_id_ejecucion_preprocesamiento_fkey
    FOREIGN KEY (id_ejecucion_preprocesamiento) REFERENCES public.ejecuciones(id_ejecucion) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_experimentos_ejecucion ON public.experimentos (id_ejecucion_preprocesamiento);

COMMENT ON TABLE public.experimentos IS 'Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería).';

-- ==============================================================================
-- Fin del script 08
-- ==============================================================================
