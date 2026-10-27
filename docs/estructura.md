# Estructura del Proyecto — Análisis de Sentimientos

Este proyecto es una aplicación web (React + Express + SQLite) que consume gráficos JSON y eventos de un pipeline de R vía **Plumber**, con **SSE** para actualización automática.

La documentación se divide en tres partes: **server**, **cliente** y **R**.

---

## 1. Server (Node.js + Express)

Puerto: `3000` (configurado en `.env` como `PORT`)

### Arquitectura
El servidor Express actúa como API REST, persistencia SQLite de la bitácora y hub de Server-Sent Events (SSE). El frontend (Vite) hace proxy de `/api` hacia `http://localhost:3000`.

### Flujo de datos
```
R (Plumber :8765) ──POST /api/bitacora──> Express + SQLite :3000
                              │
                              └── SSE (GET /api/events) ──> React (Vite :5173)
```

### Archivos y carpetas

| Archivo / Carpeta | Descripción |
|-------------------|-------------|
| `server/index.js` | Punto de entrada. Configura CORS, JSON body parser, monta las rutas bajo `/api` y arranca Express en `config.port`. |
| `server/config.js` | Carga variables de entorno con `dotenv`. Expone `config.port` (3000), `config.plumberUrl` (http://localhost:8765) y `config.dbFile` (./server/db/analisis.db). |
| `server/routes/dashboard.js` | Rutas del dashboard: `GET /status` (estado de Plumber), `GET /charts` (gráficos JSON), `GET /dataset` (resumen del dataset), `POST /preprocesar` (dispara preprocesamiento en R). |
| `server/routes/bitacora.js` | Rutas de la bitácora: `GET /` (listar registros con filtro y límite) y `POST /` (insertar registro y publicar evento SSE `bitacora:update`). |
| `server/routes/events.js` | Rutas de eventos SSE: `GET /` (endpoint de suscripción SSE) y `POST /publish` (publicar evento general, usado por R/Plumber). |
| `server/services/rService.js` | Cliente HTTP hacia la API de Plumber (R). Métodos: `getCharts`, `getDatasetSummary`, `runPreprocesamiento`, `healthCheck`. Devuelve `null` si R no está disponible (degradación graceful). |
| `server/services/sseHub.js` | Hub de SSE. Mantiene un `Set` de clientes conectados. Funciones: `handler` (suscripción), `publish` (difusión a todos los clientes), `clientCount`. |
| `server/db/sqlite.js` | Conexión a SQLite con `node:sqlite` (`DatabaseSync`). Modo WAL. Crea el directorio si no existe y aplica el esquema inicial. |
| `server/db/schema.sql` | Esquema SQL de la tabla `bitacora_registros` y su índice por fecha. |
| `server/db/analisis.db` | Base de datos SQLite persistente (archivo binario, no versionar). |
| `server/db/analisis.db-shm` | Archivo compartido de SQLite (WAL). |
| `server/db/analisis.db-wal` | Write-Ahead Log de SQLite. |

### Endpoints de la API

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/health` | Health check del servidor Express. |
| GET | `/api/dashboard/status` | Indica si Plumber está online. |
| GET | `/api/dashboard/charts` | Devuelve la definición JSON de los gráficos (desde Plumber). |
| GET | `/api/dashboard/dataset` | Resumen del dataset actual (filas, columnas, versión). |
| POST | `/api/dashboard/preprocesar` | Dispara el preprocesamiento en R vía Plumber. |
| GET | `/api/bitacora` | Lista registros de la bitácora (`?limit=50&tipo=limpieza`). |
| POST | `/api/bitacora` | Inserta un nuevo registro y emite evento SSE `bitacora:update`. |
| GET | `/api/events` | Endpoint de suscripción SSE (text/event-stream). |
| POST | `/api/events/publish` | Publica un evento SSE a todos los clientes conectados. |

### Tecnologías
- Node.js (>=22.5)
- Express 4
- CORS
- dotenv
- node:sqlite (DatabaseSync, WAL)

---

## 2. Cliente (React + Vite)

Puerto: `5173` (configurado en `client/vite.config.js`)

### Arquitectura
Aplicación de página única (SPA) con React 18, Vite como servidor de desarrollo y bundler, y ECharts para gráficos. Navegación basada en hash (`#/dashboard`, `#/bitacora`). Consume la API de Express vía `/api` (proxy de Vite hacia `http://localhost:3000`) y recibe actualizaciones en tiempo real por SSE.

### Archivos y carpetas

| Archivo / Carpeta | Descripción |
|-------------------|-------------|
| `client/vite.config.js` | Configuración de Vite. Puerto 5173 y proxy de `/api` a `http://localhost:3000`. Plugin `@vitejs/plugin-react`. |
| `client/index.html` | Punto de entrada HTML. Monta React en `#root`, carga `src/styles.css` y `src/main.jsx`. |
| `client/package.json` | Scripts: `dev` (vite), `build` (vite build), `preview` (vite preview). Dependencias: React, React DOM, ECharts. |
| `client/src/main.jsx` | Punto de entrada de React. Renderiza `<App />` en el elemento `root`. |
| `client/src/App.jsx` | Router simple basado en hash. Renderiza `Dashboard` o `Bitacora` según `#/dashboard` o `#/bitacora`. Incluye barra superior con marca y `LiveBadge`. |
| `client/src/api.js` | Funciones `apiGet` y `apiPost` para consumir la API de Express (fetch nativo con manejo de errores). |
| `client/src/sse.jsx` | Conexión SSE compartida (un único `EventSource`). Hooks `useSse(evento, handler)` y `useSseStatus()`. |
| `client/src/LiveBadge.jsx` | Indicador visual del estado de la conexión SSE en la barra superior (● En vivo / ○ Reconectando...). |
| `client/src/styles.css` | Estilos globales. Tema oscuro con variables CSS (`--bg`, `--panel`, `--acento`, `--verde`, `--rojo`). Estilos para tarjetas, gráficos, tabla de bitácora, etiquetas y estados. |
| `client/src/components/Chart.jsx` | Componente que renderiza un gráfico ECharts a partir de una definición JSON (`def.option`). Maneja `resize` y disposición del gráfico. |
| `client/src/views/Dashboard.jsx` | Vista del dashboard. Carga gráficos y resumen del dataset desde `/api/dashboard`. Botón para ejecutar preprocesamiento. Se recarga automáticamente con eventos SSE `dataset:update` y `bitacora:update`. Muestra estado de error si R/Plumber no está disponible. |
| `client/src/views/Bitacora.jsx` | Vista de la bitácora. Lista registros con filtro por tipo. Se actualiza en vivo con eventos SSE `bitacora:update`. Tabla con fecha, tipo, descripción, filas, versión y origen. |
| `client/dist/` | Build de producción generado por `vite build`. |

### Rutas del cliente (hash)

| Ruta | Vista |
|------|-------|
| `#/dashboard` | Dashboard (gráficos + botón preprocesamiento) |
| `#/bitacora` | Bitácora de cambios del dataset |

### Tecnologías
- React 18
- Vite 5
- ECharts 5
- Fetch API (nativo)
- Server-Sent Events (EventSource)

---

## 3. R (Pipeline de Análisis + Plumber)

Puerto: `8765` (configurado en `plumber_api.R` como `pr_run(port = 8765)`)

### Arquitectura
El pipeline de R realiza preprocesamiento del dataset, genera gráficos en formato JSON (compatibles con ECharts) y expone una API REST mediante **Plumber**. Al terminar cada lote, registra el cambio en la bitácora de Express y publica un evento SSE para notificar al frontend.

### Carpeta del proyecto R

Árbol en texto plano de la estructura de carpetas y archivos bajo `r/`:

```
r/
├── R_AnSent.Rproj                    # Archivo de proyecto de RStudio
├── .Rhistory                         # Historial de comandos de R
├── cargar_proyecto.R                 # Carga todas las herramientas (source de los 17 archivos en R/ y 00_main.R). No procesa nada, solo prepara el entorno.
├── ejecutar.R                        # Script de entrada para ejecutar el preprocesamiento desde terminal (acepta archivo JSON/CSV y opciones como --inicio, --fin, --responsable, etc.). Imprime un JSON final con el resumen.
├── plumber_api.R                     # API de Plumber. Endpoints: GET /__ping__ (salud), GET /dataset/summary (resumen), GET /charts (gráficos JSON), POST /preprocesar (ejecutar preprocesamiento). Corre en puerto 8765. Envía notificaciones a Express (POST /api/bitacora y POST /api/events/publish). Reusa cargar_proyecto.R y preprocesar() de 00_main.R.
├── graficos.R                        # Función generar_graficos(df): genera definiciones JSON de gráficos compatibles con ECharts (distribución de sentimientos, proporción por clase, etc.). Reusa datos del proyecto.
├── preprocesamiento.R                # Función ejecutar_preprocesamiento(df): wrapper ligero que delega en preprocesar() de 00_main.R del proyecto. Devuelve dataset limpio, descripción y resumen estadístico.
├── config/                           # Archivos de configuración y diccionarios: abreviaturas.csv, codigos_materia.csv, emojis.csv, emoticonos.csv, genero.csv, justificaciones_analisis.csv, palabras_anuncio.csv, periodos.csv, sentimientos.json, stopwords.csv.
├── data/                             # Datos de entrada: result.json (dataset de entrada del pipeline).
├── bitacoras/                        # Bitácoras del pipeline R: bitacora_limpia.xlsx, bitacora_completa.xlsx, _copia_de_control.json.
├── modelos/                          # Modelos de NLP: spanish-gsd-ud-2.5-191206.udpipe (modelo UDpipe para español).
├── R/                                # 18 scripts R del pipeline: 00_main.R a 16_analisis.R más bitacora.R.
│   ├── 00_main.R                     # Función preprocesar(): orquesta todo el pipeline (13 etapas: carga de diccionarios, lectura, auditoría, estructura, control de calidad, publicidad, emojis, normalización de texto, género, tokenización, sentimientos, nulos, validación y exportación). Gestiona las dos bitácoras.
│   ├── 01_lectura.R                  # Lectura de datos de entrada y carga de diccionarios (cargar_config).
│   ├── 02_estructura.R               # Normalización de estructura y formatos.
│   ├── 03_calidad.R                  # Control de calidad: duplicados, valores faltantes, outliers.
│   ├── 04_publicidad.R               # Detección de publicidad y anuncios.
│   ├── 05_emojis.R                   # Procesamiento de emojis.
│   ├── 06_texto.R                    # Limpieza y normalización de texto.
│   ├── 07_sentimientos.R             # Cálculo de sentimientos con diccionario propio.
│   ├── 08_salida.R                   # Exportación de salidas (CSV, JSON): mensajes_limpios.csv, mensajes_excluidos.csv, tokens.csv, stopwords_aplicadas.csv, emojis_en_uso.csv, emojis_pendientes.csv, resumen.json.
│   ├── 09_periodos.R                 # Análisis por periodos.
│   ├── 10_tfidf.R                    # TF-IDF.
│   ├── 11_shallow.R                  # Análisis shallow linguistic.
│   ├── 12_topicos.R                  # Modelado de tópicos (LDA).
│   ├── 13_libreria.R                 # Funciones de librería y utilidades compartidas.
│   ├── 14_graficos.R                 # Gráficos con ggplot2: barras, series temporales, polar, araña, dispersión, Sankey, TF-IDF, tópicos, UPOS, nivel de mensaje, mapa de calor.
│   ├── 15_oracion.R                  # Análisis a nivel de oración.
│   ├── 16_analisis.R                 # Análisis adicional.
│   └── bitacora.R                    # Motor de las dos bitácoras (bitacora_limpia.xlsx y bitacora_completa.xlsx). Detección automática de cambios, registro de ejecuciones, pasos y experimentos.
├── salida/                           # Salidas generadas: analisis/, emojis_en_uso.csv, emojis_pendientes.csv, mensajes_excluidos.csv, mensajes_limpios.csv, resumen.json, stopwords_aplicadas.csv, tokens.csv.
│   └── analisis/                     # Gráficos generados (PNG) y tablas de análisis intermedio: barras.png, calor.png, dispersion.png, polar.png, sankey.png, tiempo.png, topicos.png, topicos_tiempo.png, upos.png, tfidf.png, apilado.png, calor.png, libreria.png, y CSVs asociados (serie_mensual.csv, stopwords_conservadas.csv, stopwords_eliminadas.csv, tfidf.csv, etc.).
```

### Scripts R principales en `R/`

| Archivo | Descripción |
|---------|-------------|
| `00_main.R` | Función `preprocesar()`: orquesta todo el pipeline (13 etapas: carga de diccionarios, lectura, auditoría, estructura, control de calidad, publicidad, emojis, normalización de texto, género, tokenización, sentimientos, nulos, validación y exportación). Gestiona las dos bitácoras. |
| `01_lectura.R` | Lectura de datos de entrada y carga de diccionarios (cargar_config). |
| `02_estructura.R` | Normalización de estructura y formatos. |
| `03_calidad.R` | Control de calidad: duplicados, valores faltantes, outliers. |
| `04_publicidad.R` | Detección de publicidad y anuncios. |
| `05_emojis.R` | Procesamiento de emojis. |
| `06_texto.R` | Limpieza y normalización de texto. |
| `07_sentimientos.R` | Cálculo de sentimientos con diccionario propio. |
| `08_salida.R` | Exportación de salidas (CSV, JSON): mensajes_limpios.csv, mensajes_excluidos.csv, tokens.csv, stopwords_aplicadas.csv, emojis_en_uso.csv, emojis_pendientes.csv, resumen.json. |
| `09_periodos.R` | Análisis por periodos. |
| `10_tfidf.R` | TF-IDF. |
| `11_shallow.R` | Análisis shallow linguistic. |
| `12_topicos.R` | Modelado de tópicos (LDA). |
| `13_libreria.R` | Funciones de librería y utilidades compartidas. |
| `14_graficos.R` | Gráficos con ggplot2: barras, series temporales, polar, araña, dispersión, Sankey, TF-IDF, tópicos, UPOS, nivel de mensaje, mapa de calor. |
| `15_oracion.R` | Análisis a nivel de oración. |
| `16_analisis.R` | Análisis adicional. |
| `bitacora.R` | Motor de las dos bitácoras (`bitacora_limpia.xlsx` y `bitacora_completa.xlsx`). Incluye detección automática de cambios, registro de ejecuciones, pasos y experimentos. |

### Scripts de conexión en `r/` (raíz del proyecto R)

| Archivo | Descripción |
|---------|-------------|
| `plumber_api.R` | API de Plumber. Endpoints: `GET /__ping__` (salud), `GET /dataset/summary` (resumen), `GET /charts` (gráficos JSON), `POST /preprocesar` (ejecutar preprocesamiento). Corre en puerto 8765. Carga `cargar_proyecto.R` y `00_main.R` del proyecto y reusa `preprocesar()`. Envía notificaciones a Express (`POST /api/bitacora` y `POST /api/events/publish`). |
| `graficos.R` | Función `generar_graficos(df)`: genera definiciones JSON de gráficos compatibles con ECharts (distribución de sentimientos, proporción por clase, etc.). |
| `preprocesamiento.R` | Función `ejecutar_preprocesamiento(df)`: wrapper ligero que delega en `preprocesar()` de `00_main.R` del proyecto. Devuelve dataset limpio, descripción y resumen estadístico. |

### Flujo de integración R → Express → Frontend

```
R (plumber_api.R :8765)
    │
    ├─ GET /charts ─────────────> Express GET /api/dashboard/charts ─────> React Dashboard (ECharts)
    │
    ├─ GET /dataset/summary ───> Express GET /api/dashboard/dataset ─────> React Dashboard
    │
    ├─ POST /preprocesar ──────> Express POST /api/dashboard/preprocesar ──> React (botón Ejecutar)
    │
    └─ POST /api/bitacora ─────> Express POST /api/bitacora ── SQLite ──> SSE bitacora:update ──> React Bitacora
         POST /api/events/publish ─────────────────────────────────────────> SSE dataset:update ─────> React Dashboard
```

### Flujo de conexión con el dashboard (paso a paso)

```
Paso 1: Levantar servicios
  └─ Express (puerto 3000)        → API REST, SQLite, hub SSE
  └─ React/Vite (puerto 5173)     → Frontend, consume /api vía proxy, recibe SSE
  └─ R/Plumber (puerto 8765)      → Pipeline de análisis, gráficos JSON, notificaciones

Paso 2: Dashboard solicita gráficos y resumen
  React (Dashboard.jsx) ──GET /api/dashboard/charts──> Express
  Express ──GET /charts────────────────────────────> Plumber (r/Plumber_api.R :8765)
  Plumber ──generar_graficos(df) (graficos.R)──────> JSON compatible con ECharts
  Plumber <──────────────────────────────────────── JSON de gráficos──── Express
  Express <──────────────────────────────────────── JSON de gráficos──── React
  React renderiza los gráficos con ECharts (Chart.jsx)

Paso 3: Dashboard solicita resumen del dataset
  React (Dashboard.jsx) ──GET /api/dashboard/dataset──> Express
  Express ──GET /dataset/summary──────────────────────> Plumber
  Plumber ──lee estado en memoria (state$dataset)─────> resumen {filas, columnas, versión}
  Plumber <────────────────────────────────────────── resumen──────── Express
  Express <────────────────────────────────────────── resumen──────── React
  React muestra el resumen en el dashboard

Paso 4: Usuario ejecuta preprocesamiento desde el dashboard
  React (botón "Ejecutar") ──POST /api/dashboard/preprocesar──> Express
  Express ──POST /preprocesar─────────────────────────────────> Plumber
  Plumber ──preprocesar() (00_main.R)───────────────────────── pipeline de 13 etapas
  Pipeline genera salidas en salida/ y bitácoras en bitacoras/
  Plumber <────────────────────────────── resultado {ok, versión, filas}──── Express
  Express <────────────────────────────── resultado──────────────────── React
  React muestra resultado del preprocesamiento

Paso 5: Plumber notifica al backend (bitácora + evento SSE)
  Plumber ──POST /api/bitacora──────────────────────────────────> Express
  Express inserta registro en SQLite (tabla bitacora_registros)
  Express publica evento SSE "bitacora:update" a todos los clientes
  Plumber ──POST /api/events/publish───────────────────────────> Express
  Express publica evento SSE "dataset:update" a todos los clientes

Paso 6: Frontend recibe actualizaciones en tiempo real (SSE)
  React se suscribe a GET /api/events (EventSource único, sse.jsx)
  └─ Evento "bitacora:update" ─────> Bitacora.jsx recarga la tabla de registros (GET /api/bitacora)
  └─ Evento "dataset:update" ──────> Dashboard.jsx recarga gráficos y resumen
  LiveBadge.jsx muestra ● En vivo o ○ Reconectando...

Paso 7: Navegación entre vistas
  #/dashboard ─────────────────────> Dashboard.jsx (gráficos + botón preprocesamiento + LiveBadge)
  #/bitacora ──────────────────────> Bitacora.jsx (tabla de registros, filtro por tipo, actualización en vivo)
```

### Paquetes R requeridos
- plumber, jsonlite, httr (para la API de conexión)
- jsonlite, readr, stringi, openxlsx, digest (para el pipeline, cargar_proyecto.R)
- ggplot2, ggalluvial (para gráficos en 14_graficos.R)
- udpipe (modelo de español en `modelos/`)
- syuzhet, topicmodels, slam (mencionados en cargar_proyecto.R como opcionales)
### Comandos para iniciar R/Plumber

```powershell
# Desde la carpeta raíz del proyecto (C:\CODIGO\AnSent)
rscript r/plumber_api.R  # http://localhost:8765

# O, desde la carpeta r/
cd r
rscript plumber_api.R  # http://localhost:8765
```

### Diagnóstico de conexión Plumber ↔ Express

Si el dashboard muestra "R/Plumber no disponible" o `fetch failed`:

1. **Verificar que Plumber esté escuchando en el puerto 8765:**
   ```powershell
   curl http://localhost:8765/__ping__
   ```
   Debe devolver algo como `{ "ok": true, "ts": "...", "version": 0, ... }`.
   Si dice `Couldn't connect to server`, Plumber no está corriendo.

2. **Iniciar Plumber (en una terminal aparte):**
   ```powershell
   rscript r/plumber_api.R
   ```
   Deberías ver mensajes como:
   ```
   [Plumber] Paquetes R cargados: plumber, jsonlite, httr
   [Plumber] Carpeta del proyecto R: C:\CODIGO\AnSent\r
   [Plumber] cargar_proyecto.R cargado correctamente
   [Plumber] 00_main.R cargado correctamente. Funcion preprocesar() disponible
   [Plumber] API definida. Puerto: 8765
   [Plumber] Esperando conexiones...
   ```

3. **Verificar que Express pueda alcanzar a Plumber:**
   ```powershell
   curl http://localhost:3000/api/dashboard/status
   ```
   Debe devolver `{ "plumberOnline": true, "plumberUrl": "http://localhost:8765" }`.

4. **Paquetes R requeridos:** si Plumber falla al iniciar, verifica que estén instalados:
   ```r
   install.packages(c("plumber", "jsonlite", "httr", "jsonlite", "readr", "stringi", "openxlsx", "digest"))
   ```


### Flujo de trabajo con todos los archivos R

1. **Preparar el entorno** — Ejecutar `cargar_proyecto.R` (una sola vez al abrir R) para cargar los 17 scripts en `R/` más `00_main.R`. Esto no procesa datos, solo deja disponibles las funciones del pipeline.

2. **Ejecutar el preprocesamiento** — Llamar a `preprocesar("data/result.json")` desde R, o usar `ejecutar.R` desde terminal:
   ```
   Rscript ejecutar.R data/result.json --inicio 2026-05-01 --fin 2026-08-31 --responsable Nombre
   ```
   Esto recorre las 13 etapas del pipeline (lectura, auditoría, estructura, calidad, publicidad, emojis, texto, género, tokenización, sentimientos, nulos, validación, exportación) y genera las salidas en `salida/` y las bitácoras en `bitacoras/`.

3. **Revisar salidas** — Consultar `salida/mensajes_limpios.csv`, `salida/resumen.json`, `salida/tokens.csv`, `salida/emojis_en_uso.csv`, y las bitácoras `bitacoras/bitacora_limpia.xlsx` (última ejecución exitosa) y `bitacoras/bitacora_completa.xlsx` (historial completo de cambios, ejecuciones, pasos y experimentos).

4. **Levantar la API Plumber** — Ejecutar `plumber_api.R` en el puerto 8765. Esto carga `cargar_proyecto.R` y `00_main.R` del proyecto y reusa `preprocesar()`. Expone:
   - `GET /__ping__` — health check
   - `GET /dataset/summary` — resumen del dataset
   - `GET /charts` — definiciones JSON de gráficos para ECharts
   - `POST /preprocesar` — ejecuta el preprocesamiento del proyecto y notifica a Express

5. **Notificar al backend** — Al terminar un preprocesamiento, Plumber envía `POST /api/bitacora` (registro en SQLite + evento SSE `bitacora:update`) y `POST /api/events/publish` (evento `dataset:update`) a Express en el puerto 3000.

6. **Consumir desde el frontend** — El dashboard de React (Vite :5173) lee `/api/dashboard/charts` y `/api/dashboard/dataset` a través de Express, y recibe actualizaciones en tiempo real por SSE en `/api/events`. La vista de bitácora muestra los registros de `GET /api/bitacora` y se actualiza con eventos `bitacora:update`.

---

## Resumen de puertos

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| React (Vite) | 5173 | Frontend, servidor de desarrollo |
| Express | 3000 | Backend API, SQLite, hub SSE |
| R (Plumber) | 8765 | Pipeline de análisis y gráficos JSON |

## Comandos de puesta en marcha

```powershell
# 1) Backend Express (desde la raíz del proyecto)
npm install
npm run dev          # http://localhost:3000

# 2) Frontend Vite (desde client/)
cd client
npm install
npm run dev          # http://localhost:5173

# 3) R / Plumber (desde la carpeta raíz del proyecto)
rscript r/plumber_api.R  # http://localhost:8765
```
