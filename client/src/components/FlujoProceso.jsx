/** Diagrama de flujo del preprocesamiento (contenido estático para exposición).
 * El código R es ilustrativo y está extraído de los scripts de `r/R/`. */
import { useState } from 'react';

const ETAPAS = [
  {
    n: '1',
    titulo: 'Auditoría inicial',
    etiqueta: 'Diagnóstico',
    tono: 'info',
    archivo: 'r/R/01_lectura.R',
    puntos: [
      { texto: 'Registros de servicio', valor: '3,466' },
      { texto: 'Enlaces', valor: '1,782' },
      { texto: 'Autor vacío', valor: '1,754' },
      { texto: 'Reenviados', valor: '601' },
    ],
    codigo: String.raw`auditar_entrada <- function(ctx, d) {
  M <- "1. Auditoría y perfilado inicial"
  N <- nrow(d)

  registrar_hallazgo(ctx, metodologia = M,
    problema = "Registros que no son mensajes (servicio)",
    valor = sum(d$tipo_registro != "message"), base = N)

  registrar_hallazgo(ctx, metodologia = M,
    problema = "Autor nulo (cuenta eliminada)",
    valor = sum(d$tipo_registro == "message" &
                is.na(d$autor_raw)), base = N)

  registrar_hallazgo(ctx, metodologia = M,
    problema = "Mensajes reenviados",
    valor = sum(!is.na(d$reenviado_de)), base = N)

  d
}`,
  },
  {
    n: '2',
    titulo: 'Estructura y formatos',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    archivo: 'r/R/02_estructura.R',
    puntos: [
      { texto: 'Eliminación de los registros de servicio', valor: '3,466' },
      { texto: 'Autores anonimizados', valor: '✓' },
    ],
    salida: '22,564 mensajes',
    perdidos: '−3,466',
    codigo: String.raw`# 2.3 Mensajes de servicio: se separan, no se mezclan
es_serv <- datos$tipo_registro != "message"
excluir(ctx, datos[es_serv, ],
        "Mensaje de servicio de Telegram")
datos <- datos[!es_serv, ]

# 2.6 Autor: nombre real -> seudónimo estable
datos$autor <- ifelse(is.na(datos$autor_raw) |
                      !nzchar(datos$autor_raw),
                      "desconocido", datos$autor_raw)

if (isTRUE(ctx$p$anonimizar_autor)) {
  ids   <- unique(datos$autor_id)
  seudo <- paste0("U", substr(vapply(paste0("sal-mineria-", ids),
                   digest::digest, character(1),
                   algo = "md5", serialize = FALSE), 1, 6))
  datos$autor <- seudo[match(datos$autor_id, ids)]
}`,
  },
  {
    n: '3',
    titulo: 'Duplicados',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    archivo: 'r/R/03_calidad.R',
    puntos: [
      { texto: 'Eliminación de mensajes largos', valor: '463' },
      { texto: 'Se conservan mensajes cortos repetidos', valor: '1,797' },
    ],
    salida: '22,101 mensajes',
    perdidos: '−463',
    codigo: String.raw`clave <- paste(datos$autor_id,
               stringi::stri_trans_tolower(
                 stringi::stri_trim_both(datos$texto_original)),
               sep = "||")

dup <- duplicated(clave) & datos$n_caracteres >= minc
excluir(ctx, datos[dup, ],
        sprintf("Duplicado exacto (mismo autor y texto, >= %d caracteres)",
                minc))
datos <- datos[!dup, ]`,
  },
  {
    n: '4',
    titulo: 'Valores faltantes',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    archivo: 'r/R/03_calidad.R',
    puntos: [{ texto: 'Eliminación de mensajes multimedia', valor: '1,356' }],
    salida: '20,745 mensajes',
    perdidos: '−1,356',
    codigo: String.raw`vacio <- !nzchar(stringi::stri_trim_both(datos$texto_original))
tb    <- table(datos$tipo_contenido[vacio])

ctx$nota <- paste0("Detalle por tipo: ",
                   paste(names(tb), tb, sep = "=", collapse = ", "), ".")

excluir(ctx, datos[vacio, ],
        "Sin texto (solo foto, video, archivo, audio u otro contenido multimedia)")
datos <- datos[!vacio, ]`,
  },
  {
    n: '5',
    titulo: 'Outliers',
    etiqueta: 'Análisis',
    tono: 'info',
    archivo: 'r/R/03_calidad.R',
    puntos: [
      { texto: 'Mensajes muy largos (más de 549 caracteres)', valor: '248' },
    ],
    codigo: String.raw`lg  <- log1p(datos$n_caracteres)          # longitud en escala log
q   <- stats::quantile(lg, c(0.25, 0.75), names = FALSE)
lim <- q[2] + 1.5 * (q[2] - q[1])         # Q3 + 1.5 * IQR

datos$outlier_longitud <- lg > lim
# Solo se marca: el umbral calculado fue de 549 caracteres`,
  },
  {
    n: '6',
    titulo: 'Publicidad',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    archivo: 'r/R/04_publicidad.R',
    puntos: [
      {
        texto:
          'Cada mensaje recibe un puntaje: enlace, reenviado, muy largo, teléfono y frases de inscripción',
      },
      { texto: 'Eliminación de anuncios', valor: '615' },
    ],
    salida: '20,130 mensajes',
    perdidos: '−615',
    codigo: String.raw`pp <- puntaje_publicidad(datos, reglas)
datos$puntaje_publicidad <- pp$puntaje
datos$motivo_publicidad  <- pp$motivo
datos$posible_publicidad <- pp$puntaje >= umbral

# 6.2 Apartar la publicidad detectada
pub <- datos$posible_publicidad
excluir(ctx, datos[pub, ],
        sprintf("Publicidad / anuncio (puntaje >= %s)", umbral))
datos <- datos[!pub, ]`,
  },
  {
    n: '7',
    titulo: 'Emojis y emoticonos',
    etiqueta: 'Análisis',
    tono: 'info',
    archivo: 'r/R/05_emojis.R',
    puntos: [
      { texto: 'Emojis distintos identificados', valor: '233' },
      {
        texto: 'Mensajes con reacciones contadas como positivas o negativas',
        valor: '1,922',
      },
    ],
    codigo: String.raw`# 7.2 Traducir cada emoji a su significado en español
mapa   <- stats::setNames(dic$token, dic$emoji)
salida <- datos$texto_original
# ... cada emoji se reemplaza por "emoji_<significado>"
datos$texto_traducido <- salida

# 7.4 Reacciones positivas y negativas
pol_map <- stats::setNames(dic$polaridad, dic$emoji)
datos$reacciones_total <- acumular(rep(TRUE, nrow(rl)))
datos$reacciones_pos   <- acumular(pol > 0)
datos$reacciones_neg   <- acumular(pol < 0)`,
  },
];

const PASOS_LIMPIEZA = [
  { paso: 'Enlaces, correos, menciones, teléfonos', hace: 'Se eliminan', mensajes: '734' },
  { paso: '“compañer@s” → “compañeros”', hace: 'Se completa la palabra', mensajes: '94' },
  { paso: 'Minúsculas', hace: '“Gracias” = “GRACIAS”', mensajes: '17,301' },
  { paso: 'Horas y fechas', hace: 'Se eliminan', mensajes: '422' },
  { paso: 'Códigos de materia', hace: '“inf 111” → inf_111', mensajes: '1,012' },
  { paso: 'Hashtags', hace: 'Se quita el #', mensajes: '6' },
  { paso: 'Puntuación y símbolos', hace: 'Se quitan', mensajes: '10,273' },
  { paso: 'Letras alargadas', hace: '“holaaaa” → “hola”', mensajes: '256' },
  { paso: 'Abreviaturas', hace: '“q” → “que”', mensajes: '1,047' },
  { paso: 'Espacios sobrantes', hace: 'Se unifican', mensajes: '11,958' },
  { paso: 'Mensajes vacíos', hace: 'Se apartan', mensajes: '634' },
];

const ETAPAS_FINALES = [
  {
    n: '9',
    titulo: 'Género',
    etiqueta: 'Análisis',
    tono: 'info',
    archivo: 'r/R/06_texto.R',
    puntos: [
      { texto: 'Se marca a quién se refiere el mensaje', valor: null },
      { texto: 'Mensajes que mencionan a alguien', valor: '947' },
    ],
    codigo: String.raw`pat_f <- patron("femenino")
pat_m <- patron("masculino")

# Formas inclusivas con @ (compañer@s, tod@s)
inc <- stringi::stri_extract_all_regex(datos$texto_traducido,
         "(?<![\\p{L}\\p{N}_@])\\p{L}+@s?(?![\\p{L}\\p{N}_@])")

datos$n_ref_inclusivo <- lengths(inc)
datos$n_ref_femenino  <- stringi::stri_count_regex(datos$texto_limpio, pat_f)
datos$n_ref_masculino <- pmax(0,
  stringi::stri_count_regex(datos$texto_limpio, pat_m) - inc_m)

datos$genero_mencionado <- ifelse(
  datos$n_ref_femenino > 0 & datos$n_ref_masculino > 0, "ambos",
  ifelse(datos$n_ref_femenino > 0, "femenino",
  ifelse(datos$n_ref_masculino > 0, "masculino",
  ifelse(datos$n_ref_inclusivo > 0, "inclusivo", "ninguno"))))`,
  },
  {
    n: '10',
    titulo: 'Tokenización y stopwords',
    etiqueta: 'Transformación',
    tono: 'limpia',
    archivo: 'r/R/06_texto.R',
    puntos: [
      { texto: 'Se eliminan las stopwords', valor: '17,119 mensajes' },
      { texto: 'Al final se quitan las tildes', valor: '5,808 mensajes' },
    ],
    codigo: String.raw`# 10.1 Tokenización
tk <- strsplit(datos$texto_limpio, " ", fixed = TRUE)
tk <- lapply(tk, function(t)
  t[nzchar(t) & (!grepl("[0-9]", t) | grepl("_", t) |
                 grepl("^x[0-9]+$", t))])
datos$n_tokens_brutos <- lengths(tk)

# 10.2 Stopwords personalizadas
quitar <- u[en_elim & !en_cons & !en_prot & !es_emoji]
tk_f   <- lapply(tk, function(t) t[!(t %in% quitar)])
datos$texto_tokens <- vapply(tk_f, paste, character(1), collapse = " ")
datos$n_tokens     <- lengths(tk_f)

# 10.3 Quitar tildes (protegiendo "él")
mapa <- stats::setNames(ifelse(u2 %in% proteger, u2, .sin_tilde(u2)), u2)
datos$texto_tokens <- vapply(tk2, function(t)
  paste(mapa[t], collapse = " "), character(1))`,
  },
];

const ETAPA_8 = {
  n: '8',
  titulo: 'Limpieza del texto',
  etiqueta: '11 pasos',
  tono: 'limpia',
  archivo: 'r/R/06_texto.R',
  codigo: String.raw`# 8.1 Enlaces, correos, menciones y teléfonos
x <- datos$texto_traducido
x <- stringi::stri_replace_all_regex(x, RX_URL,  " ")
x <- stringi::stri_replace_all_regex(x, RX_MAIL, " ")
x <- stringi::stri_replace_all_regex(x, RX_MENC, " ")
x <- stringi::stri_replace_all_regex(x, RX_TEL,  " telefono ")
datos$texto_limpio <- x

# 8.1b "compañer@s" -> "compañeros"
datos$texto_limpio <- stringi::stri_replace_all_regex(
  datos$texto_limpio, "(\\p{L})@(s?)", "$1o$2")

# 8.2 Minúsculas: "Gracias" = "GRACIAS"
datos$texto_limpio <- stringi::stri_trans_tolower(datos$texto_limpio)

# 8.5 Letras alargadas: "holaaaa" -> "hola"
datos$texto_limpio <- stringi::stri_replace_all_regex(
  datos$texto_limpio, "(\\p{L})\\1{2,}", "$1")

# 8.6 Espacios sobrantes
datos$texto_limpio <- stringi::stri_trim_both(
  stringi::stri_replace_all_regex(datos$texto_limpio, "\\s+", " "))`,
};

const ETAPA_11 = {
  n: '11',
  titulo: 'Sentimientos',
  etiqueta: 'Análisis',
  tono: 'info',
  archivo: 'r/R/07_sentimientos.R',
  codigo: String.raw`txt <- .ascii(datos$texto_limpio)   # coincidencias sin tildes
hits <- matrix(0, n, length(nombres),
               dimnames = list(NULL, nombres))

for (i in seq_along(nombres)) {
  pat <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]])
  bruto <- stringi::stri_count_regex(txt, pat)
  pat_neg <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]],
                                negado = TRUE)
  negs[, i] <- pmin(stringi::stri_count_regex(txt, pat_neg), bruto)
  hits[, i] <- bruto - negs[, i]
}

datos$polaridad_score <- ifelse(base_pol > 0,
                                round(num_pol / base_pol, 3), 0)
datos$polaridad_msg <- ifelse(datos$polaridad_score > 0, "positivo",
                              ifelse(datos$polaridad_score < 0,
                                     "negativo", "neutral"))`,
};

const ETAPA_12 = {
  n: '12',
  titulo: 'Faltantes finales',
  etiqueta: 'Verificación',
  tono: 'final',
  archivo: 'r/R/08_salida.R',
  codigo: String.raw`REGLAS_NULOS <- list(
  reenviado_de          = "original",
  responde_a            = 0,
  reacciones            = "ninguna",
  sentimiento_emoji     = "sin_emoji",
  sentimiento_dominante = "ninguno"
)

for (cn in cols) {
  m <- vacio(datos[[cn]])
  if (!any(m)) next
  datos[[cn]][m] <- if (!is.null(REGLAS_NULOS[[cn]])) REGLAS_NULOS[[cn]]
                    else if (is.numeric(v)) 0
                    else if (is.logical(v)) FALSE
                    else "ninguno"
}`,
};

const ETAPA_13 = {
  n: '13',
  titulo: 'Validaciones',
  etiqueta: 'Balance',
  tono: 'final',
  archivo: 'r/R/08_salida.R',
  codigo: String.raw`total  <- ctx$N_inicial
N      <- nrow(d)
n_excl <- nrow(excluidos_df(ctx))

registrar_hallazgo(ctx, metodologia = M,
  problema = "Conservación de filas (nada se pierde)",
  valor = total - N - n_excl, base = total,
  script = "ctx$N_inicial - nrow(datos) - nrow(excluidos)")

# 26,030 - 19,496 - 6,534 = 0`,
};

const TODAS_LAS_ETAPAS = [...ETAPAS, ETAPA_8, ...ETAPAS_FINALES, ETAPA_11, ETAPA_12, ETAPA_13];

const TODOS_LOS_N = TODAS_LAS_ETAPAS.map((e) => e.n);

const TONO_COLOR = {
  info: 'var(--azul-oscuro)',
  excluye: 'var(--rojo)',
  limpia: 'var(--menta)',
  final: 'var(--azul)',
};

function CodigoR({ etapa, abierto, alternar }) {
  if (!etapa.codigo) return null;
  return (
    <div className="flujo-codigo">
      <button
        type="button"
        className="flujo-codigo-btn"
        onClick={alternar}
        aria-expanded={abierto}
      >
        <span className="flujo-codigo-icono">&lt;/&gt;</span>
        {abierto ? 'Ocultar código R' : 'Ver código R'}
        <span className="flujo-codigo-archivo">{etapa.archivo}</span>
      </button>
      {abierto && (
        <pre className="flujo-pre">
          <code>{etapa.codigo}</code>
        </pre>
      )}
    </div>
  );
}

function Tarjeta({ etapa, abierto, alternarCodigo, children }) {
  return (
    <li className="flujo-item">
      <div className={`flujo-nodo flujo-nodo--${etapa.tono || 'info'}`}>{etapa.n}</div>
      <div className="flujo-tarjeta">
        <div className="flujo-cabecera">
          <h3 className="flujo-titulo">
            <span className="flujo-etapa">Etapa {etapa.n}</span>
            {etapa.titulo}
          </h3>
          {etapa.etiqueta && (
            <span className="flujo-badge" style={{ color: TONO_COLOR[etapa.tono || 'info'] }}>
              {etapa.etiqueta}
            </span>
          )}
        </div>
        {children}
        {(etapa.salida || etapa.perdidos) && (
          <div className="flujo-salida">
            {etapa.perdidos && <span className="flujo-perdida">{etapa.perdidos}</span>}
            {etapa.salida && (
              <span className="flujo-salida-texto">
                Quedan <strong>{etapa.salida}</strong>
              </span>
            )}
          </div>
        )}
        <CodigoR etapa={etapa} abierto={abierto} alternar={alternarCodigo} />
      </div>
    </li>
  );
}

function Puntos({ puntos }) {
  return (
    <ul className="flujo-puntos">
      {puntos.map((p) => (
        <li key={p.texto}>
          <span>{p.texto}</span>
          {p.valor != null && <span className="flujo-valor">{p.valor}</span>}
        </li>
      ))}
    </ul>
  );
}

export default function FlujoProceso() {
  const [codigosAbiertos, setCodigosAbiertos] = useState(new Set());

  const todosAbiertos = TODOS_LOS_N.every((n) => codigosAbiertos.has(n));

  const alternarCodigo = (n) => {
    setCodigosAbiertos((prev) => {
      const next = new Set(prev);
      if (next.has(n)) next.delete(n);
      else next.add(n);
      return next;
    });
  };

  const alternarTodos = () => {
    setCodigosAbiertos(() => (todosAbiertos ? new Set() : new Set(TODOS_LOS_N)));
  };

  return (
    <div className="flujo">
      <div className="flujo-hero">
        <div>
          <p className="flujo-hero-etiqueta">Registros analizados</p>
          <p className="flujo-hero-numero">26,030</p>
          <p className="flujo-hero-rango">26/12/2022 al 20/10/2026</p>
        </div>
        <div className="flujo-hero-resumen">
          <div>
            <span className="flujo-hero-dato">19,496</span>
            <span className="flujo-hero-pie">mensajes limpios</span>
          </div>
          <span className="flujo-hero-mas">+</span>
          <div>
            <span className="flujo-hero-dato">6,534</span>
            <span className="flujo-hero-pie">excluidos</span>
          </div>
        </div>
      </div>

      <div className="flujo-toolbar">
        <span>
          Código R ilustrativo extraído de <code>r/R/</code>
        </span>
        <button type="button" className="btn" onClick={alternarTodos}>
          {todosAbiertos ? 'Ocultar todo el código' : 'Mostrar todo el código'}
        </button>
      </div>

      <ol className="flujo-lista">
        {ETAPAS.map((etapa) => (
          <Tarjeta
            key={etapa.n}
            etapa={etapa}
            abierto={codigosAbiertos.has(etapa.n)}
            alternarCodigo={() => alternarCodigo(etapa.n)}
          >
            <Puntos puntos={etapa.puntos} />
          </Tarjeta>
        ))}

        <Tarjeta
          etapa={ETAPA_8}
          abierto={codigosAbiertos.has(ETAPA_8.n)}
          alternarCodigo={() => alternarCodigo(ETAPA_8.n)}
        >
          <div className="tabla-scroll flujo-tabla-scroll">
            <table className="tabla flujo-tabla">
              <thead>
                <tr>
                  <th>Paso</th>
                  <th>Qué hace</th>
                  <th>Mensajes</th>
                </tr>
              </thead>
              <tbody>
                {PASOS_LIMPIEZA.map((p) => (
                  <tr key={p.paso}>
                    <td>{p.paso}</td>
                    <td>{p.hace}</td>
                    <td className="flujo-tabla-num">{p.mensajes}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flujo-salida">
            <span className="flujo-salida-texto">
              Quedan <strong>19,496 mensajes</strong>
            </span>
          </div>
        </Tarjeta>

        {ETAPAS_FINALES.map((etapa) => (
          <Tarjeta
            key={etapa.n}
            etapa={etapa}
            abierto={codigosAbiertos.has(etapa.n)}
            alternarCodigo={() => alternarCodigo(etapa.n)}
          >
            <Puntos puntos={etapa.puntos} />
          </Tarjeta>
        ))}

        <Tarjeta
          etapa={ETAPA_11}
          abierto={codigosAbiertos.has(ETAPA_11.n)}
          alternarCodigo={() => alternarCodigo(ETAPA_11.n)}
        >
          <Puntos
            puntos={[
              { texto: 'Mensajes con algún sentimiento', valor: '4,729 (24.3%)' },
            ]}
          />
          <div className="flujo-barra" aria-hidden="true">
            <span className="flujo-barra-pos" style={{ width: '11.18%' }} />
            <span className="flujo-barra-neg" style={{ width: '6.07%' }} />
            <span className="flujo-barra-neu" style={{ width: '82.75%' }} />
          </div>
          <div className="flujo-leyenda">
            <span>
              <i className="flujo-punto flujo-punto--pos" />
              Positivos <strong>2,179</strong>
            </span>
            <span>
              <i className="flujo-punto flujo-punto--neg" />
              Negativos <strong>1,184</strong>
            </span>
            <span>
              <i className="flujo-punto flujo-punto--neu" />
              Neutrales <strong>16,133</strong>
            </span>
          </div>
          <p className="flujo-nota">
            Neutral incluye los mensajes que no coinciden con ninguna palabra.
          </p>
        </Tarjeta>

        <Tarjeta
          etapa={ETAPA_12}
          abierto={codigosAbiertos.has(ETAPA_12.n)}
          alternarCodigo={() => alternarCodigo(ETAPA_12.n)}
        >
          <p className="flujo-nota">Revisión de valores faltantes al cierre del proceso.</p>
        </Tarjeta>

        <Tarjeta
          etapa={ETAPA_13}
          abierto={codigosAbiertos.has(ETAPA_13.n)}
          alternarCodigo={() => alternarCodigo(ETAPA_13.n)}
        >
          <div className="flujo-balance">
            <span className="flujo-balance-total">26,030</span>
            <span className="flujo-balance-signo">=</span>
            <span className="flujo-balance-parte">
              19,496 <small>limpios</small>
            </span>
            <span className="flujo-balance-signo">+</span>
            <span className="flujo-balance-parte">
              6,534 <small>excluidos</small>
            </span>
          </div>
        </Tarjeta>
      </ol>
    </div>
  );
}
