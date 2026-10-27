# graficos.R — Genera la definicion JSON de graficos compatible con ECharts
# Cada grafico = list(titulo = "...", option = list(...)) que el frontend
# de React pasa directo a echarts.setOption().
#
# Esta version reusa los datos y resultados del proyecto en lugar de reimplementar
# logica propia.

generar_graficos <- function(df) {
  charts <- list()

  # 1) Distribucion de sentimientos (si existe la columna)
  if ("sentimiento" %in% names(df)) {
    conteo <- as.data.frame(table(df$sentimiento), stringsAsFactors = FALSE)
    names(conteo) <- c("clase", "total")
    charts[[length(charts) + 1]] <- list(
      titulo = "Distribución de sentimientos",
      option = list(
        xAxis = list(
          type = "category",
          data = conteo$clase
        ),
        yAxis = list(type = "value"),
        series = list(
          list(
            type = "bar",
            data = conteo$total
          )
        )
      )
    )
  }

  # 2) Proporciones (pie) del mismo campo, como demo
  if ("sentimiento" %in% names(df)) {
    conteo <- table(df$sentimiento)
    pie_data <- lapply(names(conteo), function(nm) {
      list(name = nm, value = unname(conteo[nm]))
    })
    charts[[length(charts) + 1]] <- list(
      titulo = "Proporción por clase",
      option = list(
        series = list(
          list(
            type = "pie",
            radius = "60%",
            data = pie_data
          )
        )
      )
    )
  }

  # 3) Si hay columna de polaridad del mensaje (del proyecto real), graficar barras
  if ("polaridad_msg" %in% names(df)) {
    conteo <- as.data.frame(table(df$polaridad_msg), stringsAsFactors = FALSE)
    names(conteo) <- c("clase", "total")
    charts[[length(charts) + 1]] <- list(
      titulo = "Polaridad de mensajes",
      option = list(
        xAxis = list(type = "category", data = conteo$clase),
        yAxis = list(type = "value"),
        series = list(list(type = "bar", data = conteo$total))
      )
    )
  }

  # PERSONALIZAR: agregar aqui los graficos reales del proyecto
  # (nube de palabras, serie temporal, sentimiento por fuente, etc.)

  charts
}
