# ==============================================================================
# 06_texto.R  -  ETAPAS 8, 9 y 10: LIMPIEZA DE TEXTO, GÉNERO, TOKENIZACIÓN Y STOPWORDS
# ------------------------------------------------------------------------------
# ORDEN IMPORTANTE (por qué las tildes se quitan al final y no al principio):
#   1) minúsculas y limpieza de signos          (se conservan las tildes)
#   2) stopwords: aquí hacen falta las tildes para distinguir "él" (pronombre, se conserva) de "el" (artículo, se elimina)
#   3) recién entonces se quitan las tildes de los tokens (para TF-IDF y LDA), salvo la ñ y las palabras que se conservan con tilde (él)
# El diccionario de sentimientos se compara aparte, sobre texto sin tildes.
# ==============================================================================

.ascii <- function(x) stringi::stri_trans_general(x, "Latin-ASCII")


# Dominios sueltos sin http (umsa.bo, fcpn.edu.bo): son direcciones, no palabras
RX_DOM <- "(?<![\\p{L}\\p{N}@._-])[a-z0-9-]+(?:\\.[a-z0-9-]+)*\\.(?:com|net|org|edu|gob|gov|info|bo)(?:\\.[a-z]{2})?(?![\\p{L}\\p{N}])(?:/\\S*)?"
MESES <- "enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre"


# Quita las tildes pero CONSERVA la ñ (año != ano) ; "pingüino" -> "pinguino"
.sin_tilde <- function(x) {
  x <- stringi::stri_replace_all_fixed(x, "\u00F1", "<<enie>>")
  x <- stringi::stri_trans_general(x, "NFD; [:Nonspacing Mark:] Remove; NFC")
  stringi::stri_replace_all_fixed(x, "<<enie>>", "\u00F1")
}

# ==============================================================================
#  ETAPA 8: LIMPIEZA Y NORMALIZACIÓN DEL TEXTO
# ==============================================================================
normalizar_texto <- function(ctx, d) {
  M <- "8. Limpieza y normalización de texto"
  RX_RUIDO <- paste(RX_URL, RX_MAIL, RX_DOM, RX_MENC, RX_TEL, sep = "|")

  # ── 8.1 Enlaces, correos, menciones, teléfonos ─────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_traducido -> texto_limpio", atributo = "texto",
    problema = "Enlaces, correos, menciones y teléfonos dentro del texto",
    accion = "Se eliminaron URLs, correos, dominios sueltos (umsa.bo) y @menciones, y los teléfonos se reemplazaron por la palabra 'telefono'. Antes, las letras y números decorativos de Unicode (por ejemplo un 3 en negrita matemática) se pasaron a su forma normal (NFKC, solo en esos bloques). Se creó texto_limpio.",
    justificacion = "Son ruido para el análisis de sentimiento y, además, datos personales que no deben quedar en el texto analizado.",
    ejemplo_col = "texto_limpio", texto_ref = "texto_traducido",
    afectadas = sum(stringi::stri_detect_regex(datos$texto_traducido, RX_RUIDO)),
    # CÓDIGO
    codigo = {
      x <- datos$texto_traducido
      # letras/números decorados (negrita matemática, ancho completo) -> forma normal. NFKC solo en esos
      # bloques: aplicado a todo el texto alteraría algunos emojis (‼ -> !!, ™ -> TM)
      deco <- which(stringi::stri_detect_regex(x, "[\\x{1D400}-\\x{1D7FF}\\x{FF01}-\\x{FF5E}]"))
      x[deco] <- stringi::stri_trans_nfkc(x[deco])
      x <- stringi::stri_replace_all_regex(x, RX_URL, " ")
      x <- stringi::stri_replace_all_regex(x, RX_MAIL, " ")
      x <- stringi::stri_replace_all_regex(x, RX_DOM, " ", opts_regex = stringi::stri_opts_regex(case_insensitive = TRUE))
      x <- stringi::stri_replace_all_regex(x, RX_MENC, " ")
      x <- stringi::stri_replace_all_regex(x, RX_TEL, " telefono ")
      datos$texto_limpio <- x
    })
 
  
  
  # ── 8.1b Lenguaje inclusivo con @ ──────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Lenguaje inclusivo con @ (compañer@s, tod@s)",
    accion = "Se reemplazó la @ dentro de una palabra por 'o' (compañer@s -> compañeros, tod@s -> todos).",
    justificacion = "Sin esto, la @ se borraba como signo y la palabra quedaba partida ('compañer s'). Se escribe completa para que coincida con genero.csv y con los diccionarios.",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, "(\\p{L})@(s?)(?![\\p{L}\\p{N}_@])", "$1o$2")
    })

  

  # ── 8.2 Minúsculas ─────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Mayúsculas y minúsculas mezcladas",
    accion = "Se convirtió todo el texto a minúsculas (las tildes se conservan por ahora).",
    justificacion = "'Gracias', 'GRACIAS' y 'gracias' deben contarse como la misma palabra.",
    ejemplo_col = "texto_limpio",
    #CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_trans_tolower(datos$texto_limpio)
    })
  
  
  # ── 8.2b Horas y fechas ─────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Horas y fechas escritas con números (10:40am, 4 pm, 26-12-22, 27 de diciembre)",
    accion = "Se eliminaron las horas (10:40am, 16:00, 4 pm, 16 horas) y las fechas (26-12-22, 27 de diciembre de 2022). Los nombres de meses y días sueltos se conservan.",
    justificacion = "Al quitar los signos y los números sueltos quedaban restos sin sentido ('40am', 'pm', 'am'). Una hora o una fecha no expresa sentimiento y ensucia el TF-IDF y el topic modeling.",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      x <- datos$texto_limpio
      x <- stringi::stri_replace_all_regex(x, "(?<![\\p{N}])\\d{1,2}[-/.]\\d{1,2}[-/.]\\d{2,4}(?![\\p{N}])", " ")
      x <- stringi::stri_replace_all_regex(x, paste0("(?<![\\p{N}])\\d{1,2}\\s+de\\s+(?:", MESES, ")(?:\\s+(?:de|del)\\s+\\d{2,4})?"), " ")
      x <- stringi::stri_replace_all_regex(x, "(?<![\\p{N}])\\d{1,2}\\s*[:.h]\\s*\\d{2}(?::\\d{2})?\\s*(?:a\\.?\\s?m\\.?|p\\.?\\s?m\\.?|hrs?\\.?|horas?)?(?![\\p{L}\\p{N}])", " ")
      x <- stringi::stri_replace_all_regex(x, "(?<![\\p{N}])\\d{1,2}\\s*(?:a\\.?\\s?m\\.?|p\\.?\\s?m\\.?|hrs?\\.?|horas)(?![\\p{L}\\p{N}])", " ")
      datos$texto_limpio <- x
    })
  


  # ── 8.2c Códigos de materia ─────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Códigos de materia partidos (INF 111, INF-330, LAB 273)",
    accion = "Se unió el prefijo con el número en un solo token (inf-111 -> inf_111). Los prefijos válidos están en config/codigos_materia.csv.",
    justificacion = "Quitar los números dejaba solo 'inf' o 'lab', y se pierde de qué materia se habla. Con el código completo el topic modeling puede agrupar por materia. Solo se unen los prefijos de la lista para no tocar frases como 'hay 100 personas'.",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      pref <- paste(unique(stringi::stri_trans_tolower(ctx$cfg$materias$prefijo)), collapse = "|")
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio,
      paste0("(?<![\\p{L}\\p{N}_])(", pref, ")\\s*[-\\u2013\\u2014]?\\s*(\\d{3})(?![\\p{N}])"), "$1_$2")
    })


  # ── 8.3 Hashtags ───────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Hashtags",
    accion = "Se quitó el símbolo # y se conservó la palabra (#curso -> curso).",
    justificacion = "El hashtag contiene una palabra con significado temático que debe entrar al TF-IDF y al topic modeling.",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, "#(?=[\\p{L}\\p{N}_])", "")
    })

  

  # ── 8.4 Signos extraños y puntuación ───────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Puntuación y símbolos extraños",
    accion = "Se reemplazaron por espacio todos los caracteres que no son letras, números o guion bajo (se conservan tildes y eñe; el guion bajo une los tokens emoji_*).",
    justificacion = "La puntuación no aporta al conteo de palabras y pega signos a las palabras ('hola!' no sería igual a 'hola').",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, "[^\\p{L}\\p{N}\\p{M}_\\s]", " ")
    })

  
  
  # ── 8.5 Letras alargadas ───────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Alargamiento de letras ('holaaaa', 'graciasss')",
    accion = "Se redujeron a una sola letra las repeticiones de 3 o más letras iguales seguidas.",
    justificacion = "En chat se alargan las palabras para dar énfasis; sin normalizar, 'graciasss' no coincide con 'gracias' en el diccionario. En español no existen palabras con 3 letras iguales seguidas.",
    ejemplo_col = "texto_limpio",
    # ▌CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, "(\\p{L})\\1{2,}", "$1")
    })

  
  

  # ── 8.5b Abreviaturas y variantes de escritura ──────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Abreviaturas de chat (q, xq, porfa, bn, tmb, okey...)",
    accion = "Se escribieron completas las abreviaturas y variantes de config/abreviaturas.csv (q -> que, xq -> porque, xfvor -> por favor, bn -> bien, okey -> ok). Solo se reemplazan palabras completas.",
    justificacion = "Normalización léxica: la misma palabra escrita de varias maneras debe contarse una sola vez, y los diccionarios de stopwords y sentimientos buscan la forma completa. No se tocan letras sueltas ambiguas (x, d, k, s, c).",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      ab <- ctx$cfg$abrev
      ab <- ab[order(-nchar(ab$abreviatura)), ]
      pat <- paste0("(?<![\\p{L}\\p{N}_])", .esc(stringi::stri_trans_tolower(ab$abreviatura)), "(?![\\p{L}\\p{N}_])")
      datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, pat, ab$normal, vectorize_all = FALSE)
    })

  

  # ── 8.6 Espacios ───────────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Espacios múltiples",
    accion = "Se colapsaron los espacios repetidos y se recortaron los extremos.",
    justificacion = "Deja una separación uniforme entre tokens para tokenizar.",
    ejemplo_col = "texto_limpio",
    # CÓDIGO
    codigo = {
      datos$texto_limpio <- stringi::stri_trim_both(stringi::stri_replace_all_regex(datos$texto_limpio, "\\s+", " "))
    })


  # ── 8.7 Mensajes vacíos tras la limpieza ───────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio", atributo = "texto", problema = "Mensajes sin contenido textual tras la limpieza",
    accion = "Se separaron los mensajes que quedaron vacíos (solo enlaces, símbolos o menciones). Quedan en mensajes_excluidos.csv.",
    justificacion = "Sin palabras no hay nada que analizar; se documenta para poder auditarlo.",
    # CÓDIGO
    codigo = {
      vacio <- !nzchar(datos$texto_limpio)
      excluir(ctx, datos[vacio, ], "Sin contenido textual tras la limpieza (solo enlaces, símbolos o menciones)")
      datos <- datos[!vacio, ]
    })
  d
}

# ==============================================================================
#  ETAPA 9: REFERENCIAS DE GÉNERO (el sentimiento de ellas y de ellos es distinto)
# ------------------------------------------------------------------------------
# Telegram NO guarda el sexo de quien escribe, y deducirlo del nombre sería adivinar.
# Lo que sí se puede medir es A QUIÉN SE REFIERE el mensaje: "ella", "las chicas", "la
# profesora" vs "él", "los chicos", "el profesor". Por eso "él/ella" no se eliminan como
# stopwords. Las palabras están en config/genero.csv.
# Límite: el masculino genérico ("compañeros") puede referirse a mixtos.
# ==============================================================================

marcar_genero <- function(ctx, d) {
  M <- "9. Referencias de género (antes de quitar stopwords)"
  g <- ctx$cfg$genero
  g$palabra <- stringi::stri_trans_tolower(g$palabra)
  patron <- function(gen) {
    w <- unique(g$palabra[g$genero == gen])
    paste0("(?<![\\p{L}\\p{N}_])(?:", paste(w[order(-nchar(w))], collapse = "|"), ")(?![\\p{L}\\p{N}_])")
  }
  pat_f <- patron("femenino"); pat_m <- patron("masculino")
  pal_m <- unique(g$palabra[g$genero == "masculino"])

  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio -> n_ref_femenino, n_ref_masculino, n_ref_inclusivo, genero_mencionado", atributo = "categórica",
    problema = "No se distingue a quién se refiere el mensaje (ellas / ellos)",
    accion = "Se contaron las palabras de referencia femenina y masculina (config/genero.csv) y las formas inclusivas con @ (compañer@s, tod@s), y se clasificó cada mensaje como femenino, masculino, ambos, inclusivo o ninguno. Las formas con @ NO cuentan como masculino.",
    justificacion = "La licenciada indicó que el sentimiento de ellas y de ellos es distinto y que 'él/ella' no deben eliminarse; esta columna permite comparar sentimientos según a quién se menciona. No se deduce el sexo del autor.",
    ejemplo_col = "genero_mencionado",
    afectadas = sum(datos$genero_mencionado != "ninguno"),
    # CÓDIGO
    codigo = {
      # formas inclusivas: se buscan en el texto ANTES de que 8.1b cambie la @ por 'o'
      inc <- stringi::stri_extract_all_regex(datos$texto_traducido,
               "(?<![\\p{L}\\p{N}_@])\\p{L}+@s?(?![\\p{L}\\p{N}_@])")
      inc <- lapply(inc, function(w) stringi::stri_trans_tolower(
               stringi::stri_replace_all_regex(w[!is.na(w)], "@", "o")))
      datos$n_ref_inclusivo <- lengths(inc)
      inc_m <- vapply(inc, function(w) sum(w %in% pal_m), numeric(1))   # "compañer@s" -> "compañeros" ya fue contado como masculino: se descuenta
      datos$n_ref_femenino <- stringi::stri_count_regex(datos$texto_limpio, pat_f)
      datos$n_ref_masculino <- pmax(0, stringi::stri_count_regex(datos$texto_limpio, pat_m) - inc_m)
      datos$genero_mencionado <- ifelse(datos$n_ref_femenino > 0 & datos$n_ref_masculino > 0, "ambos",
                                 ifelse(datos$n_ref_femenino > 0, "femenino",
                                 ifelse(datos$n_ref_masculino > 0, "masculino",
                                 ifelse(datos$n_ref_inclusivo > 0, "inclusivo", "ninguno"))))
    })
  d
}



# ==============================================================================
#  ETAPA 10: TOKENIZACIÓN, STOPWORDS PERSONALIZADAS Y TILDES
# ==============================================================================
# Stopwords = lista base (config/stopwords.csv) + reglas propias (conservar él, ella, no, muy...)
# + protección automática de toda palabra del diccionario de sentimientos.

preparar_stopwords <- function(ctx) {
  sw <- ctx$cfg$stop
  elim <- sw$palabra[sw$accion == "eliminar"]
  cons <- sw$palabra[sw$accion == "conservar"]
  # variante sin tilde de cada palabra a eliminar, salvo que choque con una que se conserva
  var <- setdiff(unique(.ascii(elim)), c(elim, cons))
  elim <- c(elim, var)

  sj <- ctx$cfg$sent
  sj <- sj[sj$activo, ]
  palabras <- unique(.ascii(tolower(unlist(sj$palabras))))
  palabras <- palabras[!grepl(" ", palabras)]          # solo palabras sueltas
  raices <- unique(.ascii(tolower(unlist(sj$raices))))
  list(elim = elim, cons = cons, prot_pal = palabras, prot_raiz = raices, tabla = sw)
}

tokenizar_y_filtrar <- function(ctx, d) {
  M <- "10. Tokenización y stopwords personalizadas"

  
  # ── 10.1 Tokenización ──────────────────────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio -> n_tokens_brutos", atributo = "texto",
    problema = "Texto continuo sin unidades de análisis",
    accion = "Se tokenizó cada mensaje (separación por espacios) y se descartaron los tokens que contienen números (26, 3er, 1ro), salvo los códigos de materia (inf_111) y respuestas tipo x2. Conteo guardado en n_tokens_brutos.",
    justificacion = "La tokenización es la base de n-gramas, TF-IDF y topic modeling: divide el texto en unidades (palabras).",
    ejemplo_col = "n_tokens_brutos", texto_ref = "texto_limpio",
    afectadas = sum(datos$n_tokens_brutos > 0),
    # CÓDIGO
    codigo = {
      tk <- strsplit(datos$texto_limpio, " ", fixed = TRUE)
      tk <- lapply(tk, function(t) t[nzchar(t) & (!grepl("[0-9]", t) | grepl("_", t) | grepl("^x[0-9]+$", t))])
      ctx$tokens <- tk
      datos$n_tokens_brutos <- lengths(tk)
    })
  

  # ── 10.2 Stopwords personalizadas ──────────────────────────────────────────────
  sw <- preparar_stopwords(ctx)
  tk <- ctx$tokens
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_limpio -> texto_tokens, n_tokens", atributo = "texto",
    problema = "Palabras vacías (stopwords) genéricas vs. significativas para el sentimiento",
    accion = "Se eliminaron las palabras vacías de la lista base, EXCEPTO: (a) pronombres que marcan género/sujeto (él, ella), (b) negaciones e intensificadores y (c) toda palabra del diccionario de sentimientos. Todo se lista en stopwords_aplicadas.csv.",
    justificacion = "Las listas genéricas (NLTK/spaCy) borran 'ella' o 'no', pero el sentimiento de ellas y de ellos es distinto y 'no me gusta' invierte la polaridad. Por eso la lista es personalizada y justificada palabra por palabra (shallow linguistic: se conserva información gramatical útil).",
    ejemplo_col = "texto_tokens", texto_ref = "texto_limpio",
    afectadas = sum(datos$n_tokens < datos$n_tokens_brutos),
    # CÓDIGO
    codigo = {
      u <- unique(unlist(tk))
      u_ascii <- .ascii(u)
      rx_raiz <- if (length(sw$prot_raiz)) paste0("^(", paste(sw$prot_raiz, collapse = "|"), ")") else "^$a"
      es_emoji <- startsWith(u, "emoji_")
      en_cons <- u %in% sw$cons
      en_prot <- u_ascii %in% sw$prot_pal | grepl(rx_raiz, u_ascii)
      en_elim <- u %in% sw$elim | u_ascii %in% sw$elim
      quitar_u <- en_elim & !en_cons & !en_prot & !es_emoji
      quitar <- u[quitar_u]
      tk_f <- lapply(tk, function(t) t[!(t %in% quitar)])
      datos$texto_tokens <- vapply(tk_f, paste, character(1), collapse = " ")
      datos$n_tokens <- lengths(tk_f)

      # registro didáctico: qué pasó con cada palabra vacía
      cnt <- table(unlist(tk))
      ocu <- as.integer(cnt[u])
      motivo <- ifelse(en_cons, "se conserva: regla propia (justificación en stopwords.csv)",
                ifelse(en_prot & en_elim, "se conserva: protegida por diccionario de sentimientos",
                ifelse(en_elim, "se elimina: lista base", NA)))
      log <- data.frame(palabra = u, decision = ifelse(quitar_u, "eliminada", "conservada"),
                        motivo = motivo, ocurrencias = ocu, stringsAsFactors = FALSE)
      log <- log[!is.na(log$motivo), ]
      jus <- sw$tabla$justificacion[match(log$palabra, sw$tabla$palabra)]
      log$justificacion <- ifelse(is.na(jus), "", jus)
      ctx$stop_log <- log[order(log$decision, -log$ocurrencias), ]

      tot0 <- sum(lengths(tk)); tot1 <- sum(lengths(tk_f))
      top <- utils::head(log[log$decision == "eliminada", ], 6)
      cons_riesgo <- log[log$decision == "conservada", ]
      ctx$nota <- sprintf(
        "Resultado: %s tokens -> %s (se eliminaron %s, %.1f%%). Más eliminadas: %s. Conservadas pese a estar en listas genéricas: %s apariciones (%s).",
        .fmt(tot0), .fmt(tot1), .fmt(tot0 - tot1), 100 * (tot0 - tot1) / max(tot0, 1),
        paste0(top$palabra, " (", top$ocurrencias, ")", collapse = ", "),
        .fmt(sum(cons_riesgo$ocurrencias)),
        paste(utils::head(cons_riesgo$palabra[order(-cons_riesgo$ocurrencias)], 8), collapse = ", "))
    })

  

  # ── 10.3 Quitar tildes de los tokens ───────────────────────────────────────────
  # ▌BITÁCORA OFICIAL
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_tokens", atributo = "texto",
    problema = "Mismo vocablo con y sin tilde (canción / cancion)",
    accion = "Ya aplicadas las stopwords, se quitaron las tildes de los tokens. Se conserva la ñ y la palabra 'él', que si perdiera la tilde se confundiría con el artículo 'el'.",
    justificacion = "En chat la gente escribe con y sin tilde; sin unificar, TF-IDF y LDA contarían 'cancion' y 'canción' como palabras distintas. Se hace DESPUÉS de las stopwords porque ahí hacían falta las tildes (él / el).",
    ejemplo_col = "texto_tokens",
    # CÓDIGO
    codigo = {
      tk2 <- strsplit(datos$texto_tokens, " ", fixed = TRUE)
      u2 <- unique(unlist(tk2))
      proteger <- sw$cons[sw$cons != .ascii(sw$cons) & .ascii(sw$cons) %in% sw$elim]   # solo "él"
      mapa <- stats::setNames(ifelse(u2 %in% proteger, u2, .sin_tilde(u2)), u2)
      datos$texto_tokens <- vapply(tk2, function(t) paste(mapa[t], collapse = " "), character(1))
    })
  d
}
