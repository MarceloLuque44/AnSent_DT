# ==============================================================================
# 14_graficos.R  -  GRÁFICOS (devuelven objetos ggplot; el dashboard solo los dibuja)
# ------------------------------------------------------------------------------
#  función:
#   barras con porcentajes ............ g_barras(), g_barras_comparar()
#   varios sentimientos en un gráfico . g_tiempo(), g_apilado()
#   coordenadas polares ............... g_polar()
#   gráfico de araña .................. g_arana()
#   gráficos de tiempo ................ g_tiempo()
#   dispersión ........................ g_dispersion()
#   Sankey ............................ g_sankey()   (tópico -> sentimiento)
#   cartograma ........................ g_calor() (mapa de calor día x hora; pendiente de
#                                       confirmar con la lic, el chat no tiene datos geográficos)
# Además: g_tfidf(), g_topicos(), g_topicos_tiempo(), g_upos(), g_nivel_mensaje()
# Paquete requerido: ggplot2.  Sankey: ggalluvial.
# ==============================================================================

.gg <- function() { .requiere("ggplot2"); asNamespace("ggplot2") }
.pct_lab <- function(x) paste0(round(x, 1), "%")

# Barras horizontales con porcentaje: nivel de cada sentimiento en un periodo
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

# Barras agrupadas: periodo A contra periodo B (niv_largo viene de niveles_por_periodo())
g_barras_comparar <- function(niv_largo, titulo = "Comparación de periodos") {
  g <- .gg()
  g$ggplot(niv_largo, g$aes(x = sentimiento, y = nivel_pct, fill = periodo)) +
    g$geom_col(position = "dodge") + g$coord_flip() +
    g$labs(title = titulo, x = NULL, y = "% (promedio por mensaje)", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# Evolución mensual de varios sentimientos en un solo gráfico (serie viene de serie_sentimientos())
g_tiempo <- function(serie, sentimientos = NULL, titulo = "Evolución mensual de los sentimientos") {
  g <- .gg()
  if (!is.null(sentimientos)) serie <- serie[serie$sentimiento %in% sentimientos, , drop = FALSE]
  serie$mes <- as.Date(paste0(serie$anio_mes, "-01"))
  g$ggplot(serie, g$aes(x = mes, y = pct, color = sentimiento, group = sentimiento)) +
    g$geom_line() + g$geom_point(size = 1) +
    g$labs(title = titulo, x = NULL, y = "% (promedio por mensaje)", color = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

g_apilado <- function(serie, titulo = "Composición de los sentimientos por mes") {
  g <- .gg()
  serie$mes <- as.Date(paste0(serie$anio_mes, "-01"))
  g$ggplot(serie, g$aes(x = mes, y = pct, fill = sentimiento)) + g$geom_area(position = "stack") +
    g$labs(title = titulo, x = NULL, y = "% acumulado", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# Coordenadas polares (rosa de los sentimientos)
g_polar <- function(niv, titulo = "Sentimientos en coordenadas polares") {
  g <- .gg()
  niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  g$ggplot(niv, g$aes(x = sentimiento, y = nivel_pct, fill = sentimiento)) +
    g$geom_col(width = 1, color = "white") + g$coord_polar() +
    g$labs(title = titulo, x = NULL, y = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "none")
}

# Gráfico de araña (radar): perfil emocional de uno o varios periodos
g_arana <- function(niv_largo, titulo = "Perfil emocional (araña)") {
  g <- .gg()
  niv_largo$sentimiento <- factor(niv_largo$sentimiento, levels = unique(niv_largo$sentimiento))
  g$ggplot(niv_largo, g$aes(x = sentimiento, y = nivel_pct, group = periodo, color = periodo, fill = periodo)) +
    g$geom_polygon(alpha = 0.2) + g$geom_point() + g$coord_polar() +
    g$labs(title = titulo, x = NULL, y = NULL, color = NULL, fill = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "bottom")
}

# Dispersión: un mes = un punto; relaciona dos sentimientos (x e y son nombres de sentimientos)
g_dispersion <- function(serie, x, y, titulo = NULL) {
  g <- .gg()
  a <- serie[serie$sentimiento == x, c("anio_mes", "pct")]
  b <- serie[serie$sentimiento == y, c("anio_mes", "pct")]
  d <- merge(a, b, by = "anio_mes", suffixes = c("_x", "_y"))
  g$ggplot(d, g$aes(x = pct_x, y = pct_y)) + g$geom_point(color = "#2E75B6", size = 2) +
    g$geom_text(g$aes(label = anio_mes), vjust = -0.8, size = 2.8) +
    g$geom_smooth(method = "lm", formula = y ~ x, se = FALSE, color = "grey40") +
    g$labs(title = titulo %||% paste("Dispersión:", x, "vs", y), x = paste(x, "(%)"), y = paste(y, "(%)")) +
    g$theme_minimal(base_size = 12)
}

# Sankey: tópico (LDA) -> sentimiento dominante. m debe venir de mensajes_con_topico()
g_sankey <- function(m, titulo = "De qué se habla (tópico) y qué se siente (sentimiento dominante)") {
  g <- .gg(); .requiere("ggalluvial")
  d <- m[!is.na(m$topico) & m$sentimiento_dominante %in% nombres_sentimientos(m), , drop = FALSE]
  tab <- as.data.frame(table(topico = d$topico, sentimiento = d$sentimiento_dominante), stringsAsFactors = FALSE)
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  g$ggplot(tab, g$aes(axis1 = topico, axis2 = sentimiento, y = Freq)) +
    ggalluvial::geom_alluvium(g$aes(fill = topico)) + ggalluvial::geom_stratum(width = 1/8) +
    g$geom_text(stat = ggalluvial::StatStratum, g$aes(label = ggplot2::after_stat(stratum)), size = 3) +
    g$scale_x_discrete(limits = c("Tópico", "Sentimiento"), expand = c(0.1, 0.1)) +
    g$labs(title = titulo, y = "mensajes") + g$theme_minimal(base_size = 12) + g$theme(legend.position = "none")
}

# TF-IDF: términos más distintivos de cada documento (mes o periodo)
g_tfidf <- function(top, titulo = "Términos más distintivos (TF-IDF)") {
  g <- .gg()
  clave <- paste(top$doc, top$token, sep = "___")
  top$clave <- factor(clave, levels = rev(unique(clave)))
  g$ggplot(top, g$aes(x = tf_idf, y = clave)) + g$geom_col(fill = "#C55A11") +
    g$facet_wrap(~doc, scales = "free_y") + g$scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
    g$labs(title = titulo, x = "TF-IDF", y = NULL) + g$theme_minimal(base_size = 11)
}

# Tópicos: palabras más probables de cada tópico
g_topicos <- function(terminos, titulo = "Tópicos (LDA): palabras más probables") {
  g <- .gg()
  terminos$panel <- paste0(terminos$topico, ": ", terminos$etiqueta)
  clave <- paste(terminos$panel, terminos$termino, sep = "___")
  terminos$clave <- factor(clave, levels = rev(unique(clave)))
  g$ggplot(terminos, g$aes(x = beta, y = clave)) + g$geom_col(fill = "#548235") +
    g$facet_wrap(~panel, scales = "free_y") + g$scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
    g$labs(title = titulo, x = "probabilidad (beta)", y = NULL) + g$theme_minimal(base_size = 10)
}

g_topicos_tiempo <- function(peso_mes, titulo = "Peso de cada tópico por mes") {
  g <- .gg()
  peso_mes$mes <- as.Date(paste0(peso_mes$anio_mes, "-01"))
  peso_mes$panel <- paste0(peso_mes$topico, ": ", peso_mes$etiqueta)
  g$ggplot(peso_mes, g$aes(x = mes, y = peso_pct, color = panel, group = panel)) + g$geom_line() +
    g$labs(title = titulo, x = NULL, y = "% del mes", color = NULL) +
    g$theme_minimal(base_size = 11) + g$theme(legend.position = "bottom")
}

# Shallow linguistic: distribución de categorías gramaticales
g_upos <- function(upos, titulo = "Categorías gramaticales (shallow linguistic)") {
  g <- .gg()
  upos$clase <- factor(upos$clase, levels = rev(upos$clase))
  g$ggplot(upos, g$aes(x = clase, y = pct)) + g$geom_col(fill = "#7030A0") +
    g$geom_text(g$aes(label = .pct_lab(pct)), hjust = -0.1, size = 3) + g$coord_flip() +
    g$scale_y_continuous(expand = g$expansion(mult = c(0, 0.15))) +
    g$labs(title = titulo, x = NULL, y = "% de las palabras") + g$theme_minimal(base_size = 12)
}

# "Este mensaje es 8 % alegría; la temporada, 7 %" (df viene de nivel_mensaje())
g_nivel_mensaje <- function(df, titulo = "Nivel del mensaje frente a su periodo") {
  g <- .gg()
  largo <- rbind(data.frame(sentimiento = df$sentimiento, tipo = "mensaje", pct = df$mensaje_pct),
                 data.frame(sentimiento = df$sentimiento, tipo = "periodo", pct = df$periodo_pct))
  g$ggplot(largo, g$aes(x = sentimiento, y = pct, fill = tipo)) + g$geom_col(position = "dodge") + g$coord_flip() +
    g$labs(title = titulo, x = NULL, y = "%", fill = NULL) +
    g$theme_minimal(base_size = 12) + g$theme(legend.position = "bottom")
}

# Mapa de calor de actividad (día de la semana x hora)
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
