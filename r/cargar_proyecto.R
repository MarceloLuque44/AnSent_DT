# ==============================================================================
# cargar_proyecto.R  -  Carga todas las herramientas (se ejecuta UNA vez al abrir R)
# Esto NO procesa nada: solo "saca las herramientas de la caja".
# Después se usa:   res <- preprocesar("data/result.json")
# Requiere R >= 4.2 (los archivos .R están en UTF-8 con tildes).
# ==============================================================================

#install.packages(c("ggplot2", "syuzhet", "udpipe", "topicmodels", "slam", "ggalluvial"))

paquetes <- c("jsonlite", "readr", "stringi", "openxlsx", "digest")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) stop("Instala primero: install.packages(c(",
                         paste0('"', faltan, '"', collapse = ", "), "))")
for (f in c("bitacora", "01_lectura", "02_estructura", "03_calidad", "04_publicidad",
            "05_emojis", "06_texto", "07_sentimientos", "08_salida",
            "09_periodos", "10_tfidf", "11_shallow", "12_topicos", "13_libreria",
            "14_graficos", "15_oracion", "16_analisis", "00_main"))
  source(file.path("R", paste0(f, ".R")), encoding = "UTF-8")   # C04: UTF-8 para las tildes
message("Herramientas cargadas. Ahora ejecuta:  res <- preprocesar(\"data/result.json\")")















