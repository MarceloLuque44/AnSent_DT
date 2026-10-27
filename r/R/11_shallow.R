# ==============================================================================
# 11_shallow.R  -  SHALLOW LINGUISTIC (análisis lingüístico superficial) con udpipe
# ------------------------------------------------------------------------------
# Qué hace: etiqueta cada palabra con su categoría gramatical (sustantivo, verbo,
# adjetivo...), obtiene su lema (forma base) y extrae frases nominales (chunking).
# Se aplica sobre texto_limpio (la frase COMPLETA, con stopwords): la gramática necesita
# las palabras de enlace. No sobre los tokens ya filtrados.
# Decisión C11: aquí se lematiza; el preprocesamiento NO lematiza (los sentimientos
# usan raíces). Los lemas viven en una tabla aparte.
# Requiere internet UNA vez para bajar el modelo de español (queda en modelos/).
# ==============================================================================

modelo_udpipe <- function(dir_modelos = "modelos") {
  .requiere("udpipe")
  dir.create(dir_modelos, showWarnings = FALSE, recursive = TRUE)
  f <- list.files(dir_modelos, pattern = "spanish.*\\.udpipe$", full.names = TRUE)
  if (!length(f)) {
    message("Descargando el modelo de español de udpipe (solo la primera vez; necesita internet)...")
    f <- udpipe::udpipe_download_model(language = "spanish", model_dir = dir_modelos)$file_model
  }
  udpipe::udpipe_load_model(f[1])
}

shallow_linguistic <- function(m, modelo = NULL, max_mensajes = 1500, semilla = 1) {
  .requiere("udpipe")
  if (is.null(modelo)) modelo <- modelo_udpipe()
  x <- m[!is.na(m$texto_limpio) & nzchar(m$texto_limpio), c("id_mensaje", "texto_limpio"), drop = FALSE]
  if (!nrow(x)) stop("No hay texto para analizar.", call. = FALSE)
  if (nrow(x) > max_mensajes) { set.seed(semilla); x <- x[sample(nrow(x), max_mensajes), , drop = FALSE] }
  a <- as.data.frame(udpipe::udpipe_annotate(modelo, x = x$texto_limpio, doc_id = as.character(x$id_mensaje)),
                     stringsAsFactors = FALSE)
  a <- a[, c("doc_id", "sentence_id", "token_id", "token", "lemma", "upos")]

  upos <- as.data.frame(table(clase = a$upos), stringsAsFactors = FALSE)
  names(upos)[2] <- "n"
  upos$pct <- round(100 * upos$n / sum(upos$n), 1)
  upos <- upos[order(-upos$n), , drop = FALSE]

  lemas <- do.call(rbind, lapply(c("NOUN", "VERB", "ADJ"), function(u) {
    s <- a$lemma[a$upos == u & !is.na(a$lemma)]
    if (!length(s)) return(NULL)
    h <- utils::head(sort(table(tolower(s)), decreasing = TRUE), 15)
    data.frame(clase = u, lema = names(h), n = as.integer(h), stringsAsFactors = FALSE)
  }))

  frases <- tryCatch({
    fase <- udpipe::as_phrasemachine(a$upos, type = "upos")
    fr <- udpipe::keywords_phrases(fase, term = tolower(a$token), pattern = "(A|N)*N(P+D*(A|N)*N)*",
                                   is_regex = TRUE, ngram_max = 4, detailed = FALSE)
    fr <- fr[fr$ngram > 1, , drop = FALSE]
    utils::head(fr[order(-fr$freq), ], 20)
  }, error = function(e) NULL)

  list(paso = "Shallow linguistic: udpipe (R/11_shallow.R) sobre texto_limpio", n_mensajes = nrow(x),
       anotado = a, upos = upos, lemas = lemas, frases_nominales = frases)
}
