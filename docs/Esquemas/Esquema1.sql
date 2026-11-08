--
-- PostgreSQL database dump
--

\restrict gNW9cbdade8RdqnJsfRGFyapAuNE9H1GbzNbXWPCrajWBS0YaNBGMrNzpX6K1sy

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.4

-- Started on 2026-11-08 11:08:56

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 11 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 4122 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 280 (class 1259 OID 18598)
-- Name: abreviaturas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.abreviaturas (
    id integer NOT NULL,
    abreviatura character varying(50) NOT NULL,
    normal character varying(100) NOT NULL,
    categoria character varying(50),
    justificacion text
);


ALTER TABLE public.abreviaturas OWNER TO postgres;

--
-- TOC entry 4124 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE abreviaturas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.abreviaturas IS 'Abreviaturas de chat y su forma normal para normalización léxica.';


--
-- TOC entry 279 (class 1259 OID 18597)
-- Name: abreviaturas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.abreviaturas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.abreviaturas_id_seq OWNER TO postgres;

--
-- TOC entry 4126 (class 0 OID 0)
-- Dependencies: 279
-- Name: abreviaturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.abreviaturas_id_seq OWNED BY public.abreviaturas.id;


--
-- TOC entry 342 (class 1259 OID 19007)
-- Name: bitacora_registros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bitacora_registros (
    id integer NOT NULL,
    fecha text NOT NULL,
    tipo_cambio text NOT NULL,
    descripcion text NOT NULL,
    filas_afectadas integer,
    columnas_afectadas text,
    version_dataset integer,
    resumen_estadistico text,
    creado_por text DEFAULT 'R-Plumber'::text
);


ALTER TABLE public.bitacora_registros OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 19006)
-- Name: bitacora_registros_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bitacora_registros_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bitacora_registros_id_seq OWNER TO postgres;

--
-- TOC entry 4129 (class 0 OID 0)
-- Dependencies: 341
-- Name: bitacora_registros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bitacora_registros_id_seq OWNED BY public.bitacora_registros.id;


--
-- TOC entry 338 (class 1259 OID 18984)
-- Name: cambios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cambios (
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

--
-- TOC entry 4131 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE cambios; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cambios IS 'Cambios detectados automáticamente en código y diccionarios (vigilar_cambios).';


--
-- TOC entry 337 (class 1259 OID 18983)
-- Name: cambios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cambios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cambios_id_seq OWNER TO postgres;

--
-- TOC entry 4133 (class 0 OID 0)
-- Dependencies: 337
-- Name: cambios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cambios_id_seq OWNED BY public.cambios.id;


--
-- TOC entry 300 (class 1259 OID 18717)
-- Name: chats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chats (
    id integer NOT NULL,
    name character varying(200),
    type character varying(50),
    fecha_ingesta timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.chats OWNER TO postgres;

--
-- TOC entry 278 (class 1259 OID 18591)
-- Name: codigos_materia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.codigos_materia (
    prefijo character varying(10) NOT NULL,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.codigos_materia OWNER TO postgres;

--
-- TOC entry 4136 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE codigos_materia; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.codigos_materia IS 'Prefijos de códigos de materia (INF, MAT, LAB...) para agrupar tokens por materia.';


--
-- TOC entry 324 (class 1259 OID 18890)
-- Name: comparacion_niveles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comparacion_niveles (
    id integer NOT NULL,
    periodo_a character varying(100) NOT NULL,
    periodo_b character varying(100) NOT NULL,
    sentimiento character varying(50) NOT NULL,
    nivel_a numeric(6,3),
    nivel_b numeric(6,3),
    diferencia numeric(6,3),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.comparacion_niveles OWNER TO postgres;

--
-- TOC entry 323 (class 1259 OID 18889)
-- Name: comparacion_niveles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.comparacion_niveles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.comparacion_niveles_id_seq OWNER TO postgres;

--
-- TOC entry 4139 (class 0 OID 0)
-- Dependencies: 323
-- Name: comparacion_niveles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.comparacion_niveles_id_seq OWNED BY public.comparacion_niveles.id;


--
-- TOC entry 344 (class 1259 OID 19019)
-- Name: configuraciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.configuraciones (
    id integer NOT NULL,
    nombre text NOT NULL,
    paso integer NOT NULL,
    parametros text NOT NULL,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.configuraciones OWNER TO postgres;

--
-- TOC entry 343 (class 1259 OID 19018)
-- Name: configuraciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configuraciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuraciones_id_seq OWNER TO postgres;

--
-- TOC entry 4142 (class 0 OID 0)
-- Dependencies: 343
-- Name: configuraciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configuraciones_id_seq OWNED BY public.configuraciones.id;


--
-- TOC entry 336 (class 1259 OID 18969)
-- Name: ejecucion_pasos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ejecucion_pasos (
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

--
-- TOC entry 4144 (class 0 OID 0)
-- Dependencies: 336
-- Name: TABLE ejecucion_pasos; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ejecucion_pasos IS 'Detalle de cada paso ejecutado dentro de una ejecución.';


--
-- TOC entry 335 (class 1259 OID 18968)
-- Name: ejecucion_pasos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ejecucion_pasos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ejecucion_pasos_id_seq OWNER TO postgres;

--
-- TOC entry 4146 (class 0 OID 0)
-- Dependencies: 335
-- Name: ejecucion_pasos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ejecucion_pasos_id_seq OWNED BY public.ejecucion_pasos.id;


--
-- TOC entry 326 (class 1259 OID 18898)
-- Name: ejecuciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ejecuciones (
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

--
-- TOC entry 4148 (class 0 OID 0)
-- Dependencies: 326
-- Name: TABLE ejecuciones; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ejecuciones IS 'Registro de cada ejecución del pipeline preprocesar().';


--
-- TOC entry 325 (class 1259 OID 18897)
-- Name: ejecuciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ejecuciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ejecuciones_id_seq OWNER TO postgres;

--
-- TOC entry 4150 (class 0 OID 0)
-- Dependencies: 325
-- Name: ejecuciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ejecuciones_id_seq OWNED BY public.ejecuciones.id_ejecucion;


--
-- TOC entry 284 (class 1259 OID 18620)
-- Name: emojis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emojis (
    id integer NOT NULL,
    emoji character varying(20) NOT NULL,
    significado_es character varying(200),
    sentimiento character varying(50),
    polaridad integer,
    nombre_unicode character varying(200),
    pendiente boolean DEFAULT false,
    CONSTRAINT emojis_polaridad_check CHECK ((polaridad = ANY (ARRAY['-1'::integer, 0, 1])))
);


ALTER TABLE public.emojis OWNER TO postgres;

--
-- TOC entry 4152 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE emojis; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.emojis IS 'Diccionario maestro de emojis con significado, sentimiento y polaridad.';


--
-- TOC entry 283 (class 1259 OID 18619)
-- Name: emojis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emojis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emojis_id_seq OWNER TO postgres;

--
-- TOC entry 4154 (class 0 OID 0)
-- Dependencies: 283
-- Name: emojis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emojis_id_seq OWNED BY public.emojis.id;


--
-- TOC entry 282 (class 1259 OID 18609)
-- Name: emoticonos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emoticonos (
    id integer NOT NULL,
    emoticono character varying(20) NOT NULL,
    emoji character varying(20),
    justificacion text
);


ALTER TABLE public.emoticonos OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 18608)
-- Name: emoticonos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emoticonos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emoticonos_id_seq OWNER TO postgres;

--
-- TOC entry 4157 (class 0 OID 0)
-- Dependencies: 281
-- Name: emoticonos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emoticonos_id_seq OWNED BY public.emoticonos.id;


--
-- TOC entry 340 (class 1259 OID 18993)
-- Name: experimentos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.experimentos (
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

--
-- TOC entry 4159 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE experimentos; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.experimentos IS 'Experimentos post-preprocesamiento (TF-IDF, LDA, shallow, librería).';


--
-- TOC entry 339 (class 1259 OID 18992)
-- Name: experimentos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.experimentos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.experimentos_id_seq OWNER TO postgres;

--
-- TOC entry 4161 (class 0 OID 0)
-- Dependencies: 339
-- Name: experimentos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.experimentos_id_seq OWNED BY public.experimentos.id;


--
-- TOC entry 286 (class 1259 OID 18631)
-- Name: genero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.genero (
    id integer NOT NULL,
    palabra character varying(100) NOT NULL,
    genero character varying(20),
    tipo character varying(50),
    justificacion text,
    CONSTRAINT genero_genero_check CHECK (((genero)::text = ANY ((ARRAY['femenino'::character varying, 'masculino'::character varying])::text[])))
);


ALTER TABLE public.genero OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 18630)
-- Name: genero_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.genero_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.genero_id_seq OWNER TO postgres;

--
-- TOC entry 4164 (class 0 OID 0)
-- Dependencies: 285
-- Name: genero_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.genero_id_seq OWNED BY public.genero.id;


--
-- TOC entry 346 (class 1259 OID 19031)
-- Name: graficos_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.graficos_info (
    id integer NOT NULL,
    paso integer NOT NULL,
    archivo text NOT NULL,
    ruta text NOT NULL,
    tipo text NOT NULL,
    "tamaño_bytes" integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.graficos_info OWNER TO postgres;

--
-- TOC entry 345 (class 1259 OID 19030)
-- Name: graficos_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.graficos_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.graficos_info_id_seq OWNER TO postgres;

--
-- TOC entry 4167 (class 0 OID 0)
-- Dependencies: 345
-- Name: graficos_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.graficos_info_id_seq OWNED BY public.graficos_info.id;


--
-- TOC entry 287 (class 1259 OID 18640)
-- Name: justificaciones_analisis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.justificaciones_analisis (
    id character varying(50) NOT NULL,
    que_muestra character varying(200),
    justificacion_teorica text,
    referencia text
);


ALTER TABLE public.justificaciones_analisis OWNER TO postgres;

--
-- TOC entry 322 (class 1259 OID 18881)
-- Name: libreria_sentimientos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.libreria_sentimientos (
    id integer NOT NULL,
    periodo character varying(100) NOT NULL,
    sentimiento character varying(50) NOT NULL,
    tipo character varying(30),
    nivel_pct numeric(6,3),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.libreria_sentimientos OWNER TO postgres;

--
-- TOC entry 321 (class 1259 OID 18880)
-- Name: libreria_sentimientos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.libreria_sentimientos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.libreria_sentimientos_id_seq OWNER TO postgres;

--
-- TOC entry 4171 (class 0 OID 0)
-- Dependencies: 321
-- Name: libreria_sentimientos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.libreria_sentimientos_id_seq OWNED BY public.libreria_sentimientos.id;


--
-- TOC entry 301 (class 1259 OID 18723)
-- Name: mensajes_crudos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mensajes_crudos (
    id_mensaje integer NOT NULL,
    chat_id integer NOT NULL,
    tipo_registro character varying(20),
    fecha_raw text,
    fecha_hora timestamp without time zone,
    autor_raw character varying(200),
    autor_id character varying(100),
    responde_a integer,
    editado boolean DEFAULT false,
    reenviado_de character varying(200),
    texto_raw text,
    texto_era_lista boolean DEFAULT false,
    tipo_contenido character varying(50),
    sticker_emoji character varying(20),
    reacciones text,
    accion_servicio character varying(100)
);


ALTER TABLE public.mensajes_crudos OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 18740)
-- Name: mensajes_limpios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mensajes_limpios (
    id_mensaje integer NOT NULL,
    chat_id integer NOT NULL,
    fecha_hora timestamp without time zone,
    fecha date,
    anio integer,
    mes integer,
    anio_mes character varying(7),
    trimestre character varying(10),
    dia_semana character varying(20),
    hora integer,
    autor character varying(200),
    autor_id character varying(100),
    tipo_contenido character varying(50),
    es_respuesta boolean DEFAULT false,
    responde_a integer,
    editado boolean DEFAULT false,
    reenviado boolean DEFAULT false,
    reenviado_de character varying(200),
    n_caracteres integer,
    n_palabras integer,
    n_tokens integer,
    n_enlaces integer,
    n_hashtags integer,
    n_menciones integer,
    tiene_telefono boolean DEFAULT false,
    n_emojis integer,
    emojis_lista text,
    sentimiento_emoji character varying(50),
    polaridad_emoji numeric(5,3),
    reacciones_total integer DEFAULT 0,
    reacciones_pos integer DEFAULT 0,
    reacciones_neg integer DEFAULT 0,
    outlier_longitud boolean DEFAULT false,
    outlier_rafaga boolean DEFAULT false,
    puntaje_publicidad numeric(5,2),
    motivo_publicidad text,
    posible_publicidad boolean DEFAULT false,
    n_ref_femenino integer DEFAULT 0,
    n_ref_masculino integer DEFAULT 0,
    n_ref_inclusivo integer DEFAULT 0,
    genero_mencionado character varying(20),
    texto_original text,
    texto_traducido text,
    texto_limpio text,
    texto_tokens text,
    polaridad_msg character varying(20),
    polaridad_score numeric(5,3),
    sentimiento_dominante character varying(50),
    hits_total integer DEFAULT 0,
    n_negados integer DEFAULT 0
);


ALTER TABLE public.mensajes_limpios OWNER TO postgres;

--
-- TOC entry 4174 (class 0 OID 0)
-- Dependencies: 302
-- Name: TABLE mensajes_limpios; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.mensajes_limpios IS 'Dataset limpio final: una fila por mensaje procesado con todas las variables derivadas.';


--
-- TOC entry 308 (class 1259 OID 18804)
-- Name: niveles_por_periodo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.niveles_por_periodo (
    id integer NOT NULL,
    periodo character varying(100) NOT NULL,
    fecha_inicio date,
    fecha_fin date,
    sentimiento character varying(50) NOT NULL,
    nivel_pct numeric(6,3),
    mensajes_pct numeric(6,3),
    n_mensajes integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.niveles_por_periodo OWNER TO postgres;

--
-- TOC entry 4176 (class 0 OID 0)
-- Dependencies: 308
-- Name: TABLE niveles_por_periodo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.niveles_por_periodo IS 'Nivel promedio de cada sentimiento por período de análisis.';


--
-- TOC entry 307 (class 1259 OID 18803)
-- Name: niveles_por_periodo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.niveles_por_periodo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.niveles_por_periodo_id_seq OWNER TO postgres;

--
-- TOC entry 4178 (class 0 OID 0)
-- Dependencies: 307
-- Name: niveles_por_periodo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.niveles_por_periodo_id_seq OWNED BY public.niveles_por_periodo.id;


--
-- TOC entry 293 (class 1259 OID 18667)
-- Name: palabras_anuncio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.palabras_anuncio (
    id integer NOT NULL,
    tipo character varying(30) NOT NULL,
    patron character varying(200) NOT NULL,
    peso integer DEFAULT 1,
    parametro character varying(50),
    categoria character varying(50),
    justificacion text
);


ALTER TABLE public.palabras_anuncio OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 18666)
-- Name: palabras_anuncio_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.palabras_anuncio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.palabras_anuncio_id_seq OWNER TO postgres;

--
-- TOC entry 4181 (class 0 OID 0)
-- Dependencies: 292
-- Name: palabras_anuncio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.palabras_anuncio_id_seq OWNED BY public.palabras_anuncio.id;


--
-- TOC entry 291 (class 1259 OID 18658)
-- Name: periodos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.periodos (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL
);


ALTER TABLE public.periodos OWNER TO postgres;

--
-- TOC entry 290 (class 1259 OID 18657)
-- Name: periodos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.periodos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.periodos_id_seq OWNER TO postgres;

--
-- TOC entry 4184 (class 0 OID 0)
-- Dependencies: 290
-- Name: periodos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.periodos_id_seq OWNED BY public.periodos.id;


--
-- TOC entry 328 (class 1259 OID 18910)
-- Name: salida_emojis_en_uso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salida_emojis_en_uso (
    id integer NOT NULL,
    ejecucion_id integer,
    emoji character varying(20) NOT NULL,
    en_texto integer DEFAULT 0,
    en_reacciones integer DEFAULT 0,
    significado_es character varying(200),
    sentimiento character varying(50),
    polaridad integer,
    pendiente boolean DEFAULT false
);


ALTER TABLE public.salida_emojis_en_uso OWNER TO postgres;

--
-- TOC entry 327 (class 1259 OID 18909)
-- Name: salida_emojis_en_uso_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.salida_emojis_en_uso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.salida_emojis_en_uso_id_seq OWNER TO postgres;

--
-- TOC entry 4187 (class 0 OID 0)
-- Dependencies: 327
-- Name: salida_emojis_en_uso_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.salida_emojis_en_uso_id_seq OWNED BY public.salida_emojis_en_uso.id;


--
-- TOC entry 332 (class 1259 OID 18939)
-- Name: salida_mensajes_excluidos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salida_mensajes_excluidos (
    id integer NOT NULL,
    ejecucion_id integer,
    id_mensaje integer,
    fecha_hora timestamp without time zone,
    autor character varying(200),
    tipo_contenido character varying(50),
    motivo_exclusion text,
    puntaje_publicidad numeric(5,2),
    motivo_publicidad text,
    texto_original text
);


ALTER TABLE public.salida_mensajes_excluidos OWNER TO postgres;

--
-- TOC entry 331 (class 1259 OID 18938)
-- Name: salida_mensajes_excluidos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.salida_mensajes_excluidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.salida_mensajes_excluidos_id_seq OWNER TO postgres;

--
-- TOC entry 4190 (class 0 OID 0)
-- Dependencies: 331
-- Name: salida_mensajes_excluidos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.salida_mensajes_excluidos_id_seq OWNED BY public.salida_mensajes_excluidos.id;


--
-- TOC entry 334 (class 1259 OID 18953)
-- Name: salida_resumen; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salida_resumen (
    id integer NOT NULL,
    ejecucion_id integer,
    archivo character varying(200),
    registros_leidos integer,
    mensajes_limpios integer,
    mensajes_excluidos integer,
    rango_fechas_inicio date,
    rango_fechas_fin date,
    sentimientos_activos text,
    polaridad_distribucion text,
    emojis_pendientes integer DEFAULT 0,
    pasos_bitacora integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.salida_resumen OWNER TO postgres;

--
-- TOC entry 333 (class 1259 OID 18952)
-- Name: salida_resumen_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.salida_resumen_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.salida_resumen_id_seq OWNER TO postgres;

--
-- TOC entry 4193 (class 0 OID 0)
-- Dependencies: 333
-- Name: salida_resumen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.salida_resumen_id_seq OWNED BY public.salida_resumen.id;


--
-- TOC entry 330 (class 1259 OID 18925)
-- Name: salida_stopwords_aplicadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salida_stopwords_aplicadas (
    id integer NOT NULL,
    ejecucion_id integer,
    palabra character varying(100) NOT NULL,
    decision character varying(20),
    motivo character varying(200),
    ocurrencias integer,
    justificacion text
);


ALTER TABLE public.salida_stopwords_aplicadas OWNER TO postgres;

--
-- TOC entry 329 (class 1259 OID 18924)
-- Name: salida_stopwords_aplicadas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.salida_stopwords_aplicadas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.salida_stopwords_aplicadas_id_seq OWNER TO postgres;

--
-- TOC entry 4196 (class 0 OID 0)
-- Dependencies: 329
-- Name: salida_stopwords_aplicadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.salida_stopwords_aplicadas_id_seq OWNED BY public.salida_stopwords_aplicadas.id;


--
-- TOC entry 295 (class 1259 OID 18677)
-- Name: sentimientos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sentimientos (
    id integer NOT NULL,
    orden integer NOT NULL,
    nombre character varying(50) NOT NULL,
    polaridad integer,
    activo boolean DEFAULT true,
    definicion text,
    comentario_archivo text,
    CONSTRAINT sentimientos_polaridad_check CHECK ((polaridad = ANY (ARRAY['-1'::integer, 0, 1])))
);


ALTER TABLE public.sentimientos OWNER TO postgres;

--
-- TOC entry 4198 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE sentimientos; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.sentimientos IS 'Diccionario propio de 15 sentimientos con palabras, raíces y estado activo.';


--
-- TOC entry 294 (class 1259 OID 18676)
-- Name: sentimientos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sentimientos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sentimientos_id_seq OWNER TO postgres;

--
-- TOC entry 4200 (class 0 OID 0)
-- Dependencies: 294
-- Name: sentimientos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sentimientos_id_seq OWNED BY public.sentimientos.id;


--
-- TOC entry 297 (class 1259 OID 18690)
-- Name: sentimientos_palabras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sentimientos_palabras (
    id integer NOT NULL,
    sentimiento_id integer NOT NULL,
    palabra character varying(100) NOT NULL
);


ALTER TABLE public.sentimientos_palabras OWNER TO postgres;

--
-- TOC entry 4202 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE sentimientos_palabras; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.sentimientos_palabras IS 'Relación muchos a muchos entre sentimientos y palabras del diccionario.';


--
-- TOC entry 296 (class 1259 OID 18689)
-- Name: sentimientos_palabras_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sentimientos_palabras_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sentimientos_palabras_id_seq OWNER TO postgres;

--
-- TOC entry 4204 (class 0 OID 0)
-- Dependencies: 296
-- Name: sentimientos_palabras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sentimientos_palabras_id_seq OWNED BY public.sentimientos_palabras.id;


--
-- TOC entry 304 (class 1259 OID 18774)
-- Name: sentimientos_por_mensaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sentimientos_por_mensaje (
    id integer NOT NULL,
    id_mensaje integer NOT NULL,
    chat_id integer NOT NULL,
    sentimiento character varying(50) NOT NULL,
    pct numeric(6,3),
    hits integer DEFAULT 0
);


ALTER TABLE public.sentimientos_por_mensaje OWNER TO postgres;

--
-- TOC entry 4206 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE sentimientos_por_mensaje; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.sentimientos_por_mensaje IS 'Nivel de sentimiento (%) por mensaje y sentimiento activo.';


--
-- TOC entry 303 (class 1259 OID 18773)
-- Name: sentimientos_por_mensaje_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sentimientos_por_mensaje_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sentimientos_por_mensaje_id_seq OWNER TO postgres;

--
-- TOC entry 4208 (class 0 OID 0)
-- Dependencies: 303
-- Name: sentimientos_por_mensaje_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sentimientos_por_mensaje_id_seq OWNED BY public.sentimientos_por_mensaje.id;


--
-- TOC entry 299 (class 1259 OID 18704)
-- Name: sentimientos_raices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sentimientos_raices (
    id integer NOT NULL,
    sentimiento_id integer NOT NULL,
    raiz character varying(100) NOT NULL
);


ALTER TABLE public.sentimientos_raices OWNER TO postgres;

--
-- TOC entry 4210 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE sentimientos_raices; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.sentimientos_raices IS 'Relación muchos a muchos entre sentimientos y raíces de palabras.';


--
-- TOC entry 298 (class 1259 OID 18703)
-- Name: sentimientos_raices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sentimientos_raices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sentimientos_raices_id_seq OWNER TO postgres;

--
-- TOC entry 4212 (class 0 OID 0)
-- Dependencies: 298
-- Name: sentimientos_raices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sentimientos_raices_id_seq OWNED BY public.sentimientos_raices.id;


--
-- TOC entry 310 (class 1259 OID 18814)
-- Name: serie_sentimientos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.serie_sentimientos (
    id integer NOT NULL,
    periodo character varying(100) NOT NULL,
    fecha date NOT NULL,
    sentimiento character varying(50) NOT NULL,
    pct numeric(6,3),
    n_mensajes integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.serie_sentimientos OWNER TO postgres;

--
-- TOC entry 4214 (class 0 OID 0)
-- Dependencies: 310
-- Name: TABLE serie_sentimientos; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.serie_sentimientos IS 'Serie temporal de sentimientos (por mes/semana/día).';


--
-- TOC entry 309 (class 1259 OID 18813)
-- Name: serie_sentimientos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.serie_sentimientos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.serie_sentimientos_id_seq OWNER TO postgres;

--
-- TOC entry 4216 (class 0 OID 0)
-- Dependencies: 309
-- Name: serie_sentimientos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.serie_sentimientos_id_seq OWNED BY public.serie_sentimientos.id;


--
-- TOC entry 289 (class 1259 OID 18648)
-- Name: stopwords; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stopwords (
    id integer NOT NULL,
    palabra character varying(100) NOT NULL,
    accion character varying(20),
    categoria character varying(50),
    justificacion text,
    CONSTRAINT stopwords_accion_check CHECK (((accion)::text = ANY ((ARRAY['eliminar'::character varying, 'conservar'::character varying])::text[])))
);


ALTER TABLE public.stopwords OWNER TO postgres;

--
-- TOC entry 288 (class 1259 OID 18647)
-- Name: stopwords_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stopwords_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stopwords_id_seq OWNER TO postgres;

--
-- TOC entry 4219 (class 0 OID 0)
-- Dependencies: 288
-- Name: stopwords_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stopwords_id_seq OWNED BY public.stopwords.id;


--
-- TOC entry 312 (class 1259 OID 18824)
-- Name: tfidf_resultados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tfidf_resultados (
    id integer NOT NULL,
    periodo character varying(100) NOT NULL,
    doc character varying(100) NOT NULL,
    token character varying(100) NOT NULL,
    n integer DEFAULT 1,
    tf numeric(8,6),
    idf numeric(8,6),
    tf_idf numeric(10,6),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tfidf_resultados OWNER TO postgres;

--
-- TOC entry 4221 (class 0 OID 0)
-- Dependencies: 312
-- Name: TABLE tfidf_resultados; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.tfidf_resultados IS 'Resultados TF-IDF por documento y término.';


--
-- TOC entry 311 (class 1259 OID 18823)
-- Name: tfidf_resultados_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tfidf_resultados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tfidf_resultados_id_seq OWNER TO postgres;

--
-- TOC entry 4223 (class 0 OID 0)
-- Dependencies: 311
-- Name: tfidf_resultados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tfidf_resultados_id_seq OWNED BY public.tfidf_resultados.id;


--
-- TOC entry 306 (class 1259 OID 18789)
-- Name: tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tokens (
    id integer NOT NULL,
    id_mensaje integer NOT NULL,
    chat_id integer NOT NULL,
    fecha date,
    anio_mes character varying(7),
    token character varying(100) NOT NULL
);


ALTER TABLE public.tokens OWNER TO postgres;

--
-- TOC entry 4225 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE tokens; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.tokens IS 'Tokens por mensaje para TF-IDF, n-gramas y LDA.';


--
-- TOC entry 305 (class 1259 OID 18788)
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tokens_id_seq OWNER TO postgres;

--
-- TOC entry 4227 (class 0 OID 0)
-- Dependencies: 305
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- TOC entry 314 (class 1259 OID 18835)
-- Name: topicos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topicos (
    id integer NOT NULL,
    periodo character varying(100) NOT NULL,
    k integer NOT NULL,
    agrupar character varying(10),
    n_documentos integer,
    n_terminos integer,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT topicos_agrupar_check CHECK (((agrupar)::text = ANY ((ARRAY['dia'::character varying, 'mes'::character varying])::text[])))
);


ALTER TABLE public.topicos OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 18845)
-- Name: topicos_etiquetas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topicos_etiquetas (
    id integer NOT NULL,
    topico_id integer NOT NULL,
    topico character varying(20) NOT NULL,
    etiqueta character varying(200)
);


ALTER TABLE public.topicos_etiquetas OWNER TO postgres;

--
-- TOC entry 315 (class 1259 OID 18844)
-- Name: topicos_etiquetas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topicos_etiquetas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.topicos_etiquetas_id_seq OWNER TO postgres;

--
-- TOC entry 4231 (class 0 OID 0)
-- Dependencies: 315
-- Name: topicos_etiquetas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topicos_etiquetas_id_seq OWNED BY public.topicos_etiquetas.id;


--
-- TOC entry 313 (class 1259 OID 18834)
-- Name: topicos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topicos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.topicos_id_seq OWNER TO postgres;

--
-- TOC entry 4233 (class 0 OID 0)
-- Dependencies: 313
-- Name: topicos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topicos_id_seq OWNED BY public.topicos.id;


--
-- TOC entry 320 (class 1259 OID 18869)
-- Name: topicos_por_documento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topicos_por_documento (
    id integer NOT NULL,
    topico_id integer NOT NULL,
    doc character varying(100) NOT NULL,
    topico character varying(20),
    peso numeric(8,6)
);


ALTER TABLE public.topicos_por_documento OWNER TO postgres;

--
-- TOC entry 319 (class 1259 OID 18868)
-- Name: topicos_por_documento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topicos_por_documento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.topicos_por_documento_id_seq OWNER TO postgres;

--
-- TOC entry 4236 (class 0 OID 0)
-- Dependencies: 319
-- Name: topicos_por_documento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topicos_por_documento_id_seq OWNED BY public.topicos_por_documento.id;


--
-- TOC entry 318 (class 1259 OID 18857)
-- Name: topicos_terminos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topicos_terminos (
    id integer NOT NULL,
    topico_id integer NOT NULL,
    termino character varying(100) NOT NULL,
    beta numeric(10,6)
);


ALTER TABLE public.topicos_terminos OWNER TO postgres;

--
-- TOC entry 317 (class 1259 OID 18856)
-- Name: topicos_terminos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topicos_terminos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.topicos_terminos_id_seq OWNER TO postgres;

--
-- TOC entry 4239 (class 0 OID 0)
-- Dependencies: 317
-- Name: topicos_terminos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topicos_terminos_id_seq OWNED BY public.topicos_terminos.id;


--
-- TOC entry 348 (class 1259 OID 19046)
-- Name: v_ejecucion_resumen; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_ejecucion_resumen AS
 SELECT e.id_ejecucion AS id,
    e.fecha,
    e.responsable,
    e.archivo,
    e.estado,
    e.registros_leidos,
    e.mensajes_limpios,
    e.mensajes_excluidos,
    e.emojis_pendientes,
    count(DISTINCT c.id) AS n_cambios
   FROM (public.ejecuciones e
     LEFT JOIN public.cambios c ON ((c.ejecucion_prueba ~~ (('%'::text || e.id_ejecucion) || '%'::text))))
  GROUP BY e.id_ejecucion, e.fecha, e.responsable, e.archivo, e.estado, e.registros_leidos, e.mensajes_limpios, e.mensajes_excluidos, e.emojis_pendientes;


ALTER VIEW public.v_ejecucion_resumen OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 19041)
-- Name: v_resumen_sentimientos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resumen_sentimientos AS
 SELECT e.id_ejecucion AS ejecucion_id,
    e.fecha,
    e.responsable,
    s.nombre AS sentimiento,
    avg(spm.pct) AS nivel_promedio,
    count(*) AS n_mensajes_con_sentimiento
   FROM ((public.ejecuciones e
     JOIN public.sentimientos_por_mensaje spm ON ((spm.id_mensaje = ( SELECT ml.id_mensaje
           FROM public.mensajes_limpios ml
          WHERE (ml.chat_id = spm.chat_id)
         LIMIT 1))))
     JOIN public.sentimientos s ON (((s.nombre)::text = (spm.sentimiento)::text)))
  GROUP BY e.id_ejecucion, e.fecha, e.responsable, s.nombre;


ALTER VIEW public.v_resumen_sentimientos OWNER TO postgres;

--
-- TOC entry 3758 (class 2604 OID 18601)
-- Name: abreviaturas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abreviaturas ALTER COLUMN id SET DEFAULT nextval('public.abreviaturas_id_seq'::regclass);


--
-- TOC entry 3824 (class 2604 OID 19010)
-- Name: bitacora_registros id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora_registros ALTER COLUMN id SET DEFAULT nextval('public.bitacora_registros_id_seq'::regclass);


--
-- TOC entry 3822 (class 2604 OID 18987)
-- Name: cambios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios ALTER COLUMN id SET DEFAULT nextval('public.cambios_id_seq'::regclass);


--
-- TOC entry 3806 (class 2604 OID 18893)
-- Name: comparacion_niveles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comparacion_niveles ALTER COLUMN id SET DEFAULT nextval('public.comparacion_niveles_id_seq'::regclass);


--
-- TOC entry 3826 (class 2604 OID 19022)
-- Name: configuraciones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuraciones ALTER COLUMN id SET DEFAULT nextval('public.configuraciones_id_seq'::regclass);


--
-- TOC entry 3821 (class 2604 OID 18972)
-- Name: ejecucion_pasos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejecucion_pasos ALTER COLUMN id SET DEFAULT nextval('public.ejecucion_pasos_id_seq'::regclass);


--
-- TOC entry 3808 (class 2604 OID 18901)
-- Name: ejecuciones id_ejecucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejecuciones ALTER COLUMN id_ejecucion SET DEFAULT nextval('public.ejecuciones_id_seq'::regclass);


--
-- TOC entry 3760 (class 2604 OID 18623)
-- Name: emojis id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emojis ALTER COLUMN id SET DEFAULT nextval('public.emojis_id_seq'::regclass);


--
-- TOC entry 3759 (class 2604 OID 18612)
-- Name: emoticonos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emoticonos ALTER COLUMN id SET DEFAULT nextval('public.emoticonos_id_seq'::regclass);


--
-- TOC entry 3823 (class 2604 OID 18996)
-- Name: experimentos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.experimentos ALTER COLUMN id SET DEFAULT nextval('public.experimentos_id_seq'::regclass);


--
-- TOC entry 3762 (class 2604 OID 18634)
-- Name: genero id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genero ALTER COLUMN id SET DEFAULT nextval('public.genero_id_seq'::regclass);


--
-- TOC entry 3829 (class 2604 OID 19034)
-- Name: graficos_info id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.graficos_info ALTER COLUMN id SET DEFAULT nextval('public.graficos_info_id_seq'::regclass);


--
-- TOC entry 3804 (class 2604 OID 18884)
-- Name: libreria_sentimientos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.libreria_sentimientos ALTER COLUMN id SET DEFAULT nextval('public.libreria_sentimientos_id_seq'::regclass);


--
-- TOC entry 3792 (class 2604 OID 18807)
-- Name: niveles_por_periodo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.niveles_por_periodo ALTER COLUMN id SET DEFAULT nextval('public.niveles_por_periodo_id_seq'::regclass);


--
-- TOC entry 3765 (class 2604 OID 18670)
-- Name: palabras_anuncio id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.palabras_anuncio ALTER COLUMN id SET DEFAULT nextval('public.palabras_anuncio_id_seq'::regclass);


--
-- TOC entry 3764 (class 2604 OID 18661)
-- Name: periodos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodos ALTER COLUMN id SET DEFAULT nextval('public.periodos_id_seq'::regclass);


--
-- TOC entry 3812 (class 2604 OID 18913)
-- Name: salida_emojis_en_uso id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_emojis_en_uso ALTER COLUMN id SET DEFAULT nextval('public.salida_emojis_en_uso_id_seq'::regclass);


--
-- TOC entry 3817 (class 2604 OID 18942)
-- Name: salida_mensajes_excluidos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_mensajes_excluidos ALTER COLUMN id SET DEFAULT nextval('public.salida_mensajes_excluidos_id_seq'::regclass);


--
-- TOC entry 3818 (class 2604 OID 18956)
-- Name: salida_resumen id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_resumen ALTER COLUMN id SET DEFAULT nextval('public.salida_resumen_id_seq'::regclass);


--
-- TOC entry 3816 (class 2604 OID 18928)
-- Name: salida_stopwords_aplicadas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_stopwords_aplicadas ALTER COLUMN id SET DEFAULT nextval('public.salida_stopwords_aplicadas_id_seq'::regclass);


--
-- TOC entry 3767 (class 2604 OID 18680)
-- Name: sentimientos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos ALTER COLUMN id SET DEFAULT nextval('public.sentimientos_id_seq'::regclass);


--
-- TOC entry 3769 (class 2604 OID 18693)
-- Name: sentimientos_palabras id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_palabras ALTER COLUMN id SET DEFAULT nextval('public.sentimientos_palabras_id_seq'::regclass);


--
-- TOC entry 3789 (class 2604 OID 18777)
-- Name: sentimientos_por_mensaje id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_por_mensaje ALTER COLUMN id SET DEFAULT nextval('public.sentimientos_por_mensaje_id_seq'::regclass);


--
-- TOC entry 3770 (class 2604 OID 18707)
-- Name: sentimientos_raices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_raices ALTER COLUMN id SET DEFAULT nextval('public.sentimientos_raices_id_seq'::regclass);


--
-- TOC entry 3794 (class 2604 OID 18817)
-- Name: serie_sentimientos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.serie_sentimientos ALTER COLUMN id SET DEFAULT nextval('public.serie_sentimientos_id_seq'::regclass);


--
-- TOC entry 3763 (class 2604 OID 18651)
-- Name: stopwords id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stopwords ALTER COLUMN id SET DEFAULT nextval('public.stopwords_id_seq'::regclass);


--
-- TOC entry 3796 (class 2604 OID 18827)
-- Name: tfidf_resultados id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tfidf_resultados ALTER COLUMN id SET DEFAULT nextval('public.tfidf_resultados_id_seq'::regclass);


--
-- TOC entry 3791 (class 2604 OID 18792)
-- Name: tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- TOC entry 3799 (class 2604 OID 18838)
-- Name: topicos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos ALTER COLUMN id SET DEFAULT nextval('public.topicos_id_seq'::regclass);


--
-- TOC entry 3801 (class 2604 OID 18848)
-- Name: topicos_etiquetas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_etiquetas ALTER COLUMN id SET DEFAULT nextval('public.topicos_etiquetas_id_seq'::regclass);


--
-- TOC entry 3803 (class 2604 OID 18872)
-- Name: topicos_por_documento id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_por_documento ALTER COLUMN id SET DEFAULT nextval('public.topicos_por_documento_id_seq'::regclass);


--
-- TOC entry 3802 (class 2604 OID 18860)
-- Name: topicos_terminos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_terminos ALTER COLUMN id SET DEFAULT nextval('public.topicos_terminos_id_seq'::regclass);


--
-- TOC entry 3839 (class 2606 OID 18607)
-- Name: abreviaturas abreviaturas_abreviatura_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abreviaturas
    ADD CONSTRAINT abreviaturas_abreviatura_key UNIQUE (abreviatura);


--
-- TOC entry 3841 (class 2606 OID 18605)
-- Name: abreviaturas abreviaturas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abreviaturas
    ADD CONSTRAINT abreviaturas_pkey PRIMARY KEY (id);


--
-- TOC entry 3942 (class 2606 OID 19015)
-- Name: bitacora_registros bitacora_registros_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bitacora_registros
    ADD CONSTRAINT bitacora_registros_pkey PRIMARY KEY (id);


--
-- TOC entry 3938 (class 2606 OID 18991)
-- Name: cambios cambios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios
    ADD CONSTRAINT cambios_pkey PRIMARY KEY (id);


--
-- TOC entry 3875 (class 2606 OID 18722)
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);


--
-- TOC entry 3837 (class 2606 OID 18596)
-- Name: codigos_materia codigos_materia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_materia
    ADD CONSTRAINT codigos_materia_pkey PRIMARY KEY (prefijo);


--
-- TOC entry 3923 (class 2606 OID 18896)
-- Name: comparacion_niveles comparacion_niveles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comparacion_niveles
    ADD CONSTRAINT comparacion_niveles_pkey PRIMARY KEY (id);


--
-- TOC entry 3946 (class 2606 OID 19028)
-- Name: configuraciones configuraciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuraciones
    ADD CONSTRAINT configuraciones_pkey PRIMARY KEY (id);


--
-- TOC entry 3935 (class 2606 OID 18976)
-- Name: ejecucion_pasos ejecucion_pasos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejecucion_pasos
    ADD CONSTRAINT ejecucion_pasos_pkey PRIMARY KEY (id);


--
-- TOC entry 3925 (class 2606 OID 18908)
-- Name: ejecuciones ejecuciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejecuciones
    ADD CONSTRAINT ejecuciones_pkey PRIMARY KEY (id_ejecucion);


--
-- TOC entry 3847 (class 2606 OID 18629)
-- Name: emojis emojis_emoji_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emojis
    ADD CONSTRAINT emojis_emoji_key UNIQUE (emoji);


--
-- TOC entry 3849 (class 2606 OID 18627)
-- Name: emojis emojis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emojis
    ADD CONSTRAINT emojis_pkey PRIMARY KEY (id);


--
-- TOC entry 3843 (class 2606 OID 18618)
-- Name: emoticonos emoticonos_emoticono_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emoticonos
    ADD CONSTRAINT emoticonos_emoticono_key UNIQUE (emoticono);


--
-- TOC entry 3845 (class 2606 OID 18616)
-- Name: emoticonos emoticonos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emoticonos
    ADD CONSTRAINT emoticonos_pkey PRIMARY KEY (id);


--
-- TOC entry 3940 (class 2606 OID 19000)
-- Name: experimentos experimentos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.experimentos
    ADD CONSTRAINT experimentos_pkey PRIMARY KEY (id);


--
-- TOC entry 3851 (class 2606 OID 18639)
-- Name: genero genero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genero
    ADD CONSTRAINT genero_pkey PRIMARY KEY (id);


--
-- TOC entry 3949 (class 2606 OID 19039)
-- Name: graficos_info graficos_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.graficos_info
    ADD CONSTRAINT graficos_info_pkey PRIMARY KEY (id);


--
-- TOC entry 3853 (class 2606 OID 18646)
-- Name: justificaciones_analisis justificaciones_analisis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.justificaciones_analisis
    ADD CONSTRAINT justificaciones_analisis_pkey PRIMARY KEY (id);


--
-- TOC entry 3921 (class 2606 OID 18887)
-- Name: libreria_sentimientos libreria_sentimientos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.libreria_sentimientos
    ADD CONSTRAINT libreria_sentimientos_pkey PRIMARY KEY (id);


--
-- TOC entry 3880 (class 2606 OID 18731)
-- Name: mensajes_crudos mensajes_crudos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_crudos
    ADD CONSTRAINT mensajes_crudos_pkey PRIMARY KEY (id_mensaje, chat_id);


--
-- TOC entry 3888 (class 2606 OID 18761)
-- Name: mensajes_limpios mensajes_limpios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_limpios
    ADD CONSTRAINT mensajes_limpios_pkey PRIMARY KEY (id_mensaje, chat_id);


--
-- TOC entry 3901 (class 2606 OID 18810)
-- Name: niveles_por_periodo niveles_por_periodo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.niveles_por_periodo
    ADD CONSTRAINT niveles_por_periodo_pkey PRIMARY KEY (id);


--
-- TOC entry 3861 (class 2606 OID 18675)
-- Name: palabras_anuncio palabras_anuncio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.palabras_anuncio
    ADD CONSTRAINT palabras_anuncio_pkey PRIMARY KEY (id);


--
-- TOC entry 3857 (class 2606 OID 18665)
-- Name: periodos periodos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodos
    ADD CONSTRAINT periodos_nombre_key UNIQUE (nombre);


--
-- TOC entry 3859 (class 2606 OID 18663)
-- Name: periodos periodos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.periodos
    ADD CONSTRAINT periodos_pkey PRIMARY KEY (id);


--
-- TOC entry 3927 (class 2606 OID 18918)
-- Name: salida_emojis_en_uso salida_emojis_en_uso_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_emojis_en_uso
    ADD CONSTRAINT salida_emojis_en_uso_pkey PRIMARY KEY (id);


--
-- TOC entry 3931 (class 2606 OID 18946)
-- Name: salida_mensajes_excluidos salida_mensajes_excluidos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_mensajes_excluidos
    ADD CONSTRAINT salida_mensajes_excluidos_pkey PRIMARY KEY (id);


--
-- TOC entry 3933 (class 2606 OID 18962)
-- Name: salida_resumen salida_resumen_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_resumen
    ADD CONSTRAINT salida_resumen_pkey PRIMARY KEY (id);


--
-- TOC entry 3929 (class 2606 OID 18932)
-- Name: salida_stopwords_aplicadas salida_stopwords_aplicadas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_stopwords_aplicadas
    ADD CONSTRAINT salida_stopwords_aplicadas_pkey PRIMARY KEY (id);


--
-- TOC entry 3863 (class 2606 OID 18688)
-- Name: sentimientos sentimientos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos
    ADD CONSTRAINT sentimientos_nombre_key UNIQUE (nombre);


--
-- TOC entry 3867 (class 2606 OID 18695)
-- Name: sentimientos_palabras sentimientos_palabras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_palabras
    ADD CONSTRAINT sentimientos_palabras_pkey PRIMARY KEY (id);


--
-- TOC entry 3869 (class 2606 OID 18697)
-- Name: sentimientos_palabras sentimientos_palabras_sentimiento_id_palabra_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_palabras
    ADD CONSTRAINT sentimientos_palabras_sentimiento_id_palabra_key UNIQUE (sentimiento_id, palabra);


--
-- TOC entry 3865 (class 2606 OID 18686)
-- Name: sentimientos sentimientos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos
    ADD CONSTRAINT sentimientos_pkey PRIMARY KEY (id);


--
-- TOC entry 3892 (class 2606 OID 18780)
-- Name: sentimientos_por_mensaje sentimientos_por_mensaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_por_mensaje
    ADD CONSTRAINT sentimientos_por_mensaje_pkey PRIMARY KEY (id);


--
-- TOC entry 3871 (class 2606 OID 18709)
-- Name: sentimientos_raices sentimientos_raices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_raices
    ADD CONSTRAINT sentimientos_raices_pkey PRIMARY KEY (id);


--
-- TOC entry 3873 (class 2606 OID 18711)
-- Name: sentimientos_raices sentimientos_raices_sentimiento_id_raiz_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_raices
    ADD CONSTRAINT sentimientos_raices_sentimiento_id_raiz_key UNIQUE (sentimiento_id, raiz);


--
-- TOC entry 3905 (class 2606 OID 18820)
-- Name: serie_sentimientos serie_sentimientos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.serie_sentimientos
    ADD CONSTRAINT serie_sentimientos_pkey PRIMARY KEY (id);


--
-- TOC entry 3855 (class 2606 OID 18656)
-- Name: stopwords stopwords_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stopwords
    ADD CONSTRAINT stopwords_pkey PRIMARY KEY (id);


--
-- TOC entry 3909 (class 2606 OID 18831)
-- Name: tfidf_resultados tfidf_resultados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tfidf_resultados
    ADD CONSTRAINT tfidf_resultados_pkey PRIMARY KEY (id);


--
-- TOC entry 3897 (class 2606 OID 18794)
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- TOC entry 3914 (class 2606 OID 18850)
-- Name: topicos_etiquetas topicos_etiquetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_etiquetas
    ADD CONSTRAINT topicos_etiquetas_pkey PRIMARY KEY (id);


--
-- TOC entry 3912 (class 2606 OID 18842)
-- Name: topicos topicos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos
    ADD CONSTRAINT topicos_pkey PRIMARY KEY (id);


--
-- TOC entry 3918 (class 2606 OID 18874)
-- Name: topicos_por_documento topicos_por_documento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_por_documento
    ADD CONSTRAINT topicos_por_documento_pkey PRIMARY KEY (id);


--
-- TOC entry 3916 (class 2606 OID 18862)
-- Name: topicos_terminos topicos_terminos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_terminos
    ADD CONSTRAINT topicos_terminos_pkey PRIMARY KEY (id);


--
-- TOC entry 3943 (class 1259 OID 19016)
-- Name: idx_bitacora_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bitacora_fecha ON public.bitacora_registros USING btree (fecha DESC);


--
-- TOC entry 3944 (class 1259 OID 19017)
-- Name: idx_bitacora_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bitacora_tipo ON public.bitacora_registros USING btree (tipo_cambio);


--
-- TOC entry 3947 (class 1259 OID 19029)
-- Name: idx_configuraciones_paso; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_configuraciones_paso ON public.configuraciones USING btree (paso);


--
-- TOC entry 3936 (class 1259 OID 18982)
-- Name: idx_ejecucion_pasos_ejecucion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ejecucion_pasos_ejecucion ON public.ejecucion_pasos USING btree (ejecucion_id);


--
-- TOC entry 3950 (class 1259 OID 19040)
-- Name: idx_graficos_info_paso; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_graficos_info_paso ON public.graficos_info USING btree (paso);


--
-- TOC entry 3919 (class 1259 OID 18888)
-- Name: idx_libreria_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_libreria_periodo ON public.libreria_sentimientos USING btree (periodo);


--
-- TOC entry 3876 (class 1259 OID 18738)
-- Name: idx_mensajes_crudos_autor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_crudos_autor ON public.mensajes_crudos USING btree (autor_id);


--
-- TOC entry 3877 (class 1259 OID 18737)
-- Name: idx_mensajes_crudos_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_crudos_fecha ON public.mensajes_crudos USING btree (fecha_hora);


--
-- TOC entry 3878 (class 1259 OID 18739)
-- Name: idx_mensajes_crudos_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_crudos_tipo ON public.mensajes_crudos USING btree (tipo_contenido);


--
-- TOC entry 3881 (class 1259 OID 18768)
-- Name: idx_mensajes_limpios_anio_mes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_anio_mes ON public.mensajes_limpios USING btree (anio_mes);


--
-- TOC entry 3882 (class 1259 OID 18769)
-- Name: idx_mensajes_limpios_autor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_autor ON public.mensajes_limpios USING btree (autor_id);


--
-- TOC entry 3883 (class 1259 OID 18771)
-- Name: idx_mensajes_limpios_dominante; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_dominante ON public.mensajes_limpios USING btree (sentimiento_dominante);


--
-- TOC entry 3884 (class 1259 OID 18767)
-- Name: idx_mensajes_limpios_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_fecha ON public.mensajes_limpios USING btree (fecha);


--
-- TOC entry 3885 (class 1259 OID 18772)
-- Name: idx_mensajes_limpios_genero; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_genero ON public.mensajes_limpios USING btree (genero_mencionado);


--
-- TOC entry 3886 (class 1259 OID 18770)
-- Name: idx_mensajes_limpios_polaridad; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_limpios_polaridad ON public.mensajes_limpios USING btree (polaridad_msg);


--
-- TOC entry 3898 (class 1259 OID 18811)
-- Name: idx_niveles_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_niveles_periodo ON public.niveles_por_periodo USING btree (periodo);


--
-- TOC entry 3899 (class 1259 OID 18812)
-- Name: idx_niveles_sentimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_niveles_sentimiento ON public.niveles_por_periodo USING btree (sentimiento);


--
-- TOC entry 3889 (class 1259 OID 18786)
-- Name: idx_sentimientos_por_mensaje_msg; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sentimientos_por_mensaje_msg ON public.sentimientos_por_mensaje USING btree (id_mensaje, chat_id);


--
-- TOC entry 3890 (class 1259 OID 18787)
-- Name: idx_sentimientos_por_mensaje_sent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sentimientos_por_mensaje_sent ON public.sentimientos_por_mensaje USING btree (sentimiento);


--
-- TOC entry 3902 (class 1259 OID 18821)
-- Name: idx_serie_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_serie_periodo ON public.serie_sentimientos USING btree (periodo, fecha);


--
-- TOC entry 3903 (class 1259 OID 18822)
-- Name: idx_serie_sentimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_serie_sentimiento ON public.serie_sentimientos USING btree (sentimiento);


--
-- TOC entry 3906 (class 1259 OID 18832)
-- Name: idx_tfidf_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tfidf_periodo ON public.tfidf_resultados USING btree (periodo, doc);


--
-- TOC entry 3907 (class 1259 OID 18833)
-- Name: idx_tfidf_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tfidf_token ON public.tfidf_resultados USING btree (token);


--
-- TOC entry 3893 (class 1259 OID 18802)
-- Name: idx_tokens_anio_mes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tokens_anio_mes ON public.tokens USING btree (anio_mes);


--
-- TOC entry 3894 (class 1259 OID 18800)
-- Name: idx_tokens_msg; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tokens_msg ON public.tokens USING btree (id_mensaje, chat_id);


--
-- TOC entry 3895 (class 1259 OID 18801)
-- Name: idx_tokens_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tokens_token ON public.tokens USING btree (token);


--
-- TOC entry 3910 (class 1259 OID 18843)
-- Name: idx_topicos_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_topicos_periodo ON public.topicos USING btree (periodo);


--
-- TOC entry 3964 (class 2606 OID 18977)
-- Name: ejecucion_pasos ejecucion_pasos_ejecucion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejecucion_pasos
    ADD CONSTRAINT ejecucion_pasos_ejecucion_id_fkey FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion) ON DELETE CASCADE;


--
-- TOC entry 3965 (class 2606 OID 19001)
-- Name: experimentos experimentos_id_ejecucion_preprocesamiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.experimentos
    ADD CONSTRAINT experimentos_id_ejecucion_preprocesamiento_fkey FOREIGN KEY (id_ejecucion_preprocesamiento) REFERENCES public.ejecuciones(id_ejecucion);


--
-- TOC entry 3953 (class 2606 OID 18732)
-- Name: mensajes_crudos mensajes_crudos_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_crudos
    ADD CONSTRAINT mensajes_crudos_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id);


--
-- TOC entry 3954 (class 2606 OID 18762)
-- Name: mensajes_limpios mensajes_limpios_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_limpios
    ADD CONSTRAINT mensajes_limpios_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id);


--
-- TOC entry 3960 (class 2606 OID 18919)
-- Name: salida_emojis_en_uso salida_emojis_en_uso_ejecucion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_emojis_en_uso
    ADD CONSTRAINT salida_emojis_en_uso_ejecucion_id_fkey FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion);


--
-- TOC entry 3962 (class 2606 OID 18947)
-- Name: salida_mensajes_excluidos salida_mensajes_excluidos_ejecucion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_mensajes_excluidos
    ADD CONSTRAINT salida_mensajes_excluidos_ejecucion_id_fkey FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion);


--
-- TOC entry 3963 (class 2606 OID 18963)
-- Name: salida_resumen salida_resumen_ejecucion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_resumen
    ADD CONSTRAINT salida_resumen_ejecucion_id_fkey FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion);


--
-- TOC entry 3961 (class 2606 OID 18933)
-- Name: salida_stopwords_aplicadas salida_stopwords_aplicadas_ejecucion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salida_stopwords_aplicadas
    ADD CONSTRAINT salida_stopwords_aplicadas_ejecucion_id_fkey FOREIGN KEY (ejecucion_id) REFERENCES public.ejecuciones(id_ejecucion);


--
-- TOC entry 3951 (class 2606 OID 18698)
-- Name: sentimientos_palabras sentimientos_palabras_sentimiento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_palabras
    ADD CONSTRAINT sentimientos_palabras_sentimiento_id_fkey FOREIGN KEY (sentimiento_id) REFERENCES public.sentimientos(id) ON DELETE CASCADE;


--
-- TOC entry 3955 (class 2606 OID 18781)
-- Name: sentimientos_por_mensaje sentimientos_por_mensaje_id_mensaje_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_por_mensaje
    ADD CONSTRAINT sentimientos_por_mensaje_id_mensaje_chat_id_fkey FOREIGN KEY (id_mensaje, chat_id) REFERENCES public.mensajes_limpios(id_mensaje, chat_id);


--
-- TOC entry 3952 (class 2606 OID 18712)
-- Name: sentimientos_raices sentimientos_raices_sentimiento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sentimientos_raices
    ADD CONSTRAINT sentimientos_raices_sentimiento_id_fkey FOREIGN KEY (sentimiento_id) REFERENCES public.sentimientos(id) ON DELETE CASCADE;


--
-- TOC entry 3956 (class 2606 OID 18795)
-- Name: tokens tokens_id_mensaje_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_id_mensaje_chat_id_fkey FOREIGN KEY (id_mensaje, chat_id) REFERENCES public.mensajes_limpios(id_mensaje, chat_id);


--
-- TOC entry 3957 (class 2606 OID 18851)
-- Name: topicos_etiquetas topicos_etiquetas_topico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_etiquetas
    ADD CONSTRAINT topicos_etiquetas_topico_id_fkey FOREIGN KEY (topico_id) REFERENCES public.topicos(id) ON DELETE CASCADE;


--
-- TOC entry 3959 (class 2606 OID 18875)
-- Name: topicos_por_documento topicos_por_documento_topico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_por_documento
    ADD CONSTRAINT topicos_por_documento_topico_id_fkey FOREIGN KEY (topico_id) REFERENCES public.topicos(id) ON DELETE CASCADE;


--
-- TOC entry 3958 (class 2606 OID 18863)
-- Name: topicos_terminos topicos_terminos_topico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topicos_terminos
    ADD CONSTRAINT topicos_terminos_topico_id_fkey FOREIGN KEY (topico_id) REFERENCES public.topicos(id) ON DELETE CASCADE;


--
-- TOC entry 4123 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- TOC entry 4125 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE abreviaturas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.abreviaturas TO anon;
GRANT ALL ON TABLE public.abreviaturas TO authenticated;
GRANT ALL ON TABLE public.abreviaturas TO service_role;


--
-- TOC entry 4127 (class 0 OID 0)
-- Dependencies: 279
-- Name: SEQUENCE abreviaturas_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.abreviaturas_id_seq TO anon;
GRANT ALL ON SEQUENCE public.abreviaturas_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.abreviaturas_id_seq TO service_role;


--
-- TOC entry 4128 (class 0 OID 0)
-- Dependencies: 342
-- Name: TABLE bitacora_registros; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.bitacora_registros TO anon;
GRANT ALL ON TABLE public.bitacora_registros TO authenticated;
GRANT ALL ON TABLE public.bitacora_registros TO service_role;


--
-- TOC entry 4130 (class 0 OID 0)
-- Dependencies: 341
-- Name: SEQUENCE bitacora_registros_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.bitacora_registros_id_seq TO anon;
GRANT ALL ON SEQUENCE public.bitacora_registros_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.bitacora_registros_id_seq TO service_role;


--
-- TOC entry 4132 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE cambios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.cambios TO anon;
GRANT ALL ON TABLE public.cambios TO authenticated;
GRANT ALL ON TABLE public.cambios TO service_role;


--
-- TOC entry 4134 (class 0 OID 0)
-- Dependencies: 337
-- Name: SEQUENCE cambios_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.cambios_id_seq TO anon;
GRANT ALL ON SEQUENCE public.cambios_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.cambios_id_seq TO service_role;


--
-- TOC entry 4135 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE chats; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.chats TO anon;
GRANT ALL ON TABLE public.chats TO authenticated;
GRANT ALL ON TABLE public.chats TO service_role;


--
-- TOC entry 4137 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE codigos_materia; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.codigos_materia TO anon;
GRANT ALL ON TABLE public.codigos_materia TO authenticated;
GRANT ALL ON TABLE public.codigos_materia TO service_role;


--
-- TOC entry 4138 (class 0 OID 0)
-- Dependencies: 324
-- Name: TABLE comparacion_niveles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.comparacion_niveles TO anon;
GRANT ALL ON TABLE public.comparacion_niveles TO authenticated;
GRANT ALL ON TABLE public.comparacion_niveles TO service_role;


--
-- TOC entry 4140 (class 0 OID 0)
-- Dependencies: 323
-- Name: SEQUENCE comparacion_niveles_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.comparacion_niveles_id_seq TO anon;
GRANT ALL ON SEQUENCE public.comparacion_niveles_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.comparacion_niveles_id_seq TO service_role;


--
-- TOC entry 4141 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE configuraciones; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.configuraciones TO anon;
GRANT ALL ON TABLE public.configuraciones TO authenticated;
GRANT ALL ON TABLE public.configuraciones TO service_role;


--
-- TOC entry 4143 (class 0 OID 0)
-- Dependencies: 343
-- Name: SEQUENCE configuraciones_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.configuraciones_id_seq TO anon;
GRANT ALL ON SEQUENCE public.configuraciones_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.configuraciones_id_seq TO service_role;


--
-- TOC entry 4145 (class 0 OID 0)
-- Dependencies: 336
-- Name: TABLE ejecucion_pasos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ejecucion_pasos TO anon;
GRANT ALL ON TABLE public.ejecucion_pasos TO authenticated;
GRANT ALL ON TABLE public.ejecucion_pasos TO service_role;


--
-- TOC entry 4147 (class 0 OID 0)
-- Dependencies: 335
-- Name: SEQUENCE ejecucion_pasos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.ejecucion_pasos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.ejecucion_pasos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.ejecucion_pasos_id_seq TO service_role;


--
-- TOC entry 4149 (class 0 OID 0)
-- Dependencies: 326
-- Name: TABLE ejecuciones; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ejecuciones TO anon;
GRANT ALL ON TABLE public.ejecuciones TO authenticated;
GRANT ALL ON TABLE public.ejecuciones TO service_role;


--
-- TOC entry 4151 (class 0 OID 0)
-- Dependencies: 325
-- Name: SEQUENCE ejecuciones_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.ejecuciones_id_seq TO anon;
GRANT ALL ON SEQUENCE public.ejecuciones_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.ejecuciones_id_seq TO service_role;


--
-- TOC entry 4153 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE emojis; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.emojis TO anon;
GRANT ALL ON TABLE public.emojis TO authenticated;
GRANT ALL ON TABLE public.emojis TO service_role;


--
-- TOC entry 4155 (class 0 OID 0)
-- Dependencies: 283
-- Name: SEQUENCE emojis_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.emojis_id_seq TO anon;
GRANT ALL ON SEQUENCE public.emojis_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.emojis_id_seq TO service_role;


--
-- TOC entry 4156 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE emoticonos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.emoticonos TO anon;
GRANT ALL ON TABLE public.emoticonos TO authenticated;
GRANT ALL ON TABLE public.emoticonos TO service_role;


--
-- TOC entry 4158 (class 0 OID 0)
-- Dependencies: 281
-- Name: SEQUENCE emoticonos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.emoticonos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.emoticonos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.emoticonos_id_seq TO service_role;


--
-- TOC entry 4160 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE experimentos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.experimentos TO anon;
GRANT ALL ON TABLE public.experimentos TO authenticated;
GRANT ALL ON TABLE public.experimentos TO service_role;


--
-- TOC entry 4162 (class 0 OID 0)
-- Dependencies: 339
-- Name: SEQUENCE experimentos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.experimentos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.experimentos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.experimentos_id_seq TO service_role;


--
-- TOC entry 4163 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE genero; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.genero TO anon;
GRANT ALL ON TABLE public.genero TO authenticated;
GRANT ALL ON TABLE public.genero TO service_role;


--
-- TOC entry 4165 (class 0 OID 0)
-- Dependencies: 285
-- Name: SEQUENCE genero_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.genero_id_seq TO anon;
GRANT ALL ON SEQUENCE public.genero_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.genero_id_seq TO service_role;


--
-- TOC entry 4166 (class 0 OID 0)
-- Dependencies: 346
-- Name: TABLE graficos_info; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.graficos_info TO anon;
GRANT ALL ON TABLE public.graficos_info TO authenticated;
GRANT ALL ON TABLE public.graficos_info TO service_role;


--
-- TOC entry 4168 (class 0 OID 0)
-- Dependencies: 345
-- Name: SEQUENCE graficos_info_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.graficos_info_id_seq TO anon;
GRANT ALL ON SEQUENCE public.graficos_info_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.graficos_info_id_seq TO service_role;


--
-- TOC entry 4169 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE justificaciones_analisis; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.justificaciones_analisis TO anon;
GRANT ALL ON TABLE public.justificaciones_analisis TO authenticated;
GRANT ALL ON TABLE public.justificaciones_analisis TO service_role;


--
-- TOC entry 4170 (class 0 OID 0)
-- Dependencies: 322
-- Name: TABLE libreria_sentimientos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.libreria_sentimientos TO anon;
GRANT ALL ON TABLE public.libreria_sentimientos TO authenticated;
GRANT ALL ON TABLE public.libreria_sentimientos TO service_role;


--
-- TOC entry 4172 (class 0 OID 0)
-- Dependencies: 321
-- Name: SEQUENCE libreria_sentimientos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.libreria_sentimientos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.libreria_sentimientos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.libreria_sentimientos_id_seq TO service_role;


--
-- TOC entry 4173 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE mensajes_crudos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mensajes_crudos TO anon;
GRANT ALL ON TABLE public.mensajes_crudos TO authenticated;
GRANT ALL ON TABLE public.mensajes_crudos TO service_role;


--
-- TOC entry 4175 (class 0 OID 0)
-- Dependencies: 302
-- Name: TABLE mensajes_limpios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mensajes_limpios TO anon;
GRANT ALL ON TABLE public.mensajes_limpios TO authenticated;
GRANT ALL ON TABLE public.mensajes_limpios TO service_role;


--
-- TOC entry 4177 (class 0 OID 0)
-- Dependencies: 308
-- Name: TABLE niveles_por_periodo; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.niveles_por_periodo TO anon;
GRANT ALL ON TABLE public.niveles_por_periodo TO authenticated;
GRANT ALL ON TABLE public.niveles_por_periodo TO service_role;


--
-- TOC entry 4179 (class 0 OID 0)
-- Dependencies: 307
-- Name: SEQUENCE niveles_por_periodo_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.niveles_por_periodo_id_seq TO anon;
GRANT ALL ON SEQUENCE public.niveles_por_periodo_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.niveles_por_periodo_id_seq TO service_role;


--
-- TOC entry 4180 (class 0 OID 0)
-- Dependencies: 293
-- Name: TABLE palabras_anuncio; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.palabras_anuncio TO anon;
GRANT ALL ON TABLE public.palabras_anuncio TO authenticated;
GRANT ALL ON TABLE public.palabras_anuncio TO service_role;


--
-- TOC entry 4182 (class 0 OID 0)
-- Dependencies: 292
-- Name: SEQUENCE palabras_anuncio_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.palabras_anuncio_id_seq TO anon;
GRANT ALL ON SEQUENCE public.palabras_anuncio_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.palabras_anuncio_id_seq TO service_role;


--
-- TOC entry 4183 (class 0 OID 0)
-- Dependencies: 291
-- Name: TABLE periodos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.periodos TO anon;
GRANT ALL ON TABLE public.periodos TO authenticated;
GRANT ALL ON TABLE public.periodos TO service_role;


--
-- TOC entry 4185 (class 0 OID 0)
-- Dependencies: 290
-- Name: SEQUENCE periodos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.periodos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.periodos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.periodos_id_seq TO service_role;


--
-- TOC entry 4186 (class 0 OID 0)
-- Dependencies: 328
-- Name: TABLE salida_emojis_en_uso; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.salida_emojis_en_uso TO anon;
GRANT ALL ON TABLE public.salida_emojis_en_uso TO authenticated;
GRANT ALL ON TABLE public.salida_emojis_en_uso TO service_role;


--
-- TOC entry 4188 (class 0 OID 0)
-- Dependencies: 327
-- Name: SEQUENCE salida_emojis_en_uso_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.salida_emojis_en_uso_id_seq TO anon;
GRANT ALL ON SEQUENCE public.salida_emojis_en_uso_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.salida_emojis_en_uso_id_seq TO service_role;


--
-- TOC entry 4189 (class 0 OID 0)
-- Dependencies: 332
-- Name: TABLE salida_mensajes_excluidos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.salida_mensajes_excluidos TO anon;
GRANT ALL ON TABLE public.salida_mensajes_excluidos TO authenticated;
GRANT ALL ON TABLE public.salida_mensajes_excluidos TO service_role;


--
-- TOC entry 4191 (class 0 OID 0)
-- Dependencies: 331
-- Name: SEQUENCE salida_mensajes_excluidos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.salida_mensajes_excluidos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.salida_mensajes_excluidos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.salida_mensajes_excluidos_id_seq TO service_role;


--
-- TOC entry 4192 (class 0 OID 0)
-- Dependencies: 334
-- Name: TABLE salida_resumen; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.salida_resumen TO anon;
GRANT ALL ON TABLE public.salida_resumen TO authenticated;
GRANT ALL ON TABLE public.salida_resumen TO service_role;


--
-- TOC entry 4194 (class 0 OID 0)
-- Dependencies: 333
-- Name: SEQUENCE salida_resumen_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.salida_resumen_id_seq TO anon;
GRANT ALL ON SEQUENCE public.salida_resumen_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.salida_resumen_id_seq TO service_role;


--
-- TOC entry 4195 (class 0 OID 0)
-- Dependencies: 330
-- Name: TABLE salida_stopwords_aplicadas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.salida_stopwords_aplicadas TO anon;
GRANT ALL ON TABLE public.salida_stopwords_aplicadas TO authenticated;
GRANT ALL ON TABLE public.salida_stopwords_aplicadas TO service_role;


--
-- TOC entry 4197 (class 0 OID 0)
-- Dependencies: 329
-- Name: SEQUENCE salida_stopwords_aplicadas_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.salida_stopwords_aplicadas_id_seq TO anon;
GRANT ALL ON SEQUENCE public.salida_stopwords_aplicadas_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.salida_stopwords_aplicadas_id_seq TO service_role;


--
-- TOC entry 4199 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE sentimientos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sentimientos TO anon;
GRANT ALL ON TABLE public.sentimientos TO authenticated;
GRANT ALL ON TABLE public.sentimientos TO service_role;


--
-- TOC entry 4201 (class 0 OID 0)
-- Dependencies: 294
-- Name: SEQUENCE sentimientos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.sentimientos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.sentimientos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sentimientos_id_seq TO service_role;


--
-- TOC entry 4203 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE sentimientos_palabras; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sentimientos_palabras TO anon;
GRANT ALL ON TABLE public.sentimientos_palabras TO authenticated;
GRANT ALL ON TABLE public.sentimientos_palabras TO service_role;


--
-- TOC entry 4205 (class 0 OID 0)
-- Dependencies: 296
-- Name: SEQUENCE sentimientos_palabras_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.sentimientos_palabras_id_seq TO anon;
GRANT ALL ON SEQUENCE public.sentimientos_palabras_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sentimientos_palabras_id_seq TO service_role;


--
-- TOC entry 4207 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE sentimientos_por_mensaje; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sentimientos_por_mensaje TO anon;
GRANT ALL ON TABLE public.sentimientos_por_mensaje TO authenticated;
GRANT ALL ON TABLE public.sentimientos_por_mensaje TO service_role;


--
-- TOC entry 4209 (class 0 OID 0)
-- Dependencies: 303
-- Name: SEQUENCE sentimientos_por_mensaje_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.sentimientos_por_mensaje_id_seq TO anon;
GRANT ALL ON SEQUENCE public.sentimientos_por_mensaje_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sentimientos_por_mensaje_id_seq TO service_role;


--
-- TOC entry 4211 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE sentimientos_raices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sentimientos_raices TO anon;
GRANT ALL ON TABLE public.sentimientos_raices TO authenticated;
GRANT ALL ON TABLE public.sentimientos_raices TO service_role;


--
-- TOC entry 4213 (class 0 OID 0)
-- Dependencies: 298
-- Name: SEQUENCE sentimientos_raices_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.sentimientos_raices_id_seq TO anon;
GRANT ALL ON SEQUENCE public.sentimientos_raices_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sentimientos_raices_id_seq TO service_role;


--
-- TOC entry 4215 (class 0 OID 0)
-- Dependencies: 310
-- Name: TABLE serie_sentimientos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.serie_sentimientos TO anon;
GRANT ALL ON TABLE public.serie_sentimientos TO authenticated;
GRANT ALL ON TABLE public.serie_sentimientos TO service_role;


--
-- TOC entry 4217 (class 0 OID 0)
-- Dependencies: 309
-- Name: SEQUENCE serie_sentimientos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.serie_sentimientos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.serie_sentimientos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.serie_sentimientos_id_seq TO service_role;


--
-- TOC entry 4218 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE stopwords; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.stopwords TO anon;
GRANT ALL ON TABLE public.stopwords TO authenticated;
GRANT ALL ON TABLE public.stopwords TO service_role;


--
-- TOC entry 4220 (class 0 OID 0)
-- Dependencies: 288
-- Name: SEQUENCE stopwords_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.stopwords_id_seq TO anon;
GRANT ALL ON SEQUENCE public.stopwords_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.stopwords_id_seq TO service_role;


--
-- TOC entry 4222 (class 0 OID 0)
-- Dependencies: 312
-- Name: TABLE tfidf_resultados; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tfidf_resultados TO anon;
GRANT ALL ON TABLE public.tfidf_resultados TO authenticated;
GRANT ALL ON TABLE public.tfidf_resultados TO service_role;


--
-- TOC entry 4224 (class 0 OID 0)
-- Dependencies: 311
-- Name: SEQUENCE tfidf_resultados_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.tfidf_resultados_id_seq TO anon;
GRANT ALL ON SEQUENCE public.tfidf_resultados_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.tfidf_resultados_id_seq TO service_role;


--
-- TOC entry 4226 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE tokens; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tokens TO anon;
GRANT ALL ON TABLE public.tokens TO authenticated;
GRANT ALL ON TABLE public.tokens TO service_role;


--
-- TOC entry 4228 (class 0 OID 0)
-- Dependencies: 305
-- Name: SEQUENCE tokens_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.tokens_id_seq TO anon;
GRANT ALL ON SEQUENCE public.tokens_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.tokens_id_seq TO service_role;


--
-- TOC entry 4229 (class 0 OID 0)
-- Dependencies: 314
-- Name: TABLE topicos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.topicos TO anon;
GRANT ALL ON TABLE public.topicos TO authenticated;
GRANT ALL ON TABLE public.topicos TO service_role;


--
-- TOC entry 4230 (class 0 OID 0)
-- Dependencies: 316
-- Name: TABLE topicos_etiquetas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.topicos_etiquetas TO anon;
GRANT ALL ON TABLE public.topicos_etiquetas TO authenticated;
GRANT ALL ON TABLE public.topicos_etiquetas TO service_role;


--
-- TOC entry 4232 (class 0 OID 0)
-- Dependencies: 315
-- Name: SEQUENCE topicos_etiquetas_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.topicos_etiquetas_id_seq TO anon;
GRANT ALL ON SEQUENCE public.topicos_etiquetas_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.topicos_etiquetas_id_seq TO service_role;


--
-- TOC entry 4234 (class 0 OID 0)
-- Dependencies: 313
-- Name: SEQUENCE topicos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.topicos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.topicos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.topicos_id_seq TO service_role;


--
-- TOC entry 4235 (class 0 OID 0)
-- Dependencies: 320
-- Name: TABLE topicos_por_documento; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.topicos_por_documento TO anon;
GRANT ALL ON TABLE public.topicos_por_documento TO authenticated;
GRANT ALL ON TABLE public.topicos_por_documento TO service_role;


--
-- TOC entry 4237 (class 0 OID 0)
-- Dependencies: 319
-- Name: SEQUENCE topicos_por_documento_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.topicos_por_documento_id_seq TO anon;
GRANT ALL ON SEQUENCE public.topicos_por_documento_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.topicos_por_documento_id_seq TO service_role;


--
-- TOC entry 4238 (class 0 OID 0)
-- Dependencies: 318
-- Name: TABLE topicos_terminos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.topicos_terminos TO anon;
GRANT ALL ON TABLE public.topicos_terminos TO authenticated;
GRANT ALL ON TABLE public.topicos_terminos TO service_role;


--
-- TOC entry 4240 (class 0 OID 0)
-- Dependencies: 317
-- Name: SEQUENCE topicos_terminos_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.topicos_terminos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.topicos_terminos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.topicos_terminos_id_seq TO service_role;


--
-- TOC entry 4241 (class 0 OID 0)
-- Dependencies: 348
-- Name: TABLE v_ejecucion_resumen; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.v_ejecucion_resumen TO anon;
GRANT ALL ON TABLE public.v_ejecucion_resumen TO authenticated;
GRANT ALL ON TABLE public.v_ejecucion_resumen TO service_role;


--
-- TOC entry 4242 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE v_resumen_sentimientos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.v_resumen_sentimientos TO anon;
GRANT ALL ON TABLE public.v_resumen_sentimientos TO authenticated;
GRANT ALL ON TABLE public.v_resumen_sentimientos TO service_role;


--
-- TOC entry 2517 (class 826 OID 16490)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2518 (class 826 OID 16491)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2516 (class 826 OID 16489)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2520 (class 826 OID 16493)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2515 (class 826 OID 16488)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- TOC entry 2519 (class 826 OID 16492)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


-- Completed on 2026-11-08 11:09:05

--
-- PostgreSQL database dump complete
--

\unrestrict gNW9cbdade8RdqnJsfRGFyapAuNE9H1GbzNbXWPCrajWBS0YaNBGMrNzpX6K1sy

