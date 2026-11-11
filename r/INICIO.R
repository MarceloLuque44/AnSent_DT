source("cargar_proyecto.R")              # carga todas las herramientas (una vez)

# --- Paso 1: Preprocesamiento (solo local, sin API) ---
res <- preprocesar("data/result.json", dir_salida = "salida")
datos <- cargar_datos_analisis("salida")

# --- Paso 2: Analisis por periodo ---
a <- analizar_periodo(datos, "2022-01-02", "2026-03-31")
cmp <- comparar_periodos(datos, "2023-01-01", "2024-03-31", "2024-01-01", "2025-03-31")
men <- a$mensajes;
str(men)
# --- Paso 3: Guardar analisis localmente (CSV/PNG, sin API) ---
guardar_analisis(a, dir = "salida/analisis", enviar_api = FALSE)
guardar_analisis(cmp, dir = "salida/analisis", enviar_api = FALSE)

# --- Paso 4: Enviar todo a la API (una sola llamada centralizada) ---
source("Peticiones.R")
enviar_flujo_completo_api(a = a, cmp = cmp, responsable = Sys.getenv("RESPONSABLE", "R local"))

# --- Paso 5 (opcional): prueba de conexión ---
# probar_conexion_api()
