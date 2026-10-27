# ==============================================================================
# 15_oracion.R  -  UNA ORACIÓN EN VIVO: corre los 4 procesos sobre una frase
# ------------------------------------------------------------------------------
#   o <- analizar_oracion("Hola, no entiendo el laboratorio de INF 111, ayuda por favor",
#                         datos = datos, lda = analisis$topicos)
#   o            # se imprime paso a paso: STOPWORDS, SHALLOW, TF-IDF, TÓPICOS, SENTIMIENTOS
#
# Usa el MISMO preprocesamiento (preprocesar) sobre un archivo temporal, así que la frase
# pasa por exactamente las mismas reglas y diccionarios. Sus bitácoras van a una carpeta
# temporal: NO ensucian bitacoras/ ni salida/.
#   datos = lo que devuelve cargar_datos_analisis()  (da el idf del TF-IDF)
#   lda   = analisis$topicos                         (da los tópicos)
# ==============================================================================

analizar_oracion <- function(texto, datos = NULL, lda = NULL, modelo = NULL,
                             usar_udpipe = TRUE, usar_libreria = TRUE) {
  stopifnot(is.character(texto), length(texto) == 1, nzchar(trimws(texto)))
  tmp <- tempfile("oracion_")
  tmp <- tempfile("oracion_")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  csv <- file.path(tmp, "oracion.csv")
  
  utils::write.csv(data.frame(id = 1, date = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), from = "demo",
                              text = texto, stringsAsFactors = FALSE),
                   csv, row.names = FALSE, fileEncoding = "UTF-8")
  sal <- file.path(tmp, "salida")
  r <- try(suppressMessages(preprocesar(csv, dir_salida = sal, dir_bitacoras = file.path(tmp, "bitacoras"),
                                        consola = "silencioso", preguntar_cambios = FALSE,
                                        nuevos_emojis = "marcar")), silent = TRUE)
  out <- list(texto = texto)
  f_limpio <- file.path(sal, "mensajes_limpios.csv")
  fila <- if (file.exists(f_limpio)) readr::read_csv(f_limpio, show_col_types = FALSE, progress = FALSE) else NULL
  if (is.null(fila) || !nrow(fila)) {
    fx <- file.path(sal, "mensajes_excluidos.csv")
    out$excluida <- TRUE
    out$motivo <- if (file.exists(fx)) readr::read_csv(fx, show_col_types = FALSE, progress = FALSE)$motivo_exclusion[1]
                  else if (inherits(r, "try-error")) as.character(r) else "no se pudo procesar"
    return(structure(out, class = "analisis_oracion"))
  }
  fila$fecha <- as.Date(fila$fecha)
  tk <- readr::read_csv(file.path(sal, "tokens.csv"), show_col_types = FALSE, progress = FALSE)
  tokens <- tk$token
  tokens_tema <- tokens[!tokens %in% PALABRAS_SIN_TEMA]
  fsw <- file.path(sal, "stopwords_aplicadas.csv")
  sw <- if (file.exists(fsw)) readr::read_csv(fsw, show_col_types = FALSE, progress = FALSE) else NULL

  out$excluida <- FALSE
  out$limpio <- fila$texto_limpio[1]
  out$tokens <- tokens
  # 1) STOPWORDS
  out$stopwords <- list(eliminadas = if (!is.null(sw)) sw[sw$decision == "eliminada", ] else NULL,
                        conservadas = if (!is.null(sw)) sw[sw$decision == "conservada", ] else NULL)
  # 2) SHALLOW LINGUISTIC
  if (usar_udpipe) out$shallow <- tryCatch(shallow_linguistic(fila, modelo = modelo, max_mensajes = 1),
                                           error = function(e) { message("Shallow no disponible: ", conditionMessage(e)); NULL })
  # 3) TF-IDF (idf calculado con todo el corpus; tf, con esta oración)
  if (!is.null(datos) && !is.null(datos$tokens) && length(tokens)) {
    idf <- idf_corpus(datos$tokens, datos$tokens$anio_mes)
    tb <- table(tokens_tema)
    t <- data.frame(token = names(tb), n = as.integer(tb), stringsAsFactors = FALSE)
    t$tf <- t$n / sum(t$n)
    t$idf <- idf$idf[match(t$token, idf$token)]
    t$idf[is.na(t$idf)] <- max(idf$idf)            # palabra nunca vista = la más rara
    t$tf_idf <- t$tf * t$idf
    out$tfidf <- t[order(-t$tf_idf), ]
  }
  # 4) TOPIC MODELING
  if (!is.null(lda)) out$topicos <- topico_de_texto(tokens_tema, lda) 
  out$lda_dado <- !is.null(lda)
  # 5) SENTIMIENTOS: propios (15) y de la librería (8)
  nom <- nombres_sentimientos(fila)
  p <- data.frame(sentimiento = nom, pct = unname(vapply(nom, function(s) fila[[paste0("pct_", s)]][1], numeric(1))),
                  stringsAsFactors = FALSE)
  out$propios <- p[p$pct > 0, , drop = FALSE][order(-p$pct[p$pct > 0]), ]
  out$polaridad <- fila$polaridad_msg[1]
  out$dominante <- fila$sentimiento_dominante[1]
  if (!is.null(datos)) out$nivel_vs_corpus <- nivel_mensaje(fila, datos$mensajes)
  if (usar_libreria) out$libreria <- tryCatch({
    l <- sentimientos_libreria(fila); x <- nivel_libreria(l); x[x$nivel_pct > 0, ]
  }, error = function(e) { message("Librería no disponible: ", conditionMessage(e)); NULL })
  structure(out, class = "analisis_oracion")
}

print.analisis_oracion <- function(x, ...) {
  b <- function(t) cat("\n", strrep("=", 80), "\n  ", t, "\n", strrep("=", 80), "\n", sep = "")
  cat("ORACIÓN: ", x$texto, "\n", sep = "")
  if (isTRUE(x$excluida)) { cat("\nEsta oración fue EXCLUIDA por el preprocesamiento. Motivo: ", x$motivo, "\n", sep = ""); return(invisible(x)) }
  b("0. PREPROCESAMIENTO (mismo que el dataset)")
  cat("Texto limpio : ", x$limpio, "\nTokens finales: ", paste(x$tokens, collapse = " "), "\n", sep = "")
  b("1. STOPWORDS (paso 10.2 de R/06_texto.R, config/stopwords.csv)")
  if (!is.null(x$stopwords$eliminadas) && nrow(x$stopwords$eliminadas)) { cat("Eliminadas:\n"); print(x$stopwords$eliminadas[, intersect(c("palabra", "motivo"), names(x$stopwords$eliminadas))], row.names = FALSE) }
  if (!is.null(x$stopwords$conservadas) && nrow(x$stopwords$conservadas)) { cat("Conservadas (importan para el sentimiento):\n"); print(x$stopwords$conservadas[, intersect(c("palabra", "motivo"), names(x$stopwords$conservadas))], row.names = FALSE) }
  b("2. SHALLOW LINGUISTIC (R/11_shallow.R, udpipe)")
  if (!is.null(x$shallow)) { print(x$shallow$anotado[, c("token", "lemma", "upos")], row.names = FALSE); if (!is.null(x$shallow$frases_nominales)) { cat("Frases nominales:\n"); print(x$shallow$frases_nominales, row.names = FALSE) } } else cat("(no disponible)\n")
  b("3. TF-IDF (R/10_tfidf.R)  tf = de esta oración;  idf = de todo el corpus")
  if (!is.null(x$tfidf)) print(x$tfidf, row.names = FALSE) else cat("(pasa datos = cargar_datos_analisis() para calcularlo)\n")
  b("4. TOPIC MODELING (R/12_topicos.R)  a qué tópico se parece")
  if (!is.null(x$topicos)) print(x$topicos[, c("topico", "etiqueta", "probabilidad_pct")], row.names = FALSE)    else if (isTRUE(x$lda_dado)) cat("Ninguna palabra de la oración está en el vocabulario de los tópicos de este periodo.\n") else cat("(pasa lda = analisis$topicos)\n")
  b("5. SENTIMIENTOS")
  cat("Polaridad: ", x$polaridad, "   Dominante: ", ifelse(is.na(x$dominante), "ninguno", x$dominante), "\n", sep = "")
  cat("Propios (% de las palabras):\n"); print(x$propios, row.names = FALSE)
  if (!is.null(x$nivel_vs_corpus)) { cat("Mensaje vs. todo el dataset:\n"); print(x$nivel_vs_corpus[x$nivel_vs_corpus$mensaje_pct > 0, ], row.names = FALSE) }
  if (!is.null(x$libreria)) { cat("Librería (syuzhet / NRC):\n"); print(x$libreria, row.names = FALSE) }
  invisible(x)
}
