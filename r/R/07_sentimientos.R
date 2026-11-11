# ==============================================================================
# 07_sentimientos.R  -  ETAPA 11: SENTIMIENTOS con el diccionario propio
# ------------------------------------------------------------------------------
# El diccionario vive en config/sentimientos.json (15 sentimientos; "activo": false
# desactiva uno).

# Por mensaje y por cada sentimiento activo:
#   sent_<nombre> = coincidencias (palabras exactas, frases y raíces) + emojis, SIN contar las
#                   negadas ("no estoy feliz" no suma alegría; se cuenta aparte en n_negados)
#   pct_<nombre>  = 100 * coincidencias / n_tokens        <- el "nivel" del sentimiento
# La búsqueda se hace sobre el texto SIN tildes (el diccionario está sin tildes).

# Polaridad del mensaje: positivo / negativo / neutral, según la polaridad (+1, 0, -1) de cada sentimiento.
# ==============================================================================

.esc <- function(x) gsub("([\\\\.^$|?*+()\\[\\]{}])", "\\\\\\1", x, perl = TRUE)

# Convierte las palabras y raíces de un sentimiento en una expresión regular
# Palabras que niegan: si aparecen justo antes (o una palabra antes) de un término del diccionario,
# el término está NEGADO ("no estoy feliz", "nunca fue bueno"). "sin" no se incluye: choca con
# frases del propio diccionario ("sin duda", "sin problema").
NEGADORES <- "no|nunca|jamas|ni|tampoco"

# Términos que NO se niegan aunque haya un "no" antes: "no gracias" (rechazo cortés), "no conviene
# PARA NADA" ("para nada" ya es énfasis de la negación, no un sentimiento negado) y las risas
# ("no hay horario xd": xd/jaja/jeje son interjecciones, no se pueden negar).
NO_NEGABLES <- "gracias|para nada|xd|jaj[a-z]*|jej[a-z]*"

patron_sentimiento <- function(palabras, raices, negado = FALSE) {
  pal <- unique(.ascii(tolower(palabras)))
  pal <- pal[nzchar(pal)]
  pal <- pal[order(-nchar(pal))]
  pal <- gsub(" ", "\\\\s+", .esc(pal))
  rai <- unique(.ascii(tolower(raices)))
  rai <- rai[nzchar(rai)]
  rai <- if (length(rai)) paste0(.esc(rai), "[a-z0-9]*") else character(0)
  alt <- c(pal, rai)
  if (!length(alt)) return(NULL)
  nucleo <- paste0("(?:", paste(alt, collapse = "|"), ")")
  if (!negado) return(paste0("(?<![a-z0-9_])", nucleo, "(?![a-z0-9_])"))
  # negador + (una palabra opcional) + término, salvo los términos de NO_NEGABLES
  paste0("(?<![a-z0-9_])(?:", NEGADORES, ")\\s+(?:[a-z0-9_]+\\s+)?(?!(?:", NO_NEGABLES, ")(?![a-z0-9_]))",
         nucleo, "(?![a-z0-9_])")
}

calcular_sentimientos <- function(ctx, d) {
  M <- "11. Sentimientos con diccionario propio"
  sj <- ctx$cfg$sent[ctx$cfg$sent$activo, ]
  dic_emo <- ctx$cfg$emojis
  nombres <- sj$nombre
  
  # ── 11.1 Contar sentimientos por mensaje ───────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
                      campo = paste0("sent_<", length(nombres), " sentimientos>, pct_*"), atributo = "numérica",
                      problema = "Mensajes sin medida de sentimiento",
                      accion = sprintf("Se contó, por mensaje, las coincidencias de cada uno de los %d sentimientos activos (palabras, frases y raíces del diccionario propio, más los emojis) y se calculó el nivel pct = 100 * coincidencias / n_tokens. Los términos precedidos por una negación (no, nunca, jamás, ni, tampoco; ventana de una palabra) no suman al sentimiento: se cuentan en n_negados y entran a la polaridad con el signo invertido.", length(nombres)),
                      justificacion = "La licenciada pide 15 sentimientos propios (ajustables a 12) y poder decir, por ejemplo, 'este mensaje es 8% alegría y la temporada 7%'. El diccionario vive en config/sentimientos.json para activar o desactivar sentimientos sin tocar el código.",
                      afectadas = sum(datos$hits_total > 0),
                      # ▌CÓDIGO
                      codigo = {
                        txt <- .ascii(datos$texto_limpio)        # coincidencia sobre texto sin tildes
                        n <- nrow(datos)
                        emo_lst <- strsplit(datos$emojis_lista, " ", fixed = TRUE)
                        sent_emo <- stats::setNames(dic_emo$sentimiento, dic_emo$emoji)
                        hits <- matrix(0, n, length(nombres), dimnames = list(NULL, nombres))
                        negs <- matrix(0, n, length(nombres), dimnames = list(NULL, nombres))   # coincidencias NEGADAS
                        for (i in seq_along(nombres)) {
                          pat <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]])
                          if (!is.null(pat)) {
                            bruto <- stringi::stri_count_regex(txt, pat)
                            pat_neg <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]], negado = TRUE)
                            negs[, i] <- pmin(stringi::stri_count_regex(txt, pat_neg), bruto)
                            hits[, i] <- bruto - negs[, i]
                          }
                          hits[, i] <- hits[, i] + vapply(emo_lst, function(k) sum(sent_emo[k] == nombres[i], na.rm = TRUE), numeric(1))
                        }
                        unidades <- pmax(datos$n_tokens, 1)
                        pol <- stats::setNames(sj$polaridad, nombres)
                        for (i in seq_along(nombres)) {
                          datos[[paste0("sent_", nombres[i])]] <- hits[, i]
                          datos[[paste0("pct_", nombres[i])]] <- round(pmin(100, 100 * hits[, i] / unidades), 2)
                        }
                        datos$hits_total <- rowSums(hits)
                        datos$n_negados <- rowSums(negs)
                        base_pol <- datos$hits_total + datos$n_negados
                        num_pol <- as.vector(hits %*% pol[nombres]) - as.vector(negs %*% pol[nombres])   # lo negado invierte su signo
                        datos$polaridad_score <- ifelse(base_pol > 0, round(num_pol / base_pol, 3), 0)
                        datos$polaridad_msg <- ifelse(datos$polaridad_score > 0, "positivo",
                                                      ifelse(datos$polaridad_score < 0, "negativo", "neutral"))
                        datos$sentimiento_dominante <- ifelse(datos$hits_total > 0, nombres[max.col(hits, ties.method = "first")], NA)
                      })

  
  
  # ── 11.2 Distribución de la polaridad ──────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  registrar_hallazgo(ctx, metodologia = M, campo = "polaridad_msg", atributo = "categórica",
                     problema = "Distribución de la polaridad",
                     accion = sprintf("Polaridad por mensaje: positivo %s, negativo %s, neutral %s (neutral incluye los mensajes sin ninguna coincidencia).",
                                      .fmt(sum(d$polaridad_msg == "positivo")), .fmt(sum(d$polaridad_msg == "negativo")),
                                      .fmt(sum(d$polaridad_msg == "neutral"))),
                     justificacion = "Una distribución muy sesgada hacia neutral indica que el diccionario cubre poco vocabulario del grupo y conviene ampliarlo.",
                     valor = sum(d$hits_total > 0), base = nrow(d), script = "table(datos$polaridad_msg)")
  
  registrar_hallazgo(ctx, metodologia = M, campo = "n_negados", atributo = "numérica",
                     problema = "Términos de sentimiento negados (no feliz, nunca bueno)",
                     accion = sprintf("Se contaron los mensajes con al menos un término del diccionario precedido por una negación: %s mensajes, %s términos negados.", .fmt(sum(d$n_negados > 0)), .fmt(sum(d$n_negados))),
                     justificacion = "La negación invierte la polaridad ('no estoy feliz' no es alegría). Sin este paso, un diccionario de palabras sueltas cuenta 'feliz' como alegría aunque esté negada. Es el tratamiento de alcance de la negación (ventana de una palabra) propio de los métodos basados en léxicos.",
                     valor = sum(d$n_negados > 0), base = nrow(d), script = "table(datos$n_negados)")
  d
}

# ---- Niveles por periodo (para el dashboard y la comparación por temporadas) --------
resumen_periodo <- function(datos, inicio = NULL, fin = NULL) {
  f <- datos$fecha
  if (!is.null(inicio)) datos <- datos[f >= as.Date(inicio), ]
  f <- datos$fecha
  if (!is.null(fin)) datos <- datos[f <= as.Date(fin), ]
  cols <- grep("^sent_", names(datos), value = TRUE)
  nom <- sub("^sent_", "", cols)
  unidades <- sum(pmax(datos$n_tokens, 1))
  data.frame(sentimiento = nom,
             coincidencias = vapply(cols, function(c) sum(datos[[c]]), numeric(1)),
             pct_periodo = round(100 * vapply(cols, function(c) sum(datos[[c]]), numeric(1)) / unidades, 2),
             n_mensajes = nrow(datos), row.names = NULL, stringsAsFactors = FALSE)
}

# Compara el nivel de un mensaje con el de un periodo ("8% el mensaje vs 7% la temporada")
nivel_sentimiento <- function(datos, id_mensaje, inicio = NULL, fin = NULL) {
  m <- datos[datos$id_mensaje == id_mensaje, ]
  if (nrow(m) != 1) stop("id_mensaje no encontrado")
  r <- resumen_periodo(datos, inicio, fin)
  r$pct_mensaje <- as.numeric(m[1, paste0("pct_", r$sentimiento)])
  r$diferencia <- round(r$pct_mensaje - r$pct_periodo, 2)
  r[order(-r$pct_mensaje), c("sentimiento", "pct_mensaje", "pct_periodo", "diferencia")]
}

# Sentimiento según a quién se refiere el mensaje (femenino / masculino / ambos / ninguno)
resumen_genero <- function(datos, inicio = NULL, fin = NULL) {
  if (!is.null(inicio)) datos <- datos[datos$fecha >= as.Date(inicio), ]
  if (!is.null(fin)) datos <- datos[datos$fecha <= as.Date(fin), ]
  out <- lapply(split(datos, datos$genero_mencionado), function(g) {
    r <- resumen_periodo(g)
    r$genero_mencionado <- g$genero_mencionado[1]
    r
  })
  do.call(rbind, out)[, c("genero_mencionado", "sentimiento", "coincidencias", "pct_periodo", "n_mensajes")]
}

