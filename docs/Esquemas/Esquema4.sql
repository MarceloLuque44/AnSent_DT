--
-- PostgreSQL database dump
--

\restrict HmdEYmgX9CPMJZWnnIidWpGFSbglI19p0ViMgoXbuRWB7bsgSsD95jNriiaCvIy

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.4

-- Started on 2026-11-08 20:36:41

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
-- TOC entry 17 (class 2615 OID 19343)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 3770 (class 0 OID 0)
-- Dependencies: 17
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 278 (class 1259 OID 19344)
-- Name: analisis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis (
    id_analisis integer NOT NULL,
    nombre character varying(100) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    n_mensajes integer,
    responsable character varying(200),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.analisis OWNER TO postgres;

--
-- TOC entry 3771 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE analisis; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis IS 'Cabecera de cada análisis por periodo (objeto a de analizar_periodo).';


--
-- TOC entry 279 (class 1259 OID 19348)
-- Name: analisis_comparacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_comparacion (
    id_comparacion integer NOT NULL,
    nombre character varying(200) NOT NULL,
    id_analisis_a integer NOT NULL,
    id_analisis_b integer NOT NULL,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT analisis_comparacion_check CHECK ((id_analisis_a <> id_analisis_b))
);


ALTER TABLE public.analisis_comparacion OWNER TO postgres;

--
-- TOC entry 3772 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE analisis_comparacion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis_comparacion IS 'Cabecera de una comparación A vs B; los niveles están en analisis_nivel.';


--
-- TOC entry 280 (class 1259 OID 19353)
-- Name: analisis_comparacion_id_comparacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_comparacion_id_comparacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_comparacion_id_comparacion_seq OWNER TO postgres;

--
-- TOC entry 3773 (class 0 OID 0)
-- Dependencies: 280
-- Name: analisis_comparacion_id_comparacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_comparacion_id_comparacion_seq OWNED BY public.analisis_comparacion.id_comparacion;


--
-- TOC entry 281 (class 1259 OID 19354)
-- Name: analisis_id_analisis_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_id_analisis_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_id_analisis_seq OWNER TO postgres;

--
-- TOC entry 3774 (class 0 OID 0)
-- Dependencies: 281
-- Name: analisis_id_analisis_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_id_analisis_seq OWNED BY public.analisis.id_analisis;


--
-- TOC entry 282 (class 1259 OID 19355)
-- Name: analisis_nivel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_nivel (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    sentimiento character varying(50) NOT NULL,
    nivel_pct numeric(6,3) NOT NULL,
    mensajes_pct numeric(6,3),
    n_mensajes integer,
    orden integer,
    CONSTRAINT analisis_nivel_nivel_pct_check CHECK (((nivel_pct >= (0)::numeric) AND (nivel_pct <= (100)::numeric)))
);


ALTER TABLE public.analisis_nivel OWNER TO postgres;

--
-- TOC entry 3775 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE analisis_nivel; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis_nivel IS 'Nivel por sentimiento que consume el gráfico de barras del dashboard.';


--
-- TOC entry 283 (class 1259 OID 19359)
-- Name: analisis_nivel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_nivel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_nivel_id_seq OWNER TO postgres;

--
-- TOC entry 3776 (class 0 OID 0)
-- Dependencies: 283
-- Name: analisis_nivel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_nivel_id_seq OWNED BY public.analisis_nivel.id;


--
-- TOC entry 284 (class 1259 OID 19360)
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
-- TOC entry 3777 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE cambios; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cambios IS 'Cambios detectados automáticamente en código y diccionarios (vigilar_cambios).';


--
-- TOC entry 285 (class 1259 OID 19365)
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
-- TOC entry 3778 (class 0 OID 0)
-- Dependencies: 285
-- Name: cambios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cambios_id_seq OWNED BY public.cambios.id;


--
-- TOC entry 3586 (class 2604 OID 19366)
-- Name: analisis id_analisis; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis ALTER COLUMN id_analisis SET DEFAULT nextval('public.analisis_id_analisis_seq'::regclass);


--
-- TOC entry 3588 (class 2604 OID 19367)
-- Name: analisis_comparacion id_comparacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion ALTER COLUMN id_comparacion SET DEFAULT nextval('public.analisis_comparacion_id_comparacion_seq'::regclass);


--
-- TOC entry 3590 (class 2604 OID 19368)
-- Name: analisis_nivel id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel ALTER COLUMN id SET DEFAULT nextval('public.analisis_nivel_id_seq'::regclass);


--
-- TOC entry 3591 (class 2604 OID 19369)
-- Name: cambios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios ALTER COLUMN id SET DEFAULT nextval('public.cambios_id_seq'::regclass);


--
-- TOC entry 3599 (class 2606 OID 19371)
-- Name: analisis_comparacion analisis_comparacion_id_analisis_a_id_analisis_b_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion
    ADD CONSTRAINT analisis_comparacion_id_analisis_a_id_analisis_b_key UNIQUE (id_analisis_a, id_analisis_b);


--
-- TOC entry 3601 (class 2606 OID 19373)
-- Name: analisis_comparacion analisis_comparacion_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion
    ADD CONSTRAINT analisis_comparacion_nombre_key UNIQUE (nombre);


--
-- TOC entry 3603 (class 2606 OID 19375)
-- Name: analisis_comparacion analisis_comparacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion
    ADD CONSTRAINT analisis_comparacion_pkey PRIMARY KEY (id_comparacion);


--
-- TOC entry 3607 (class 2606 OID 19377)
-- Name: analisis_nivel analisis_nivel_id_analisis_sentimiento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_id_analisis_sentimiento_key UNIQUE (id_analisis, sentimiento);


--
-- TOC entry 3609 (class 2606 OID 19379)
-- Name: analisis_nivel analisis_nivel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_pkey PRIMARY KEY (id);


--
-- TOC entry 3595 (class 2606 OID 19381)
-- Name: analisis analisis_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis
    ADD CONSTRAINT analisis_nombre_key UNIQUE (nombre);


--
-- TOC entry 3597 (class 2606 OID 19383)
-- Name: analisis analisis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis
    ADD CONSTRAINT analisis_pkey PRIMARY KEY (id_analisis);


--
-- TOC entry 3612 (class 2606 OID 19385)
-- Name: cambios cambios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios
    ADD CONSTRAINT cambios_pkey PRIMARY KEY (id);


--
-- TOC entry 3604 (class 1259 OID 19386)
-- Name: idx_analisis_comparacion_a; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_comparacion_a ON public.analisis_comparacion USING btree (id_analisis_a);


--
-- TOC entry 3605 (class 1259 OID 19387)
-- Name: idx_analisis_comparacion_b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_comparacion_b ON public.analisis_comparacion USING btree (id_analisis_b);


--
-- TOC entry 3610 (class 1259 OID 19388)
-- Name: idx_analisis_nivel_analisis; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_nivel_analisis ON public.analisis_nivel USING btree (id_analisis);


--
-- TOC entry 3613 (class 2606 OID 19389)
-- Name: analisis_comparacion analisis_comparacion_id_analisis_a_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion
    ADD CONSTRAINT analisis_comparacion_id_analisis_a_fkey FOREIGN KEY (id_analisis_a) REFERENCES public.analisis(id_analisis);


--
-- TOC entry 3614 (class 2606 OID 19394)
-- Name: analisis_comparacion analisis_comparacion_id_analisis_b_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_comparacion
    ADD CONSTRAINT analisis_comparacion_id_analisis_b_fkey FOREIGN KEY (id_analisis_b) REFERENCES public.analisis(id_analisis);


--
-- TOC entry 3615 (class 2606 OID 19399)
-- Name: analisis_nivel analisis_nivel_id_analisis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


-- Completed on 2026-11-08 20:36:50

--
-- PostgreSQL database dump complete
--

\unrestrict HmdEYmgX9CPMJZWnnIidWpGFSbglI19p0ViMgoXbuRWB7bsgSsD95jNriiaCvIy

