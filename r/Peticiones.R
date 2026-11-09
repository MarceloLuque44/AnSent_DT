# source("cargar_proyecto.R")              # carga todas las herramientas (una vez)
# res   <- preprocesar("data/result.json") # UNA vez, con todo el dataset
# datos <- cargar_datos_analisis("salida") # carga mensajes_limpios.csv y tokens.csv
# 
# a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))   # un periodo
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
Sys.setenv(RESPONSABLE = "GRUPO13")
Sys.setenv(ANSENT_API_URL = "http://localhost:3000")
Sys.setenv(ANSENT_API_KEY = "784b578e8cd3fcf26996d65403775af39b42c37f423acdfe1397278549a28c81")
#
# O mejor en ~/.Renviron:
#   ANSENT_API_URL=https://tu-servicio.onrender.com
#   ANSENT_API_KEY=tu_clave
if (!requireNamespace("httr2", quietly = TRUE)) {
  install.packages('httr2')
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

# ==============================================================================
# enviar_niveles_api(): manda a$nivel al backend para el gráfico de barras
# POST /api/dashboard/niveles
# ==============================================================================
enviar_niveles_api <- function(a, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (is.null(a$nivel) || is.null(a$periodo)) {
    stop("'a' debe ser la salida de analizar_periodo().", call. = FALSE)
  }

  niv <- a$nivel[order(-a$nivel$nivel_pct), , drop = FALSE]
  niv <- niv[, c("sentimiento", "nivel_pct", "mensajes_pct", "n_mensajes"), drop = FALSE]

  body_niv <- list(
    periodo = list(
      nombre = a$periodo$nombre,
      inicio = as.character(a$periodo$inicio),
      fin    = as.character(a$periodo$fin)
    ),
    n_mensajes  = a$n_mensajes,
    responsable = responsable,
    datos       = niv
  )

  .post <- function(path, body, timeout = 60) {
    req <- httr2::request(paste0(api_url(), path)) |>
      httr2::req_headers(`x-api-key` = api_key()) |>
      httr2::req_body_json(body, auto_unbox = TRUE) |>
      httr2::req_method("POST") |>
      httr2::req_timeout(timeout)
    resp <- api_perform(req)
    httr2::resp_body_json(resp, simplifyVector = TRUE)
  }

  guardado <- .post("/api/dashboard/niveles", body_niv)

  # --- Serie mensual (g_tiempo, g_apilado, g_dispersion) ----------------------
  if (!is.null(a$serie) && nrow(a$serie)) {
    body_serie <- list(
      periodo = list(
        nombre = a$periodo$nombre,
        inicio = as.character(a$periodo$inicio),
        fin    = as.character(a$periodo$fin)
      ),
      n_mensajes  = a$n_mensajes,
      responsable = responsable,
      datos       = a$serie[, c("anio_mes", "sentimiento", "pct", "n_mensajes"), drop = FALSE]
    )
    tryCatch({
      guardado_serie <- .post("/api/dashboard/serie", body_serie)
      message("Serie mensual enviada: ", guardado_serie$filas, " filas")
    }, error = function(e) message("No se pudo enviar la serie mensual: ", conditionMessage(e)))
  }

  # --- Sankey: tópico x sentimiento dominante (g_sankey) ----------------------
  if (!is.null(a$topicos) && !is.null(a$mensajes) && nrow(a$mensajes)) {
    m <- mensajes_con_topico(a$mensajes, a$topicos)
    nom <- nombres_sentimientos(m)
    m <- m[!is.na(m$topico) & m$sentimiento_dominante %in% nom, , drop = FALSE]
    if (nrow(m)) {
      cruz <- as.data.frame.table(
        table(topico = m$topico, sentimiento_dominante = m$sentimiento_dominante),
        stringsAsFactors = FALSE
      )
      cruz <- cruz[cruz$Freq > 0, , drop = FALSE]
      names(cruz) <- c("topico", "sentimiento_dominante", "freq")
      body_sankey <- list(
        periodo = list(
          nombre = a$periodo$nombre,
          inicio = as.character(a$periodo$inicio),
          fin    = as.character(a$periodo$fin)
        ),
        responsable = responsable,
        datos = cruz
      )
      tryCatch({
        guardado_sankey <- .post("/api/dashboard/sankey", body_sankey)
        message("Sankey enviado: ", guardado_sankey$filas, " filas")
      }, error = function(e) message("No se pudo enviar el sankey: ", conditionMessage(e)))
    } else {
      message("Sankey: no hay cruces topico x sentimiento dominante válidos para enviar.")
    }
  }

  guardado
}

# ==============================================================================
# enviar_graficos_api(): manda los graficos #9-14 al backend
# POST /api/dashboard/graficos (un solo POST, cada grafico opcional)
# ==============================================================================
enviar_graficos_api <- function(a, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (is.null(a$periodo)) {
    stop("'a' debe ser la salida de analizar_periodo().", call. = FALSE)
  }

  .post <- function(path, body, timeout = 60) {
    req <- httr2::request(paste0(api_url(), path)) |>
      httr2::req_headers(`x-api-key` = api_key()) |>
      httr2::req_body_json(body, auto_unbox = TRUE) |>
      httr2::req_method("POST") |>
      httr2::req_timeout(timeout)
    resp <- api_perform(req)
    httr2::resp_body_json(resp, simplifyVector = TRUE)
  }

  periodo <- list(
    nombre = a$periodo$nombre,
    inicio = as.character(a$periodo$inicio),
    fin    = as.character(a$periodo$fin)
  )

  graficos <- list()

  # --- 9. TF-IDF --------------------------------------------------------------
  if (!is.null(a$tfidf) && nrow(a$tfidf)) {
    graficos$tfidf <- a$tfidf[, c("doc", "token", "n", "tf", "idf", "tf_idf"), drop = FALSE]
  }

  # --- 10. Topicos (terminos) -------------------------------------------------
  if (!is.null(a$topicos) && !is.null(a$topicos$terminos) && nrow(a$topicos$terminos)) {
    graficos$topicos <- a$topicos$terminos[, c("topico", "etiqueta", "termino", "beta"), drop = FALSE]
  }

  # --- 11. Topicos en el tiempo (peso_mes) ------------------------------------
  if (!is.null(a$topicos) && !is.null(a$topicos$peso_mes) && nrow(a$topicos$peso_mes)) {
    graficos$topicos_tiempo <- a$topicos$peso_mes[, c("anio_mes", "topico", "etiqueta", "peso_pct"), drop = FALSE]
  }

  # --- 12. Shallow linguistic (upos) ------------------------------------------
  if (!is.null(a$shallow) && !is.null(a$shallow$upos) && nrow(a$shallow$upos)) {
    graficos$upos <- a$shallow$upos[, c("clase", "n", "pct"), drop = FALSE]
  }

  # --- 13. Nivel de mensaje representante -------------------------------------
  m <- a$mensajes
  if (!is.null(m) && nrow(m)) {
    ej <- if ("hits_total" %in% names(m)) m[which.max(m$hits_total), , drop = FALSE] else m[1, , drop = FALSE]
    graficos$nivel_mensaje <- nivel_mensaje(ej, m)
  }

  # --- 14. Calor (dia_semana x hora) ------------------------------------------
  if (!is.null(m) && nrow(m) && all(c("dia_semana", "hora") %in% names(m))) {
    cal <- as.data.frame.table(
      table(dia = m$dia_semana, hora = m$hora),
      stringsAsFactors = FALSE
    )
    cal <- cal[cal$Freq > 0, , drop = FALSE]
    names(cal) <- c("dia", "hora", "freq")
    cal$hora <- as.integer(as.character(cal$hora))
    cal$freq <- as.integer(as.character(cal$freq))
    if (nrow(cal)) {
      graficos$calor <- cal
    }
  }

  body <- list(
    periodo = periodo,
    n_mensajes  = a$n_mensajes,
    responsable = responsable,
    graficos    = graficos
  )

  tryCatch({
    guardado <- .post("/api/dashboard/graficos", body)
    n <- sum(vapply(graficos, nrow, integer(1)))
    message("Graficos enviados: ", n, " filas totales")
    guardado
  }, error = function(e) {
    message("No se pudieron enviar los graficos: ", conditionMessage(e))
    invisible(NULL)
  })
}

# ==============================================================================
# enviar_graficos_adicionales_api(): manda los graficos #15-24 al backend
# POST /api/dashboard/graficos (un solo POST, cada grafico opcional).
# G25 (diferencia) requiere cmp de dos periodos; no va aqui.
# ==============================================================================
enviar_graficos_adicionales_api <- function(a, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (is.null(a$periodo)) {
    stop("'a' debe ser la salida de analizar_periodo().", call. = FALSE)
  }

  .post <- function(path, body, timeout = 60) {
    req <- httr2::request(paste0(api_url(), path)) |>
      httr2::req_headers(`x-api-key` = api_key()) |>
      httr2::req_body_json(body, auto_unbox = TRUE) |>
      httr2::req_method("POST") |>
      httr2::req_timeout(timeout)
    resp <- api_perform(req)
    httr2::resp_body_json(resp, simplifyVector = TRUE)
  }

  periodo <- list(
    nombre = a$periodo$nombre,
    inicio = as.character(a$periodo$inicio),
    fin    = as.character(a$periodo$fin)
  )

  m <- a$mensajes
  if (is.null(m) || !nrow(m)) {
    message("No hay mensajes en a$mensajes; no hay graficos adicionales que enviar.")
    return(invisible(NULL))
  }

  # Asegurar columnas de fecha/hora que pueden faltar en a$mensajes
  if (!inherits(m$fecha, "Date")) m$fecha <- as.Date(m$fecha)
  if (!"hora" %in% names(m) || all(is.na(m$hora))) m$hora <- as.integer(format(m$fecha, "%H"))
  if (!"dia_semana" %in% names(m) || all(is.na(m$dia_semana))) m$dia_semana <- weekdays(m$fecha)
  if (!"polaridad_msg" %in% names(m) || all(is.na(m$polaridad_msg))) m$polaridad_msg <- NA_character_
  if (!"sentimiento_dominante" %in% names(m)) m$sentimiento_dominante <- NA_character_

  nom <- nombres_sentimientos(m)
  graficos <- list()

  # --- 15. Volumen -------------------------------------------------------------
  v <- as.data.frame(table(fecha = m$fecha), stringsAsFactors = FALSE)
  if (nrow(v)) {
    names(v) <- c("fecha", "freq")
    v$fecha <- as.character(v$fecha)
    v$freq <- as.integer(v$freq)
    graficos$volumen <- v
  }

  # --- 16. Evolucion anual -----------------------------------------------------
  if (length(nom) && length(unique(format(m$fecha, "%Y"))) >= 2) {
    med <- vapply(nom, function(s) mean(m[[paste0("pct_", s)]], na.rm = TRUE), numeric(1))
    sel <- names(sort(med, decreasing = TRUE))[seq_len(min(6, length(nom)))]
    anio <- format(m$fecha, "%Y")
    ev <- do.call(rbind, lapply(sel, function(s) {
      aa <- tapply(m[[paste0("pct_", s)]], anio, mean, na.rm = TRUE)
      data.frame(anio = names(aa), sentimiento = s, pct = as.numeric(aa), stringsAsFactors = FALSE)
    }))
    if (nrow(ev)) {
      ev$anio <- as.integer(ev$anio); ev$pct <- as.numeric(ev$pct)
      graficos$evolucion_anual <- ev
    }
  }

  # --- 17. Sent heat (mes x sentimiento) ---------------------------------------
  ser <- tryCatch(serie_periodo(m), error = function(e) NULL)
  if (!is.null(ser) && nrow(ser)) {
    sh <- ser[, c("fecha", "sentimiento", "pct"), drop = FALSE]
    sh$fecha <- as.character(sh$fecha); sh$pct <- as.numeric(sh$pct)
    graficos$sent_heat <- sh
  }

  # --- 18. Dominante (fecha x dom) --------------------------------------------
  d <- m[m$sentimiento_dominante %in% nom, , drop = FALSE]
  if (nrow(d)) {
    tab <- as.data.frame.table(table(fecha = d$fecha, dom = d$sentimiento_dominante), stringsAsFactors = FALSE)
    tab <- tab[tab$Freq > 0, , drop = FALSE]
    if (nrow(tab)) {
      names(tab) <- c("fecha", "dom", "freq")
      tab$fecha <- as.character(tab$fecha); tab$freq <- as.integer(tab$freq)
      graficos$dominante <- tab
    }
  }

  # --- 19. Polaridad tiempo ----------------------------------------------------
  cat <- ifelse(!(m$sentimiento_dominante %in% nom), "sin sentimiento detectado", as.character(m$polaridad_msg))
  cat <- factor(cat, levels = c("positivo", "neutral", "negativo", "sin sentimiento detectado"))
  tab <- as.data.frame.table(table(fecha = m$fecha, cat = cat), stringsAsFactors = FALSE)
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  if (nrow(tab)) {
    names(tab) <- c("fecha", "cat", "freq")
    tab$fecha <- as.character(tab$fecha); tab$freq <- as.integer(tab$freq)
    graficos$polaridad_tiempo <- tab
  }

  # --- 20. Sent hora heat (hora x sentimiento) ---------------------------------
  if (length(nom)) {
    L <- do.call(rbind, lapply(nom, function(s) {
      aa <- tapply(m[[paste0("pct_", s)]], factor(m$hora, levels = 0:23), mean, na.rm = TRUE)
      data.frame(hora = 0:23, sentimiento = s, pct = as.numeric(aa), stringsAsFactors = FALSE)
    }))
    L <- L[!is.na(L$pct), , drop = FALSE]
    if (nrow(L)) {
      L$hora <- as.integer(L$hora); L$pct <- as.numeric(L$pct)
      graficos$sent_hora_heat <- L
    }
  }

  # --- 21. Correlacion ---------------------------------------------------------
  if (length(nom) >= 2) {
    x <- m[paste0("pct_", nom)]; names(x) <- nom
    x <- x[, vapply(x, function(z) isTRUE(stats::sd(z, na.rm = TRUE) > 0), logical(1)), drop = FALSE]
    if (ncol(x) >= 2) {
      cm <- stats::cor(x, use = "pairwise.complete.obs")
      cr <- as.data.frame(as.table(cm)); names(cr) <- c("a", "b", "r")
      cr$r <- as.numeric(cr$r)
      if (nrow(cr)) graficos$correlacion <- cr
    }
  }

  # --- 22. Palabras ------------------------------------------------------------
  x <- m$texto_tokens[!is.na(m$texto_tokens) & nzchar(m$texto_tokens)]
  tk <- unlist(strsplit(x, " ", fixed = TRUE)); tk <- tk[nzchar(tk)]
  if (length(tk)) {
    t <- utils::head(sort(table(tk), decreasing = TRUE), 25)
    graficos$palabras <- data.frame(palabra = names(t), n = as.integer(t), stringsAsFactors = FALSE)
  }

  # --- 23. Emojis --------------------------------------------------------------
  e <- m$emojis_lista[!is.na(m$emojis_lista) & m$emojis_lista != "ninguno"]
  e <- unlist(strsplit(e, " ", fixed = TRUE)); e <- e[nzchar(e)]
  if (length(e)) {
    t <- utils::head(sort(table(e), decreasing = TRUE), 20)
    em <- data.frame(emoji = names(t), n = as.integer(t), sentimiento = "sin dato",
                     etiqueta = names(t), stringsAsFactors = FALSE)
    f_dic <- "config/emojis.csv"
    if (file.exists(f_dic)) {
      dic <- tryCatch(readr::read_csv(f_dic, show_col_types = FALSE, progress = FALSE), error = function(e) NULL)
      if (!is.null(dic) && all(c("emoji", "sentimiento") %in% names(dic))) {
        i <- match(em$emoji, dic$emoji)
        s <- dic$sentimiento[i]
        em$sentimiento <- ifelse(is.na(s) | s == "", "sin dato", s)
        if ("significado_es" %in% names(dic)) {
          z <- dic$significado_es[i]
          em$etiqueta <- ifelse(is.na(z) | z == "", em$emoji, z)
        }
      }
    }
    em$etiqueta <- make.unique(em$etiqueta)
    graficos$emojis <- em
  }

  # --- 24. Libreria vs propios -------------------------------------------------
  if (!is.null(a$comparacion) && !is.null(a$comparacion$distribucion)) {
    dist <- a$comparacion$distribucion
    lv <- rbind(
      data.frame(polaridad = dist$polaridad, fuente = "diccionario propio", pct = dist$propios_pct, stringsAsFactors = FALSE),
      data.frame(polaridad = dist$polaridad, fuente = "libreria (syuzhet)", pct = dist$libreria_pct, stringsAsFactors = FALSE)
    )
    lv$pct <- as.numeric(lv$pct)
    graficos$libreria_vs_propios <- lv
  }

  body <- list(
    periodo = periodo,
    n_mensajes  = a$n_mensajes,
    responsable = responsable,
    graficos    = graficos
  )

  tryCatch({
    guardado <- .post("/api/dashboard/graficos", body)
    n <- sum(vapply(graficos, nrow, integer(1)))
    message("Graficos adicionales enviados: ", n, " filas totales")
    guardado
  }, error = function(e) {
    message("No se pudieron enviar los graficos adicionales: ", conditionMessage(e))
    invisible(NULL)
  })
}

# ==============================================================================
# enviar_comparacion_api(): manda cmp$niveles (dos periodos) para el gráfico
# de barras agrupadas. POST /api/dashboard/comparaciones
# ==============================================================================
enviar_comparacion_api <- function(cmp, responsable = Sys.getenv("RESPONSABLE", "R local")) {
  if (!inherits(cmp, "comparacion_periodos")) {
    stop("'cmp' debe ser la salida de comparar_periodos().", call. = FALSE)
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

  req <- httr2::request(paste0(api_url(), "/api/dashboard/comparaciones")) |>
    httr2::req_headers(`x-api-key` = api_key()) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_method("POST") |>
    httr2::req_timeout(60)

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
#probar_conexion_api()

# Con un análisis ya calculado, sube los niveles al dashboard:
if (exists("a") && inherits(a, "analisis_periodo")) {
  guardado <- enviar_niveles_api(a)
  print(guardado)
  guardado_graficos <- tryCatch(enviar_graficos_api(a), error = function(e) message("Graficos: ", conditionMessage(e)))
  print(guardado_graficos)
  guardado_graficos_adicionales <- tryCatch(enviar_graficos_adicionales_api(a), error = function(e) message("Graficos adicionales: ", conditionMessage(e)))
  print(guardado_graficos_adicionales)
} else {
  message("Crea 'a' con analizar_periodo() y luego ejecuta enviar_niveles_api(a) y enviar_graficos_api(a).")
}

# Con una comparación ya calculada, sube los dos periodos al dashboard:
if (exists("cmp") && inherits(cmp, "comparacion_periodos")) {
  guardada_cmp <- enviar_comparacion_api(cmp)
  print(guardada_cmp)
} else {
  message("Crea 'cmp' con comparar_periodos() y luego ejecuta enviar_comparacion_api(cmp).")
}
