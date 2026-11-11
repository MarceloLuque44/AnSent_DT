# ==============================================================================
# 03_calidad.R  -  ETAPAS 3, 4 y 5: DUPLICADOS, VALORES FALTANTES Y OUTLIERS
# ==============================================================================

control_calidad <- function(ctx, d) {
  minc <- ctx$p$min_chars_duplicado
  rafaga_min <- 8

  # ── 3.1 Duplicados ─────────────────────────────────────────────────────────────
  M <- "3. Gestión de duplicados"
  # ▌BITÁCORA OFICIAL (hallazgo: no se borra nada)
  registrar_hallazgo(ctx, metodologia = M, campo = "texto_original, autor_id", atributo = "texto",
    problema = "Repeticiones cortas (saludos, 'gracias', 'jaja')",
    accion = sprintf("Se contaron mensajes cortos (menos de %d caracteres) repetidos por el mismo autor. NO se eliminan.", minc),
    justificacion = "Repetir 'gracias' o 'jaja' es una expresión genuina de sentimiento; borrarlo subestimaría la gratitud o la alegría.",
    valor = sum(duplicated(paste(d$autor_id, stringi::stri_trans_tolower(stringi::stri_trim_both(d$texto_original)), sep = "||")) &
                  d$n_caracteres < minc),
    base = nrow(d))

  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original, autor_id", atributo = "texto",
    problema = "Duplicado exacto (mismo autor y mismo texto)",
    accion = sprintf("Se eliminaron las repeticiones exactas de un mismo autor con %d o más caracteres; se conserva la primera aparición.", minc),
    justificacion = "Un mensaje largo repetido (spam o reposteo del mismo anuncio) infla artificialmente frecuencias y TF-IDF sin aportar un sentimiento nuevo.",
    # CÓDIGO
    codigo = {
      clave <- paste(datos$autor_id, stringi::stri_trans_tolower(stringi::stri_trim_both(datos$texto_original)), sep = "||")
      dup <- duplicated(clave) & datos$n_caracteres >= minc
      excluir(ctx, datos[dup, ], sprintf("Duplicado exacto (mismo autor y texto, >= %d caracteres)", minc))
      datos <- datos[!dup, ]
    })


  # ── 4.1 Valores faltantes ──────────────────────────────────────────────────────
  M <- "4. Tratamiento de valores faltantes"
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original", atributo = "texto",
    problema = "Mensajes sin texto (solo multimedia)",
    accion = "Se separaron los mensajes sin texto (foto, video, archivo, nota de voz...). Quedan en mensajes_excluidos.csv.",
    justificacion = "El análisis de sentimiento es textual y no hay imputación válida para un texto ausente; se descarta la fila pero se documenta.",
    # CÓDIGO
    codigo = {
      vacio <- !nzchar(stringi::stri_trim_both(datos$texto_original))
      tb <- table(datos$tipo_contenido[vacio])
      ctx$nota <- paste0("Detalle por tipo: ", paste(names(tb), tb, sep = "=", collapse = ", "), ".")
      excluir(ctx, datos[vacio, ], "Sin texto (solo foto, video, archivo, audio u otro contenido multimedia)")
      datos <- datos[!vacio, ]
    })


  # ── 5.1 Outliers de longitud ───────────────────────────────────────────────────
  M <- "5. Detección y tratamiento de outliers"
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "n_caracteres -> outlier_longitud", atributo = "numérica",
    problema = "Mensajes de longitud extrema",
    accion = "Se marcaron como outlier los mensajes cuya longitud supera Q3 + 1.5*IQR (calculado sobre log(1 + caracteres)). Se CONSERVAN, solo se marcan.",
    justificacion = "La longitud es muy asimétrica, por eso se usa escala logarítmica; los textos largos pueden ser anuncios o mensajes legítimos, y decidir si se excluyen se hace en la etapa de publicidad.",
    ejemplo_col = "outlier_longitud",
    # CÓDIGO
    codigo = {
      lg <- log1p(datos$n_caracteres)
      q <- stats::quantile(lg, c(0.25, 0.75), names = FALSE)
      lim <- q[2] + 1.5 * (q[2] - q[1])
      datos$outlier_longitud <- lg > lim
      ctx$nota <- sprintf("Umbral calculado: %d caracteres.", round(expm1(lim)))
    })


  # ── 5.2 Outliers: ráfagas ──────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "autor_id, fecha_hora -> outlier_rafaga", atributo = "numérica",
    problema = "Ráfagas de mensajes (posible spam)",
    accion = sprintf("Se marcaron los mensajes de un autor que envió %d o más mensajes en el mismo minuto. Se CONSERVAN, solo se marcan.", rafaga_min),
    justificacion = "Una ráfaga puede ser un debate real o spam; marcarla permite revisarla sin perder datos.",
    ejemplo_col = "outlier_rafaga",
    # CÓDIGO
    codigo = {
      k <- paste(datos$autor_id, format(datos$fecha_hora, "%Y-%m-%d %H:%M"))
      n_k <- stats::ave(seq_along(k), k, FUN = length)
      datos$outlier_rafaga <- n_k >= rafaga_min
    })
  d
}
