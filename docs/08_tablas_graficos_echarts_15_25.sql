--
-- Tablas para los gráficos ECharts adicionales del dashboard (#15-25:
-- volumen, evolucion anual, sent_heat, dominante, polaridad tiempo,
-- sent hora heat, correlacion, palabras, emojis, libreria vs propios,
-- diferencia).
-- Añadir a Esquema4.sql sin modificar archivos existentes.
--


--
-- TOC entry analisis_grafico_volumen; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_volumen (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    fecha date NOT NULL,
    freq integer NOT NULL
);


ALTER TABLE public.analisis_grafico_volumen OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_volumen IS 'Volumen de mensajes por fecha que consume g_volumen.';


--
-- TOC entry analisis_grafico_volumen_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_volumen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_volumen_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_volumen_id_seq OWNED BY public.analisis_grafico_volumen.id;


--
-- TOC entry analisis_grafico_evolucion_anual; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_evolucion_anual (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    anio integer NOT NULL,
    sentimiento text NOT NULL,
    pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_evolucion_anual OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_evolucion_anual IS 'Evolucion de sentimientos por ano que consume g_evolucion_anual.';


--
-- TOC entry analisis_grafico_evolucion_anual_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_evolucion_anual_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_evolucion_anual_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_evolucion_anual_id_seq OWNED BY public.analisis_grafico_evolucion_anual.id;


--
-- TOC entry analisis_grafico_sent_heat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_sent_heat (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    fecha date NOT NULL,
    sentimiento text NOT NULL,
    pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_sent_heat OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_sent_heat IS 'Mapa de calor sentimiento x tiempo que consume g_sent_heat.';


--
-- TOC entry analisis_grafico_sent_heat_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_sent_heat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_sent_heat_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_sent_heat_id_seq OWNED BY public.analisis_grafico_sent_heat.id;


--
-- TOC entry analisis_grafico_dominante; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_dominante (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    fecha date NOT NULL,
    dom text NOT NULL,
    freq integer NOT NULL
);


ALTER TABLE public.analisis_grafico_dominante OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_dominante IS 'Sentimiento dominante por fecha (frecuencia) que consume g_dominante.';


--
-- TOC entry analisis_grafico_dominante_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_dominante_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_dominante_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_dominante_id_seq OWNED BY public.analisis_grafico_dominante.id;


--
-- TOC entry analisis_grafico_polaridad_tiempo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_polaridad_tiempo (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    fecha date NOT NULL,
    cat text NOT NULL,
    freq integer NOT NULL
);


ALTER TABLE public.analisis_grafico_polaridad_tiempo OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_polaridad_tiempo IS 'Polaridad de mensajes por fecha que consume g_polaridad_tiempo.';


--
-- TOC entry analisis_grafico_polaridad_tiempo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq OWNED BY public.analisis_grafico_polaridad_tiempo.id;


--
-- TOC entry analisis_grafico_sent_hora_heat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_sent_hora_heat (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    hora integer NOT NULL,
    sentimiento text NOT NULL,
    pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_sent_hora_heat OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_sent_hora_heat IS 'Mapa de calor sentimiento x hora del dia que consume g_sent_hora_heat.';


--
-- TOC entry analisis_grafico_sent_hora_heat_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq OWNED BY public.analisis_grafico_sent_hora_heat.id;


--
-- TOC entry analisis_grafico_correlacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_correlacion (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    a text NOT NULL,
    b text NOT NULL,
    r numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_correlacion OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_correlacion IS 'Correlacion entre sentimientos por mensaje que consume g_correlacion.';


--
-- TOC entry analisis_grafico_correlacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_correlacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_correlacion_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_correlacion_id_seq OWNED BY public.analisis_grafico_correlacion.id;


--
-- TOC entry analisis_grafico_palabras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_palabras (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    palabra text NOT NULL,
    n integer NOT NULL
);


ALTER TABLE public.analisis_grafico_palabras OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_palabras IS 'Palabras mas usadas del periodo que consume g_palabras.';


--
-- TOC entry analisis_grafico_palabras_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_palabras_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_palabras_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_palabras_id_seq OWNED BY public.analisis_grafico_palabras.id;


--
-- TOC entry analisis_grafico_emojis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_emojis (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    emoji text NOT NULL,
    n integer NOT NULL,
    sentimiento text NOT NULL,
    etiqueta text NOT NULL
);


ALTER TABLE public.analisis_grafico_emojis OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_emojis IS 'Emojis mas usados y su sentimiento que consume g_emojis.';


--
-- TOC entry analisis_grafico_emojis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_emojis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_emojis_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_emojis_id_seq OWNED BY public.analisis_grafico_emojis.id;


--
-- TOC entry analisis_grafico_libreria_vs_propios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_libreria_vs_propios (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    polaridad text NOT NULL,
    fuente text NOT NULL,
    pct numeric NOT NULL
);


ALTER TABLE public.analisis_grafico_libreria_vs_propios OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_libreria_vs_propios IS 'Polaridad diccionario propio vs libreria que consume g_libreria_vs_propios.';


--
-- TOC entry analisis_grafico_libreria_vs_propios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq OWNED BY public.analisis_grafico_libreria_vs_propios.id;


--
-- TOC entry analisis_grafico_diferencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_grafico_diferencia (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    sentimiento text NOT NULL,
    dif numeric NOT NULL,
    sube boolean NOT NULL
);


ALTER TABLE public.analisis_grafico_diferencia OWNER TO postgres;

COMMENT ON TABLE public.analisis_grafico_diferencia IS 'Diferencia de sentimientos entre dos periodos que consume g_diferencia.';


--
-- TOC entry analisis_grafico_diferencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_grafico_diferencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_grafico_diferencia_id_seq OWNER TO postgres;

ALTER SEQUENCE public.analisis_grafico_diferencia_id_seq OWNED BY public.analisis_grafico_diferencia.id;


--
-- Primary keys
--

ALTER TABLE ONLY public.analisis_grafico_volumen
    ADD CONSTRAINT analisis_grafico_volumen_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_evolucion_anual
    ADD CONSTRAINT analisis_grafico_evolucion_anual_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_sent_heat
    ADD CONSTRAINT analisis_grafico_sent_heat_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_dominante
    ADD CONSTRAINT analisis_grafico_dominante_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_polaridad_tiempo
    ADD CONSTRAINT analisis_grafico_polaridad_tiempo_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_sent_hora_heat
    ADD CONSTRAINT analisis_grafico_sent_hora_heat_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_correlacion
    ADD CONSTRAINT analisis_grafico_correlacion_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_palabras
    ADD CONSTRAINT analisis_grafico_palabras_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_emojis
    ADD CONSTRAINT analisis_grafico_emojis_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_libreria_vs_propios
    ADD CONSTRAINT analisis_grafico_libreria_vs_propios_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.analisis_grafico_diferencia
    ADD CONSTRAINT analisis_grafico_diferencia_pkey PRIMARY KEY (id);


--
-- Uniques
--

ALTER TABLE ONLY public.analisis_grafico_volumen
    ADD CONSTRAINT analisis_grafico_volumen_id_analisis_fecha_key UNIQUE (id_analisis, fecha);

ALTER TABLE ONLY public.analisis_grafico_evolucion_anual
    ADD CONSTRAINT analisis_grafico_evolucion_anual_id_analisis_anio_sentimiento_key UNIQUE (id_analisis, anio, sentimiento);

ALTER TABLE ONLY public.analisis_grafico_sent_heat
    ADD CONSTRAINT analisis_grafico_sent_heat_id_analisis_fecha_sentimiento_key UNIQUE (id_analisis, fecha, sentimiento);

ALTER TABLE ONLY public.analisis_grafico_dominante
    ADD CONSTRAINT analisis_grafico_dominante_id_analisis_fecha_dom_key UNIQUE (id_analisis, fecha, dom);

ALTER TABLE ONLY public.analisis_grafico_polaridad_tiempo
    ADD CONSTRAINT analisis_grafico_polaridad_tiempo_id_analisis_fecha_cat_key UNIQUE (id_analisis, fecha, cat);

ALTER TABLE ONLY public.analisis_grafico_sent_hora_heat
    ADD CONSTRAINT analisis_grafico_sent_hora_heat_id_analisis_hora_sentimiento_key UNIQUE (id_analisis, hora, sentimiento);

ALTER TABLE ONLY public.analisis_grafico_correlacion
    ADD CONSTRAINT analisis_grafico_correlacion_id_analisis_a_b_key UNIQUE (id_analisis, a, b);

ALTER TABLE ONLY public.analisis_grafico_palabras
    ADD CONSTRAINT analisis_grafico_palabras_id_analisis_palabra_key UNIQUE (id_analisis, palabra);

ALTER TABLE ONLY public.analisis_grafico_emojis
    ADD CONSTRAINT analisis_grafico_emojis_id_analisis_emoji_key UNIQUE (id_analisis, emoji);

ALTER TABLE ONLY public.analisis_grafico_libreria_vs_propios
    ADD CONSTRAINT analisis_grafico_libreria_vs_propios_id_analisis_polaridad_fuente_key UNIQUE (id_analisis, polaridad, fuente);

ALTER TABLE ONLY public.analisis_grafico_diferencia
    ADD CONSTRAINT analisis_grafico_diferencia_id_analisis_sentimiento_key UNIQUE (id_analisis, sentimiento);


--
-- Foreign keys
--

ALTER TABLE ONLY public.analisis_grafico_volumen
    ADD CONSTRAINT analisis_grafico_volumen_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_evolucion_anual
    ADD CONSTRAINT analisis_grafico_evolucion_anual_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_sent_heat
    ADD CONSTRAINT analisis_grafico_sent_heat_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_dominante
    ADD CONSTRAINT analisis_grafico_dominante_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_polaridad_tiempo
    ADD CONSTRAINT analisis_grafico_polaridad_tiempo_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_sent_hora_heat
    ADD CONSTRAINT analisis_grafico_sent_hora_heat_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_correlacion
    ADD CONSTRAINT analisis_grafico_correlacion_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_palabras
    ADD CONSTRAINT analisis_grafico_palabras_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_emojis
    ADD CONSTRAINT analisis_grafico_emojis_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_libreria_vs_propios
    ADD CONSTRAINT analisis_grafico_libreria_vs_propios_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;

ALTER TABLE ONLY public.analisis_grafico_diferencia
    ADD CONSTRAINT analisis_grafico_diferencia_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


--
-- Indexes
--

CREATE INDEX idx_analisis_grafico_volumen_analisis ON public.analisis_grafico_volumen USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_evolucion_anual_analisis ON public.analisis_grafico_evolucion_anual USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_sent_heat_analisis ON public.analisis_grafico_sent_heat USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_dominante_analisis ON public.analisis_grafico_dominante USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_polaridad_tiempo_analisis ON public.analisis_grafico_polaridad_tiempo USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_sent_hora_heat_analisis ON public.analisis_grafico_sent_hora_heat USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_correlacion_analisis ON public.analisis_grafico_correlacion USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_palabras_analisis ON public.analisis_grafico_palabras USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_emojis_analisis ON public.analisis_grafico_emojis USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_libreria_vs_propios_analisis ON public.analisis_grafico_libreria_vs_propios USING btree (id_analisis);

CREATE INDEX idx_analisis_grafico_diferencia_analisis ON public.analisis_grafico_diferencia USING btree (id_analisis);


--
-- Grants tables
--

GRANT ALL ON TABLE public.analisis_grafico_volumen TO anon;
GRANT ALL ON TABLE public.analisis_grafico_volumen TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_volumen TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_evolucion_anual TO anon;
GRANT ALL ON TABLE public.analisis_grafico_evolucion_anual TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_evolucion_anual TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_sent_heat TO anon;
GRANT ALL ON TABLE public.analisis_grafico_sent_heat TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_sent_heat TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_dominante TO anon;
GRANT ALL ON TABLE public.analisis_grafico_dominante TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_dominante TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_polaridad_tiempo TO anon;
GRANT ALL ON TABLE public.analisis_grafico_polaridad_tiempo TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_polaridad_tiempo TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_sent_hora_heat TO anon;
GRANT ALL ON TABLE public.analisis_grafico_sent_hora_heat TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_sent_hora_heat TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_correlacion TO anon;
GRANT ALL ON TABLE public.analisis_grafico_correlacion TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_correlacion TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_palabras TO anon;
GRANT ALL ON TABLE public.analisis_grafico_palabras TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_palabras TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_emojis TO anon;
GRANT ALL ON TABLE public.analisis_grafico_emojis TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_emojis TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_libreria_vs_propios TO anon;
GRANT ALL ON TABLE public.analisis_grafico_libreria_vs_propios TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_libreria_vs_propios TO service_role;

GRANT ALL ON TABLE public.analisis_grafico_diferencia TO anon;
GRANT ALL ON TABLE public.analisis_grafico_diferencia TO authenticated;
GRANT ALL ON TABLE public.analisis_grafico_diferencia TO service_role;


--
-- Grants sequences
--

GRANT ALL ON SEQUENCE public.analisis_grafico_volumen_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_volumen_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_volumen_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_evolucion_anual_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_evolucion_anual_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_evolucion_anual_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_sent_heat_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_sent_heat_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_sent_heat_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_dominante_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_dominante_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_dominante_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_polaridad_tiempo_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_sent_hora_heat_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_correlacion_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_correlacion_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_correlacion_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_palabras_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_palabras_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_palabras_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_emojis_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_emojis_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_emojis_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_libreria_vs_propios_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.analisis_grafico_diferencia_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_grafico_diferencia_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_grafico_diferencia_id_seq TO service_role;
