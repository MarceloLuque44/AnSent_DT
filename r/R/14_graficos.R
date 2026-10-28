# ==============================================================================
# 14_graficos.R  -  GRÁFICOS (devuelven objetos ggplot; el dashboard solo los dibuja)
# ------------------------------------------------------------------------------
# CATÁLOGO: 25 gráficos.  Todos funcionan con CUALQUIER rango de fechas, porque se
# dibujan con lo que devuelve analizar_periodo(datos, c("inicio", "fin")).
#
#  ORIGINALES (1-14)  <- los que pidió la lic; no se tocan
#   1  g_barras()              barras con % de cada sentimiento
#   2  g_barras_comparar()     barras agrupadas: periodo A contra B          (necesita cmp)
#   3  g_tiempo()              líneas: varios sentimientos en el tiempo
#   4  g_apilado()             áreas apiladas por periodo
#   5  g_polar()               coordenadas polares (rosa)
#   6  g_arana()               gráfico de araña (radar)
#   7  g_dispersion()          dispersión: un sentimiento contra otro
#   8  g_sankey()              Sankey: tópico -> sentimiento dominante       (CORREGIDO)
#   9  g_tfidf()               términos más distintivos (TF-IDF)
#  10  g_topicos()             palabras de cada tópico (LDA)
#  11  g_topicos_tiempo()      peso de cada tópico en el tiempo
#  12  g_upos()                categorías gramaticales (shallow linguistic)
#  13  g_nivel_mensaje()       un mensaje frente a su periodo ("8 % contra 7 %")
#  14  g_calor()               mapa de calor día de la semana x hora
#
#  AUMENTADOS (15-25)   -> ver la sección "---- graficos aumentados ----"
#  15 g_volumen            volumen de mensajes (contexto: por qué se usan porcentajes)
#  16 g_evolucion_anual    evolución de los sentimientos AÑO POR AÑO
#  17 g_sent_heat          mapa de calor sentimiento x tiempo
#  18 g_dominante          qué emoción domina en cada mes/semana/día
#  19 g_polaridad_tiempo   positivo / negativo / neutral / sin sentimiento detectado
#  20 g_sent_hora_heat     cómo cambia el ánimo durante el día
#  21 g_correlacion        qué sentimientos aparecen juntos
#  22 g_palabras           palabras más usadas
#  23 g_emojis             emojis más usados y su sentimiento
#  24 g_libreria_vs_propios  diccionario propio contra librería (syuzhet)   (necesita libreria = TRUE)
#  25 g_diferencia         qué sube y qué baja entre dos periodos           (necesita cmp)
#
# Uso:  a <- analizar_periodo(datos, c("2024-01-12", "2025-05-03"))
#       g <- graficos_todos(a)       # lista con todos los que se pudieron dibujar
#       g$G15_volumen                # uno solo
#       ver_graficos(a)              # los dibuja uno por uno en Plots
# Paquete requerido: ggplot2 (Sankey ya NO necesita ggalluvial).
# ==============================================================================

.gg <- function() { .requiere("ggplot2"); asNamespace("ggplot2") }
.pct_lab <- function(x) paste0(round(x, 1), "%")

# ---- Colores: cada sentimiento tiene SIEMPRE el mismo color en todos los gráficos -----------
.PAL <- c("#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51", "#8E5572", "#3A86FF", "#8338EC",
          "#FF006E", "#06D6A0", "#6D597A", "#B56576", "#355070", "#00B4D8", "#90BE6D")
.pal <- function(n) rep(.PAL, length.out = n)
.COL_SENT <- c(alegria = "#F4C20D", gratitud = "#2A9D8F", esperanza = "#06D6A0", seguridad = "#3A86FF",
               admiracion = "#8338EC", satisfaccion_tranquilidad = "#90BE6D", sorpresa = "#FF9F1C",
               confusion = "#8E5572", preocupacion = "#6D597A", tristeza = "#355070", enojo = "#E63946",
               decepcion = "#B56576", frustracion_cansancio = "#C2571A", ironia = "#FF006E",
               curiosidad = "#00B4D8")
.col_sent <- function(niveles) {
  v <- .COL_SENT[niveles]
  if (anyNA(v)) v <- stats::setNames(.pal(length(niveles)), niveles)   # nombres que no conozco: paleta general
  v
}
.sc_fill <- function(g, niveles) g$scale_fill_manual(values = .col_sent(niveles), name = NULL)
.sc_col  <- function(g, niveles) g$scale_color_manual(values = .col_sent(niveles), name = NULL)

# Eje de tiempo: acepta series mensuales (anio_mes) o de cualquier unidad (fecha)
.eje_t <- function(serie) {
  serie$mes <- if ("fecha" %in% names(serie)) as.Date(serie$fecha) else as.Date(paste0(serie$anio_mes, "-01"))
  serie
}

# ==============================================================================
# 1-14  ORIGINALES
# ==============================================================================

# 1. Barras horizontales con porcentaje: nivel de cada sentimiento en un periodo
g_barras <- function(niv, titulo = "Nivel de cada sentimiento", valor = "nivel_pct") {
  g <- .gg()
  niv$v <- niv[[valor]]
  niv <- niv[order(niv$v), , drop = FALSE]
  niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  g$ggplot(niv, g$aes(x = sentimiento, y = v)) +
    g$geom_col(fill = "#2E75B6") +
    g$geom_text(g$aes(label = .pct_lab(v)), hjust = -0.1, size = 3) +
    g$coord_flip() + g$scale_y_continuous(expand = g$expansion(mult = c(0, 0.15))) +
    g$labs(title = titulo, x = NULL, y = "% (promedio por mensaje)") + g$theme_minimal(base_size = 12)
}

# 2. Barras agrupadas: periodo A contra periodo B (niv_largo viene de niveles_por_periodo())
g_barras_comparar <- function(niv_largo, titulo = "Comparación de periodos") {
  g <- .gg()
  g$ggplot(niv_largo, g$aes(x = sentimiento, y = nivel_pct, fill = periodo)) +
    g$geom_col(position = "dodge") + g$coord_flip() +
    g$labs(title = titulo, x = NULL, y = "% (promedio por mensaje)", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 3. Evolución de varios sentimientos en un solo gráfico (serie: serie_sentimientos() o serie_periodo())
g_tiempo <- function(serie, sentimientos = NULL, titulo = "Evolución de los sentimientos") {
  g <- .gg()
  if (!is.null(sentimientos)) serie <- serie[serie$sentimiento %in% sentimientos, , drop = FALSE]
  serie <- .eje_t(serie)
  g$ggplot(serie, g$aes(x = mes, y = pct, color = sentimiento, group = sentimiento)) +
    g$geom_line() + g$geom_point(size = 1) + .sc_col(g, unique(serie$sentimiento)) +
    g$labs(title = titulo, x = NULL, y = "% (promedio por mensaje)", color = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 4. Áreas apiladas
g_apilado <- function(serie, titulo = "Composición de los sentimientos en el tiempo") {
  g <- .gg()
  serie <- .eje_t(serie)
  g$ggplot(serie, g$aes(x = mes, y = pct, fill = sentimiento)) + g$geom_area(position = "stack") +
    .sc_fill(g, unique(serie$sentimiento)) +
    g$labs(title = titulo, x = NULL, y = "% acumulado", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 5. Coordenadas polares (rosa de los sentimientos)
g_polar <- function(niv, titulo = "Sentimientos en coordenadas polares") {
  g <- .gg()
  niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  g$ggplot(niv, g$aes(x = sentimiento, y = nivel_pct, fill = sentimiento)) +
    g$geom_col(width = 1, color = "white") + g$coord_polar() + .sc_fill(g, levels(niv$sentimiento)) +
    g$labs(title = titulo, x = NULL, y = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "none")
}

# 6. Gráfico de araña (radar): perfil emocional de uno o varios periodos
g_arana <- function(niv_largo, titulo = "Perfil emocional (araña)") {
  g <- .gg()
  niv_largo$sentimiento <- factor(niv_largo$sentimiento, levels = unique(niv_largo$sentimiento))
  g$ggplot(niv_largo, g$aes(x = sentimiento, y = nivel_pct, group = periodo, color = periodo, fill = periodo)) +
    g$geom_polygon(alpha = 0.2) + g$geom_point() + g$coord_polar() +
    g$labs(title = titulo, x = NULL, y = NULL, color = NULL, fill = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "bottom")
}

# 7. Dispersión: un punto por mes/semana/día; relaciona dos sentimientos (x e y son nombres)
g_dispersion <- function(serie, x, y, titulo = NULL) {
  g <- .gg()
  k <- if ("fecha" %in% names(serie)) "fecha" else "anio_mes"
  a <- serie[serie$sentimiento == x, c(k, "pct")]
  b <- serie[serie$sentimiento == y, c(k, "pct")]
  d <- merge(a, b, by = k, suffixes = c("_x", "_y"))
  d$etiqueta <- as.character(d[[k]])
  g$ggplot(d, g$aes(x = pct_x, y = pct_y)) + g$geom_point(color = "#2E75B6", size = 2) +
    g$geom_text(g$aes(label = etiqueta), vjust = -0.8, size = 2.8) +
    g$geom_smooth(method = "lm", formula = y ~ x, se = FALSE, color = "grey40") +
    g$labs(title = titulo %||% paste("Dispersión:", x, "vs", y), x = paste(x, "(%)"), y = paste(y, "(%)")) +
    g$theme_minimal(base_size = 12)
}

# 8. SANKEY: tópico (LDA) -> sentimiento dominante.  m debe venir de mensajes_con_topico()
#    CORREGIDO: antes dependía de ggalluvial y salía en blanco cuando no había cruce o la
#    librería fallaba. Ahora se dibuja solo con ggplot2 y, si no hay datos, avisa por qué.
g_sankey <- function(m, titulo = "De qué se habla (tópico) y qué se siente (sentimiento dominante)") {
  g <- .gg()
  if (!all(c("topico", "sentimiento_dominante") %in% names(m)))
    stop("Primero usa mensajes_con_topico(a$mensajes, a$topicos).", call. = FALSE)
  nom <- nombres_sentimientos(m)
  d <- m[!is.na(m$topico) & m$sentimiento_dominante %in% nom, , drop = FALSE]
  if (!nrow(d))
    stop("Ningún mensaje tiene a la vez tópico y sentimiento dominante (con tópico: ", sum(!is.na(m$topico)),
         "; con sentimiento: ", sum(m$sentimiento_dominante %in% nom), "). Corre diagnostico_sankey(a).", call. = FALSE)
  tab <- as.data.frame(table(topico = d$topico, sentimiento = d$sentimiento_dominante), stringsAsFactors = FALSE)
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  tl <- sort(tapply(tab$Freq, tab$topico, sum), decreasing = TRUE)
  sr <- sort(tapply(tab$Freq, tab$sentimiento, sum), decreasing = TRUE)
  gap <- 0.03 * sum(tab$Freq)
  bloque <- function(tot) {
    n <- as.numeric(tot); ymin <- c(0, cumsum(n + gap))[seq_along(n)]
    data.frame(nombre = names(tot), n = n, ymin = ymin, ymax = ymin + n, stringsAsFactors = FALSE)
  }
  izq <- bloque(tl); der <- bloque(sr)
  tab$ot <- match(tab$topico, izq$nombre); tab$os <- match(tab$sentimiento, der$nombre)
  tab <- tab[order(tab$ot, tab$os), , drop = FALSE]
  tab$yl0 <- NA_real_
  for (t in izq$nombre) {
    i <- which(tab$topico == t)
    tab$yl0[i] <- izq$ymin[izq$nombre == t] + c(0, cumsum(tab$Freq[i]))[seq_along(i)]
  }
  tab <- tab[order(tab$os, tab$ot), , drop = FALSE]
  tab$yr0 <- NA_real_
  for (s in der$nombre) {
    i <- which(tab$sentimiento == s)
    tab$yr0[i] <- der$ymin[der$nombre == s] + c(0, cumsum(tab$Freq[i]))[seq_along(i)]
  }
  tab$yl1 <- tab$yl0 + tab$Freq; tab$yr1 <- tab$yr0 + tab$Freq
  xs <- seq(0, 1, length.out = 40); sg <- 3 * xs^2 - 2 * xs^3          # curva suave entre columnas
  x0 <- 0.12; x1 <- 0.88
  poly <- do.call(rbind, lapply(seq_len(nrow(tab)), function(k) {
    lo <- tab$yl0[k] + (tab$yr0[k] - tab$yl0[k]) * sg
    up <- tab$yl1[k] + (tab$yr1[k] - tab$yl1[k]) * sg
    data.frame(id = k, topico = tab$topico[k],
               x = c(x0 + (x1 - x0) * xs, x0 + (x1 - x0) * rev(xs)), y = c(lo, rev(up)), stringsAsFactors = FALSE)
  }))
  cols <- stats::setNames(.pal(nrow(izq)), izq$nombre)
  g$ggplot() +
    g$geom_polygon(data = poly, g$aes(x = x, y = y, group = id, fill = topico), alpha = 0.55) +
    g$geom_rect(data = izq, g$aes(xmin = 0, xmax = x0, ymin = ymin, ymax = ymax, fill = nombre)) +
    g$geom_rect(data = der, g$aes(xmin = x1, xmax = 1, ymin = ymin, ymax = ymax), fill = "grey55") +
    g$geom_text(data = izq, g$aes(x = -0.01, y = (ymin + ymax) / 2, label = paste0(nombre, " (", n, ")")), hjust = 1, size = 3.3) +
    g$geom_text(data = der, g$aes(x = 1.01, y = (ymin + ymax) / 2, label = paste0(nombre, " (", n, ")")), hjust = 0, size = 3.3) +
    g$scale_fill_manual(values = cols, guide = "none") + g$scale_x_continuous(limits = c(-0.3, 1.35)) +
    g$labs(title = titulo, subtitle = "Ancho = cantidad de mensajes (solo los que tienen tópico y sentimiento)") +
    g$theme_void(base_size = 12)
}

# Si el Sankey sale vacío: muestra en qué paso se pierden los mensajes
diagnostico_sankey <- function(a) {
  m <- mensajes_con_topico(a$mensajes, a$topicos)
  nom <- nombres_sentimientos(m)
  cat("Mensajes del periodo       :", nrow(m), "\n")
  cat("Con tópico asignado        :", sum(!is.na(m$topico)), "\n")
  cat("Con sentimiento dominante  :", sum(m$sentimiento_dominante %in% nom), "\n")
  cat("Con ambos (los del Sankey) :", sum(!is.na(m$topico) & m$sentimiento_dominante %in% nom), "\n")
  cat("Claves de documento de los tópicos :", paste(utils::head(a$topicos$dominante$doc, 3), collapse = ", "), "\n")
  cat("Fechas de los mensajes             :", paste(utils::head(format(m$fecha, "%Y-%m-%d"), 3), collapse = ", "), "\n")
  cat("(Si 'con tópico' es 0, las claves no coinciden con las fechas.)\n")
  invisible(m)
}

# 9. TF-IDF: términos más distintivos de cada documento (mes o periodo)
g_tfidf <- function(top, titulo = "Términos más distintivos (TF-IDF)") {
  g <- .gg()
  if (is.null(top) || !nrow(top)) stop("No hay resultados de TF-IDF (el periodo necesita al menos 2 meses).", call. = FALSE)
  clave <- paste(top$doc, top$token, sep = "___")
  top$clave <- factor(clave, levels = rev(unique(clave)))
  g$ggplot(top, g$aes(x = tf_idf, y = clave)) + g$geom_col(fill = "#C55A11") +
    g$facet_wrap(~doc, scales = "free_y") + g$scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
    g$labs(title = titulo, x = "TF-IDF", y = NULL) + g$theme_minimal(base_size = 11)
}

# 10. Tópicos: palabras más probables de cada tópico
g_topicos <- function(terminos, titulo = "Tópicos (LDA): palabras más probables") {
  g <- .gg()
  terminos$panel <- paste0(terminos$topico, ": ", terminos$etiqueta)
  clave <- paste(terminos$panel, terminos$termino, sep = "___")
  terminos$clave <- factor(clave, levels = rev(unique(clave)))
  g$ggplot(terminos, g$aes(x = beta, y = clave)) + g$geom_col(fill = "#548235") +
    g$facet_wrap(~panel, scales = "free_y") + g$scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
    g$labs(title = titulo, x = "probabilidad (beta)", y = NULL) + g$theme_minimal(base_size = 10)
}

# 11. Peso de cada tópico por mes
g_topicos_tiempo <- function(peso_mes, titulo = "Peso de cada tópico por mes") {
  g <- .gg()
  peso_mes$mes <- as.Date(paste0(peso_mes$anio_mes, "-01"))
  peso_mes$panel <- paste0(peso_mes$topico, ": ", peso_mes$etiqueta)
  g$ggplot(peso_mes, g$aes(x = mes, y = peso_pct, color = panel, group = panel)) + g$geom_line() +
    g$labs(title = titulo, x = NULL, y = "% del mes", color = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "bottom")
}

# 12. Shallow linguistic: distribución de categorías gramaticales
g_upos <- function(upos, titulo = "Categorías gramaticales (shallow linguistic)") {
  g <- .gg()
  upos$clase <- factor(upos$clase, levels = rev(upos$clase))
  g$ggplot(upos, g$aes(x = clase, y = pct)) + g$geom_col(fill = "#7030A0") +
    g$geom_text(g$aes(label = .pct_lab(pct)), hjust = -0.1, size = 3) + g$coord_flip() +
    g$scale_y_continuous(expand = g$expansion(mult = c(0, 0.15))) +
    g$labs(title = titulo, x = NULL, y = "% de las palabras") + g$theme_minimal(base_size = 12)
}

# 13. "Este mensaje es 8 % alegría; la temporada, 7 %" (df viene de nivel_mensaje())
g_nivel_mensaje <- function(df, titulo = "Nivel del mensaje frente a su periodo") {
  g <- .gg()
  largo <- rbind(data.frame(sentimiento = df$sentimiento, tipo = "mensaje", pct = df$mensaje_pct),
                 data.frame(sentimiento = df$sentimiento, tipo = "periodo", pct = df$periodo_pct))
  g$ggplot(largo, g$aes(x = sentimiento, y = pct, fill = tipo)) + g$geom_col(position = "dodge") + g$coord_flip() +
    g$labs(title = titulo, x = NULL, y = "%", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 14. Mapa de calor de actividad (día de la semana x hora)
g_calor <- function(m, titulo = "Actividad del grupo: día de la semana x hora") {
  g <- .gg()
  tab <- as.data.frame(table(dia = m$dia_semana, hora = m$hora), stringsAsFactors = FALSE)
  
  # Orden de lunes a domingo (acepta con o sin tildes y en minúscula o mayúscula)
  orden <- c("lunes", "martes", "miercoles", "miércoles", "jueves", "viernes",
             "sabado", "sábado", "domingo")
  presentes <- unique(tab$dia)
  niveles <- orden[tolower(orden) %in% tolower(presentes)]
  niveles <- unique(c(presentes[match(tolower(niveles), tolower(presentes))],
                      presentes))                      # lo que no esté en la lista va al final
  # rev(): ggplot dibuja el primer nivel abajo; así "lunes" queda ARRIBA
  tab$dia  <- factor(tab$dia, levels = rev(niveles))
  tab$hora <- as.integer(tab$hora)                     # 0, 1, 2, ... 10, 11 (no "0", "1", "10", "11", "2")
  
  g$ggplot(tab, g$aes(x = hora, y = dia, fill = Freq)) + g$geom_tile() +
    g$scale_x_continuous(breaks = 0:23) +
    g$scale_fill_gradient(low = "white", high = "#C00000") +
    g$labs(title = titulo, x = "hora", y = NULL, fill = "mensajes") + g$theme_minimal(base_size = 12)
}





# ==============================================================================
# ---- graficos aumentados ----
# 15-25. Adaptados a TUS columnas (pct_*, fecha, hora, autor, emojis_lista, texto_tokens...)
# y a CUALQUIER rango de fechas: la unidad de tiempo se elige sola
#   rango <= 31 días -> por día | <= 180 días -> por semana | más largo -> por mes
# ==============================================================================

.HEAT <- c("#F8F9FA", "#FFE8A3", "#F4A261", "#E76F51", "#6A040F")

# Prepara columnas de fecha/hora/día de la semana (no depende del idioma de R)
.pre <- function(m) {
  if (is.null(m) || !nrow(m)) stop("No hay mensajes en el periodo.", call. = FALSE)
  m$.dia  <- as.Date(m$fecha)
  m$.hora <- if ("hora" %in% names(m)) suppressWarnings(as.integer(m$hora)) else rep(NA_integer_, nrow(m))
  m$.wd   <- factor(as.integer(format(m$.dia, "%u")), levels = 1:7,
                    labels = c("Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"))
  m
}
.unidad_auto <- function(f) {
  d <- as.numeric(diff(range(f, na.rm = TRUE)))
  if (d <= 31) "dia" else if (d <= 180) "semana" else "mes"
}
.bin <- function(f, por) switch(por, dia = f, semana = f - (as.integer(format(f, "%u")) - 1),
                                mes = as.Date(format(f, "%Y-%m-01")))
.LAB_UNI <- c(dia = "día", semana = "semana", mes = "mes")
.ANCHO <- c(dia = 0.9, semana = 6, mes = 25)

# Serie de cada sentimiento en la unidad adecuada al rango (columnas: fecha, sentimiento, pct, n_mensajes)
serie_periodo <- function(m, por = "auto") {
  nom <- nombres_sentimientos(m); m <- .pre(m)
  if (identical(por, "auto")) por <- .unidad_auto(m$.dia)
  m$.bin <- .bin(m$.dia, por)
  partes <- lapply(nom, function(s) {
    a <- tapply(m[[paste0("pct_", s)]], m$.bin, mean, na.rm = TRUE)
    data.frame(fecha = as.Date(names(a)), sentimiento = s, pct = as.numeric(a), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, partes)
  n <- table(m$.bin)
  out$n_mensajes <- as.integer(n[as.character(out$fecha)])
  attr(out, "por") <- por
  out
}

# ---- ACTIVIDAD --------------------------------------------------------------------------------

# 15. Volumen de mensajes en el tiempo
g_volumen <- function(m, por = "auto", titulo = NULL) {
  g <- .gg(); m <- .pre(m)
  if (identical(por, "auto")) por <- .unidad_auto(m$.dia)
  d <- as.data.frame(table(fecha = .bin(m$.dia, por)), stringsAsFactors = FALSE); d$fecha <- as.Date(d$fecha)
  g$ggplot(d, g$aes(fecha, Freq)) +
    g$geom_area(fill = "#3A86FF", alpha = 0.18) + g$geom_line(color = "#3A86FF", linewidth = 1) +
    g$geom_point(color = "#3A86FF", size = 1.8) +
    g$labs(title = titulo %||% paste("Volumen de mensajes por", .LAB_UNI[[por]]), x = NULL, y = "mensajes") +
    g$theme_minimal(base_size = 12)
}


# 16. EVOLUCIÓN POR AÑO: cómo cambia cada sentimiento de un año a otro (los más presentes)
g_evolucion_anual <- function(m, top = 6) {
  g <- .gg(); m <- .pre(m); nom <- nombres_sentimientos(m)
  anio <- format(m$.dia, "%Y")
  if (length(unique(anio)) < 2)
    stop("Se necesitan al menos 2 años en el rango. Para rangos cortos usa G03 (evolución en el tiempo).", call. = FALSE)
  med <- vapply(nom, function(s) mean(m[[paste0("pct_", s)]], na.rm = TRUE), numeric(1))
  sel <- names(sort(med, decreasing = TRUE))[seq_len(min(top, length(nom)))]
  n <- table(anio)
  meses <- tapply(format(m$.dia, "%m"), anio, function(x) length(unique(x)))
  etiqueta <- paste0(names(n), ifelse(meses[names(n)] < 12, "*", ""), "\n(", format(as.integer(n), big.mark = ","), " mensajes)")
  d <- do.call(rbind, lapply(sel, function(s) {
    a <- tapply(m[[paste0("pct_", s)]], anio, mean, na.rm = TRUE)
    data.frame(anio = names(a), sentimiento = s, pct = as.numeric(a), stringsAsFactors = FALSE)
  }))
  d$x <- factor(d$anio, levels = names(n), labels = etiqueta)
  g$ggplot(d, g$aes(x, pct, color = sentimiento, group = sentimiento)) +
    g$geom_line(linewidth = 1.1) + g$geom_point(size = 3) +
    g$geom_text(g$aes(label = .pct_lab(pct)), vjust = -0.9, size = 2.8, show.legend = FALSE) +
    .sc_col(g, sel) + g$scale_y_continuous(expand = g$expansion(mult = c(0.05, 0.15))) +
    g$labs(title = "Evolución de los sentimientos por año",
           subtitle = paste0("Los ", length(sel), " más presentes. * = año incompleto (menos de 12 meses). Son porcentajes, no cantidades."),
           x = NULL, y = "% promedio por mensaje") +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# ---- SENTIMIENTOS ---------------------------------------------------------------------------

# 17. Mapa de calor sentimiento x tiempo
g_sent_heat <- function(m, por = "auto") {
  g <- .gg(); s <- serie_periodo(m, por); por <- attr(s, "por")
  fmt <- if (por == "mes") "%Y-%m" else "%Y-%m-%d"
  fechas <- sort(unique(s$fecha)); s$x <- factor(format(s$fecha, fmt), levels = format(fechas, fmt))
  g$ggplot(s, g$aes(x, sentimiento, fill = pct)) + g$geom_tile(color = "white", linewidth = 0.4) +
    g$scale_fill_gradientn(colors = .HEAT, name = "%") +
    g$labs(title = paste("Mapa de calor emocional por", .LAB_UNI[[por]]), subtitle = "Cuanto más rojo, más presente", x = NULL, y = NULL) +
    g$theme_minimal(base_size = 11) +
    g$theme(panel.grid = g$element_blank(), axis.text.x = g$element_text(angle = 60, hjust = 1), legend.position = "bottom")
}

# 20. ¿Cómo cambia el ánimo durante el día? (sentimiento x hora)
g_sent_hora_heat <- function(m) {
  g <- .gg(); m <- .pre(m); nom <- nombres_sentimientos(m)
  L <- do.call(rbind, lapply(nom, function(s) {
    a <- tapply(m[[paste0("pct_", s)]], factor(m$.hora, levels = 0:23), mean, na.rm = TRUE)
    data.frame(hora = 0:23, sentimiento = s, pct = as.numeric(a), stringsAsFactors = FALSE)
  }))
  L <- L[!is.na(L$pct), , drop = FALSE]
  g$ggplot(L, g$aes(hora, sentimiento, fill = pct)) + g$geom_tile(color = "white", linewidth = 0.4) +
    g$scale_fill_gradientn(colors = .HEAT, name = "%") + g$scale_x_continuous(breaks = seq(0, 23, 3)) +
    g$labs(title = "¿Cómo cambia el ánimo durante el día?", subtitle = "Sentimiento promedio por hora", x = "hora", y = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(panel.grid = g$element_blank(), legend.position = "bottom")
}

# 18. Qué emoción domina en cada mes/semana/día (barras al 100 %)
g_dominante <- function(m, por = "auto") {
  g <- .gg(); m <- .pre(m); nom <- nombres_sentimientos(m)
  if (identical(por, "auto")) por <- .unidad_auto(m$.dia)
  d <- m[m$sentimiento_dominante %in% nom, , drop = FALSE]
  if (!nrow(d)) stop("Ningún mensaje tiene sentimiento dominante en este periodo.", call. = FALSE)
  tab <- as.data.frame(table(fecha = .bin(d$.dia, por), dom = d$sentimiento_dominante), stringsAsFactors = FALSE)
  tab$fecha <- as.Date(tab$fecha)
  g$ggplot(tab, g$aes(fecha, Freq, fill = dom)) + g$geom_col(position = "fill", width = .ANCHO[[por]]) +
    .sc_fill(g, unique(tab$dom)) + g$scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    g$labs(title = paste("Qué emoción domina cada", .LAB_UNI[[por]]), subtitle = "Solo mensajes con algún sentimiento detectado",
           x = NULL, y = NULL) + g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 21. ¿Qué sentimientos aparecen juntos? (correlación entre sentimientos por mensaje)
g_correlacion <- function(m) {
  g <- .gg(); nom <- nombres_sentimientos(m)
  x <- m[paste0("pct_", nom)]; names(x) <- nom
  x <- x[, vapply(x, function(z) isTRUE(stats::sd(z, na.rm = TRUE) > 0), logical(1)), drop = FALSE]
  if (ncol(x) < 2) stop("Hay menos de 2 sentimientos con variación en este periodo.", call. = FALSE)
  cm <- stats::cor(x, use = "pairwise.complete.obs")
  d <- as.data.frame(as.table(cm)); names(d) <- c("a", "b", "r")
  g$ggplot(d, g$aes(a, b, fill = r)) + g$geom_tile(color = "white") +
    g$geom_text(g$aes(label = sprintf("%.2f", r)), size = 2.8) +
    g$scale_fill_gradient2(low = "#3A86FF", mid = "white", high = "#E76F51", limits = c(-1, 1), name = "correlación") +
    g$labs(title = "¿Qué sentimientos aparecen juntos?", subtitle = "Correlación entre sentimientos por mensaje", x = NULL, y = NULL) +
    g$theme_minimal(base_size = 11) +
    g$theme(axis.text.x = g$element_text(angle = 45, hjust = 1), panel.grid = g$element_blank(), legend.position = "bottom")
}

# ---- PALABRAS Y EMOJIS -------------------------------------------------------------------

# 22. Palabras más usadas en el periodo (de texto_tokens; sin las negaciones de PALABRAS_SIN_TEMA)
g_palabras <- function(m, n = 25, excluir = if (exists("PALABRAS_SIN_TEMA")) PALABRAS_SIN_TEMA else character(0)) {
  g <- .gg()
  x <- m$texto_tokens[!is.na(m$texto_tokens) & nzchar(m$texto_tokens)]
  tk <- unlist(strsplit(x, " ", fixed = TRUE)); tk <- tk[nzchar(tk) & !(tk %in% excluir)]
  if (!length(tk)) stop("No hay palabras en el periodo.", call. = FALSE)
  t <- utils::head(sort(table(tk), decreasing = TRUE), n)
  d <- data.frame(p = factor(names(t), levels = rev(names(t))), n = as.integer(t))
  g$ggplot(d, g$aes(p, n, fill = n)) + g$geom_col(width = 0.75) + g$coord_flip() +
    g$scale_fill_gradient(low = "#9BC5FF", high = "#8338EC", guide = "none") +
    g$labs(title = paste("Las", nrow(d), "palabras más usadas"), x = NULL, y = "veces") + g$theme_minimal(base_size = 12)
}

# 23. Emojis más usados en el periodo y su sentimiento (de emojis_lista + config/emojis.csv)
g_emojis <- function(m, n = 20, f_dic = "config/emojis.csv") {
  g <- .gg()
  x <- m$emojis_lista[!is.na(m$emojis_lista) & m$emojis_lista != "ninguno"]
  e <- unlist(strsplit(x, " ", fixed = TRUE)); e <- e[nzchar(e)]
  if (!length(e)) stop("No hay emojis en este periodo.", call. = FALSE)
  t <- utils::head(sort(table(e), decreasing = TRUE), n)
  d <- data.frame(emoji = names(t), n = as.integer(t), sentimiento = "sin dato", etiqueta = names(t), stringsAsFactors = FALSE)
  dic <- if (file.exists(f_dic)) tryCatch(readr::read_csv(f_dic, show_col_types = FALSE, progress = FALSE), error = function(e) NULL) else NULL
  if (!is.null(dic) && all(c("emoji", "sentimiento") %in% names(dic))) {
    i <- match(d$emoji, dic$emoji)
    s <- dic$sentimiento[i]; d$sentimiento <- ifelse(is.na(s) | s == "", "sin dato", s)
    if ("significado_es" %in% names(dic)) { z <- dic$significado_es[i]; d$etiqueta <- ifelse(is.na(z) | z == "", d$emoji, z) }
  }
  d$etiqueta <- make.unique(d$etiqueta); d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
  g$ggplot(d, g$aes(etiqueta, n, fill = sentimiento)) + g$geom_col(width = 0.75) + g$coord_flip() +
    .sc_fill(g, unique(d$sentimiento)) +
    g$labs(title = "Emojis más usados y su sentimiento", x = NULL, y = "veces (en el texto)") +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# ---- COBERTURA, LIBRERÍA Y COMPARACIÓN ------------------------------------------------------

# 19. Polaridad en el tiempo (incluye "sin sentimiento detectado" para no confundirlo con neutral)
g_polaridad_tiempo <- function(m, por = "auto") {
  g <- .gg(); m <- .pre(m); nom <- nombres_sentimientos(m)
  if (identical(por, "auto")) por <- .unidad_auto(m$.dia)
  cat <- ifelse(!(m$sentimiento_dominante %in% nom), "sin sentimiento detectado", as.character(m$polaridad_msg))
  cat <- factor(cat, levels = c("positivo", "neutral", "negativo", "sin sentimiento detectado"))
  tab <- as.data.frame(table(fecha = .bin(m$.dia, por), cat = cat), stringsAsFactors = FALSE); tab$fecha <- as.Date(tab$fecha)
  cols <- c(positivo = "#2A9D8F", neutral = "#E9C46A", negativo = "#E76F51", `sin sentimiento detectado` = "grey80")
  g$ggplot(tab, g$aes(fecha, Freq, fill = cat)) + g$geom_col(position = "fill", width = .ANCHO[[por]]) +
    g$scale_fill_manual(values = cols, name = NULL, drop = FALSE) +
    g$scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    g$labs(title = paste("Polaridad de los mensajes por", .LAB_UNI[[por]]),
           subtitle = "Neutral = hay sentimientos que se cancelan; gris = el diccionario no detectó ninguno", x = NULL, y = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 24. Con y sin librería: positivo / negativo / neutral  (dist = a$comparacion$distribucion)
g_libreria_vs_propios <- function(dist, titulo = "Polaridad: diccionario propio vs. librería (syuzhet)") {
  g <- .gg()
  largo <- rbind(data.frame(polaridad = dist$polaridad, fuente = "diccionario propio", pct = dist$propios_pct),
                 data.frame(polaridad = dist$polaridad, fuente = "librería (syuzhet)", pct = dist$libreria_pct))
  largo$polaridad <- factor(largo$polaridad, levels = c("positivo", "neutral", "negativo"))
  g$ggplot(largo, g$aes(polaridad, pct, fill = fuente)) + g$geom_col(position = "dodge", width = 0.7) +
    g$geom_text(g$aes(label = .pct_lab(pct)), position = g$position_dodge(width = 0.7), vjust = -0.4, size = 3.2) +
    g$scale_fill_manual(values = c(`diccionario propio` = "#2E75B6", `librería (syuzhet)` = "#E76F51"), name = NULL) +
    g$scale_y_continuous(expand = g$expansion(mult = c(0, 0.12))) +
    g$labs(title = titulo, x = NULL, y = "% de mensajes") + g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# 25. Diferencia entre dos periodos: qué sube y qué baja (niv_largo = cmp$niveles; B menos A)
g_diferencia <- function(niv_largo, titulo = NULL) {
  g <- .gg(); per <- unique(niv_largo$periodo)
  if (length(per) != 2) stop("Se necesitan exactamente 2 periodos.", call. = FALSE)
  a <- niv_largo[niv_largo$periodo == per[1], ]; b <- niv_largo[niv_largo$periodo == per[2], ]
  d <- data.frame(sentimiento = a$sentimiento, dif = b$nivel_pct[match(a$sentimiento, b$sentimiento)] - a$nivel_pct)
  d <- d[order(d$dif), , drop = FALSE]; d$sentimiento <- factor(d$sentimiento, levels = d$sentimiento); d$sube <- d$dif > 0
  g$ggplot(d, g$aes(sentimiento, dif, fill = sube)) + g$geom_col() + g$coord_flip() +
    g$geom_hline(yintercept = 0, color = "grey40") +
    g$scale_fill_manual(values = c(`TRUE` = "#2A9D8F", `FALSE` = "#E76F51"), guide = "none") +
    g$labs(title = titulo %||% "¿Qué cambió entre los dos periodos?", subtitle = paste(per[2], "menos", per[1], "(puntos porcentuales)"),
           x = NULL, y = "diferencia") + g$theme_minimal(base_size = 12)
}

# ==============================================================================
# ---- utilidades para el DASHBOARD: rango de fechas LIBRE y lista de gráficos ----
# ==============================================================================

# Acepta "12/01/2024" (dd/mm/aaaa), "12-01-2024" o "2024-01-12"
fecha_libre <- function(x) {
  x <- trimws(as.character(x))
  f <- if (grepl("^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$", x)) as.Date(x, format = "%Y-%m-%d")
  else if (grepl("^[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{4}$", x)) as.Date(gsub("-", "/", x), format = "%d/%m/%Y")
  else as.Date(NA)
  if (is.na(f)) stop("No entiendo la fecha '", x, "'. Usa dd/mm/aaaa o aaaa-mm-dd.", call. = FALSE)
  f
}

# Ordena, recorta al rango que tiene el dataset y devuelve c("aaaa-mm-dd", "aaaa-mm-dd")
rango_libre <- function(desde, hasta, datos = NULL) {
  ini <- fecha_libre(desde); fin <- fecha_libre(hasta)
  if (ini > fin) { t <- ini; ini <- fin; fin <- t }
  if (!is.null(datos)) {
    r <- range(datos$mensajes$fecha, na.rm = TRUE)
    ini <- max(ini, r[1]); fin <- min(fin, r[2])
    if (ini > fin) stop("Ese rango no tiene datos. El dataset va de ", r[1], " a ", r[2], ".", call. = FALSE)
  }
  c(format(ini), format(fin))
}

# analizar_rango(datos, "12/01/2024", "03/05/2025")  = analizar_periodo() con fechas escritas libremente
analizar_rango <- function(datos, desde, hasta, ...) analizar_periodo(datos, rango_libre(desde, hasta, datos), ...)

GRAFICOS_CATALOGO <- data.frame(
  id = sprintf("G%02d", 1:25),
  funcion = c("g_barras", "g_barras_comparar", "g_tiempo", "g_apilado", "g_polar", "g_arana", "g_dispersion",
              "g_sankey", "g_tfidf", "g_topicos", "g_topicos_tiempo", "g_upos", "g_nivel_mensaje", "g_calor",
              "g_volumen", "g_evolucion_anual", "g_sent_heat", "g_dominante", "g_polaridad_tiempo",
              "g_sent_hora_heat", "g_correlacion", "g_palabras", "g_emojis", "g_libreria_vs_propios", "g_diferencia"),
  grupo = c(rep("sentimientos", 7), "tópicos y sentimientos", "TF-IDF", "tópicos", "tópicos", "shallow", "mensaje",
            "actividad", "actividad", "evolución por año", "sentimientos", "sentimientos", "polaridad",
            "sentimientos", "sentimientos", "palabras", "emojis", "librería", "comparación"),
  necesita = c("a", "cmp", "a", "a", "a", "a o cmp", "a", "a$topicos", "a$tfidf", "a$topicos", "a$topicos", "a$shallow",
               "a", "a", rep("a", 9), "a$comparacion", "cmp"),
  stringsAsFactors = FALSE)
listar_graficos <- function() GRAFICOS_CATALOGO

.necesita <- function(x, que) { if (is.null(x)) stop("Falta ", que, ".", call. = FALSE); x }

# Devuelve una lista con todos los gráficos que se pudieron dibujar para ese rango.
#   a   = analizar_periodo(...)        cmp = comparar_periodos(...)  (opcional: habilita G02, G06 y G33)
#   solo = c(1, 8, 15)  o  c("G15_volumen")  para pedir algunos
graficos_todos <- function(a, cmp = NULL, solo = NULL, verbose = TRUE) {
  m <- a$mensajes; niv <- a$nivel; nom <- niv$sentimiento
  top2 <- nom[order(-niv$nivel_pct)][1:2]
  ser <- tryCatch(serie_periodo(m), error = function(e) NULL)
  niv1 <- niv; niv1$periodo <- a$periodo$nombre
  ej <- if ("hits_total" %in% names(m)) m[which.max(m$hits_total), , drop = FALSE] else m[1, , drop = FALSE]
  L <- list(
    G01_barras         = function() g_barras(niv, paste("Sentimientos propios:", a$periodo$nombre)),
    G02_barras_comparar = function() g_barras_comparar(.necesita(cmp, "cmp (usa comparar_periodos)")$niveles),
    G03_tiempo         = function() g_tiempo(.necesita(ser, "la serie")),
    G04_apilado        = function() g_apilado(.necesita(ser, "la serie")),
    G05_polar          = function() g_polar(niv),
    G06_arana          = function() g_arana(if (!is.null(cmp)) cmp$niveles else niv1),
    G07_dispersion     = function() g_dispersion(.necesita(ser, "la serie"), top2[1], top2[2]),
    G08_sankey         = function() g_sankey(mensajes_con_topico(m, .necesita(a$topicos, "los tópicos (LDA)"))),
    G09_tfidf          = function() g_tfidf(a$tfidf),
    G10_topicos        = function() g_topicos(.necesita(a$topicos, "los tópicos (LDA)")$terminos),
    G11_topicos_tiempo = function() g_topicos_tiempo(.necesita(a$topicos, "los tópicos (LDA)")$peso_mes),
    G12_upos           = function() g_upos(.necesita(a$shallow, "shallow (usa shallow = TRUE)")$upos),
    G13_nivel_mensaje  = function() g_nivel_mensaje(nivel_mensaje(ej, m), "Mensaje con más coincidencias frente al periodo"),
    G14_calor          = function() g_calor(m),
    G15_volumen        = function() g_volumen(m),
    G16_evolucion_anual = function() g_evolucion_anual(m),
    G17_sent_heat      = function() g_sent_heat(m),
    G18_dominante      = function() g_dominante(m),
    G19_polaridad_tiempo = function() g_polaridad_tiempo(m),
    G20_sent_hora_heat = function() g_sent_hora_heat(m),
    G21_correlacion    = function() g_correlacion(m),
    G22_palabras       = function() g_palabras(m),
    G23_emojis         = function() g_emojis(m),
    G24_libreria_vs_propios = function() g_libreria_vs_propios(.necesita(a$comparacion, "la librería (usa libreria = TRUE)")$distribucion),
    G25_diferencia     = function() g_diferencia(.necesita(cmp, "cmp (usa comparar_periodos)")$niveles))
  if (!is.null(solo)) {
    if (is.numeric(solo)) solo <- names(L)[solo]
    L <- L[intersect(names(L), solo)]
  }
  out <- list(); fallos <- character()
  for (nm in names(L)) {
    r <- tryCatch(L[[nm]](), error = function(e) conditionMessage(e))
    if (inherits(r, "ggplot")) out[[nm]] <- r else fallos[nm] <- as.character(r)
  }
  if (verbose) {
    cat("Gráficos listos:", length(out), "de", length(L), "\n")
    if (length(fallos)) for (nm in names(fallos)) cat(sprintf("  %-26s no se dibujó: %s\n", nm, fallos[[nm]]))
  }
  attr(out, "fallos") <- fallos
  out
}

# Dibuja los gráficos uno por uno en la pestaña Plots (para revisarlos)
ver_graficos <- function(a, cmp = NULL, solo = NULL, pausa = 0) {
  gs <- graficos_todos(a, cmp, solo)
  for (nm in names(gs)) { cat(nm, "\n"); print(gs[[nm]]); if (pausa > 0) Sys.sleep(pausa) }
  invisible(gs)
}
