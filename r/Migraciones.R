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

if (!requireNamespace("readr", quietly = TRUE)) {
  install.packages('readr')
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages('jsonlite')
}

# Funciones de conexión a la API: se proveen desde r/Peticiones.R
source("Peticiones.R")



migra_sentimientos <- function(dir_config) {
  cat("[Migraciones] sentimientos ...\n")
  # simplifyVector = FALSE evita que jsonlite convierta palabras/raices en
  # data.frames o escalares cuando tienen distinta longitud o un solo elemento.
  j <- jsonlite::fromJSON(file.path(dir_config, "sentimientos.json"),
                          simplifyVector = FALSE)$sentimientos

  existentes <- tryCatch(
    get_diccionario("sentimientos"),
    error = function(e) {
      cat("  AVISO: no se pudieron leer los sentimientos existentes: ",
          conditionMessage(e), "\n", sep = "")
      list()
    }
  )
  ids <- integer(0)
  if (length(existentes)) {
    ids <- vapply(existentes, function(x) as.integer(x$id), integer(1))
    names(ids) <- vapply(existentes, function(x) as.character(x$nombre), character(1))
  }

  nuevos <- 0L; actualizados <- 0L; errores <- 0L
  for (i in seq_along(j)) {
    s <- j[[i]]
    fila <- list(
      orden = num_o_null(s$orden),
      nombre = limpia(s$nombre),
      polaridad = num_o_null(s$polaridad),
      activo = logico_o_null(s$activo, default = TRUE),
      definicion = limpia(s$definicion),
      palabras = como_array(s$palabras),
      raices = como_array(s$raices)
    )

    if (is.null(fila$nombre) || is.null(fila$polaridad)) {
      cat("  ERROR fila", i, ": 'nombre' y 'polaridad' son obligatorios\n")
      errores <- errores + 1L
      next
    }

    pos <- match(fila$nombre, names(ids))
    id <- if (!is.na(pos)) ids[[pos]] else NULL
    r <- tryCatch(
      {
        if (is.null(id)) {
          post_diccionario("sentimientos", fila)
          "nuevo"
        } else {
          put_diccionario("sentimientos", id, fila)
          "actualizado"
        }
      },
      error = function(e) e
    )

    if (inherits(r, "error")) {
      cat("  ERROR fila", i, ":", fila$nombre, ":", conditionMessage(r), "\n")
      errores <- errores + 1L
    } else if (identical(r, "actualizado")) {
      cat("  OK (actualizado) fila", i, ":", fila$nombre, "\n")
      actualizados <- actualizados + 1L
    } else {
      cat("  OK fila", i, ":", fila$nombre, "\n")
      nuevos <- nuevos + 1L
    }
  }
  cat(sprintf("[Migraciones] sentimientos: %d nuevos, %d actualizados, %d errores\n",
              nuevos, actualizados, errores))
  invisible(errores == 0L)
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
