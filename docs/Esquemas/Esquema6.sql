--
-- Esquema 6: diccionarios de configuracion en PostgreSQL
-- Estilo Esquema5.sql: schema public, PK secuencial,
-- creado_en DEFAULT CURRENT_TIMESTAMP, actualizado_en.
--

CREATE TABLE IF NOT EXISTS public.config_diccionario_sentimientos (
    id serial PRIMARY KEY,
    orden integer,
    nombre character varying(100) UNIQUE,
    polaridad integer,
    activo boolean DEFAULT true,
    definicion text,
    palabras jsonb,
    raices jsonb,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_sentimientos IS 'Diccionario propio de sentimientos (1 fila por sentimiento).';
COMMENT ON COLUMN public.config_diccionario_sentimientos.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_sentimientos.orden IS 'Orden de aparicion en el diccionario.';
COMMENT ON COLUMN public.config_diccionario_sentimientos.nombre IS 'Nombre del sentimiento.';
COMMENT ON COLUMN public.config_diccionario_sentimientos.polaridad IS 'Polaridad (-1, 0, 1).';
COMMENT ON COLUMN public.config_diccionario_sentimientos.activo IS 'Si el sentimiento esta activo.';
COMMENT ON COLUMN public.config_diccionario_sentimientos.definicion IS 'Definicion del sentimiento.';
COMMENT ON COLUMN public.config_diccionario_sentimientos.palabras IS 'Array de palabras asociadas (jsonb).';
COMMENT ON COLUMN public.config_diccionario_sentimientos.raices IS 'Array de raices asociadas (jsonb).';

CREATE TABLE IF NOT EXISTS public.config_diccionario_emojis (
    id serial PRIMARY KEY,
    emoji character varying(50) UNIQUE,
    significado_es character varying(200),
    sentimiento character varying(100),
    polaridad numeric,
    nombre_unicode character varying(200),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_emojis IS 'Diccionario de emojis (1 fila por emoji).';
COMMENT ON COLUMN public.config_diccionario_emojis.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_emojis.emoji IS 'Caracter emoji.';
COMMENT ON COLUMN public.config_diccionario_emojis.significado_es IS 'Significado en espanol.';
COMMENT ON COLUMN public.config_diccionario_emojis.sentimiento IS 'Sentimiento asociado ("neutral" o nombre de sentimientos.json).';
COMMENT ON COLUMN public.config_diccionario_emojis.polaridad IS 'Polaridad asociada.';
COMMENT ON COLUMN public.config_diccionario_emojis.nombre_unicode IS 'Nombre Unicode del emoji.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_stopwords (
    id serial PRIMARY KEY,
    palabra character varying(100),
    accion character varying(50),
    categoria character varying(100),
    justificacion text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_stopwords IS 'Stopwords (palabras vacias) con accion y categoria.';
COMMENT ON COLUMN public.config_diccionario_stopwords.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_stopwords.palabra IS 'Palabra vacia.';
COMMENT ON COLUMN public.config_diccionario_stopwords.accion IS 'Accion (eliminar, conservar...).';
COMMENT ON COLUMN public.config_diccionario_stopwords.categoria IS 'Categoria (articulo, negacion, intensificador...).';
COMMENT ON COLUMN public.config_diccionario_stopwords.justificacion IS 'Justificacion de la accion.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_palabras_anuncio (
    id serial PRIMARY KEY,
    tipo character varying(50),
    patron character varying(200),
    peso integer,
    parametro character varying(100),
    categoria character varying(100),
    justificacion text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_palabras_anuncio IS 'Patrones para detectar anuncios/publicidad.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.tipo IS 'Tipo de patron (estructura, regex, frase...).';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.patron IS 'Patron de texto o regex.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.peso IS 'Peso del patron.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.parametro IS 'Parametro adicional.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.categoria IS 'Categoria del anuncio.';
COMMENT ON COLUMN public.config_diccionario_palabras_anuncio.justificacion IS 'Justificacion del patron.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_genero (
    id serial PRIMARY KEY,
    palabra character varying(100),
    genero character varying(50),
    tipo character varying(50),
    justificacion text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_genero IS 'Diccionario de genero por palabra.';
COMMENT ON COLUMN public.config_diccionario_genero.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_genero.palabra IS 'Palabra.';
COMMENT ON COLUMN public.config_diccionario_genero.genero IS 'Genero (femenino, masculino...).';
COMMENT ON COLUMN public.config_diccionario_genero.tipo IS 'Tipo de palabra (pronombre, sustantivo...).';
COMMENT ON COLUMN public.config_diccionario_genero.justificacion IS 'Justificacion.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_abreviaturas (
    id serial PRIMARY KEY,
    abreviatura character varying(50) UNIQUE,
    normal character varying(100),
    categoria character varying(100),
    justificacion text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_abreviaturas IS 'Abreviaturas de chat y su forma normal.';
COMMENT ON COLUMN public.config_diccionario_abreviaturas.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_abreviaturas.abreviatura IS 'Abreviatura.';
COMMENT ON COLUMN public.config_diccionario_abreviaturas.normal IS 'Forma normal.';
COMMENT ON COLUMN public.config_diccionario_abreviaturas.categoria IS 'Categoria.';
COMMENT ON COLUMN public.config_diccionario_abreviaturas.justificacion IS 'Justificacion.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_emoticonos (
    id serial PRIMARY KEY,
    emoticono character varying(50),
    emoji character varying(50),
    justificacion text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_emoticonos IS 'Emoticonos de texto y su equivalente emoji.';
COMMENT ON COLUMN public.config_diccionario_emoticonos.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_emoticonos.emoticono IS 'Emoticono de texto (:), :(, etc).';
COMMENT ON COLUMN public.config_diccionario_emoticonos.emoji IS 'Emoji equivalente.';
COMMENT ON COLUMN public.config_diccionario_emoticonos.justificacion IS 'Justificacion.';

CREATE TABLE IF NOT EXISTS public.config_diccionario_codigos_materia (
    id serial PRIMARY KEY,
    prefijo character varying(50) UNIQUE,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.config_diccionario_codigos_materia IS 'Prefijos/codigos de materia.';
COMMENT ON COLUMN public.config_diccionario_codigos_materia.id IS 'Identificador de fila.';
COMMENT ON COLUMN public.config_diccionario_codigos_materia.prefijo IS 'Prefijo de materia.';

-- Indices en columnas naturales de consulta frecuente.
CREATE INDEX IF NOT EXISTS idx_config_diccionario_sentimientos_activo ON public.config_diccionario_sentimientos (activo);
CREATE INDEX IF NOT EXISTS idx_config_diccionario_emojis_sentimiento ON public.config_diccionario_emojis (sentimiento);
CREATE INDEX IF NOT EXISTS idx_config_diccionario_stopwords_accion ON public.config_diccionario_stopwords (accion);
CREATE INDEX IF NOT EXISTS idx_config_diccionario_palabras_anuncio_tipo ON public.config_diccionario_palabras_anuncio (tipo);
CREATE INDEX IF NOT EXISTS idx_config_diccionario_genero_genero ON public.config_diccionario_genero (genero);
