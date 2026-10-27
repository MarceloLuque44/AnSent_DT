# preprocesamiento.R — Logica de limpieza y transformacion del dataset
#
# Esta version es un wrapper ligero que delega en el pipeline real del proyecto
# (00_main.R -> preprocesar()) en lugar de reimplementar la limpieza. Mantiene
# la misma firma que esperaba Plumber: ejecutar_preprocesamiento(df).

ejecutar_preprocesamiento <- function(df) {
  filas_antes <- nrow(df)

  # Persistir el dataframe recibido como JSON de entrada para el pipeline del proyecto
  PROYECTO <- file.path("C:", "CODIGO", "AnSent", "r")
  entrada_path <- file.path(PROYECTO, "data", "plumber_entrada_df.json")
  jsonlite::write_json(df, entrada_path, auto_unbox = TRUE, pretty = FALSE)

  # Ejecutar el preprocesamiento real del proyecto (00_main.R)
  res <- tryCatch(
    preprocesar(
      entrada_path,
      dir_salida = file.path(PROYECTO, "salida"),
      dir_config = file.path(PROYECTO, "config"),
      dir_bitacoras = file.path(PROYECTO, "bitacoras"),
      consola = "silencioso",
      csv_para_excel = FALSE,
      preguntar_cambios = FALSE
    ),
    error = function(e) {
      message("Error en preprocesamiento: ", conditionMessage(e))
      list(estado = "error", mensaje = conditionMessage(e),
           resumen = list(filas_antes = filas_antes, filas_despues = 0,
                          filas_eliminadas = filas_antes))
    }
  )

  filas_despues <- if (!is.null(res$resumen)) res$resumen$mensajes_limpios else 0
  filas_afectadas <- filas_antes - filas_despues

  resumen <- list(
    filas_antes = filas_antes,
    filas_despues = filas_despues,
    filas_eliminadas = filas_afectadas,
    columnas = names(df),
    ts = format(Sys.time(), format = "%Y-%m-%d %H:%M:%S"),
    estado = res$estado %||% "ok"
  )

  list(
    dataset = df,
    descripcion = sprintf(
      "Preprocesamiento (pipeline del proyecto): %d filas eliminadas (duplicados/vacios). %d -> %d filas.",
      filas_afectadas, filas_antes, filas_despues
    ),
    filas_afectadas = filas_afectadas,
    resumen = resumen
  )
}
