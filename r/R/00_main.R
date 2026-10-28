# ==============================================================================
# 00_main.R  -  preprocesar(): UNA función que ejecuta todo el preprocesamiento
# ------------------------------------------------------------------------------
#   source("cargar_proyecto.R")                      # carga las herramientas (una vez)
#   res <- preprocesar("data/result.json")           # <- AQUÍ se indica el archivo de entrada
#
# Entrada : result.json de Telegram (o un CSV equivalente)
# Salida  : carpeta `dir_salida` (por defecto salida/) con
#             mensajes_limpios.csv      dataset listo para graficar (1 fila = 1 mensaje, sin vacíos)
#             mensajes_excluidos.csv    todo lo que se quitó y por qué (nada se pierde)
#             tokens.csv                1 fila = 1 palabra (TF-IDF, n-gramas, LDA)
#             stopwords_aplicadas.csv   qué palabra vacía se eliminó/conservó y por qué
#             emojis_en_uso.csv / emojis_pendientes.csv
#             resumen.json              conteos clave de la ejecución
#         y la carpeta `dir_bitacoras` (por defecto bitacoras/) con SOLO DOS archivos:
#             bitacora_limpia.xlsx     pasos de la última ejecución exitosa
#             bitacora_completa.xlsx   cambios (código y diccionarios), ejecuciones, pasos y experimentos
#
# consola: "didactico" explica cada paso mientras trabaja | "resumen" una línea por paso | "silencioso"
# ==============================================================================

preprocesar <- function(ruta_archivo,
                        fecha_inicio = NULL, fecha_fin = NULL,
                        responsable = Sys.getenv("RESPONSABLE", ""),
                        dir_config = "config", dir_salida = file.path("client", "src", "views", "salida"),
                        dir_bitacoras = "bitacoras",
                        sentimientos_activos = NULL,
                        excluir_publicidad = TRUE, umbral_publicidad = 4,
                        anonimizar_autor = TRUE, min_chars_duplicado = 25,
                        nuevos_emojis = c("marcar", "detener"),
                        consola = c("didactico", "resumen", "silencioso"),
                        csv_para_excel = TRUE,
                        preguntar_cambios = interactive(), motivo_cambios = NULL,
                        chat = NULL) {
  nuevos_emojis <- match.arg(nuevos_emojis)
  consola <- match.arg(consola)
  dir.create(dir_salida, recursive = TRUE, showWarnings = FALSE)
  old <- options(sentimientos.bom = csv_para_excel)   # BOM = Excel abre bien tildes y emojis
  on.exit(options(old), add = TRUE)
  t_ini <- Sys.time()
  md5_entrada <- tryCatch(digest::digest(file = ruta_archivo, algo = "md5"), error = function(e) "")

  # Cambios hechos al código o a los diccionarios desde la última vez: se detectan solos y se anotan
  # en bitacoras/bitacora_completa.xlsx (hoja "Cambios"), pidiendo la justificación.
  try(vigilar_cambios(dir_bitacoras, dir_config, responsable, preguntar_cambios, motivo_cambios), silent = FALSE)

  prog <- new.env()                      # seguimiento: en qué paso estamos
  prog$paso <- "inicio"; prog$ctx <- NULL
  etapa <- function(titulo) {
    prog$paso <- titulo
    if (consola == "didactico") cat("\n", strrep("=", 98), "\n  ", titulo, "\n", strrep("=", 98), "\n", sep = "")
    else if (consola == "resumen") message(format(Sys.time(), "%H:%M:%S"), "  ", titulo)
  }

  # C02: los parámetros vacíos se dejan como NULL (antes se volvían texto y rompían as.Date)
  params <- list(ruta_archivo = ruta_archivo, archivo_md5 = md5_entrada,
                 fecha_inicio = fecha_inicio, fecha_fin = fecha_fin,
                 responsable = responsable, dir_config = dir_config, dir_salida = dir_salida,
                 dir_bitacoras = dir_bitacoras,
                 sentimientos_activos = sentimientos_activos %||% "(todos los activos del json)",
                 excluir_publicidad = excluir_publicidad, umbral_publicidad = umbral_publicidad,
                 anonimizar_autor = anonimizar_autor, min_chars_duplicado = min_chars_duplicado,
                 nuevos_emojis = nuevos_emojis, consola = consola, csv_para_excel = csv_para_excel)

  cuerpo <- function() {
    etapa("Cargando diccionarios (config/)")
    cfg <- cargar_config(dir_config, sentimientos_activos)
    ctx <- nuevo_ctx(params, cfg)
    ctx$emojis_pendientes <- NULL
    prog$ctx <- ctx

    etapa(paste0("Leyendo ", basename(ruta_archivo)))
    d <- leer_entrada(ruta_archivo, chat)
    ctx$N_inicial <- nrow(d)

    etapa(paste0("ETAPA 1. Auditoría y perfilado inicial (", format(nrow(d), big.mark = ","), " registros)"))
    d <- auditar_entrada(ctx, d)
    etapa("ETAPA 2. Normalización de estructura y formatos")
    d <- estructurar(ctx, d)
    etapa("ETAPAS 3-5. Duplicados, valores faltantes y outliers")
    d <- control_calidad(ctx, d)
    etapa("ETAPA 6. Publicidad y anuncios")
    d <- detectar_publicidad(ctx, d)
    etapa("ETAPA 7. Emojis")
    d <- procesar_emojis(ctx, d)

    if (isTRUE(ctx$detenido)) {
      pend <- ctx$emojis_pendientes
      escribir_csv(pend, file.path(dir_salida, "emojis_pendientes.csv"))
      # C06: la bitácora limpia NO se pisa con una ejecución incompleta (los pasos que alcanzaron
      #      a correr quedan en bitacora_completa.xlsx, hoja "Pasos por ejecucion")
      if (consola != "silencioso")
        message("DETENIDO: hay ", nrow(pend), " emojis nuevos por traducir (salida/emojis_pendientes.csv). ",
                "Tradúcelos con actualizar_emoji() o desde el dashboard y vuelve a ejecutar.")
      return(list(estado = "emojis_pendientes", emojis_pendientes = pend, bitacora = bitacora_df(ctx)))
    }

    etapa("ETAPA 8. Limpieza y normalización de texto")
    d <- normalizar_texto(ctx, d)
    etapa("ETAPA 9. Referencias de género")
    d <- marcar_genero(ctx, d)
    etapa("ETAPA 10. Tokenización, stopwords personalizadas y tildes")
    d <- tokenizar_y_filtrar(ctx, d)
    etapa("ETAPA 11. Sentimientos con el diccionario propio")
    d <- calcular_sentimientos(ctx, d)
    etapa("ETAPA 12. Valores faltantes del dataset final")
    d <- rellenar_nulos(ctx, d)
    etapa("ETAPA 13. Validación de consistencia y exportación")
    d <- validar_consistencia(ctx, d)

    out <- exportar_salidas(ctx, d, dir_salida)
    b <- exportar_bitacora(ctx, dir_bitacoras, parametros_df(ctx))

    resumen <- list(
      estado = "ok", archivo = basename(ruta_archivo), responsable = responsable,
      registros_leidos = ctx$N_inicial, mensajes_limpios = nrow(out$limpio),
      mensajes_excluidos = nrow(out$excluidos),
      excluidos_por_motivo = as.list(table(out$excluidos$motivo_exclusion)),
      rango_fechas = c(format(min(d$fecha)), format(max(d$fecha))),
      sentimientos_activos = ctx$cfg$sent$nombre[ctx$cfg$sent$activo],
      polaridad = as.list(table(d$polaridad_msg)),
      emojis_pendientes = nrow(ctx$emojis_pendientes %||% data.frame()),
      pasos_bitacora = nrow(b))
    jsonlite::write_json(resumen, file.path(dir_salida, "resumen.json"), pretty = TRUE, auto_unbox = TRUE)

    if (consola == "didactico") {
      cat("\n", strrep("=", 98), "\n  LISTO\n", strrep("=", 98), "\n", sep = "")
      cat(sprintf("  Registros leídos     : %s\n  Mensajes limpios     : %s   (%s/mensajes_limpios.csv)\n  Mensajes excluidos   : %s   (%s/mensajes_excluidos.csv)\n",
                  .fmt(resumen$registros_leidos), .fmt(resumen$mensajes_limpios), dir_salida,
                  .fmt(resumen$mensajes_excluidos), dir_salida))
      cat("  Excluidos por motivo :\n")
      for (m in names(resumen$excluidos_por_motivo))
        cat(sprintf("      %-6s %s\n", .fmt(resumen$excluidos_por_motivo[[m]]), m))
      cat(sprintf("  Bitácora limpia      : %s/bitacora_limpia.xlsx (%d pasos)\n  Bitácora completa    : %s/bitacora_completa.xlsx\n",
                  dir_bitacoras, nrow(b), dir_bitacoras))
    } else if (consola == "resumen") {
      message("Listo. ", nrow(out$limpio), " mensajes limpios en ", dir_salida)
    }

    list(estado = "ok", datos = d, excluidos = out$excluidos, tokens = out$tokens,
         bitacora = b, emojis_pendientes = ctx$emojis_pendientes, resumen = resumen)
  }

  # ---- BITÁCORA COMPLETA: se escribe SIEMPRE (ok, detenido o error) ----
  anotar <- function(estado, mensaje = "", res = NULL) {
    ctx <- prog$ctx
    periodo <- paste0(fecha_inicio %||% "inicio", " a ", fecha_fin %||% "fin")
    fila <- list(
      fecha = format(t_ini, "%Y-%m-%d"), hora_inicio = format(t_ini, "%H:%M:%S"),
      hora_fin = format(Sys.time(), "%H:%M:%S"),
      duracion_seg = round(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 1),
      responsable = responsable, archivo = basename(ruta_archivo), archivo_md5 = substr(md5_entrada, 1, 8),
      parametros = sprintf("periodo=%s; umbral_publicidad=%s; sentimientos=%s; anonimizar=%s; emojis_nuevos=%s",
                           periodo, umbral_publicidad,
                           if (is.null(sentimientos_activos)) "todos los activos" else length(sentimientos_activos),
                           anonimizar_autor, nuevos_emojis),
      estado = estado,
      paso_donde_paro = if (estado == "ok") "" else prog$paso,
      mensaje_error = gsub("[\r\n]+", " ", mensaje),
      pasos_registrados = if (!is.null(ctx)) ctx$contador else 0L,
      registros_leidos = if (!is.null(ctx)) ctx$N_inicial %||% NA else NA,
      mensajes_limpios = if (!is.null(res$resumen)) res$resumen$mensajes_limpios else NA,
      mensajes_excluidos = if (!is.null(res$resumen)) res$resumen$mensajes_excluidos else NA,
      emojis_pendientes = if (!is.null(ctx$emojis_pendientes)) nrow(ctx$emojis_pendientes) else 0L)
    fila[] <- lapply(fila, function(x) if (is.null(x) || length(x) == 0 || is.na(x)) "" else as.character(x))
    # una sola llamada: fila en "Ejecuciones", un renglón por paso, y seguimiento de los cambios
    try(registrar_ejecucion(dir_bitacoras, fila, ctx, estado, mensaje, prog$paso), silent = FALSE)
  }

  res <- tryCatch(cuerpo(), error = function(e) {
    anotar("error", conditionMessage(e))
    if (consola != "silencioso")
      message("\nERROR en el paso '", prog$paso, "': ", conditionMessage(e),
              "\n(El intento quedó registrado en ", file.path(dir_bitacoras, "bitacora_completa.xlsx"),
              "; la bitácora limpia no se modificó.)")
    stop(conditionMessage(e), call. = FALSE)
  })
  anotar(if (identical(res$estado, "ok")) "ok" else "detenido_emojis_pendientes", "", res)
  invisible(res)
}
