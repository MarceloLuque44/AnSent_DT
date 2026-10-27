# ==============================================================================
# 05_emojis.R  -  ETAPA 7: EMOJIS (extracción, diccionario maestro, traducción, reacciones)
# ------------------------------------------------------------------------------
# Diccionario: config/emojis.csv
#   columnas: emoji, significado_es, sentimiento, polaridad, nombre_unicode
#   Un emoji está PENDIENTE cuando su columna significado_es está vacía.
# Emoticonos de texto (":(", ":c", "<3") -> su emoji, solo para detectar y traducir el sentimiento.
# ==============================================================================

RX_EMOJI <- "[\\p{Extended_Pictographic}\\x{1F1E6}-\\x{1F1FF}\\x{20E3}]"
.NO_EMOJI <- c("\u00A9", "\u00AE", "\u2122")   # ©, ®, ™ no son emojis de sentimiento


# Quita tonos de piel y selectores de variación para que 👍 y 👍🏽 sean la misma clave
emoji_clave <- function(x) {
  stringi::stri_replace_all_regex(x, "[\\x{1F3FB}-\\x{1F3FF}\\x{FE0F}\\x{FE0E}]", "")
}

.es_emoji <- function(g) stringi::stri_detect_regex(g, RX_EMOJI) & !(g %in% .NO_EMOJI)


# El texto_original NO se modifica. El emoticono debe estar suelto (no pegado a letras ni numeros), asi "10:40" o "https://" no se confunden con una carita.
.emoticonos_a_emoji <- function(x, tabla) {
  if (is.null(tabla) || !nrow(tabla)) return(x)
  tabla <- tabla[order(-nchar(tabla$emoticono)), ]
  pat <- paste0("(?<![\\p{L}\\p{N}])", .esc(tabla$emoticono), "(?![\\p{L}\\p{N}])")
  x[is.na(x)] <- ""
  stringi::stri_replace_all_regex(x, pat, paste0(" ", tabla$emoji, " "), vectorize_all = FALSE,
                                  opts_regex = stringi::stri_opts_regex(case_insensitive = TRUE))
}

# Devuelve una lista (una entrada por texto) con los emojis encontrados (clave normalizada)
extraer_emojis <- function(textos) {
  textos[is.na(textos)] <- ""
  res <- rep(list(character(0)), length(textos))
  cand <- which(stringi::stri_detect_regex(
    textos, "[\\x{00A9}\\x{00AE}\\x{203C}-\\x{3299}\\x{1F000}-\\x{1FAFF}\\x{1F1E6}-\\x{1F1FF}\\x{20E3}]"))
  if (length(cand)) {
    gr <- stringi::stri_extract_all_boundaries(textos[cand], type = "character")
    for (k in seq_along(cand)) {
      g <- gr[[k]]
      res[[cand[k]]] <- emoji_clave(g[.es_emoji(g)])
    }
  }
  res
}

.slug <- function(x) {
  x <- stringi::stri_trans_general(stringi::stri_trans_tolower(x), "Latin-ASCII")
  gsub("^_+|_+$", "", gsub("[^a-z0-9]+", "_", x))
}

.nombre_unicode <- function(x) {
  nm <- stringi::stri_trans_general(x, "Any-Name")
  nm <- gsub("\\\\N\\{|\\}", " ", nm)
  trimws(gsub("\\s+", " ", tolower(nm)))
}


# Reacciones "👍:2|👎:1" -> tabla larga (i = fila, emoji, n)
reacciones_largo <- function(x) {
  i <- which(!is.na(x) & grepl(":[0-9]+", x))   # ignora "ninguna" y vacíos
  if (!length(i)) return(data.frame(i = integer(0), emoji = character(0), n = numeric(0)))
  partes <- strsplit(x[i], "|", fixed = TRUE)
  df <- data.frame(i = rep(i, lengths(partes)), raw = unlist(partes), stringsAsFactors = FALSE)
  df$n <- as.numeric(sub("^.*:([0-9]+)$", "\\1", df$raw))
  df$emoji <- emoji_clave(sub(":[0-9]+$", "", df$raw))
  df[, c("i", "emoji", "n")]
}

.guardar_emojis <- function(ctx) {
  e <- ctx$cfg$emojis
  cols <- c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")
  escribir_csv(e[, cols], file.path(ctx$cfg$dir, "emojis.csv"))
}







# Función pública: guardar la traducción de un emoji (la usará el dashboard)para actualizar_emoji("🦖", "dinosaurio rex", "alegria")
actualizar_emoji <- function(emoji, significado_es, sentimiento = "neutral", polaridad = NULL,
                             dir_config = "config") {
  f <- file.path(dir_config, "emojis.csv")
  e <- readr::read_csv(f, col_types = readr::cols(.default = "c"), progress = FALSE, na = character())
  s <- jsonlite::fromJSON(file.path(dir_config, "sentimientos.json"))$sentimientos
  if (is.null(polaridad))
    polaridad <- if (sentimiento %in% s$nombre) s$polaridad[match(sentimiento, s$nombre)] else 0
  k <- match(emoji_clave(emoji), emoji_clave(e$emoji))
  if (is.na(k)) {
    e <- rbind(e[, c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")],
               data.frame(emoji = emoji_clave(emoji), significado_es = "", sentimiento = "neutral",
                          polaridad = "0", nombre_unicode = .nombre_unicode(emoji),
                          stringsAsFactors = FALSE))
    k <- nrow(e)
  }
  e$significado_es[k] <- significado_es
  e$sentimiento[k] <- sentimiento
  e$polaridad[k] <- as.character(polaridad)
  escribir_csv(e[, c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")], f)
  invisible(e[k, ])
}

procesar_emojis <- function(ctx, d) {
  M <- "7. Traducción de emojis (diccionario maestro)"
  p <- ctx$p
  dic <- ctx$cfg$emojis

  en_texto <- unlist(strsplit(d$emojis_lista[nzchar(d$emojis_lista)], " ", fixed = TRUE))
  rl <- reacciones_largo(d$reacciones)
  usados <- unique(c(en_texto, rl$emoji))
  nuevos <- setdiff(usados, dic$emoji)

  # ── 7.1 Emojis nuevos ──────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  registrar_hallazgo(ctx, metodologia = M, campo = "emojis_lista, reacciones", atributo = "texto",
    problema = "Emojis distintos usados / emojis nuevos fuera del diccionario",
    accion = sprintf("Se encontraron %d emojis distintos (texto + reacciones); %d no estaban en config/emojis.csv.",
                     length(usados), length(nuevos)),
    justificacion = "Un diccionario maestro persistente evita traducir el mismo emoji dos veces y permite reutilizar el trabajo en otros datasets.",
    valor = length(nuevos), base = length(usados),
    script = "usados <- unique(c(en_texto, reacciones_largo(datos$reacciones)$emoji))\nnuevos <- setdiff(usados, diccionario$emoji)")


  if (length(nuevos)) {
    nuevo_df <- data.frame(
      emoji = nuevos, significado_es = "", sentimiento = "neutral", polaridad = 0,
      nombre_unicode = .nombre_unicode(nuevos), stringsAsFactors = FALSE)
    dic <- rbind(dic, nuevo_df)
    ctx$cfg$emojis <- dic
    .guardar_emojis(ctx)
  }
  pend_usados <- dic[dic$emoji %in% usados & !nzchar(dic$significado_es), ]
  ctx$emojis_pendientes <- pend_usados

  if (p$nuevos_emojis == "detener" && nrow(pend_usados) > 0) {
    ctx$detenido <- TRUE
    return(d)
  }
  dic$token <- paste0("emoji_", ifelse(nzchar(dic$significado_es), .slug(dic$significado_es),
                                       .slug(dic$nombre_unicode)))

  # ── 7.2 Traducir el texto ──────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original -> texto_traducido", atributo = "texto",
    problema = "Emojis sin significado textual",
    accion = "Cada emoji se reemplazó por su significado en español (token emoji_<significado>) según el diccionario maestro. No se eliminó ninguno.",
    justificacion = "La licenciada indicó que los emojis tienen significado y no deben limpiarse sino traducirse, sin perder datos.",
    ejemplo_col = "texto_traducido", texto_ref = "texto_original",
    afectadas = sum(datos$n_emojis > 0),
    # CÓDIGO
    codigo = {
      mapa <- stats::setNames(dic$token, dic$emoji)
      base <- .emoticonos_a_emoji(datos$texto_original, ctx$cfg$emoticonos)   # emoticonos -> emoji
      salida <- datos$texto_original
      con <- which(datos$n_emojis > 0)
      gr <- stringi::stri_extract_all_boundaries(base[con], type = "character")
      for (k in seq_along(con)) {
        g <- gr[[k]]
        es <- .es_emoji(g)
        g[es] <- paste0(" ", mapa[emoji_clave(g[es])], " ")
        salida[con[k]] <- paste(g, collapse = "")
      }
      datos$texto_traducido <- salida
    })

  # ── 7.3 Sentimiento del emoji ──────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "emojis_lista -> sentimiento_emoji, polaridad_emoji", atributo = "texto / numérica",
    problema = "Sentimiento expresado solo con emojis",
    accion = "Se asignó a cada mensaje el sentimiento dominante de sus emojis y la polaridad promedio (-1 negativo, 0 neutral, +1 positivo).",
    justificacion = "Permite medir el sentimiento aunque el mensaje no tenga palabras del diccionario (por ejemplo, un mensaje de solo emojis).",
    ejemplo_col = "sentimiento_emoji", texto_ref = "texto_original",
    afectadas = sum(!is.na(datos$sentimiento_emoji)),
    # CÓDIGO
    codigo = {
      sent_map <- stats::setNames(dic$sentimiento, dic$emoji)
      pol_map <- stats::setNames(dic$polaridad, dic$emoji)
      lst <- strsplit(datos$emojis_lista, " ", fixed = TRUE)
      datos$sentimiento_emoji <- vapply(lst, function(k) {
        if (!length(k)) return(NA_character_)
        s <- sent_map[k]
        s2 <- s[s != "neutral"]
        if (!length(s2)) "neutral" else names(sort(table(s2), decreasing = TRUE))[1]
      }, character(1))
      datos$polaridad_emoji <- vapply(lst, function(k) if (length(k)) mean(pol_map[k]) else NA_real_, numeric(1))
    })


  # ── 7.4 Reacciones de Telegram ─────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "reacciones -> reacciones_total, reacciones_pos, reacciones_neg", atributo = "numérica",
    problema = "Reacciones (👍 👎 ❤) sin cuantificar",
    accion = "Se contaron las reacciones recibidas por mensaje y se clasificaron en positivas y negativas según la polaridad del diccionario de emojis.",
    justificacion = "Las reacciones son una señal de sentimiento de los lectores hacia el mensaje, independiente del texto.",
    afectadas = sum(datos$reacciones_total > 0),
    # CÓDIGO
    codigo = {
      pol_map <- stats::setNames(dic$polaridad, dic$emoji)
      rl <- reacciones_largo(datos$reacciones)
      pol <- unname(pol_map[rl$emoji]); pol[is.na(pol)] <- 0
      acumular <- function(sel) {
        out <- numeric(nrow(datos))
        if (any(sel)) {
          s <- rowsum(rl$n[sel], rl$i[sel])
          out[as.integer(rownames(s))] <- s[, 1]
        }
        out
      }
      datos$reacciones_total <- acumular(rep(TRUE, nrow(rl)))
      datos$reacciones_pos <- acumular(pol > 0)
      datos$reacciones_neg <- acumular(pol < 0)
    })
  ctx$cfg$emojis <- dic
  d
}
