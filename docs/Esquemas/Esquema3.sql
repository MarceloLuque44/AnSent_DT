--
-- PostgreSQL database dump
--

\restrict nzcPWVxXJbcdJzG5tKBAT6wpTBAFUGWK5nphhF0Exrvt9sjPKtzcr8F0lZng7zO

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.4

-- Started on 2026-11-08 19:14:02

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
-- TOC entry 3755 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 281 (class 1259 OID 19166)
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
-- TOC entry 3757 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE analisis; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis IS 'Cabecera de cada análisis por periodo (objeto a de analizar_periodo).';


--
-- TOC entry 280 (class 1259 OID 19165)
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
-- TOC entry 3759 (class 0 OID 0)
-- Dependencies: 280
-- Name: analisis_id_analisis_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_id_analisis_seq OWNED BY public.analisis.id_analisis;


--
-- TOC entry 283 (class 1259 OID 19176)
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
-- TOC entry 3761 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE analisis_nivel; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis_nivel IS 'Nivel por sentimiento que consume el gráfico de barras del dashboard.';


--
-- TOC entry 282 (class 1259 OID 19175)
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
-- TOC entry 3763 (class 0 OID 0)
-- Dependencies: 282
-- Name: analisis_nivel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_nivel_id_seq OWNED BY public.analisis_nivel.id;


--
-- TOC entry 279 (class 1259 OID 18984)
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
-- TOC entry 3765 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE cambios; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cambios IS 'Cambios detectados automáticamente en código y diccionarios (vigilar_cambios).';


--
-- TOC entry 278 (class 1259 OID 18983)
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
-- TOC entry 3767 (class 0 OID 0)
-- Dependencies: 278
-- Name: cambios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cambios_id_seq OWNED BY public.cambios.id;


--
-- TOC entry 3585 (class 2604 OID 19169)
-- Name: analisis id_analisis; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis ALTER COLUMN id_analisis SET DEFAULT nextval('public.analisis_id_analisis_seq'::regclass);


--
-- TOC entry 3587 (class 2604 OID 19179)
-- Name: analisis_nivel id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel ALTER COLUMN id SET DEFAULT nextval('public.analisis_nivel_id_seq'::regclass);


--
-- TOC entry 3584 (class 2604 OID 18987)
-- Name: cambios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios ALTER COLUMN id SET DEFAULT nextval('public.cambios_id_seq'::regclass);


--
-- TOC entry 3596 (class 2606 OID 19184)
-- Name: analisis_nivel analisis_nivel_id_analisis_sentimiento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_id_analisis_sentimiento_key UNIQUE (id_analisis, sentimiento);


--
-- TOC entry 3598 (class 2606 OID 19182)
-- Name: analisis_nivel analisis_nivel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_pkey PRIMARY KEY (id);


--
-- TOC entry 3592 (class 2606 OID 19174)
-- Name: analisis analisis_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis
    ADD CONSTRAINT analisis_nombre_key UNIQUE (nombre);


--
-- TOC entry 3594 (class 2606 OID 19172)
-- Name: analisis analisis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis
    ADD CONSTRAINT analisis_pkey PRIMARY KEY (id_analisis);


--
-- TOC entry 3590 (class 2606 OID 18991)
-- Name: cambios cambios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambios
    ADD CONSTRAINT cambios_pkey PRIMARY KEY (id);


--
-- TOC entry 3599 (class 1259 OID 19190)
-- Name: idx_analisis_nivel_analisis; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_nivel_analisis ON public.analisis_nivel USING btree (id_analisis);


--
-- TOC entry 3600 (class 2606 OID 19185)
-- Name: analisis_nivel analisis_nivel_id_analisis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_nivel
    ADD CONSTRAINT analisis_nivel_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


--
-- TOC entry 3756 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- TOC entry 3758 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE analisis; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.analisis TO anon;
GRANT ALL ON TABLE public.analisis TO authenticated;
GRANT ALL ON TABLE public.analisis TO service_role;


--
-- TOC entry 3760 (class 0 OID 0)
-- Dependencies: 280
-- Name: SEQUENCE analisis_id_analisis_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.analisis_id_analisis_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_id_analisis_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_id_analisis_seq TO service_role;


--
-- TOC entry 3762 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE analisis_nivel; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.analisis_nivel TO anon;
GRANT ALL ON TABLE public.analisis_nivel TO authenticated;
GRANT ALL ON TABLE public.analisis_nivel TO service_role;


--
-- TOC entry 3764 (class 0 OID 0)
-- Dependencies: 282
-- Name: SEQUENCE analisis_nivel_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.analisis_nivel_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_nivel_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_nivel_id_seq TO service_role;


--
-- TOC entry 3766 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE cambios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.cambios TO anon;
GRANT ALL ON TABLE public.cambios TO authenticated;
GRANT ALL ON TABLE public.cambios TO service_role;


--
-- TOC entry 3768 (class 0 OID 0)
-- Dependencies: 278
-- Name: SEQUENCE cambios_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.cambios_id_seq TO anon;
GRANT ALL ON SEQUENCE public.cambios_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.cambios_id_seq TO service_role;


--
-- TOC entry 2344 (class 826 OID 16490)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2345 (class 826 OID 16491)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2343 (class 826 OID 16489)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2347 (class 826 OID 16493)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2342 (class 826 OID 16488)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- TOC entry 2346 (class 826 OID 16492)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


-- Completed on 2026-11-08 19:14:12

--
-- PostgreSQL database dump complete
--

\unrestrict nzcPWVxXJbcdJzG5tKBAT6wpTBAFUGWK5nphhF0Exrvt9sjPKtzcr8F0lZng7zO

