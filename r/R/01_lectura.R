# ==============================================================================
# 01_lectura.R  -  LEER EL ARCHIVO, CARGAR DICCIONARIOS Y AUDITAR
# ------------------------------------------------------------------------------
# Aquí se "declara" el archivo de entrada: preprocesar("data/result.json")
# llama a leer_entrada(), que acepta el JSON de Telegram o un CSV equivalente.
# ==============================================================================

# ------------------------------------------------------------------------------
# A. LECTURA DEL JSON / CSV
# ------------------------------------------------------------------------------

# En el JSON de Telegram el campo "text" a veces es texto y a veces una lista de
# fragmentos (enlaces, negritas...). Esta función lo convierte siempre en texto plano.

aplanar_texto <- function(t) {
  if (is.null(t)) return(list(texto = "", era_lista = FALSE))
  if (is.character(t)) return(list(texto = paste(t, collapse = ""), era_lista = FALSE))
  partes <- vapply(t, function(p) {
    if (is.character(p)) paste(p, collapse = "")
    else if (is.list(p) && !is.null(p$text)) as.character(p$text)
    else ""
  }, character(1))
  list(texto = paste(partes, collapse = ""), era_lista = TRUE)
}


leer_entrada <- function(ruta, chat = NULL) {
  if (!file.exists(ruta)) stop("No existe el archivo: ", ruta,
                               "\n  (carpeta de trabajo actual: ", getwd(), ")")
  ext <- tolower(tools::file_ext(ruta))
  if (ext == "json") leer_telegram_json(ruta, chat)
  else if (ext %in% c("csv", "tsv")) leer_csv_generico(ruta)
  else stop("Formato no soportado (usa el .json de Telegram o un .csv): ", ext)
}


leer_telegram_json <- function(ruta, chat = NULL) {
  j <- jsonlite::fromJSON(ruta, simplifyVector = FALSE)
  if (!is.null(j$chats)) {                       # "Exportar todos los chats"
    lista <- j$chats$list
    nombres <- vapply(lista, function(c) c$name %||% "(sin nombre)", character(1))
    if (is.null(chat)) {
      if (length(lista) == 1) chat <- 1
      else stop("El archivo tiene varios chats: ",
                paste(seq_along(nombres), nombres, sep = ": ", collapse = " | "),
                ". Usa preprocesar(..., chat = <número>).")
    }
    j <- lista[[chat]]
  }
  if (is.null(j$messages))
    stop("No se encontró el campo 'messages'. Verifica que sea el result.json de Telegram.")
  msgs <- j$messages
  g <- function(m, k) { v <- m[[k]]; if (is.null(v)) NA else v }
  chr <- function(f) vapply(msgs, function(m) { v <- f(m); if (length(v) != 1) NA_character_ else as.character(v) }, character(1))

  txt <- lapply(msgs, function(m) aplanar_texto(m$text))
  reac <- function(m) {
    r <- m$reactions
    if (is.null(r) || !length(r)) return(NA_character_)
    r <- Filter(function(x) !is.null(x$emoji), r)
    if (!length(r)) return(NA_character_)
    paste0(vapply(r, function(x) paste0(x$emoji, ":", x$count %||% 1), character(1)), collapse = "|")
  }
  tipo <- function(m) {
    if (!is.null(m$photo)) "foto"
    else if (!is.null(m$media_type))
      switch(m$media_type, sticker = "sticker", video_file = "video", video_message = "video",
             animation = "gif", voice_message = "nota_de_voz", audio_file = "audio", m$media_type)
    else if (!is.null(m$poll)) "encuesta"
    else if (!is.null(m$file)) "archivo"
    else "texto"
  }
  data.frame(
    id_mensaje      = vapply(msgs, function(m) as.numeric(g(m, "id")), numeric(1)),
    tipo_registro   = chr(function(m) g(m, "type")),
    fecha_raw       = chr(function(m) g(m, "date")),
    autor_raw       = chr(function(m) g(m, "from")),
    autor_id        = chr(function(m) g(m, "from_id")),
    responde_a      = chr(function(m) g(m, "reply_to_message_id")),
    editado         = vapply(msgs, function(m) !is.null(m$edited), logical(1)),
    reenviado_de    = chr(function(m) g(m, "forwarded_from")),
    texto_raw       = vapply(txt, function(x) x$texto, character(1)),
    texto_era_lista = vapply(txt, function(x) x$era_lista, logical(1)),
    tipo_contenido  = vapply(msgs, tipo, character(1)),
    sticker_emoji   = chr(function(m) g(m, "sticker_emoji")),
    reacciones      = vapply(msgs, reac, character(1)),
    accion_servicio = chr(function(m) g(m, "action")),
    stringsAsFactors = FALSE
  )
}


# CSV ya convertido: acepta nombres de columna alternativos (text/texto, date/fecha...)
leer_csv_generico <- function(ruta) {
  d <- readr::read_delim(ruta, delim = if (grepl("\\.tsv$", ruta, ignore.case = TRUE)) "\t" else ",",
                         col_types = readr::cols(.default = "c"), progress = FALSE,
                         show_col_types = FALSE)
  names(d) <- tolower(names(d))
  pick <- function(opts) { h <- intersect(opts, names(d)); if (length(h)) d[[h[1]]] else NULL }
  txt <- pick(c("texto_original", "text", "texto", "mensaje", "message"))
  fec <- pick(c("fecha_hora", "date", "fecha", "datetime"))
  if (is.null(txt) || is.null(fec))
    stop("El CSV necesita al menos una columna de texto (text/texto) y una de fecha (date/fecha).")
  n <- nrow(d)
  def <- function(x, v = NA_character_) if (is.null(x)) rep(v, n) else x
  fec <- sub(" ", "T", substr(fec, 1, 19))
  data.frame(
    id_mensaje      = if (is.null(pick(c("id", "id_mensaje")))) seq_len(n) else as.numeric(pick(c("id", "id_mensaje"))),
    tipo_registro   = "message",
    fecha_raw       = fec,
    autor_raw       = def(pick(c("from", "autor", "usuario"))),
    autor_id        = def(pick(c("from_id", "autor_id")), NA_character_),
    responde_a      = def(pick(c("reply_to_message_id", "responde_a"))),
    editado         = FALSE,
    reenviado_de    = def(pick(c("forwarded_from", "reenviado_de"))),
    texto_raw       = ifelse(is.na(txt), "", txt),
    texto_era_lista = FALSE,
    tipo_contenido  = "texto",
    sticker_emoji   = NA_character_,
    reacciones      = def(pick(c("reacciones", "reactions"))),
    accion_servicio = NA_character_,
    stringsAsFactors = FALSE
  )
}


# ------------------------------------------------------------------------------
# B. DICCIONARIOS EXTERNOS (carpeta config/): nada fijo dentro del código
# ------------------------------------------------------------------------------
cargar_config <- function(dir_config, sentimientos_activos = NULL) {
  ruta <- function(f) file.path(dir_config, f)
  req <- c("sentimientos.json", "emojis.csv", "stopwords.csv", "palabras_anuncio.csv", "genero.csv",
           "abreviaturas.csv", "emoticonos.csv", "codigos_materia.csv")
  falta <- req[!file.exists(ruta(req))]
  if (length(falta)) stop("Faltan archivos en '", dir_config, "': ", paste(falta, collapse = ", "),
                          "\n  (¿estás en la carpeta del proyecto? carpeta actual: ", getwd(), ")")

  sj <- jsonlite::fromJSON(ruta("sentimientos.json"), simplifyVector = TRUE)$sentimientos
  if (!is.null(sentimientos_activos)) {
    desconocidos <- setdiff(sentimientos_activos, sj$nombre)
    if (length(desconocidos)) stop("Sentimientos que no existen en el diccionario: ",
                                   paste(desconocidos, collapse = ", "))
    sj$activo <- sj$nombre %in% sentimientos_activos
  }
  sj <- sj[order(sj$orden), ]

  leer <- function(f) readr::read_csv(ruta(f), col_types = readr::cols(.default = "c"),
                                      progress = FALSE, na = character())
  emo <- leer("emojis.csv")
  for (cn in c("significado_es", "sentimiento", "polaridad", "nombre_unicode"))
    if (!cn %in% names(emo)) emo[[cn]] <- ""
  emo <- emo[, c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")]
  emo$emoji <- emoji_clave(emo$emoji)
  emo$polaridad <- suppressWarnings(as.numeric(emo$polaridad))
  emo$polaridad[is.na(emo$polaridad)] <- 0
  emo <- emo[!duplicated(emo$emoji), ]
  # el sentimiento de cada emoji debe ser "neutral" o un nombre EXACTO de sentimientos.json; si no, el
  # emoji se traduce pero nunca suma a ningún sentimiento (pasaba con "tranquilidad", "cansancio", "amor")
  malos <- !(emo$sentimiento %in% c("", "neutral", sj$nombre))
  if (any(malos))
    stop("config/emojis.csv tiene sentimientos que no existen en sentimientos.json: ",
         paste(unique(emo$sentimiento[malos]), collapse = ", "), "\n  Emojis afectados: ",
         paste(utils::head(emo$emoji[malos], 8), collapse = " "),
         "\n  Usa 'neutral' o uno de: ", paste(sj$nombre, collapse = ", "))

  # huella de cada diccionario: sirve para dejar constancia en bitacora_limpia.xlsx (hoja "Parametros") de qué versión se usó
  hashes <- vapply(req, function(f) digest::digest(file = ruta(f), algo = "md5"), character(1))
  list(sent = sj, emojis = emo, stop = leer("stopwords.csv"), anuncio = leer("palabras_anuncio.csv"),
       genero = leer("genero.csv"), abrev = leer("abreviaturas.csv"),
       emoticonos = leer("emoticonos.csv"), materias = leer("codigos_materia.csv"), hashes = hashes, dir = dir_config)
}


# ------------------------------------------------------------------------------
# C. ETAPA 1: AUDITORÍA Y PERFILADO INICIAL (solo mira, no modifica nada)
# ------------------------------------------------------------------------------
auditar_entrada <- function(ctx, d) {
  M <- "1. Auditoría y perfilado inicial"
  N <- nrow(d)
  # optional = TRUE: una fecha no ISO no debe abortar la auditoria; se cuenta
  # despues en "Fechas no interpretables".
  fechas_aud <- suppressWarnings(as.Date(substr(d$fecha_raw, 1, 10), optional = TRUE))
  rf <- suppressWarnings(range(fechas_aud, na.rm = TRUE))
  if (!all(is.finite(rf))) rf <- c(as.Date(NA), as.Date(NA))

  # ▌BITÁCORA OFICIAL
  registrar_hallazgo(ctx, metodologia = M, campo = "(todo el dataset)", atributo = "estructura",
    problema = "Volumen y rango temporal",
    accion = sprintf("Se leyeron %s registros del archivo '%s'. Rango de fechas: %s a %s.",
                     .fmt(N), basename(ctx$p$ruta_archivo), format(rf[1]), format(rf[2])),
    justificacion = "Todo preprocesamiento parte de conocer el tamaño y el periodo cubierto, para poder medir el impacto de cada paso y recortar por periodos.",
    valor = nrow(d), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "type / action", atributo = "categórica",
    problema = "Registros que no son mensajes (servicio)",
    accion = "Se contaron los registros de servicio de Telegram (altas por enlace, invitaciones, fijados, cambios del grupo). Se separan más adelante.",
    justificacion = "No contienen opinión ni sentimiento de los participantes; mantenerlos sesgaría las frecuencias y los periodos.",
    valor = sum(d$tipo_registro != "message"), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "text", atributo = "texto",
    problema = "Campo mixto (texto o lista de fragmentos)",
    accion = "Se detectó que 'text' llega como lista (enlaces, negritas, hashtags) en parte de los mensajes; la lectura lo unifica a texto plano con aplanar_texto().",
    justificacion = "Un campo con dos tipos de dato impide tokenizar y contar de forma homogénea (normalización de estructura).",
    valor = sum(d$texto_era_lista), base = N, script = paste(deparse(aplanar_texto), collapse = "\n"))

  sin_txt <- d$tipo_registro == "message" & !nzchar(trimws(d$texto_raw))
  registrar_hallazgo(ctx, metodologia = M, campo = "text", atributo = "texto",
    problema = "Mensajes sin texto (valores faltantes)",
    accion = "Se contaron los mensajes que no tienen texto (solo foto, video, sticker, archivo o audio).",
    justificacion = "El análisis de sentimiento por texto no puede evaluarlos; se tratan en la etapa de valores faltantes.",
    valor = sum(sin_txt), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "from / from_id", atributo = "categórica",
    problema = "Autor nulo (cuenta eliminada)",
    accion = "Se contaron mensajes cuyo campo 'from' viene vacío (cuentas eliminadas); se conservan identificados por from_id.",
    justificacion = "Evita perder mensajes válidos; el identificador permite seguir agrupando por autor.",
    valor = sum(d$tipo_registro == "message" & is.na(d$autor_raw)), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "forwarded_from", atributo = "categórica",
    problema = "Mensajes reenviados",
    accion = "Se contaron mensajes reenviados de otros canales o personas; serán una señal para detectar publicidad.",
    justificacion = "Los reenviados suelen ser contenido ajeno al grupo (anuncios, cursos) y no reflejan el sentimiento de los miembros.",
    valor = sum(!is.na(d$reenviado_de)), base = N)
  d
}
