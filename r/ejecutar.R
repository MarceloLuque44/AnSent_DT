# Uso desde terminal (lo puede llamar Node, plumber o cualquier programa):
#   Rscript ejecutar.R data/result.json --inicio 2026-05-01 --fin 2026-08-31 --responsable Nombre
# Opciones: --inicio --fin --responsable --salida --config --bitacoras --umbral
#           --sin-anonimizar  --detener-emojis (parar si hay emojis nuevos)
#           --sentimientos a,b,c   --consola didactico|resumen|silencioso (por defecto: resumen)
#           --sin-bom (CSV "puro", sin marca UTF-8 para Excel)
#           --motivo "texto"  justificación para los cambios de código/diccionarios detectados
#                             (sin consola no se puede preguntar; si se omite queda FALTA JUSTIFICAR)
# La ULTIMA linea que imprime es un JSON con el resumen (estado, conteos, excluidos por motivo).
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("Uso: Rscript ejecutar.R <archivo.json|csv> [opciones]")
opt <- function(nombre, def = NULL) { i <- match(paste0("--", nombre), args); if (is.na(i)) def else args[i + 1] }
flag <- function(nombre) paste0("--", nombre) %in% args
source("cargar_proyecto.R")
res <- preprocesar(
  args[1],
  fecha_inicio = opt("inicio"), fecha_fin = opt("fin"),
  responsable = opt("responsable", Sys.getenv("RESPONSABLE", "")),
  dir_salida = opt("salida", "salida"), dir_config = opt("config", "config"),
  dir_bitacoras = opt("bitacoras", "bitacoras"),
  preguntar_cambios = FALSE, motivo_cambios = opt("motivo"),
  umbral_publicidad = as.numeric(opt("umbral", 4)),
  anonimizar_autor = !flag("sin-anonimizar"),
  nuevos_emojis = if (flag("detener-emojis")) "detener" else "marcar",
  consola = opt("consola", "resumen"),
  csv_para_excel = !flag("sin-bom"),
  sentimientos_activos = if (!is.null(opt("sentimientos"))) strsplit(opt("sentimientos"), ",")[[1]] else NULL)
cat(jsonlite::toJSON(res$resumen %||% list(estado = res$estado), auto_unbox = TRUE), "\n")
