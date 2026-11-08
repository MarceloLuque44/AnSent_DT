source("cargar_proyecto.R")              # carga todas las herramientas (una vez)
res   <- preprocesar("data/result.json") # UNA vez, con todo el dataset
datos <- cargar_datos_analisis("salida") # carga mensajes_limpios.csv y tokens.csv

a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))   # un periodo
#a$nivel; a$tfidf; a$topicos$terminos; a$shallow$upos; a$libreria
# p <- graficos_periodo(a);  p$barras;  p$tiempo;  p$polar
#
# cmp <- comparar_periodos(datos, "todo_2023", "todo_2024")      # A contra B
# cmp$interpretacion;  graficos_comparacion(cmp)$arana
#
#guardar_analisis(a)   # deja CSV/PNG en salida/analisis/<periodo>/ (para el dashboard)
#

# ==============================================================================
# Fase 1: conexión con la API en Render
# ==============================================================================

# Configura antes de ejecutar:
#   Sys.setenv(ANSENT_API_URL = "https://tu-servicio.onrender.com")
#   Sys.setenv(ANSENT_API_KEY = "la-misma-R_API_KEY-de-Render")
#
# O mejor en ~/.Renviron:
#   ANSENT_API_URL=https://tu-servicio.onrender.com
#   ANSENT_API_KEY=tu_clave

if (!requireNamespace("httr2", quietly = TRUE)) {
  stop("Falta el paquete httr2. Instalalo con install.packages('httr2').", call. = FALSE)
}

api_url <- function() {
  u <- Sys.getenv("ANSENT_API_URL", "")
  if (!nzchar(u)) {
    stop("Define ANSENT_API_URL, por ejemplo https://ansent.onrender.com", call. = FALSE)
  }
  sub("/+$", "", u)
}

api_key <- function() {
  k <- Sys.getenv("ANSENT_API_KEY", "")
  if (!nzchar(k)) {
    stop("Define ANSENT_API_KEY con la R_API_KEY configurada en Render.", call. = FALSE)
  }
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
    stop(
      "API ", httr2::resp_status(resp), ": ",
      httr2::resp_body_string(resp),
      call. = FALSE
    )
  }
  resp
}

listar_cambios_api <- function(limit = 20) {
  req <- httr2::request(paste0(api_url(), "/api/cambios")) |>
    httr2::req_url_query(limit = limit) |>
    httr2::req_timeout(30)
  resp <- api_perform(req)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

enviar_cambio_api <- function(tipo, archivo, seccion = "", problema_detectado = "",
                              como_se_detecto = "", cambio_realizado = "",
                              justificacion = "", resultado = "", ejecucion_prueba = "",
                              responsable = Sys.getenv("RESPONSABLE", "R local"),
                              estado_registro = NULL) {
  body <- list(
    fecha = format(Sys.Date(), "%Y-%m-%d"),
    hora = format(Sys.time(), "%H:%M:%S"),
    tipo = tipo,
    archivo = archivo,
    seccion = seccion,
    problema_detectado = problema_detectado,
    como_se_detecto = como_se_detecto,
    cambio_realizado = cambio_realizado,
    justificacion = justificacion,
    resultado = resultado,
    ejecucion_prueba = ejecucion_prueba,
    responsable = responsable,
    estado_registro = estado_registro
  )

  req <- httr2::request(paste0(api_url(), "/api/cambios")) |>
    httr2::req_headers(`x-api-key` = api_key()) |>
    httr2::req_body_json(body) |>
    httr2::req_method("POST") |>
    httr2::req_timeout(30)

  resp <- api_perform(req)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

probar_conexion_api <- function() {
  message("POST /api/cambios ...")
  creado <- enviar_cambio_api(
    tipo = "prueba",
    archivo = "r/Peticiones.R",
    seccion = "Fase 1 - Render",
    problema_detectado = "Probar la conexión R -> Render -> Postgres",
    como_se_detecto = "Ejecución manual desde R",
    cambio_realizado = "Se envió un registro de prueba al endpoint /api/cambios",
    justificacion = "Validar el despliegue y la conexión con la base de datos",
    resultado = "ok",
    ejecucion_prueba = "manual"
  )
  print(creado)

  message("GET /api/cambios ...")
  print(listar_cambios_api(10))
  invisible(TRUE)
}

# Ejecuta una vez después de configurar las variables:
# probar_conexion_api()
