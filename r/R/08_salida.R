# ==============================================================================
# 08_salida.R  -  ETAPAS 12 y 13: VALORES FALTANTES FINALES, VALIDACIÓN Y EXPORTACIÓN
# ==============================================================================

# Qué valor se pone cuando una celda queda vacía, según el significado de la columna.
# (Para cualquier otra columna: número -> 0, lógico -> FALSE, texto -> "ninguno".)
REGLAS_NULOS <- list(
  reenviado_de          = "original",   # no es reenviado: el mensaje es original del grupo
  responde_a            = 0,            # no responde a ningún mensaje (es_respuesta = FALSE)
  reacciones            = "ninguna",
  emojis_lista          = "ninguno",
  sentimiento_emoji     = "sin_emoji",  # (n_emojis = 0 lo confirma)
  polaridad_emoji       = 0,
  sentimiento_dominante = "ninguno",    # el mensaje no coincide con ningún sentimiento
  motivo_publicidad     = "ninguno"
  # texto_tokens NO se rellena: si todas sus palabras eran stopwords queda vacío (n_tokens = 0).
  # "ninguno" es una negación REAL que se conserva en stopwords.csv; como relleno se confundía con
  # ella y entraba al TF-IDF, a los n-gramas y al LDA como si fuera una palabra del grupo.
)

# Columnas que forman el dataset limpio (y en este orden)
columnas_limpio <- function(ctx, d) {
  nom <- ctx$cfg$sent$nombre[ctx$cfg$sent$activo]
  cols <- c("id_mensaje", "fecha_hora", "fecha", "anio", "mes", "anio_mes", "trimestre",
            "dia_semana", "hora", "autor", if (!isTRUE(ctx$p$anonimizar_autor)) "autor_id",
            "tipo_contenido", "es_respuesta", "responde_a", "editado", "reenviado", "reenviado_de",
            "n_caracteres", "n_palabras", "n_tokens", "n_enlaces", "n_hashtags", "n_menciones",
            "tiene_telefono", "n_emojis", "emojis_lista", "sentimiento_emoji", "polaridad_emoji",
            "reacciones", "reacciones_total", "reacciones_pos", "reacciones_neg",
            "outlier_longitud", "outlier_rafaga", "puntaje_publicidad", "motivo_publicidad",
            "posible_publicidad", "n_ref_femenino", "n_ref_masculino", "n_ref_inclusivo", "genero_mencionado",
            "texto_original", "texto_traducido", "texto_limpio", "texto_tokens",
            "polaridad_msg", "polaridad_score", "sentimiento_dominante", "hits_total", "n_negados",
            paste0("sent_", nom), paste0("pct_", nom))
  cols[cols %in% names(d)]
}

# ── 12. Valores faltantes del dataset final ──────────────────────────────────────
rellenar_nulos <- function(ctx, d) {
  M <- "12. Valores faltantes del dataset final"
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "reenviado_de, responde_a, reacciones, emojis_lista, sentimiento_emoji, polaridad_emoji, sentimiento_dominante, motivo_publicidad",
    atributo = "texto / numérica",
    problema = "Celdas vacías (NA) en columnas derivadas",
    accion = "Se rellenaron las celdas vacías con un valor que significa 'no aplica', distinto para cada columna (por ejemplo reenviado_de = 'original', responde_a = 0, sentimiento_emoji = 'sin_emoji'). Ninguna columna del dataset limpio queda con vacíos.",
    justificacion = "Un NA aquí no es un dato perdido sino 'no corresponde' (un mensaje que no es reenviado no tiene origen). Rellenarlo con una etiqueta explícita evita errores en gráficos y filtros; los conteos (n_emojis, es_respuesta, n_tokens) siguen permitiendo distinguir los casos.",
    afectadas = n_llenos,
    # CÓDIGO
    codigo = {
      cols <- columnas_limpio(ctx, datos)
      vacio <- function(x) if (is.character(x)) is.na(x) | !nzchar(x) else is.na(x)
      detalle <- character(0); n_llenos <- 0
      for (cn in cols) {
        if (cn == "texto_tokens") next   # vacío = sin palabras útiles (n_tokens = 0); ver REGLAS_NULOS
        v <- datos[[cn]]
        m <- vacio(v)
        if (!any(m)) next
        # Las columnas Date/POSIXct no se rellenan con texto: asignar "ninguno"
        # a una fecha dispara as.Date("ninguno") y oculta el problema real.
        if (inherits(v, "Date") || inherits(v, "POSIXct")) next
        val <- if (!is.null(REGLAS_NULOS[[cn]])) REGLAS_NULOS[[cn]]
               else if (is.numeric(v)) 0 else if (is.logical(v)) FALSE else "ninguno"
        datos[[cn]][m] <- val
        n_llenos <- n_llenos + sum(m)
        detalle <- c(detalle, sprintf("%s: %s -> '%s'", cn, .fmt(sum(m)), val))
      }
      ctx$nota <- paste0("Reglas aplicadas (columna: celdas vacías -> valor): ", paste(detalle, collapse = "; "), ".")
    })
  d
}

# ── 13. Validación de consistencia ───────────────────────────────────────────────
validar_consistencia <- function(ctx, d) {
  M <- "13. Validación de consistencia"
  N <- nrow(d)
  n_excl <- nrow(excluidos_df(ctx))
  total <- ctx$N_inicial
  cols <- columnas_limpio(ctx, d)

  # ▌BITÁCORA OFICIAL (todas son comprobaciones: el resultado esperado es 0)
  registrar_hallazgo(ctx, metodologia = M, campo = "id_mensaje", atributo = "identificador",
    problema = "Identificadores repetidos",
    accion = "Se verificó que cada id_mensaje aparezca una sola vez en el dataset limpio (esperado: 0 repetidos).",
    justificacion = "Un id repetido indicaría filas duplicadas por error en algún paso.",
    valor = sum(duplicated(d$id_mensaje)), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "fecha_hora", atributo = "fecha",
    problema = "Fechas faltantes",
    accion = "Se verificó que todos los mensajes limpios tengan fecha (esperado: 0).",
    justificacion = "Todo mensaje debe poder asignarse a un periodo para los gráficos de tendencia.",
    valor = sum(is.na(d$fecha_hora)), base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "texto_limpio", atributo = "texto",
    problema = "Textos limpios vacíos",
    accion = "Se verificó que ningún mensaje limpio tenga texto_limpio vacío (esperado: 0). Los mensajes sin tokens útiles (solo palabras vacías) se conservan con n_tokens = 0 y texto_tokens vacío.",
    justificacion = "El texto limpio es la base de todo el análisis; un vacío indicaría un paso defectuoso.",
    valor = sum(!nzchar(d$texto_limpio)), base = N)

  pct_cols <- grep("^pct_", names(d), value = TRUE)
  registrar_hallazgo(ctx, metodologia = M, campo = paste(pct_cols[1], "...", pct_cols[length(pct_cols)]),
    atributo = "numérica", problema = "Porcentajes de sentimiento fuera de [0, 100]",
    accion = "Se verificó que todos los niveles de sentimiento estén entre 0 y 100 (esperado: 0 fuera de rango).",
    justificacion = "Un porcentaje fuera de rango indica un error de cálculo en el diccionario o en n_tokens.",
    valor = sum(vapply(pct_cols, function(c) sum(d[[c]] < 0 | d[[c]] > 100, na.rm = TRUE), numeric(1))),
    base = N)

  registrar_hallazgo(ctx, metodologia = M, campo = "(todas las columnas del dataset limpio)", atributo = "estructura",
    problema = "Celdas vacías en el dataset limpio",
    accion = sprintf("Se contaron las celdas vacías (NA o texto vacío) en las %d columnas del dataset limpio (esperado: 0).", length(cols)),
    justificacion = "El dataset limpio no debe tener vacíos: cada celda tiene un dato real o una etiqueta explícita de 'no aplica'.",
    valor = sum(vapply(cols, function(cn) {
      if (cn == "texto_tokens") return(0)   # puede estar vacío a propósito (se controla abajo)
      v <- d[[cn]]; sum(is.na(v) | (is.character(v) & !nzchar(v))) }, numeric(1))),
    base = N * length(cols),
    script = "sum(is.na(datos[, columnas]) | datos[, columnas] == '')   # excepto texto_tokens")

  registrar_hallazgo(ctx, metodologia = M, campo = "texto_tokens, n_tokens", atributo = "texto",
    problema = "texto_tokens vacío que no coincide con n_tokens = 0",
    accion = "Se verificó que texto_tokens esté vacío exactamente en los mensajes con n_tokens = 0 (esperado: 0 incoherencias).",
    justificacion = "Un mensaje sin palabras útiles queda con tokens vacíos (no con una palabra de relleno); si ambos datos no coinciden hay un error en la tokenización o en el filtrado de stopwords.",
    valor = sum((trimws(d$texto_tokens) == "") != (d$n_tokens == 0)), base = N,
    script = "sum((trimws(datos$texto_tokens) == '') != (datos$n_tokens == 0))")

  registrar_hallazgo(ctx, metodologia = M, campo = "(todo el dataset)", atributo = "estructura",
    problema = "Conservación de filas (nada se pierde)",
    accion = sprintf("Balance final: %s registros leídos = %s en mensajes_limpios.csv + %s en mensajes_excluidos.csv (diferencia esperada: 0).",
                     .fmt(total), .fmt(N), .fmt(n_excl)),
    justificacion = "Toda fila eliminada debe quedar registrada con su motivo; así el preprocesamiento es auditable y reversible.",
    valor = total - N - n_excl, base = total,
    script = "ctx$N_inicial - nrow(datos) - nrow(excluidos)")
  d
}

# ── Exportación de archivos ──────────────────────────────────────────────────────
exportar_salidas <- function(ctx, d, dir_salida) {
  cols <- columnas_limpio(ctx, d)
  limpio <- d[, cols]
  limpio$fecha_hora <- format(limpio$fecha_hora, "%Y-%m-%d %H:%M:%S")

  ex <- excluidos_df(ctx)
  con_tokens <- d$n_tokens > 0
  tokens <- strsplit(d$texto_tokens[con_tokens], " ", fixed = TRUE)
  tk_df <- data.frame(id_mensaje = rep(d$id_mensaje[con_tokens], lengths(tokens)),
                      fecha = rep(format(d$fecha[con_tokens]), lengths(tokens)),
                      anio_mes = rep(d$anio_mes[con_tokens], lengths(tokens)),
                      token = unlist(tokens), stringsAsFactors = FALSE)

  escribir_csv(limpio, file.path(dir_salida, "mensajes_limpios.csv"))
  if (nrow(ex)) escribir_csv(ex, file.path(dir_salida, "mensajes_excluidos.csv"))
  escribir_csv(tk_df, file.path(dir_salida, "tokens.csv"))
  if (!is.null(ctx$stop_log)) escribir_csv(ctx$stop_log, file.path(dir_salida, "stopwords_aplicadas.csv"))

  # emojis en uso (frecuencia en texto y reacciones) y pendientes
  dic <- ctx$cfg$emojis
  lista <- d$emojis_lista[d$n_emojis > 0]
  f_txt <- table(unlist(strsplit(lista, " ", fixed = TRUE)))
  rl <- reacciones_largo(d$reacciones)
  f_rea <- if (nrow(rl)) tapply(rl$n, rl$emoji, sum) else numeric(0)
  uso <- data.frame(emoji = union(names(f_txt), names(f_rea)), stringsAsFactors = FALSE)
  uso$en_texto <- as.integer(f_txt[uso$emoji]); uso$en_texto[is.na(uso$en_texto)] <- 0L
  uso$en_reacciones <- as.numeric(f_rea[uso$emoji]); uso$en_reacciones[is.na(uso$en_reacciones)] <- 0
  k <- match(uso$emoji, dic$emoji)
  uso$significado_es <- dic$significado_es[k]; uso$sentimiento <- dic$sentimiento[k]
  uso$polaridad <- dic$polaridad[k]; uso$pendiente <- ifelse(nzchar(uso$significado_es), "no", "sí")
  uso <- uso[order(-(uso$en_texto + uso$en_reacciones)), ]
  escribir_csv(uso, file.path(dir_salida, "emojis_en_uso.csv"))
  pend <- if (!is.null(ctx$emojis_pendientes)) ctx$emojis_pendientes else dic[0, ]
  escribir_csv(pend, file.path(dir_salida, "emojis_pendientes.csv"))

  invisible(list(limpio = limpio, excluidos = ex, tokens = tk_df, emojis_en_uso = uso))
}

parametros_df <- function(ctx) {
  p <- ctx$p
  v <- vapply(p, function(x) if (is.null(x)) "(sin límite)" else paste(format(x), collapse = ", "), character(1))
  hs <- ctx$cfg$hashes
  data.frame(
    parametro = c(names(p), paste0("md5 config/", names(hs)), "R version", "fecha ejecución"),
    valor = c(unname(v), unname(hs), R.version.string, format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    stringsAsFactors = FALSE)
}
