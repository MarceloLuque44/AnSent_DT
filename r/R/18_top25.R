# ==============================================================================
# 18_top25.R - LAS 25 MEJORES GRAFICAS (autocontenido; no depende del archivo 17)
# ------------------------------------------------------------------------------
# USO (consola de RStudio):
#   setwd("C:/proyecto")
#   source("C:/proyecto/iniciar.R")
#   datos <- cargar_datos_analisis("salida")
#   a     <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))
#   source("R/18_top25.R")
#   ver_top25(datos, a)                 # dibuja las 25 en Plots y las guarda en salida/top25/
#   ver_top25(datos, a, solo = 1:6)     # solo algunas
#   ver_top25(datos, a, guardar = FALSE)
#
# GRUPOS:  1-9 actividad | 10-15 sentimientos por mensaje | 16-19 perfil del periodo (a$nivel)
#          20-22 serie mensual | 23-25 palabras y emojis
# ==============================================================================

suppressPackageStartupMessages(library(ggplot2))

.T_PAL <- c("#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51",
            "#8E5572", "#3A86FF", "#8338EC", "#FF006E", "#06D6A0")
.T_AZUL <- "#3A86FF"; .T_VERDE <- "#2A9D8F"; .T_ROJO <- "#E76F51"; .T_OSC <- "#1B263B"
.T_HEAT <- c("#F8F9FA", "#FFE8A3", "#F4A261", "#E76F51", "#6A040F")

.t_tm <- function(base = 12) {
  theme_minimal(base_size = base) +
    theme(plot.title = element_text(face = "bold", size = base + 4, color = .T_OSC),
          plot.subtitle = element_text(color = "grey40"),
          plot.title.position = "plot",
          panel.grid.minor = element_blank(),
          legend.position = "bottom",
          plot.margin = margin(12, 16, 12, 12))
}
.t_vacio <- function(base = 12) {
  theme_void(base_size = base) +
    theme(plot.title = element_text(face = "bold", size = base + 4, color = .T_OSC),
          plot.subtitle = element_text(color = "grey40"),
          legend.position = "right", plot.margin = margin(12, 16, 12, 12))
}
.t_pal <- function(n) rep(.T_PAL, length.out = n)

# ---- utilidades --------------------------------------------------------------
.t_col <- function(df, cands, req = TRUE) {
  h <- cands[cands %in% names(df)]
  if (length(h)) return(h[1])
  if (req) stop("No encuentro ninguna de estas columnas: ", paste(cands, collapse = ", "),
                ". Columnas disponibles: ", paste(names(df), collapse = ", "), call. = FALSE)
  NULL
}

.t_prep <- function(m) {
  if (".mes" %in% names(m)) return(m)
  cf <- .t_col(m, c("fecha_hora", "datetime", "timestamp", "fecha", "date"))
  f <- m[[cf]]
  if (inherits(f, "Date")) f <- as.POSIXct(f, tz = "UTC")
  else if (is.character(f))
    f <- as.POSIXct(f, tz = "UTC", tryFormats = c("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"))
  m$.f <- f
  m$.dia <- as.Date(f)
  m$.mes <- as.Date(format(f, "%Y-%m-01"))
  m$.hora <- if ("hora" %in% names(m)) suppressWarnings(as.integer(m$hora)) else as.integer(format(f, "%H"))
  m$.wd <- factor(as.integer(format(f, "%u")), levels = 1:7,
                  labels = c("Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"))
  m
}

.t_autor <- function(m) .t_col(m, c("autor_anon", "autor", "usuario", "from", "remitente", "nombre"))

.t_sent <- function(m) {
  s <- tryCatch(nombres_sentimientos(m), error = function(e) NULL)
  s <- s[s %in% names(m)]
  if (!length(s)) {
    norm <- function(x) {
      x <- tolower(x)
      if (requireNamespace("stringi", quietly = TRUE)) x <- stringi::stri_trans_general(x, "Latin-ASCII")
      x
    }
    dic <- c("ira", "anticipacion", "asco", "miedo", "alegria", "tristeza", "sorpresa", "confianza",
             "preocupacion", "negativo", "positivo", "anger", "anticipation", "disgust", "fear", "joy",
             "sadness", "surprise", "trust")
    num <- names(m)[vapply(m, is.numeric, logical(1))]
    s <- num[norm(sub("^(s_|sent_|sentimiento_|nivel_|pct_)", "", num)) %in% dic]
  }
  if (!length(s)) stop("No detecte columnas de sentimiento por mensaje. Ejecuta diagnostico_sentimientos(datos).", call. = FALSE)
  s
}

.t_con_sent <- function(datos) {
  m <- datos$mensajes
  if (length(tryCatch(.t_sent(m), error = function(e) NULL))) return(m)
  for (nm in names(datos)) {
    d <- datos[[nm]]
    if (is.data.frame(d) && nrow(d) == nrow(m) && length(tryCatch(.t_sent(d), error = function(e) NULL)))
      return(cbind(m, d[setdiff(names(d), names(m))]))
  }
  m
}

.t_largo <- function(m, s) {
  n <- nrow(m)
  d <- data.frame(mes = rep(m$.mes, length(s)), wd = rep(m$.wd, length(s)),
                  hora = rep(m$.hora, length(s)), sentimiento = rep(s, each = n),
                  valor = as.numeric(unlist(m[s], use.names = FALSE)))
  d[!is.na(d$valor), ]
}

.t_dom <- function(m, s) {
  x <- as.matrix(m[s]); x[is.na(x)] <- 0
  d <- s[max.col(x, ties.method = "first")]
  d[rowSums(x) == 0] <- NA
  d
}

.t_heat <- function(d, x, y, titulo, sub = NULL, xlab = NULL) {
  ggplot(d, aes(x = .data[[x]], y = .data[[y]], fill = valor)) +
    geom_tile(color = "white", linewidth = 0.4) +
    scale_fill_gradientn(colors = .T_HEAT, name = "promedio") +
    labs(title = titulo, subtitle = sub, x = xlab, y = NULL) + .t_tm() +
    theme(panel.grid = element_blank(), legend.key.width = unit(1.6, "cm"))
}

.t_emo_total <- function(e) {
  e <- as.data.frame(e)
  for (cn in c("en_texto", "en_reacciones")) if (!cn %in% names(e)) e[[cn]] <- 0
  e$en_texto <- as.numeric(e$en_texto); e$en_reacciones <- as.numeric(e$en_reacciones)
  e$total <- rowSums(e[c("en_texto", "en_reacciones")], na.rm = TRUE)
  if (!"sentimiento" %in% names(e)) e$sentimiento <- "neutral"
  e$sentimiento[is.na(e$sentimiento) | e$sentimiento == ""] <- "neutral"
  if (!"polaridad" %in% names(e)) e$polaridad <- 0
  e$polaridad <- suppressWarnings(as.numeric(e$polaridad)); e$polaridad[is.na(e$polaridad)] <- 0
  e
}
.t_emo_lab <- function(e) {
  sig <- if ("significado_es" %in% names(e)) as.character(e$significado_es) else rep(NA_character_, nrow(e))
  ifelse(is.na(sig) | sig == "", as.character(e$emoji), sig)
}

# ==============================================================================
# A. ACTIVIDAD (1-9)  -> reciben m
# ==============================================================================
t01_volumen_mes <- function(m) {
  m <- .t_prep(m); d <- as.data.frame(table(mes = m$.mes), stringsAsFactors = FALSE)
  d$mes <- as.Date(d$mes)
  ggplot(d, aes(mes, Freq)) +
    geom_area(fill = .T_AZUL, alpha = 0.18) + geom_line(color = .T_AZUL, linewidth = 1.2) +
    geom_point(color = .T_AZUL, size = 2.5) +
    geom_smooth(se = FALSE, color = .T_ROJO, linewidth = 0.8, linetype = "dashed", formula = y ~ x, method = "loess") +
    labs(title = "Volumen de mensajes por mes", subtitle = "Linea punteada: tendencia suavizada", x = NULL, y = "mensajes") + .t_tm()
}

t02_reloj <- function(m) {
  m <- .t_prep(m); d <- as.data.frame(table(hora = factor(m$.hora, levels = 0:23)))
  ggplot(d, aes(hora, Freq, fill = Freq)) + geom_col(width = 0.95, color = "white") +
    coord_polar(start = -pi / 24) +
    scale_fill_gradientn(colors = c("#CDE7F0", .T_AZUL, "#8338EC", "#FF006E"), guide = "none") +
    labs(title = "El reloj del grupo", subtitle = "A que hora se escribe mas (0 a 23 h)", x = NULL, y = NULL) +
    .t_tm() + theme(axis.text.y = element_blank())
}

t03_punchcard <- function(m) {
  m <- .t_prep(m)
  d <- as.data.frame(table(wd = m$.wd, hora = m$.hora)); d$hora <- as.integer(as.character(d$hora))
  d$wd <- factor(d$wd, levels = rev(levels(m$.wd)))
  ggplot(d, aes(hora, wd)) + geom_point(aes(size = Freq, color = Freq), alpha = 0.9) +
    scale_size_area(max_size = 14, guide = "none") +
    scale_color_gradientn(colors = c("#4CC9F0", "#7209B7", "#F72585"), name = "mensajes") +
    scale_x_continuous(breaks = seq(0, 23, 3)) +
    labs(title = "Punchcard de actividad", subtitle = "Tamano de la burbuja = cantidad de mensajes", x = "hora", y = NULL) +
    .t_tm() + theme(legend.key.width = unit(1.6, "cm"))
}

t04_polar_heat <- function(m) {
  m <- .t_prep(m)
  d <- as.data.frame(table(wd = m$.wd, hora = factor(m$.hora, levels = 0:23)))
  d$hora <- as.integer(as.character(d$hora))
  ggplot(d, aes(hora, wd, fill = Freq)) + geom_tile(color = "white", linewidth = 0.4) +
    coord_polar(start = -pi / 24) +
    scale_x_continuous(breaks = 0:23, limits = c(-0.5, 23.5)) +
    scale_y_discrete(expand = expansion(add = c(2, 0.2))) +
    scale_fill_gradientn(colors = c("#F8F9FA", "#9BD3C7", "#F4A261", "#E76F51", "#6A040F"), name = "mensajes") +
    labs(title = "El pulso del grupo", subtitle = "Anillos = dias de la semana (Lun al centro) | angulo = hora", x = NULL, y = NULL) +
    .t_tm(11) + theme(panel.grid = element_blank(), legend.key.width = unit(1.6, "cm"))
}

t05_calendario <- function(m) {
  m <- .t_prep(m); d <- as.data.frame(table(dia = m$.dia), stringsAsFactors = FALSE); d$dia <- as.Date(d$dia)
  d$semana <- d$dia - (as.integer(format(d$dia, "%u")) - 1)
  d$anio <- format(d$dia, "%Y")
  d$wd <- factor(as.integer(format(d$dia, "%u")), levels = 7:1,
                 labels = c("Dom", "Sab", "Vie", "Jue", "Mie", "Mar", "Lun"))
  ggplot(d, aes(semana, wd, fill = Freq)) + geom_tile(color = "white", linewidth = 0.5) +
    facet_wrap(~anio, ncol = 1, scales = "free_x") +
    scale_fill_gradientn(colors = c("#EAF4F4", "#9BD3C7", .T_VERDE, "#0B5345"), name = "mensajes") +
    labs(title = "Calendario de actividad", subtitle = "Cada cuadro es un dia", x = NULL, y = NULL) +
    .t_tm(11) + theme(panel.grid = element_blank(), legend.key.width = unit(1.6, "cm"))
}

t06_autores <- function(m, n = 15) {
  m <- .t_prep(m); t <- head(sort(table(m[[.t_autor(m)]]), decreasing = TRUE), n)
  d <- data.frame(autor = factor(names(t), levels = rev(names(t))), n = as.integer(t))
  ggplot(d, aes(autor, n)) + geom_segment(aes(xend = autor, yend = 0), color = "grey75", linewidth = 1) +
    geom_point(color = .T_ROJO, size = 5) + geom_text(aes(label = n), hjust = -0.8, size = 3.3) + coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(title = paste("Los", n, "participantes mas activos"), x = NULL, y = "mensajes") + .t_tm()
}

t07_pareto <- function(m) {
  m <- .t_prep(m); a <- sort(table(m[[.t_autor(m)]]), decreasing = TRUE)
  d <- data.frame(rank = seq_along(a), acum = cumsum(as.numeric(a)) / sum(a) * 100)
  ggplot(d, aes(rank, acum)) + geom_area(fill = .T_VERDE, alpha = 0.2) + geom_line(color = .T_VERDE, linewidth = 1.3) +
    geom_hline(yintercept = 80, linetype = "dashed", color = .T_ROJO) +
    annotate("text", x = max(d$rank) * 0.6, y = 84, label = "80 % de los mensajes", color = .T_ROJO) +
    labs(title = "Concentracion de la conversacion",
         subtitle = "Cuantos participantes escriben la mayor parte de los mensajes",
         x = "participantes (de mas a menos activo)", y = "% acumulado de mensajes") + .t_tm()
}

t08_bump <- function(m, n = 8) {
  m <- .t_prep(m); a <- .t_autor(m)
  top <- names(head(sort(table(m[[a]]), decreasing = TRUE), n)); mm <- m[m[[a]] %in% top, ]
  d <- as.data.frame(table(mes = as.character(mm$.mes), autor = as.character(mm[[a]])), stringsAsFactors = FALSE)
  d$mes <- as.Date(d$mes); d$rank <- ave(-d$Freq, d$mes, FUN = function(x) rank(x, ties.method = "first"))
  ini <- d[d$mes == min(d$mes), ]; fin <- d[d$mes == max(d$mes), ]
  ggplot(d, aes(mes, rank, color = autor, group = autor)) +
    geom_line(linewidth = 1.8, alpha = 0.85) + geom_point(size = 4.5) +
    geom_text(data = ini, aes(label = autor), hjust = 1.2, size = 3.2, show.legend = FALSE) +
    geom_text(data = fin, aes(label = autor), hjust = -0.2, size = 3.2, show.legend = FALSE) +
    scale_y_reverse(breaks = 1:n) + scale_x_date(expand = expansion(mult = 0.22)) +
    scale_color_manual(values = .t_pal(n), guide = "none") +
    labs(title = "La carrera de los participantes",
         subtitle = paste("Ranking mensual de los", n, "mas activos (1 = el que mas escribe)"), x = NULL, y = "puesto") +
    .t_tm() + theme(panel.grid.minor = element_blank())
}

t09_ridgeline <- function(m, n = 8) {
  m <- .t_prep(m); a <- .t_autor(m)
  top <- names(head(sort(table(m[[a]]), decreasing = TRUE), n))
  filas <- lapply(top, function(p) {
    idx <- which(m[[a]] == p)
    h <- tabulate(m$.hora[idx] + 1, nbins = 24); v <- h / max(h, 1)
    s <- spline(0:23, v, n = 200, method = "natural")
    data.frame(autor = p, x = s$x, v = pmax(s$y, 0), mediana = median(m$.hora[idx], na.rm = TRUE))
  })
  d <- do.call(rbind, filas)
  orden <- unique(d[order(d$mediana), c("autor", "mediana")])$autor
  d$pos <- match(d$autor, orden); d$ymin <- d$pos; d$ymax <- d$pos + d$v * 1.8
  ggplot(d, aes(x, ymin = ymin, ymax = ymax, fill = autor)) +
    geom_ribbon(color = "white", linewidth = 0.4, alpha = 0.9) +
    scale_y_continuous(breaks = seq_along(orden), labels = orden) +
    scale_x_continuous(breaks = seq(0, 23, 3)) +
    scale_fill_manual(values = .t_pal(length(orden)), guide = "none") +
    labs(title = "Quien madruga y quien es noctambulo?",
         subtitle = "Hora habitual de cada participante (de mas madrugador a mas nocturno)",
         x = "hora del dia", y = NULL) + .t_tm()
}

# ==============================================================================
# B. SENTIMIENTOS POR MENSAJE (10-15) -> reciben m con columnas de sentimiento
# ==============================================================================
t10_sent_mes_heat <- function(m) {
  m <- .t_prep(m); L <- .t_largo(m, .t_sent(m)); d <- aggregate(valor ~ mes + sentimiento, L, mean)
  d$mes <- factor(format(d$mes, "%Y-%m"))
  .t_heat(d, "mes", "sentimiento", "Mapa de calor: sentimiento x mes", "Cuanto mas rojo, mas presente") +
    theme(axis.text.x = element_text(angle = 60, hjust = 1))
}

t11_sent_hora_heat <- function(m) {
  m <- .t_prep(m); L <- .t_largo(m, .t_sent(m)); d <- aggregate(valor ~ hora + sentimiento, L, mean)
  d$hora <- factor(d$hora, levels = 0:23)
  .t_heat(d, "hora", "sentimiento", "Como cambia el animo durante el dia?", "Sentimiento promedio por hora", "hora")
}

t12_dominante_mes <- function(m) {
  m <- .t_prep(m); s <- .t_sent(m); d <- data.frame(mes = m$.mes, dom = .t_dom(m, s)); d <- d[!is.na(d$dom), ]
  ggplot(d, aes(mes, fill = dom)) + geom_bar(position = "fill", width = 25) +
    scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    scale_fill_manual(values = .t_pal(length(unique(d$dom))), name = NULL) +
    labs(title = "Que emocion domina cada mes", subtitle = "Barras al 100 %", x = NULL, y = NULL) + .t_tm()
}

t13_correlacion <- function(m) {
  m <- .t_prep(m); s <- .t_sent(m); x <- m[s]
  x <- x[, sapply(x, function(z) sd(z, na.rm = TRUE) > 0), drop = FALSE]
  cm <- cor(x, use = "pairwise.complete.obs"); d <- as.data.frame(as.table(cm)); names(d) <- c("a", "b", "r")
  ggplot(d, aes(a, b, fill = r)) + geom_tile(color = "white") + geom_text(aes(label = sprintf("%.2f", r)), size = 3) +
    scale_fill_gradient2(low = "#3A86FF", mid = "white", high = .T_ROJO, limits = c(-1, 1), name = "correlacion") +
    labs(title = "Que sentimientos aparecen juntos?", subtitle = "Correlacion entre sentimientos por mensaje", x = NULL, y = NULL) +
    .t_tm() + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
}

t14_autor_sent <- function(m, n = 12) {
  m <- .t_prep(m); s <- .t_sent(m); a <- .t_autor(m)
  top <- names(head(sort(table(m[[a]]), decreasing = TRUE), n)); mm <- m[m[[a]] %in% top, ]
  L <- data.frame(autor = rep(as.character(mm[[a]]), length(s)), sentimiento = rep(s, each = nrow(mm)),
                  valor = as.numeric(unlist(mm[s], use.names = FALSE)))
  L <- L[!is.na(L$valor), ]
  d <- aggregate(valor ~ autor + sentimiento, L, mean)
  .t_heat(d, "sentimiento", "autor", paste("Perfil emocional de los", n, "mas activos"), "Sentimiento promedio por persona") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

t15_media_movil <- function(m, k = 30, top = 4) {
  m <- .t_prep(m); s <- .t_sent(m)
  med <- sapply(s, function(z) mean(m[[z]], na.rm = TRUE)); s <- names(sort(med, decreasing = TRUE))[seq_len(min(top, length(s)))]
  dias <- seq(min(m$.dia, na.rm = TRUE), max(m$.dia, na.rm = TRUE), by = "day")
  out <- do.call(rbind, lapply(s, function(z) {
    v <- tapply(m[[z]], factor(m$.dia, levels = as.character(dias)), mean, na.rm = TRUE); v[is.nan(v)] <- NA
    v <- as.numeric(v); mm <- stats::filter(ifelse(is.na(v), 0, v), rep(1 / k, k), sides = 1)
    data.frame(dia = dias, sentimiento = z, v = as.numeric(mm))
  }))
  ggplot(out, aes(dia, v, color = sentimiento)) + geom_line(linewidth = 1.1, na.rm = TRUE) +
    scale_color_manual(values = .t_pal(length(s)), name = NULL) +
    labs(title = paste0("Tendencia emocional (media movil de ", k, " dias)"),
         subtitle = paste("Los", top, "sentimientos mas presentes"), x = NULL, y = "intensidad") + .t_tm()
}

# ==============================================================================
# C. PERFIL DEL PERIODO (16-19) -> reciben a$nivel (sentimiento, nivel_pct)
# ==============================================================================
t16_nivel_lollipop <- function(niv, titulo = "Perfil emocional del periodo") {
  niv <- niv[order(niv$nivel_pct), ]; niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  ggplot(niv, aes(sentimiento, nivel_pct, color = sentimiento)) +
    geom_segment(aes(xend = sentimiento, yend = 0), linewidth = 1.6) + geom_point(size = 9) +
    geom_text(aes(label = paste0(round(nivel_pct, 1), "%")), color = "white", size = 2.8, fontface = "bold") +
    coord_flip() + scale_color_manual(values = .t_pal(nrow(niv)), guide = "none") +
    labs(title = titulo, subtitle = "% promedio por mensaje", x = NULL, y = NULL) + .t_tm()
}

t17_nivel_rosa <- function(niv, titulo = "Rosa de los sentimientos") {
  niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  ggplot(niv, aes(sentimiento, nivel_pct, fill = nivel_pct)) + geom_col(width = 0.9, color = "white") +
    geom_text(aes(label = paste0(round(nivel_pct, 1), "%")), vjust = -0.4, size = 3.2, color = .T_OSC) +
    coord_polar() + scale_fill_gradientn(colors = c("#CDE7F0", .T_AZUL, "#8338EC", "#FF006E"), guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(title = titulo, x = NULL, y = NULL) + .t_tm() + theme(axis.text.y = element_blank())
}

t18_nivel_ranking <- function(niv, titulo = "Ranking de sentimientos") {
  niv <- niv[order(niv$nivel_pct), ]; niv$sentimiento <- factor(niv$sentimiento, levels = niv$sentimiento)
  ggplot(niv, aes(sentimiento, nivel_pct, fill = nivel_pct)) + geom_col(width = 0.75) +
    geom_text(aes(label = paste0(round(nivel_pct, 1), "%")), hjust = -0.15, fontface = "bold", size = 3.4) + coord_flip() +
    scale_fill_gradientn(colors = c("#FFE8A3", "#F4A261", "#E76F51", "#6A040F"), guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(title = titulo, x = NULL, y = "% promedio por mensaje") + .t_tm()
}

t19_waffle <- function(niv, titulo = "100 mensajes, que sienten?") {
  niv <- niv[order(-niv$nivel_pct), ]; p <- niv$nivel_pct / sum(niv$nivel_pct) * 100
  fl <- floor(p); resto <- 100 - sum(fl)
  if (resto > 0) { idx <- order(-(p - fl))[seq_len(resto)]; fl[idx] <- fl[idx] + 1 }
  cat <- rep(niv$sentimiento, fl)
  d <- data.frame(i = seq_along(cat), s = factor(cat, levels = niv$sentimiento))
  d$x <- (d$i - 1) %% 10; d$y <- 9 - (d$i - 1) %/% 10
  ggplot(d, aes(x, y, fill = s)) + geom_tile(width = 0.92, height = 0.92) + coord_equal() +
    scale_fill_manual(values = .t_pal(nrow(niv)), name = NULL,
                      labels = paste0(niv$sentimiento, " (", fl, ")"), drop = FALSE) +
    labs(title = titulo, subtitle = "Cada cuadro = 1 % de la carga emocional") + .t_vacio()
}

# ==============================================================================
# D. SERIE MENSUAL (20-22) -> reciben serie (anio_mes, pct, sentimiento)
# ==============================================================================
t20_serie_facetas <- function(serie) {
  serie$mes <- as.Date(paste0(serie$anio_mes, "-01")); k <- length(unique(serie$sentimiento))
  ggplot(serie, aes(mes, pct, fill = sentimiento, color = sentimiento)) +
    geom_area(alpha = 0.25) + geom_line(linewidth = 1) + facet_wrap(~sentimiento, scales = "free_y") +
    scale_fill_manual(values = .t_pal(k)) + scale_color_manual(values = .t_pal(k)) +
    labs(title = "Cada sentimiento a lo largo del tiempo", x = NULL, y = "% promedio") +
    .t_tm(11) + theme(legend.position = "none", strip.text = element_text(face = "bold"))
}

t21_serie_heat <- function(serie) {
  serie$mes <- factor(serie$anio_mes)
  ggplot(serie, aes(mes, sentimiento, fill = pct)) + geom_tile(color = "white", linewidth = 0.4) +
    scale_fill_gradientn(colors = .T_HEAT, name = "%") +
    labs(title = "Mapa de calor emocional mes a mes", subtitle = "Cuanto mas rojo, mas presente", x = NULL, y = NULL) +
    .t_tm() + theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 60, hjust = 1),
                    legend.key.width = unit(1.6, "cm"))
}

t22_serie_stream <- function(serie) {
  serie$mes <- as.Date(paste0(serie$anio_mes, "-01"))
  ggplot(serie, aes(mes, pct, fill = sentimiento)) +
    geom_area(position = "fill", alpha = 0.9, color = "white", linewidth = 0.2) +
    scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    scale_fill_manual(values = .t_pal(length(unique(serie$sentimiento))), name = NULL) +
    labs(title = "Composicion emocional mes a mes", subtitle = "Proporcion de cada sentimiento sobre el total del mes",
         x = NULL, y = NULL) + .t_tm()
}

# ==============================================================================
# E. PALABRAS Y EMOJIS (23-25) -> tokens (datos$tokens) y emojis_en_uso.csv
# ==============================================================================
t23_palabras <- function(tokens, n = 25) {
  cw <- .t_col(tokens, c("token", "palabra", "lemma", "termino", "term"))
  cn <- .t_col(tokens, c("n", "freq", "frecuencia", "conteo"), FALSE)
  t <- if (is.null(cn)) table(tokens[[cw]]) else tapply(tokens[[cn]], tokens[[cw]], sum)
  t <- head(sort(t, decreasing = TRUE), n)
  d <- data.frame(p = factor(names(t), levels = rev(names(t))), n = as.numeric(t))
  ggplot(d, aes(p, n, fill = n)) + geom_col(width = 0.75) + coord_flip() +
    scale_fill_gradient(low = "#9BC5FF", high = "#8338EC", guide = "none") +
    labs(title = paste("Las", n, "palabras mas usadas"), x = NULL, y = "veces") + .t_tm()
}

t24_emojis <- function(emojis, n = 20) {
  e <- .t_emo_total(emojis); d <- e[order(-e$total), ][seq_len(min(n, nrow(e))), ]
  d$lab <- make.unique(.t_emo_lab(d)); d$lab <- factor(d$lab, levels = rev(d$lab))
  ggplot(d, aes(lab, total, fill = sentimiento)) + geom_col(width = 0.75) + coord_flip() +
    scale_fill_manual(values = .t_pal(length(unique(d$sentimiento))), name = "sentimiento") +
    labs(title = "Emojis mas usados y su sentimiento", x = NULL, y = "veces (texto + reacciones)") + .t_tm()
}

t25_sunburst_emojis <- function(emojis, n = 18) {
  e <- .t_emo_total(emojis)
  e$pol <- ifelse(e$polaridad > 0, "Positivo", ifelse(e$polaridad < 0, "Negativo", "Neutro"))
  e <- e[order(-e$total), ][seq_len(min(n, nrow(e))), ]
  e$pol <- factor(e$pol, levels = c("Positivo", "Neutro", "Negativo"))
  e <- e[order(e$pol, -e$total), ]
  e$lab <- substr(.t_emo_lab(e), 1, 12)
  r1 <- aggregate(total ~ pol, e, sum); r1 <- r1[order(r1$pol), ]
  cols <- c(Positivo = "#06D6A0", Neutro = "#FFBA08", Negativo = "#F72585")
  ggplot() +
    geom_col(data = r1, aes(x = 1, y = total, fill = pol), width = 1, color = "white") +
    geom_text(data = r1, aes(x = 1, y = total, label = pol), position = position_stack(vjust = 0.5),
              color = .T_OSC, fontface = "bold", size = 3.4) +
    geom_col(data = e, aes(x = 2, y = total, fill = pol), width = 1, color = "white", alpha = 0.75) +
    geom_text(data = e, aes(x = 2, y = total, label = lab), position = position_stack(vjust = 0.5),
              color = .T_OSC, size = 2.4) +
    coord_polar("y") + xlim(0, 2.5) + scale_fill_manual(values = cols, guide = "none") +
    labs(title = "Emojis: de la polaridad al detalle",
         subtitle = paste("Anillo interior = polaridad | exterior = los", n, "emojis mas usados")) + .t_vacio()
}

# ==============================================================================
# EJECUTOR: dibuja las 25, avisa cual falla y guarda PNG en salida/top25/
# ==============================================================================
ver_top25 <- function(datos, a, serie = NULL, emojis = NULL, guardar = TRUE, pausa = 0, solo = NULL) {
  m0 <- datos$mensajes
  ms <- tryCatch(.t_con_sent(datos), error = function(e) m0)
  m  <- .t_prep(ms)
  niv <- a$nivel
  tokens <- datos$tokens
  if (is.null(emojis)) {
    f <- "salida/emojis_en_uso.csv"
    emojis <- if (file.exists(f)) tryCatch(readr::read_csv(f, show_col_types = FALSE), error = function(e) NULL) else NULL
  }
  if (is.null(serie)) serie <- tryCatch(serie_sentimientos(ms), error = function(e) NULL)
  if (is.null(serie)) serie <- tryCatch(a$serie, error = function(e) NULL)
  
  falta <- function(x, nombre) function() stop("No hay ", nombre, " disponible.", call. = FALSE)
  req <- function(x, nombre, f) if (is.null(x)) falta(x, nombre) else function() f(x)
  
  lista <- list(
    "01_volumen_mes"     = function() t01_volumen_mes(m),
    "02_reloj"           = function() t02_reloj(m),
    "03_punchcard"       = function() t03_punchcard(m),
    "04_polar_heat"      = function() t04_polar_heat(m),
    "05_calendario"      = function() t05_calendario(m),
    "06_autores"         = function() t06_autores(m),
    "07_pareto"          = function() t07_pareto(m),
    "08_bump"            = function() t08_bump(m),
    "09_ridgeline"       = function() t09_ridgeline(m),
    "10_sent_mes_heat"   = function() t10_sent_mes_heat(m),
    "11_sent_hora_heat"  = function() t11_sent_hora_heat(m),
    "12_dominante_mes"   = function() t12_dominante_mes(m),
    "13_correlacion"     = function() t13_correlacion(m),
    "14_autor_sent"      = function() t14_autor_sent(m),
    "15_media_movil"     = function() t15_media_movil(m),
    "16_nivel_lollipop"  = req(niv, "a$nivel", t16_nivel_lollipop),
    "17_nivel_rosa"      = req(niv, "a$nivel", t17_nivel_rosa),
    "18_nivel_ranking"   = req(niv, "a$nivel", t18_nivel_ranking),
    "19_waffle"          = req(niv, "a$nivel", t19_waffle),
    "20_serie_facetas"   = req(serie, "la serie mensual", t20_serie_facetas),
    "21_serie_heat"      = req(serie, "la serie mensual", t21_serie_heat),
    "22_serie_stream"    = req(serie, "la serie mensual", t22_serie_stream),
    "23_palabras"        = req(tokens, "datos$tokens", t23_palabras),
    "24_emojis"          = req(emojis, "salida/emojis_en_uso.csv", t24_emojis),
    "25_sunburst_emojis" = req(emojis, "salida/emojis_en_uso.csv", t25_sunburst_emojis)
  )
  if (!is.null(solo)) lista <- lista[solo]
  if (guardar) dir.create("salida/top25", showWarnings = FALSE, recursive = TRUE)
  
  ok <- 0; malas <- character()
  for (nm in names(lista)) {
    g <- tryCatch(lista[[nm]](), error = function(e) {
      cat(sprintf("%-20s FALLA: %s\n", nm, conditionMessage(e))); NULL })
    if (is.null(g)) { malas <- c(malas, nm); next }
    r <- tryCatch({ print(g); TRUE }, error = function(e) {
      cat(sprintf("%-20s FALLA al dibujar: %s\n", nm, conditionMessage(e))); FALSE })
    if (!r) { malas <- c(malas, nm); next }
    ok <- ok + 1; cat(sprintf("%-20s OK\n", nm))
    if (guardar) tryCatch(ggsave(file.path("salida/top25", paste0(nm, ".png")), g,
                                 width = 11, height = 7, dpi = 150, bg = "white"),
                          error = function(e) cat("   (no se pudo guardar el PNG)\n"))
    if (pausa > 0) Sys.sleep(pausa)
  }
  cat("\nListos:", ok, "de", length(lista), "\n")
  if (length(malas)) cat("Fallaron:", paste(malas, collapse = ", "), "\n")
  invisible(NULL)
}