# ==============================================================================
# 02_estructura.R  -  ETAPA 2: NORMALIZACIÓN DE ESTRUCTURA Y FORMATOS
# ==============================================================================

# Patrones reutilizados en varios módulos (expresiones regulares)
RX_URL  <- "(?i:https?://|www\\.|t\\.me/)\\S+"
RX_MAIL <- "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
RX_MENC <- "(?<![A-Za-z0-9._%+-])@[A-Za-z0-9_]{3,}"
RX_TEL  <- "(?<![0-9])(?:\\+?591[ -]?)?[67][0-9]{7}(?![0-9])|\\+[0-9][0-9 -]{7,}[0-9]"
RX_HASH <- "#[\\p{L}\\p{N}_]+"

estructurar <- function(ctx, d) {
  M <- "2. Normalización de estructura y formatos"
  p <- ctx$p

  # ── 2.1 Unicode ────────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_raw -> texto_original", atributo = "texto",
    problema = "Codificación y normalización Unicode",
    accion = "Se convirtió el texto a UTF-8 y se normalizó a forma NFC (una sola representación interna por letra con tilde o eñe).",
    justificacion = "Una misma palabra con tilde puede estar escrita de dos formas internas distintas; sin normalizar se contaría como dos palabras diferentes al comparar o contar.",
    ejemplo_col = "texto_original", texto_ref = "texto_raw",
    #CÓDIGO
    codigo = {
      datos$texto_original <- stringi::stri_trans_nfc(enc2utf8(datos$texto_raw))
      datos$texto_original[is.na(datos$texto_original)] <- ""
    })

  # ── 2.2 Fechas ─────────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "fecha_raw -> fecha_hora, fecha, anio, mes, anio_mes, trimestre, dia_semana, hora",
    atributo = "fecha", problema = "Fecha como texto ISO",
    accion = "Se convirtió la fecha de texto a fecha-hora (hora local de La Paz) y se derivaron fecha, año, mes, trimestre, día de la semana y hora, todos desde la misma fecha-hora local.",
    justificacion = "El análisis por periodos y las gráficas de tendencia necesitan fechas reales y columnas temporales para agrupar y filtrar.",
    ejemplo_col = "fecha_hora", texto_ref = "fecha_raw",
    #CÓDIGO
    codigo = {
      f <- as.POSIXct(strptime(datos$fecha_raw, "%Y-%m-%dT%H:%M:%S", tz = "America/La_Paz"))
      datos$fecha_hora <- f
      datos$fecha <- as.Date(format(f, "%Y-%m-%d"))   # fecha LOCAL; as.Date(f) usa UTC y pasaba al día siguiente los mensajes de las 20:00 en adelante
      datos$anio <- as.integer(format(f, "%Y"))
      datos$mes <- as.integer(format(f, "%m"))
      datos$anio_mes <- format(f, "%Y-%m")
      datos$trimestre <- paste0(datos$anio, "-T", (datos$mes - 1) %/% 3 + 1)
      datos$dia_semana <- c("domingo", "lunes", "martes", "miércoles", "jueves",
                            "viernes", "sábado")[as.POSIXlt(f)$wday + 1]
      datos$hora <- as.integer(format(f, "%H"))
    })
  registrar_hallazgo(ctx, metodologia = M, campo = "fecha_hora", atributo = "fecha",
    problema = "Fechas no interpretables",
    accion = "Se verificó cuántas fechas no pudieron convertirse (NA).",
    justificacion = "Un NA en la fecha deja al mensaje fuera de cualquier periodo; debe ser cero o quedar justificado.",
    valor = sum(is.na(d$fecha_hora)), base = nrow(d))
  registrar_hallazgo(ctx, metodologia = M, campo = "fecha vs fecha_hora", atributo = "fecha",
    problema = "Fecha desfasada respecto a fecha_hora (zona horaria)",
    accion = "Se verificó que la fecha calendario de cada mensaje coincida con el día de fecha_hora (esperado: 0 diferencias).",
    justificacion = "Si 'fecha' se calcula en UTC y 'fecha_hora' en hora local, los mensajes de la noche pasan al día siguiente y, a fin de mes, al mes equivocado; eso falsea la comparación por periodos.",
    valor = sum(format(d$fecha_hora, "%Y-%m-%d") != format(d$fecha), na.rm = TRUE), base = nrow(d))

  
  # ── 2.3 Mensajes de servicio ───────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "tipo_registro", atributo = "categórica",
    problema = "Registros de servicio mezclados con mensajes",
    accion = "Se separaron los registros de servicio (altas, invitaciones, fijados, cambios del grupo). Quedan en mensajes_excluidos.csv.",
    justificacion = "No son expresión de los participantes. Se conservan aparte para no perder trazabilidad.",
    # CÓDIGO
    codigo = {
      es_serv <- datos$tipo_registro != "message"
      excluir(ctx, datos[es_serv, ], "Mensaje de servicio de Telegram (altas, invitaciones, fijados, cambios del grupo)")
      datos <- datos[!es_serv, ]
    })
  

  # ── 2.4 Stickers ───────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original", atributo = "texto",
    problema = "Sticker sin texto pero con emoji",
    accion = "En los stickers sin texto se usó su emoji asociado como contenido del mensaje.",
    justificacion = "El emoji del sticker expresa la emoción del usuario; descartarlo perdería datos (la licenciada indicó no perder emojis).",
    ejemplo_col = "texto_original",
    #CÓDIGO
    codigo = {
      m <- datos$tipo_contenido == "sticker" & !nzchar(trimws(datos$texto_original)) & !is.na(datos$sticker_emoji)
      datos$texto_original[m] <- datos$sticker_emoji[m]
    })
 

  # ── 2.5 Recorte por periodo (opcional) ─────────────────────────────────────────
  if (!is.null(p$fecha_inicio) || !is.null(p$fecha_fin)) {
    ini <- if (!is.null(p$fecha_inicio)) as.Date(p$fecha_inicio) else as.Date("1900-01-01")
    fin <- if (!is.null(p$fecha_fin)) as.Date(p$fecha_fin) else as.Date("2999-12-31")
    # ▌BITÁCORA OFICIAL
    d <- registrar_paso(ctx, d, metodologia = M,
      campo = "fecha", atributo = "fecha", problema = "Mensajes fuera del periodo pedido",
      accion = sprintf("Se recortó el dataset al periodo %s a %s (ambos inclusive).",
                       p$fecha_inicio %||% "inicio", p$fecha_fin %||% "fin"),
      justificacion = "La licenciada pide analizar periodos concretos (por ejemplo, una temporada) y compararlos entre sí.",
      # ▌CÓDIGO
      codigo = {
        fuera <- is.na(datos$fecha) | datos$fecha < ini | datos$fecha > fin
        excluir(ctx, datos[fuera, ], "Fuera del periodo seleccionado")
        datos <- datos[!fuera, ]
      })
  }

  # ── 2.6 Autor (datos personales) ───────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "autor_raw, autor_id -> autor", atributo = "categórica",
    problema = "Autor nulo y datos personales",
    accion = if (isTRUE(p$anonimizar_autor)) "Se reemplazó el nombre del autor por un seudónimo estable (hash del id); las cuentas sin nombre se identifican por su id."
             else "Las cuentas sin nombre se rotularon como 'desconocido'; se conserva el nombre real.",
    justificacion = "Permite agrupar por autor sin exponer nombres reales de unas 2,000 personas (protección de datos personales).",
    ejemplo_col = "autor", texto_ref = "autor_raw",
    # CÓDIGO
    codigo = {
      datos$autor_id[is.na(datos$autor_id)] <- "sin_id"
      datos$autor <- ifelse(is.na(datos$autor_raw) | !nzchar(datos$autor_raw), "desconocido", datos$autor_raw)
      if (isTRUE(ctx$p$anonimizar_autor)) {
        ids <- unique(datos$autor_id)
        seudo <- paste0("U", substr(vapply(paste0("sal-mineria-", ids), digest::digest,
                                           character(1), algo = "md5", serialize = FALSE), 1, 6))
        datos$autor <- seudo[match(datos$autor_id, ids)]
      }
    })
  

  # ── 2.7 Variables descriptivas ─────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original", atributo = "numérica / booleana",
    problema = "Faltan variables descriptivas del mensaje",
    accion = "Se derivaron: n_caracteres, n_palabras, n_enlaces, n_hashtags, n_menciones, tiene_telefono, n_emojis, emojis_lista, es_respuesta, reenviado y responde_a (numérico).",
    justificacion = "Son insumos para detectar duplicados, outliers y publicidad, y para gráficos descriptivos del análisis.",
    afectadas = sum(datos$n_enlaces > 0 | datos$n_emojis > 0),
    # CÓDIGO
    codigo = {
      t <- datos$texto_original
      datos$n_caracteres <- nchar(t)
      datos$n_palabras <- stringi::stri_count_words(t)
      datos$n_enlaces <- stringi::stri_count_regex(t, RX_URL)
      datos$n_hashtags <- stringi::stri_count_regex(t, RX_HASH)
      datos$n_menciones <- stringi::stri_count_regex(t, RX_MENC)
      datos$tiene_telefono <- stringi::stri_detect_regex(t, RX_TEL)
      em <- extraer_emojis(.emoticonos_a_emoji(t, ctx$cfg$emoticonos))   # emojis y emoticonos (:( :c <3)
      datos$n_emojis <- lengths(em)
      datos$emojis_lista <- vapply(em, paste, character(1), collapse = " ")
      datos$es_respuesta <- !is.na(datos$responde_a)
      datos$reenviado <- !is.na(datos$reenviado_de)
      datos$responde_a <- suppressWarnings(as.numeric(datos$responde_a))
    })
  d
}
