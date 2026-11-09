--
-- Tablas para los gráficos ECharts del dashboard (serie mensual y sankey).
-- Añadir a Esquema4.sql sin modificar archivos existentes.
--

--
-- TOC entry 286 (class 1259 OID 19218)
-- Name: analisis_serie_mensual; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_serie_mensual (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    anio_mes text NOT NULL,
    sentimiento text NOT NULL,
    pct numeric NOT NULL,
    n_mensajes integer
);


ALTER TABLE public.analisis_serie_mensual OWNER TO postgres;

--
-- TOC entry 3791 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE analisis_serie_mensual; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis_serie_mensual IS 'Serie mensual de sentimientos (anio_mes x sentimiento) que consume g_tiempo, g_apilado y g_dispersion.';


--
-- TOC entry 287 (class 1259 OID 19219)
-- Name: analisis_serie_mensual_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_serie_mensual_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_serie_mensual_id_seq OWNER TO postgres;

--
-- TOC entry 3792 (class 0 OID 0)
-- Dependencies: 287
-- Name: SEQUENCE analisis_serie_mensual_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_serie_mensual_id_seq OWNED BY public.analisis_serie_mensual.id;


--
-- TOC entry 288 (class 1259 OID 19220)
-- Name: analisis_sankey; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analisis_sankey (
    id bigint NOT NULL,
    id_analisis integer NOT NULL,
    topico text NOT NULL,
    sentimiento_dominante text NOT NULL,
    freq integer NOT NULL
);


ALTER TABLE public.analisis_sankey OWNER TO postgres;

--
-- TOC entry 3793 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE analisis_sankey; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.analisis_sankey IS 'Cruce tópico x sentimiento dominante (frecuencia) que consume g_sankey. Solo sentimientos válidos (excluye "ninguno").';


--
-- TOC entry 289 (class 1259 OID 19221)
-- Name: analisis_sankey_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.analisis_sankey_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.analisis_sankey_id_seq OWNER TO postgres;

--
-- TOC entry 3794 (class 0 OID 0)
-- Dependencies: 289
-- Name: SEQUENCE analisis_sankey_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.analisis_sankey_id_seq OWNED BY public.analisis_sankey.id;


--
-- TOC entry 3594 (class 2604 OID 19223)
-- Name: analisis_serie_mensual id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_serie_mensual ALTER COLUMN id SET DEFAULT nextval('public.analisis_serie_mensual_id_seq'::regclass);


--
-- TOC entry 3595 (class 2604 OID 19224)
-- Name: analisis_sankey id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_sankey ALTER COLUMN id SET DEFAULT nextval('public.analisis_sankey_id_seq'::regclass);


--
-- TOC entry 3619 (class 2606 OID 19225)
-- Name: analisis_serie_mensual analisis_serie_mensual_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_serie_mensual
    ADD CONSTRAINT analisis_serie_mensual_pkey PRIMARY KEY (id);


--
-- TOC entry 3620 (class 2606 OID 19226)
-- Name: analisis_serie_mensual analisis_serie_mensual_id_analisis_anio_mes_sentimiento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_serie_mensual
    ADD CONSTRAINT analisis_serie_mensual_id_analisis_anio_mes_sentimiento_key UNIQUE (id_analisis, anio_mes, sentimiento);


--
-- TOC entry 3621 (class 2606 OID 19227)
-- Name: analisis_sankey analisis_sankey_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_sankey
    ADD CONSTRAINT analisis_sankey_pkey PRIMARY KEY (id);


--
-- TOC entry 3622 (class 2606 OID 19228)
-- Name: analisis_sankey analisis_sankey_id_analisis_topico_sentimiento_dominante_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_sankey
    ADD CONSTRAINT analisis_sankey_id_analisis_topico_sentimiento_dominante_key UNIQUE (id_analisis, topico, sentimiento_dominante);


--
-- TOC entry 3623 (class 2606 OID 19229)
-- Name: analisis_serie_mensual analisis_serie_mensual_id_analisis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_serie_mensual
    ADD CONSTRAINT analisis_serie_mensual_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


--
-- TOC entry 3624 (class 2606 OID 19230)
-- Name: analisis_sankey analisis_sankey_id_analisis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analisis_sankey
    ADD CONSTRAINT analisis_sankey_id_analisis_fkey FOREIGN KEY (id_analisis) REFERENCES public.analisis(id_analisis) ON DELETE CASCADE;


--
-- TOC entry 3625 (class 1259 OID 19231)
-- Name: idx_analisis_serie_mensual_analisis; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_serie_mensual_analisis ON public.analisis_serie_mensual USING btree (id_analisis);


--
-- TOC entry 3626 (class 1259 OID 19232)
-- Name: idx_analisis_sankey_analisis; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analisis_sankey_analisis ON public.analisis_sankey USING btree (id_analisis);


--
-- TOC entry 3796 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE analisis_serie_mensual; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.analisis_serie_mensual TO anon;
GRANT ALL ON TABLE public.analisis_serie_mensual TO authenticated;
GRANT ALL ON TABLE public.analisis_serie_mensual TO service_role;


--
-- TOC entry 3797 (class 0 OID 0)
-- Dependencies: 287
-- Name: SEQUENCE analisis_serie_mensual_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.analisis_serie_mensual_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_serie_mensual_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_serie_mensual_id_seq TO service_role;


--
-- TOC entry 3798 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE analisis_sankey; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.analisis_sankey TO anon;
GRANT ALL ON TABLE public.analisis_sankey TO authenticated;
GRANT ALL ON TABLE public.analisis_sankey TO service_role;


--
-- TOC entry 3799 (class 0 OID 0)
-- Dependencies: 289
-- Name: SEQUENCE analisis_sankey_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.analisis_sankey_id_seq TO anon;
GRANT ALL ON SEQUENCE public.analisis_sankey_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.analisis_sankey_id_seq TO service_role;
