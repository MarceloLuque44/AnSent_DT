# Plan: Corregir errores de conexión Express ↔ R/Plumber y lectura de result.json

## Estado actual

### Problema 1 (RESUELTO): Plumber no arrancaba
Plumber ahora inicia correctamente en el puerto 8765 y responde `GET /__ping__`. Las correcciones aplicadas:
- Descomentó `library(plumber)`, `library(jsonlite)`, `library(httr)` en `r/plumber_api.R`
- Reemplazó `sys.frame(1)$ofile` por `commandArgs()` para compatibilidad con `Rscript`
- Reemplazó hook `#* @plumber` (que nunca se invocaba con `rscript`) por creación manual con `Plumber$new()` + `pr_run()`
- Agregó `tryCatch` en cada endpoint y logging de diagnóstico
- `r/graficos.R` se sourcea correctamente en `plumber_api.R`
- `r/cargar_proyecto.R` usa `PROYECTO` (ruta absoluta) en lugar de ruta relativa `"R/"`

### Problema 2 (PENDIENTE): result.json no tiene estructura de Telegram
Al ejecutar `POST /preprocesar`, Plumber carga `result.json` (26,030 filas) pero falla en `leer_telegram_json()` con:
```
No se encontró el campo 'messages'. Verifica que sea el result.json de Telegram.
```

La función `leer_telegram_json()` en `r/R/01_lectura.R` espera:
- `j$chats$list` (exportar todos los chats) o
- `j$messages` (exportar un solo chat)

El `result.json` actual no tiene ni `$chats` ni `$messages` en su estructura raíz. Su estructura real es desconocida hasta inspeccionar el archivo.

## Decisiones de diseño

1. **Inspeccionar la estructura real de `result.json`** — Determinar si es un array de mensajes, un objeto con clave diferente, o un formato completamente distinto.
2. **Adaptar `leer_telegram_json()` o crear un lector alternativo** — Si el JSON tiene una estructura distinta, modificar `01_lectura.R` para soportar ese formato, o agregar un nuevo lector que Plumber use en `cargar_dataset()`.
3. **No cambiar el contrato de la API** — Los endpoints `/__ping__`, `/dataset/summary`, `/charts`, `/preprocesar` se mantienen igual; solo cambia la lectura interna del dataset.

## Tareas pendientes

1. **Inspeccionar `r/data/result.json`** — Ver las claves raíz y la estructura de los primeros elementos para determinar el formato real.
2. **Modificar `r/R/01_lectura.R`** — Agregar soporte para la estructura real de `result.json` (o crear `leer_result_json()` alternativo) para que `cargar_dataset()` en `plumber_api.R` pueda leer los 26,030 mensajes correctamente.
3. **Probar `POST /preprocesar`** — Verificar que el preprocesamiento complete sin error y que Plumber notifique a Express vía `/api/bitacora` y `/api/events/publish`.
4. **Validar `/api/dashboard/charts`** — Confirmar que Express devuelve gráficos con `data` no vacío después de un preprocesamiento exitoso.

## Validación

- `curl http://localhost:8765/__ping__` → `{ok: true, ...}`
- `curl http://localhost:3000/api/dashboard/charts` → JSON con `data` (gráficos para ECharts)
- `curl http://localhost:3000/api/dashboard/dataset` → `{filas: 26030, columnas: N, ...}`
- `POST http://localhost:3000/api/dashboard/preprocesar` → completa sin error "No se encontró el campo 'messages'"
- Dashboard de React carga gráficos sin error 503

## Riesgos

- Si `result.json` tiene columnas distintas a las esperadas por el pipeline (texto, fecha, autor, etc.), el preprocesamiento puede fallar en etapas posteriores (lectura, estructura, sentimientos).
- El `result.json` es ~12 MB; `cargar_dataset()` lo lee entero en memoria en cada reinicio de Plumber.
- Las 48 cambios sin justificar en `bitacora_completa.xlsx` son una advertencia, no un error crítico.

## Preguntas abiertas

¿Cuál es la estructura real de `result.json`? (¿array de mensajes, objeto con clave distinta, etc.) — Esto determina cómo adaptar `01_lectura.R`.

## Archivos afectados

- `r/R/01_lectura.R` — `leer_telegram_json()` necesita soporte para la estructura real de `result.json`
- `r/plumber_api.R` — `cargar_dataset()` usa `leer_entrada()` que llama a `leer_telegram_json()`
- `r/cargar_proyecto.R` — ya corregido (usa `PROYECTO` absoluta)
- `r/graficos.R` — ya corregido (se sourcea correctamente)