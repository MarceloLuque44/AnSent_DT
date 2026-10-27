# ==============================================================================
# 04_publicidad.R  -  ETAPA 6: PUBLICIDAD Y ANUNCIOS (detección por puntaje)
# ------------------------------------------------------------------------------
# Una sola palabra como "inscripción" o "cupos" 
# NO basta: en un grupo de curso los estudiantes preguntan "no puedo inscribirme". 
# Por eso se suma un PUNTAJE de señales (estructura del mensaje + frases de llamado a la acción), configurables en
# config/palabras_anuncio.csv. El mensaje es publicidad si puntaje >= umbral.
# ==============================================================================

puntaje_publicidad <- function(d, reglas) {
  n <- nrow(d)
  tn <- stringi::stri_trans_general(stringi::stri_trans_tolower(d$texto_original), "Latin-ASCII")
  score <- numeric(n)
  motivos <- character(n)
  empieza_emoji <- stringi::stri_detect_regex(d$texto_original, "^\\s*[\\p{Extended_Pictographic}]")

  for (i in seq_len(nrow(reglas))) {
    r <- reglas[i, ]
    peso <- as.numeric(r$peso)
    par <- suppressWarnings(as.numeric(r$parametro))
    hit <- switch(r$tipo,
      estructura = switch(r$patron,
        reenviado     = d$reenviado,
        enlace        = d$n_enlaces > 0,
        largo         = d$n_caracteres >= par,
        muchos_emojis = d$n_emojis >= par,
        empieza_emoji = empieza_emoji,
        hashtag       = d$n_hashtags > 0,
        telefono      = d$tiene_telefono,
        rep(FALSE, n)),
      # la frase debe empezar en una palabra ("feria" no debe coincidir dentro de "refería")
      frase = stringi::stri_detect_regex(tn, paste0("(?<![a-z0-9])", .esc(stringi::stri_trans_general(tolower(r$patron), "Latin-ASCII")))),
      regex = stringi::stri_detect_regex(tn, r$patron),
      rep(FALSE, n))
    hit[is.na(hit)] <- FALSE
    score <- score + hit * peso
    motivos[hit] <- paste0(motivos[hit], ifelse(nzchar(motivos[hit]), "; ", ""), r$patron)
  }
  list(puntaje = score, motivo = motivos)
}

detectar_publicidad <- function(ctx, d) {
  M <- "6. Limpieza de publicidad y anuncios (propia del texto)"
  umbral <- ctx$p$umbral_publicidad
  reglas <- ctx$cfg$anuncio

  
  
  # ── 6.1 Calcular el puntaje ────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "puntaje_publicidad, motivo_publicidad, posible_publicidad", atributo = "texto / booleana",
    problema = "Publicidad y anuncios de cursos/eventos",
    accion = sprintf("Se calculó un puntaje de publicidad por mensaje (señales de estructura + frases de llamado a la acción, de config/palabras_anuncio.csv) y se marcó como posible publicidad si puntaje >= %s.", umbral),
    justificacion = "La licenciada indicó eliminar publicidades y cursos. Un puntaje compuesto evita borrar preguntas legítimas que solo contienen palabras como 'inscripción' o 'cupos'.",
    ejemplo_col = "posible_publicidad",
    # CÓDIGO
    codigo = {
      pp <- puntaje_publicidad(datos, reglas)
      datos$puntaje_publicidad <- pp$puntaje
      datos$motivo_publicidad <- pp$motivo
      datos$posible_publicidad <- pp$puntaje >= umbral
    })
  registrar_hallazgo(ctx, metodologia = M, campo = "puntaje_publicidad", atributo = "numérica",
    problema = "Mensajes cerca del umbral de publicidad (para calibrar)",
    accion = sprintf("Se contaron los mensajes con puntaje entre %s y %s (a 1-2 puntos del umbral). No se excluyen; conviene leerlos para decidir si el umbral o los pesos de palabras_anuncio.csv están bien calibrados.", max(umbral - 2, 1), umbral - 1),
    justificacion = "Un umbral fijo nunca es perfecto: revisar los casos límite permite medir falsos positivos (preguntas de estudiantes) y falsos negativos (anuncios) antes de eliminar nada.",
    valor = sum(d$puntaje_publicidad >= max(umbral - 2, 1) & d$puntaje_publicidad < umbral), base = nrow(d))

  
  

  # ── 6.2 Apartar la publicidad ──────────────────────────────────────────────────
  if (isTRUE(ctx$p$excluir_publicidad)) {
    # ▌BITÁCORA OFICIAL
    d <- registrar_paso(ctx, d, metodologia = M,
      campo = "posible_publicidad", atributo = "booleana", problema = "Publicidad detectada",
      accion = "Se separaron los mensajes marcados como publicidad; quedan en mensajes_excluidos.csv con su puntaje y motivo para poder revisarlos.",
      justificacion = "Eliminar publicidad es lo único que la licenciada permitió quitar; guardarlos aparte permite auditar falsos positivos.",
      # CÓDIGO
      codigo = {
        pub <- datos$posible_publicidad
        excluir(ctx, datos[pub, ], sprintf("Publicidad / anuncio (puntaje >= %s)", umbral))
        datos <- datos[!pub, ]
      })
  }
  d
}
