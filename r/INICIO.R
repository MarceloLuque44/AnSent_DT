source("cargar_proyecto.R")              # carga todas las herramientas (una vez)
source("Peticiones.R")              # carga todas las herramientas (una vez)
#res   <- preprocesar("data/result.json","") # UNA vez, con todo el dataset
res <- preprocesar(
  "data/result.json",
  dir_salida   = "salida",
  fecha_inicio = "2026-05-01",
  fecha_fin    = "2026-08-31"
)
datos <- cargar_datos_analisis("salida") # carga mensajes_limpios.csv y tokens.csv

a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))   # un periodo
#a$nivel; a$tfidf; a$topicos$terminos; a$shallow$upos; a$libreria
#p <- graficos_periodo(a);  p$barras;  p$tiempo;  p$polar

cmp <- comparar_periodos(datos, "todo_2023", "todo_2024")      # A contra B
#cmp$interpretacion;  graficos_comparacion(cmp)$arana

#guardar_analisis(a)   # deja CSV/PNG en salida/analisis/<periodo>/ (para el dashboard)

