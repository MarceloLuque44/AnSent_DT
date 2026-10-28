# plumber_api.R — API de Plumber para el proyecto de análisis de sentimientos
# Iniciar:   Rscript r/plumber_api.R   (desde la raíz del proyecto)
#            Rscript plumber_api.R      (desde la carpeta r/)
# Puerto:    8765
#
# Este script:
#   1. Valida que los paquetes R requeridos estén instalados.
#   2. Carga las utilidades del proyecto (cargar_proyecto.R + 00_main.R + 16_analisis.R).
#   3. Expone endpoints REST: /__ping__, /dataset/summary, /charts, /preprocesar.
#   4. Agrega endpoints para los 4 pasos de ejecucion (docs/analisis_codigo_r.md, seccion 5, Opcion A):
#      POST /paso/preprocesar      — Paso 1: preprocesamiento completo
#      POST /paso/analizar-periodo — Paso 2: analisis por periodo
#      POST /paso/comparar-periodos— Paso 3: comparacion de dos periodos
#      POST /paso/analizar-oracion — Paso 4: analisis de una sola oracion
#   5. Notifica a Express (puerto 3000) al terminar un preprocesamiento.
#   6. Cada endpoint de paso devuelve las rutas en memoria de los archivos generados
#      para que el frontend los pueda renderizar como imagenes.

# ------------------------------------------------------------------------------
# 0. Validar paquetes requeridos
# ------------------------------------------------------------------------------
paquetes <- c("plumber", "jsonlite", "httr")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) {
  cat("\n====================================================================\n")
  cat("ERROR: Faltan paquetes R requeridos para Plumber:\n")
  cat("  ", paste(faltan, collapse = ", "), "\n")
  cat("Instalalos con:\n")
  cat("  install.packages(c(", paste0('"', faltan, '"', collapse = ", "), "))\n")
  cat("====================================================================\n\n")
  quit(status = 1)
}

library(plumber)
library(jsonlite)
library(httr)

# Filtro CORS para permitir peticiones desde el frontend (Vite en puerto 5173)
cors_filter <- function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    res$body <- ""
    return(res)
  }
  plumber::forward()
}

cat("[Plumber] Paquetes R cargados: plumber, jsonlite, httr\n")

# ------------------------------------------------------------------------------
# 1. Determinar la carpeta del proyecto R (r/)
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  script_path <- sub("^--file=", "", file_arg)
  SCRIPT_DIR <- dirname(normalizePath(script_path, winslash = "/"))
} else {
  SCRIPT_DIR <- normalizePath(getwd(), winslash = "/")
}
PROYECTO <- SCRIPT_DIR

# Carpeta de salida para los graficos del analisis (solo pasos 2 y 3 y dashboard):
# sube un nivel desde r/ y agrega client/src/views/salida/analisis.
# El resto de archivos exportados se queda en r/salida/ — no se modifica.
SALIDA_FRONT <- file.path(dirname(SCRIPT_DIR), "client", "src", "views", "salida")
SALIDA_ANALISIS <- file.path(SALIDA_FRONT, "analisis")

cat("[Plumber] Carpeta del proyecto R:", PROYECTO, "\n")
cat("[Plumber] Carpeta de salida del analisis:", SALIDA_ANALISIS, "\n")

# ------------------------------------------------------------------------------
# 2. Cargar utilidades del proyecto
# ------------------------------------------------------------------------------
cat("[Plumber] Cargando cargar_proyecto.R...\n")
tryCatch(
  source(file.path(PROYECTO, "cargar_proyecto.R"), encoding = "UTF-8"),
  error = function(e) {
    cat("\n====================================================================\n")
    cat("ERROR al cargar cargar_proyecto.R:\n")
    cat("  ", conditionMessage(e), "\n")
    cat("Verifica que exista:", file.path(PROYECTO, "cargar_proyecto.R"), "\n")
    cat("====================================================================\n\n")
    quit(status = 1)
  }
)
cat("[Plumber] cargar_proyecto.R cargado correctamente\n")

cat("[Plumber] Cargando 00_main.R...\n")
tryCatch(
  source(file.path(PROYECTO, "R", "00_main.R"), encoding = "UTF-8"),
  error = function(e) {
    cat("\n====================================================================\n")
    cat("ERROR al cargar 00_main.R:\n")
    cat("  ", conditionMessage(e), "\n")
    cat("Verifica que exista:", file.path(PROYECTO, "R", "00_main.R"), "\n")
    cat("====================================================================\n\n")
    quit(status = 1)
  }
)
cat("[Plumber] 00_main.R cargado correctamente. Funcion preprocesar() disponible\n")

cat("[Plumber] Cargando graficos.R...\n")
tryCatch(
  source(file.path(PROYECTO, "graficos.R"), encoding = "UTF-8"),
  error = function(e) {
    cat("\n====================================================================\n")
    cat("ERROR al cargar graficos.R:\n")
    cat("  ", conditionMessage(e), "\n")
    cat("Verifica que exista:", file.path(PROYECTO, "graficos.R"), "\n")
    cat("====================================================================\n\n")
    quit(status = 1)
  }
)
cat("[Plumber] graficos.R cargado correctamente. Funcion generar_graficos() disponible\n")

cat("[Plumber] Cargando 16_analisis.R...\n")
tryCatch(
  source(file.path(PROYECTO, "R", "16_analisis.R"), encoding = "UTF-8"),
  error = function(e) {
    cat("\n====================================================================\n")
    cat("ERROR al cargar 16_analisis.R:\n")
    cat("  ", conditionMessage(e), "\n")
    cat("Verifica que exista:", file.path(PROYECTO, "R", "16_analisis.R"), "\n")
    cat("====================================================================\n\n")
    quit(status = 1)
  }
)
cat("[Plumber] 16_analisis.R cargado correctamente. Funciones de analisis disponibles\n")

# ------------------------------------------------------------------------------
# 3. Estado global en memoria
# ------------------------------------------------------------------------------
state <- new.env(parent = emptyenv())
state$dataset <- NULL
state$version <- 0
state$iniciado <- Sys.time()

EXPRESS <- "http://localhost:3000"

# ------------------------------------------------------------------------------
# 4. Utilidad: POST JSON a Express (bitacora / SSE)
# ------------------------------------------------------------------------------
POST_JSON <- function(path, objeto, timeout_sec = 5) {
  tryCatch(
    {
      httr::POST(
        url = paste0(EXPRESS, path),
        body = jsonlite::toJSON(objeto, auto_unbox = TRUE, na = "null"),
        encode = "json",
        httr::timeout(seconds = timeout_sec)
      )
      cat("[Plumber] Notificado a Express:", path, "\n")
    },
    error = function(e) {
      cat("[Plumber] AVISO: no se pudo notificar a Express", path, ":", conditionMessage(e), "\n")
    }
  )
}

# ------------------------------------------------------------------------------
# 5. Endpoints de la API
# ------------------------------------------------------------------------------

#* Ping de salud
#* @get /__ping__
function() {
  list(
    ok = TRUE,
    ts = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    version = state$version,
    iniciado = format(state$iniciado, "%Y-%m-%d %H:%M:%S")
  )
}

#* Cargar dataset inicial (si no está en memoria)
cargar_dataset <- function() {
  if (is.null(state$dataset)) {
    cat("[Plumber] Cargando dataset inicial...\n")
    ruta <- file.path(PROYECTO, "data", "result.json")
    cat("[Plumber] Ruta del dataset:", ruta, "\n")
    if (file.exists(ruta)) {
      cat("[Plumber] Leyendo dataset:", ruta, "\n")
      state$dataset <- leer_entrada(ruta)
      cat("[Plumber] Dataset cargado desde:", ruta, "con", nrow(state$dataset), "filas y", ncol(state$dataset), "columnas\n")
      cat("[Plumber] Columnas del dataset:", paste(names(state$dataset), collapse = ", "), "\n")
    } else {
      cat("[Plumber] AVISO: no se encontro", ruta, ". Usando dataset de ejemplo en memoria.\n")
      state$dataset <- data.frame(
        id_mensaje = 1:5,
        fecha_raw = format(Sys.Date() - 0:4),
        autor_raw = c("a", "b", "c", "d", "e"),
        texto_raw = c("me encanta", "horrible servicio", "regular", "excelente", "malo"),
        tipo_contenido = "texto",
        stringsAsFactors = FALSE
      )
      cat("[Plumber] Dataset de ejemplo creado con", nrow(state$dataset), "filas y", ncol(state$dataset), "columnas\n")
      cat("[Plumber] Columnas del dataset ejemplo:", paste(names(state$dataset), collapse = ", "), "\n")
    }
  } else {
    cat("[Plumber] Usando dataset ya cargado en memoria:", nrow(state$dataset), "filas\n")
  }
  state$dataset
}

#* Resumen del dataset
#* @get /dataset/summary
function() {
  tryCatch(
    {
      ruta <- file.path(PROYECTO, "data", "result.json")
      cat("[Plumber] /dataset/summary: usando dataset desde", ruta, "\n")
      df <- cargar_dataset()
      cat("[Plumber] /dataset/summary: dataset tiene", nrow(df), "filas y", ncol(df), "columnas\n")
      list(
        filas = nrow(df),
        columnas = ncol(df),
        nombres_columnas = names(df),
        version = state$version
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en /dataset/summary:", conditionMessage(e), "\n")
      list(error = conditionMessage(e))
    }
  )
}

# ------------------------------------------------------------------------------
# 6. Endpoints de los 4 pasos de ejecucion (docs/analisis_codigo_r.md, seccion 5, Opcion A)
# ------------------------------------------------------------------------------

# Helper: listar archivos de salida generados por un paso
.listar_salidas <- function(dir_base, extra_dirs = character()) {
  archivos <- list()
  if (dir.exists(dir_base)) {
    for (f in list.files(dir_base, full.names = TRUE, recursive = FALSE)) {
      archivos[[length(archivos) + 1]] <- list(
        nombre = basename(f),
        ruta = f,
        tipo = tools::file_ext(f)
      )
    }
  }
  for (d in extra_dirs) {
    if (dir.exists(d)) {
      for (f in list.files(d, full.names = TRUE, recursive = TRUE)) {
        archivos[[length(archivos) + 1]] <- list(
          nombre = basename(f),
          ruta = f,
          tipo = tools::file_ext(f),
          carpeta = basename(dirname(f))
        )
      }
    }
  }
  archivos
}

# Helper: agrupar imagenes (PNG) de salida y client/src/views/salida/analisis por nombre de carpeta
.agrupar_imagenes <- function() {
  grupos <- list()
  salida_dir <- SALIDA_FRONT
  carpetas <- c(
    salida_dir,
    file.path(salida_dir, "analisis")
  )
  for (base in carpetas) {
    if (!dir.exists(base)) next
    for (f in list.files(base, full.names = TRUE, recursive = TRUE)) {
      if (!file.info(f)$isdir && tolower(tools::file_ext(f)) == "png") {
        # Ruta relativa a salida/ para servir via /archivos/*
        rel_full <- normalizePath(f, winslash = "/")
        ruta_rel <- sub(paste0("^", normalizePath(salida_dir, winslash = "/"), "/"), "", rel_full)
        carpeta <- basename(dirname(f))
        if (is.null(grupos[[carpeta]])) {
          grupos[[carpeta]] <- list(
            nombre_carpeta = carpeta,
            imagenes = list()
          )
        }
        grupos[[carpeta]]$imagenes[[length(grupos[[carpeta]]$imagenes) + 1]] <- list(
          nombre = basename(f),
          ruta = ruta_rel,
          tipo = "png"
        )
      }
    }
  }
  grupos
}

# Helper: normalizar ruta para el frontend (usar barras adelante)
.ruta_frontend <- function(ruta) {
  chartr("\\", "/", normalizePath(ruta, winslash = "/"))
}

# Helper: listar solo archivos (sin carpetas ni subcarpetas) de r/salida/
.listar_archivos_salida <- function() {
  salida_dir <- file.path(PROYECTO, "salida")
  if (!dir.exists(salida_dir)) {
    return(list())
  }
  archivos <- list()
  for (f in list.files(salida_dir, full.names = TRUE, recursive = FALSE)) {
    if (file.exists(f) && !file.info(f)$isdir) {
      archivos[[length(archivos) + 1]] <- list(
        nombre = basename(f),
        ruta = .ruta_frontend(f),
        tipo = tools::file_ext(f),
        tamano_bytes = as.integer(file.info(f)$size),
        modificado = format(file.info(f)$mtime, format = "%Y-%m-%d %H:%M:%S")
      )
    }
  }
  archivos
}

# Maximo de filas por pagina en el contenido JSON
MAX_FILAS_CONTENIDO <- 200

# Helper: parsear query string a lista clave=valor
.parse_qs <- function(qs) {
  qp <- list()
  if (is.null(qs)) {
    qs <- ""
  } else {
    qs <- as.character(qs[1])
  }
  # Plumber entrega ?clave=...: quitar el signo inicial
  qs <- sub("^\\?", "", qs)
  if (is.null(qs) || !nzchar(qs)) return(qp)
  for (p in strsplit(qs, "&", fixed = TRUE)[[1]]) {
    partes <- strsplit(p, "=", fixed = TRUE)[[1]]
    if (length(partes) == 2) {
      qp[[URLdecode(partes[1])]] <- URLdecode(partes[2])
    } else if (length(partes) == 1 && nzchar(partes[1])) {
      qp[[URLdecode(partes[1])]] <- ""
    }
  }
  qp
}

# Helper: respuesta JSON completa para el contenido de un archivo (con paginacion)
.respuesta_contenido <- function(qs) {
  qp <- .parse_qs(qs)
  nombre <- qp[["archivo"]] %||% NULL
  pagina <- qp[["pagina"]] %||% 1
  por_pagina <- qp[["por_pagina"]] %||% 50
  cat("[Plumber] /salida/archivos/contenido:", nombre %||% "(sin archivo)",
      "| pagina:", pagina, "| por_pagina:", por_pagina, "\n")
  contenido <- .leer_csv_salida(nombre, pagina = pagina, tam_pagina = por_pagina)
  list(
    ok = TRUE,
    archivo = contenido$archivo,
    columnas = contenido$columnas,
    n_columnas = contenido$n_columnas,
    n_filas = contenido$n_filas,
    filas_devueltas = contenido$filas_devueltas,
    truncado = contenido$truncado,
    pagina = contenido$pagina,
    tam_pagina = contenido$tam_pagina,
    total_paginas = contenido$total_paginas,
    filas = contenido$filas,
    mensaje = "Contenido del archivo leido correctamente"
  )
}

# Helper: respuesta JSON de error para el contenido de un archivo
.respuesta_contenido_error <- function(e) {
  cat("[Plumber] ERROR en /salida/archivos/contenido:", conditionMessage(e), "\n")
  list(
    ok = FALSE,
    error = conditionMessage(e),
    mensaje = paste("No se pudo leer el archivo:", conditionMessage(e))
  )
}

# Endpoints fijos del frontend (los archivos de r/salida/ siempre son los mismos)
RUTAS_SALIDA <- list(
  list(ruta = "emojis_en_uso",      archivo = "emojis_en_uso.csv",      tipo = "csv"),
  list(ruta = "emojis_pendientes",  archivo = "emojis_pendientes.csv",  tipo = "csv"),
  list(ruta = "mensajes_incluidos", archivo = "mensajes_limpios.csv",   tipo = "csv"),
  list(ruta = "mensajes_excluidos", archivo = "mensajes_excluidos.csv", tipo = "csv"),
  list(ruta = "stopwords_aplicadas", archivo = "stopwords_aplicadas.csv", tipo = "csv"),
  list(ruta = "tokens",             archivo = "tokens.csv",             tipo = "csv"),
  list(ruta = "resumen",            archivo = "resumen.json",           tipo = "json")
)

# Helper: leer un archivo por su ruta fija; resumen.json se parsea como JSON
.leer_archivo_salida_ruta <- function(cfg, pagina = 1, tam_pagina = 50) {
  if (identical(cfg$tipo, "json")) {
    ruta <- normalizePath(file.path(PROYECTO, "salida", cfg$archivo), winslash = "/", mustWork = FALSE)
    if (!startsWith(paste0(ruta, "/"), paste0(normalizePath(file.path(PROYECTO, "salida"), winslash = "/"), "/"))) {
      stop("Archivo fuera de la carpeta de salida")
    }
    if (!file.exists(ruta)) stop("Archivo no encontrado: ", cfg$archivo)
    obj <- jsonlite::fromJSON(ruta, simplifyDataFrame = FALSE)
    list(
      ok = TRUE,
      archivo = cfg$archivo,
      tipo = "json",
      columnas = character(0),
      n_columnas = 0,
      n_filas = 1,
      filas_devueltas = 1,
      truncado = FALSE,
      pagina = 1,
      tam_pagina = tam_pagina,
      total_paginas = 1,
      filas = list(obj) # El JSON completo como una "fila" de datos
    )
  } else {
    .leer_csv_salida(cfg$archivo, pagina = pagina, tam_pagina = tam_pagina)
  }
}

# Helper: respuesta JSON completa para un endpoint fijo de salida (con paginacion)
.respuesta_ruta_salida <- function(cfg, qs) {
  qp <- .parse_qs(qs)
  pagina <- qp[["pagina"]] %||% 1
  por_pagina <- qp[["por_pagina"]] %||% 50
  cat("[Plumber] /salida/", cfg$ruta, "| pagina:", pagina, "| por_pagina:", por_pagina, "\n")
  contenido <- .leer_archivo_salida_ruta(cfg, pagina = pagina, tam_pagina = por_pagina)
  resultado <- c(
    list(ok = TRUE, ruta = cfg$ruta, mensaje = "Contenido del archivo leido correctamente"),
    contenido
  )
  resultado
}

# Helper: construir el handler de la ruta fija (pagina/por_pagina por query string)
.hend_salida_ruta <- function(cfg) {
  force(cfg)
  function(req, res) {
    tryCatch(
      .respuesta_ruta_salida(cfg, req$QUERY_STRING %||% ""),
      error = function(e) {
        cat("[Plumber] ERROR en /salida/", cfg$ruta, ":", conditionMessage(e), "\n")
        res$status <- 400
        .respuesta_contenido_error(e)
      }
    )
  }
}

# Helper: leer un CSV de r/salida/ y devolverlo como JSON-able list con paginacion:
# ?archivo=<nombre.csv>&pagina=<n>&por_pagina=<n>
.leer_csv_salida <- function(nombre, max_filas = MAX_FILAS_CONTENIDO,
                             pagina = 1, tam_pagina = 50) {
  if (is.null(nombre) || !nzchar(nombre)) {
    stop("Se requiere el parametro 'archivo'")
  }
  salida_dir <- file.path(PROYECTO, "salida")
  ruta <- normalizePath(file.path(salida_dir, nombre), winslash = "/", mustWork = FALSE)
  base <- normalizePath(salida_dir, winslash = "/")
  # Seguridad: el archivo debe estar directamente dentro de r/salida/
  if (!startsWith(paste0(ruta, "/"), paste0(base, "/"))) {
    stop("Archivo fuera de la carpeta de salida")
  }
  if (!file.exists(ruta) || file.info(ruta)$isdir) {
    stop("Archivo no encontrado: ", nombre)
  }
  ext <- tolower(tools::file_ext(ruta))
  df <- tryCatch(
    {
      if (ext == "txt") {
        # Archivos de texto separados por tabuladores
        read.table(ruta, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                   check.names = FALSE, quote = "", fill = TRUE, comment.char = "")
      } else {
        read.csv(ruta, stringsAsFactors = FALSE, check.names = FALSE,
                 encoding = "Latin-1", blank.lines.skip = TRUE)
      }
    },
    error = function(e) {
      if (ext == "csv") stop(conditionMessage(e))
      stop("Solo se puede mostrar el contenido de archivos CSV (este archivo es '", ext, "')")
    }
  )
  columnas <- names(df)
  n_total <- nrow(df)

  # Paginacion: pagina empieza en 1, tamano de pagina limitado por max_filas
  aEntero <- function(v, def) {
    r <- suppressWarnings(as.integer(v[1]))
    if (length(r) != 1 || is.na(r)) def else r
  }
  pagina <- min(max(1L, aEntero(pagina, 1L)), 1000000L)
  tam_pagina <- min(max(1L, aEntero(tam_pagina, 50L)), max_filas)
  tam_pagina <- min(tam_pagina, max_filas)
  total_paginas <- if (n_total == 0) 1L else ceiling(n_total / tam_pagina)
  pagina <- min(pagina, total_paginas)
  desde <- (pagina - 1) * tam_pagina
  hasta <- min(desde + tam_pagina - 1L, n_total)
  idx_fechas <- if (n_total == 0) integer(0) else seq(desde + 1L, hasta + 1L)

  filas <- lapply(idx_fechas, function(i) {
    f <- as.list(df[i, ])
    names(f) <- columnas
    # Normalizar celdas vacias a null y simplificar vectores de longitud 1
    lapply(f, function(v) if (length(v) == 0 || (length(v) == 1 && is.na(v))) NULL else unname(v))
  })

  list(
    archivo = nombre,
    columnas = columnas,
    n_columnas = length(columnas),
    n_filas = n_total,
    filas_devueltas = length(filas),
    truncado = length(filas) < n_total,
    # Paginacion
    pagina = pagina,
    tam_pagina = tam_pagina,
    total_paginas = total_paginas,
    filas = filas
  )
}

#* Paso 1 — Ejecutar el preprocesamiento completo (preprocesar())
#* @post /paso/preprocesar
function() {
  cat("[Plumber] Paso 1: Iniciando preprocesamiento completo...\n")
  cat("[Plumber] Paso 1: Carpeta del proyecto R:", PROYECTO, "\n")
  cat("[Plumber] Paso 1: Directorio de salida:", file.path(PROYECTO, "salida"), "\n")
  cat("[Plumber] Paso 1: Directorio de configuracion:", file.path(PROYECTO, "config"), "\n")
  cat("[Plumber] Paso 1: Directorio de bitacoras:", file.path(PROYECTO, "bitacoras"), "\n")
  df <- cargar_dataset()

  entrada_path <- file.path(PROYECTO, "data", "result.json")
  cat("[Plumber] Paso 1: Usando entrada directa:", entrada_path, "\n")
  res <- tryCatch(
    {
      preprocesar(
        entrada_path,
        dir_salida = file.path(PROYECTO, "salida"),
        dir_config = file.path(PROYECTO, "config"),
        dir_bitacoras = file.path(PROYECTO, "bitacoras"),
        consola = "silencioso",
        csv_para_excel = FALSE,
        preguntar_cambios = FALSE
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en preprocesamiento (paso 1):", conditionMessage(e), "\n")
      list(estado = "error", mensaje = conditionMessage(e))
    }
  )

  state$version <- state$version + 1

  if (!is.null(res$resumen)) {
    POST_JSON("/api/bitacora", list(
      tipo_cambio = "preprocesamiento",
      descripcion = sprintf("Paso 1: Preprocesamiento completado: %s mensajes limpios de %s leídos.",
                            res$resumen$mensajes_limpios %||% 0, res$resumen$registros_leidos %||% 0),
      filas_afectadas = res$resumen$mensajes_excluidos %||% 0,
      version_dataset = state$version,
      resumen_estadistico = res$resumen
    ))
    POST_JSON("/api/events/publish", list(
      event = "dataset:update",
      data = list(version = state$version, filas = res$resumen$mensajes_limpios %||% 0)
    ))
  }

  salida_dir <- file.path(PROYECTO, "salida")
  cat("[Plumber> Paso 1: Listando archivos de salida en:", salida_dir, "\n")
  archivos <- .listar_salidas(salida_dir)
  archivos_png <- .listar_salidas(file.path(salida_dir, "analisis"))

  list(
    ok = identical(res$estado, "ok"),
    paso = 1,
    nombre = "Preprocesamiento completo",
    version = state$version,
    estado = res$estado %||% "ok",
    resumen = res$resumen,
    archivos = archivos,
    archivos_analisis = archivos_png,
    mensaje = if (identical(res$estado, "ok")) "Preprocesamiento completado exitosamente" else res$mensaje %||% "Error en el preprocesamiento"
  )
}

#* Paso 2 — Ejecutar analisis por periodo (analizar_periodo() + guardar_analisis())
#* @post /paso/analizar-periodo
function(req, res) {
  cat("[Plumber] Paso 2: Ejecutando analisis por periodo...\n")
  cat("[Plumber] Paso 2: Carpeta del proyecto R:", PROYECTO, "\n")
  tryCatch(
    {
      body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
      periodo <- body$periodo %||% c("2023-01-01", "2023-03-31")
      dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
      dir_analisis <- body$dir_analisis %||% SALIDA_ANALISIS
      k <- as.integer(body$k %||% 6)
      agrupar <- body$agrupar %||% "dia"
      shallow <- isTRUE(body$shallow %||% TRUE)
      libreria <- isTRUE(body$libreria %||% TRUE)

      cat("[Plumber] Paso 2: Variables -> periodo:", paste(periodo, collapse = ", "), "\n")
      cat("[Plumber] Paso 2: Variables -> dir_salida:", dir_salida, "\n")
      cat("[Plumber] Paso 2: Variables -> dir_analisis:", dir_analisis, "\n")
      cat("[Plumber] Paso 2: Variables -> k:", k, "\n")
      cat("[Plumber] Paso 2: Variables -> agrupar:", agrupar, "\n")
      cat("[Plumber] Paso 2: Variables -> shallow:", shallow, "\n")
      cat("[Plumber] Paso 2: Variables -> libreria:", libreria, "\n")

      datos <- cargar_datos_analisis(dir_salida)
      cat("[Plumber] Paso 2: Datos cargados desde", dir_salida, "\n")
      a <- analizar_periodo(
        datos, periodo = periodo, k = k, agrupar = agrupar,
        shallow = shallow, libreria = libreria,
        registrar = TRUE, dir_bitacoras = file.path(PROYECTO, "bitacoras"),
        dir_salida = dir_salida
      )

      dir_creado <- guardar_analisis(a, dir = dir_analisis, graficos = TRUE)
      cat("[Plumber] Paso 2: Analisis guardado en:", dir_creado, "\n")

      archivos <- .listar_salidas(dir_creado)

      state$version <- state$version + 1

      POST_JSON("/api/bitacora", list(
        tipo_cambio = "analisis_periodo",
        descripcion = sprintf("Paso 2: Analisis por periodo '%s' generado.", a$periodo$nombre),
        filas_afectadas = a$n_mensajes,
        version_dataset = state$version,
        resumen_estadistico = list(nivel = a$nivel, interpretacion = a$interpretacion)
      ))
      POST_JSON("/api/events/publish", list(
        event = "dataset:update",
        data = list(version = state$version, periodo = a$periodo$nombre, n_mensajes = a$n_mensajes)
      ))

      res$setHeader("Content-Type", "application/json")
      jsonlite::toJSON(list(
        ok = TRUE,
        paso = 2,
        nombre = "Analisis por periodo",
        periodo = a$periodo,
        n_mensajes = a$n_mensajes,
        nivel = a$nivel,
        serie = a$serie,
        interpretacion = a$interpretacion,
        dir_analisis = .ruta_frontend(dir_creado),
        archivos = archivos,
        mensaje = "Analisis por periodo completado exitosamente"
      ), auto_unbox = TRUE, na = "null")
    },
    error = function(e) {
      cat("[Plumber] ERROR en paso 2 (analisis por periodo):", conditionMessage(e), "\n")
      res$setHeader("Content-Type", "application/json")
      res$status <- 500
      jsonlite::toJSON(list(
        ok = FALSE,
        paso = 2,
        nombre = "Analisis por periodo",
        error = conditionMessage(e),
        mensaje = paste("Error ejecutando analisis por periodo:", conditionMessage(e))
      ), auto_unbox = TRUE, na = "null")
    }
  )
}

#* Paso 3 — Comparar dos periodos (comparar_periodos() + guardar_analisis())
#* @post /paso/comparar-periodos
function(req, res) {
  cat("[Plumber] Paso 3: Comparando dos periodos...\n")
  cat("[Plumber] Paso 3: Carpeta del proyecto R:", PROYECTO, "\n")
  tryCatch(
    {
      body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
      periodoA <- body$periodoA
      periodoB <- body$periodoB
      if (is.null(periodoA) || is.null(periodoB)) {
        res$setHeader("Content-Type", "application/json")
        res$status <- 400
        return(jsonlite::toJSON(list(
          ok = FALSE,
          paso = 3,
          nombre = "Comparacion de periodos",
          error = "Se requieren periodoA y periodoB en el cuerpo de la peticion"
        ), auto_unbox = TRUE))
      }

      dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
      dir_analisis <- body$dir_analisis %||% SALIDA_ANALISIS
      libreria <- isTRUE(body$libreria %||% TRUE)

      cat("[Plumber] Paso 3: Variables -> periodoA:", periodoA, "\n")
      cat("[Plumber] Paso 3: Variables -> periodoB:", periodoB, "\n")
      cat("[Plumber] Paso 3: Variables -> dir_salida:", dir_salida, "\n")
      cat("[Plumber] Paso 3: Variables -> dir_analisis:", dir_analisis, "\n")
      cat("[Plumber] Paso 3: Variables -> libreria:", libreria, "\n")

      datos <- cargar_datos_analisis(dir_salida)
      cat("[Plumber] Paso 3: Datos cargados desde", dir_salida, "\n")
      cmp <- comparar_periodos(
        datos, periodoA, periodoB,
        libreria = libreria,
        registrar = TRUE, dir_bitacoras = file.path(PROYECTO, "bitacoras")
      )

      dir_creado <- guardar_analisis(cmp, dir = dir_analisis, graficos = TRUE)
      cat("[Plumber] Paso 3: Analisis guardado en:", dir_creado, "\n")

      archivos <- .listar_salidas(dir_creado)

      state$version <- state$version + 1

      POST_JSON("/api/bitacora", list(
        tipo_cambio = "comparacion_periodos",
        descripcion = sprintf("Paso 3: Comparacion entre '%s' y '%s'.", cmp$periodos[[1]]$nombre, cmp$periodos[[2]]$nombre),
        filas_afectadas = nrow(cmp$niveles),
        version_dataset = state$version,
        resumen_estadistico = list(niveles = cmp$niveles, interpretacion = cmp$interpretacion)
      ))
      POST_JSON("/api/events/publish", list(
        event = "dataset:update",
        data = list(version = state$version, comparacion = list(A = cmp$periodos[[1]]$nombre, B = cmp$periodos[[2]]$nombre))
      ))

      res$setHeader("Content-Type", "application/json")
      jsonlite::toJSON(list(
        ok = TRUE,
        paso = 3,
        nombre = "Comparacion de periodos",
        periodos = cmp$periodos,
        niveles = cmp$niveles,
        serie = cmp$serie,
        interpretacion = cmp$interpretacion,
        dir_analisis = .ruta_frontend(dir_creado),
        archivos = archivos,
        mensaje = "Comparacion de periodos completada exitosamente"
      ), auto_unbox = TRUE, na = "null")
    },
    error = function(e) {
      cat("[Plumber] ERROR en paso 3 (comparar periodos):", conditionMessage(e), "\n")
      res$setHeader("Content-Type", "application/json")
      res$status <- 500
      jsonlite::toJSON(list(
        ok = FALSE,
        paso = 3,
        nombre = "Comparacion de periodos",
        error = conditionMessage(e),
        mensaje = paste("Error comparando periodos:", conditionMessage(e))
      ), auto_unbox = TRUE, na = "null")
    }
  )
}

#* Paso 4 — Analizar una sola oracion (analizar_oracion())
#* @post /paso/analizar-oracion
function(req, res) {
  cat("[Plumber] Paso 4: Analizando una sola oracion...\n")
  cat("[Plumber] Paso 4: Carpeta del proyecto R:", PROYECTO, "\n")
  tryCatch(
    {
      body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
      texto <- body$texto
      if (is.null(texto) || !nzchar(texto)) {
        res$setHeader("Content-Type", "application/json")
        res$status <- 400
        return(jsonlite::toJSON(list(
          ok = FALSE,
          paso = 4,
          nombre = "Analisis de una oracion",
          error = "Se requiere el campo 'texto' en el cuerpo de la peticion"
        ), auto_unbox = TRUE))
      }

      dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
      usar_udpipe <- isTRUE(body$usar_udpipe %||% TRUE)
      usar_libreria <- isTRUE(body$usar_libreria %||% TRUE)
      usar_topicos <- isTRUE(body$usar_topicos %||% FALSE)

      cat("[Plumber] Paso 4: Variables -> texto:", substr(texto, 1, 100), "\n")
      cat("[Plumber] Paso 4: Variables -> dir_salida:", dir_salida, "\n")
      cat("[Plumber] Paso 4: Variables -> usar_udpipe:", usar_udpipe, "\n")
      cat("[Plumber] Paso 4: Variables -> usar_libreria:", usar_libreria, "\n")
      cat("[Plumber] Paso 4: Variables -> usar_topicos:", usar_topicos, "\n")

      datos <- cargar_datos_analisis(dir_salida)
      cat("[Plumber] Paso 4: Datos cargados desde", dir_salida, "\n")

      lda <- NULL
      if (isTRUE(body$usar_topicos %||% FALSE)) {
        tk <- datos$tokens
        lda <- tryCatch(topicos_lda(tk, k = 6, agrupar = "dia"), error = function(e) NULL)
      }

      o <- analizar_oracion(
        texto,
        datos = datos,
        lda = lda,
        usar_udpipe = usar_udpipe,
        usar_libreria = usar_libreria
      )

      state$version <- state$version + 1

      POST_JSON("/api/bitacora", list(
        tipo_cambio = "analisis_oracion",
        descripcion = "Paso 4: Analisis de una sola oracion.",
        filas_afectadas = 1,
        version_dataset = state$version,
        resumen_estadistico = list(texto = texto, polaridad = o$polaridad, dominante = o$dominante)
      ))
      POST_JSON("/api/events/publish", list(
        event = "dataset:update",
        data = list(version = state$version, oracion = texto)
      ))

      res$setHeader("Content-Type", "application/json")
      jsonlite::toJSON(list(
        ok = TRUE,
        paso = 4,
        nombre = "Analisis de una oracion",
        texto = o$texto,
        limpio = o$limpio,
        tokens = o$tokens,
        stopwords = o$stopwords,
        shallow = o$shallow,
        tfidf = o$tfidf,
        topicos = o$topicos,
        propios = o$propios,
        polaridad = o$polaridad,
        dominante = o$dominante,
        nivel_vs_corpus = o$nivel_vs_corpus,
        libreria = o$libreria,
        mensaje = "Analisis de oracion completado exitosamente"
      ), auto_unbox = TRUE, na = "null")
    },
    error = function(e) {
      cat("[Plumber] ERROR en paso 4 (analizar oracion):", conditionMessage(e), "\n")
      res$setHeader("Content-Type", "application/json")
      res$status <- 500
      jsonlite::toJSON(list(
        ok = FALSE,
        paso = 4,
        nombre = "Analisis de una oracion",
        error = conditionMessage(e),
        mensaje = paste("Error analizando oracion:", conditionMessage(e))
      ), auto_unbox = TRUE, na = "null")
    }
  )
}

# ------------------------------------------------------------------------------
# 7. Endpoint para el dashboard: imagenes agrupadas por carpeta
# ------------------------------------------------------------------------------

#* Archivos de la carpeta salida (solo archivos, sin carpetas) en JSON
#* @get /salida/archivos
#* @serializer unboxedJSON
function() {
  cat("[Plumber] /salida/archivos: Listando archivos de", file.path(PROYECTO, "salida"), "...\n")
  tryCatch(
    {
      archivos <- .listar_archivos_salida()
      list(
        ok = TRUE,
        carpeta = .ruta_frontend(file.path(PROYECTO, "salida")),
        archivos = archivos,
        total = length(archivos),
        version = state$version,
        mensaje = "Archivos de salida listados (solo archivos, sin carpetas)"
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en /salida/archivos:", conditionMessage(e), "\n")
      list(
        ok = FALSE,
        carpeta = NULL,
        archivos = list(),
        total = 0,
        mensaje = paste("Error listando archivos de salida:", conditionMessage(e))
      )
    }
  )
}

#* Contenido de un archivo CSV de r/salida (JSON)
#* @get /salida/archivos/contenido
#* @param archivo
function(req, res) {
  # Obtener el nombre desde la query string (?archivo=...)
  qs <- req$QUERY_STRING %||% ""
  tryCatch(
    {
      # Parametros: archivo, pagina (>=1), por_pagina (<= 200)
      .respuesta_contenido(qs)
    },
    error = function(e) {
      cat("[Plumber] ERROR en /salida/archivos/contenido:", conditionMessage(e), "\n")
      res$status <- 400
      .respuesta_contenido_error(e)
    }
  )
}

#* Graficos del dashboard agrupados por carpeta
#* @get /dashboard/graficos
function() {
  cat("[Plumber] /dashboard/graficos: Listando imagenes agrupadas por carpeta...\n")
  tryCatch(
    {
      grupos <- .agrupar_imagenes()
      list(
        ok = TRUE,
        carpetas = grupos,
        total_carpetas = length(grupos),
        total_imagenes = sum(vapply(grupos, function(g) length(g$imagenes), integer(1))),
        mensaje = "Imagenes listadas agrupadas por carpeta"
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en /dashboard/graficos:", conditionMessage(e), "\n")
      list(
        ok = FALSE,
        carpetas = list(),
        total_carpetas = 0,
        total_imagenes = 0,
        mensaje = paste("Error listando imagenes:", conditionMessage(e))
      )
    }
  )
}

# ------------------------------------------------------------------------------
# 8. Ejecutar preprocesamiento (endpoint existente, mantenido por compatibilidad)
#* @post /preprocesar
function() {
  cat("[Plumber] Endpoint /preprocesar (compatibilidad): Iniciando preprocesamiento...\n")
  cat("[Plumber] /preprocesar: Carpeta del proyecto R:", PROYECTO, "\n")
  cat("[Plumber] /preprocesar: Directorio de salida:", file.path(PROYECTO, "salida"), "\n")
  cat("[Plumber] /preprocesar: Directorio de configuracion:", file.path(PROYECTO, "config"), "\n")
  cat("[Plumber] /preprocesar: Directorio de bitacoras:", file.path(PROYECTO, "bitacoras"), "\n")
  entrada_path <- file.path(PROYECTO, "data", "result.json")
  cat("[Plumber] /preprocesar: Usando entrada directa:", entrada_path, "\n")

  res <- tryCatch(
    {
      preprocesar(
        entrada_path,
        dir_salida = file.path(PROYECTO, "salida"),
        dir_config = file.path(PROYECTO, "config"),
        dir_bitacoras = file.path(PROYECTO, "bitacoras"),
        consola = "silencioso",
        csv_para_excel = FALSE,
        preguntar_cambios = FALSE
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en preprocesamiento:", conditionMessage(e), "\n")
      list(estado = "error", mensaje = conditionMessage(e))
    }
  )

  state$version <- state$version + 1
  cat("[Plumber] Preprocesamiento terminado. Version:", state$version, "\n")

  if (!is.null(res$resumen)) {
    POST_JSON("/api/bitacora", list(
      tipo_cambio = "preprocesamiento",
      descripcion = sprintf("Preprocesamiento completado: %s mensajes limpios de %s leídos.",
                            res$resumen$mensajes_limpios %||% 0, res$resumen$registros_leidos %||% 0),
      filas_afectadas = res$resumen$mensajes_excluidos %||% 0,
      version_dataset = state$version,
      resumen_estadistico = res$resumen
    ))
    POST_JSON("/api/events/publish", list(
      event = "dataset:update",
      data = list(version = state$version, filas = res$resumen$mensajes_limpios %||% 0)
    ))
  }

  list(
    ok = TRUE,
    version = state$version,
    filas = if (!is.null(res$resumen)) res$resumen$mensajes_limpios else 0,
    estado = res$estado %||% "ok"
  )
}

# ------------------------------------------------------------------------------
# 8b. Endpoints para las bitacoras en r/bitacoras/ (xlsx -> JSON paginado)
# ------------------------------------------------------------------------------

BITACORAS_DIR <- file.path(PROYECTO, "bitacoras")

# Helper: listar los archivos de r/bitacoras/ (con sus hojas si es xlsx)
.listar_bitacoras <- function() {
  if (!dir.exists(BITACORAS_DIR)) {
    return(list())
  }
  archivos <- list()
  for (f in list.files(BITACORAS_DIR, full.names = TRUE, recursive = FALSE)) {
    if (file.exists(f) && !file.info(f)$isdir) {
      ext <- tolower(tools::file_ext(f))
      hojas <- NULL
      if (ext == "xlsx") {
        hojas <- tryCatch(readxl::excel_sheets(f), error = function(e) NULL)
      }
      archivos[[length(archivos) + 1]] <- list(
        nombre = basename(f),
        ruta = .ruta_frontend(f),
        ruta_api = paste0("/bitacoras/", tools::file_path_sans_ext(basename(f))),
        tipo = ext,
        tamano_bytes = as.integer(file.info(f)$size),
        modificado = format(file.info(f)$mtime, format = "%Y-%m-%d %H:%M:%S"),
        hojas = hojas
      )
    }
  }
  archivos
}

# Helper: leer un archivo de bitacora (xlsx o json) y devolver filas paginadas
.leer_bitacora_ruta <- function(cfg, hoja = NULL, pagina = 1, tam_pagina = 50) {
  if (is.null(cfg$archivo) || !nzchar(cfg$archivo)) {
    stop("Se requiere un archivo de bitacora valido")
  }
  ruta <- normalizePath(file.path(BITACORAS_DIR, cfg$archivo), winslash = "/", mustWork = FALSE)
  base <- normalizePath(BITACORAS_DIR, winslash = "/")
  # Seguridad: el archivo debe estar dentro de r/bitacoras/
  if (!startsWith(paste0(ruta, "/"), paste0(base, "/"))) {
    stop("Archivo fuera de la carpeta de bitacoras")
  }
  if (!file.exists(ruta) || file.info(ruta)$isdir) {
    stop("Archivo de bitacora no encontrado: ", cfg$archivo)
  }

  # Utilidad compartida para convertir un entero de query a entero seguro
  aEntero <- function(v, def) {
    r <- suppressWarnings(as.integer(v[1]))
    if (length(r) != 1 || is.na(r)) def else r
  }
  pagina <- min(max(1L, aEntero(pagina, 1L)), 1000000L)
  tam_pagina <- min(max(1L, aEntero(tam_pagina, 50L)), MAX_FILAS_CONTENIDO)

  respuesta_base <- function(df, hoja_usada = NULL) {
    columnas <- names(df)
    n_total <- nrow(df)
    total_paginas <- if (n_total == 0) 1L else ceiling(n_total / tam_pagina)
    pagina <- min(pagina, total_paginas)
    desde <- (pagina - 1) * tam_pagina
    hasta <- min(desde + tam_pagina - 1L, n_total)
    idx_filas <- if (n_total == 0) integer(0) else seq(desde + 1L, hasta + 1L)
    filas <- lapply(idx_filas, function(i) {
      f <- as.list(df[i, ])
      names(f) <- columnas
      lapply(f, function(v) {
        if (length(v) == 0 || (length(v) == 1 && is.na(v))) {
          return(NULL)
        }
        if (nrow(v) > 0 && !is.null(dim(v))) {
          list(n_filas = nrow(v), filas = lapply(seq_len(nrow(v)), as.list))
        } else if (length(v) > 1) {
          as.list(v)
        } else {
          unname(v)
        }
      })
    })
    list(
      ok = TRUE,
      archivo = cfg$archivo,
      tipo = cfg$tipo,
      hoja = hoja_usada,
      columnas = columnas,
      n_columnas = length(columnas),
      n_filas = n_total,
      filas_devueltas = length(filas),
      truncado = length(filas) < n_total,
      pagina = pagina,
      tam_pagina = tam_pagina,
      total_paginas = total_paginas,
      filas = filas
    )
  }

  if (identical(cfg$tipo, "json")) {
    obj <- jsonlite::fromJSON(ruta, simplifyDataFrame = FALSE)
    res <- respuesta_base(data.frame(clave = "contenido", valor = "", stringsAsFactors = FALSE))
    res$filas <- list(
      list(clave = NULL, valor = obj)
    )
    res$columnas_tocadas <- NULL
    res$mensaje <- "Contenido JSON de la bitacora leido correctamente"
    return(res)
  }

  # XLSX: elegir hoja
  hojas <- tryCatch(readxl::excel_sheets(ruta), error = function(e) NULL)
  hoja_sel <- if (!is.null(hoja) && !is.na(hoja) && !is.null(hojas) &&
                   hoja %in% hojas) hoja else (hojas[[1]] %||% NULL)
  if (is.null(hoja_sel)) stop("El xlsx no tiene hojas legibles: ", cfg$archivo)
  df <- readxl::read_xlsx(ruta, sheet = hoja_sel, col_types = "text")
  res <- respuesta_base(as.data.frame(df), hoja_sel)
  res$mensaje <- "Contenido de la bitacora leido correctamente"
  res
}

# Rutas fijas generadas a partir de los archivos existentes en r/bitacoras/
RUTAS_BITACORAS <- lapply(.listar_bitacoras(), function(b) {
  list(
    ruta = tools::file_path_sans_ext(b$nombre),
    archivo = b$nombre,
    tipo = b$tipo,
    hojas = b$hojas
  )
})

# Helper: respuesta JSON con paginacion para una ruta de bitacora
.respuesta_ruta_bitacora <- function(cfg, req) {
  qp <- .parse_qs(req$QUERY_STRING %||% "")
  hoja <- qp[["hoja"]] %||% NULL
  pagina <- qp[["pagina"]] %||% 1
  por_pagina <- qp[["por_pagina"]] %||% 50
  cat("[Plumber] /bitacoras/", cfg$ruta, "| hoja:", hoja %||% "(default)",
      "| pagina:", pagina, "| por_pagina:", por_pagina, "\n")
  .leer_bitacora_ruta(cfg, hoja = hoja, pagina = pagina, tam_pagina = por_pagina)
}

# Helper: construir el handler de la ruta fija de bitacora
.hend_bitacora_ruta <- function(cfg) {
  force(cfg)
  function(req, res) {
    tryCatch(
      .respuesta_ruta_bitacora(cfg, req),
      error = function(e) {
        cat("[Plumber] ERROR en /bitacoras/", cfg$ruta, ":", conditionMessage(e), "\n")
        res$status <- 400
        .respuesta_contenido_error(e)
      }
    )
  }
}
cat("[Plumber] API definida. Puerto: 8765\n")
cat("[Plumber] Endpoints:\n")
cat("  GET  http://localhost:8765/__ping__        - salud\n")
cat("  GET  http://localhost:8765/dataset/summary - resumen del dataset\n")
cat("  POST http://localhost:8765/preprocesar     - ejecutar preprocesamiento (compatibilidad)\n")
cat("  POST http://localhost:8765/paso/preprocesar      - Paso 1: preprocesamiento completo\n")
cat("  POST http://localhost:8765/paso/analizar-periodo - Paso 2: analisis por periodo\n")
cat("  POST http://localhost:8765/paso/comparar-periodos - Paso 3: comparacion de periodos\n")
cat("  POST http://localhost:8765/paso/analizar-oracion - Paso 4: analisis de una oracion\n")
cat("  GET  http://localhost:8765/salida/archivos   - Archivos de r/salida (solo archivos, JSON)\n")
cat("  GET  http://localhost:8765/salida/archivos/contenido?archivo=x.csv - Contenido de un CSV (JSON, paginado)\n")
cat("  GET  http://localhost:8765/salida/<archivo>?pagina=&por_pagina=    - Endpoint fijo por archivo:\n")
cat("       /salida/emojis_en_uso  /salida/emojis_pendientes  /salida/mensajes_incluidos\n")
cat("       /salida/mensajes_excluidos  /salida/stopwords_aplicadas  /salida/tokens  /salida/resumen\n")
cat("  GET  http://localhost:8765/bitacoras - Archivos de r/bitacoras (JSON)\n")
cat("  GET  http://localhost:8765/bitacoras/<archivo>?hoja=&pagina=&por_pagina= - Contenido paginado (xlsx/json)\n")
cat("  GET  http://localhost:8765/dashboard/graficos - Imagenes agrupadas por carpeta (dashboard)\n")
cat("  GET  http://localhost:8765/archivos/*  - Servir archivos estaticos (imagenes)\n")

if (!exists(".plumber_iniciado", envir = globalenv()) || !get(".plumber_iniciado", envir = globalenv())) {
  assign(".plumber_iniciado", TRUE, envir = globalenv())

  cat("[Plumber] Creando objeto Plumber...\n")
  api_obj <- tryCatch(
    plumber::Plumber$new(),
    error = function(e) {
      cat("\n====================================================================\n")
      cat("ERROR al crear el objeto Plumber:\n")
      cat("  ", conditionMessage(e), "\n")
      cat("====================================================================\n\n")
      quit(status = 1)
    }
  )

  api_obj$filter("cors", cors_filter)

  api_obj$handle("GET", "/__ping__", function() {
    list(
      ok = TRUE,
      ts = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
      version = state$version,
      iniciado = format(state$iniciado, "%Y-%m-%d %H:%M:%S")
    )
  })

  api_obj$handle("GET", "/dataset/summary", function() {
    tryCatch(
      {
        ruta <- file.path(PROYECTO, "data", "result.json")
        cat("[Plumber] /dataset/summary: usando dataset desde", ruta, "\n")
        df <- cargar_dataset()
        cat("[Plumber] /dataset/summary: dataset tiene", nrow(df), "filas y", ncol(df), "columnas\n")
        list(
          filas = nrow(df),
          columnas = ncol(df),
          nombres_columnas = names(df),
          version = state$version
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en /dataset/summary:", conditionMessage(e), "\n")
        list(error = conditionMessage(e))
      }
    )
  })

  api_obj$handle("POST", "/preprocesar", function() {
    cat("[Plumber] Endpoint /preprocesar (compatibilidad): Iniciando preprocesamiento...\n")
    cat("[Plumber] /preprocesar: Carpeta del proyecto R:", PROYECTO, "\n")
    cat("[Plumber] /preprocesar: Directorio de salida:", file.path(PROYECTO, "salida"), "\n")
    cat("[Plumber] /preprocesar: Directorio de configuracion:", file.path(PROYECTO, "config"), "\n")
    cat("[Plumber] /preprocesar: Directorio de bitacoras:", file.path(PROYECTO, "bitacoras"), "\n")
    entrada_path <- file.path(PROYECTO, "data", "result.json")
    cat("[Plumber] /preprocesar: Usando entrada directa:", entrada_path, "\n")

    res <- tryCatch(
      {
        preprocesar(
          entrada_path,
          dir_salida = file.path(PROYECTO, "salida"),
          dir_config = file.path(PROYECTO, "config"),
          dir_bitacoras = file.path(PROYECTO, "bitacoras"),
          consola = "silencioso",
          csv_para_excel = FALSE,
          preguntar_cambios = FALSE
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en preprocesamiento:", conditionMessage(e), "\n")
        list(estado = "error", mensaje = conditionMessage(e))
      }
    )

    state$version <- state$version + 1
    cat("[Plumber] Preprocesamiento terminado. Version:", state$version, "\n")

    if (!is.null(res$resumen)) {
      POST_JSON("/api/bitacora", list(
        tipo_cambio = "preprocesamiento",
        descripcion = sprintf("Preprocesamiento completado: %s mensajes limpios de %s leídos.",
                              res$resumen$mensajes_limpios %||% 0, res$resumen$registros_leidos %||% 0),
        filas_afectadas = res$resumen$mensajes_excluidos %||% 0,
        version_dataset = state$version,
        resumen_estadistico = res$resumen
      ))
      POST_JSON("/api/events/publish", list(
        event = "dataset:update",
        data = list(version = state$version, filas = res$resumen$mensajes_limpios %||% 0)
      ))
    }

    list(
      ok = TRUE,
      version = state$version,
      filas = if (!is.null(res$resumen)) res$resumen$mensajes_limpios else 0,
      estado = res$estado %||% "ok"
    )
  })

  api_obj$handle("POST", "/paso/preprocesar", function() {
    cat("[Plumber] Paso 1: Iniciando preprocesamiento completo...\n")
    cat("[Plumber] Paso 1: Carpeta del proyecto R:", PROYECTO, "\n")
    cat("[Plumber] Paso 1: Directorio de salida:", file.path(PROYECTO, "salida"), "\n")
    cat("[Plumber] Paso 1: Directorio de configuracion:", file.path(PROYECTO, "config"), "\n")
    cat("[Plumber] Paso 1: Directorio de bitacoras:", file.path(PROYECTO, "bitacoras"), "\n")
    entrada_path <- file.path(PROYECTO, "data", "result.json")
    cat("[Plumber] Paso 1: Usando entrada directa:", entrada_path, "\n")

    res <- tryCatch(
      {
        preprocesar(
          entrada_path,
          dir_salida = file.path(PROYECTO, "salida"),
          dir_config = file.path(PROYECTO, "config"),
          dir_bitacoras = file.path(PROYECTO, "bitacoras"),
          consola = "silencioso",
          csv_para_excel = FALSE,
          preguntar_cambios = FALSE
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en preprocesamiento (paso 1):", conditionMessage(e), "\n")
        list(estado = "error", mensaje = conditionMessage(e))
      }
    )

    state$version <- state$version + 1

    if (!is.null(res$resumen)) {
      POST_JSON("/api/bitacora", list(
        tipo_cambio = "preprocesamiento",
        descripcion = sprintf("Paso 1: Preprocesamiento completado: %s mensajes limpios de %s leídos.",
                              res$resumen$mensajes_limpios %||% 0, res$resumen$registros_leidos %||% 0),
        filas_afectadas = res$resumen$mensajes_excluidos %||% 0,
        version_dataset = state$version,
        resumen_estadistico = res$resumen
      ))
      POST_JSON("/api/events/publish", list(
        event = "dataset:update",
        data = list(version = state$version, filas = res$resumen$mensajes_limpios %||% 0)
      ))
    }

    salida_dir <- file.path(PROYECTO, "salida")
    archivos <- .listar_salidas(salida_dir)
    archivos_png <- .listar_salidas(file.path(salida_dir, "analisis"))

    list(
      ok = identical(res$estado, "ok"),
      paso = 1,
      nombre = "Preprocesamiento completo",
      version = state$version,
      estado = res$estado %||% "ok",
      resumen = res$resumen,
      archivos = archivos,
      archivos_analisis = archivos_png,
      mensaje = if (identical(res$estado, "ok")) "Preprocesamiento completado exitosamente" else res$mensaje %||% "Error en el preprocesamiento"
    )
  })

  api_obj$handle("POST", "/paso/analizar-periodo", function(req, res) {
    cat("[Plumber] Paso 2: Ejecutando analisis por periodo...\n")
    cat("[Plumber] Paso 2: Carpeta del proyecto R:", PROYECTO, "\n")
    tryCatch(
      {
        body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
        periodo <- body$periodo %||% c("2023-01-01", "2023-03-31")
        dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
      dir_analisis <- body$dir_analisis %||% SALIDA_ANALISIS
      k <- as.integer(body$k %||% 6)
      agrupar <- body$agrupar %||% "dia"
      shallow <- isTRUE(body$shallow %||% TRUE)
      libreria <- isTRUE(body$libreria %||% TRUE)

      cat("[Plumber] Paso 2: Variables -> periodo:", paste(periodo, collapse = ", "), "\n")
      cat("[Plumber] Paso 2: Variables -> dir_salida:", dir_salida, "\n")
      cat("[Plumber] Paso 2: Variables -> dir_analisis:", dir_analisis, "\n")
        cat("[Plumber] Paso 2: Variables -> k:", k, "\n")
        cat("[Plumber] Paso 2: Variables -> agrupar:", agrupar, "\n")
        cat("[Plumber] Paso 2: Variables -> shallow:", shallow, "\n")
        cat("[Plumber] Paso 2: Variables -> libreria:", libreria, "\n")

        datos <- cargar_datos_analisis(dir_salida)
        cat("[Plumber] Paso 2: Datos cargados desde", dir_salida, "\n")
        a <- analizar_periodo(
          datos, periodo = periodo, k = k, agrupar = agrupar,
          shallow = shallow, libreria = libreria,
          registrar = TRUE, dir_bitacoras = file.path(PROYECTO, "bitacoras"),
          dir_salida = dir_salida
        )

        dir_creado <- guardar_analisis(a, dir = dir_analisis, graficos = TRUE)
        cat("[Plumber] Paso 2: Analisis guardado en:", dir_creado, "\n")

        archivos <- .listar_salidas(dir_creado)

        state$version <- state$version + 1

        POST_JSON("/api/bitacora", list(
          tipo_cambio = "analisis_periodo",
          descripcion = sprintf("Paso 2: Analisis por periodo '%s' generado.", a$periodo$nombre),
          filas_afectadas = a$n_mensajes,
          version_dataset = state$version,
          resumen_estadistico = list(nivel = a$nivel, interpretacion = a$interpretacion)
        ))
        POST_JSON("/api/events/publish", list(
          event = "dataset:update",
          data = list(version = state$version, periodo = a$periodo$nombre, n_mensajes = a$n_mensajes)
        ))

        list(
          ok = TRUE,
          paso = 2,
          nombre = "Analisis por periodo",
          periodo = a$periodo,
          n_mensajes = a$n_mensajes,
          nivel = a$nivel,
          serie = a$serie,
          interpretacion = a$interpretacion,
          dir_analisis = .ruta_frontend(dir_creado),
          archivos = archivos,
          mensaje = "Analisis por periodo completado exitosamente"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en paso 2 (analisis por periodo):", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          paso = 2,
          nombre = "Analisis por periodo",
          error = conditionMessage(e),
          mensaje = paste("Error ejecutando analisis por periodo:", conditionMessage(e))
        )
      }
    )
  })

  api_obj$handle("POST", "/paso/comparar-periodos", function(req, res) {
    cat("[Plumber] Paso 3: Comparando dos periodos...\n")
    cat("[Plumber] Paso 3: Carpeta del proyecto R:", PROYECTO, "\n")
    tryCatch(
      {
        body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
        periodoA <- body$periodoA
        periodoB <- body$periodoB
        if (is.null(periodoA) || is.null(periodoB)) {
          return(list(
            ok = FALSE,
            paso = 3,
            nombre = "Comparacion de periodos",
            error = "Se requieren periodoA y periodoB en el cuerpo de la peticion",
            mensaje = "Faltan parametros periodoA y periodoB"
          ))
        }

        dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
      dir_analisis <- body$dir_analisis %||% SALIDA_ANALISIS
      libreria <- isTRUE(body$libreria %||% TRUE)

      cat("[Plumber] Paso 3: Variables -> periodoA:", periodoA, "\n")
      cat("[Plumber] Paso 3: Variables -> periodoB:", periodoB, "\n")
      cat("[Plumber] Paso 3: Variables -> dir_salida:", dir_salida, "\n")
      cat("[Plumber] Paso 3: Variables -> dir_analisis:", dir_analisis, "\n")
      cat("[Plumber] Paso 3: Variables -> libreria:", libreria, "\n")

        datos <- cargar_datos_analisis(dir_salida)
        cat("[Plumber] Paso 3: Datos cargados desde", dir_salida, "\n")
        cmp <- comparar_periodos(
          datos, periodoA, periodoB,
          libreria = libreria,
          registrar = TRUE, dir_bitacoras = file.path(PROYECTO, "bitacoras")
        )

        dir_creado <- guardar_analisis(cmp, dir = dir_analisis, graficos = TRUE)
        cat("[Plumber] Paso 3: Analisis guardado en:", dir_creado, "\n")

        archivos <- .listar_salidas(dir_creado)

        state$version <- state$version + 1

        POST_JSON("/api/bitacora", list(
          tipo_cambio = "comparacion_periodos",
          descripcion = sprintf("Paso 3: Comparacion entre '%s' y '%s'.", cmp$periodos[[1]]$nombre, cmp$periodos[[2]]$nombre),
          filas_afectadas = nrow(cmp$niveles),
          version_dataset = state$version,
          resumen_estadistico = list(niveles = cmp$niveles, interpretacion = cmp$interpretacion)
        ))
        POST_JSON("/api/events/publish", list(
          event = "dataset:update",
          data = list(version = state$version, comparacion = list(A = cmp$periodos[[1]]$nombre, B = cmp$periodos[[2]]$nombre))
        ))

        list(
          ok = TRUE,
          paso = 3,
          nombre = "Comparacion de periodos",
          periodos = cmp$periodos,
          niveles = cmp$niveles,
          serie = cmp$serie,
          interpretacion = cmp$interpretacion,
          dir_analisis = .ruta_frontend(dir_creado),
          archivos = archivos,
          mensaje = "Comparacion de periodos completada exitosamente"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en paso 3 (comparar periodos):", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          paso = 3,
          nombre = "Comparacion de periodos",
          error = conditionMessage(e),
          mensaje = paste("Error comparando periodos:", conditionMessage(e))
        )
      }
    )
  })

  api_obj$handle("POST", "/paso/analizar-oracion", function(req, res) {
    cat("[Plumber] Paso 4: Analizando una sola oracion...\n")
    cat("[Plumber] Paso 4: Carpeta del proyecto R:", PROYECTO, "\n")
    tryCatch(
      {
        body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
        texto <- body$texto
        if (is.null(texto) || !nzchar(texto)) {
          return(list(
            ok = FALSE,
            paso = 4,
            nombre = "Analisis de una oracion",
            error = "Se requiere el campo 'texto' en el cuerpo de la peticion",
            mensaje = "Falta el texto a analizar"
          ))
        }

        dir_salida <- body$dir_salida %||% file.path(PROYECTO, "salida")
        usar_udpipe <- isTRUE(body$usar_udpipe %||% TRUE)
        usar_libreria <- isTRUE(body$usar_libreria %||% TRUE)
        usar_topicos <- isTRUE(body$usar_topicos %||% FALSE)

        cat("[Plumber] Paso 4: Variables -> texto:", substr(texto, 1, 100), "\n")
        cat("[Plumber] Paso 4: Variables -> dir_salida:", dir_salida, "\n")
        cat("[Plumber] Paso 4: Variables -> usar_udpipe:", usar_udpipe, "\n")
        cat("[Plumber] Paso 4: Variables -> usar_libreria:", usar_libreria, "\n")
        cat("[Plumber] Paso 4: Variables -> usar_topicos:", usar_topicos, "\n")

        datos <- cargar_datos_analisis(dir_salida)
        cat("[Plumber] Paso 4: Datos cargados desde", dir_salida, "\n")

        lda <- NULL
        if (usar_topicos) {
          tk <- datos$tokens
          lda <- tryCatch(topicos_lda(tk, k = 6, agrupar = "dia"), error = function(e) NULL)
        }

        o <- analizar_oracion(
          texto,
          datos = datos,
          lda = lda,
          usar_udpipe = usar_udpipe,
          usar_libreria = usar_libreria
        )

        state$version <- state$version + 1

        POST_JSON("/api/bitacora", list(
          tipo_cambio = "analisis_oracion",
          descripcion = "Paso 4: Analisis de una sola oracion.",
          filas_afectadas = 1,
          version_dataset = state$version,
          resumen_estadistico = list(texto = texto, polaridad = o$polaridad, dominante = o$dominante)
        ))
        POST_JSON("/api/events/publish", list(
          event = "dataset:update",
          data = list(version = state$version, oracion = texto)
        ))

        list(
          ok = TRUE,
          paso = 4,
          nombre = "Analisis de una oracion",
          texto = o$texto,
          limpio = o$limpio,
          tokens = o$tokens,
          stopwords = o$stopwords,
          shallow = o$shallow,
          tfidf = o$tfidf,
          topicos = o$topicos,
          propios = o$propios,
          polaridad = o$polaridad,
          dominante = o$dominante,
          nivel_vs_corpus = o$nivel_vs_corpus,
          libreria = o$libreria,
          mensaje = "Analisis de oracion completado exitosamente"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en paso 4 (analizar oracion):", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          paso = 4,
          nombre = "Analisis de una oracion",
          error = conditionMessage(e),
          mensaje = paste("Error analizando oracion:", conditionMessage(e))
        )
      }
    )
  })

  # Servir archivos estaticos (imagenes PNG y otros) desde la carpeta salida
  api_obj$handle("GET", "/archivos/*", function(path) {
    archivo <- file.path(SALIDA_FRONT, path)
    if (!file.exists(archivo) || file.info(archivo)$isdir) {
      res$status <- 404
      return(list(error = "Archivo no encontrado"))
    }
    res$setHeader("Content-Type", switch(tolower(tools::file_ext(archivo)),
                                         png = "image/png",
                                         csv = "text/csv",
                                         json = "application/json",
                                         txt = "text/plain",
                                         "application/octet-stream"))
    readBin(archivo, "raw", n = file.info(archivo)$size)
  })

  # Listar archivos de r/salida (solo archivos, sin carpetas) en JSON
  api_obj$handle("GET", "/salida/archivos", function() {
    cat("[Plumber] /salida/archivos: Listando archivos de", file.path(PROYECTO, "salida"), "...\n")
    tryCatch(
      {
        archivos <- .listar_archivos_salida()
        list(
          ok = TRUE,
          carpeta = .ruta_frontend(file.path(PROYECTO, "salida")),
          archivos = archivos,
          total = length(archivos),
          version = state$version,
          mensaje = "Archivos de salida listados (solo archivos, sin carpetas)"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en /salida/archivos:", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          carpeta = NULL,
          archivos = list(),
          total = 0,
          mensaje = paste("Error listando archivos de salida:", conditionMessage(e))
        )
      }
    )
  }, serializer = plumber::serializer_unboxed_json())

  # Contenido de un archivo CSV de r/salida en JSON
  api_obj$handle("GET", "/salida/archivos/contenido", function(req, res) {
    tryCatch(
      {
        # Parametros: archivo, pagina (>=1), por_pagina (<= 200)
        .respuesta_contenido(req$QUERY_STRING %||% "")
      },
      error = function(e) {
        cat("[Plumber] ERROR en /salida/archivos/contenido:", conditionMessage(e), "\n")
        res$status <- 400
        .respuesta_contenido_error(e)
      }
    )
  }, serializer = plumber::serializer_unboxed_json())

  # Endpoints fijos por archivo de r/salida/ (paginacion via ?pagina=&por_pagina=)
  lapply(RUTAS_SALIDA, function(cfg) {
    ruta <- paste0("/salida/", cfg$ruta)
    cat("[Plumber] Registrando GET ", ruta, " -> ", cfg$archivo, "\n", sep = "")
    api_obj$handle(
      "GET", ruta, .hend_salida_ruta(cfg),
      serializer = plumber::serializer_unboxed_json()
    )
  })

  # Listar los archivos de r/bitacoras/ (con hojas de xlsx) en JSON
  api_obj$handle("GET", "/bitacoras", function() {
    cat("[Plumber] /bitacoras: Listando archivos de", BITACORAS_DIR, "...\n")
    tryCatch(
      {
        archivos <- .listar_bitacoras()
        list(
          ok = TRUE,
          carpeta = .ruta_frontend(BITACORAS_DIR),
          archivos = archivos,
          total = length(archivos),
          mensaje = "Archivos de bitacoras listados"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en /bitacoras:", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          archivos = list(),
          total = 0,
          mensaje = paste("Error listando bitacoras:", conditionMessage(e))
        )
      }
    )
  }, serializer = plumber::serializer_unboxed_json())

  # Endpoints fijos por archivo de r/bitacoras/ (xlsx/json -> JSON paginado)
  lapply(RUTAS_BITACORAS, function(cfg) {
    ruta <- paste0("/bitacoras/", cfg$ruta)
    cat("[Plumber] Registrando GET ", ruta, " -> ", cfg$archivo, "\n", sep = "")
    api_obj$handle(
      "GET", ruta, .hend_bitacora_ruta(cfg),
      serializer = plumber::serializer_unboxed_json()
    )
  })

  api_obj$handle("GET", "/dashboard/graficos", function() {
    cat("[Plumber] /dashboard/graficos: Listando imagenes agrupadas por carpeta...\n")
    tryCatch(
      {
        grupos <- .agrupar_imagenes()
        list(
          ok = TRUE,
          carpetas = grupos,
          total_carpetas = length(grupos),
          total_imagenes = sum(vapply(grupos, function(g) length(g$imagenes), integer(1))),
          mensaje = "Imagenes listadas agrupadas por carpeta"
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en /dashboard/graficos:", conditionMessage(e), "\n")
        list(
          ok = FALSE,
          carpetas = list(),
          total_carpetas = 0,
          total_imagenes = 0,
          mensaje = paste("Error listando imagenes:", conditionMessage(e))
        )
      }
    )
  })

  cat("[Plumber] Iniciando servidor en http://0.0.0.0:8765 ...\n")
  tryCatch(
    {
      pr_run(api_obj, port = 8765, host = "0.0.0.0")
    },
    error = function(e) {
      cat("\n====================================================================\n")
      cat("ERROR al iniciar el servidor Plumber en el puerto 8765:\n")
      cat("  ", conditionMessage(e), "\n")
      cat("¿Está el puerto 8765 ya en uso por otro proceso?\n")
      cat("====================================================================\n\n")
      quit(status = 1)
    }
  )
}
