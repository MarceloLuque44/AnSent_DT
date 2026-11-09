--
-- Tablas para los gráficos ECharts adicionales del dashboard (#9-14: TF-IDF, tópicos,
-- tópicos en el tiempo, shallow linguistic, nivel mensaje, calor).
-- Añadir a Esquema4.sql sin modificar archivos existentes.
--

--
-- TOC entry analisis_grafico_tfidf; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_tfidf (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    doc text NOT NULL,
    token text NOT NULL,
    n integer NOT NULL,
    tf numeric NOT NULL,
    idf numeric NOT NULL,
    tf_idf numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_tfidf OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_tfidf IS 'Terminos mas distintivos por documento (TF-IDF) que consume g_tfidf.';


--
-- TOC entry analisis_grafico_tfidf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_tfidf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_tfidf_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_tfidf_id_seq OWNED BY public.analisis_grafico_tfidf.id;

--
-- TOC entry analisis_grafico_topicos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_topicos (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    topico text NOT NULL,
    etiqueta text NOT NULL,
    termino text NOT NULL,
    beta numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_topicos OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_topicos IS 'Palabras mas probables de cada topico (LDA) que consume g_topicos.';


--
-- TOC entry analisis_grafico_topicos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_topicos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_topicos_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_topicos_id_seq OWNED BY public.analisis_grafico_topicos.id;

--
-- TOC entry analisis_grafico_topicos_tiempo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_topicos_tiempo (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    anio_mes text NOT NULL,
    topico text NOT NULL,
    etiqueta text NOT NULL,
    peso_pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_topicos_tiempo OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_topicos_tiempo IS 'Peso de cada topico por mes (LDA) que consume g_topicos_tiempo.';


--
-- TOC entry analisis_grafico_topicos_tiempo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq OWNED BY public.analisis_grafico_topicos_tiempo.id;

--
-- TOC entry analisis_grafico_upos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_upos (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    clase text NOT NULL,
    n integer NOT NULL,
    pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_upos OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_upos IS 'Categorias gramaticales (shallow linguistic) que consume g_upos.';


--
-- TOC entry analisis_grafico_upos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_upos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_upos_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_upos_id_seq OWNED BY public.analisis_grafico_upos.id;

--
-- TOC entry analisis_grafico_nivel_mensaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_nivel_mensaje (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    sentimiento text NOT NULL,
    mensaje_pct numeric NOT NULL,
    periodo_pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_nivel_mensaje OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_nivel_mensaje IS 'Nivel de un mensaje representante frente a su periodo que consume g_nivel_mensaje.';


--
-- TOC entry analisis_grafico_nivel_mensaje_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq OWNED BY public.analisis_grafico_nivel_mensaje.id;

--
-- TOC entry analisis_grafico_calor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_calor (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    dia text NOT NULL,
    hora integer NOT NULL,
    freq integer NOT NULL
);


ALTER TABLE public.analisis_grafico_calor OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_calor IS 'Mapa de calor actividad: dia de la semana x hora que consume g_calor.';


--
-- TOC entry analisis_grafico_calor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_calor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_calor_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_calor_id_seq OWNED BY public.analisis_grafico_calor.id;


--
-- Primary keys
--

ALTER TABLE ONLY public.analisis_grafico_tfidf
    ADD CONSTRAINT analisis_grafico_tfidf_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_topicos
    ADD CONSTRAINT analisis_grafico_topicos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_topicos_tiempo
    ADD CONSTRAINT analisis_grafico_topicos_tiempo_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_upos
    ADD CONSTRAINT analisis_grafico_upos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_nivel_mensaje
    ADD CONSTRAINT analisis_grafico_nivel_mensaje_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_calor
    ADD CONSTRAINT analisis_grafico_calor_pkey PRIMARY KEY (id);


--
-- Uniques
--

ALTER TABLE ONLY public.analisis_grafico_tfidf
    ADD CONSTRAINT analisis_grafico_tfidf_id_analisis_doc_token_key UNIQUE (id_analisis, doc, token);

ALTER TABLE ONLY public.analisis_grafico_topicos
    ADD CONSTRAINT analisis_grafico_topicos_id_analisis_topico_termino_key UNIQUE (id_analisis, topico, termino);

ALTER TABLE ONLY public.analisis_grafico_topicos_tiempo
    ADD CONSTRAINT analisis_grafico_topicos_tiempo_id_analisis_anio_mes_topico_key UNIQUE (id_analisis, anio_mes, topico);

ALTER TABLE ONLY public.analisis_grafico_upos
    ADD CONSTRAINT analisis_grafico_upos_id_analisis_clase_key UNIQUE (id_analisis, clase);

ALTER TABLE ONLY public.analisis_grafico_nivel_mensaje
    ADD CONSTRAINT analisis_grafico_nivel_mensaje_id_analisis_sentimiento_key UNIQUE (id_analisis, sentimiento);

ALTER TABLE ONLY public.analisis_grafico_calor
    ADD CONSTRAINT analisis_grafico_calor_id_analisis_dia_hora_key UNIQUE (id_analisis, dia, hora);


--
-- Foreign keys
--

ALTER TABLE ONLY public.analisis_grafico_tfidf
    ADD CONSTRAINT analisis_grafico_tfidf_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_topicos
    ADD CONSTRAINT analisis_grafico_topicos_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_topicos_tiempo
    ADD CONSTRAINT analisis_grafico_topicos_tiempo_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_upos
    ADD CONSTRAINT analisis_grafico_upos_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_nivel_mensaje
    ADD CONSTRAINT analisis_grafico_nivel_mensaje_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_calor
    ADD CONSTRAINT analisis_grafico_calor_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


--
-- Indexes
--

CREATE INDEX idx_analisis_grafico_tfidf_analisis ON public.analisis_grafico_tfidf USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_topicos_analisis ON public.analisis_grafico_topicos USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_topicos_tiempo_analisis ON public.analisis_grafico_topicos_tiempo USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_upos_analisis ON public.analisis_grafico_upos USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_nivel_mensaje_analisis ON public.analisis_grafico_nivel_mensaje USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_calor_analisis ON public.analisis_grafico_calor USING btree (id_analisis);


--
-- Grants tables
--

GRANT ALL ON TABLE public.analisis_grafico_tfidf TO anon;
GRANT ALL ON TABLE public.analisis_grafico_tfidf TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_tfidf TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_topicos TO anon;
GRANT ALL ON TABLE public.analisis_grafico_topicos TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_topicos TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_topicos_tiempo TO anon;
GRANT ALL ON TABLE public.analisis_grafico_topicos_tiempo TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_topicos_tiempo TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_upos TO anon;
GRANT ALL ON TABLE public.analisis_grafico_upos TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_upos TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_nivel_mensaje TO anon;
GRANT ALL ON TABLE public.analisis_grafico_nivel_mensaje TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_nivel_mensaje TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_calor TO anon;
GRANT ALL ON TABLE public.analisis_grafico_calor TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_calor TO service_role;


--
-- Grants sequences
--

GRANT ALL ON SEQUENCE public.analisis_grafico_tfidf_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_tfidf_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_tfidf_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_topicos_tiempo_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_upos_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_upos_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_upos_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_nivel_mensaje_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_calor_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_calor_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_calor_id_seq TO service_role;
