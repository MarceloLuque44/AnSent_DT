# Documentación técnica del módulo R de AnSent

Esta documentación describe cada archivo de la carpeta `r/` del proyecto **AnSent** (análisis de sentimientos sobre un chat de Telegram). Para cada archivo se indica: qué hace, qué recibe (entrada), qué resultado saca (salida), dónde se guarda ese resultado y en qué formato.

---

## Índice de archivos

| Archivo | Tipo | Ubicación |
|---|---|---|
| `cargar_proyecto.R` | Script de carga | `r/cargar_proyecto.R` |
| `ejecutar.R` | Punto de entrada CLI | `r/ejecutar.R` |
| `plumber_api.R` | API REST | `r/plumber_api.R` |
| `preprocesamiento.R` | Wrapper para Plumber | `r/preprocesamiento.R` |
| `graficos.R` | Definición JSON de gráficos (ECharts) | `r/graficos.R` |
| `R/00_main.R` | Orquestador principal del pipeline | `r/R/00_main.R` |
| `R/01_lectura.R` | Lectura de datos y configuración | `r/R/01_lectura.R` |
| `R/02_estructura.R` | Normalización de estructura y formatos | `r/R/02_estructura.R` |
| `R/03_calidad.R` | Duplicados, faltantes y outliers | `r/R/03_calidad.R` |
| `R/04_publicidad.R` | Detección de publicidad y anuncios | `r/R/04_publicidad.R` |
| `R/05_emojis.R` | Emojis, emoticonos y reacciones | `r/R/05_emojis.R` |
| `R/06_texto.R` | Limpieza de texto, género, tokenización y stopwords | `r/R/06_texto.R` |
| `R/07_sentimientos.R` | Sentimientos con diccionario propio | `r/R/07_sentimientos.R` |
| `R/08_salida.R` | Relleno de nulos, validación y exportación | `r/R/08_salida.R` |
| `R/09_periodos.R` | Análisis por periodos (niveles, TF-IDF, LDA) | `r/R/09_periodos.R` |
| `R/10_tfidf.R` | TF-IDF y stopwords mostradas | `r/R/10_tfidf.R` |
| `R/11_shallow.R` | Análisis lingüístico superficial (udpipe) | `r/R/11_shallow.R` |
| `R/12_topicos.R` | Topic modeling con LDA | `r/R/12_topicos.R` |
| `R/13_libreria.R` | Sentimientos con librería syuzhet/NRC | `r/R/13_libreria.R` |
| `R/14_graficos.R` | Gráficos ggplot para el dashboard | `r/R/14_graficos.R` |
| `R/15_oracion.R` | Análisis de una sola oración | `r/R/15_oracion.R` |
| `R/16_analisis.R` | Funciones principales para el dashboard | `r/R/16_analisis.R` |
| `R/bitacora.R` | Motor de las dos bitácoras | `r/R/bitacora.R` |

---

## 1. Archivos raíz de `r/`

### `cargar_proyecto.R`

**Qué hace:** Carga una sola vez todas las herramientas (scripts) del proyecto R. Valida que los paquetes base (`jsonlite`, `readr`, `stringi`, `openxlsx`, `digest`) estén instalados y hace `source()` de los 17 scripts de `r/R/` en el orden definido.

**Qué recibe:** No recibe parámetros. Usa la ubicación del script para determinar `PROYECTO` y `CARPETA_R`.

**Resultado:** Todos los scripts de `R/` quedan cargados en el entorno global. Imprime en consola los mensajes de carga y el aviso de ejecutar `preprocesar("data/result.json")`.

**Dónde se guarda:** No guarda archivos. Solo carga funciones en memoria.

**Formato:** Salida por consola (stdout/stderr).

---

### `ejecutar.R`

**Qué hace:** Punto de entrada para ejecutar el preprocesamiento desde terminal (también puede ser llamado por Node, Plumber u otro programa). Parsea argumentos de línea de comandos (`--inicio`, `--fin`, `--responsable`, `--salida`, `--config`, `--bitacoras`, `--umbral`, `--sin-anonimizar`, `--detener-emojis`, `--sentimientos`, `--consola`, `--sin-bom`, `--motivo`) y llama a `preprocesar()`. La última línea que imprime es un JSON con el resumen.

**Qué recibe:**
- `args[1]`: ruta del archivo JSON o CSV de entrada.
- Opciones opcionales vía argumentos de CLI.

**Resultado:** Ejecuta `preprocesar()` con los parámetros recibidos e imprime al final un JSON con `res$resumen` (o `list(estado = res$estado)` si no hay resumen).

**Dónde se guarda:** No guarda directamente; `preprocesar()` guarda en `salida/` y `bitacoras/`.

**Formato:** JSON por stdout.

---

### `plumber_api.R`

**Qué hace:** Define y arranca un servidor Plumber (API REST) en el puerto 8765. Valida paquetes (`plumber`, `jsonlite`, `httr`), carga `cargar_proyecto.R`, `R/00_main.R` y `graficos.R`, y expone cuatro endpoints. Notifica a Express (puerto 3000) al terminar un preprocesamiento.

**Qué recibe:** No recibe parámetros de entrada directa; se ejecuta con `Rscript plumber_api.R`.

**Endpoints:**
| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/__ping__` | Salud de la API. Devuelve `ok`, timestamp UTC, versión y tiempo de inicio. |
| GET | `/dataset/summary` | Resumen del dataset cargado (filas, columnas, nombres, versión). |
| GET | `/charts` | Genera definiciones JSON de gráficos (ECharts) a partir del dataset en memoria. |
| POST | `/preprocesar` | Ejecuta el preprocesamiento completo (`preprocesar()`), guarda entrada en `data/plumber_entrada.json`, notifica a Express y devuelve versión, filas y estado. |

**Resultado:** Respuestas JSON por endpoint. Estado global en memoria (`state`) con `dataset`, `version` e `iniciado`.

**Dónde se guarda:** `data/plumber_entrada.json` (entrada del preprocesamiento); `salida/` y `bitacoras/` vía `preprocesar()`.

**Formato:** JSON HTTP.

---

### `preprocesamiento.R`

**Qué hace:** Wrapper ligero que delega en el pipeline real (`00_main.R` → `preprocesar()`). Mantiene la firma que esperaba Plumber: `ejecutar_preprocesamiento(df)`.

**Qué recibe:** Un `data.frame` `df` con los datos de entrada.

**Resultado:** Persiste el `data.frame` como JSON en `data/plumber_entrada_df.json`, ejecuta `preprocesar()` y devuelve una lista con `dataset`, `descripcion`, `filas_afectadas` y `resumen` (filas antes, después, eliminadas, columnas, timestamp, estado).

**Dónde se guarda:** `data/plumber_entrada_df.json`; salidas de `preprocesar()` en `salida/` y `bitacoras/`.

**Formato:** Lista R (convertible a JSON).

---

### `graficos.R`

**Qué hace:** Genera definiciones JSON de gráficos compatibles con ECharts a partir de un `data.frame` limpio (`df`). Produce hasta 10 tipos de gráficos: distribución de sentimientos, proporción por clase, polaridad, nivel promedio de sentimientos, evolución mensual, composición apilada, tópicos por mes, actividad día × hora (mapa de calor), reacciones positivas vs negativas y top emojis.

**Qué recibe:** `df` — data.frame limpio con columnas como `sentimiento_dominante`, `polaridad_msg`, `pct_*`, `anio_mes`, `dia_semana`, `hora`, `topico`, `emojis_lista`, `reacciones_pos`, `reacciones_neg`.

**Resultado:** Una lista de gráficos, cada uno con `titulo` y `option` (configuración ECharts).

**Dónde se guarda:** No guarda archivos directamente; se usa desde `plumber_api.R` (endpoint `/charts`) o desde el frontend de React.

**Formato:** Lista R de listas con estructura ECharts `option`.

---

## 2. Archivos de `r/R/` (pipeline de preprocesamiento y análisis)

### `R/00_main.R` — `preprocesar()`

**Qué hace:** Función orquestadora que ejecuta todo el preprocesamiento en 13 etapas. Carga diccionarios, lee el archivo de entrada, y aplica auditoría, estructuración, control de calidad, detección de publicidad, emojis, limpieza de texto, género, tokenización, sentimientos, relleno de nulos y validación. Exporta salidas y bitácoras.

**Qué recibe:**
- `ruta_archivo`: ruta del JSON de Telegram o CSV.
- `fecha_inicio`, `fecha_fin`: recorte opcional por periodo.
- `responsable`: nombre de quien ejecuta.
- `dir_config`, `dir_salida`, `dir_bitacoras`: carpetas de configuración, salida y bitácoras.
- `sentimientos_activos`, `excluir_publicidad`, `umbral_publicidad`, `anonimizar_autor`, `min_chars_duplicado`, `nuevos_emojis`, `consola`, `csv_para_excel`, `preguntar_cambios`, `motivo_cambios`, `chat`.

**Resultado:** Lista con `estado`, `datos`, `excluidos`, `tokens`, `bitacora`, `emojis_pendientes` y `resumen`. También escribe `salida/resumen.json`.

**Dónde se guarda:**
- `salida/resumen.json`: resumen clave de la ejecución (JSON).
- `salida/`, `bitacoras/`: archivos generados por `exportar_salidas()` y `exportar_bitacora()`.

**Formato:** Lista R + archivo JSON.

---

### `R/01_lectura.R`

**Qué hace:** Lee el archivo de entrada (JSON de Telegram o CSV equivalente), carga diccionarios de `config/` y realiza la auditoría inicial (Etapa 1) sin modificar datos.

**Funciones:**
- `leer_entrada(ruta, chat)`: lee JSON o CSV.
- `leer_telegram_json(ruta, chat)`: parsea el `result.json` de Telegram (soporta chats múltiples o individual), aplana texto de fragmentos y extrae campos (id, fecha, autor, tipo, reacciones, etc.).
- `leer_csv_generico(ruta)`: lee CSV/TSV con nombres de columna alternativos.
- `cargar_config(dir_config, sentimientos_activos)`: carga todos los diccionarios de `config/` y valida que existan.
- `auditar_entrada(ctx, d)`: registra hallazgos de auditoría (volumen, registros de servicio, texto mixto, mensajes sin texto, autor nulo, reenviados).

**Qué recibe:** Ruta de archivo y opcional `chat` (número para chats múltiples).

**Resultado:** `data.frame` con columnas crudas del mensaje + objeto `cfg` con diccionarios cargados.

**Dónde se guarda:** No guarda; registra en bitácora de pasos.

**Formato:** `data.frame` + lista de configuración.

---

### `R/02_estructura.R` — Etapa 2

**Qué hace:** Normalización de estructura y formatos: conversión a UTF-8/NFC, parseo de fechas (hora local La Paz), derivación de columnas temporales (`anio`, `mes`, `anio_mes`, `trimestre`, `dia_semana`, `hora`), separación de mensajes de servicio, uso de emoji de sticker como texto, recorte opcional por periodo, anonimización de autores (hash MD5), y derivación de variables descriptivas (`n_caracteres`, `n_palabras`, `n_enlaces`, `n_hashtags`, `n_menciones`, `tiene_telefono`, `n_emojis`, `emojis_lista`, `es_respuesta`, `reenviado`).

**Qué recibe:** `ctx` (contexto de ejecución) y `d` (data.frame leído).

**Resultado:** `data.frame` con columnas normalizadas y nuevas variables derivadas.

**Dónde se guarda:** Registra pasos en bitácora; no guarda archivo propio.

**Formato:** `data.frame`.

---

### `R/03_calidad.R` — Etapas 3, 4 y 5

**Qué hace:** Control de calidad: gestión de duplicados (elimina duplicados exactos con ≥25 caracteres del mismo autor, conserva la primera), tratamiento de valores faltantes (sepura mensajes sin texto), y detección de outliers de longitud (Q3 + 1.5×IQR sobre log) y ráfagas (≥8 mensajes del mismo autor en un minuto). Los outliers solo se marcan, no se eliminan.

**Qué recibe:** `ctx` y `d`.

**Resultado:** `data.frame` con columnas `outlier_longitud` y `outlier_rafaga` añadidas, y filas duplicadas/sin texto excluidas.

**Dónde se guarda:** Registra pasos y excluidos en bitácora.

**Formato:** `data.frame`.

---

### `R/04_publicidad.R` — Etapa 6

**Qué hace:** Detección de publicidad y anuncios por puntaje compuesto. Calcula puntaje por mensaje usando reglas de `config/palabras_anuncio.csv` (señales de estructura + frases de llamado a la acción). Un mensaje es publicidad si `puntaje >= umbral` (default 4). Los mensajes marcados se excluyen y se guardan con su puntaje y motivo.

**Qué recibe:** `ctx` y `d`.

**Resultado:** `data.frame` con columnas `puntaje_publicidad`, `motivo_publicidad`, `posible_publicidad`; filas publicitarias excluidas.

**Dónde se guarda:** Registra en bitácora; excluidos van a `mensajes_excluidos.csv`.

**Formato:** `data.frame`.

---

### `R/05_emojis.R` — Etapa 7

**Qué hace:** Procesamiento de emojis y emoticonos: extrae emojis del texto y reacciones, añade nuevos al diccionario maestro (`config/emojis.csv`), traduce emojis a texto (`emoji_<significado>`), asigna sentimiento y polaridad del emoji por mensaje, y cuantifica reacciones positivas/negativas. Puede detenerse si hay emojis pendientes (`nuevos_emojis = "detener"`).

**Qué recibe:** `ctx` y `d`.

**Resultado:** `data.frame` con columnas `texto_traducido`, `sentimiento_emoji`, `polaridad_emoji`, `reacciones_total`, `reacciones_pos`, `reacciones_neg`. Actualiza `config/emojis.csv` con emojis nuevos.

**Dónde se guarda:** `config/emojis.csv` (actualizado); `salida/emojis_en_uso.csv` y `salida/emojis_pendientes.csv` (vía `exportar_salidas`).

**Formato:** `data.frame` + CSV actualizado.

---

### `R/06_texto.R` — Etapas 8, 9 y 10

**Qué hace:** Limpieza y normalización de texto (elimina URLs, correos, dominios, menciones, teléfonos; lenguaje inclusivo `@`; minúsculas; horas/fechas; códigos de materia; hashtags; signos; letras alargadas; abreviaturas de chat), referencias de género (femenino/masculino/inclusivo/ninguno), tokenización, stopwords personalizadas (conserva negaciones, pronombres de género, palabras del diccionario de sentimientos; elimina artículos, preposiciones, etc.), y quita tildes de los tokens (salvo `él` y la `ñ`).

**Qué recibe:** `ctx` y `d`.

**Resultado:** `data.frame` con columnas `texto_limpio`, `texto_tokens`, `n_tokens`, `n_ref_femenino`, `n_ref_masculino`, `n_ref_inclusivo`, `genero_mencionado`.

**Dónde se guarda:** Registra en bitácora; `stopwords_aplicadas.csv` se genera en `exportar_salidas`.

**Formato:** `data.frame`.

---

### `R/07_sentimientos.R` — Etapa 11

**Qué hace:** Cálculo de sentimientos con el diccionario propio (`config/sentimientos.json`, 15 sentimientos). Por mensaje y sentimiento activo: `sent_<nombre>` (coincidencias) y `pct_<nombre>` (100 × coincidencias / n_tokens). Maneja negación (ventana de una palabra), términos no negables, y emojis. Calcula `polaridad_score`, `polaridad_msg` (positivo/negativo/neutral) y `sentimiento_dominante`.

**Qué recibe:** `ctx` y `d`.

**Resultado:** `data.frame` con columnas `sent_*`, `pct_*`, `hits_total`, `n_negados`, `polaridad_score`, `polaridad_msg`, `sentimiento_dominante`.

**Dónde se guarda:** Registra en bitácora; los porcentajes se usan en `salida/mensajes_limpios.csv`.

**Formato:** `data.frame`.

**Funciones adicionales:** `resumen_periodo()`, `nivel_sentimiento()`, `resumen_genero()`.

---

### `R/08_salida.R` — Etapas 12 y 13

**Qué hace:** Rellena valores faltantes del dataset final con etiquetas explícitas ("original", "ninguno", 0, FALSE, etc.), valida consistencia (ids únicos, fechas presentes, porcentajes en [0,100], balance de filas), y exporta todos los archivos de salida.

**Qué recibe:** `ctx`, `d` y `dir_salida`.

**Resultado:** Escribe archivos CSV en `salida/` y devuelve lista con `limpio`, `excluidos`, `tokens`, `emojis_en_uso`.

**Dónde se guarda:**
- `salida/mensajes_limpios.csv` (CSV con BOM para Excel)
- `salida/mensajes_excluidos.csv`
- `salida/tokens.csv`
- `salida/stopwords_aplicadas.csv`
- `salida/emojis_en_uso.csv`
- `salida/emojis_pendientes.csv`

**Formato:** CSV (con BOM opcional para Excel).

---

### `R/09_periodos.R` — Parte 2: análisis por periodos

**Qué hace:** Funciones para cargar datos limpios, definir periodos (desde `config/periodos.csv` o rangos de fechas), filtrar por periodo, calcular nivel de sentimiento por periodo, serie mensual, TF-IDF mensual y comparación entre periodos, y nivel de mensaje vs periodo.

**Funciones clave:** `cargar_datos_analisis()`, `cargar_periodos()`, `resolver_periodo()`, `filtrar_periodo()`, `nivel_sentimiento()`, `niveles_por_periodo()`, `serie_sentimientos()`, `nivel_mensaje()`, `justificaciones_analisis()`.

**Qué recibe:** Rutas de `salida/` y `config/`, nombres de periodos o rangos de fechas.

**Resultado:** Data.frames con niveles de sentimiento, series temporales y comparaciones.

**Dónde se guarda:** No guarda directamente; se usa desde `R/16_analisis.R`.

**Formato:** `data.frame` / listas.

---

### `R/10_tfidf.R` — TF-IDF

**Qué hace:** Implementación manual de TF-IDF sobre `tokens.csv`. Un "documento" es un mes o un periodo. Funciones: `tfidf_docs()`, `tfidf_top()`, `tfidf_mensual()`, `tfidf_comparar()`, `idf_corpus()`, `mostrar_stopwords()`.

**Qué recibe:** `tokens` (data.frame con `token` y `doc`), `doc` (vector de documentos), parámetros `min_freq`, `suavizado`, `top`.

**Resultado:** Data.frame con columnas `doc`, `token`, `n`, `tf`, `idf`, `tf_idf`.

**Dónde se guarda:** No guarda directamente; se usa desde `R/16_analisis.R`.

**Formato:** `data.frame`.

---

### `R/11_shallow.R` — Shallow linguistic (udpipe)

**Qué hace:** Análisis lingüístico superficial con udpipe: etiqueta categorías gramaticales (upos), lemas y frases nominales sobre `texto_limpio`. Requiere el modelo de español (`modelos/spanish-gsd-ud-2.5-191206.udpipe`), descargado la primera vez si hay internet.

**Qué recibe:** `m` (data.frame con mensajes), `modelo` (opcional), `max_mensajes` (default 1500), `semilla`.

**Resultado:** Lista con `anotado` (tokens anotados), `upos` (distribución de categorías), `lemas` (top lemas por clase), `frases_nominales`.

**Dónde se guarda:** No guarda directamente; se usa desde `R/16_analisis.R`.

**Formato:** Lista R.

---

### `R/12_topicos.R` — Topic modeling (LDA)

**Qué hace:** Modelado de temas con LDA (Gibbs sampling) sobre `tokens.csv`. Los mensajes se agrupan por día o mes para tener suficientes palabras por documento. Devuelve beta (tópico × término), gamma (documento × tópico), etiquetas de tópicos, documento dominante por día/mes, y peso por mes.

**Qué recibe:** `tokens`, `k` (número de tópicos, default 6), `agrupar` ("dia" o "mes"), `min_tokens_doc`, `min_freq_termino`, `iter`, `semilla`, `top`.

**Resultado:** Lista con `modelo`, `beta`, `gamma`, `etiquetas`, `terminos`, `dominante`, `peso_mes`.

**Dónde se guarda:** No guarda directamente; se usa desde `R/16_analisis.R`.

**Formato:** Lista R + modelo topicmodels.

**Función adicional:** `topico_de_texto()` para aproximación de una oración nueva; `mensajes_con_topico()` para asignar tópico dominante a cada mensaje.

---

### `R/13_libreria.R` — Sentimientos de la librería (syuzhet/NRC)

**Qué hace:** Aplica el léxico NRC en español (vía paquete `syuzhet`) para obtener 8 emociones (Plutchik) + 2 polaridades. Calcula `lib_<emoción>` (100 × coincidencias / n_tokens) y `lib_polaridad`. Permite comparar con los 15 sentimientos propios.

**Qué recibe:** `m` (data.frame con mensajes), `texto` (columna, default "texto_limpio"), `idioma` ("spanish"), `max_mensajes`.

**Resultado:** `data.frame` con columnas `libn_*`, `lib_*`, `lib_polaridad`.

**Dónde se guarda:** No guarda directamente; se usa desde `R/16_analisis.R`.

**Formato:** `data.frame`.

**Funciones adicionales:** `nivel_libreria()`, `comparar_con_sin_libreria()`.

---

### `R/14_graficos.R` — Gráficos ggplot

**Qué hace:** Genera objetos `ggplot` para el dashboard: barras, barras comparar, tiempo, apilado, polar, araña, dispersión, Sankey (tópico → sentimiento), TF-IDF, tópicos, tópicos tiempo, upos, nivel mensaje, calor (día × hora). Requiere `ggplot2` y opcionalmente `ggalluvial`.

**Qué recibe:** Objetos de análisis (niveles, series, términos, etc.) y parámetros de título.

**Resultado:** Objetos `ggplot` listos para guardar como PNG.

**Dónde se guarda:** Los PNG se guardan vía `guardar_analisis()` en `salida/analisis/<periodo>/`.

**Formato:** Objetos `ggplot` (se exportan como PNG).

---

### `R/15_oracion.R` — Análisis de una oración

**Qué hace:** Analiza una sola oración pasando por exactamente el mismo preprocesamiento que el dataset (archivo temporal). Evalúa stopwords, shallow linguistic, TF-IDF (idf del corpus), topic modeling y sentimientos (propios + librería). Las bitácoras van a una carpeta temporal (no ensucian `bitacoras/` ni `salida/`).

**Qué recibe:** `texto` (string), `datos` (opcional, de `cargar_datos_analisis()`), `lda` (opcional), `modelo`, `usar_udpipe`, `usar_libreria`.

**Resultado:** Objeto de clase `analisis_oracion` con `texto`, `limpio`, `tokens`, `stopwords`, `shallow`, `tfidf`, `topicos`, `propios`, `polaridad`, `dominante`, `nivel_vs_corpus`, `libreria`.

**Dónde se guarda:** Carpeta temporal (no persiste).

**Formato:** Lista R con clase `analisis_oracion` y método `print.analisis_oracion`.

---

### `R/16_analisis.R` — Funciones principales para el dashboard

**Qué hace:** Orquesta el análisis de periodos y comparaciones. `analizar_periodo()` ejecuta nivel, serie, stopwords, TF-IDF, LDA, shallow, librería y registra experimentos. `comparar_periodos()` compara dos periodos. `graficos_periodo()` y `graficos_comparacion()` generan los gráficos. `guardar_analisis()` deja CSV y PNG en `salida/analisis/<periodo>/`.

**Qué recibe:** `datos` (de `cargar_datos_analisis()`), periodos, parámetros de cada análisis.

**Resultado:** Objetos `analisis_periodo` / `comparacion_periodos` con todos los resultados de análisis.

**Dónde se guarda:** `salida/analisis/<periodo>/` (CSV + PNG + `interpretacion.txt`).

**Formato:** Objetos R + archivos CSV/PNG/TXT en disco.

---

### `R/bitacora.R` — Motor de las dos bitácoras

**Qué hace:** Gestiona las dos bitácoras del proyecto:
1. `bitacoras/bitacora_limpia.xlsx` — pasos de la última ejecución exitosa (se sobrescribe). Hojas: "Bitacora" y "Parametros".
2. `bitacoras/bitacora_completa.xlsx` — todo lo que pasó (solo se agrega). Hojas: "Cambios", "Ejecuciones", "Pasos por ejecucion", "Experimentos".

**Funciones clave:** `registrar_paso()`, `registrar_hallazgo()`, `excluir()`, `exportar_bitacora()`, `vigilar_cambios()` (detecta cambios automáticos en código y diccionarios), `registrar_ejecucion()`, `registrar_experimento()`, `anotar_cambio()`, `escribir_csv()` (CSV con BOM para Excel).

**Qué recibe:** Contexto de ejecución (`ctx`), data.frames, parámetros de bitácora.

**Resultado:** Archivos Excel actualizados con trazabilidad completa de cada ejecución.

**Dónde se guarda:**
- `bitacoras/bitacora_limpia.xlsx`
- `bitacoras/bitacora_completa.xlsx`
- `bitacoras/_copia_de_control.json` (huella de archivos vigilados)

**Formato:** Excel (.xlsx) + JSON.

---

## 3. Archivos de configuración (`r/config/`)

| Archivo | Qué contiene | Formato |
|---|---|---|
| `sentimientos.json` | 15 sentimientos con palabras, raíces, polaridad y activo/inactivo | JSON |
| `emojis.csv` | Diccionario maestro de emojis (significado, sentimiento, polaridad, unicode) | CSV |
| `emoticonos.csv` | Mapeo de emoticonos de texto a emojis | CSV |
| `stopwords.csv` | Lista de stopwords con acción (eliminar/conservar) y justificación | CSV |
| `palabras_anuncio.csv` | Reglas de detección de publicidad (tipo, patrón, peso, parámetro) | CSV |
| `genero.csv` | Palabras de referencia de género (femenino/masculino) | CSV |
| `abreviaturas.csv` | Abreviaturas de chat y su forma normal | CSV |
| `codigos_materia.csv` | Prefijos válidos de códigos de materia | CSV |
| `periodos.csv` | Periodos predefinidos (nombre, inicio, fin) | CSV |
| `justificaciones_analisis.csv` | Justificaciones teóricas de cada análisis | CSV |

---

## 4. Archivos de datos y salida

### `r/data/`
| Archivo | Qué contiene | Formato |
|---|---|---|
| `result.json` | Dataset de entrada (exportación de Telegram, chats y mensajes) | JSON |
| `plumber_entrada.json` | Entrada usada por el endpoint `/preprocesar` de Plumber | JSON |

### `r/salida/`
| Archivo | Qué contiene | Formato |
|---|---|---|
| `mensajes_limpios.csv` | Dataset limpio (1 fila = 1 mensaje, sin vacíos) | CSV con BOM |
| `mensajes_excluidos.csv` | Todo lo excluido con motivo | CSV con BOM |
| `tokens.csv` | 1 fila = 1 token (para TF-IDF, n-gramas, LDA) | CSV con BOM |
| `stopwords_aplicadas.csv` | Qué stopword se eliminó/conservó y por qué | CSV con BOM |
| `emojis_en_uso.csv` | Frecuencia de emojis en texto y reacciones | CSV con BOM |
| `emojis_pendientes.csv` | Emojis sin traducir | CSV con BOM |
| `resumen.json` | Conteo clave de la ejecución (estado, leídos, limpios, excluidos, polaridad, etc.) | JSON |
| `analisis/` | Subcarpeta con resultados de análisis por periodo (CSV, PNG, TXT) | CSV/PNG/TXT |

### `r/bitacoras/`
| Archivo | Qué contiene | Formato |
|---|---|---|
| `bitacora_limpia.xlsx` | Pasos de la última ejecución exitosa | Excel |
| `bitacora_completa.xlsx` | Cambios, ejecuciones, pasos y experimentos | Excel |
| `_copia_de_control.json` | Huella MD5 de archivos vigilados | JSON |

### `r/modelos/`
| Archivo | Qué contiene | Formato |
|---|---|---|
| `spanish-gsd-ud-2.5-191206.udpipe` | Modelo de español de udpipe para shallow linguistic | Binario (udpipe) |

---

## 5. Flujo de ejecución y comandos para ejecutarlo

### Requisitos previos

Instalar R (>= 4.2) y los paquetes necesarios. Desde una terminal de R o RStudio:

```r
install.packages(c("jsonlite", "readr", "stringi", "openxlsx", "digest",
                   "plumber", "httr", "udpipe", "topicmodels", "slam",
                   "ggplot2", "ggalluvial", "syuzhet"))
```

Para el modelo de español de udpipe (usado en `R/11_shallow.R`), se descarga automáticamente la primera vez que se ejecuta `shallow_linguistic()` si hay internet, o se puede usar el archivo ya presente en `r/modelos/spanish-gsd-ud-2.5-191206.udpipe`.

---

### Opción A: Ejecutar desde la terminal (PowerShell / CMD)

Todos los comandos se ejecutan desde la carpeta `r/` del proyecto (`C:\CODIGO\AnSent\r`).

#### Paso 1 — Cargar el proyecto y ejecutar el preprocesamiento completo

```powershell
# Desde la carpeta r/
Rscript cargar_proyecto.R
```

```powershell
# Ejecutar el preprocesamiento sobre el dataset de entrada por defecto
Rscript ejecutar.R data/result.json --consola resumen --sin-bom
```

O con opciones adicionales:

```powershell
Rscript ejecutar.R data/result.json `
  --inicio 2026-05-01 `
  --fin 2026-08-31 `
  --responsable "Nombre" `
  --salida salida `
  --config config `
  --bitacoras bitacoras `
  --umbral 4 `
  --consola resumen `
  --sin-bom
```

**Resultado:** Se generan los archivos en `salida/`:
- `mensajes_limpios.csv`
- `mensajes_excluidos.csv`
- `tokens.csv`
- `stopwords_aplicadas.csv`
- `emojis_en_uso.csv`
- `emojis_pendientes.csv`
- `resumen.json`

Y en `bitacoras/`:
- `bitacora_limpia.xlsx`
- `bitacora_completa.xlsx`
- `_copia_de_control.json`

La última línea impresa en consola es un JSON con el resumen de la ejecución.

#### Paso 2 — Ejecutar análisis por periodo (Parte 2)

Desde una sesión de R interactiva (RStudio o `R`):

```r
source("cargar_proyecto.R")
datos <- cargar_datos_analisis("salida")

# Analizar un periodo específico
a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))

# Guardar resultados (CSV + PNG + interpretacion.txt)
guardar_analisis(a, dir = "salida/analisis")
```

También se puede usar un periodo definido en `config/periodos.csv`:

```r
a <- analizar_periodo(datos, "todo_2023")
guardar_analisis(a, dir = "salida/analisis")
```

#### Paso 3 — Comparar dos periodos

```r
cmp <- comparar_periodos(datos, "todo_2023", "todo_2024")
guardar_analisis(cmp, dir = "salida/analisis")
```

#### Paso 4 — Analizar una sola oración (flujo independiente)

```r
source("cargar_proyecto.R")
datos <- cargar_datos_analisis("salida")

# Analizar una oración viva
o <- analizar_oracion("Hola, no entiendo el laboratorio de INF 111, ayuda por favor",
                      datos = datos)
print(o)
```

Si se quiere incluir topic modeling, se debe pasar también el modelo LDA:

```r
tk <- datos$tokens
lda <- topicos_lda(tk, k = 6, agrupar = "dia")
o <- analizar_oracion("Hola, no entiendo el laboratorio de INF 111, ayuda por favor",
                      datos = datos, lda = lda)
print(o)
```

#### Paso 5 — Arrancar la API Plumber (opcional)

Desde la terminal, en la carpeta `r/`:

```powershell
Rscript plumber_api.R
```

La API queda escuchando en `http://0.0.0.0:8765`. Endpoints disponibles:

| Método | URL | Descripción |
|---|---|---|
| GET | `http://localhost:8765/__ping__` | Salud de la API |
| GET | `http://localhost:8765/dataset/summary` | Resumen del dataset |
| GET | `http://localhost:8765/charts` | Definiciones JSON de gráficos (ECharts) |
| POST | `http://localhost:8765/preprocesar` | Ejecutar preprocesamiento completo |

---

### Opción B: Ejecutar desde RStudio

1. Abrir el proyecto `R_AnSent.Rproj` en RStudio.
2. Abrir la consola de RStudio.
3. Ejecutar:

```r
source("cargar_proyecto.R")
```

4. Ejecutar el preprocesamiento:

```r
res <- preprocesar("data/result.json", consola = "didactico")
```

O con recorte de fechas:

```r
res <- preprocesar("data/result.json",
                   fecha_inicio = "2026-05-01",
                   fecha_fin = "2026-08-31",
                   responsable = "Nombre",
                   consola = "resumen")
```

5. Para análisis por periodo (Parte 2):

```r
datos <- cargar_datos_analisis("salida")
a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))
guardar_analisis(a, dir = "salida/analisis")
```

6. Para arrancar la API desde RStudio:

```r
source("plumber_api.R")
```

---

### Resumen de comandos clave

| Tarea | Comando | Archivo involucrado |
|---|---|---|
| Cargar herramientas del proyecto | `source("cargar_proyecto.R")` | `cargar_proyecto.R` |
| Preprocesar desde terminal | `Rscript ejecutar.R data/result.json --consola resumen` | `ejecutar.R` |
| Preprocesar desde R interactivo | `preprocesar("data/result.json")` | `R/00_main.R` |
| Cargar datos limpios para análisis | `cargar_datos_analisis("salida")` | `R/09_periodos.R` |
| Analizar un periodo | `analizar_periodo(datos, c("inicio","fin"))` | `R/16_analisis.R` |
| Comparar dos periodos | `comparar_periodos(datos, "A", "B")` | `R/16_analisis.R` |
| Guardar análisis (CSV + PNG) | `guardar_analisis(a, dir = "salida/analisis")` | `R/16_analisis.R` |
| Analizar una oración | `analizar_oracion("texto", datos = datos)` | `R/15_oracion.R` |
| Generar gráficos ggplot | `graficos_periodo(a)` o `graficos_comparacion(cmp)` | `R/14_graficos.R` |
| Arrancar API Plumber | `Rscript plumber_api.R` | `plumber_api.R` |
| Instalar paquetes base | `install.packages(c("jsonlite","readr","stringi","openxlsx","digest"))` | `cargar_proyecto.R` |
| Instalar paquetes de análisis | `install.packages(c("udpipe","topicmodels","slam","ggplot2","ggalluvial","syuzhet","plumber","httr"))` | Varios scripts de `R/` |

---

### Estructura de carpetas de salida tras ejecutar el flujo completo

```
r/
├── salida/
│   ├── mensajes_limpios.csv
│   ├── mensajes_excluidos.csv
│   ├── tokens.csv
│   ├── stopwords_aplicadas.csv
│   ├── emojis_en_uso.csv
│   ├── emojis_pendientes.csv
│   ├── resumen.json
│   └── analisis/
│       └── <periodo>/
│           ├── niveles.csv
│           ├── serie_mensual.csv
│           ├── tfidf.csv
│           ├── libreria_niveles.csv
│           ├── topicos_terminos.csv      (si se ejecuta LDA)
│           ├── topicos_por_mes.csv       (si se ejecuta LDA)
│           ├── shallow_categorias.csv    (si se ejecuta shallow)
│           ├── shallow_lemas.csv         (si se ejecuta shallow)
│           ├── interpretacion.txt
│           ├── barras.png
│           ├── tiempo.png
│           ├── apilado.png
│           └── ... (otros PNG según análisis)
├── bitacoras/
│   ├── bitacora_limpia.xlsx
│   ├── bitacora_completa.xlsx
│   └── _copia_de_control.json
└── data/
    ├── result.json          (entrada)
    └── plumber_entrada.json (usado por Plumber)
```

