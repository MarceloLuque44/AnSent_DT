--
-- Esquema 5: tablas dedicadas para los outputs de preprocesar() (API/BD + Bitácora)
-- Estilo Esquema4.sql: schema public, PK secuencial, id_ejecucion FK a
-- public.preprocesar_ejecuciones, creado_en default now(), ON DELETE CASCADE.
--

CREATE TABLE IF NOT EXISTS public.preprocesar_ejecuciones (
    id_ejecucion serial PRIMARY KEY,
    fecha date,
    hora_inicio time without time zone,
    hora_fin time without time zone,
    duracion_seg numeric,
    responsable character varying(200),
    archivo character varying(300),
    archivo_md5 character varying(32),
    registros_leidos integer,
    mensajes_limpios integer,
    mensajes_excluidos integer,
    rango_fechas_inicio date,
    rango_fechas_fin date,
    polaridad jsonb,
    estado character varying(30),
    paso_donde_paro character varying(100),
    mensaje_error text,
    pasos_registrados integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.preprocesar_ejecuciones IS 'Cabecera de cada ejecucion de preprocesar() enviada desde R.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.fecha IS 'Fecha de inicio de la ejecucion.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.hora_inicio IS 'Hora de inicio.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.hora_fin IS 'Hora de fin.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.duracion_seg IS 'Duracion en segundos.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.responsable IS 'Quien ejecuto el preprocesamiento.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.archivo IS 'Nombre del archivo de entrada.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.archivo_md5 IS 'MD5 (8 chars) del archivo de entrada.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.registros_leidos IS 'Registros leidos del archivo de entrada.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.mensajes_limpios IS 'Cantidad de mensajes limpios.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.mensajes_excluidos IS 'Cantidad de mensajes excluidos.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.rango_fechas_inicio IS 'Fecha de inicio del rango de mensajes.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.rango_fechas_fin IS 'Fecha de fin del rango de mensajes.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.polaridad IS 'Tabla de polaridad (jsonb).';
COMMENT ON COLUMN public.preprocesar_ejecuciones.estado IS 'Estado de la ejecucion (ok, detenido_emojis_pendientes, error).';
COMMENT ON COLUMN public.preprocesar_ejecuciones.paso_donde_paro IS 'Paso donde se detuvo (si no es ok).';
COMMENT ON COLUMN public.preprocesar_ejecuciones.mensaje_error IS 'Mensaje de error si fallo.';
COMMENT ON COLUMN public.preprocesar_ejecuciones.pasos_registrados IS 'Numero de pasos registrados en bitacora.';

CREATE TABLE IF NOT EXISTS public.preprocesar_mensajes_limpios (
    id bigserial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    id_mensaje character varying(100),
    fecha date,
    anio_mes character varying(7),
    autor character varying(200),
    tipo_contenido character varying(50),
    texto_limpio text,
    polaridad_msg character varying(30),
    sentimiento_dominante character varying(50),
    datos jsonb
);

COMMENT ON TABLE public.preprocesar_mensajes_limpios IS 'Mensajes limpios de una ejecucion (1 fila por mensaje). Columnas dinamicas de sentimiento van en datos (jsonb).';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.id_ejecucion IS 'Ejecucion a la que pertenece el mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.id_mensaje IS 'Identificador del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.fecha IS 'Fecha del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.anio_mes IS 'Anio-mes del mensaje (YYYY-MM).';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.autor IS 'Autor del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.tipo_contenido IS 'Tipo de contenido del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.texto_limpio IS 'Texto limpio del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.polaridad_msg IS 'Polaridad del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.sentimiento_dominante IS 'Sentimiento dominante del mensaje.';
COMMENT ON COLUMN public.preprocesar_mensajes_limpios.datos IS 'Columnas dinamicas sent_*/pct_* y resto (jsonb).';

CREATE TABLE IF NOT EXISTS public.preprocesar_mensajes_excluidos (
    id bigserial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    id_mensaje character varying(100),
    fecha date,
    motivo_exclusion character varying(100),
    datos jsonb
);

COMMENT ON TABLE public.preprocesar_mensajes_excluidos IS 'Mensajes excluidos de una ejecucion con su motivo.';
COMMENT ON COLUMN public.preprocesar_mensajes_excluidos.id_ejecucion IS 'Ejecucion a la que pertenece el mensaje excluido.';
COMMENT ON COLUMN public.preprocesar_mensajes_excluidos.id_mensaje IS 'Identificador del mensaje excluido.';
COMMENT ON COLUMN public.preprocesar_mensajes_excluidos.fecha IS 'Fecha del mensaje excluido.';
COMMENT ON COLUMN public.preprocesar_mensajes_excluidos.motivo_exclusion IS 'Motivo de la exclusion.';
COMMENT ON COLUMN public.preprocesar_mensajes_excluidos.datos IS 'Datos adicionales del mensaje excluido (jsonb).';

CREATE TABLE IF NOT EXISTS public.preprocesar_tokens (
    id bigserial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    id_mensaje character varying(100),
    fecha date,
    anio_mes character varying(7),
    token character varying(100)
);

COMMENT ON TABLE public.preprocesar_tokens IS 'Tokens de una ejecucion (1 fila por palabra). Puede ser muy grande: paginado obligatorio.';
COMMENT ON COLUMN public.preprocesar_tokens.id_ejecucion IS 'Ejecucion a la que pertenece el token.';
COMMENT ON COLUMN public.preprocesar_tokens.id_mensaje IS 'Identificador del mensaje del que proviene el token.';
COMMENT ON COLUMN public.preprocesar_tokens.fecha IS 'Fecha del mensaje.';
COMMENT ON COLUMN public.preprocesar_tokens.anio_mes IS 'Anio-mes del mensaje (YYYY-MM).';
COMMENT ON COLUMN public.preprocesar_tokens.token IS 'Token (palabra).';

CREATE TABLE IF NOT EXISTS public.preprocesar_stopwords (
    id serial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    palabra character varying(100),
    accion character varying(20),
    justificacion text
);

COMMENT ON TABLE public.preprocesar_stopwords IS 'Stopwords aplicadas en una ejecucion (palabra, accion y justificacion).';
COMMENT ON COLUMN public.preprocesar_stopwords.id_ejecucion IS 'Ejecucion a la que pertenece la stopword.';
COMMENT ON COLUMN public.preprocesar_stopwords.palabra IS 'Palabra vacia.';
COMMENT ON COLUMN public.preprocesar_stopwords.accion IS 'Accion tomada (eliminada, conservada, etc).';
COMMENT ON COLUMN public.preprocesar_stopwords.justificacion IS 'Justificacion de la accion.';

CREATE TABLE IF NOT EXISTS public.preprocesar_emojis_uso (
    id serial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    emoji character varying(20),
    en_texto integer,
    en_reacciones integer,
    significado_es character varying(200),
    sentimiento character varying(50),
    polaridad character varying(20),
    pendiente character varying(3)
);

COMMENT ON TABLE public.preprocesar_emojis_uso IS 'Emojis en uso de una ejecucion (frecuencia en texto y reacciones).';
COMMENT ON COLUMN public.preprocesar_emojis_uso.id_ejecucion IS 'Ejecucion a la que pertenece el emoji.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.emoji IS 'Emoji.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.en_texto IS 'Veces que aparece en texto.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.en_reacciones IS 'Veces que aparece en reacciones.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.significado_es IS 'Significado en espanol.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.sentimiento IS 'Sentimiento asociado.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.polaridad IS 'Polaridad asociada.';
COMMENT ON COLUMN public.preprocesar_emojis_uso.pendiente IS 'Si esta pendiente de traducir (sí/no).';

CREATE TABLE IF NOT EXISTS public.preprocesar_emojis_pendientes (
    id serial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    datos jsonb
);

COMMENT ON TABLE public.preprocesar_emojis_pendientes IS 'Emojis pendientes de traducir de una ejecucion (jsonb).';
COMMENT ON COLUMN public.preprocesar_emojis_pendientes.id_ejecucion IS 'Ejecucion a la que pertenecen los emojis pendientes.';
COMMENT ON COLUMN public.preprocesar_emojis_pendientes.datos IS 'Datos de emojis pendientes (jsonb).';

CREATE TABLE IF NOT EXISTS public.preprocesar_resumen (
    id serial PRIMARY KEY,
    id_ejecucion integer NOT NULL REFERENCES public.preprocesar_ejecuciones(id_ejecucion) ON DELETE CASCADE,
    datos jsonb
);

COMMENT ON TABLE public.preprocesar_resumen IS 'Resumen de una ejecucion (jsonb).';
COMMENT ON COLUMN public.preprocesar_resumen.id_ejecucion IS 'Ejecucion a la que pertenece el resumen.';
COMMENT ON COLUMN public.preprocesar_resumen.datos IS 'Resumen completo de la ejecucion (jsonb).';

-- Indices para consultas filtradas por ejecucion y fecha.
CREATE INDEX IF NOT EXISTS idx_preprocesar_ejecuciones_fecha ON public.preprocesar_ejecuciones (fecha);
CREATE INDEX IF NOT EXISTS idx_preprocesar_ejecuciones_estado ON public.preprocesar_ejecuciones (estado);
CREATE INDEX IF NOT EXISTS idx_preprocesar_ejecuciones_archivo ON public.preprocesar_ejecuciones (archivo);
CREATE INDEX IF NOT EXISTS idx_preprocesar_ejecuciones_responsable ON public.preprocesar_ejecuciones (responsable);

CREATE INDEX IF NOT EXISTS idx_preprocesar_mensajes_limpios_ejecucion ON public.preprocesar_mensajes_limpios (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_mensajes_excluidos_ejecucion ON public.preprocesar_mensajes_excluidos (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_tokens_ejecucion ON public.preprocesar_tokens (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_stopwords_ejecucion ON public.preprocesar_stopwords (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_emojis_uso_ejecucion ON public.preprocesar_emojis_uso (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_emojis_pendientes_ejecucion ON public.preprocesar_emojis_pendientes (id_ejecucion);
CREATE INDEX IF NOT EXISTS idx_preprocesar_resumen_ejecucion ON public.preprocesar_resumen (id_ejecucion);
