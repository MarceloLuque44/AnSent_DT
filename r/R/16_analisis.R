# ==============================================================================
# 16_analisis.R  -  FUNCIONES PRINCIPALES de la parte 2 (las que llama el dashboard)
# ------------------------------------------------------------------------------
#   source("cargar_proyecto.R")
#   res   <- preprocesar("data/result.json")            # UNA vez, con todo el dataset
#   datos <- cargar_datos_analisis("salida")
#
#   a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))   # un periodo
#   a$nivel; a$tfidf; a$topicos$terminos; a$shallow$upos; a$libreria
#   p <- graficos_periodo(a);  p$barras;  p$tiempo;  p$polar
#
#   cmp <- comparar_periodos(datos, "todo_2023", "todo_2024")      # A contra B
#   cmp$interpretacion;  graficos_comparacion(cmp)$arana
#
#   guardar_analisis(a)   # deja CSV/PNG en salida/analisis/<periodo>/ (para el dashboard)
# Cada análisis queda anotado en bitacoras/bitacora_completa.xlsx, hoja "Experimentos".
# ==============================================================================

.registrar_exp <- function(registrar, dir_bitacoras, ...) {
  if (isTRUE(registrar)) try(registrar_experimento(..., dir_bitacoras = dir_bitacoras), silent = TRUE)
  invisible()
}

# Frases en lenguaje natural para INTERPRETAR (descriptivo; no es una prueba estadística)
interpretar_periodo <- function(niv, nombre = "el periodo") {
  niv <- niv[order(-niv$nivel_pct), ]
  top <- utils::head(niv, 3)
  paste0("En ", nombre, " predominan ", paste0(top$sentimiento, " (", round(top$nivel_pct, 1), "%)", collapse = ", "),
         "; el menos presente es ", niv$sentimiento[nrow(niv)], " (", round(niv$nivel_pct[nrow(niv)], 1), "%).")
}

interpretar_comparacion <- function(niv_largo, nombreA, nombreB) {
  a <- niv_largo[niv_largo$periodo == nombreA, ]; b <- niv_largo[niv_largo$periodo == nombreB, ]
  w <- merge(a[, c("sentimiento", "nivel_pct")], b[, c("sentimiento", "nivel_pct")], by = "sentimiento", suffixes = c("_A", "_B"))
  w$dif <- w$nivel_pct_B - w$nivel_pct_A
  w <- w[order(-w$dif), ]
  c(interpretar_periodo(a, nombreA), interpretar_periodo(b, nombreB),
    sprintf("De %s a %s, el mayor aumento es %s (%+.1f puntos) y el mayor descenso es %s (%+.1f puntos).",
            nombreA, nombreB, w$sentimiento[1], w$dif[1], w$sentimiento[nrow(w)], w$dif[nrow(w)]),
    "Lectura descriptiva: diferencias pequeñas pueden deberse al azar o a que un periodo tiene menos mensajes; revisa n_mensajes.")
}

analizar_periodo <- function(datos, fecha_inicio = NULL, fecha_fin = NULL,
                             periodo = NULL, periodos = cargar_periodos(), k = 6, agrupar = "dia",
                             shallow = TRUE, libreria = TRUE, max_mensajes_shallow = 1500,
                             max_mensajes_libreria = 5000, modelo_udpipe = NULL,
                             registrar = TRUE, dir_bitacoras = "bitacoras", dir_salida = "salida") {
  if (!is.null(fecha_inicio) || !is.null(fecha_fin)) {
    fi <- as.Date(fecha_inicio %||% min(datos$mensajes$fecha, na.rm = TRUE))
    ff <- as.Date(fecha_fin %||% max(datos$mensajes$fecha, na.rm = TRUE))
    per <- list(nombre = paste0(format(fi, "%Y-%m-%d"), "_a_", format(ff, "%Y-%m-%d")),
                inicio = fi, fin = ff)
    m <- subset(datos$mensajes, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
    tk <- subset(datos$tokens, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
  } else {
    per <- resolver_periodo(periodo, periodos, datos$mensajes$fecha)
    m  <- filtrar_periodo(datos$mensajes, per)
    tk <- filtrar_periodo(datos$tokens, per)
  }
  if (!is.null(tk)) tk <- tk[!tk$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  if (!nrow(m)) stop("No hay mensajes en el periodo ", per$nombre, ".", call. = FALSE)
  res <- list(periodo = per, n_mensajes = nrow(m))

  res$nivel <- nivel_sentimiento(m)
  res$serie <- serie_sentimientos(m)
  res$interpretacion <- interpretar_periodo(res$nivel, per$nombre)
  res$stopwords <- tryCatch(mostrar_stopwords(dir_salida), error = function(e) NULL)

  res$tfidf <- tryCatch(tfidf_mensual(tk, per), error = function(e) { message("TF-IDF: ", conditionMessage(e)); NULL })
  .registrar_exp(registrar, dir_bitacoras, metodo = "tfidf", parametros = paste0("periodo=", per$nombre, "; documentos=meses"),
                 n_documentos = length(unique(tk$anio_mes)), tamano_vocabulario = length(unique(tk$token)),
                 resultado_principal = if (!is.null(res$tfidf) && nrow(res$tfidf)) paste("top:", paste(utils::head(res$tfidf$token, 5), collapse = ", ")) else "")

  res$topicos <- tryCatch(topicos_lda(tk, k = k, agrupar = agrupar), error = function(e) { message("Tópicos: ", conditionMessage(e)); NULL })
  if (!is.null(res$topicos))
    .registrar_exp(registrar, dir_bitacoras, metodo = "topic modeling (LDA)", parametros = paste0("periodo=", per$nombre, "; k=", k, "; documentos=", agrupar),
                   n_documentos = res$topicos$n_documentos, tamano_vocabulario = res$topicos$n_terminos,
                   resultado_principal = paste(res$topicos$etiquetas$etiqueta, collapse = " | "))

  if (shallow) {
    res$shallow <- tryCatch(shallow_linguistic(m, modelo = modelo_udpipe, max_mensajes = max_mensajes_shallow),
                            error = function(e) { message("Shallow: ", conditionMessage(e)); NULL })
    if (!is.null(res$shallow))
      .registrar_exp(registrar, dir_bitacoras, metodo = "shallow linguistic (udpipe)", parametros = paste0("periodo=", per$nombre),
                     n_documentos = res$shallow$n_mensajes, tamano_vocabulario = "",
                     resultado_principal = paste(utils::head(res$shallow$upos$clase, 3), collapse = ", "))
  }
  if (libreria) {
    ml <- tryCatch(sentimientos_libreria(m, max_mensajes = max_mensajes_libreria), error = function(e) { message("Librería: ", conditionMessage(e)); NULL })
    if (!is.null(ml)) {
      res$libreria <- nivel_libreria(ml)
      res$comparacion <- comparar_con_sin_libreria(ml)
      .registrar_exp(registrar, dir_bitacoras, metodo = "sentimientos librería (syuzhet NRC)", parametros = paste0("periodo=", per$nombre),
                     n_documentos = nrow(ml), tamano_vocabulario = "",
                     resultado_principal = paste0("acuerdo de polaridad con los propios: ", res$comparacion$acuerdo_polaridad_pct, "%"))
    }
  }
  .registrar_exp(registrar, dir_bitacoras, metodo = "nivel de sentimientos (propios)", parametros = paste0("periodo=", per$nombre),
                 n_documentos = nrow(m), resultado_principal = res$interpretacion)
  res$mensajes <- m
  class(res) <- c("analisis_periodo", "list")
  res
}

comparar_periodos <- function(datos, fecha_inicio_a = NULL, fecha_fin_a = NULL,
                              fecha_inicio_b = NULL, fecha_fin_b = NULL,
                              periodoA = NULL, periodoB = NULL, periodos = cargar_periodos(), libreria = TRUE,
                              max_mensajes_libreria = 5000, registrar = TRUE, dir_bitacoras = "bitacoras") {
  if (!is.null(fecha_inicio_a) || !is.null(fecha_fin_a) ||
      !is.null(fecha_inicio_b) || !is.null(fecha_fin_b)) {
    fiA <- as.Date(fecha_inicio_a %||% min(datos$mensajes$fecha, na.rm = TRUE))
    ffA <- as.Date(fecha_fin_a %||% max(datos$mensajes$fecha, na.rm = TRUE))
    fiB <- as.Date(fecha_inicio_b %||% min(datos$mensajes$fecha, na.rm = TRUE))
    ffB <- as.Date(fecha_fin_b %||% max(datos$mensajes$fecha, na.rm = TRUE))
    perA <- list(nombre = paste0(format(fiA, "%Y-%m-%d"), "_a_", format(ffA, "%Y-%m-%d")),
                 inicio = fiA, fin = ffA)
    perB <- list(nombre = paste0(format(fiB, "%Y-%m-%d"), "_a_", format(ffB, "%Y-%m-%d")),
                 inicio = fiB, fin = ffB)
    lp <- list(A = perA, B = perB)
    nA <- lp$A$nombre; nB <- lp$B$nombre
    mA <- subset(datos$mensajes, as.Date(fecha) >= fiA & as.Date(fecha) <= ffA)
    mB <- subset(datos$mensajes, as.Date(fecha) >= fiB & as.Date(fecha) <= ffB)
    tkA <- subset(datos$tokens, as.Date(fecha) >= fiA & as.Date(fecha) <= ffA)
    tkB <- subset(datos$tokens, as.Date(fecha) >= fiB & as.Date(fecha) <= ffB)
    m <- rbind(mA, mB)
    tk <- rbind(tkA, tkB)
  } else {
    lp <- periodos_lista(list(periodoA, periodoB), periodos, datos$mensajes$fecha)
    nA <- names(lp)[1]; nB <- names(lp)[2]
    m <- rbind(filtrar_periodo(datos$mensajes, lp[[1]]), filtrar_periodo(datos$mensajes, lp[[2]]))
    tk <- rbind(filtrar_periodo(datos$tokens, lp[[1]]), filtrar_periodo(datos$tokens, lp[[2]]))
  }
  res <- list(periodos = lp)
  res$niveles <- niveles_por_periodo(datos$mensajes, lp)
  res$serie <- serie_sentimientos(m)
  res$tfidf <- tryCatch(tfidf_comparar(tk, lp[[1]], lp[[2]]), error = function(e) NULL)
  res$interpretacion <- interpretar_comparacion(res$niveles, nA, nB)
  if (libreria) {
    lib <- lapply(names(lp), function(nm) tryCatch(
      sentimientos_libreria(filtrar_periodo(datos$mensajes, lp[[nm]]), max_mensajes = max_mensajes_libreria), error = function(e) NULL))
    names(lib) <- names(lp)
    if (all(!vapply(lib, is.null, logical(1)))) {
      res$libreria <- do.call(rbind, lapply(names(lib), function(nm) { x <- nivel_libreria(lib[[nm]]); x$periodo <- nm; x }))
      res$comparacion <- lapply(lib, comparar_con_sin_libreria)
    }
  }
  .registrar_exp(registrar, dir_bitacoras, metodo = "comparación de periodos", parametros = paste0("A=", nA, "; B=", nB),
                 n_documentos = nrow(m), resultado_principal = res$interpretacion[3])
  class(res) <- c("comparacion_periodos", "list")
  res
}

graficos_periodo <- function(a, x = NULL, y = NULL) {
  tryg <- function(expr) tryCatch(expr, error = function(e) NULL)
  nom <- a$nivel$sentimiento
  g <- list()
  g$barras  <- tryg(g_barras(a$nivel, paste("Sentimientos propios:", a$periodo$nombre)))
  g$polar   <- tryg(g_polar(a$nivel))
  g$tiempo  <- tryg(g_tiempo(a$serie))
  g$apilado <- tryg(g_apilado(a$serie))
  g$dispersion <- tryg(g_dispersion(a$serie, x %||% nom[1], y %||% nom[2]))
  g$tfidf   <- if (!is.null(a$tfidf) && nrow(a$tfidf)) tryg(g_tfidf(a$tfidf)) else NULL
  if (!is.null(a$topicos)) {
    g$topicos <- tryg(g_topicos(a$topicos$terminos))
    g$topicos_tiempo <- tryg(g_topicos_tiempo(a$topicos$peso_mes))
    g$sankey <- tryg(g_sankey(mensajes_con_topico(a$mensajes, a$topicos)))
  }
  if (!is.null(a$shallow)) g$upos <- tryg(g_upos(a$shallow$upos))
  if (!is.null(a$libreria)) g$libreria <- tryg(g_barras(a$libreria[a$libreria$tipo == "emocion (8)", ], "Las 8 emociones de la librería (syuzhet)"))
  g$calor <- tryg(g_calor(a$mensajes))
  g[!vapply(g, is.null, logical(1))]
}

graficos_comparacion <- function(cmp) {
  tryg <- function(expr) tryCatch(expr, error = function(e) NULL)
  g <- list(barras = tryg(g_barras_comparar(cmp$niveles)), arana = tryg(g_arana(cmp$niveles)),
            tiempo = tryg(g_tiempo(cmp$serie)))
  if (!is.null(cmp$tfidf) && nrow(cmp$tfidf)) g$tfidf <- tryg(g_tfidf(cmp$tfidf, "Palabras que distinguen a cada periodo (TF-IDF)"))
  if (!is.null(cmp$libreria)) g$libreria <- tryg(g_barras_comparar(cmp$libreria[cmp$libreria$tipo == "emocion (8)", ], "Librería (syuzhet): comparación"))
  g[!vapply(g, is.null, logical(1))]
}

# Deja las tablas (CSV) y los gráficos (PNG) listos para que el dashboard los lea
guardar_analisis <- function(a, dir = "salida/analisis", graficos = TRUE) {
  nom <- if (inherits(a, "comparacion_periodos")) paste(a$periodos[[1]]$nombre, a$periodos[[2]]$nombre, sep = " vs ") else a$periodo$nombre
  d <- file.path(dir, gsub("[^A-Za-z0-9_-]+", "_", nom)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  w <- function(x, f) if (!is.null(x) && is.data.frame(x) && nrow(x)) escribir_csv(x, file.path(d, f))
  if (inherits(a, "comparacion_periodos")) {
    w(a$niveles, "niveles.csv"); w(a$serie, "serie_mensual.csv"); w(a$tfidf, "tfidf.csv"); w(a$libreria, "libreria_niveles.csv")
    writeLines(a$interpretacion, file.path(d, "interpretacion.txt"), useBytes = TRUE)
    gr <- if (graficos) graficos_comparacion(a) else list()
  } else {
    w(a$nivel, "niveles.csv"); w(a$serie, "serie_mensual.csv"); w(a$tfidf, "tfidf.csv"); w(a$libreria, "libreria_niveles.csv")
    if (!is.null(a$topicos)) { w(a$topicos$terminos, "topicos_terminos.csv"); w(a$topicos$peso_mes, "topicos_por_mes.csv"); w(a$topicos$dominante, "topicos_por_documento.csv") }
    if (!is.null(a$shallow)) { w(a$shallow$upos, "shallow_categorias.csv"); w(a$shallow$lemas, "shallow_lemas.csv"); w(a$shallow$frases_nominales, "shallow_frases_nominales.csv") }
    if (!is.null(a$stopwords)) { w(a$stopwords$eliminadas, "stopwords_eliminadas.csv"); w(a$stopwords$conservadas, "stopwords_conservadas.csv") }
    writeLines(a$interpretacion, file.path(d, "interpretacion.txt"), useBytes = TRUE)
    gr <- if (graficos) graficos_todos(a) else list()
  }
  for (nm in names(gr)) try(.gg()$ggsave(file.path(d, paste0(nm, ".png")), gr[[nm]], width = 9, height = 6, dpi = 120), silent = TRUE)
  message("Análisis guardado en ", d)
  invisible(d)
}






