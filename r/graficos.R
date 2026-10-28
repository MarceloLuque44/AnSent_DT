# graficos.R — Genera la definicion JSON de graficos compatible con ECharts
# Cada grafico = list(titulo = "...", option = list(...)) que el frontend
# de React pasa directo a echarts.setOption().
#
# Esta version usa los datos y resultados reales del proyecto (columnas del
# dataset limpio: sentimiento_dominante, polaridad_msg, pct_*, anio_mes,
# fecha, dia_semana, hora, topico, emojis_lista, reacciones_*, genero, etc.)
# en lugar de reimplementar logica propia.

# Operador coalescencia (fallback si rlang no está cargado)
`%||%` <- function(a, b) {
  if (!is.null(a) && length(a) > 0 && !all(is.na(a))) a else b
}

# Nombres de las columnas de nivel de sentimiento (pct_<nombre>) presentes en df
columnas_pct <- function(df) {
  grep("^pct_", names(df), value = TRUE)
}

nombres_sentimientos <- function(df) {
  sub("^pct_", "", columnas_pct(df))
}

# Helper: conteo de una columna categórica (data.frame con clase, total)
conteo_clase <- function(df, col) {
  if (!(col %in% names(df)) || !nrow(df))
    return(data.frame(clase = character(), total = integer(), stringsAsFactors = FALSE))
  t <- table(df[[col]], useNA = "ifany")
  data.frame(clase = names(t), total = as.integer(t), stringsAsFactors = FALSE)
}

# Helper: serie mensual de un sentimiento (promedio de pct_<s> por anio_mes)
serie_mensual_sentimiento <- function(df, sent) {
  col <- paste0("pct_", sent)
  if (!col %in% names(df) || !"anio_mes" %in% names(df) || !nrow(df))
    return(data.frame(anio_mes = character(), pct = numeric(), stringsAsFactors = FALSE))
  agg <- aggregate(df[[col]], by = list(anio_mes = df$anio_mes), FUN = mean, na.rm = TRUE)
  names(agg)[2] <- "pct"
  agg <- agg[order(agg$anio_mes), , drop = FALSE]
  agg
}

# Helper: top emojis usados (desde emojis_lista: "emoji1 emoji2 ...")
top_emojis <- function(df, n = 10) {
  if (!"emojis_lista" %in% names(df) || !nrow(df)) return(data.frame(emoji = character(), n = integer()))
  lst <- strsplit(df$emojis_lista[df$n_emojis > 0], " ", fixed = TRUE)
  if (!length(lst)) return(data.frame(emoji = character(), n = integer()))
  t <- sort(table(unlist(lst)), decreasing = TRUE)
  if (!length(t)) return(data.frame(emoji = character(), n = integer()))
  head <- utils::head(t, n)
  data.frame(emoji = names(head), n = as.integer(head), stringsAsFactors = FALSE)
}

generar_graficos <- function(df) {
  charts <- list()
  if (is.null(df) || !nrow(df)) return(charts)

  # ------------------------------------------------------------------
  # 1) Distribucion de sentimientos dominantes (barra)
  # ------------------------------------------------------------------
  if ("sentimiento_dominante" %in% names(df)) {
    c <- conteo_clase(df, "sentimiento_dominante")
    c <- c[c$clase != "NA" & nzchar(as.character(c$clase)), , drop = FALSE]
    if (nrow(c)) {
      charts[[length(charts) + 1]] <- list(
        titulo = "Distribución de sentimientos dominantes",
        option = list(
          title = list(text = "Distribución de sentimientos dominantes", left = "center"),
          tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
          xAxis = list(type = "category", data = c$clase, name = "Sentimiento"),
          yAxis = list(type = "value", name = "Mensajes"),
          series = list(list(type = "bar", data = c$total, itemStyle = list(color = "#2E75B6"))),
          grid = list(left = "10%", right = "10%", bottom = "15%")
        )
      )
    }
  }

  # ------------------------------------------------------------------
  # 2) Proporción por clase (pie) de sentimiento dominante
  # ------------------------------------------------------------------
  if ("sentimiento_dominante" %in% names(df)) {
    c <- conteo_clase(df, "sentimiento_dominante")
    c <- c[c$clase != "NA" & nzchar(as.character(c$clase)), , drop = FALSE]
    if (nrow(c)) {
      charts[[length(charts) + 1]] <- list(
        titulo = "Proporción por clase de sentimiento",
        option = list(
          title = list(text = "Proporción por clase de sentimiento", left = "center"),
          tooltip = list(trigger = "item"),
          legend = list(orient = "vertical", left = "left", top = "middle"),
          series = list(list(
            name = "Sentimiento",
            type = "pie",
            radius = "60%",
            data = lapply(seq_len(nrow(c)), function(i) list(value = c$total[i], name = c$clase[i])),
            emphasis = list(itemStyle = list(shadowBlur = 10, shadowOffsetX = 0, shadowColor = "rgba(0, 0, 0, 0.5)"))
          ))
        )
      )
    }
  }

  # ------------------------------------------------------------------
  # 3) Polaridad de mensajes (barra): positivo / negativo / neutral
  # ------------------------------------------------------------------
  if ("polaridad_msg" %in% names(df)) {
    c <- conteo_clase(df, "polaridad_msg")
    c <- c[c$clase != "NA" & nzchar(as.character(c$clase)), , drop = FALSE]
    if (nrow(c)) {
      cols <- setNames(c("#548235", "#C00000", "#BF8F00"), c("positivo", "negativo", "neutral"))
      charts[[length(charts) + 1]] <- list(
        titulo = "Polaridad de mensajes",
        option = list(
          title = list(text = "Polaridad de mensajes", left = "center"),
          tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
          xAxis = list(type = "category", data = c$clase, name = "Polaridad"),
          yAxis = list(type = "value", name = "Mensajes"),
          series = list(list(
            type = "bar",
            data = c$total,
            itemStyle = list(color = lapply(c$clase, function(x) cols[x] %||% "#2E75B6"))
          )),
          grid = list(left = "10%", right = "10%", bottom = "15%")
        )
      )
    }
  }

  # ------------------------------------------------------------------
  # 4) Nivel de cada sentimiento (pct_*) - barra horizontal con %
  # ------------------------------------------------------------------
  pct_cols <- columnas_pct(df)
  if (length(pct_cols)) {
    niv <- data.frame(
      sentimiento = nombres_sentimientos(df),
      nivel_pct = unname(vapply(pct_cols, function(c) mean(df[[c]], na.rm = TRUE), numeric(1))),
      stringsAsFactors = FALSE)
    niv <- niv[order(-niv$nivel_pct), , drop = FALSE]
    charts[[length(charts) + 1]] <- list(
      titulo = "Nivel promedio de cada sentimiento",
      option = list(
        title = list(text = "Nivel promedio de cada sentimiento", left = "center"),
        tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
        xAxis = list(type = "value", name = "% promedio por mensaje", max = 100),
        yAxis = list(type = "category", data = rev(niv$sentimiento), name = NULL),
        series = list(list(
          type = "bar",
          data = rev(niv$nivel_pct),
          itemStyle = list(color = "#2E75B6"),
          label = list(show = TRUE, position = "right", formatter = "{c}%")
        )),
        grid = list(left = "30%", right = "10%", bottom = "15%")
      )
    )
  }

  # ------------------------------------------------------------------
  # 5) Evolución mensual de sentimientos (serie temporal) - líneas
  # ------------------------------------------------------------------
  if ("anio_mes" %in% names(df) && length(pct_cols)) {
    nom <- nombres_sentimientos(df)
    series <- lapply(nom, function(s) {
      sm <- serie_mensual_sentimiento(df, s)
      list(name = s, type = "line", smooth = TRUE, showSymbol = FALSE,
           data = sm$pct)
    })
    meses <- unique(df$anio_mes)
    meses <- meses[order(meses)]
    charts[[length(charts) + 1]] <- list(
      titulo = "Evolución mensual de los sentimientos",
      option = list(
        title = list(text = "Evolución mensual de los sentimientos", left = "center"),
        tooltip = list(trigger = "axis"),
        legend = list(data = nom, orient = "horizontal", bottom = "left"),
        xAxis = list(type = "category", data = meses, name = "Mes"),
        yAxis = list(type = "value", name = "% promedio por mensaje", max = 100),
        series = series,
        grid = list(left = "8%", right = "8%", bottom = "20%", top = "15%")
      )
    )
  }

  # ------------------------------------------------------------------
  # 6) Composición apilada de sentimientos por mes (area apilada)
  # ------------------------------------------------------------------
  if ("anio_mes" %in% names(df) && length(pct_cols)) {
    nom <- nombres_sentimientos(df)
    meses <- unique(df$anio_mes)
    meses <- meses[order(meses)]
    stacked <- lapply(nom, function(s) {
      sm <- serie_mensual_sentimiento(df, s)
      # alinear a la lista completa de meses (rellenar faltantes con 0)
      m <- match(meses, sm$anio_mes)
      vals <- if (length(m)) sm$pct[m] else rep(0, length(meses))
      vals[is.na(vals)] <- 0
      vals
    })
    charts[[length(charts) + 1]] <- list(
      titulo = "Composición de sentimientos por mes",
      option = list(
        title = list(text = "Composición de sentimientos por mes", left = "center"),
        tooltip = list(trigger = "axis"),
        legend = list(data = nom, orient = "horizontal", bottom = "left"),
        xAxis = list(type = "category", data = meses, name = "Mes"),
        yAxis = list(type = "value", name = "% acumulado", max = 100),
        series = lapply(seq_along(nom), function(i) list(
          name = nom[i], type = "line", stack = "sentimientos", areaStyle = list(),
          emphasis = list(focus = "series"),
          data = stacked[[i]]
        )),
        grid = list(left = "8%", right = "8%", bottom = "20%", top = "15%")
      )
    )
  }

  # ------------------------------------------------------------------
  # 7) Topico dominante por mes (si existe topico) - líneas por topico
  # ------------------------------------------------------------------
  if ("topico" %in% names(df) && "anio_mes" %in% names(df) && nrow(df)) {
    d <- df[!is.na(df$topico) & nzchar(as.character(df$topico)), , drop = FALSE]
    if (nrow(d)) {
      topicos <- sort(unique(d$topico))
      meses <- unique(d$anio_mes); meses <- meses[order(meses)]
      series <- lapply(topicos, function(t) {
        sub <- d[d$topico == t, , drop = FALSE]
        tab <- table(sub$anio_mes)
        m <- match(meses, names(tab))
        vals <- as.integer(tab[m]); vals[is.na(vals)] <- 0
        list(name = t, type = "line", smooth = TRUE, showSymbol = FALSE, data = vals)
      })
      charts[[length(charts) + 1]] <- list(
        titulo = "Peso de cada tópico por mes",
        option = list(
          title = list(text = "Peso de cada tópico por mes", left = "center"),
          tooltip = list(trigger = "axis"),
          legend = list(data = topicos, orient = "horizontal", bottom = "left"),
          xAxis = list(type = "category", data = meses, name = "Mes"),
          yAxis = list(type = "value", name = "Cantidad de mensajes"),
          series = series,
          grid = list(left = "8%", right = "8%", bottom = "20%", top = "15%")
        )
      )
    }
  }

  # ------------------------------------------------------------------
  # 8) Actividad del grupo: día de la semana x hora (mapa de calor)
  # ------------------------------------------------------------------
  if (all(c("dia_semana", "hora") %in% names(df)) && nrow(df)) {
    orden <- c("domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado")
    d <- df[!is.na(df$dia_semana) & !is.na(df$hora), , drop = FALSE]
    if (nrow(d)) {
      tab <- as.data.frame(table(dia = d$dia_semana, hora = d$hora), stringsAsFactors = FALSE)
      tab$hora <- as.integer(as.character(tab$hora))
      presentes <- unique(tab$dia)
      niveles <- orden[orden %in% presentes]
      niveles <- unique(c(niveles, presentes[!(presentes %in% orden)]))
      tab$dia <- factor(tab$dia, levels = niveles)
      # datos para heatmap: [hora, dia_idx, valor]
      dias <- levels(tab$dia)
      data_heat <- do.call(rbind, lapply(split(tab, tab$dia), function(x) {
        di <- match(x$dia[1], dias)
        cbind(x$hora, di - 1, x$Freq)
      }))
      data_heat <- as.data.frame(data_heat)
      names(data_heat) <- c("hora", "dia", "valor")
      charts[[length(charts) + 1]] <- list(
        titulo = "Actividad del grupo: día x hora",
        option = list(
          title = list(text = "Actividad del grupo: día x hora", left = "center"),
          tooltip = list(trigger = "item"),
          xAxis = list(type = "category", data = 0:23, name = "Hora"),
          yAxis = list(type = "category", data = rev(dias), name = NULL),
          visualMap = list(
            min = 0, max = max(tab$Freq), calable = FALSE,
            orient = "horizontal", left = "center", bottom = "5%",
            inRange = list(color = c("#f7fbff", "#08306b"))
          ),
          series = list(list(
            name = "Mensajes",
            type = "heatmap",
            data = lapply(seq_len(nrow(data_heat)), function(i)
              list(data_heat$hora[i], data_heat$dia[i], as.integer(data_heat$valor[i]))),
            label = list(show = TRUE)
          )),
          grid = list(left = "10%", right = "10%", bottom = "25%", top = "15%")
        )
      )
    }
  }

  # ------------------------------------------------------------------
  # 9) Reacciones: positivas vs negativas (barra)
  # ------------------------------------------------------------------
  if (all(c("reacciones_pos", "reacciones_neg") %in% names(df)) && nrow(df)) {
    charts[[length(charts) + 1]] <- list(
      titulo = "Reacciones recibidas: positivas vs negativas",
      option = list(
        title = list(text = "Reacciones recibidas: positivas vs negativas", left = "center"),
        tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
        legend = list(data = c("Positivas", "Negativas"), top = "bottom"),
        xAxis = list(type = "category", data = c("Positivas", "Negativas")),
        yAxis = list(type = "value", name = "Cantidad de reacciones"),
        series = list(
          list(name = "Positivas", type = "bar", data = list(sum(df$reacciones_pos, na.rm = TRUE)),
               itemStyle = list(color = "#548235")),
          list(name = "Negativas", type = "bar", data = list(sum(df$reacciones_neg, na.rm = TRUE)),
               itemStyle = list(color = "#C00000"))
        ),
        grid = list(left = "10%", right = "10%", bottom = "20%", top = "15%")
      )
    )
  }

  # ------------------------------------------------------------------
  # 10) Top emojis más usados (barra)
  # ------------------------------------------------------------------
  em <- top_emojis(df, 10)
  if (nrow(em)) {
    charts[[length(charts) + 1]] <- list(
      titulo = "Emojis más usados",
      option = list(
        title = list(text = "Emojis más usados", left = "center"),
        tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
        xAxis = list(type = "category", data = em$emoji, name = "Emoji"),
        yAxis = list(type = "value", name = "Veces usado"),
        series = list(list(type = "bar", data = em$n, itemStyle = list(color = "#7030A0"))),
        grid = list(left = "8%", right = "8%", bottom = "15%", top = "15%")
      )
    )
  }

  charts
}
