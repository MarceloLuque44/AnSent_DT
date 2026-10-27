# ==============================================================================
# cargar_proyecto.R  -  Carga todas las herramientas (se ejecuta UNA vez al abrir R)
# Esto NO procesa nada: solo "saca las herramientas de la caja".
# Después se usa:   res <- preprocesar("data/result.json")
# Requiere R >= 4.2 (los archivos .R están en UTF-8 con tildes).
# ==============================================================================

#install.packages(c("ggplot2", "syuzhet", "udpipe", "topicmodels", "slam", "ggalluvial"))

paquetes <- c("jsonlite", "readr", "stringi", "openxlsx", "digest")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) {
  cat("\n====================================================================\n")
  cat("ERROR: Faltan paquetes R requeridos para el pipeline:\n")
  cat("  ", paste(faltan, collapse = ", "), "\n")
  cat("Instalalos con:\n")
  cat("  install.packages(c(", paste0('"', faltan, '"', collapse = ", "), "))\n")
  cat("====================================================================\n\n")
  quit(status = 1)
}
cat("[cargar_proyecto] Paquetes base cargados: jsonlite, readr, stringi, openxlsx, digest\n")

# Usar la ubicación de este script como referencia (funciona con Rscript).
args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  script_path <- sub("^--file=", "", file_arg)
  SCRIPT_DIR <- dirname(normalizePath(script_path, winslash = "/"))
} else {
  # Fallback: usar el directorio de trabajo actual
  SCRIPT_DIR <- normalizePath(getwd(), winslash = "/")
}
PROYECTO <- SCRIPT_DIR

# Determinar la carpeta R/ relativa a este archivo (funciona tanto si se sourcea
# desde la raíz del proyecto como desde r/)
CARPETA_R <- file.path(PROYECTO, "R")

scripts <- c("bitacora", "01_lectura", "02_estructura", "03_calidad", "04_publicidad",
             "05_emojis", "06_texto", "07_sentimientos", "08_salida",
             "09_periodos", "10_tfidf", "11_shallow", "12_topicos", "13_libreria",
             "14_graficos", "15_oracion", "16_analisis", "00_main")

for (f in scripts) {
  ruta <- file.path(CARPETA_R, paste0(f, ".R"))
  cat("[cargar_proyecto] Cargando:", ruta, "\n")
  tryCatch(
    source(ruta, encoding = "UTF-8"),
    error = function(e) {
      cat("\n====================================================================\n")
      cat("ERROR al cargar", ruta, ":\n")
      cat("  ", conditionMessage(e), "\n")
      cat("====================================================================\n\n")
      quit(status = 1)
    }
  )
}

cat("[cargar_proyecto] Todos los scripts cargados correctamente (", length(scripts), " archivos)\n")
cat("[cargar_proyecto] Ahora ejecuta:  res <- preprocesar(\"data/result.json\")\n")
