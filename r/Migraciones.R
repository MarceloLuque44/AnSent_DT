# ==============================================================================
# r/Migraciones.R  -  Migración única de diccionarios locales a PostgreSQL
# ------------------------------------------------------------------------------
# Lee los 8 diccionarios de r/config/ y los sube via POST a
#   /api/diccionarios/:tipo  (cabecera x-api-key)
#
# Requisitos:
#   - ANSENT_API_URL y ANSENT_API_KEY definidos (ver Peticiones.R)
#   - Tablas de Esquema6.sql ya creadas en PostgreSQL
#   - Backend Express levantado en ANSENT_API_URL
#
# Uso:
#   source("cargar_proyecto.R")
#   source("Migraciones.R")
#   migrar_diccionarios(dir_config = "config")
# ==============================================================================

if (!requireNamespace("httr2", quietly = TRUE)) {
  install.packages('httr2')
}
if (!requireNamespace("readr", quietly = TRUE)) {
  install.packages('readr')
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages('jsonlite')
}

api_url <- function() {
  u <- Sys.getenv("ANSENT_API_URL", "")
  if (!nzchar(u)) stop("Define ANSENT_API_URL (p.ej. http://localhost:3000)", call. = FALSE)
  sub("/+$", "", u)
}

api_key <- function() {
  k <- Sys.getenv("ANSENT_API_KEY", "")
  if (!nzchar(k)) stop("Define ANSENT_API_KEY", call. = FALSE)
  k
}

api_perform <- function(req) {
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      stop("No se pudo conectar con la API: ", conditionMessage(e), call. = FALSE)
    }
  )
  if (httr2::resp_status(resp) >= 400) {
    stop("API ", httr2::resp_status(resp), ": ",
         httr2::resp_body_string(resp), call. = FALSE)
  }
  resp
}

# POST /api/diccionarios/:tipo  (requiere x-api-key)
post_diccionario <- function(tipo, fila, timeout = 30) {
  req <- httr2::request(paste0(api_url(), "/api/diccionarios/", tipo)) |>
    httr2::req_headers(`x-api-key` = api_key()) |>
    httr2::req_body_json(fila, auto_unbox = TRUE) |>
    httr2::req_method("POST") |>
    httr2::req_timeout(timeout)
  resp <- api_perform(req)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

# Normaliza un valor: NA/NULL -> NULL para JSON
limpia <- function(x) {
  if (is.null(x)) return(NULL)
  if (length(x) == 0) return(NULL)
  if (is.na(x)) return(NULL)
  as.character(x)
}

# Convierte columnas numericas; deja texto como esta
as_num <- function(x) suppressWarnings(as.numeric(x))

migra_sentimientos <- function(dir_config) {
  cat("[Migraciones] sentimientos ...\n")
  j <- jsonlite::fromJSON(file.path(dir_config, "sentimientos.json"), simplifyVector = TRUE)$sentimientos
  for (i in seq_len(nrow(j))) {
    fila <- list(
      orden = as_num(j$orden[i]),
      nombre = limpia(j$nombre[i]),
      polaridad = as_num(j$polaridad[i]),
      activo = if (is.null(j$activo[i]) || is.na(j$activo[i])) TRUE else as.logical(j$activo[i]),
      definicion = limpia(j$definicion[i]),
      palabras = if (is.null(j$palabras[[i]]) || length(j$palabras[[i]]) == 0) NULL else j$palabras[[i]],
      raices = if (is.null(j$raices[[i]]) || length(j$raices[[i]]) == 0) NULL else j$raices[[i]]
    )
    r <- tryCatch(post_diccionario("sentimientos", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", j$nombre[i], "\n")
    }
  }
}

migra_emojis <- function(dir_config) {
  cat("[Migraciones] emojis ...\n")
  d <- readr::read_csv(file.path(dir_config, "emojis.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      emoji = limpia(d$emoji[i]),
      significado_es = limpia(d$significado_es[i]),
      sentimiento = limpia(d$sentimiento[i]),
      polaridad = as_num(d$polaridad[i]),
      nombre_unicode = limpia(d$nombre_unicode[i])
    )
    r <- tryCatch(post_diccionario("emojis", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$emoji[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$emoji[i], "\n")
    }
  }
}

migra_stopwords <- function(dir_config) {
  cat("[Migraciones] stopwords ...\n")
  d <- readr::read_csv(file.path(dir_config, "stopwords.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      palabra = limpia(d$palabra[i]),
      accion = limpia(d$accion[i]),
      categoria = limpia(d$categoria[i]),
      justificacion = limpia(d$justificacion[i])
    )
    r <- tryCatch(post_diccionario("stopwords", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$palabra[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$palabra[i], "\n")
    }
  }
}

migra_palabras_anuncio <- function(dir_config) {
  cat("[Migraciones] palabras_anuncio ...\n")
  d <- readr::read_csv(file.path(dir_config, "palabras_anuncio.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      tipo = limpia(d$tipo[i]),
      patron = limpia(d$patron[i]),
      peso = as_num(d$peso[i]),
      parametro = limpia(d$parametro[i]),
      categoria = limpia(d$categoria[i]),
      justificacion = limpia(d$justificacion[i])
    )
    r <- tryCatch(post_diccionario("palabras_anuncio", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$patron[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$patron[i], "\n")
    }
  }
}

migra_genero <- function(dir_config) {
  cat("[Migraciones] genero ...\n")
  d <- readr::read_csv(file.path(dir_config, "genero.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      palabra = limpia(d$palabra[i]),
      genero = limpia(d$genero[i]),
      tipo = limpia(d$tipo[i]),
      justificacion = limpia(d$justificacion[i])
    )
    r <- tryCatch(post_diccionario("genero", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$palabra[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$palabra[i], "\n")
    }
  }
}

migra_abreviaturas <- function(dir_config) {
  cat("[Migraciones] abreviaturas ...\n")
  d <- readr::read_csv(file.path(dir_config, "abreviaturas.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      abreviatura = limpia(d$abreviatura[i]),
      normal = limpia(d$normal[i]),
      categoria = limpia(d$categoria[i]),
      justificacion = limpia(d$justificacion[i])
    )
    r <- tryCatch(post_diccionario("abreviaturas", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$abreviatura[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$abreviatura[i], "\n")
    }
  }
}

migra_emoticonos <- function(dir_config) {
  cat("[Migraciones] emoticonos ...\n")
  d <- readr::read_csv(file.path(dir_config, "emoticonos.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(
      emoticono = limpia(d$emoticono[i]),
      emoji = limpia(d$emoji[i]),
      justificacion = limpia(d$justificacion[i])
    )
    r <- tryCatch(post_diccionario("emoticonos", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$emoticono[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$emoticono[i], "\n")
    }
  }
}

migra_codigos_materia <- function(dir_config) {
  cat("[Migraciones] codigos_materia ...\n")
  d <- readr::read_csv(file.path(dir_config, "codigos_materia.csv"),
                       col_types = readr::cols(.default = "c"),
                       progress = FALSE, na = character())
  for (i in seq_len(nrow(d))) {
    fila <- list(prefijo = limpia(d$prefijo[i]))
    r <- tryCatch(post_diccionario("codigos_materia", fila), error = function(e) e)
    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", d$prefijo[i], ":", conditionMessage(r), "\n")
    } else {
      cat("  OK fila", i, ":", d$prefijo[i], "\n")
    }
  }
}

# Ejecuta todas las migraciones de diccionarios.
migrar_diccionarios <- function(dir_config = "config") {
  if (!dir.exists(dir_config)) stop("No existe la carpeta '", dir_config, "'", call. = FALSE)
  cat("[Migraciones] Iniciando migracion de diccionarios desde '", dir_config, "'\n", sep = "")
  migra_sentimientos(dir_config)
  migra_emojis(dir_config)
  migra_stopwords(dir_config)
  migra_palabras_anuncio(dir_config)
  migra_genero(dir_config)
  migra_abreviaturas(dir_config)
  migra_emoticonos(dir_config)
  migra_codigos_materia(dir_config)
  cat("[Migraciones] Migracion de diccionarios terminada.\n")
  invisible(TRUE)
}

# Nota: r/bitacoras/ contiene bitacora_completa.xlsx, bitacora_limpia.xlsx y
# _copia_de_control.json. Los endpoints creados en este plan solo cubren
# /api/diccionarios/:tipo. Para migrar bitacoras faltaria definir endpoints
# dedicados (p.ej. /api/bitacoras) antes de subir esos archivos.
