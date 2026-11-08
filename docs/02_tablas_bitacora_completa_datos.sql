-- ==============================================================================
-- Script 02: Tablas de bitácora completa y datos de ejemplo
-- Esquema: public | Motor: PostgreSQL
-- Dependencias: requiere que exista la tabla ejecuciones (creada en script 01
--               o en Esquema1.sql).
--               Las claves primarias y foráneas ya están definidas en
--               Esquema1.sql; este script solo crea las tablas (si faltan) y
--               carga los datos de ejemplo.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Tabla: cambios
-- Bitácora completa: cambios detectados en código y diccionarios (vigilar_cambios)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cambios (
    id integer NOT NULL,
    fecha date,
    hora time without time zone,
    tipo character varying(20),
    archivo character varying(200),
    seccion character varying(100),
    problema_detectado text,
    como_se_detecto text,
    cambio_realizado text,
    justificacion text,
    resultado text,
    ejecucion_prueba text,
    responsable character varying(200),
    estado_registro character varying(30)
);

ALTER TABLE public.cambios OWNER TO postgres;

CREATE SEQUENCE IF NOT EXISTS public.cambios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.cambios_id_seq OWNER TO postgres;
ALTER SEQUENCE public.cambios_id_seq OWNED BY public.cambios.id;

ALTER TABLE ONLY public.cambios ALTER COLUMN id SET DEFAULT nextval('public.cambios_id_seq'::regclass);

COMMENT ON TABLE public.cambios IS 'Cambios detectados automáticamente en código y diccionarios (vigilar_cambios).';

-- ------------------------------------------------------------------------------
-- Tabla: experimentos
-- Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería)
-- FK: id_ejecucion_preprocesamiento -> ejecuciones.id_ejecucion
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

COMMENT ON TABLE public.experimentos IS 'Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería).';

-- ------------------------------------------------------------------------------
-- Tabla: ejecuciones
-- Registro de cada ejecución del pipeline preprocesar().
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

CREATE INDEX IF NOT EXISTS idx_ejecuciones_fecha ON public.ejecuciones (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_ejecuciones_estado ON public.ejecuciones (estado);

COMMENT ON TABLE public.ejecuciones IS 'Registro de cada ejecución del pipeline preprocesar().';

-- ------------------------------------------------------------------------------
-- Tabla: ejecucion_pasos
-- Detalle de cada paso ejecutado dentro de una ejecución (bitácora limpia).
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

CREATE INDEX IF NOT EXISTS idx_ejecucion_pasos_ejecucion ON public.ejecucion_pasos (ejecucion_id);

COMMENT ON TABLE public.ejecucion_pasos IS 'Detalle de cada paso ejecutado dentro de una ejecución.';

-- ==============================================================================
-- DATOS DE EJEMPLO
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- EJECUCIONES (E001, E002)
-- ------------------------------------------------------------------------------
INSERT INTO public.ejecuciones (
    id_ejecucion, fecha, responsable, archivo, archivo_md5, evento,
    parametros, estado, paso_donde_paro, mensaje_error,
    pasos_registrados, registros_leidos, mensajes_limpios, mensajes_excluidos,
    emojis_pendientes, cambios_detectados
) VALUES
(
    'E001',
    '2026-10-20',
    'Patricia',
    'result.json',
    'e517fcbf',
    'primera ejecución',
    '{"periodo":"inicio a fin","umbral_publicidad":4,"sentimientos":"todos los activos","anonimizar":TRUE,"emojis_nuevos":"marcar"}',
    'ok',
    NULL,
    NULL,
    48,
    26030,
    19496,
    6534,
    0,
    'C33, C34, C35'
),
(
    'E002',
    '2026-10-20',
    'Patricia',
    'result.json',
    'e517fcbf',
    'mismo dataset (reejecución)',
    '{"periodo":"inicio a fin","umbral_publicidad":4,"sentimientos":"todos los activos","anonimizar":TRUE,"emojis_nuevos":"marcar"}',
    'ok',
    NULL,
    NULL,
    48,
    26030,
    19496,
    6534,
    0,
    'C36'
)
ON CONFLICT (id_ejecucion) DO NOTHING;

-- ------------------------------------------------------------------------------
-- CAMBIOS (C01, C02) - Bitácora completa
-- ------------------------------------------------------------------------------
INSERT INTO public.cambios (
    id, fecha, hora, tipo, archivo, seccion, problema_detectado, como_se_detecto,
    cambio_realizado, justificacion, resultado, ejecucion_prueba, responsable, estado_registro
) VALUES
(
    'C01',
    '2026-10-20',
    '17:04:56',
    'código',
    'R/02_estructura.R; excluir() en R/bitacora.R',
    '2.3 Mensajes de servicio',
    'mensajes_excluidos.csv salía con 12 millones de filas.',
    'Por el tamaño anómalo de mensajes_excluidos.csv.',
    'Se corrigió el bug en la función excluir().',
    'Cada fila excluida debe quedar una sola vez con su motivo; si no, la trazabilidad no sirve.',
    'Corregido (según la nota del código) → ok',
    'histórico → E001',
    'equipo',
    'completo'
),
(
    'C02',
    '2026-10-20',
    '17:04:58',
    'código',
    'R/00_main.R; R/02_estructura.R',
    '2.5 Recorte por periodo',
    'fecha_inicio/fecha_fin vacíos se convertían en texto y as.Date() fallaba.',
    NULL,
    'Los parámetros vacíos se dejan como NULL (antes se volvían texto).',
    'Permite ejecutar sin límite de fechas sin romper el recorte por periodo.',
    'Corregido (según la nota del código) → ok',
    'histórico → E001',
    'equipo',
    'completo'
)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- PASOS POR EJECUCION (E001-P01, E001-P02)
-- ------------------------------------------------------------------------------
INSERT INTO public.ejecucion_pasos (
    id, ejecucion_id, id_instancia, id_paso, etapa, campo_columna, tipo_problema,
    accion_realizada, justificacion, filas_antes, filas_despues, filas_afectadas,
    impacto_dataset, ejemplo_antes, ejemplo_despues, mensaje_error, script, responsable
) VALUES
(
    1,
    'E001',
    'E001-P01',
    'P01',
    '1. Auditoría y perfilado inicial',
    '(todo el dataset)',
    'Volumen y rango temporal',
    'Se leyeron 26,030 registros del archivo ''result.json''. Rango de fechas: 2022-12-26 a 2026-10-20.',
    'Todo preprocesamiento parte de conocer el tamaño y el periodo cubierto, para poder medir el impacto de cada paso y recortar por periodos.',
    26030,
    26030,
    26030,
    '26,030 de 26,030 (100.0%); sin modificar datos',
    NULL,
    NULL,
    NULL,
    'nrow(d)',
    NULL
),
(
    2,
    'E001',
    'E001-P02',
    'P02',
    '1. Auditoría y perfilado inicial',
    'type / action',
    'Registros que no son mensajes (servicio)',
    'Se contaron los registros de servicio de Telegram (altas por enlace, invitaciones, fijados, cambios del grupo). Se separan más adelante.',
    'No contienen opinión ni sentimiento de los participantes; mantenerlos sesgaría las frecuencias y los periodos.',
    26030,
    26030,
    3466,
    '3,466 de 26,030 (13.3%); sin modificar datos',
    NULL,
    NULL,
    NULL,
    'sum(d$tipo_registro != "message")',
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- EXPERIMENTOS (X001, X002)
-- ------------------------------------------------------------------------------
INSERT INTO public.experimentos (
    id, fecha, hora, id_ejecucion_preprocesamiento, dataset, dataset_md5, metodo,
    parametros, n_documentos, tamano_vocabulario, resultado_principal, archivo_resultado,
    notas, responsable
) VALUES
(
    'X001',
    '2026-10-25',
    '17:00:15',
    'E020',
    'result.json',
    'e517fcbf',
    'tfidf',
    'periodo=2023-01-01 a 2023-03-31; documentos=meses',
    3,
    734,
    'top: hoy, no, documentos, matricula, pasar',
    NULL,
    NULL,
    NULL
),
(
    'X002',
    '2026-10-25',
    '17:00:18',
    'E020',
    'result.json',
    'e517fcbf',
    'topic modeling (LDA)',
    'periodo=2023-01-01 a 2023-03-31; k=6; documentos=dia',
    18,
    122,
    'materia / hoy / grupo || disculpen / semestre / mañana || no / materias / calculo || gracias / dia / dinero || carrera / informatica / virtual || piso / documentos / compañeros',
    NULL,
    NULL,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- Fin del script 02
-- ==============================================================================
