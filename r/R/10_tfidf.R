# ==============================================================================
# 10_tfidf.R  -  STOPWORDS (mostrar) y TF-IDF
# ------------------------------------------------------------------------------
# TF-IDF = frecuencia del término en un documento (tf) x qué tan raro es entre los
# documentos (idf).  tf = n / total de términos del documento;  idf = log(N / df)
#   N = número de documentos, df = en cuántos documentos aparece el término.

# Aquí un "documento" es un MES (para ver qué distingue a cada mes) o un PERIODO
# completo (para comparar verano 2023 contra verano 2024).
# Hecho a mano (sin paquetes extra) para que se vea la fórmula en el informe.
# ==============================================================================

# ---- STOPWORDS: dónde se produce la limpieza ----------------------------------
# Las stopwords se aplican en el paso 10.2 del preprocesamiento (R/06_texto.R).
# Esta función solo MUESTRA lo que decidió ese paso (salida/stopwords_aplicadas.csv).
mostrar_stopwords <- function(dir_salida = "salida", top = 20) {
  f <- file.path(dir_salida, "stopwords_aplicadas.csv")
  if (!file.exists(f)) stop("No existe ", f, ". Corre primero preprocesar().", call. = FALSE)
  s <- readr::read_csv(f, show_col_types = FALSE, progress = FALSE)
  list(
    paso = "Preprocesamiento, paso 10.2 'Stopwords personalizadas' (R/06_texto.R, config/stopwords.csv)",
    resumen = as.data.frame(table(decision = s$decision), stringsAsFactors = FALSE),
    eliminadas = utils::head(s[s$decision == "eliminada", ], top),
    conservadas = utils::head(s[s$decision == "conservada", ], top))
}

# ---- TF-IDF -------------------------------------------------------------------
# Cuenta (documento, término) SOLO de las combinaciones que existen (rápido y liviano)
.contar <- function(doc, token) {
  key <- paste(doc, token, sep = "\r")
  tb <- table(key)
  data.frame(doc = sub("\r.*$", "", names(tb)), token = sub("^[^\r]*\r", "", names(tb)),
             Freq = as.integer(tb), stringsAsFactors = FALSE)
}

# tokens: data.frame con columna token | doc: vector (mismo largo) con el documento de cada token
# suavizado = TRUE usa idf = log((1+N)/(1+df)) + 1 (no anula los términos comunes a todos los
#             documentos; útil al comparar solo 2 periodos)
tfidf_docs <- function(tokens, doc, min_freq = 2, suavizado = FALSE) {
  ok <- !is.na(doc) & !is.na(tokens$token) & nzchar(tokens$token)
  if (!any(ok)) return(data.frame())
  tab <- .contar(doc[ok], tokens$token[ok])
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  n_doc <- length(unique(tab$doc))
  tot   <- tapply(tab$Freq, tab$doc, sum)
  dfreq <- table(tab$token)
  tab$tf  <- tab$Freq / as.numeric(tot[tab$doc])
  df_t    <- as.numeric(dfreq[tab$token])
  tab$idf <- if (suavizado) log((1 + n_doc) / (1 + df_t)) + 1 else log(n_doc / df_t)
  tab$tf_idf <- tab$tf * tab$idf
  tab <- tab[tab$Freq >= min_freq, , drop = FALSE]
  names(tab)[names(tab) == "Freq"] <- "n"
  tab[order(tab$doc, -tab$tf_idf), , drop = FALSE]
}

tfidf_top <- function(tf, top = 10) {
  if (!nrow(tf)) return(tf)
  out <- do.call(rbind, lapply(split(tf, tf$doc), function(x) utils::head(x[order(-x$tf_idf), ], top)))
  rownames(out) <- NULL
  out
}

# Qué palabras distinguen a cada MES dentro de un periodo
tfidf_mensual <- function(tokens, per, top = 10) {
  t <- filtrar_periodo(tokens, per)
  if (is.null(t) || !nrow(t) || length(unique(t$anio_mes)) < 2) {
    warning("TF-IDF mensual necesita al menos 2 meses dentro del periodo.", call. = FALSE)
    return(data.frame())
  }
  tfidf_top(tfidf_docs(t, t$anio_mes), top)
}

# Qué palabras distinguen al periodo A del periodo B
tfidf_comparar <- function(tokens, perA, perB, top = 15) {
  ta <- filtrar_periodo(tokens, perA); tb <- filtrar_periodo(tokens, perB)
  ta <- ta[!ta$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  tb <- tb[!tb$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  na <- perA$nombre; nb <- if (identical(perA$nombre, perB$nombre)) paste(perB$nombre, "(B)") else perB$nombre
  d <- rbind(data.frame(token = ta$token, doc = rep(na, nrow(ta)), stringsAsFactors = FALSE),
             data.frame(token = tb$token, doc = rep(nb, nrow(tb)), stringsAsFactors = FALSE))
  tfidf_top(tfidf_docs(d, d$doc, suavizado = TRUE), top)
  
}

# idf de todo el corpus (se usa para analizar UNA oración nueva)
idf_corpus <- function(tokens, doc) {
  ok <- !is.na(doc) & !is.na(tokens$token)
  u <- data.frame(doc = doc[ok], token = tokens$token[ok], stringsAsFactors = FALSE)
  u <- u[!duplicated(u), , drop = FALSE]
  n_doc <- length(unique(u$doc)); dfreq <- table(u$token)
  data.frame(token = names(dfreq), idf = log((1 + n_doc) / (1 + as.numeric(dfreq))) + 1, stringsAsFactors = FALSE)
}
