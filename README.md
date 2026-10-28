# Análisis de Sentimientos — Dashboard + Bitácora

Guía paso a paso para instalar y usar el proyecto desde cero, sin nada instalado.

El proyecto tiene tres piezas que deben correr juntas:

1. **R + Plumber** (`r/plumber_api.R`): API en `http://localhost:8765` que ejecuta el preprocesamiento, análisis por periodo, comparación de periodos y análisis de oraciones.
2. **Node.js + Express + SQLite** (`server/`): API en `http://localhost:3000` que persiste la bitácora, guarda configuraciones y hace de puente entre el frontend y Plumber.
3. **React + Vite** (`client/`): frontend en `http://localhost:5173` con el dashboard, la bitácora y los gráficos.

---

## 1. Requisitos previos (instalar una sola vez)

### Node.js (para el servidor y el frontend)

Descarga e instala Node.js (incluye npm) desde https://nodejs.org/

El proyecto requiere **Node >= 22.5**. Verifica la instalación:

```powershell
node --version
npm --version
```

### R y RStudio (para el pipeline de análisis)

1. Descarga e instala R desde https://cran.r-project.org/
2. Descarga e instala RStudio desde https://posit.co/download/rstudio-desktop/

Abre R (o RStudio) e instala los paquetes que usa el proyecto:

```r
install.packages(c("plumber", "jsonlite", "httr", "readxl",
                   "readr", "ggplot2", "udpipe", "topicmodels",
                   "tm", "SnowballC", "syuzhet", "stringi", "digest"))
```

Plumber es el que levanta la API HTTP; los demás los usan los scripts de R (`r/R/`) para leer datos, calcular sentimientos, hacer tópicos (LDA), análisis shallow (udpipe) y dibujar gráficos.

### Git (opcional, para clonar)

Descarga e instala Git desde https://git-scm.com/

---

## 2. Clonar / abrir el proyecto

Si tienes el repositorio remoto:

```powershell
git clone <url-del-repositorio>
cd AnSent
```

Si ya tienes la carpeta, simplemente entrá:

```powershell
cd C:\CODIGO\AnSent
```

Estructura principal del proyecto:

```
AnSent/
├── client/               # Frontend React + Vite (puerto 5173)
├── server/               # Backend Express + SQLite (puerto 3000)
├── r/                    # Pipeline de R
│   ├── plumber_api.R     # API de Plumber (puerto 8765)
│   ├── R/                # Scripts de R (00_main.R ... 18_top25.R)
│   ├── config/           # Configuraciones y diccionarios
│   ├── data/             # Aquí va result.json (entrada de Telegram)
│   ├── salida/           # Salidas del preprocesamiento (CSV, JSON, PNG)
│   └── bitacoras/        # Bitácoras de ejecución (.xlsx)
├── package.json          # Scripts del servidor Node
└── README.md
```

---

## 3. Preparar los datos de entrada

El pipeline lee un archivo `result.json` (exportación de Telegram) o un CSV equivalente.

1. Coloca tu archivo de entrada en `r/data/result.json`.
   - Si usas Telegram: exporta el chat y guarda el JSON como `result.json`.
   - Si no tienes datos, Plumber usa un dataset de ejemplo embebido.

---

## 4. Instalar dependencias del servidor Node (Express + SQLite)

Desde la raíz del proyecto (`C:\CODIGO\AnSent`):

```powershell
npm install
```

Esto instala `express`, `cors` y `dotenv`.

---

## 5. Instalar dependencias del frontend (React + Vite)

Desde la carpeta `client`:

```powershell
npm install --prefix client
```

Esto instala `react`, `react-dom`, `echarts`, `recharts`, `vite` y el plugin de React para Vite.

---

## 6. Poner todo en marcha (tres terminales)

Necesitas tres procesos corriendo al mismo tiempo. Abre tres terminales (o tres pestañas de PowerShell), cada una en la carpeta `C:\CODIGO\AnSent`.

### Terminal 1 — Servidor Express (puerto 3000)

```powershell
npm run dev
```

Verás algo como:

```
[Express] Servidor en http://localhost:3000
[Express] Plumber configurado en http://localhost:8765
```

### Terminal 2 — Plumber / R (puerto 8765)

```powershell
Rscript r/plumber_api.R
```

Verás:

```
[Plumber] API definida. Puerto: 8765
[Plumber] Endpoints:
  GET  http://localhost:8765/__ping__
  POST http://localhost:8765/paso/preprocesar
  POST http://localhost:8765/paso/analizar-periodo
  POST http://localhost:8765/paso/comparar-periodos
  POST http://localhost:8765/paso/analizar-oracion
  ...
```

Si da error de paquetes faltantes, instálalos en R con `install.packages(...)`.

### Terminal 3 — Frontend React (puerto 5173)

```powershell
npm run dev --prefix client
```

Verás:

```
  VITE v5.x.x  ready in xxx ms
  ➜  Local:   http://localhost:5173/
```

---

## 7. Flujo de uso (paso a paso)

Con los tres servicios arriba, abre en el navegador:

```
http://localhost:5173
```

### 7.1. Preprocesar los datos (Paso 1)

Desde el dashboard, presiona el botón de preprocesamiento. Esto llama a:

```
POST http://localhost:8765/paso/preprocesar
```

que ejecuta `preprocesar()` (`r/R/00_main.R`) sobre `r/data/result.json` y genera en `r/salida/`:

- `mensajes_limpios.csv` — dataset listo para graficar
- `mensajes_excluidos.csv` — lo que se descartó y por qué
- `tokens.csv` — 1 fila = 1 palabra (para TF-IDF, n-gramas, LDA)
- `emojis_en_uso.csv` / `emojis_pendientes.csv`
- `resumen.json` — conteos clave
- `stopwords_aplicadas.csv`

También registra la ejecución en `r/bitacoras/bitacora_completa.xlsx`.

### 7.2. Análisis por periodo (Paso 2)

En RStudio (o consola de R), ejecuta:

```r
setwd("C:/CODIGO/AnSent")
source("cargar_proyecto.R")

# 1. Cargar los datos ya preprocesados
datos <- cargar_datos_analisis("salida")

# 2. Elegir un rango de fechas y analizar
a <- analizar_periodo(datos, c("2024-01-01", "2024-03-31"))

# 3. Ver el nivel de sentimientos del periodo
print(a$nivel)

# 4. Ver la interpretación automática
print(a$interpretacion)

# 5. Guardar tablas y gráficos en salida/analisis/<periodo>/
guardar_analisis(a)
```

También puedes llamarlo por la API de Plumber:

```
POST http://localhost:8765/paso/analizar-periodo
Cuerpo: { "fecha_inicio": "2024-01-01", "fecha_fin": "2024-03-31" }
```

### 7.3. Comparación de periodos (Paso 3)

En RStudio:

```r
# Comparar dos periodos (A contra B)
cmp <- comparar_periodos(datos,
                         fecha_inicio_a = "2023-01-01", fecha_fin_a = "2023-03-31",
                         fecha_inicio_b = "2024-01-01", fecha_fin_b = "2024-03-31")

# Ver los niveles de cada periodo
print(cmp$niveles)

# Ver la interpretación de la comparación
print(cmp$interpretacion)

# Guardar CSV y PNG de la comparación
guardar_analisis(cmp)
```

Por la API de Plumber:

```
POST http://localhost:8765/paso/comparar-periodos
Cuerpo: {
  "fecha_inicio_a": "2023-01-01",
  "fecha_fin_a": "2023-03-31",
  "fecha_inicio_b": "2024-01-01",
  "fecha_fin_b": "2024-03-31"
}
```

### 7.4. Usar el nuevo script `18_top25.R` (las 25 mejores gráficas)

Este script está en `r/R/18_top25.R` y es autocontenido (no depende del archivo 17). Genera 25 gráficos agrupados en 5 grupos:

- **1-9 Actividad**: volumen por mes, reloj, punchcard, pulso polar, calendario, autores, pareto, carrera (bump), ridgeline.
- **10-15 Sentimientos por mensaje**: mapa de calor mes/sentimiento, ánimo por hora, emoción dominante, correlación, perfil por autor, media móvil.
- **16-19 Perfil del periodo**: lollipop, rosa, ranking, waffle (reciben `a$nivel`).
- **20-22 Serie mensual**: facetas, mapa de calor, stream (reciben la serie mensual).
- **23-25 Palabras y emojis**: top palabras, top emojis, sunburst de emojis por polaridad.

**Cómo usarlo en RStudio:**

```r
setwd("C:/CODIGO/AnSent")
source("cargar_proyecto.R")

# Cargar datos ya preprocesados
datos <- cargar_datos_analisis("salida")

# Definir un periodo (ejemplo: primer trimestre 2024)
a <- analizar_periodo(datos, c("2024-01-01", "2024-03-31"))

# Cargar el script de las 25 gráficas
source("R/18_top25.R")

# Dibujar las 25 en la pestaña Plots y guardarlas como PNG en salida/top25/
ver_top25(datos, a)

# O solo algunas (por ejemplo las 6 primeras)
ver_top25(datos, a, solo = 1:6)

# Sin guardar archivos (solo ver en Plots)
ver_top25(datos, a, guardar = FALSE)
```

Por la API de Plumber, el paso 2 y 3 ya guardan automáticamente los análisis (incluyendo gráficos) en `salida/analisis/`.

---

## 8. Comandos resumen

Desde `C:\CODIGO\AnSent`:

```powershell
# Instalar todo (primera vez)
npm install
npm install --prefix client

# Levantar backend (terminal 1)
npm run dev

# Levantar Plumber/R (terminal 2)
Rscript r/plumber_api.R

# Levantar frontend (terminal 3)
npm run dev --prefix client

# Iniciar servidor Express sin watch
npm start
```

Desde **RStudio**, consola de R:

```r
setwd("C:/CODIGO/AnSent")
source("cargar_proyecto.R")

datos <- cargar_datos_analisis("salida")             # cargar datos limpios
a <- analizar_periodo(datos, c("inicio", "fin"))      # analizar un periodo
cmp <- comparar_periodos(datos, ...)                  # comparar dos periodos
guardar_analisis(a)                                   # guardar CSV y PNG
source("R/18_top25.R")                                # cargar script de las 25 gráficas
ver_top25(datos, a)                                   # dibujar y guardar las 25
```

---

## 9. Puertos y URLs

| Servicio | Puerto | URL |
|---|---|---|
| Frontend (React + Vite) | 5173 | http://localhost:5173 |
| Backend (Express + SQLite) | 3000 | http://localhost:3000 |
| Plumber (R API) | 8765 | http://localhost:8765 |

Endpoints clave de Plumber:

- `GET /__ping__` — salud de la API
- `GET /dataset/summary` — resumen del dataset cargado
- `POST /paso/preprocesar` — preprocesamiento completo
- `POST /paso/analizar-periodo` — análisis por periodo
- `POST /paso/comparar-periodos` — comparación de dos periodos
- `POST /paso/analizar-oracion` — análisis de una oración
- `GET /dashboard/graficos` — imágenes agrupadas por carpeta
- `GET /salida/archivos` — listado de archivos de salida

---

## 10. Solución de problemas

- **Puerto ya en uso**: otro proceso está usando 3000, 5173 o 8765. Cierra ese proceso o cambia el puerto (`PORT` para Express, `PLUMBER_URL` para el cliente).
- **Plumber no responde**: verifica que `Rscript r/plumber_api.R` esté corriendo y que instalaste `plumber`, `jsonlite`, `httr`, `readxl`.
- **El dashboard no muestra gráficos**: ejecuta primero el preprocesamiento (Paso 1) para generar `salida/` y luego un análisis por periodo (Paso 2) para generar `salida/analisis/`.
- **Error de paquetes en R**: ejecuta `install.packages()` con la lista de la sección 1 y reinicia RStudio.
- **Bitácora vacía**: los registros se escriben al terminar cada lote en R (Plumber llama a `POST /api/bitacora` en Express). Asegúrate de que Express esté arriba cuando corras los pasos en R.
