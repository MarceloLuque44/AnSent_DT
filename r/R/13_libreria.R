# ==============================================================================
# 13_libreria.R  -  SENTIMIENTOS DE LA LIBRERÍA (syuzhet, léxico NRC en español)
# ------------------------------------------------------------------------------
# La librería da 8 emociones (Plutchik): enojo, anticipación, asco, miedo, alegría,
# tristeza, sorpresa y confianza; más 2 de polaridad: negativo y positivo.
# Se aplica sobre texto_limpio (minúsculas, con tildes, con emojis ya traducidos).

# Para que se pueda comparar con los 15 propios, el nivel se calcula igual:
#   lib_<emoción> = 100 * coincidencias / n_tokens

# "CON librería" = estas columnas lib_*.  "SIN librería" = tus 15 sentimientos (pct_*).
# syuzhet puede tardar con muchos mensajes: usa un periodo o max_mensajes.
# ==============================================================================

sentimientos_libreria <- function(m, texto = "texto_limpio", idioma = "spanish", max_mensajes = NULL, semilla = 1) {
  .requiere("syuzhet")
  if (!is.null(max_mensajes) && nrow(m) > max_mensajes) { set.seed(semilla); m <- m[sample(nrow(m), max_mensajes), , drop = FALSE] }
  x <- m[[texto]]; x[is.na(x)] <- ""
  nrc <- syuzhet::get_nrc_sentiment(x, language = idioma)
  ES <- c(anger = "enojo", anticipation = "anticipacion", disgust = "asco", fear = "miedo", joy = "alegria",
          sadness = "tristeza", surprise = "sorpresa", trust = "confianza", negative = "negativo", positive = "positivo")
  den <- if ("n_tokens" %in% names(m)) pmax(m$n_tokens, 1) else pmax(stringi::stri_count_words(x), 1)
  for (nm in names(ES)) {
    m[[paste0("libn_", ES[[nm]])]] <- nrc[[nm]]                   # conteo bruto
    m[[paste0("lib_", ES[[nm]])]]  <- round(100 * nrc[[nm]] / den, 3)   # nivel (%)
  }
  m$lib_polaridad <- ifelse(nrc$positive > nrc$negative, "positivo",
                     ifelse(nrc$negative > nrc$positive, "negativo", "neutral"))
  m
}

EMOCIONES_LIB <- c("enojo", "anticipacion", "asco", "miedo", "alegria", "tristeza", "sorpresa", "confianza")

nivel_libreria <- function(m) {
  cols <- paste0("lib_", c(EMOCIONES_LIB, "negativo", "positivo"))
  cols <- cols[cols %in% names(m)]
  if (!length(cols) || !nrow(m)) return(data.frame(sentimiento = character(), nivel_pct = numeric(), tipo = character()))
  s <- sub("^lib_", "", cols)
  data.frame(sentimiento = s, nivel_pct = unname(vapply(cols, function(c) mean(m[[c]], na.rm = TRUE), numeric(1))),
             tipo = ifelse(s %in% EMOCIONES_LIB, "emocion (8)", "polaridad"), stringsAsFactors = FALSE)
}

# Con y sin librería: ¿coinciden en positivo/negativo? (sobre mensajes con polaridad definida en ambos)
comparar_con_sin_libreria <- function(m) {
  if (!all(c("polaridad_msg", "lib_polaridad") %in% names(m))) stop("Primero usa sentimientos_libreria().", call. = FALSE)
  tabla <- as.data.frame(table(propio = m$polaridad_msg, libreria = m$lib_polaridad), stringsAsFactors = FALSE)
  d <- m[m$polaridad_msg != "neutral" & m$lib_polaridad != "neutral", , drop = FALSE]
  list(
    propios = nivel_sentimiento(m),
    libreria = nivel_libreria(m),
    polaridad_cruzada = tabla,
    acuerdo_polaridad_pct = if (nrow(d)) round(100 * mean(d$polaridad_msg == d$lib_polaridad), 1) else NA_real_,
    mensajes_comparados = nrow(d),
    distribucion = data.frame(
      polaridad = c("positivo", "negativo", "neutral"),
      propios_pct = round(100 * as.numeric(table(factor(m$polaridad_msg, c("positivo", "negativo", "neutral")))) / nrow(m), 1),
      libreria_pct = round(100 * as.numeric(table(factor(m$lib_polaridad, c("positivo", "negativo", "neutral")))) / nrow(m), 1)))
}
