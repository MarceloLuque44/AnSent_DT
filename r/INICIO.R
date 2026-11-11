source("cargar_proyecto.R")              # carga todas las herramientas (una vez)
res <- preprocesar("data/result.json", dir_salida = "salida")  # sin filtro de fecha: todos los datos
datos <- cargar_datos_analisis("salida") # carga mensajes_limpios.csv y tokens.csv
migrar_bitacora()
datos <- cargar_datos_analisis("salida")

a <- analizar_periodo(datos, "2022-01-02", "2026-03-31")   
# cmp <- comparar_periodos(datos, "todo_2023", "todo_2024") 
cmp <- comparar_periodos(datos, "2023-01-01", "2024-03-31","2024-01-01", "2025-03-31")

source("Peticiones.R")              # carga todas las herramientas (una vez)
# enviar_niveles_api(a)
# enviar_graficos_api(a)
# enviar_graficos_adicionales_api(a)
#a$nivel; a$tfidf; a$topicos$terminos; a$shallow$upos; a$libreria
#p <- graficos_periodo(a);  
#p$barras;  p$tiempo;  p$polar



#cmp$interpretacion;  graficos_comparacion(cmp)$arana

#guardar_analisis(a)   # deja CSV/PNG en salida/analisis/<periodo>/ (para el dashboard)



  # source("cargar_proyecto.R")
  # source("Migraciones.R")
  # migrar_diccionarios(dir_config = "config")

