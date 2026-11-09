# ==============================================================================
# 16_analisis.R  -  FUNCIONES PRINCIPALES de la parte 2 (las que llama el dashboard)
# ------------------------------------------------------------------------------
# Este script contiene las funciones de alto nivel del análisis de sentimientos
# (parte 2 del pipeline). Asume que el preprocesamiento ya se ejecutó una vez con
# todo el dataset y que los datos limpios están disponibles en salida/.
#
# Flujo típico:
#   source("cargar_proyecto.R")              # carga todas las herramientas (una vez)
#   res   <- preprocesar("data/result.json") # UNA vez, con todo el dataset
#   datos <- cargar_datos_analisis("salida") # carga mensajes_limpios.csv y tokens.csv
#
#   a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))   # un periodo
#   a$nivel; a$tfidf; a$topicos$terminos; a$shallow$upos; a$libreria
#   p <- graficos_periodo(a);  p$barras;  p$tiempo;  p$polar
#
#   cmp <- comparar_periodos(datos, "todo_2023", "todo_2024")      # A contra B
#   cmp$interpretacion;  graficos_comparacion(cmp)$arana
#
#   guardar_analisis(a)   # deja CSV/PNG en salida/analisis/<periodo>/ (para el dashboard)
#
# Cada análisis queda anotado en bitacoras/bitacora_completa.xlsx, hoja "Experimentos".
# ==============================================================================

# ------------------------------------------------------------------------------
# Helper interno: registra un experimento en la bitácora completa si registrar=TRUE.
# Se usa para dejar constancia de cada análisis post-preprocesamiento (TF-IDF,
# LDA, shallow, librería, nivel de sentimientos, comparación).
# ------------------------------------------------------------------------------
.registrar_exp <- function(registrar, dir_bitacoras, ...) {
  if (isTRUE(registrar)) try(registrar_experimento(..., dir_bitacoras = dir_bitacoras), silent = TRUE)
  invisible()
}

# ------------------------------------------------------------------------------
# interpretar_periodo: genera una frase en lenguaje natural que resume el
# perfil emocional de un periodo (descriptivo, no es prueba estadística).
#
# Parametros:
#   niv   : data.frame con columnas sentimiento, nivel_pct (salida de nivel_sentimiento)
#   nombre: texto descriptivo del periodo (ej. "enero 2023", "todo el dataset")
#
# Retorna: un string con la interpretación.
# ------------------------------------------------------------------------------
interpretar_periodo <- function(niv, nombre = "el periodo") {
  niv <- niv[order(-niv$nivel_pct), ]           # ordena de mayor a menor nivel
  top <- utils::head(niv, 3)                    # top 3 sentimientos
  paste0("En ", nombre, " predominan ", paste0(top$sentimiento, " (", round(top$nivel_pct, 1), "%)", collapse = ", "),
         "; el menos presente es ", niv$sentimiento[nrow(niv)], " (", round(niv$nivel_pct[nrow(niv)], 1), "%).")
}

# ------------------------------------------------------------------------------
# interpretar_comparacion: genera frases interpretativas para la comparacion
# de dos periodos (A vs B): que predominó en cada uno, que aumento mas y que
# disminuyo mas.
#
# Parametros:
#   niv_largo : data.frame largo con columnas periodo, sentimiento, nivel_pct
#               (salida de niveles_por_periodo)
#   nombreA   : nombre del periodo A
#   nombreB   : nombre del periodo B
#
# Retorna: vector de strings con la interpretación completa.
# ------------------------------------------------------------------------------
interpretar_comparacion <- function(niv_largo, nombreA, nombreB) {
  a <- niv_largo[niv_largo$periodo == nombreA, ]; b <- niv_largo[niv_largo$periodo == nombreB, ]
  w <- merge(a[, c("sentimiento", "nivel_pct")], b[, c("sentimiento", "nivel_pct")], by = "sentimiento", suffixes = c("_A", "_B"))
  w$dif <- w$nivel_pct_B - w$nivel_pct_A            # diferencia punto porcentual B - A
  w <- w[order(-w$dif), ]                          # ordena de mayor aumento a mayor descenso
  c(interpretar_periodo(a, nombreA), interpretar_periodo(b, nombreB),
    sprintf("De %s a %s, el mayor aumento es %s (%+.1f puntos) y el mayor descenso es %s (%+.1f puntos).",
            nombreA, nombreB, w$sentimiento[1], w$dif[1], w$sentimiento[nrow(w)], w$dif[nrow(w)]),
    "Lectura descriptiva: diferencias pequeñas pueden deberse al azar o a que un periodo tiene menos mensajes; revisa n_mensajes.")
}

# ------------------------------------------------------------------------------
# analizar_periodo: funcion principal de analisis de un periodo. Filtra los datos
# limpios por fechas (o por nombre de periodo) y calcula: nivel de sentimientos,
# serie temporal, TF-IDF mensual, topicos LDA, shallow linguistic (opcional) y
# sentimientos de la librería syuzhet (opcional).
#
# Parametros:
#   datos               : lista salida de cargar_datos_analisis() (mensajes + tokens)
#   fecha_inicio        : fecha de inicio (opcional, formato "YYYY-MM-DD")
#   fecha_fin           : fecha de fin (opcional, formato "YYYY-MM-DD")
#   periodo             : nombre de periodo predefinido (opcional, usa config/periodos.csv)
#   periodos            : data.frame de periodos (salida de cargar_periodos())
#   k                   : numero de topicos para LDA (default 6)
#   agrupar             : unidad de agrupacion para LDA ("dia" o "mes", default "dia")
#   shallow             : si ejecutar shallow linguistic con udpipe (default TRUE)
#   libreria            : si ejecutar sentimientos de syuzhet NRC (default TRUE)
#   max_mensajes_shallow: max mensajes para shallow (default 1500)
#   max_mensajes_libreria: max mensajes para syuzhet (default 5000)
#   modelo_udpipe       : modelo udpipe cargado (opcional, se carga si es NULL)
#   registrar           : si registrar experimentos en bitacora (default TRUE)
#   dir_bitacoras       : carpeta de bitacoras (default "bitacoras")
#   dir_salida          : carpeta de salida para stopwords (default "salida")
#
# Retorna: lista de clase "analisis_periodo" con:
#   periodo      : info del periodo (nombre, inicio, fin)
#   n_mensajes   : cantidad de mensajes filtrados
#   nivel        : data.frame con nivel_pct y mensajes_pct por sentimiento
#   serie        : serie temporal de sentimientos
#   interpretacion : frase descriptiva del periodo
#   stopwords    : tabla de stopwords aplicadas
#   tfidf        : terminos mas distintivos por mes
#   topicos      : resultado LDA (modelo, beta, terminos, dominante, peso_mes)
#   shallow      : analisis udpipe (upos, lemas, frases nominales)
#   libreria     : nivel de emociones syuzhet
#   comparacion  : comparacion propio vs libreria (polaridad)
#   mensajes     : data.frame filtrado de mensajes del periodo
# ------------------------------------------------------------------------------
analizar_periodo <- function(datos, fecha_inicio = NULL, fecha_fin = NULL,
                             periodo = NULL, periodos = cargar_periodos(), k = 6, agrupar = "dia",
                             shallow = TRUE, libreria = TRUE, max_mensajes_shallow = 1500,
                             max_mensajes_libreria = 5000, modelo_udpipe = NULL,
                             registrar = TRUE, dir_bitacoras = "bitacoras", dir_salida = "salida") {
  # --- Resolver parametros de fecha ---
  fi <- .fecha_param(fecha_inicio)
  ff <- .fecha_param(fecha_fin)
  if (!is.null(fi) || !is.null(ff)) {
    # Rango de fechas explicitado: usar directamente
    fi <- fi %||% as.Date(min(datos$mensajes$fecha, na.rm = TRUE))
    ff <- ff %||% as.Date(max(datos$mensajes$fecha, na.rm = TRUE))
    per <- list(nombre = paste0(format(fi, "%Y-%m-%d"), "_a_", format(ff, "%Y-%m-%d")),
                inicio = fi, fin = ff)
    m <- subset(datos$mensajes, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
    tk <- subset(datos$tokens, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
  } else {
    # Periodo por nombre: resolver desde config/periodos.csv
    per <- resolver_periodo(periodo, periodos, datos$mensajes$fecha)
    m  <- filtrar_periodo(datos$mensajes, per)
    tk <- filtrar_periodo(datos$tokens, per)
  }
  # Quitar palabras sin tema (no, ni, nunca, tampoco, jamas, nada, sin, muy, mas) de los tokens
  if (!is.null(tk)) tk <- tk[!tk$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  # Validar que haya mensajes en el periodo
  if (!nrow(m)) stop("No hay mensajes en el periodo ", per$nombre, ".", call. = FALSE)
  res <- list(periodo = per, n_mensajes = nrow(m))

  # --- Nivel de sentimientos propios (pct_*) ---
  res$nivel <- nivel_sentimiento(m)
  # --- Serie temporal de sentimientos ---
  res$serie <- serie_sentimientos(m)
  # --- Interpretacion descriptiva ---
  res$interpretacion <- interpretar_periodo(res$nivel, per$nombre)
  # --- Stopwords aplicadas en el preprocesamiento ---
  res$stopwords <- tryCatch(mostrar_stopwords(dir_salida), error = function(e) NULL)

  # --- TF-IDF mensual (terminos mas distintivos por mes) ---
  res$tfidf <- tryCatch(tfidf_mensual(tk, per), error = function(e) { message("TF-IDF: ", conditionMessage(e)); NULL })
  .registrar_exp(registrar, dir_bitacoras, metodo = "tfidf", parametros = paste0("periodo=", per$nombre, "; documentos=meses"),
                 n_documentos = length(unique(tk$anio_mes)), tamano_vocabulario = length(unique(tk$token)),
                 resultado_principal = if (!is.null(res$tfidf) && nrow(res$tfidf)) paste("top:", paste(utils::head(res$tfidf$token, 5), collapse = ", ")) else "")

  # --- Topic modeling LDA (topicos) ---
  res$topicos <- tryCatch(topicos_lda(tk, k = k, agrupar = agrupar), error = function(e) { message("Tópicos: ", conditionMessage(e)); NULL })
  if (!is.null(res$topicos))
    .registrar_exp(registrar, dir_bitacoras, metodo = "topic modeling (LDA)", parametros = paste0("periodo=", per$nombre, "; k=", k, "; documentos=", agrupar),
                   n_documentos = res$topicos$n_documentos, tamano_vocabulario = res$topicos$n_terminos,
                   resultado_principal = paste(res$topicos$etiquetas$etiqueta, collapse = " | "))

  # --- Shallow linguistic con udpipe (categorias gramaticales, lemas, frases) ---
  if (shallow) {
    res$shallow <- tryCatch(shallow_linguistic(m, modelo = modelo_udpipe, max_mensajes = max_mensajes_shallow),
                            error = function(e) { message("Shallow: ", conditionMessage(e)); NULL })
    if (!is.null(res$shallow))
      .registrar_exp(registrar, dir_bitacoras, metodo = "shallow linguistic (udpipe)", parametros = paste0("periodo=", per$nombre),
                     n_documentos = res$shallow$n_mensajes, tamano_vocabulario = "",
                     resultado_principal = paste(utils::head(res$shallow$upos$clase, 3), collapse = ", "))
  }
  # --- Sentimientos de la libreria syuzhet (NRC: 8 emociones + polaridad) ---
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
  # --- Registrar experimento de nivel de sentimientos propios ---
  .registrar_exp(registrar, dir_bitacoras, metodo = "nivel de sentimientos (propios)", parametros = paste0("periodo=", per$nombre),
                 n_documentos = nrow(m), resultado_principal = res$interpretacion)
  res$mensajes <- m
  class(res) <- c("analisis_periodo", "list")
  res
}

# ------------------------------------------------------------------------------
# comparar_periodos: compara dos periodos (A vs B) calculando niveles de
# sentimientos, TF-IDF comparativo y, opcionalmente, sentimientos de librería
# para cada uno.
#
# Parametros:
#   datos              : lista salida de cargar_datos_analisis()
#   fecha_inicio_a/b   : fechas de inicio para periodo A y B (opcional)
#   fecha_fin_a/b      : fechas de fin para periodo A y B (opcional)
#   periodoA/periodoB  : nombres de periodos predefinidos (opcional)
#   periodos           : data.frame de periodos
#   libreria           : si ejecutar syuzhet para cada periodo (default TRUE)
#   max_mensajes_libreria: max mensajes para syuzhet (default 5000)
#   registrar          : si registrar experimento en bitacora (default TRUE)
#   dir_bitacoras      : carpeta de bitacoras (default "bitacoras")
#
# Retorna: lista de clase "comparacion_periodos" con:
#   periodos     : lista A y B con nombre, inicio, fin
#   niveles      : data.frame largo con nivel de cada sentimiento por periodo
#   serie        : serie temporal combinada
#   tfidf        : terminos que distinguen A de B
#   interpretacion : frases descriptivas (3 elementos)
#   libreria     : nivel de emociones syuzhet por periodo (si libreria=TRUE)
#   comparacion  : comparacion propio vs libreria por periodo
# ------------------------------------------------------------------------------
comparar_periodos <- function(datos, fecha_inicio_a = NULL, fecha_fin_a = NULL,
                              fecha_inicio_b = NULL, fecha_fin_b = NULL,
                              periodoA = NULL, periodoB = NULL, periodos = cargar_periodos(), libreria = TRUE,
                              max_mensajes_libreria = 5000, registrar = TRUE, dir_bitacoras = "bitacoras") {
  # --- Resolver fechas para periodo A y B ---
  fiA <- .fecha_param(fecha_inicio_a); ffA <- .fecha_param(fecha_fin_a)
  fiB <- .fecha_param(fecha_inicio_b); ffB <- .fecha_param(fecha_fin_b)
  if (!is.null(fiA) || !is.null(ffA) || !is.null(fiB) || !is.null(ffB)) {
    # Rangos explicitados: usar min/max si falta uno de los extremos
    fiA <- fiA %||% as.Date(min(datos$mensajes$fecha, na.rm = TRUE))
    ffA <- ffA %||% as.Date(max(datos$mensajes$fecha, na.rm = TRUE))
    fiB <- fiB %||% as.Date(min(datos$mensajes$fecha, na.rm = TRUE))
    ffB <- ffB %||% as.Date(max(datos$mensajes$fecha, na.rm = TRUE))
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
    # Periodos por nombre desde config/periodos.csv
    lp <- periodos_lista(list(periodoA, periodoB), periodos, datos$mensajes$fecha)
    nA <- names(lp)[1]; nB <- names(lp)[2]
    m <- rbind(filtrar_periodo(datos$mensajes, lp[[1]]), filtrar_periodo(datos$mensajes, lp[[2]]))
    tk <- rbind(filtrar_periodo(datos$tokens, lp[[1]]), filtrar_periodo(datos$tokens, lp[[2]]))
  }
  res <- list(periodos = lp)
  # Niveles de sentimientos por periodo (formato largo)
  res$niveles <- niveles_por_periodo(datos$mensajes, lp)
  # Serie temporal combinada de ambos periodos
  res$serie <- serie_sentimientos(m)
  # TF-IDF comparativo: terminos que distinguen A de B
  res$tfidf <- tryCatch(tfidf_comparar(tk, lp[[1]], lp[[2]]), error = function(e) NULL)
  # Interpretacion descriptiva de la comparacion
  res$interpretacion <- interpretar_comparacion(res$niveles, nA, nB)
  # --- Sentimientos de librería syuzhet para cada periodo (opcional) ---
  if (libreria) {
    lib <- lapply(names(lp), function(nm) tryCatch(
      sentimientos_libreria(filtrar_periodo(datos$mensajes, lp[[nm]]), max_mensajes = max_mensajes_libreria), error = function(e) NULL))
    names(lib) <- names(lp)
    if (all(!vapply(lib, is.null, logical(1)))) {
      res$libreria <- do.call(rbind, lapply(names(lib), function(nm) { x <- nivel_libreria(lib[[nm]]); x$periodo <- nm; x }))
      res$comparacion <- lapply(lib, comparar_con_sin_libreria)
    }
  }
  # Registrar experimento de comparacion de periodos
  .registrar_exp(registrar, dir_bitacoras, metodo = "comparación de periodos", parametros = paste0("A=", nA, "; B=", nB),
                 n_documentos = nrow(m), resultado_principal = res$interpretacion[3])
  class(res) <- c("comparacion_periodos", "list")
  res
}

# ------------------------------------------------------------------------------
# graficos_periodo: genera todos los ggplot disponibles para un analisis de
# periodo (resultado de analizar_periodo). Cada grafico se envuelve en tryCatch
# para que un fallo no detenga a los demas.
#
# Parametros:
#   a : objeto de clase "analisis_periodo" (salida de analizar_periodo)
#   x : nombre del sentimiento para el eje X de dispersion (opcional, default = primer sentimiento)
#   y : nombre del sentimiento para el eje Y de dispersion (opcional, default = segundo sentimiento)
#
# Retorna: lista nombrada con los graficos que se pudieron generar (G01_barras,
# G02_barras_comparar, G03_tiempo, etc. segun lo disponible).
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# graficos_comparacion: genera los ggplot para una comparacion de dos periodos
# (resultado de comparar_periodos).
#
# Parametros:
#   cmp : objeto de clase "comparacion_periodos" (salida de comparar_periodos)
#
# Retorna: lista nombrada con los graficos disponibles (barras, arana, tiempo,
# tfidf, libreria segun lo disponible).
# ------------------------------------------------------------------------------
graficos_comparacion <- function(cmp) {
  tryg <- function(expr) tryCatch(expr, error = function(e) NULL)
  g <- list(barras = tryg(g_barras_comparar(cmp$niveles)), arana = tryg(g_arana(cmp$niveles)),
            tiempo = tryg(g_tiempo(cmp$serie)))
  if (!is.null(cmp$tfidf) && nrow(cmp$tfidf)) g$tfidf <- tryg(g_tfidf(cmp$tfidf, "Palabras que distinguen a cada periodo (TF-IDF)"))
  if (!is.null(cmp$libreria)) g$libreria <- tryg(g_barras_comparar(cmp$libreria[cmp$libreria$tipo == "emocion (8)", ], "Librería (syuzhet): comparación"))
  g[!vapply(g, is.null, logical(1))]
}

# ------------------------------------------------------------------------------
# Helpers de envío a la API del dashboard (Postgres vía Node/Express).
# No se reutiliza r/Peticiones.R porque no es sourceada por cargar_proyecto.R
# y su final auto-ejecuta probar_conexion_api(); estos helpers viven aquí.
# ------------------------------------------------------------------------------

# URL base de la API (env var ANSENT_API_URL).
.api_url <- function() {
  u <- Sys.getenv("ANSENT_API_URL", "")
  if (!nzchar(u)) {
    stop("Define ANSENT_API_URL, por ejemplo http://localhost:3000", call. = FALSE)
  }
  sub("/+$", "", u)
}

# Clave de API (env var ANSENT_API_KEY, debe coincidir con R_API_KEY del servidor).
.api_key <- function() {
  k <- Sys.getenv("ANSENT_API_KEY", "")
  if (!nzchar(k)) {
    stop("Define ANSENT_API_KEY con la clave del servidor (R_API_KEY).", call. = FALSE)
  }
  k
}

# POST JSON con header x-api-key. Requiere httr2 (se instala bajo demanda si falta).
.api_post <- function(path, body, timeout = 60) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    install.packages('httr2')
  }
  req <- httr2::request(paste0(.api_url(), path)) |>
    httr2::req_headers(`x-api-key` = .api_key()) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_method("POST") |>
    httr2::req_timeout(timeout)
  resp <- httr2::req_perform(req)
  if (httr2::resp_status(resp) >= 400) {
    stop(
      "API ", httr2::resp_status(resp), ": ",
      httr2::resp_body_string(resp),
      call. = FALSE
    )
  }
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

# bloque común de periodo para los bodies de envío
.periodo_body <- function(per) {
  list(
    nombre = per$nombre,
    inicio = as.character(per$inicio),
    fin    = as.character(per$fin)
  )
}

# POST de niveles (un periodo): guarda analisis + analisis_nivel.
enviar_niveles_api_equiv <- function(a, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (is.null(a$nivel) || !is.data.frame(a$nivel) || !nrow(a$nivel)) {
    message("Niveles: sin datos para enviar a la API.")
    return(invisible(NULL))
  }
  if (is.null(a$periodo)) {
    message("Niveles: 'a$periodo' no definido; no se envia a la API.")
    return(invisible(NULL))
  }
  niv <- a$nivel[, c("sentimiento", "nivel_pct", "mensajes_pct", "n_mensajes"), drop = FALSE]
  body <- list(
    periodo = .periodo_body(a$periodo),
    n_mensajes  = a$n_mensajes,
    responsable = responsable,
    datos       = niv
  )
  .api_post("/api/dashboard/niveles", body)
}

# POST de serie mensual (un periodo): guarda analisis + analisis_serie_mensual.
enviar_serie_api_equiv <- function(a, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (is.null(a$serie) || !is.data.frame(a$serie) || !nrow(a$serie)) {
    message("Serie: sin datos para enviar a la API.")
    return(invisible(NULL))
  }
  if (is.null(a$periodo)) {
    message("Serie: 'a$periodo' no definido; no se envia a la API.")
    return(invisible(NULL))
  }
  serie <- a$serie[, c("anio_mes", "sentimiento", "pct", "n_mensajes"), drop = FALSE]
  body <- list(
    periodo = .periodo_body(a$periodo),
    n_mensajes  = a$n_mensajes,
    responsable = responsable,
    datos       = serie
  )
  .api_post("/api/dashboard/serie", body)
}

# POST de comparación (dos periodos): guarda analisis/analisis_nivel de ambos
# periodos + cabecera en analisis_comparacion.
enviar_comparacion_api_equiv <- function(cmp, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (!inherits(cmp, "comparacion_periodos")) {
    message("Comparacion: objeto no valido para enviar a la API.")
    return(invisible(NULL))
  }
  if (is.null(cmp$niveles) || !is.data.frame(cmp$niveles) || !nrow(cmp$niveles)) {
    message("Comparacion: sin niveles para enviar a la API.")
    return(invisible(NULL))
  }

  claves    <- names(cmp$periodos)
  etiquetas <- vapply(cmp$periodos, function(p) p$nombre, character(1))

  niveles <- cmp$niveles
  niveles$periodo <- etiquetas[match(niveles$periodo, claves)]

  periodos <- lapply(seq_along(cmp$periodos), function(i) {
    p <- cmp$periodos[[i]]
    n <- unique(niveles$n_mensajes[niveles$periodo == etiquetas[i]])
    list(
      clave      = claves[i],
      nombre     = p$nombre,
      inicio     = as.character(p$inicio),
      fin        = as.character(p$fin),
      n_mensajes = if (length(n)) n[1] else NA
    )
  })

  body <- list(
    nombre      = paste(etiquetas[1], "vs", etiquetas[2]),
    responsable = responsable,
    periodos    = periodos,
    datos       = niveles[, c("sentimiento", "periodo", "nivel_pct",
                              "mensajes_pct", "n_mensajes"), drop = FALSE]
  )
  .api_post("/api/dashboard/comparaciones", body)
}

# ------------------------------------------------------------------------------
# Helpers de envío de los outputs de preprocesar() a la API/BD (Postgres).
# Se usan desde preprocesar() (00_main.R) tras anotar(), envuelto en tryCatch
# para que nunca bloquee los archivos locales ni el retorno.
# ------------------------------------------------------------------------------

# POST de la cabecera de ejecucion de preprocesar(): devuelve id_ejecucion.
enviar_ejecucion_api <- function(meta) {
  if (is.null(meta) || !is.list(meta)) {
    message("Ejecucion: sin metadatos para enviar a la API.")
    return(invisible(NULL))
  }
  body <- list(
    fecha = meta$fecha %||% format(Sys.time(), "%Y-%m-%d"),
    hora_inicio = meta$hora_inicio %||% format(Sys.time(), "%H:%M:%S"),
    hora_fin = meta$hora_fin %||% format(Sys.time(), "%H:%M:%S"),
    duracion_seg = meta$duracion_seg,
    responsable = meta$responsable %||% Sys.getenv("RESPONSABLE", ""),
    archivo = meta$archivo %||% "",
    archivo_md5 = meta$archivo_md5 %||% "",
    registros_leidos = meta$registros_leidos,
    mensajes_limpios = meta$mensajes_limpios,
    mensajes_excluidos = meta$mensajes_excluidos,
    rango_fechas_inicio = meta$rango_fechas_inicio,
    rango_fechas_fin = meta$rango_fechas_fin,
    polaridad = meta$polaridad,
    estado = meta$estado %||% "ok",
    paso_donde_paro = meta$paso_donde_paro %||% "",
    mensaje_error = meta$mensaje_error %||% "",
    pasos_registrados = meta$pasos_registrados)
  resp <- tryCatch(.api_post("/api/preprocesar/ejecuciones", body), error = function(e) NULL)
  if (is.null(resp)) return(invisible(NULL))
  invisible(resp$id_ejecucion %||% NULL)
}

# POST de un output de preprocesar() (DELETE WHERE id_ejecucion + INSERT masivo).
# `datos` puede ser un data.frame o una lista (para el resumen, una fila).
enviar_output_api <- function(endpoint, id_ejecucion, datos) {
  if (is.null(id_ejecucion) || is.na(id_ejecucion)) {
    message(sprintf("%s: sin id_ejecucion; no se envia a la API.", endpoint))
    return(invisible(NULL))
  }
  if (is.data.frame(datos)) {
    if (!nrow(datos)) {
      message(sprintf("%s: sin filas para enviar a la API.", endpoint))
      return(invisible(NULL))
    }
    filas <- lapply(seq_len(nrow(datos)), function(i) as.list(datos[i, , drop = FALSE]))
  } else if (is.list(datos)) {
    filas <- list(datos)
  } else {
    message(sprintf("%s: datos no validos para enviar a la API.", endpoint))
    return(invisible(NULL))
  }
  filas <- lapply(filas, function(f) {
    lapply(f, function(v) {
      if (length(v) == 0 || all(is.na(v))) return(NULL)
      v <- if (is.atomic(v) && length(v) == 1) v[[1]] else v
      if (inherits(v, c("Date", "POSIXct", "POSIXlt", "POSIXt"))) return(format(v))
      if (is.factor(v)) return(as.character(v))
      if (is.list(v) && !is.data.frame(v)) return(jsonlite::toJSON(v, auto_unbox = TRUE))
      if (is.data.frame(v)) return(jsonlite::toJSON(v, auto_unbox = TRUE))
      v
    })
  })
  body <- list(id_ejecucion = id_ejecucion, datos = filas)
  tryCatch(
    .api_post(sprintf("/api/preprocesar/%s", endpoint), body),
    error = function(e) {
      message(sprintf("%s: no se pudieron enviar los datos a la API: %s", endpoint, conditionMessage(e)))
      invisible(NULL)
    }
  )
}

# ------------------------------------------------------------------------------
# guardar_analisis: guarda las tablas (CSV) y los graficos (PNG) de un analisis
# en salida/analisis/<nombre_periodo>/ para que el dashboard los pueda leer.
#
# Parametros:
#   a         : objeto "analisis_periodo" o "comparacion_periodos"
#   dir       : carpeta base de salida (default "salida/analisis")
#   graficos  : si TRUE, tambien guarda los PNG de los graficos (default TRUE)
#   enviar_api: si TRUE, envia niveles/serie (o comparacion) a la API->BD
#               envuelto en tryCatch (best-effort, default TRUE)
#   responsable: quien ejecuta el analisis (default Sys.getenv("RESPONSABLE", "R local"))
#
# Retorna: ruta del directorio creado (invisible).
#
# Archivos generados para analisis de periodo:
#   niveles.csv, serie_mensual.csv, tfidf.csv, libreria_niveles.csv,
#   topicos_terminos.csv, topicos_por_mes.csv, topicos_por_documento.csv,
#   shallow_categorias.csv, shallow_lemas.csv, shallow_frases_nominales.csv,
#   stopwords_eliminadas.csv, stopwords_conservadas.csv, interpretacion.txt
#   y PNG: G01_barras.png ... G25_diferencia.png (según lo disponible)
#
# Archivos generados para comparacion de periodos:
#   niveles.csv, serie_mensual.csv, tfidf.csv, libreria_niveles.csv,
#   interpretacion.txt y PNG de comparacion.
# ------------------------------------------------------------------------------
# Deja las tablas (CSV) y los graficos (PNG) listos para que el dashboard los lea
guardar_analisis <- function(a, dir = "salida/analisis", graficos = FALSE,
                             enviar_api = TRUE, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  # Nombre del directorio de salida basado en el periodo(s)
  nom <- if (inherits(a, "comparacion_periodos")) paste(a$periodos[[1]]$nombre, a$periodos[[2]]$nombre, sep = " vs ") else a$periodo$nombre
  d <- file.path(dir, gsub("[^A-Za-z0-9_-]+", "_", nom)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  # Helper local: escribir CSV si el objeto es data.frame con filas
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
  # Guardar cada grafico como PNG con ggsave
  for (nm in names(gr)) try(.gg()$ggsave(file.path(d, paste0(nm, ".png")), gr[[nm]], width = 9, height = 6, dpi = 120), silent = TRUE)

  # Envío a API/BD (best-effort: nunca bloquea el guardado local ni el retorno)
  if (isTRUE(enviar_api)) {
    tryCatch({
      if (inherits(a, "comparacion_periodos")) {
        enviar_comparacion_api_equiv(a, responsable = responsable)
      } else {
        enviar_niveles_api_equiv(a, responsable = responsable)
        enviar_serie_api_equiv(a, responsable = responsable)
      }
    }, error = function(e) {
      message("No se pudieron enviar los datos a la API/BD: ", conditionMessage(e))
    })
  }

  message("Analisis guardado en ", d)
  invisible(d)
}


