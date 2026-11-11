# ==============================================================================
# bitacora.R  -  MOTOR DE LAS DOS BITÁCORAS
# ------------------------------------------------------------------------------
#  1) bitacoras/bitacora_limpia.xlsx    pasos de la ÚLTIMA ejecución exitosa (se sobrescribe)
#  2) bitacoras/bitacora_completa.xlsx  cambios, ejecuciones, pasos y experimentos (solo se agrega)
# (el detalle de cómo funciona cada una está más abajo, en la sección "LAS DOS BITÁCORAS")
#
# CORRECCIÓN (fechas/horas): si editas a mano una fecha u hora en Excel, Excel la guarda
# como número (46315, 0.7117593). Ahora .leer_completa() las convierte de vuelta a texto
# legible (2026-10-20, 17:05:03) cada vez que lee el archivo.
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- CSV que Excel abre bien (tildes y emojis) --------------------------------

escribir_csv <- function(x, f, bom = getOption("sentimientos.bom", TRUE)) {
  if (isTRUE(bom)) readr::write_excel_csv(x, f, na = "") else readr::write_csv(x, f, na = "")
}

COLS_BITACORA <- c(
  "campo_columna", "id_paso", "fecha", "hora", "atributo", "tipo_problema",
  "metodologia", "accion_realizada", "justificacion", "filas_afectadas",
  "impacto_dataset", "script", "filas_antes", "filas_despues",
  "ejemplo_antes", "ejemplo_despues", "id_mensaje_ejemplo", "responsable"
)

# ---- contexto de ejecución ----------------------------------------------------
nuevo_ctx <- function(params, cfg) {
  ctx <- new.env(parent = globalenv())
  ctx$p <- params
  ctx$cfg <- cfg
  ctx$filas <- list()
  ctx$contador <- 0L
  ctx$nota <- NULL
  ctx$excl <- list()
  ctx$detenido <- FALSE
  ctx$tokens <- NULL
  ctx$stop_log <- NULL
  ctx
}

.fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)

.txt_corto <- function(x, n = 220) {
  x <- gsub("[\r\n\t]+", " ", as.character(x))
  x <- gsub("\\s+", " ", x)
  ifelse(!is.na(x) & nchar(x) > n, paste0(substr(x, 1, n), "..."), x)
}

# Convierte el bloque de código en texto legible (sin las llaves externas)
.codigo_texto <- function(expr) {
  txt <- deparse(expr, width.cutoff = 90L)
  if (length(txt) >= 2 && trimws(txt[1]) == "{" && trimws(txt[length(txt)]) == "}")
    txt <- txt[-c(1, length(txt))]
  paste(sub("^    ", "", txt), collapse = "\n")
}

# ==============================================================================
#  CONSOLA: lo que el programa va "contando" mientras trabaja
#    consola = "didactico"  explica cada paso (qué hace, por qué, resultado, ejemplo, vista)
#    consola = "resumen"    una línea por paso
#    consola = "silencioso" nada
# ==============================================================================
.modo <- function(ctx) ctx$p$consola %||% "resumen"
.wrap <- function(txt, sangria = 14) {
  paste(strwrap(txt, width = 96, exdent = sangria), collapse = "\n")
}

.vista_texto <- function(df) {
  if (is.null(df) || !nrow(df) || !ncol(df)) return(NULL)
  df[] <- lapply(df, function(x) {
    if (inherits(x, c("POSIXct", "Date"))) x <- format(x)
    if (is.character(x)) { x <- gsub("[\r\n\t]+", " ", x); x <- ifelse(nchar(x) > 42, paste0(substr(x, 1, 40), ".."), x) }
    x
  })
  paste0("      ", utils::capture.output(print(df, row.names = FALSE)), collapse = "\n")
}

.imprimir_paso <- function(ctx, f, vista = NULL) {
  modo <- .modo(ctx)
  if (modo == "silencioso") return(invisible())
  if (modo == "resumen") {
    message(sprintf("   [%s] %s -> %s filas afectadas", f$id_paso, f$tipo_problema, .fmt(f$filas_afectadas)))
    return(invisible())
  }
  cat("\n", strrep("-", 98), "\n", sep = "")
  cat(sprintf("[%s]  %s\n", f$id_paso, f$metodologia))
  cat(sprintf("  Campo     : %s\n", f$campo_columna))
  cat(sprintf("  Problema  : %s\n", f$tipo_problema))
  cat("  Qué hace  : ", .wrap(f$accion_realizada), "\n", sep = "")
  cat("  Por qué   : ", .wrap(f$justificacion), "\n", sep = "")
  cat(sprintf("  Resultado : %s  |  filas afectadas: %s\n", f$impacto_dataset, .fmt(f$filas_afectadas)))
  if (!is.na(f$ejemplo_antes) && nzchar(f$ejemplo_antes)) {
    cat(sprintf("  Ejemplo   : ANTES   -> %s\n", f$ejemplo_antes))
    cat(sprintf("              DESPUÉS -> %s\n", f$ejemplo_despues))
  }
  v <- .vista_texto(vista)
  if (!is.null(v)) cat("  Así queda el dataset (3 primeras filas, columnas tocadas):\n", v, "\n", sep = "")
  invisible()
}

# ---- fila de bitácora -----------------------------------------------------------
.agregar_fila <- function(ctx, campo, atributo, problema, metodologia, accion,
                          justificacion, afectadas, impacto, script,
                          n_antes, n_despues, ej_antes = NA, ej_despues = NA,
                          ej_id = NA, vista = NULL) {
  ctx$contador <- ctx$contador + 1L
  ahora <- Sys.time()
  if (!is.null(ctx$nota)) {
    accion <- paste(accion, ctx$nota)
    ctx$nota <- NULL
  }
  fila <- data.frame(
    campo_columna = campo,
    id_paso = sprintf("P%02d", ctx$contador),
    fecha = format(ahora, "%Y-%m-%d"),
    hora = format(ahora, "%H:%M:%S"),
    atributo = atributo,
    tipo_problema = problema,
    metodologia = metodologia,
    accion_realizada = accion,
    justificacion = justificacion,
    filas_afectadas = as.numeric(afectadas),
    impacto_dataset = impacto,
    script = script,
    filas_antes = n_antes,
    filas_despues = n_despues,
    ejemplo_antes = .txt_corto(ej_antes),
    ejemplo_despues = .txt_corto(ej_despues),
    id_mensaje_ejemplo = as.character(ej_id),
    responsable = ctx$p$responsable %||% "",
    stringsAsFactors = FALSE
  )
  ctx$filas[[ctx$contador]] <- fila
  .imprimir_paso(ctx, fila, vista)
  invisible(NULL)
}

# ---- comparar dataset antes/después de un paso ------------------------------------
# Elige un ejemplo ilustrativo: corto (20-160 caracteres) y donde el cambio se vea
.elegir <- function(cand, antes_txt, despues_txt) {
  a <- gsub("\\s+", " ", as.character(antes_txt[cand]))
  b <- gsub("\\s+", " ", as.character(despues_txt[cand]))
  largo <- nchar(a)
  visible <- !is.na(a) & !is.na(b) & a != b
  ok <- which(visible & !is.na(largo) & largo >= 20 & largo <= 160)
  if (!length(ok)) ok <- which(visible)
  if (!length(ok)) ok <- seq_along(cand)
  cand[ok[1]]
}

.comparar <- function(antes, despues, col, texto_ref) {
  out <- list(removidas = 0L, modificadas = 0L, ej_antes = NA, ej_despues = NA, ej_id = NA)
  idc <- "id_mensaje"
  rem_ids <- setdiff(antes[[idc]], despues[[idc]])
  out$removidas <- length(rem_ids)
  
  if (!is.null(col) && col %in% names(despues)) {
    idx <- match(despues[[idc]], antes[[idc]])
    b <- despues[[col]]
    if (col %in% names(antes)) {
      a <- antes[[col]][idx]
      dif <- !is.na(idx) & (xor(is.na(a), is.na(b)) | (!is.na(a) & !is.na(b) & a != b))
      nuevo <- FALSE
    } else {
      dif <- if (is.logical(b)) b %in% TRUE
      else if (is.character(b)) (!is.na(b) & nzchar(b))
      else !is.na(b)
      dif <- dif & !is.na(idx)
      nuevo <- TRUE
    }
    out$modificadas <- sum(dif)
    if (any(dif)) {
      ref_txt <- if (nuevo && !is.null(texto_ref) && texto_ref %in% names(despues)) despues[[texto_ref]]
      else if (nuevo) rep(NA_character_, length(b)) else a
      k <- .elegir(which(dif), ref_txt, if (nuevo) as.character(b) else b)
      out$ej_id <- despues[[idc]][k]
      if (nuevo) {
        out$ej_antes <- if (!is.null(texto_ref) && texto_ref %in% names(despues)) despues[[texto_ref]][k] else "(columna nueva)"
        out$ej_despues <- as.character(b[k])
      } else {
        out$ej_antes <- as.character(a[k])
        out$ej_despues <- as.character(b[k])
      }
      return(out)
    }
  }
  if (length(rem_ids) > 0) {
    k <- match(rem_ids[1], antes[[idc]])
    colx <- if (!is.null(col) && col %in% names(antes)) col else
      if ("texto_original" %in% names(antes)) "texto_original" else NULL
    out$ej_id <- rem_ids[1]
    out$ej_antes <- if (!is.null(colx)) as.character(antes[[colx]][k]) else NA
    if ((is.na(out$ej_antes) || !nzchar(out$ej_antes)) && "tipo_contenido" %in% names(antes))
      out$ej_antes <- paste0("[mensaje sin texto, tipo: ", antes$tipo_contenido[k], "]")
    out$ej_despues <- "(fila excluida del dataset limpio)"
  }
  out
}

# ------------------------------------------------------------------------------
# registrar_paso(): ejecuta el bloque `codigo` (que modifica `datos`) y lo registra.
#   ejemplo_col : columna cuyo cambio define "fila afectada" y el ejemplo
#   texto_ref   : columna mostrada como "antes" cuando ejemplo_col es nueva
#   afectadas   : (opcional) expresión que cuenta las filas afectadas
# ------------------------------------------------------------------------------
registrar_paso <- function(ctx, datos, metodologia, campo, atributo, problema,
                           accion, justificacion, ejemplo_col = NULL,
                           texto_ref = "texto_original", afectadas, codigo) {
  caller <- parent.frame()
  expr <- substitute(codigo)
  expr_af <- if (!missing(afectadas)) substitute(afectadas) else NULL
  env <- new.env(parent = caller)
  env$datos <- datos
  ctx$nota <- NULL
  eval(expr, env)
  res <- env$datos
  
  cmp <- .comparar(datos, res, ejemplo_col, texto_ref)
  n0 <- nrow(datos); n1 <- nrow(res)
  af <- if (!is.null(expr_af)) as.numeric(eval(expr_af, env)) else cmp$removidas + cmp$modificadas
  
  nuevas <- setdiff(names(res), names(datos))
  imp <- if (n1 != n0) sprintf("Filas: %s -> %s (%+.1f%%)", .fmt(n0), .fmt(n1), 100 * (n1 - n0) / n0)
  else sprintf("Filas sin cambio (%s)", .fmt(n0))
  if (n1 == n0 && length(nuevas) == 0 && af > 0 && !is.null(ejemplo_col))
    imp <- sprintf("%s valores modificados (%.1f%% de las filas)", .fmt(af), 100 * af / max(n0, 1))
  if (length(nuevas)) imp <- paste0(imp, "; columnas nuevas: ", paste(nuevas, collapse = ", "))
  
  cols_vista <- unique(c("id_mensaje", intersect(c(ejemplo_col, nuevas), names(res))))
  vista <- if (n1 > 0) utils::head(res[, utils::head(cols_vista, 6), drop = FALSE], 3) else NULL
  
  .agregar_fila(ctx, campo, atributo, problema, metodologia, accion, justificacion,
                af, imp, .codigo_texto(expr), n0, n1,
                cmp$ej_antes, cmp$ej_despues, cmp$ej_id, vista)
  res
}

# ------------------------------------------------------------------------------
# registrar_hallazgo(): paso que NO modifica datos (auditoría / validación)
#   valor : expresión que devuelve el número de filas involucradas
# ------------------------------------------------------------------------------
registrar_hallazgo <- function(ctx, metodologia, campo, atributo, problema, accion,
                               justificacion, valor, base = NULL, script = NULL,
                               ejemplo = NULL) {
  expr <- substitute(valor)
  v <- as.numeric(eval(expr, parent.frame()))
  imp <- if (!is.null(base) && base > 0)
    sprintf("%s de %s (%.1f%%); sin modificar datos", .fmt(v), .fmt(base), 100 * v / base)
  else sprintf("Valor observado: %s; sin modificar datos", .fmt(v))
  .agregar_fila(ctx, campo, atributo, problema, metodologia, accion, justificacion,
                v, imp, script %||% .codigo_texto(expr), base %||% NA, base %||% NA,
                ejemplo %||% NA, NA, NA)
  invisible(v)
}

# ---- filas excluidas (nada se pierde: queda en mensajes_excluidos.csv) ---------------
excluir <- function(ctx, df, motivo) {
  if (is.null(df) || nrow(df) == 0) return(invisible(NULL))
  g <- function(col, def = NA) {
    if (col %in% names(df)) df[[col]]
    else if (length(def) == nrow(df)) def
    else rep(def, nrow(df))
  }
  ctx$excl[[length(ctx$excl) + 1L]] <- data.frame(
    id_mensaje = g("id_mensaje"),
    fecha_hora = as.character(g("fecha_hora", g("fecha_raw"))),
    autor = as.character(g("autor", g("autor_raw"))),
    tipo_contenido = as.character(g("tipo_contenido")),
    accion_servicio = as.character(g("accion_servicio")),
    motivo_exclusion = motivo,
    puntaje_publicidad = g("puntaje_publicidad"),
    motivo_publicidad = as.character(g("motivo_publicidad")),
    texto_original = .txt_corto({
      t <- g("texto_original", g("texto_raw")); a <- g("accion_servicio")
      ifelse(is.na(t) | !nzchar(t), ifelse(is.na(a), "", paste0("[acción de servicio: ", a, "]")), t)
    }, 2000),
    stringsAsFactors = FALSE
  )
  invisible(NULL)
}

bitacora_df <- function(ctx) {
  if (!length(ctx$filas)) return(as.data.frame(matrix(nrow = 0, ncol = length(COLS_BITACORA),
                                                      dimnames = list(NULL, COLS_BITACORA))))
  b <- do.call(rbind, ctx$filas)
  b[, COLS_BITACORA]
}

excluidos_df <- function(ctx) {
  if (!length(ctx$excl)) return(data.frame())
  do.call(rbind, ctx$excl)
}

# ---- estilos Excel -------------------------------------------------------------------
.est_cab <- function() openxlsx::createStyle(fontName = "Arial", fontSize = 10, fontColour = "#FFFFFF",
                                             fgFill = "#1F3864", textDecoration = "bold", halign = "center", valign = "center",
                                             wrapText = TRUE, border = "TopBottomLeftRight")
.est_cel <- function() openxlsx::createStyle(fontName = "Arial", fontSize = 9, valign = "top",
                                             wrapText = TRUE, border = "TopBottomLeftRight", borderColour = "#BFBFBF")

.hoja <- function(wb, nombre, df, anchos) {
  openxlsx::addWorksheet(wb, nombre)
  openxlsx::writeData(wb, nombre, df, withFilter = TRUE)
  openxlsx::addStyle(wb, nombre, .est_cab(), rows = 1, cols = seq_along(df), gridExpand = TRUE)
  if (nrow(df) > 0)
    openxlsx::addStyle(wb, nombre, .est_cel(), rows = 2:(nrow(df) + 1), cols = seq_along(df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, nombre, cols = seq_along(df), widths = c(anchos, rep(18, ncol(df)))[seq_along(df)])
  openxlsx::freezePane(wb, nombre, firstRow = TRUE)
}

# ==============================================================================
#  LAS DOS BITÁCORAS (todo vive en la carpeta bitacoras/)
# ------------------------------------------------------------------------------
#  1) bitacora_limpia.xlsx    Los pasos de la ÚLTIMA ejecución exitosa (se sobrescribe).
#                             Hojas: "Bitacora" y "Parametros".
#  2) bitacora_completa.xlsx  TODO lo que pasó, en cuatro hojas (solo se agregan filas):
#        Cambios              cada cambio hecho al código o a un diccionario, con su
#                             justificación y su resultado hasta llegar a una ejecución ok.
#        Ejecuciones          una fila por cada intento (ok, error, detenido, otro dataset).
#        Pasos por ejecucion  una fila por cada paso de cada intento.
#        Experimentos         pruebas posteriores (TF-IDF, shallow, LDA...) y con qué
#                             ejecución de preprocesamiento se hicieron.

# ==============================================================================

f_limpia   <- function(dir) file.path(dir, "bitacora_limpia.xlsx")
f_completa <- function(dir) file.path(dir, "bitacora_completa.xlsx")
f_control  <- function(dir) file.path(dir, "_copia_de_control.json")

# ==============================================================================
#  1) BITÁCORA LIMPIA (se actualiza solo con cada ejecución exitosa)
# ==============================================================================
exportar_bitacora <- function(ctx, dir_bitacoras, extra_params = NULL) {
  dir.create(dir_bitacoras, recursive = TRUE, showWarnings = FALSE)
  b <- bitacora_df(ctx)
  wb <- openxlsx::createWorkbook()
  .hoja(wb, "Bitacora", b, c(18, 8, 11, 9, 11, 28, 30, 55, 55, 11, 38, 70, 10, 10, 45, 45, 12, 14))
  openxlsx::freezePane(wb, "Bitacora", firstRow = TRUE, firstActiveCol = 3)
  if (!is.null(extra_params)) .hoja(wb, "Parametros", extra_params, c(34, 95))
  tryCatch(openxlsx::saveWorkbook(wb, f_limpia(dir_bitacoras), overwrite = TRUE),
           error = function(e) warning("No se pudo guardar bitacora_limpia.xlsx (¿está abierto en Excel?): ",
                                       conditionMessage(e), call. = FALSE))
  invisible(b)
}

# ==============================================================================
#  2) BITÁCORA COMPLETA
# ==============================================================================
COLS_CAMBIOS <- c("id_cambio", "fecha", "hora", "tipo", "archivo", "seccion", "problema_detectado",
                  "como_se_detecto", "cambio_realizado", "justificacion", "resultado",
                  "ejecucion_prueba", "responsable", "estado_registro")
COLS_EJECUCIONES <- c("id_ejecucion", "fecha", "hora_inicio", "hora_fin", "duracion_seg", "responsable",
                      "archivo", "archivo_md5", "evento", "parametros", "estado", "paso_donde_paro",
                      "mensaje_error", "pasos_registrados", "registros_leidos", "mensajes_limpios",
                      "mensajes_excluidos", "emojis_pendientes", "cambios_detectados")
COLS_PASOS <- c("id_ejecucion", "id_instancia", "fecha", "hora", "archivo", "estado_paso", "id_paso",
                "etapa", "campo_columna", "tipo_problema", "accion_realizada", "filas_antes",
                "filas_despues", "filas_afectadas", "impacto_dataset", "ejemplo_antes",
                "ejemplo_despues", "mensaje_error", "script")
COLS_EXPERIMENTOS <- c("id_experimento", "fecha", "hora", "id_ejecucion_preprocesamiento", "dataset",
                       "dataset_md5", "metodo", "parametros", "n_documentos", "tamano_vocabulario",
                       "resultado_principal", "archivo_resultado", "notas", "responsable")

HOJAS_COMPLETA <- list("Cambios" = COLS_CAMBIOS, "Ejecuciones" = COLS_EJECUCIONES,
                       "Pasos por ejecucion" = COLS_PASOS, "Experimentos" = COLS_EXPERIMENTOS)
ANCHOS_COMPLETA <- list(
  "Cambios" = c(10, 12, 9, 12, 26, 28, 50, 38, 60, 60, 30, 16, 12, 16),
  "Ejecuciones" = c(9, 11, 10, 10, 9, 14, 18, 11, 26, 50, 14, 38, 50, 10, 10, 10, 10, 10, 22),
  "Pasos por ejecucion" = c(9, 11, 11, 9, 18, 10, 8, 30, 28, 30, 55, 10, 10, 10, 38, 40, 40, 30, 60),
  "Experimentos" = c(12, 11, 9, 14, 18, 11, 22, 45, 12, 12, 50, 30, 40, 12))

.vacio <- function(cols) as.data.frame(matrix(character(0), 0, length(cols), dimnames = list(NULL, cols)),
                                       stringsAsFactors = FALSE)

# ---- Fechas y horas editadas a mano en Excel --------------------------------------
# Excel guarda una fecha como número de serie (20/10/2026 = 46315) y una hora como
# fracción del día (17:05:03 = 0.7117593). Si editas una celda a mano y Excel la vuelve
# fecha/hora real, aquí se devuelve a texto legible (2026-10-20 / 17:05:03).
# Si agregas otra columna de fecha u hora, añade su nombre a estas listas.
.COLS_FECHA <- c("fecha")
.COLS_HORA  <- c("hora", "hora_inicio", "hora_fin")

.arreglar_fecha <- function(v) {
  s <- trimws(as.character(v))
  es_serial <- !is.na(s) & grepl("^[0-9]+(\\.[0-9]+)?$", s)
  if (any(es_serial))
    s[es_serial] <- format(as.Date(floor(as.numeric(s[es_serial])), origin = "1899-12-30"), "%Y-%m-%d")
  s
}

.arreglar_hora <- function(v) {
  s <- trimws(as.character(v))
  es_serial <- !is.na(s) & grepl("^[0-9]*\\.[0-9]+$", s)
  if (any(es_serial)) {
    x <- as.numeric(s[es_serial])
    seg <- round((x - floor(x)) * 86400)
    s[es_serial] <- sprintf("%02d:%02d:%02d", seg %/% 3600, (seg %% 3600) %/% 60, seg %% 60)
  }
  s
}

# Lee las 4 hojas como texto. Es TOLERANTE: si escribiste filas o columnas a mano, las respeta.
.leer_completa <- function(dir) {
  f <- f_completa(dir)
  existentes <- if (file.exists(f)) tryCatch(openxlsx::getSheetNames(f), error = function(e) character(0)) else character(0)
  out <- lapply(names(HOJAS_COMPLETA), function(h) {
    cols <- HOJAS_COMPLETA[[h]]
    x <- if (h %in% existentes) tryCatch(openxlsx::read.xlsx(f, sheet = h, colNames = TRUE),
                                         error = function(e) NULL) else NULL
    if (is.null(x) || !ncol(x)) return(.vacio(cols))
    for (cn in names(x)) {
      v <- x[[cn]]
      na <- is.na(v)
      if (cn %in% .COLS_FECHA)     v <- .arreglar_fecha(v)
      else if (cn %in% .COLS_HORA) v <- .arreglar_hora(v)
      else v <- if (is.numeric(v)) format(v, scientific = FALSE, trim = TRUE, drop0trailing = TRUE) else as.character(v)
      v[na] <- ""
      x[[cn]] <- v
    }
    for (cn in setdiff(cols, names(x))) x[[cn]] <- character(nrow(x))
    x[, c(cols, setdiff(names(x), cols)), drop = FALSE]
  })
  names(out) <- names(HOJAS_COMPLETA)
  out
}

# Une dos tablas aunque tengan columnas distintas (por columnas escritas a mano)
.unir <- function(a, b) {
  todas <- union(names(a), names(b))
  for (cn in setdiff(todas, names(a))) a[[cn]] <- character(nrow(a))
  for (cn in setdiff(todas, names(b))) b[[cn]] <- character(nrow(b))
  rbind(a[, todas, drop = FALSE], b[, todas, drop = FALSE])
}

# Siguiente número correlativo a partir del ÚLTIMO id existente (E007 -> E008)
.siguiente_id <- function(prefijo, ids, ancho = 3) {
  ids <- ids[grepl(paste0("^", prefijo, "[0-9]+$"), ids)]
  n <- suppressWarnings(as.integer(sub(paste0("^", prefijo, "0*([0-9]+)$"), "\\1", ids)))
  sprintf(paste0("%s%0", ancho, "d"), prefijo, (if (length(n)) max(n, na.rm = TRUE) else 0L) + 1L)
}

# Una celda vacía en "justificacion" = el cambio quedó sin explicar
.estado_cambios <- function(cam) {
  cam$estado_registro <- ifelse(nzchar(trimws(cam$justificacion)), "completo", "FALTA JUSTIFICAR")
  cam
}

# Guarda las 4 hojas en bitacora_completa.xlsx. Devuelve TRUE/FALSE (FALSE si el Excel está abierto).
.guardar_completa <- function(dir, hojas) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  wb <- openxlsx::createWorkbook()
  for (h in names(HOJAS_COMPLETA)) .hoja(wb, h, hojas[[h]], ANCHOS_COMPLETA[[h]])
  pinta <- function(hoja, col, valores, colores) {
    df <- hojas[[hoja]]
    if (!nrow(df) || !(col %in% names(df))) return(invisible())
    for (i in seq_len(nrow(df))) {
      rel <- if (valores[i] %in% names(colores)) colores[[valores[i]]] else colores[["otro"]]
      if (!is.null(rel) && nzchar(rel))
        openxlsx::addStyle(wb, hoja, openxlsx::createStyle(fgFill = rel), rows = i + 1,
                           cols = match(col, names(df)), stack = TRUE)
    }
  }
  pinta("Ejecuciones", "estado", hojas$Ejecuciones$estado, list(ok = "#E2EFDA", error = "#F8CBAD", otro = "#FFF2CC"))
  pinta("Pasos por ejecucion", "estado_paso", hojas[["Pasos por ejecucion"]]$estado_paso,
        list(ok = "", error = "#F8CBAD", otro = "#FFF2CC"))
  pinta("Cambios", "estado_registro", hojas$Cambios$estado_registro, list(`FALTA JUSTIFICAR` = "#FFF2CC"))
  tryCatch({ openxlsx::saveWorkbook(wb, f_completa(dir), overwrite = TRUE); TRUE },
           error = function(e) {
             warning("No se pudo guardar bitacora_completa.xlsx (¿está abierto en Excel? Ciérralo y vuelve a ejecutar): ",
                     conditionMessage(e), call. = FALSE)
             FALSE })
}

# ------------------------------------------------------------------------------
# DETECCIÓN AUTOMÁTICA DE CAMBIOS (código y diccionarios)
# ------------------------------------------------------------------------------
.archivos_vigilados <- function(dir_config) {
  r <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  raiz <- intersect(c("cargar_proyecto.R", "ejecutar.R"), list.files("."))
  cfg <- list.files(dir_config, pattern = "\\.(csv|json)$", full.names = TRUE)
  sort(unique(c(raiz, r, cfg)))
}

.leer_lineas <- function(f) {
  x <- readLines(f, warn = FALSE, encoding = "UTF-8")
  x <- sub("\r$", "", x)
  if (length(x)) x[1] <- sub("^\ufeff", "", x[1])
  x
}

.leer_control <- function(dir) {
  f <- f_control(dir)
  if (!file.exists(f)) return(NULL)
  tryCatch({
    x <- jsonlite::fromJSON(f, simplifyVector = FALSE)
    lapply(x, function(v) as.character(unlist(v)))
  }, error = function(e) NULL)
}

.guardar_control <- function(dir, archivos) {
  jsonlite::write_json(lapply(archivos, as.character), f_control(dir), auto_unbox = FALSE, pretty = FALSE)
}

.lista_corta <- function(x, n = 10) {
  paste0(paste(utils::head(x, n), collapse = ", "), if (length(x) > n) sprintf(" (+%d más)", length(x) - n) else "")
}

# Encabezado de sección más cercano hacia arriba (p. ej. "8.2c Códigos de materia")
.seccion_de <- function(lineas, i) {
  if (!length(lineas) || is.na(i)) return("")
  i <- min(max(i, 1L), length(lineas))
  pat <- "^\\s*#\\s*\u2500\u2500|<-\\s*function\\s*\\("
  j <- which(grepl(pat, lineas[seq_len(i)]))
  if (!length(j)) return("")
  l <- lineas[tail(j, 1)]
  if (grepl("<-\\s*function\\s*\\(", l)) return(paste0("función ", sub("\\s*<-.*$", "", trimws(l))))
  trimws(gsub("\u2500+", "", sub("^\\s*#\\s*", "", l)))
}

.describir_csv <- function(old, new) {
  clave <- function(x) sub("^\"?([^\",]*).*$", "\\1", x)
  partes <- character(0)
  if (length(old) && length(new) && !identical(old[1], new[1])) partes <- "cambió el encabezado"
  o <- if (length(old) > 1) old[-1] else character(0)
  n <- if (length(new) > 1) new[-1] else character(0)
  ka <- clave(n[!(n %in% o)]); kd <- clave(o[!(o %in% n)])
  mod <- intersect(ka, kd); add <- setdiff(ka, mod); del <- setdiff(kd, mod)
  if (length(add)) partes <- c(partes, sprintf("agregó %d: %s", length(add), .lista_corta(add)))
  if (length(del)) partes <- c(partes, sprintf("quitó %d: %s", length(del), .lista_corta(del)))
  if (length(mod)) partes <- c(partes, sprintf("modificó %d: %s", length(mod), .lista_corta(mod)))
  if (!length(partes)) "solo cambió el orden o el formato de las filas" else paste(partes, collapse = " | ")
}

.describir_sentimientos <- function(old, new) {
  a <- jsonlite::fromJSON(paste(old, collapse = "\n"), simplifyVector = TRUE)$sentimientos
  b <- jsonlite::fromJSON(paste(new, collapse = "\n"), simplifyVector = TRUE)$sentimientos
  partes <- character(0)
  for (s in setdiff(b$nombre, a$nombre)) partes <- c(partes, sprintf("sentimiento nuevo: %s", s))
  for (s in setdiff(a$nombre, b$nombre)) partes <- c(partes, sprintf("sentimiento eliminado: %s", s))
  for (s in intersect(a$nombre, b$nombre)) {
    x <- a[a$nombre == s, ]; y <- b[b$nombre == s, ]
    for (campo in c("palabras", "raices")) {
      p0 <- unlist(x[[campo]]); p1 <- unlist(y[[campo]])
      ag <- setdiff(p1, p0); qu <- setdiff(p0, p1)
      if (length(ag)) partes <- c(partes, sprintf("%s: +%s (%s)", s, .lista_corta(ag, 8), campo))
      if (length(qu)) partes <- c(partes, sprintf("%s: -%s (%s)", s, .lista_corta(qu, 8), campo))
    }
    for (campo in c("activo", "polaridad", "definicion", "orden"))
      if (!identical(x[[campo]], y[[campo]]))
        partes <- c(partes, sprintf("%s: %s %s -> %s", s, campo, .txt_corto(x[[campo]], 40), .txt_corto(y[[campo]], 40)))
  }
  if (!length(partes)) NULL else paste(partes, collapse = " | ")
}

.describir_codigo <- function(old, new) {
  ag <- new[!(new %in% old)]; qu <- old[!(old %in% new)]
  idx <- which(!(new %in% old))
  sec <- if (length(idx)) .seccion_de(new, idx[1]) else .seccion_de(old, which(!(old %in% new))[1])
  nota <- trimws(ag[nzchar(trimws(ag)) & !grepl("^\\s*#", ag)])
  ej <- if (length(nota)) paste0(" Ej.: ", paste(substr(utils::head(nota, 2), 1, 90), collapse = " // ")) else ""
  list(detalle = sprintf("+%d / -%d líneas%s.%s", length(ag), length(qu),
                         if (length(idx)) sprintf(" (primera modificación: línea %d)", idx[1]) else "", ej),
       seccion = sec)
}

.describir <- function(a, old, new, nuevo, borrado) {
  if (nuevo) return(list(detalle = sprintf("archivo nuevo (%d líneas)", length(new)), seccion = ""))
  if (borrado) return(list(detalle = "archivo eliminado", seccion = ""))
  if (grepl("\\.R$", a)) return(.describir_codigo(old, new))
  det <- NULL
  if (grepl("sentimientos\\.json$", a)) det <- tryCatch(.describir_sentimientos(old, new), error = function(e) NULL)
  if (is.null(det) && grepl("\\.csv$", a)) det <- .describir_csv(old, new)
  if (is.null(det)) det <- .describir_codigo(old, new)$detalle
  list(detalle = det, seccion = "")
}

.preguntar <- function(txt) trimws(readline(paste0("   ", txt, " ")))

.avisar_pendientes <- function(dir) {
  cam <- tryCatch(.leer_completa(dir)$Cambios, error = function(e) NULL)
  if (is.null(cam) || !nrow(cam)) return(invisible())
  n <- sum(!nzchar(trimws(cam$justificacion)))
  if (n > 0) message("Bitácora: ", n, " cambio(s) sin justificar. Completa la columna 'justificacion' en la hoja ",
                     "'Cambios' de ", f_completa(dir), ".")
}

# ------------------------------------------------------------------------------
# vigilar_cambios(): se llama sola al inicio de preprocesar().
#   Compara R/*.R, cargar_proyecto.R, ejecutar.R y config/* con la última foto.
#   Si algo cambió: lo describe, te pide la justificación y lo anota en la hoja "Cambios".
#   preguntar = TRUE en consola de R/RStudio; FALSE en Rscript. motivo: justificación común.
# ------------------------------------------------------------------------------
vigilar_cambios <- function(dir_bitacoras, dir_config = "config", responsable = "",
                            preguntar = interactive(), motivo = NULL) {
  dir.create(dir_bitacoras, recursive = TRUE, showWarnings = FALSE)
  archivos <- .archivos_vigilados(dir_config)
  actual <- stats::setNames(lapply(archivos, .leer_lineas), archivos)
  previo <- .leer_control(dir_bitacoras)
  
  if (is.null(previo)) {
    .guardar_control(dir_bitacoras, actual)
    message("Bitácoras: primera ejecución en esta carpeta. Se tomó la versión actual de ", length(actual),
            " archivos como punto de partida; desde ahora los cambios se registran solos.")
    return(invisible(character(0)))
  }
  
  nuevos <- setdiff(names(actual), names(previo))
  borrados <- setdiff(names(previo), names(actual))
  comunes <- intersect(names(actual), names(previo))
  mod <- comunes[!vapply(comunes, function(a) identical(actual[[a]], previo[[a]]), logical(1))]
  todos <- c(mod, nuevos, borrados)
  if (!length(todos)) { .avisar_pendientes(dir_bitacoras); return(invisible(character(0))) }
  
  hojas <- .leer_completa(dir_bitacoras)
  cam <- hojas$Cambios
  misma <- NULL
  ids <- character(0)
  if (preguntar) cat("\n", strrep("=", 90), "\n  Se detectaron ", length(todos),
                     " archivo(s) con cambios desde la última vez. Cuéntame qué pasó\n  (Enter deja la respuesta vacía; luego puedes completarla en el Excel).\n",
                     strrep("=", 90), "\n", sep = "")
  for (k in seq_along(todos)) {
    a <- todos[k]
    old <- if (a %in% names(previo)) previo[[a]] else character(0)
    new <- if (a %in% names(actual)) actual[[a]] else character(0)
    desc <- .describir(a, old, new, nuevo = a %in% nuevos, borrado = a %in% borrados)
    resp <- list(problema = "", como = "", porque = "")
    if (!is.null(misma)) {
      resp <- misma
    } else if (preguntar) {
      cat("\n-- ", a, if (nzchar(desc$seccion)) paste0("  [", desc$seccion, "]"), "\n   ", desc$detalle, "\n", sep = "")
      resp$problema <- .preguntar("¿Qué problema notaste o qué querías lograr?")
      resp$como <- .preguntar("¿Cómo lo detectaste? (Enter para omitir)")
      resp$porque <- .preguntar("¿Por qué este cambio lo resuelve? (justificación)")
      resto <- length(todos) - k
      if (resto > 0) {
        r <- tolower(.preguntar(sprintf("¿Usar estas mismas respuestas para los %d archivo(s) restantes? (s/n)", resto)))
        if (r %in% c("s", "si", "sí")) misma <- resp
      }
    } else if (!is.null(motivo)) {
      resp$porque <- motivo
    }
    ahora <- Sys.time()
    id <- .siguiente_id("C", cam$id_cambio, ancho = 2)
    fila <- data.frame(
      id_cambio = id, fecha = format(ahora, "%Y-%m-%d"), hora = format(ahora, "%H:%M:%S"),
      tipo = if (grepl("\\.R$", a)) "código" else "diccionario", archivo = a, seccion = desc$seccion,
      problema_detectado = resp$problema, como_se_detecto = resp$como, cambio_realizado = desc$detalle,
      justificacion = resp$porque, resultado = "", ejecucion_prueba = "", responsable = responsable,
      estado_registro = "", stringsAsFactors = FALSE)
    cam <- .unir(cam, fila)
    ids <- c(ids, id)
  }
  hojas$Cambios <- .estado_cambios(cam)
  if (.guardar_completa(dir_bitacoras, hojas)) {
    .guardar_control(dir_bitacoras, actual)      # la foto solo se actualiza si el registro se guardó
    message("Bitácora: se registraron ", length(ids), " cambio(s): ", paste(ids, collapse = ", "), ".")
    .avisar_pendientes(dir_bitacoras)
  }
  invisible(ids)
}

# ------------------------------------------------------------------------------
# anotar_cambio(): para decisiones o correcciones que NO son un cambio de archivo
#   anotar_cambio("R/06_texto.R", "10.3 Tildes", problema = "...", cambio = "...", justificacion = "...")
# ------------------------------------------------------------------------------
anotar_cambio <- function(archivo, seccion = "", problema, como_se_detecto = "", cambio,
                          justificacion = "", resultado = "", tipo = "decisión",
                          responsable = Sys.getenv("RESPONSABLE", "equipo"), dir_bitacoras = "bitacoras") {
  hojas <- .leer_completa(dir_bitacoras)
  cam <- hojas$Cambios
  fila <- data.frame(
    id_cambio = .siguiente_id("C", cam$id_cambio, ancho = 2), fecha = format(Sys.Date()),
    hora = format(Sys.time(), "%H:%M:%S"), tipo = tipo, archivo = archivo, seccion = seccion,
    problema_detectado = problema, como_se_detecto = como_se_detecto, cambio_realizado = cambio,
    justificacion = justificacion, resultado = resultado, ejecucion_prueba = "manual",
    responsable = responsable, estado_registro = "", stringsAsFactors = FALSE)
  hojas$Cambios <- .estado_cambios(.unir(cam, fila))
  .guardar_completa(dir_bitacoras, hojas)
  invisible(fila)
}

# ------------------------------------------------------------------------------
# registrar_ejecucion(): UNA llamada al terminar cada intento (ok, error o detenido).
#   - agrega 1 fila a "Ejecuciones" y 1 fila por paso a "Pasos por ejecucion"
#   - a cada cambio aún sin ejecución exitosa le suma este intento (E012 -> E013) y su
#     resultado (error en '...' -> ok), así queda el camino hasta el paso exitoso final
# ------------------------------------------------------------------------------
registrar_ejecucion <- function(dir_bitacoras, fila, ctx, estado = "ok", mensaje = "", paso_final = "") {
  hojas <- .leer_completa(dir_bitacoras)
  ej <- hojas$Ejecuciones; cam <- hojas$Cambios
  id_e <- .siguiente_id("E", ej$id_ejecucion)
  fila$id_ejecucion <- id_e
  
  # ¿mismo dataset o se cambió de archivo? (se compara el CONTENIDO, no el nombre)
  md5s <- ej$archivo_md5[nzchar(ej$archivo_md5)]
  fila$evento <- if (!length(md5s)) "primera ejecución"
  else if (!nzchar(fila$archivo_md5)) "(sin dato del archivo)"
  else if (tail(md5s, 1) == fila$archivo_md5) "mismo dataset (reejecución)"
  else if (fila$archivo_md5 %in% md5s) "vuelve a un dataset anterior"
  else "DATASET NUEVO (se cambió de archivo)"
  
  # cambios que se prueban por primera vez en este intento + seguimiento de los abiertos
  excl <- c("histórico", "manual")
  abiertos <- which(!(cam$ejecucion_prueba %in% excl) & !grepl("ok$", cam$resultado))
  nuevos_c <- abiertos[!nzchar(cam$ejecucion_prueba[abiertos])]
  fila$cambios_detectados <- paste(cam$id_cambio[nuevos_c], collapse = ", ")
  est_txt <- switch(estado, ok = "ok", error = paste0("error en '", paso_final, "'"), "detenido (emojis pendientes)")
  for (i in abiertos) {
    cam$ejecucion_prueba[i] <- if (nzchar(cam$ejecucion_prueba[i])) paste(cam$ejecucion_prueba[i], id_e, sep = " \u2192 ") else id_e
    cam$resultado[i] <- if (nzchar(cam$resultado[i])) paste(cam$resultado[i], est_txt, sep = " \u2192 ") else est_txt
  }
  
  # pasos de este intento
  b <- if (!is.null(ctx)) bitacora_df(ctx) else NULL
  nuevas <- NULL
  if (!is.null(b) && nrow(b)) {
    nuevas <- data.frame(
      id_ejecucion = id_e, id_instancia = paste0(id_e, "-", b$id_paso), fecha = b$fecha, hora = b$hora,
      archivo = fila$archivo, estado_paso = "ok", id_paso = b$id_paso, etapa = b$metodologia,
      campo_columna = b$campo_columna, tipo_problema = b$tipo_problema, accion_realizada = b$accion_realizada,
      filas_antes = b$filas_antes, filas_despues = b$filas_despues, filas_afectadas = b$filas_afectadas,
      impacto_dataset = b$impacto_dataset, ejemplo_antes = b$ejemplo_antes, ejemplo_despues = b$ejemplo_despues,
      mensaje_error = "", script = b$script, stringsAsFactors = FALSE)
  }
  if (!identical(estado, "ok")) {
    n <- if (is.null(nuevas)) 0L else nrow(nuevas)
    ult <- data.frame(
      id_ejecucion = id_e, id_instancia = sprintf("%s-P%02d", id_e, n + 1L), fecha = fila$fecha,
      hora = fila$hora_fin %||% "", archivo = fila$archivo,
      estado_paso = if (identical(estado, "error")) "error" else "detenido", id_paso = sprintf("P%02d", n + 1L),
      etapa = paso_final, campo_columna = "", tipo_problema = "", accion_realizada = "", filas_antes = "",
      filas_despues = "", filas_afectadas = "", impacto_dataset = "", ejemplo_antes = "", ejemplo_despues = "",
      mensaje_error = mensaje, script = "", stringsAsFactors = FALSE)
    nuevas <- if (is.null(nuevas)) ult else rbind(nuevas, ult)
  }
  if (!is.null(nuevas) && nrow(nuevas)) {
    nuevas[] <- lapply(nuevas, function(v) { v <- as.character(v); v[is.na(v)] <- ""; gsub("[\r\n]+", " ", v) })
    nuevas$script <- sub("^\\s+", "", nuevas$script)
    hojas[["Pasos por ejecucion"]] <- .unir(hojas[["Pasos por ejecucion"]], nuevas)
  }
  
  df <- as.data.frame(fila[COLS_EJECUCIONES], stringsAsFactors = FALSE)
  hojas$Ejecuciones <- .unir(ej, df)
  hojas$Cambios <- .estado_cambios(cam)
  .guardar_completa(dir_bitacoras, hojas)

  invisible(id_e)
}

# ------------------------------------------------------------------------------
# registrar_experimento(): para lo que viene DESPUÉS del preprocesamiento (TF-IDF, shallow
# linguistic, n-gramas, LDA...). Deja escrito con qué ejecución de preprocesamiento se hizo
# (por defecto, la última ejecución ok), así se puede comparar: "cambié un paso -> nueva
# ejecución E0xx -> ¿cómo cambió el TF-IDF?".
#   registrar_experimento("tfidf", parametros = "min_df=5; ngram=1", n_documentos = 8421,
#       tamano_vocabulario = 3120, resultado_principal = "top: inscripcion, horario, nota",
#       archivo_resultado = "salida/tfidf_top.csv")
# ------------------------------------------------------------------------------
registrar_experimento <- function(metodo, parametros = "", n_documentos = "", tamano_vocabulario = "",
                                  resultado_principal = "", archivo_resultado = "", notas = "",
                                  id_ejecucion = NULL, responsable = Sys.getenv("RESPONSABLE", ""),
                                  dir_bitacoras = "bitacoras") {
  hojas <- .leer_completa(dir_bitacoras)
  ej <- hojas$Ejecuciones; ex <- hojas$Experimentos
  if (is.null(id_ejecucion)) {
    oks <- ej$id_ejecucion[ej$estado == "ok"]
    id_ejecucion <- if (length(oks)) tail(oks, 1) else ""
  }
  k <- match(id_ejecucion, ej$id_ejecucion)
  fila <- data.frame(
    id_experimento = .siguiente_id("X", ex$id_experimento), fecha = format(Sys.Date()),
    hora = format(Sys.time(), "%H:%M:%S"), id_ejecucion_preprocesamiento = id_ejecucion,
    dataset = if (is.na(k)) "" else ej$archivo[k], dataset_md5 = if (is.na(k)) "" else ej$archivo_md5[k],
    metodo = metodo, parametros = parametros, n_documentos = as.character(n_documentos),
    tamano_vocabulario = as.character(tamano_vocabulario), resultado_principal = resultado_principal,
    archivo_resultado = archivo_resultado, notas = notas, responsable = responsable, stringsAsFactors = FALSE)
  hojas$Experimentos <- .unir(ex, fila)
  .guardar_completa(dir_bitacoras, hojas)

  invisible(fila)
}


