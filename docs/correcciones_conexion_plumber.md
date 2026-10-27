# Correcciones de Conexión Express ↔ R/Plumber

## Error original

El dashboard mostraba `[rService] Error contactando Plumber (/charts): fetch failed` porque **Plumber no estaba escuchando en el puerto 8765**. Al ejecutar `rscript r/plumber_api.R`, el proceso arrancaba y finalizaba inmediatamente sin dejar el servidor activo.

## Causa raíz

El archivo `r/plumber_api.R` tenía dos problemas críticos:

1. **`library()` comentado**: Las líneas `library(plumber)`, `library(jsonlite)` y `library(httr)` estaban comentadas (líneas 6-8 del archivo original). Sin ellas, Plumber no podía cargar sus dependencias y fallaba silenciosamente.

2. **`sys.frame(1)$ofile` no funciona con Rscript**: El código usaba `SCRIPT_DIR <- dirname(normalizePath(sys.frame(1)$ofile))` para determinar la carpeta del proyecto, pero `sys.frame(1)$ofile` no está disponible al ejecutar con `Rscript`, provocando un error que detenía el script antes de llegar a `pr_run()`.

3. **`pr_run()` nunca se ejecutaba**: El hook `#* @plumber` definía `pr_run()` dentro de su cuerpo, pero `rscript` no invoca automáticamente ese hook. La función se definía pero nunca se llamaba, por lo que `pr_run()` nunca se ejecutaba y el servidor nunca quedaba escuchando.

4. **`plumber::plumber` es un R6ClassGenerator, no una función**: Al intentar usar `plumber::plumber()` para crear el objeto servidor, fallaba porque `plumber` es un generador de clases R6, no una función ejecutable.

## Archivos modificados

### `r/plumber_api.R`
- Descomentó `library(plumber)`, `library(jsonlite)`, `library(httr)`.
- Reemplazó `sys.frame(1)$ofile` por `commandArgs(trailingOnly = FALSE)` para obtener la ruta del script de forma compatible con `Rscript`.
- Agregó validación de paquetes requeridos al inicio con mensaje de error claro y `quit(status = 1)` si faltan.
- Cada `source()` envuelto en `tryCatch` que imprime el error exacto y sale si falla.
- Reemplazó el hook `#* @plumber` (que nunca se invocaba con `rscript`) por creación manual del objeto servidor con `plumber::Plumber$new()` y registro manual de endpoints con `api_obj$handle()`.
- `pr_run()` ahora se llama explícitamente sobre el objeto plumber, con `tryCatch` que imprime errores si el puerto 8765 está en uso.
- Agregó logging de diagnóstico en cada paso: paquetes cargados, carpeta del proyecto, scripts cargados, endpoints definidos, servidor iniciado.
- Endpoints protegidos con `tryCatch` para no caer si hay errores internos.

### `r/cargar_proyecto.R`
- Agregó validación de paquetes base (jsonlite, readr, stringi, openxlsx, digest) con mensaje de error claro.
- `CARPETA_R` ahora usa `PROYECTO` (ruta absoluta pasada desde `plumber_api.R`) en lugar de ruta relativa `"R/"`, que fallaba cuando se ejecutaba desde la raíz del proyecto.
- Cada `source()` envuelto en `tryCatch` con reporte del error exacto y `quit(status = 1)` si falla.

### `server/services/rService.js`
- `rFetch()` ahora distingue errores de timeout (`AbortError`) de conexión rechazada (`fetch failed`) y muestra un mensaje claro: *"Conexión rechazada — ¿Está Plumber corriendo en http://localhost:8765?"*.
- `healthCheck()` reintenta 2 veces con 1 segundo de espera entre intentos antes de rendirse.

### `server/index.js`
- Log de arranque muestra la URL configurada de Plumber y el comando para iniciarlo: `Rscript r/plumber_api.R`.

### `server/routes/dashboard.js`
- El endpoint `/status` ahora devuelve `plumberUrl` junto con `plumberOnline`.
- El error 503 de `/charts` incluye un hint con el comando exacto y la URL de Plumber: `Inicia Plumber en otra terminal: Rscript r/plumber_api.R (http://localhost:8765)`.

### `server/routes/bitacora.js`
- Agregó import de `config` para uso futuro (referencia a `config.plumberUrl`).

### `docs/estructura.md`
- Corregió la ruta de arranque de Plumber: `rscript r/plumber_api.R` (directamente en `r/`, no en `r/CONEXION/`).
- Agregó sección "Diagnóstico de conexión Plumber ↔ Express" con pasos para verificar que Plumber esté escuchando (`curl http://localhost:8765/__ping__`), cómo iniciarlo, y qué paquetes R instalar.

## Cómo iniciar los 3 servicios

```powershell
# Terminal 1: Express (desde la raíz del proyecto)
npm run dev          # http://localhost:3000

# Terminal 2: Frontend (desde client/)
cd client
npm run dev          # http://localhost:5173

# Terminal 3: R/Plumber (desde la raíz del proyecto)
rscript r/plumber_api.R   # http://localhost:8765
```

## Verificación

```powershell
# Plumber debe responder:
curl http://localhost:8765/__ping__
# -> {"ok":[true],"ts":"...","version":[0],...}

# Express debe detectar Plumber online:
curl http://localhost:3000/api/dashboard/status
# -> {"plumberOnline":true,"plumberUrl":"http://localhost:8765"}

# Dashboard debe recibir gráficos:
curl http://localhost:3000/api/dashboard/charts
# -> JSON con arreglo de gráficos para ECharts
```

## Paquetes R requeridos

```r
install.packages(c("plumber", "jsonlite", "httr", "jsonlite", "readr", "stringi", "openxlsx", "digest"))
```