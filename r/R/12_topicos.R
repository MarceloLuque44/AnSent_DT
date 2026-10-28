# ==============================================================================
# 12_topicos.R  -  TOPIC MODELING (LDA)
# ------------------------------------------------------------------------------
# LDA (Blei, Ng y Jordan, 2003): cada documento es una mezcla de tópicos y cada tópico
# una distribución de palabras. Los mensajes de chat son MUY cortos, así que se agrupan
# en "documentos" por DÍA (o por MES): así LDA tiene suficientes palabras por documento.
# Un tópico = una temática; sus palabras más probables (beta) dicen de qué trata.
# Usa tokens.csv (ya sin stopwords).
# ==============================================================================

topicos_lda <- function(tokens, k = 6, agrupar = c("dia", "mes"), min_tokens_doc = 5,
                        min_freq_termino = 3, iter = 400, semilla = 123, top = 10) {
  .requiere(c("topicmodels", "slam"))
  agrupar <- match.arg(agrupar)
  doc <- if (agrupar == "dia") format(tokens$fecha, "%Y-%m-%d") else tokens$anio_mes
  ok <- !is.na(doc) & !is.na(tokens$token) & nzchar(tokens$token)
  tab <- .contar(doc[ok], tokens$token[ok])
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  tot_t <- tapply(tab$Freq, tab$token, sum)
  tab <- tab[tab$token %in% names(tot_t)[tot_t >= min_freq_termino], , drop = FALSE]
  tot_d <- tapply(tab$Freq, tab$doc, sum)
  tab <- tab[tab$doc %in% names(tot_d)[tot_d >= min_tokens_doc], , drop = FALSE]
  docs <- sort(unique(tab$doc)); terms <- sort(unique(tab$token))
  if (length(docs) < k + 1)
    stop("Hay muy pocos documentos (", length(docs), ") para ", k, " tópicos. ",
         "Usa un periodo más largo o menos tópicos (k).", call. = FALSE)

  dtm <- slam::simple_triplet_matrix(i = match(tab$doc, docs), j = match(tab$token, terms),
                                     v = as.integer(tab$Freq), nrow = length(docs), ncol = length(terms),
                                     dimnames = list(docs, terms))
  mod <- topicmodels::LDA(dtm, k = k, method = "Gibbs",
                          control = list(seed = semilla, burnin = 100, iter = iter, thin = 10))
  post  <- topicmodels::posterior(mod)
  beta  <- post$terms      # tópico x término
  gamma <- post$topics     # documento x tópico
  rownames(gamma) <- docs

  etiqueta <- apply(beta, 1, function(b) paste(names(sort(b, decreasing = TRUE))[1:3], collapse = " / "))
  ids <- paste0("T", seq_len(k))
  terminos <- do.call(rbind, lapply(seq_len(k), function(t) {
    b <- sort(beta[t, ], decreasing = TRUE)[seq_len(top)]
    data.frame(topico = ids[t], etiqueta = etiqueta[t], termino = names(b), beta = as.numeric(b),
               stringsAsFactors = FALSE)
  }))
  dominante <- data.frame(doc = rownames(gamma), topico = ids[max.col(gamma, ties.method = "first")],
                          peso = apply(gamma, 1, max), stringsAsFactors = FALSE)
  mes <- if (agrupar == "dia") substr(rownames(gamma), 1, 7) else rownames(gamma)
  peso_mes <- do.call(rbind, lapply(seq_len(k), function(t) {
    a <- tapply(gamma[, t], mes, mean)
    data.frame(anio_mes = names(a), topico = ids[t], etiqueta = etiqueta[t], peso_pct = as.numeric(a) * 100,
               stringsAsFactors = FALSE)
  }))
  list(paso = "Topic modeling: LDA con Gibbs (R/12_topicos.R) sobre tokens.csv", k = k, agrupar = agrupar,
       n_documentos = length(docs), n_terminos = length(terms), modelo = mod, beta = beta,
       etiquetas = data.frame(topico = ids, etiqueta = etiqueta, stringsAsFactors = FALSE),
       terminos = terminos, dominante = dominante, peso_mes = peso_mes)
}

# Aproximación para UNA oración nueva: se suma la probabilidad de sus palabras en cada tópico
# (no reentrena el modelo; sirve para mostrar "a qué temática se parece esta oración").
topico_de_texto <- function(tokens_oracion, lda) {
  b <- lda$beta
  v <- intersect(tokens_oracion, colnames(b))
  if (!length(v)) return(NULL)
  s <- rowSums(b[, v, drop = FALSE])
  data.frame(topico = lda$etiquetas$topico, etiqueta = lda$etiquetas$etiqueta,
             probabilidad_pct = round(100 * s / sum(s), 1), palabras_usadas = paste(v, collapse = " "),
             stringsAsFactors = FALSE)[order(-s), ]
}

# Agrega a cada mensaje el tópico dominante de su día (o mes). Sirve para el Sankey.
mensajes_con_topico <- function(m, lda) {
  clave <- if (lda$agrupar == "dia") format(m$fecha, "%Y-%m-%d") else m$anio_mes
  m$topico <- lda$dominante$topico[match(clave, lda$dominante$doc)]
  m
}
