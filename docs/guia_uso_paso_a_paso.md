# Guía de uso paso a paso — módulo R de AnSent

Esta guía explica cómo usar el proyecto **AnSent** (análisis de sentimientos sobre un chat de Telegram) partiendo de la carpeta `r/`. Cubre desde la instalación hasta el preprocesamiento, el análisis por periodos, la API de Plumber y el dashboard web.

> Todos los comandos de terminal se muestran para **PowerShell en Windows** y se ejecutan, salvo que se indique lo contrario, desde la carpeta `r/` (`C:\CODIGO\AnSent\r`).

---

## Índice

1. [Qué hace el módulo R](#1-qué-hace-el-módulo-r)
2. [Requisitos e instalación](#2-requisitos-e-instalación)
3. [Mapa de archivos y carpetas](#3-mapa-de-archivos-y-carpetas)
4. [Paso 1 — Preparar los datos de entrada](#paso-1--preparar-los-datos-de-entrada)
5. [Paso 2 — Revisar la configuración y los diccionarios](#paso-2--revisar-la-configuración-y-los-diccionarios)
6. [Paso 3 — Ejecutar el preprocesamiento](#paso-3--ejecutar-el-preprocesamiento)
7. [Paso 4 — Revisar las salidas y las bitácoras](#paso-4--revisar-las-salidas-y-las-bitácoras)
8. [Paso 5 — Análisis por periodos (Parte 2)](#paso-5--análisis-por-periodos-parte-2)
9. [Paso 6 — Gráficos con `18_top25.R`](#paso-6--gráficos-con-18_top25r)
10. [Paso 7 — Usar la API de Plumber](#paso-7--usar-la-api-de-plumber)
11. [Paso 8 — Usar el dashboard web](#paso-8--usar-el-dashboard-web)
12. [Paso 9 — Flujo de cambios y emojis pendientes](#paso-9--flujo-de-cambios-y-emojis-pendientes)
13. [Solución de problemas](#solución-de-problemas)
14. [Referencia rápida de comandos](#referencia-rápida-de-comandos)

---

## 1. Qué hace el módulo R

El módulo R tiene tres capas:

| Capa | Archivo(s) | Función |
|------|-----------|---------|
| **Pipeline de limpieza** | `R/00_main.R` → `preprocesar()` | Orquesta 13 etapas: diccionarios, lectura, auditoría, estructura, calidad, publicidad, emojis, texto, género, tokenización, sentimientos, nulos, validación y exportación. |
| **Análisis posterior** | `R/09_periodos.R`, `10_tfidf.R`, `11_shallow.R`, `12_topicos.R`, `13_libreria.R`, `14_graficos.R`, `15_oracion.R`, `16_analisis.R`, `18_top25.R` | Análisis por periodo, comparación de periodos, TF-IDF, LDA, lingüística superficial, gráficos y análisis de una oración. |
| **Exposición de servicios** | `cargar_proyecto.R`, `ejecutar.R`, `plumber_api.R`, `graficos.R` | Carga de utilidades, ejecución por terminal, API REST en el puerto 8765 y gráficos JSON para ECharts. |

Además, `R/bitacora.R` mantiene la trazabilidad completa en dos archivos Excel.

### Flujo general

```
result.json (Telegram)  ──>  preprocesar()  ──>  salida/*.csv + resumen.json
                                     │
                                     └──>  bitacoras/*.xlsx

salida/mensajes_limpios.csv + tokens.csv
        │
        ├──> cargar_datos_analisis() ──> analizar_periodo() / comparar_periodos()
        │                                       │
        │                                       └──> salida/analisis/<periodo>/*.csv,*.png
        │
        └──> fuente de datos de Plumber (:8765) ──> Express (:3000) ──> React (:5173)
```

---

## 2. Requisitos e instalación

### 2.1 Software

| Software | Versión mínima | Para qué |
|----------|----------------|----------|
| R | 4.2 (los `.R` están en UTF-8 con tildes) | Pipeline y API Plumber |
| RStudio | Opcional, recomendado | Ejecución interactiva |
| Node.js + npm | 22.5 | Backend Express y frontend Vite |
| Navegador moderno | — | Dashboard |

Verifica:

```powershell
Rscript --version
node --version
npm --version
```

### 2.2 Paquetes R

Instala todos los paquetes en una sola sesión de R:

```r
install.packages(c(
  # Núcleo del pipeline (obligatorios para cargar_proyecto.R)
  "jsonlite", "readr", "stringi", "openxlsx", "digest",
  # API Plumber (obligatorios para plumber_api.R)
  "plumber", "httr", "readxl",
  # Análisis y gráficos (opcionales, pero necesarios para la Parte 2)
  "ggplot2", "ggalluvial", "udpipe", "syuzhet",
  "topicmodels", "slam"
))
```

Comprobación rápida:

```powershell
Rscript -e "for (p in c('jsonlite','readr','stringi','openxlsx','digest','plumber','httr','readxl')) cat(p, requireNamespace(p, quietly=TRUE), '\n')"
```

### 2.3 Modelo de español para udpipe

El análisis *shallow* usa `modelos/spanish-gsd-ud-2.5-191206.udpipe`. Si el archivo no existe, `shallow_linguistic()` intenta descargarlo automáticamente la primera vez (requiere internet). Para trabajar sin conexión, coloca el `.udpipe` en `r/modelos/`.

---

## 3. Mapa de archivos y carpetas

```
r/
├── R_AnSent.Rproj                  # Proyecto de RStudio
├── cargar_proyecto.R               # Carga los 18 scripts de R/ (no procesa datos)
├── ejecutar.R                      # Entrada por terminal (CLI)
├── plumber_api.R                   # API REST en el puerto 8765
├── graficos.R                      # generar_graficos(df): JSON compatible con ECharts
├── preprocesamiento.R              # Wrapper ejecutar_preprocesamiento(df)
├── R/
│   ├── 00_main.R                   # preprocesar(): orquestador de 13 etapas
│   ├── 01_lectura.R                # leer_entrada(), cargar_config(), auditar_entrada()
│   ├── 02_estructura.R             # Normalización, fechas, anonimización, variables derivadas
│   ├── 03_calidad.R                # Duplicados, faltantes, outliers
│   ├── 04_publicidad.R             # Detección de anuncios
│   ├── 05_emojis.R                 # Emojis, emoticonos y reacciones
│   ├── 06_texto.R                  # Limpieza, género, tokenización, stopwords
│   ├── 07_sentimientos.R           # Diccionario propio (15 sentimientos)
│   ├── 08_salida.R                 # Nulos, validación y exportación
│   ├── 09_periodos.R               # Periodos, series, niveles
│   ├── 10_tfidf.R                  # TF-IDF
│   ├── 11_shallow.R                # udpipe (UPOS, lemas, frases nominales)
│   ├── 12_topicos.R                # LDA
│   ├── 13_libreria.R               # syuzhet / NRC
│   ├── 14_graficos.R               # Gráficos ggplot2
│   ├── 15_oracion.R                # analizar_oracion()
│   ├── 16_analisis.R               # analizar_periodo(), comparar_periodos(), guardar_analisis()
│   ├── 18_top25.R                  # ver_top25(): 25 gráficos (se carga aparte)
│   └── bitacora.R                  # Motor de las dos bitácoras
├── config/                         # Diccionarios y configuración (CSV + sentimientos.json)
├── data/result.json                # Dataset de entrada
├── modelos/                        # Modelo udpipe de español
├── salida/                         # Resultados del preprocesamiento y análisis
└── bitacoras/                      # bitacora_limpia.xlsx, bitacora_completa.xlsx, control
```

> `cargar_proyecto.R` carga 18 scripts: `bitacora`, `01_lectura` … `16_analisis` y `00_main`. **No carga `18_top25.R`**; ese se carga explícitamente cuando se necesita.

---

## Paso 1 — Preparar los datos de entrada

### 1.1 Exportación de Telegram (recomendado)

1. En Telegram, abre el chat → menú → **Exportar historial del chat**.
2. Elige formato **JSON** y descarga el archivo.
3. Renómbralo a `result.json` y colócalo en:

```
C:\CODIGO\AnSent\r\data\result.json
```

El lector espera la estructura típica de Telegram (`chats.list[].messages` o `messages`). Para cada mensaje extrae: `id`, tipo, fecha, autor, respuestas, reenvíos, texto, sticker, reacciones y acciones de servicio.

### 1.2 Exportación con varios chats

Si el JSON contiene varios chats, `preprocesar()` se detiene y lista los chats disponibles. Indica el número con el parámetro `chat`:

```r
res <- preprocesar("data/result.json", chat = 2)
```

Desde Plumber, el endpoint `/paso/preprocesar` usa siempre `data/result.json` y no expone `chat`; para elegir chat, ejecuta desde R o CLI.

### 1.3 Alternativa: CSV/TSV

También se acepta un CSV o TSV. Debe tener al menos:

- una columna de **texto**: `text`, `texto`, `mensaje`, `message` o `texto_original`;
- una columna de **fecha**: `date`, `fecha`, `datetime` o `fecha_hora`.

Columnas opcionales: `id`, `autor`/`from`, `usuario`, `from_id`, `reply_to_message_id`, `forwarded_from`, `reacciones`. El separador se detecta por la extensión (`.tsv` = tabulador, `.csv` = coma).

---

## Paso 2 — Revisar la configuración y los diccionarios

Todo se edita en `r/config/`, nunca en el código:

| Archivo | Contenido |
|---------|-----------|
| `sentimientos.json` | 15 sentimientos con `nombre`, `polaridad`, `activo`, `definicion`, `palabras` y `raices`. |
| `emojis.csv` | Diccionario maestro de emojis (significado, sentimiento, polaridad, unicode). |
| `emoticonos.csv` | Emoticonos de texto → emoji. |
| `stopwords.csv` | Stopwords con acción (`eliminar`/`conservar`) y justificación. |
| `palabras_anuncio.csv` | Reglas de detección de publicidad (tipo, patrón, peso, parámetro). |
| `genero.csv` | Palabras de referencia femenina/masculina. |
| `abreviaturas.csv` | Abreviaturas de chat → forma normal. |
| `codigos_materia.csv` | Prefijos válidos de códigos de materia. |
| `periodos.csv` | Periodos predefinidos (nombre, inicio, fin). |
| `justificaciones_analisis.csv` | Justificación teórica de cada análisis. |

### Activar o desactivar sentimientos

Edita `activo` en `sentimientos.json`:

```json
{
  "orden": 3,
  "nombre": "enojo",
  "polaridad": -1,
  "activo": true,
  "definicion": "...",
  "palabras": ["..."],
  "raices": ["..."]
}
```

`preprocesar()` genera columnas `sent_<nombre>` y `pct_<nombre>` solo para los sentimientos activos. También puedes limitar la ejecución con `sentimientos_activos = c("alegria", "gratitud")`.

> Los cambios en `config/` y en los `.R` se detectan automáticamente y se registran en la bitácora (ver [Paso 9](#paso-9--flujo-de-cambios-y-emojis-pendientes)).

---

## Paso 3 — Ejecutar el preprocesamiento

Elige **una** de las tres formas según tu necesidad.

### Opción A — RStudio / consola interactiva (recomendada para explorar)

1. Abre `r/R_AnSent.Rproj` en RStudio (o abre una terminal en `r/`).
2. Carga las herramientas **una sola vez**:

```r
setwd("C:/CODIGO/AnSent/r")
source("cargar_proyecto.R")
```

3. Ejecuta el pipeline:

```r
res <- preprocesar(
  "data/result.json",
  dir_salida    = "salida",      # ver nota importante abajo
  consola       = "didactico",   # "didactico" | "resumen" | "silencioso"
  responsable   = "Tu nombre"
)
```

4. Revisa el resultado:

```r
res$estado          # "ok"
res$resumen         # conteos clave
head(res$datos)     # dataset limpio en memoria
res$excluidos       # mensajes descartados con su motivo
```

> **Nota importante:** el valor por defecto de `dir_salida` en `00_main.R` es `client/src/views/salida`, pensado para el frontend. Si quieres las salidas en `r/salida/` (lo que esperan `cargar_datos_analisis("salida")`, el CLI y Plumber), **pasa siempre `dir_salida = "salida"`**.

#### Con recorte de fechas

```r
res <- preprocesar(
  "data/result.json",
  dir_salida   = "salida",
  fecha_inicio = "2026-05-01",
  fecha_fin    = "2026-08-31",
  consola      = "resumen"
)
```

#### Parámetros principales de `preprocesar()`

| Parámetro | Por defecto | Descripción |
|-----------|-------------|-------------|
| `ruta_archivo` | — | Ruta al JSON/CSV de entrada. |
| `fecha_inicio`, `fecha_fin` | `NULL` | Recorte opcional por fechas (`YYYY-MM-DD`). |
| `responsable` | `Sys.getenv("RESPONSABLE", "")` | Nombre que queda en la bitácora. |
| `dir_config` | `"config"` | Diccionarios. |
| `dir_salida` | `client/src/views/salida` | Carpeta de salidas. **Pasa `"salida"` para el flujo R.** |
| `dir_bitacoras` | `"bitacoras"` | Carpeta de bitácoras. |
| `sentimientos_activos` | `NULL` | `NULL` = todos los activos; o un vector de nombres. |
| `excluir_publicidad` | `TRUE` | Activa la Etapa 6. |
| `umbral_publicidad` | `4` | Puntaje mínimo para marcar publicidad. |
| `anonimizar_autor` | `TRUE` | Sustituye el autor por un hash MD5. |
| `min_chars_duplicado` | `25` | Longitud mínima para considerar duplicado. |
| `nuevos_emojis` | `"marcar"` | `"marcar"` registra pendientes; `"detener"` aborta. |
| `consola` | `"didactico"` | Nivel de detalle en consola. |
| `csv_para_excel` | `TRUE` | Añade BOM para que Excel lea tildes/emojis. |
| `preguntar_cambios` | `interactive()` | Pregunta justificaciones si hay cambios de código/diccionarios. |
| `motivo_cambios` | `NULL` | Justificación única para modo no interactivo. |
| `chat` | `NULL` | Número de chat cuando el JSON tiene varios. |

### Opción B — Terminal (CLI) con `ejecutar.R`

Útil para automatizar o llamar desde Node/Plumber. **Ejecuta desde `r/`**, porque `ejecutar.R` hace `source("cargar_proyecto.R")`.

```powershell
cd C:\CODIGO\AnSent\r
Rscript ejecutar.R data/result.json --consola resumen --responsable "Tu nombre"
```

Ejemplo completo:

```powershell
Rscript ejecutar.R data/result.json `
  --inicio 2026-05-01 `
  --fin 2026-08-31 `
  --responsable "Tu nombre" `
  --umbral 4 `
  --consola resumen `
  --motivo "Actualización mensual del dataset"
```

Opciones disponibles:

| Opción | Efecto |
|--------|--------|
| `--inicio YYYY-MM-DD` | Fecha inicial. |
| `--fin YYYY-MM-DD` | Fecha final. |
| `--responsable "Nombre"` | Responsable en bitácora. |
| `--salida RUTA` | Carpeta de salida (por defecto `salida`). |
| `--config RUTA` | Carpeta de configuración (por defecto `config`). |
| `--bitacoras RUTA` | Carpeta de bitácoras (por defecto `bitacoras`). |
| `--umbral N` | Umbral de publicidad. |
| `--sin-anonimizar` | Conserva el autor original. |
| `--detener-emojis` | Aborta si hay emojis nuevos sin traducir. |
| `--sentimientos a,b,c` | Solo esos sentimientos. |
| `--consola didactico\|resumen\|silencioso` | Detalle en consola. |
| `--sin-bom` | CSV sin BOM (UTF-8 puro). |
| `--motivo "texto"` | Justificación de cambios detectados. |

La **última línea** de la salida es un JSON con el resumen:

```json
{"estado":"ok","archivo":"result.json","registros_leidos":1500,"mensajes_limpios":1320,...}
```

### Opción C — API de Plumber

```powershell
# Desde la raíz del proyecto
Rscript r/plumber_api.R
```

La API queda en `http://localhost:8765`. Dispara el preprocesamiento:

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8765/paso/preprocesar `
  -ContentType "application/json" `
  -Body '{"fecha_inicio":"2026-05-01","fecha_fin":"2026-08-31","responsable":"Tu nombre"}'
```

Cuerpo admitido (todos opcionales):

```json
{
  "fecha_inicio": "2026-05-01",
  "fecha_fin": "2026-08-31",
  "responsable": "Tu nombre",
  "sentimientos_activos": ["alegria", "gratitud"],
  "excluir_publicidad": true,
  "umbral_publicidad": 4,
  "anonimizar_autor": true,
  "min_chars_duplicado": 25,
  "nuevos_emojis": "marcar",
  "consola": "silencioso",
  "csv_para_excel": false,
  "preguntar_cambios": false,
  "motivo_cambios": "Ejecución desde el dashboard"
}
```

Plumber siempre lee `r/data/result.json`, escribe en `r/salida/` y registra en `r/bitacoras/`.

---

## Paso 4 — Revisar las salidas y las bitácoras

### 4.1 Archivos en `r/salida/`

| Archivo | Contenido |
|---------|-----------|
| `mensajes_limpios.csv` | Dataset final: **1 fila = 1 mensaje** listo para graficar. Incluye `texto_limpio`, `texto_tokens`, `n_tokens`, `sent_*`, `pct_*`, `polaridad_score`, `polaridad_msg`, `sentimiento_dominante`, variables temporales (`anio_mes`, `dia_semana`, `hora`), reacciones y emojis. |
| `mensajes_excluidos.csv` | Todo lo descartado con `motivo_exclusion` (vacíos, duplicados, publicidad, etc.). Nada se pierde. |
| `tokens.csv` | 1 fila = 1 token, con documento/fecha/mes. Base para TF-IDF, n-gramas y LDA. |
| `stopwords_aplicadas.csv` | Stopword, acción (`eliminar`/`conservar`) y justificación. |
| `emojis_en_uso.csv` | Frecuencia de emojis en texto y reacciones. |
| `emojis_pendientes.csv` | Emojis sin traducir (vacío si todo está en el diccionario). |
| `resumen.json` | Conteos: `estado`, `registros_leidos`, `mensajes_limpios`, `mensajes_excluidos`, `excluidos_por_motivo`, `rango_fechas`, `sentimientos_activos`, `polaridad`, `emojis_pendientes`, `pasos_bitacora`. |
| `analisis/` | Resultados de la Parte 2 (CSV, PNG, `interpretacion.txt`). |
| `top25/` | PNG de `ver_top25()`. |

### 4.2 Bitácoras en `r/bitacoras/`

| Archivo | Contenido |
|---------|-----------|
| `bitacora_limpia.xlsx` | Pasos de la **última ejecución exitosa**. Hojas: `Bitacora` y `Parametros`. Se sobrescribe. **No se toca si la ejecución falla o se detiene.** |
| `bitacora_completa.xlsx` | Historial acumulativo. Hojas: `Cambios`, `Ejecuciones`, `Pasos por ejecucion`, `Experimentos`. Solo agrega filas. |
| `_copia_de_control.json` | “Foto” del contenido de los archivos vigilados (`R/*.R`, `cargar_proyecto.R`, `ejecutar.R`, `config/*.csv`, `config/*.json`) para detectar cambios. |

### 4.3 Comprobaciones rápidas

```r
# Desde R, tras preprocesar
res$resumen$registros_leidos
res$resumen$mensajes_limpios
res$resumen$mensajes_excluidos
res$resumen$excluidos_por_motivo
table(res$datos$polaridad_msg)
table(res$datos$sentimiento_dominante)
```

```powershell
# Desde PowerShell
Get-Content .\salida\resumen.json
Import-Csv .\salida\mensajes_limpios.csv | Measure-Object
```

> Si abres los `.xlsx` en Excel, **ciérralos** antes de volver a ejecutar: `openxlsx` no puede escribir sobre un archivo bloqueado.

---

## Paso 5 — Análisis por periodos (Parte 2)

Estos pasos usan las salidas del Paso 3. Ejecuta desde `r/` (las rutas son relativas).

### 5.1 Cargar los datos limpios

```r
source("cargar_proyecto.R")          # si no está cargado ya
datos <- cargar_datos_analisis("salida")
```

`datos` contiene al menos `mensajes` y `tokens`.

### 5.2 Analizar un periodo por fechas

```r
a <- analizar_periodo(
  datos,
  fecha_inicio = "2026-05-01",
  fecha_fin    = "2026-08-31",
  k            = 6,        # número de tópicos LDA
  agrupar      = "dia",    # "dia" | "mes" para LDA
  shallow      = TRUE,     # udpipe
  libreria     = TRUE      # syuzhet/NRC
)

print(a$nivel)            # nivel de cada sentimiento
print(a$serie)            # serie mensual
print(a$interpretacion)   # interpretación automática
```

### 5.3 Analizar un periodo predefinido

Los periodos se definen en `config/periodos.csv`:

```r
a <- analizar_periodo(datos, periodo = "todo_2023")
```

> También se acepta la forma `analizar_periodo(datos, c("2026-05-01", "2026-08-31"))` que aparece en algunos ejemplos antiguos; la forma con argumentos nombrados es la más explícita.

### 5.4 Comparar dos periodos

```r
cmp <- comparar_periodos(
  datos,
  fecha_inicio_a = "2025-01-01", fecha_fin_a = "2025-03-31",
  fecha_inicio_b = "2026-01-01", fecha_fin_b = "2026-03-31"
)

print(cmp$niveles)
print(cmp$interpretacion)
```

O con periodos nombrados:

```r
cmp <- comparar_periodos(datos, periodoA = "periodo_a", periodoB = "periodo_b")
```

### 5.5 Guardar los resultados

```r
guardar_analisis(a, dir = "salida/analisis")     # CSV + PNG + interpretacion.txt
guardar_analisis(cmp, dir = "salida/analisis")
```

Cada análisis crea una subcarpeta `salida/analisis/<periodo>/` con:

- `niveles.csv`, `serie_mensual.csv`, `tfidf.csv`
- `libreria_niveles.csv` (si `libreria = TRUE`)
- `topicos_terminos.csv`, `topicos_por_mes.csv` (si LDA tuvo éxito)
- `shallow_categorias.csv`, `shallow_lemas.csv` (si `shallow = TRUE`)
- `interpretacion.txt`
- `barras.png`, `polar.png`, `tiempo.png`, `apilado.png`, `dispersion.png`, `sankey.png`, etc.

Si `ggplot2`/`ggalluvial` no están instalados, los CSV se generan igual y los PNG se omiten.

### 5.6 Analizar una sola oración

```r
datos <- cargar_datos_analisis("salida")
o <- analizar_oracion(
  "Hola, no entiendo el laboratorio de INF 111, ayuda por favor",
  datos = datos,
  usar_udpipe  = TRUE,
  usar_libreria = TRUE
)
print(o)
```

Para incluir tópicos, calcula primero el LDA y pásalo:

```r
lda <- topicos_lda(datos$tokens, k = 6, agrupar = "dia")
o <- analizar_oracion("No me gustó la clase de hoy", datos = datos, lda = lda)
```

`analizar_oracion()` reutiliza el mismo preprocesamiento del corpus, pero escribe sus bitácoras en una carpeta temporal: no contamina `salida/` ni `bitacoras/`.

---

## Paso 6 — Gráficos con `18_top25.R`

`18_top25.R` no se carga con `cargar_proyecto.R`; se carga aparte cuando se necesita. Genera 25 gráficos en 5 grupos (actividad, sentimientos por mensaje, perfil del periodo, serie mensual, palabras y emojis).

```r
source("cargar_proyecto.R")
datos <- cargar_datos_analisis("salida")
a <- analizar_periodo(datos, fecha_inicio = "2026-05-01", fecha_fin = "2026-08-31")

source("R/18_top25.R")
ver_top25(datos, a)                 # dibuja y guarda en salida/top25/
ver_top25(datos, a, solo = 1:9)     # solo el grupo de actividad
ver_top25(datos, a, guardar = FALSE) # solo mostrar en Plots
```

---

## Paso 7 — Usar la API de Plumber

### 7.1 Arrancar

Desde la raíz del proyecto (funciona también desde `r/`):

```powershell
Rscript r/plumber_api.R
```

Salida esperada:

```
[Plumber] Paquetes R cargados: plumber, jsonlite, httr, readxl
[Plumber] Carpeta del proyecto R: C:/CODIGO/AnSent/r
[Plumber] cargar_proyecto.R cargado correctamente
[Plumber] 00_main.R cargado correctamente. Funcion preprocesar() disponible
[Plumber] graficos.R cargado correctamente. Funcion generar_graficos() disponible
[Plumber] 16_analisis.R cargado correctamente. Funciones de analisis disponibles
[Plumber] API definida. Puerto: 8765
[Plumber] Esperando conexiones...
```

**Deja esta terminal abierta.**

### 7.2 Endpoints reales del archivo

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/__ping__` | Salud: `ok`, `ts`, `version`, `iniciado`. |
| GET | `/dataset/summary` | Filas, columnas, nombres y versión del dataset en memoria. |
| POST | `/paso/preprocesar` | Paso 1: preprocesamiento completo (acepta parámetros). |
| POST | `/paso/analizar-periodo` | Paso 2: análisis por periodo + gráficos. |
| POST | `/paso/comparar-periodos` | Paso 3: comparación de dos periodos + gráficos. |
| POST | `/paso/analizar-oracion` | Paso 4: análisis de una oración. |
| POST | `/preprocesar` | Compatibilidad: preprocesar sin parámetros. |
| GET | `/salida/archivos` | Lista los archivos de `r/salida/` (sin subcarpetas). |
| GET | `/salida/archivos/contenido?archivo=x.csv&pagina=1&por_pagina=50` | Contenido paginado de un CSV. |
| GET | `/salida/<ruta>?pagina=&por_pagina=` | Endpoints fijos: `emojis_en_uso`, `emojis_pendientes`, `mensajes_incluidos`, `mensajes_excluidos`, `stopwords_aplicadas`, `tokens`, `resumen`. |
| GET | `/bitacoras` | Lista los archivos de `r/bitacoras/` y sus hojas. |
| GET | `/bitacoras/<nombre>?hoja=&pagina=&por_pagina=` | Contenido paginado de una bitácora. |
| GET | `/dashboard/graficos` | PNG agrupados por carpeta. |
| PUT | `/sentimientos.json` | Activa/desactiva sentimientos y recarga la configuración. |

> **Discrepancia conocida:** `server/services/rService.js` llama a `GET /charts`, pero `plumber_api.R` **no define** ese endpoint (la lista de arranque tampoco lo muestra). Para gráficos en el dashboard usa `/dashboard/graficos` (PNG) o añade un endpoint `/charts` que llame a `generar_graficos(state$dataset)`. La documentación antigua (`docs/estructura.md`, `docs/analisis_codigo_r.md`) todavía menciona `/charts`.

### 7.3 Ejemplos de peticiones

**Paso 2 — análisis por periodo**

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8765/paso/analizar-periodo `
  -ContentType "application/json" `
  -Body '{"fecha_inicio":"2026-05-01","fecha_fin":"2026-08-31","k":6,"agrupar":"dia","shallow":true,"libreria":true}'
```

**Paso 3 — comparación de periodos**

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8765/paso/comparar-periodos `
  -ContentType "application/json" `
  -Body '{"fecha_inicio_a":"2025-01-01","fecha_fin_a":"2025-03-31","fecha_inicio_b":"2026-01-01","fecha_fin_b":"2026-03-31"}'
```

**Paso 4 — una oración**

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8765/paso/analizar-oracion `
  -ContentType "application/json" `
  -Body '{"texto":"No entiendo el laboratorio, necesito ayuda","usar_udpipe":true,"usar_libreria":true}'
```

**Activar/desactivar sentimientos**

```powershell
Invoke-RestMethod -Method Put `
  -Uri http://localhost:8765/sentimientos.json `
  -ContentType "application/json" `
  -Body '{"sentimientos":[{"nombre":"alegria","activo":true},{"nombre":"enojo","activo":false}]}'
```

### 7.4 Notificaciones a Express

Al terminar cada paso, Plumber intenta:

- `POST http://localhost:3000/api/bitacora` → inserta el registro en SQLite y emite `bitacora:update`.
- `POST http://localhost:3000/api/events/publish` → emite `dataset:update`.

Si Express no está corriendo, Plumber **no falla**: solo imprime un aviso (`no se pudo notificar a Express`).

---

## Paso 8 — Usar el dashboard web

### 8.1 Instalar dependencias (una sola vez)

```powershell
cd C:\CODIGO\AnSent
npm install
npm install --prefix client
```

### 8.2 Levantar los tres servicios (tres terminales)

| Terminal | Comando | URL |
|----------|---------|-----|
| 1 — Express | `cd C:\CODIGO\AnSent; npm run dev` | http://localhost:3000 |
| 2 — Plumber | `cd C:\CODIGO\AnSent; Rscript r/plumber_api.R` | http://localhost:8765 |
| 3 — Frontend | `cd C:\CODIGO\AnSent; npm run dev --prefix client` | http://localhost:5173 |

### 8.3 Flujo dentro de la interfaz

1. Abre `http://localhost:5173`.
2. **Dashboard** (`#/dashboard`): muestra resumen del dataset y gráficos. Si Plumber no está arriba, verás el aviso correspondiente.
3. Pulsa **Ejecutar preprocesamiento** → React llama a Express → Express llama a `POST /paso/preprocesar` de Plumber → se ejecutan las 13 etapas.
4. **Paso 2** y **Paso 3** permiten analizar un periodo o comparar dos; los PNG quedan en `client/src/views/salida/analisis/` y se sirven al frontend.
5. **Bitácora** (`#/bitacora`): tabla de registros de SQLite, con filtro por tipo y actualización en vivo por SSE (`bitacora:update`).
6. El indicador **● En vivo / ○ Reconectando…** muestra el estado de SSE.

### 8.4 Verificación de conectividad

```powershell
# Plumber arriba
curl.exe http://localhost:8765/__ping__

# Express ve a Plumber
curl.exe http://localhost:3000/api/dashboard/status

# Resumen del dataset
curl.exe http://localhost:3000/api/dashboard/dataset

# Gráficos (PNG agrupados)
curl.exe http://localhost:8765/dashboard/graficos
```

---

## Paso 9 — Flujo de cambios y emojis pendientes

### 9.1 Detección automática de cambios

Al inicio de cada `preprocesar()`, `vigilar_cambios()` compara:

- todos los `R/*.R`;
- `cargar_proyecto.R` y `ejecutar.R` (si existen);
- todos los `.csv` y `.json` de `config/`;

contra la foto guardada en `bitacoras/_copia_de_control.json`.

- **Primera ejecución:** crea la foto y no pregunta nada.
- **Ejecuciones posteriores:** detecta archivos `nuevos`, `borrados` y `modificados`.
- **Modo interactivo** (`preguntar_cambios = TRUE`, por defecto en RStudio): pregunta por cada archivo:
  1. ¿Qué problema notaste o qué querías lograr?
  2. ¿Cómo lo detectaste? (Enter para omitir)
  3. ¿Por qué este cambio lo resuelve?
  
  Después ofrece aplicar las mismas respuestas a los archivos restantes.
- **Modo no interactivo** (CLI/Plumber): no pregunta. Usa `--motivo "texto"` o `motivo_cambios`; si se omite, queda como `FALTA JUSTIFICAR`.
- La foto **solo se actualiza** si el registro se guardó correctamente en `bitacora_completa.xlsx` (hoja `Cambios`).

Cada cambio registra: `id_cambio`, `fecha`, `hora`, `tipo`, `archivo`, `seccion`, `problema_detectado`, `como_se_detecto`, `cambio_realizado`, `justificacion`, `resultado`, `ejecucion_prueba`, `responsable`, `estado_registro`.

### 9.2 Emojis pendientes

1. Ejecuta con `nuevos_emojis = "marcar"` (por defecto). Los emojis desconocidos se listan en `salida/emojis_pendientes.csv`.
2. Traduce los que quieras en `config/emojis.csv` (significado, sentimiento, polaridad, unicode) o con `actualizar_emoji()` desde R:

   ```r
   actualizar_emoji("🦖", "dinosaurio rex", sentimiento = "alegria")
   ```
3. Vuelve a ejecutar.

Si usas `nuevos_emojis = "detener"` (o `--detener-emojis`), el pipeline se detiene en la Etapa 7 (`estado = "emojis_pendientes"`), escribe `emojis_pendientes.csv`, registra el intento en `bitacora_completa.xlsx` y **no sobrescribe** `bitacora_limpia.xlsx`.

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `ERROR: Faltan paquetes R requeridos` | Paquetes no instalados | Ejecuta el `install.packages(...)` de la sección 2.2. |
| `No existe el archivo: data/result.json` | Ruta relativa incorrecta | Ejecuta desde `r/` o usa ruta absoluta. |
| `El archivo tiene varios chats: ...` | JSON con varios chats | Añade `chat = <número>` a `preprocesar()`. |
| `Formato no soportado` | Extensión distinta de `.json`, `.csv`, `.tsv` | Convierte el archivo o exporta de nuevo desde Telegram. |
| Las salidas no aparecen en `r/salida/` | `preprocesar()` usó `client/src/views/salida` | Pasa `dir_salida = "salida"` explícitamente. |
| `preprocesar()` se detuvo con `emojis_pendientes` | Hay emojis sin traducir y usaste `"detener"` | Traduce `salida/emojis_pendientes.csv` y vuelve a ejecutar, o usa `"marcar"`. |
| `openxlsx` falla al escribir la bitácora | El `.xlsx` está abierto en Excel | Cierra el archivo y reintenta. |
| Plumber no arranca / puerto ocupado | Otro proceso en 8765 | `netstat -ano \| findstr :8765` y termina el proceso, o reinicia. |
| `fetch failed` desde el dashboard | Plumber no está corriendo | `Rscript r/plumber_api.R` en otra terminal. |
| El dashboard no ve gráficos | Falta ejecutar el Paso 1 o el Paso 2 | Preprocesa y luego analiza un periodo; revisa `/dashboard/graficos`. |
| `GET /charts` devuelve 404 | Endpoint no definido en `plumber_api.R` | Usa `/dashboard/graficos` o añade el endpoint que llame a `generar_graficos()`. |
| `udpipe` falla o no descarga el modelo | Sin internet o falta `modelos/*.udpipe` | Coloca el modelo manualmente en `r/modelos/`. |
| Bitácora web vacía | Express estaba apagado al ejecutar R | Levanta Express antes de lanzar los pasos. |
| Tildes o emojis se ven mal en Excel | CSV sin BOM | Deja `csv_para_excel = TRUE` (no uses `--sin-bom`). |

### Diagnóstico rápido

```powershell
# ¿Plumber escucha?
netstat -ano | findstr :8765
curl.exe http://localhost:8765/__ping__

# ¿Express ve a Plumber?
curl.exe http://localhost:3000/api/dashboard/status

# Matar Rscript colgados
Get-Process -Name "Rscript" -ErrorAction SilentlyContinue | Stop-Process -Force

# Ver la última línea JSON del CLI
Rscript ejecutar.R data/result.json --consola silencioso
```

---

## Referencia rápida de comandos

### Desde `r/` en RStudio

```r
setwd("C:/CODIGO/AnSent/r")
source("cargar_proyecto.R")

# Preprocesar
res <- preprocesar("data/result.json", dir_salida = "salida", consola = "didactico")

# Cargar datos limpios
datos <- cargar_datos_analisis("salida")

# Analizar un periodo
a <- analizar_periodo(datos, fecha_inicio = "2026-05-01", fecha_fin = "2026-08-31")
guardar_analisis(a, dir = "salida/analisis")

# Comparar periodos
cmp <- comparar_periodos(datos,
         fecha_inicio_a = "2025-01-01", fecha_fin_a = "2025-03-31",
         fecha_inicio_b = "2026-01-01", fecha_fin_b = "2026-03-31")
guardar_analisis(cmp, dir = "salida/analisis")

# Analizar una oración
o <- analizar_oracion("No entiendo el laboratorio", datos = datos)
print(o)

# Las 25 gráficas
source("R/18_top25.R")
ver_top25(datos, a)
```

### Desde PowerShell

```powershell
# Instalación inicial (raíz del proyecto)
cd C:\CODIGO\AnSent
npm install
npm install --prefix client

# Preprocesar por CLI (desde r/)
cd C:\CODIGO\AnSent\r
Rscript ejecutar.R data/result.json --consola resumen --responsable "Tu nombre"

# Servicios
cd C:\CODIGO\AnSent
npm run dev                      # Express :3000
npm run dev --prefix client      # Vite   :5173
Rscript r/plumber_api.R          # Plumber :8765
```

### Tabla resumen de tareas

| Tarea | Comando / función | Archivo |
|-------|-------------------|---------|
| Cargar herramientas | `source("cargar_proyecto.R")` | `cargar_proyecto.R` |
| Preprocesar (R) | `preprocesar("data/result.json", dir_salida = "salida")` | `R/00_main.R` |
| Preprocesar (CLI) | `Rscript ejecutar.R data/result.json --consola resumen` | `ejecutar.R` |
| Preprocesar (API) | `POST /paso/preprocesar` | `plumber_api.R` |
| Cargar datos limpios | `cargar_datos_analisis("salida")` | `R/09_periodos.R` |
| Analizar periodo | `analizar_periodo(datos, fecha_inicio, fecha_fin)` | `R/16_analisis.R` |
| Comparar periodos | `comparar_periodos(datos, ...)` | `R/16_analisis.R` |
| Guardar análisis | `guardar_analisis(a, dir = "salida/analisis")` | `R/16_analisis.R` |
| Analizar oración | `analizar_oracion("texto", datos = datos)` | `R/15_oracion.R` |
| 25 gráficas | `source("R/18_top25.R"); ver_top25(datos, a)` | `R/18_top25.R` |
| Gráficos ECharts | `generar_graficos(df)` | `graficos.R` |
| Levantar API | `Rscript r/plumber_api.R` | `plumber_api.R` |
| Ver bitácoras | `bitacoras/bitacora_limpia.xlsx`, `bitacoras/bitacora_completa.xlsx` | `R/bitacora.R` |

---

## Orden recomendado de trabajo

1. Instalar R, Node y los paquetes.
2. Colocar `result.json` en `r/data/`.
3. Revisar `config/sentimientos.json` y los diccionarios.
4. Ejecutar el preprocesamiento (RStudio, CLI o Plumber).
5. Revisar `salida/resumen.json`, `mensajes_limpios.csv` y las bitácoras.
6. Cargar `cargar_datos_analisis("salida")`.
7. Analizar periodos, comparar y guardar en `salida/analisis/`.
8. Generar las 25 gráficas si se necesitan.
9. Levantar Express + Vite + Plumber para el dashboard y la bitácora en vivo.
10. Antes de cada nueva ejecución: cerrar los Excel, revisar emojis pendientes y documentar los cambios (o pasar `--motivo`).
