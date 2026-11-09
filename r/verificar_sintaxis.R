# Verifica que todos los scripts R del proyecto se puedan parsear.
# Uso: Rscript r/verificar_sintaxis.R
# Pensado para detectar errores de sintaxis (por ejemplo, comas finales en
# llamadas a list()/c(), que en R se interpretan como argumentos vacios).

args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
base_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[1]))) else getwd()
root <- normalizePath(file.path(base_dir, ".."), mustWork = FALSE)

files <- list.files(root, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
files <- files[!grepl("[/\\\\]renv[/\\\\]|[/\\\\]packrat[/\\\\]", files)]

errores <- character(0)
for (f in files) {
  res <- tryCatch(
    {
      parse(f)
      "ok"
    },
    error = function(e) conditionMessage(e)
  )
  if (!identical(res, "ok")) {
    errores <- c(errores, sprintf("%s: %s", f, res))
  }
}

if (length(errores)) {
  cat(paste(errores, collapse = "\n"), "\n", sep = "")
  quit(status = 1)
}

cat(sprintf("Sintaxis OK: %d archivos R\n", length(files)))
