# Flujo Completo de Ejecución — Análisis de Sentimientos

Este documento describe paso a paso cómo poner en marcha los tres servicios del proyecto (Express, React/Vite, R/Plumber), los archivos R involucrados y los comandos de verificación.

## Arquitectura

```
React (Vite :5173)  <── proxy /api ──  Express (Node.js :3000)  <── HTTP ───  R/Plumber (:8765)
       │                                              │                    │
       │                                              │                    │
       └──────────── SSE (GET /api/events) ───────────┘                    │
                                              │                            │
                                              └──── POST /api/bitacora ────┘
                                              └──── POST /api/events/publish ─┘
```

Puertos:
| Servicio | Puerto | Archivo de inicio |
|----------|--------|-------------------|
| React (Vite) | 5173 | `client/package.json` → `npm run dev` |
| Express | 3000 | `server/index.js` → `npm run dev` |
| R (Plumber) | 8765 | `r/plumber_api.R` → `rscript r/plumber_api.R` |

---

## 1. Paquetes R requeridos

Antes de iniciar cualquier cosa, instala los paquetes R necesarios:

```r
install.packages(c("plumber", "jsonlite", "httr", "readr", "stringi", "openxlsx", "digest"))
```

Paquetes opcionales (para el pipeline completo de R):
```r
install.packages(c("ggplot2", "ggalluvial", "udpipe", "syuzhet", "topicmodels", "slam"))
```

---

## 2. Archivos R involucrados

### `r/plumber_api.R` — API de Plumber (puerto 8765)
Punto de entrada de la API R. Expone:
- `GET /__ping__` — salud del servidor
- `GET /dataset/summary` — resumen del dataset
- `GET /charts` — definiciones JSON de gráficos (ECharts)
- `POST /preprocesar` — ejecuta el preprocesamiento del pipeline R

Carga internamente: `cargar_proyecto.R`, `00_main.R`, `graficos.R`.

### `r/cargar_proyecto.R` — Carga de herramientas
Carga los 18 scripts del pipeline R ubicados en `r/R/`:
`bitacora`, `01_lectura`, `02_estructura`, `03_calidad`, `04_publicidad`,
`05_emojis`, `06_texto`, `07_sentimientos`, `08_salida`,
`09_periodos`, `10_tfidf`, `11_shallow`, `12_topicos`, `13_libreria`,
`14_graficos`, `15_oracion`, `16_analisis`, `00_main`.

### `r/R/00_main.R` — Pipeline principal
Define `preprocesar()`: orquesta las 13 etapas del preprocesamiento
(carga de diccionarios, lectura, auditoría, estructura, calidad, publicidad,
emojis, texto, género, tokenización, sentimientos, nulos, validación, exportación).

### `r/graficos.R` — Generación de gráficos
Define `generar_graficos(df)`: produce definiciones JSON compatibles con ECharts
(distribución de sentimientos, proporción por clase, polaridad de mensajes).

### `r/ejecutar.R` — Entrada por terminal
Ejecuta `preprocesar()` desde línea de comandos con opciones de fechas, responsable, etc.

### `r/bitacora.R` — Motor de bitácoras
Gestiona `bitacora_limpia.xlsx` (última ejecución) y `bitacora_completa.xlsx` (historial).

### `r/datos/result.json` — Dataset de entrada
Archivo JSON de Telegram con los mensajes a analizar.

---

## 3. Comandos de puesta en marcha (3 terminales separadas)

### Terminal 1 — Backend Express

Desde la raíz del proyecto (`C:\CODIGO\AnSent`):

```powershell
npm install
npm run dev
```

Resultado esperado: `Servidor en http://localhost:3000`

### Terminal 2 — Frontend React/Vite

Desde la carpeta `client/`:

```powershell
cd client
npm install
npm run dev
```

Resultado esperado: `http://localhost:5173`

### Terminal 3 — R / Plumber

Desde la raíz del proyecto (`C:\CODIGO\AnSent`):

```powershell
rscript r/plumber_api.R
```

Resultado esperado: Plumber queda escuchando en `http://localhost:8765`

> **Importante:** Esta terminal debe permanecer abierta mientras se use la aplicación.

---

## 4. Verificación de conectividad

Ejecutar estas pruebas en orden:

### 4.1 Plumber responde
```powershell
curl http://localhost:8765/__ping__
```
Esperado: `{"ok":[true],"ts":"...","version":[0],"iniciado":"..."}`

### 4.2 Express detecta a Plumber
```powershell
curl http://localhost:3000/api/dashboard/status
```
Esperado: `{"plumberOnline":true,"plumberUrl":"http://localhost:8765"}`

### 4.3 Express recibe gráficos de Plumber
```powershell
curl http://localhost:3000/api/dashboard/charts
```
Esperado: JSON con arreglo `data` de gráficos (puede estar vacío si no hay datos con columnas de sentimiento).

### 4.4 Express recibe resumen del dataset
```powershell
curl http://localhost:3000/api/dashboard/dataset
```
Esperado: `{"filas":N,"columnas":N,"nombres_columnas":[...],"version":0}`

### 4.5 Frontend carga
Abrir en el navegador: `http://localhost:5173`

---

## 5. Flujo de datos completo

```
Paso 1: Usuario abre React en http://localhost:5173
        └─> Dashboard.jsx llama GET /api/dashboard/charts y GET /api/dashboard/dataset

Paso 2: Express reenvía a Plumber
        └─> GET http://localhost:8765/charts  y  GET http://localhost:8765/dataset/summary

Paso 3: Plumber responde con JSON de gráficos y resumen
        └─> Express se lo devuelve a React

Paso 4: Usuario hace clic en "Ejecutar preprocesamiento"
        └─> React llama POST /api/dashboard/preprocesar
        └─> Express llama POST http://localhost:8765/preprocesar
        └─> Plumber ejecuta preprocesar() (00_main.R): 13 etapas
        └─> Plumber notifica a Express:
              POST /api/bitacora      (registro en SQLite + SSE bitacora:update)
              POST /api/events/publish (SSE dataset:update)

Paso 5: Frontend recibe eventos SSE en tiempo real
        └─> Dashboard.jsx recarga gráficos y resumen
        └─> Bitacora.jsx recarga tabla de cambios
        └─> LiveBadge.jsx muestra ● En vivo
```

---

## 6. Solución de problemas

| Problema | Causa posible | Solución |
|----------|--------------|----------|
| `fetch failed` al contactar Plumber | Plumber no está corriendo | Ejecutar `rscript r/plumber_api.R` en terminal aparte |
| Puerto 8765 en uso | Otro proceso ocupa el puerto | `netstat -ano \| findstr :8765` y terminar el proceso |
| Gráficos vacíos | Dataset sin columnas de sentimiento | Los gráficos se poblan cuando hay datos con `sentimiento` o `polaridad_msg` |
| Plumber no inicia | Paquetes R faltantes | `install.packages(c("plumber","jsonlite","httr"))` |
| Error cargando `graficos.R` | Archivo no encontrado | Verificar que exista `r/graficos.R` |

---

## 7. Comandos de diagnóstico rápido

```powershell
# Ver si Plumber está escuchando
netstat -ano | findstr :8765

# Probar Plumber directamente
curl http://localhost:8765/__ping__

# Probar Express → Plumber
curl http://localhost:3000/api/dashboard/status

# Matar procesos Rscript colgados
Get-Process -Name "Rscript" -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## 8. Resumen de archivos R tocados

| Archivo | Ruta | Función |
|---------|------|---------|
| API Plumber | `r/plumber_api.R` | Servidor REST en puerto 8765 |
| Carga de herramientas | `r/cargar_proyecto.R` | Carga 18 scripts del pipeline |
| Pipeline principal | `r/R/00_main.R` | `preprocesar()` — 13 etapas |
| Gráficos | `r/graficos.R` | `generar_graficos(df)` — JSON para ECharts |
| Entrada terminal | `r/ejecutar.R` | Ejecuta preprocesar desde CLI |
| Bitácoras | `r/R/bitacora.R` | Gestión de bitacora_limpia/completa.xlsx |
| Lectura | `r/R/01_lectura.R` | `leer_entrada()`, `cargar_config()` |
| Salida | `r/R/08_salida.R` | Exportación de CSV/JSON |