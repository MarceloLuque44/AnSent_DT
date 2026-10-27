# plumber_api.R — API de Plumber para el proyecto de análisis de sentimientos
# Iniciar:   Rscript r/plumber_api.R   (desde la raíz del proyecto)
#            Rscript plumber_api.R      (desde la carpeta r/)
# Puerto:    8765
#
# Este script:
#   1. Valida que los paquetes R requeridos estén instalados.
#   2. Carga las utilidades del proyecto (cargar_proyecto.R + 00_main.R).
#   3. Expone endpoints REST: /__ping__, /dataset/summary, /charts, /preprocesar.
#   4. Notifica a Express (puerto 3000) al terminar un preprocesamiento.
#   5. Imprime mensajes de diagnóstico claros si algo falla.

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

cat("[Plumber] Paquetes R cargados: plumber, jsonlite, httr\n")

# ------------------------------------------------------------------------------
# 1. Determinar la carpeta del proyecto R (r/)
# ------------------------------------------------------------------------------
# Usar la ubicación de este script como referencia (funciona con Rscript).
args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  script_path <- sub("^--file=", "", file_arg)
  SCRIPT_DIR <- dirname(normalizePath(script_path, winslash = "/"))
} else {
  # Fallback: usar el directorio de trabajo actual
  SCRIPT_DIR <- normalizePath(getwd(), winslash = "/")
}
PROYECTO <- SCRIPT_DIR

cat("[Plumber] Carpeta del proyecto R:", PROYECTO, "\n")

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
    if (file.exists(ruta)) {
      cat("[Plumber] Leyendo dataset:", ruta, "\n")
      state$dataset <- leer_entrada(ruta)
      cat("[Plumber] Dataset cargado:", nrow(state$dataset), "filas\n")
    } else {
      cat("[Plumber] AVISO: no se encontro", ruta, ". Usando dataset de ejemplo.\n")
      state$dataset <- data.frame(
        id_mensaje = 1:5,
        fecha_raw = format(Sys.Date() - 0:4),
        autor_raw = c("a", "b", "c", "d", "e"),
        texto_raw = c("me encanta", "horrible servicio", "regular", "excelente", "malo"),
        tipo_contenido = "texto",
        stringsAsFactors = FALSE
      )
    }
  }
  state$dataset
}

#* Resumen del dataset
#* @get /dataset/summary
function() {
  tryCatch(
    {
      df <- cargar_dataset()
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

#* Gráficos en formato JSON (compatible con ECharts en el frontend)
#* @get /charts
function() {
  tryCatch(
    {
      df <- cargar_dataset()
      cat("[Plumber] Generando graficos para", nrow(df), "filas\n")
      list(
        data = generar_graficos(df),
        version = state$version
      )
    },
    error = function(e) {
      cat("[Plumber] ERROR en /charts:", conditionMessage(e), "\n")
      list(error = conditionMessage(e), data = list())
    }
  )
}

#* Ejecutar preprocesamiento (usa preprocesar() de 00_main.R del proyecto)
#* @post /preprocesar
function() {
  cat("[Plumber] Iniciando preprocesamiento...\n")
  df <- cargar_dataset()

  # Guardar una copia del dataset actual como entrada del preprocesamiento
  entrada_path <- file.path(PROYECTO, "data", "plumber_entrada.json")
  jsonlite::write_json(df, entrada_path, auto_unbox = TRUE, pretty = FALSE)

  # Ejecutar el preprocesamiento real del proyecto (00_main.R -> preprocesar())
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
    # Notificar a Express: bitacora + evento SSE dataset:update
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
# 6. Configuración y arranque del servidor
# ------------------------------------------------------------------------------
# Arranque explícito del servidor Plumber (registro manual de endpoints)
cat("[Plumber] API definida. Puerto: 8765\n")
cat("[Plumber] Endpoints:\n")
cat("  GET  http://localhost:8765/__ping__        - salud\n")
cat("  GET  http://localhost:8765/dataset/summary - resumen del dataset\n")
cat("  GET  http://localhost:8765/charts          - graficos JSON para ECharts\n")
cat("  POST http://localhost:8765/preprocesar     - ejecutar preprocesamiento\n")

# Guard contra ejecuciones duplicadas
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

  # Registrar endpoints manualmente
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
        df <- cargar_dataset()
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

  api_obj$handle("GET", "/charts", function() {
    tryCatch(
      {
        df <- cargar_dataset()
        cat("[Plumber] Generando graficos para", nrow(df), "filas\n")
        list(
          data = generar_graficos(df),
          version = state$version
        )
      },
      error = function(e) {
        cat("[Plumber] ERROR en /charts:", conditionMessage(e), "\n")
        list(error = conditionMessage(e), data = list())
      }
    )
  })

  api_obj$handle("POST", "/preprocesar", function() {
    cat("[Plumber] Iniciando preprocesamiento...\n")
    df <- cargar_dataset()

    entrada_path <- file.path(PROYECTO, "data", "plumber_entrada.json")
    jsonlite::write_json(df, entrada_path, auto_unbox = TRUE, pretty = FALSE)

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
