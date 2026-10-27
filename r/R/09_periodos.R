# ==============================================================================
# 09_periodos.R  -  PARTE 2 (análisis): cargar los datos limpios, elegir periodos y calcular el NIVEL de cada sentimiento.
# ------------------------------------------------------------------------------
# Idea clave: el preprocesamiento se corre UNA vez con TODO el dataset. Aquí solo se
# FILTRA por fechas (verano 2023, mayo-agosto 2024, etc.), así no hay que reprocesar.
#
#   datos <- cargar_datos_analisis("salida")
#   per   <- resolver_periodo(c("2023-01-01", "2023-03-31"), fechas = datos$mensajes$fecha)
#   nivel_sentimiento(filtrar_periodo(datos$mensajes, per))
# ==============================================================================

# Verifica que los paquetes necesarios estén instalados (mensaje claro si faltan)
.requiere <- function(pkgs) {
  faltan <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan))
    stop("Falta instalar: install.packages(c(", paste0('"', faltan, '"', collapse = ", "), "))", call. = FALSE)
  invisible(TRUE)
}

# ---- Datos --------------------------------------------------------------------
cargar_datos_analisis <- function(dir_salida = "salida") {
  fm <- file.path(dir_salida, "mensajes_limpios.csv")
  ft <- file.path(dir_salida, "tokens.csv")
  if (!file.exists(fm)) stop("No existe ", fm, ". Corre primero preprocesar().", call. = FALSE)
  m <- readr::read_csv(fm, show_col_types = FALSE, progress = FALSE, guess_max = 100000)
  m$fecha <- as.Date(m$fecha)
  tk <- NULL
  if (file.exists(ft)) {
    tk <- readr::read_csv(ft, show_col_types = FALSE, progress = FALSE, guess_max = 100000)
    tk$fecha <- as.Date(tk$fecha)
  }
  list(mensajes = m, tokens = tk)
}

# ---- Periodos -----------------------------------------------------------------
# config/periodos.csv  (columnas: nombre, inicio, fin)  -> se edita sin tocar código
cargar_periodos <- function(f = "config/periodos.csv") {
  if (!file.exists(f)) return(data.frame(nombre = character(), inicio = character(), fin = character()))
  readr::read_csv(f, col_types = readr::cols(.default = "c"), show_col_types = FALSE, progress = FALSE)
}

# periodo puede ser: NULL (todo el dataset) | un nombre de periodos.csv |
#                    c("2023-01-01", "2023-03-31") | list(nombre=, inicio=, fin=)
resolver_periodo <- function(periodo = NULL, periodos = cargar_periodos(), fechas = NULL) {
  if (is.null(periodo)) {
    if (is.null(fechas)) stop("Para usar todo el dataset indica fechas = datos$mensajes$fecha", call. = FALSE)
    r <- range(fechas, na.rm = TRUE)
    return(list(nombre = "todo el dataset", inicio = r[1], fin = r[2]))
  }
  if (is.list(periodo) && !is.null(periodo$inicio))
    return(list(nombre = periodo$nombre %||% "periodo", inicio = as.Date(periodo$inicio), fin = as.Date(periodo$fin)))
  if (is.character(periodo) && length(periodo) == 1) {
    i <- match(periodo, periodos$nombre)
    if (is.na(i)) stop("El periodo '", periodo, "' no está en config/periodos.csv", call. = FALSE)
    return(list(nombre = periodo, inicio = as.Date(periodos$inicio[i]), fin = as.Date(periodos$fin[i])))
  }
  if (length(periodo) == 2)
    return(list(nombre = paste(periodo[1], "a", periodo[2]), inicio = as.Date(periodo[1]), fin = as.Date(periodo[2])))
  stop("No entiendo el periodo. Usa NULL, un nombre, o c('inicio', 'fin').", call. = FALSE)
}

# Varios periodos a la vez -> lista con nombre (para comparar A contra B)
periodos_lista <- function(x, periodos = cargar_periodos(), fechas = NULL) {
  out <- lapply(x, resolver_periodo, periodos = periodos, fechas = fechas)
  names(out) <- vapply(out, function(p) p$nombre, character(1))
  out
}

filtrar_periodo <- function(x, per) {
  if (is.null(x)) return(NULL)
  x[!is.na(x$fecha) & x$fecha >= per$inicio & x$fecha <= per$fin, , drop = FALSE]
}

# ---- Nivel del sentimiento ----------------------------------------------------
# Los nombres se leen de las columnas pct_* (así funciona con 15, con 12 o con otros nombres)
nombres_sentimientos <- function(m) sub("^pct_", "", grep("^pct_", names(m), value = TRUE))


# nivel_pct    = promedio de pct_<sentimiento> (cada mensaje: 100 * coincidencias / n_tokens)
# mensajes_pct = % de mensajes que tienen al menos una coincidencia de ese sentimiento
nivel_sentimiento <- function(m) {
  nom <- nombres_sentimientos(m)
  if (!nrow(m) || !length(nom))
    return(data.frame(sentimiento = character(), nivel_pct = numeric(), mensajes_pct = numeric(),
                      n_mensajes = integer(), stringsAsFactors = FALSE))
  data.frame(
    sentimiento  = nom,
    nivel_pct    = unname(vapply(nom, function(s) mean(m[[paste0("pct_", s)]], na.rm = TRUE), numeric(1))),
    mensajes_pct = unname(vapply(nom, function(s) 100 * mean(m[[paste0("sent_", s)]] > 0, na.rm = TRUE), numeric(1))),
    n_mensajes   = nrow(m), stringsAsFactors = FALSE)
}

# Mismo cálculo para varios periodos (formato largo: periodo, sentimiento, nivel_pct, ...)
niveles_por_periodo <- function(m, periodos) {
  partes <- lapply(names(periodos), function(nm) {
    x <- nivel_sentimiento(filtrar_periodo(m, periodos[[nm]]))
    if (nrow(x)) { x$periodo <- nm; x } else NULL
  })
  do.call(rbind, partes)
}

# Evolución mensual de cada sentimiento (para gráficos de tiempo)
serie_sentimientos <- function(m) {
  nom <- nombres_sentimientos(m)
  if (!nrow(m) || !length(nom)) return(NULL)
  n <- table(m$anio_mes)
  partes <- lapply(nom, function(s) {
    a <- tapply(m[[paste0("pct_", s)]], m$anio_mes, mean, na.rm = TRUE)
    data.frame(anio_mes = names(a), sentimiento = s, pct = as.numeric(a),
               n_mensajes = as.integer(n[names(a)]), stringsAsFactors = FALSE)
  })
  do.call(rbind, partes)
}

# "Este mensaje es 8 % alegría y la temporada es 7 %": un mensaje frente a su periodo
nivel_mensaje <- function(fila, m_periodo) {
  nom <- nombres_sentimientos(fila)
  data.frame(
    sentimiento = nom,
    mensaje_pct = unname(vapply(nom, function(s) as.numeric(fila[[paste0("pct_", s)]][1]), numeric(1))),
    periodo_pct = unname(vapply(nom, function(s) mean(m_periodo[[paste0("pct_", s)]], na.rm = TRUE), numeric(1))),
    stringsAsFactors = FALSE)
}

# ---- Justificación teórica (config/justificaciones_analisis.csv) ---------------
justificaciones_analisis <- function(f = "config/justificaciones_analisis.csv") {
  if (!file.exists(f)) stop("No existe ", f, call. = FALSE)
  readr::read_csv(f, show_col_types = FALSE, progress = FALSE)
}
justificacion <- function(id) {
  j <- justificaciones_analisis()
  j[j$id == id, , drop = FALSE]
}

# Importan para el sentimiento (negaciones), pero ensucian TF-IDF y los tópicos no nos ayudan a encontrar la temática por lo que son excluidos
PALABRAS_SIN_TEMA <- c("no", "ni", "nunca", "tampoco", "jamas", "nada", "sin", "muy", "mas")
