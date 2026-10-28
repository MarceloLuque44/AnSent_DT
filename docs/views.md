# Documentación de Vistas del Frontend — AnSent

Este documento describe cada vista (componente React) de `client/src/views/`: para qué sirve, qué puede hacer el usuario, qué opciones tiene y qué datos consume.

## Índice de vistas

| Vista | Ruta (hash) | Propósito |
|-------|-------------|-----------|
| `Dashboard.jsx` | `#/dashboard` | Lienzo de gráficos PNG generados por el análisis, agrupados por carpeta. |
| `Bitacoras.jsx` | `#/bitacora` | Consulta de archivos de bitácora (xlsx/json de `r/bitacoras`) con paginación y gráfico de serie. |
| `Pasos.jsx` | (incrustado en dashboard) | Formularios para ejecutar los 4 pasos del pipeline (preprocesamiento, análisis por periodo, comparación y oración). |
| `Salida.jsx` | — | Lista y lectura de archivos generados en `r/salida/` (CSV/JSON). |
| `Sentimientos.jsx` | — | Lista y lectura de archivos de configuración en `r/config/` (diccionarios, stopwords, emojis, periodos). |

---

## 1. Dashboard.jsx — `#/dashboard`

**Propósito:** Lienzo visual de los gráficos (PNG) generados por el pipeline de análisis. Permite activar carpetas de gráficos desde el menú "Dashboard" de la barra lateral y mostrarlas en pantalla.

### Qué puede hacer el usuario

- **Activar/desactivar carpetas de gráficos** desde el árbol del menú Dashboard en la barra lateral (gestionado por `dashboardStore.jsx`).
- **Ver los gráficos de cada carpeta activa** en columnas: con una carpeta activa las imágenes se muestran dos por fila; con varias carpetas, cada imagen ocupa el ancho completo de su columna.
- **Ampliar una imagen** al hacer clic sobre ella (overlay con la imagen a tamaño completo).
- **Contar carpetas y gráficos** mostrados en el chip del encabezado.

### Opciones / comportamiento

| Opción | Efecto |
|--------|--------|
| Carpetas activas | Determina qué columnas de gráficos se renderizan. Un gráfico puede ocultarse individualmente vía `graficosOcultos`. |
| Modo de visualización | `"doble"` (una carpeta, dos por fila) o `"sencilla"` (varias carpetas, una por columna). |
| Imagen ampliada | Click en una figura abre un overlay con `Cerrar` para volver. |

### Datos que consume

- `useDashboard()` (store de `dashboardStore.jsx`): `carpetas`, `carpetasActivas`, `graficosOcultos`.
- Las rutas de imagen (`img.ruta`) apuntan a los archivos PNG generados en `client/src/views/salida/analisis/` (servidos por Plumber vía `/archivos/*`).

---

## 2. Bitacoras.jsx — `#/bitacora`

**Propósito:** Pantalla de consulta de la bitácora del proceso. Lista los archivos de bitácora guardados en `r/bitacoras/` (archivos `.xlsx` y `.json`), permite elegir una hoja (para xlsx) y ver el contenido paginado. Incluye un gráfico de líneas con la evolución de "filas después" por registro (solo para `bitacora_limpia.xlsx`).

### Qué puede hacer el usuario

- **Listar bitácoras disponibles** (botón "Refrescar" para recargar la lista).
- **Seleccionar un archivo de bitácora** desde un desplegable (por defecto se selecciona `bitacora_limpia.xlsx` si existe).
- **Elegir la hoja** del archivo xlsx (desplegable dinámico según las hojas disponibles).
- **Paginar el contenido** de la hoja (tamaños de página: 25, 50, 100, 200 filas).
- **Ver metadatos** del archivo: nombre, tipo, tamaño (KB), fecha de modificación, número de filas/columnas y hoja usada.
- **Ver el contenido JSON** directamente si el archivo es de tipo json (primer fila).
- **Ver un gráfico de líneas** (`recharts`) con `filas_despues` por registro, solo cuando el archivo activo es `bitacora_limpia.xlsx` (hoja "Bitacora").

### Opciones / comportamiento

| Opción | Valores | Efecto |
|--------|---------|--------|
| Bitácora | lista de archivos `.xlsx` / `.json` | Cambia el archivo consultado. |
| Hoja | lista de hojas del xlsx seleccionado | Cambia la hoja mostrada (solo xlsx). |
| Página | 1 … totalPaginas | Navega por las páginas del contenido. |
| Filas por página | 25, 50, 100, 200 | Cambia el tamaño de página y reinicia a la página 1. |

### Datos que consume

- `GET /bitacoras` — lista de archivos de bitácora y carpeta base.
- `GET /bitacoras/<archivo>?hoja=&pagina=&por_pagina=` — contenido paginado de una hoja.
- Normaliza respuestas de Plumber (arrays unboxed/boxed, valores nulos).

---

## 3. Pasos.jsx — Ejecución de pasos 1-4

**Propósito:** Vista de ejecución de los 4 pasos del pipeline de análisis. Cada paso es un formulario para configurar parámetros y ejecutar la acción correspondiente en la API de Express, que a su vez llama a Plumber (R). Muestra los resultados, imágenes (PNG) y CSV generados.

> **Nota:** El card del paso 1 (Preprocesamiento completo) está ocultado por defecto (`style={{ display: 'none' }}` para `paso.id === 1`).

### Qué puede hacer el usuario

- **Ejecutar cualquiera de los 4 pasos** rellenando el formulario correspondiente y pulsando "Ejecutar paso N".
- **Guardar configuración** de cada paso con un nombre opcional (se persiste vía `POST /api/configuraciones`).
- **Ver el resultado** de la ejecución: mensaje de éxito/error, versión del dataset, número de mensajes, directorio de análisis, interpretación.
- **Ver imágenes generadas** (PNG) y **archivos CSV** de cada paso completado.
- **Ver configuraciones guardadas** previamente para cada paso.

### Paso 1 — Preprocesamiento completo (oculto)

Ejecutar `preprocesar()` sobre el dataset de entrada (`data/result.json`). Genera `mensajes_limpios.csv`, `tokens.csv`, `resumen.json`, bitácoras, etc.

**Opciones del formulario:**

| Opción | Tipo | Valor por defecto | Descripción |
|--------|------|-------------------|-------------|
| Archivo de entrada | texto (disabled) | `data/result.json` | Fijo, no editable. |
| Fecha de inicio | texto | — | Filtra mensajes desde esta fecha (opcional). |
| Fecha de fin | texto | — | Filtra mensajes hasta esta fecha (opcional). |
| Responsable | texto | — | Nombre que se registra en la bitácora. |
| Excluir publicidad/anuncios | checkbox | activado | Detecta y excluye publicidad. |
| Anonimizar autor | checkbox | activado | Anonimiza el autor de los mensajes. |
| CSV con BOM para Excel | checkbox | desactivado | Genera CSV con marca UTF-8 para Excel. |
| Preguntar cambios de código/diccionarios | checkbox | desactivado | Pide justificación ante cambios detectados. |
| Umbral publicidad | número | 4 | Umbral para detección de publicidad. |
| Mínimo caracteres duplicado | número | 25 | Longitud mínima para detectar duplicados. |
| Modo de consola | select | Silencioso | `silencioso`, `resumen` o `didactico`. |

### Paso 2 — Análisis por periodo

Ejecutar `analizar_periodo() + guardar_analisis()`. Filtra por fechas, calcula nivel de sentimiento, serie mensual, TF-IDF, LDA, shallow y librería. Genera CSV y PNG.

**Opciones del formulario:**

| Opción | Tipo | Valor por defecto | Descripción |
|--------|------|-------------------|-------------|
| Fecha de inicio | date | `2023-01-01` | Inicio del periodo a analizar. |
| Fecha de fin | date | `2023-03-31` | Fin del periodo a analizar. |
| Número de tópicos (k, LDA) | número | 6 | Temas a identificar con LDA. |
| Agrupar documentos | select | `dia` | `dia` o `mes`. |
| Shallow linguistic (udpipe) | checkbox | activado | Análisis morfosintáctico con UDPipe. |
| Sentimientos de librería (syuzhet/NRC) | checkbox | activado | Diccionarios externos además del propio. |

### Paso 3 — Comparar dos periodos

Ejecutar `comparar_periodos()` entre dos periodos y guarda resultados. Compara niveles, serie, TF-IDF y sentimientos de librería.

**Opciones del formulario:**

| Opción | Tipo | Valores por defecto | Descripción |
|--------|------|---------------------|-------------|
| Periodo A (inicio/fin) | date × 2 | `2023-01-01` / `2023-03-31` | Rango del primer periodo. |
| Periodo B (inicio/fin) | date × 2 | `2024-01-01` / `2024-03-31` | Rango del segundo periodo. |
| Sentimientos de librería (syuzhet/NRC) | checkbox | activado | Usar diccionarios externos. |

### Paso 4 — Análisis de una oración (oculto en la UI)

Ejecutar `analizar_oracion()` sobre una sola oración con el mismo preprocesamiento que el dataset.

**Opciones del formulario:**

| Opción | Tipo | Valor por defecto | Descripción |
|--------|------|-------------------|-------------|
| Oración a analizar | textarea | — | Texto de la oración. |
| Shallow linguistic (udpipe) | checkbox | activado | Análisis morfosintáctico. |
| Sentimientos de librería (syuzhet/NRC) | checkbox | activado | Diccionarios externos. |
| Incluir topic modeling (LDA) | checkbox | desactivado | Modelado de tópicos. |

### Flujo de ejecución

1. El usuario rellena el formulario y pulsa "Ejecutar paso N".
2. Se envía `POST /api/pasos/${paso}` con el cuerpo de parámetros.
3. La API de Express ejecuta el comando en Plumber (R) y devuelve la ruta en memoria de los archivos generados.
4. Si `resultado.ok`, se cargan los archivos del paso (`imagenes` y `csvs`) y las configuraciones.
5. Se muestra el resultado: mensaje, datos (versión, mensajes), directorio de análisis, interpretación, imágenes y CSV.

---

## 4. Salida.jsx

**Propósito:** Lista los archivos generados directamente en `r/salida/` (solo archivos, sin carpetas) vía `GET /salida/archivos` de la API de Plumber. Cada archivo se muestra como un toggle (interruptor) que, al activarse, despliega su detalle (ruta, tipo, tamaño, fecha de modificación) y su contenido.

### Qué puede hacer el usuario

- **Listar archivos de salida** (botón "Refrescar" para recargar).
- **Ver resumen de chips**: total de archivos, cuántos están abiertos y cuántos cerrados.
- **Activar/desactivar archivos** con un toggle para leer su contenido.
- **Leer el contenido** de cada archivo: CSV (tabla paginada), JSON (nodo JSON) o texto plano.
- **Paginar archivos grandes** (mensajes incluidos/excluidos): tamaños 25, 50, 100, 200 filas.
- **Ver metadatos**: ruta, tamaño (KB), fecha de modificación.

### Archivos reconocidos con endpoint dedicado

| Archivo | Endpoint de detalle | Paginado |
|---------|---------------------|----------|
| `emojis_en_uso.csv` | `/salida/emojis_en_uso` | No |
| `emojis_pendientes.csv` | `/salida/emojis_pendientes` | No |
| `mensajes_limpios.csv` | `/salida/mensajes_incluidos` | Sí |
| `mensajes_excluidos.csv` | `/salida/mensajes_excluidos` | Sí |
| `stopwords_aplicadas.csv` | `/salida/stopwords_aplicadas` | No |
| `tokens.csv` | `/salida/tokens` | No |
| `resumen.json` | `/salida/resumen` | No |

Cualquier otro archivo se lee vía `/salida/archivos/contenido?archivo=<nombre>`.

### Opciones / comportamiento

| Opción | Valores | Efecto |
|--------|---------|--------|
| Archivo activo | toggle por archivo | Muestra/oculta el detalle y contenido del archivo. |
| Página | 1 … totalPaginas | Navega por páginas (solo archivos paginados). |
| Filas por página | 25, 50, 100, 200 | Cambia el tamaño de página y reinicia a la página 1. |

### Datos que consume

- `GET /salida/archivos` — lista de archivos de salida y carpeta base.
- `GET /salida/<endpoint>?pagina=&por_pagina=` — contenido de archivos con endpoint dedicado.
- `GET /salida/archivos/contenido?archivo=<nombre>&pagina=&por_pagina=` — contenido de archivos genéricos.

---

## 5. Sentimientos.jsx

**Propósito:** Lista los archivos de configuración en `r/config/` (diccionarios, stopwords, emojis, periodos, etc.) vía `GET /api/sentimientos` de la API de Express. Cada archivo se muestra como un toggle que, al activarse, despliega su contenido (JSON, CSV como tabla o texto plano).

### Qué puede hacer el usuario

- **Listar archivos de configuración** (botón "Refrescar" para recargar).
- **Ver resumen de chips**: total de archivos, cuántos están abiertos y cuántos cerrados.
- **Activar/desactivar archivos** con un toggle para leer su contenido.
- **Leer el contenido** de cada archivo: JSON (bloque preformateado), CSV (tabla con columnas y filas) o texto plano (`<pre>`).
- **Ver metadatos**: nombre del archivo, tamaño (KB), fecha de modificación, tipo.

### Opciones / comportamiento

| Opción | Efecto |
|--------|--------|
| Archivo activo | toggle por archivo; muestra/oculta detalle y contenido. |

### Datos que consume

- `GET /api/sentimientos` — lista de archivos de configuración y carpeta base.
- `GET /api/sentimientos/<nombre>` — contenido de un archivo de configuración (JSON, CSV o texto).

### Tipos de archivo soportados

| Tipo | Icono | Formato de visualización |
|------|-------|--------------------------|
| `csv` | 📄 | Tabla con columnas y filas (parseo simple de CSV). |
| `json` | 🧾 | Bloque JSON preformateado (`<pre>`). |
| `txt` | 📝 | Texto plano en `<pre>`. |

---

## Notas de integración

- Todas las vistas consumen la API de Express a través de `client/src/api.js` (`apiGet` / `apiPost`) o `rGet` (para endpoints directos de Plumber/bitácoras).
- Las actualizaciones en tiempo real llegan por SSE (`client/src/sse.jsx`), aunque estas vistas específicas no se suscriben a eventos SSE (salvo `Pasos.jsx` que usa `useSse('dataset:update')` para recargar archivos al llegar un nuevo dataset).
- Las vistas de lista de archivos (`Salida.jsx`, `Sentimientos.jsx`, `Bitacoras.jsx`) comparten el patrón de "toggle para activar/leer contenido" y chips de resumen.
