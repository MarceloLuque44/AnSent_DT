# Documentación detallada de los scripts de `r/R/`

Este documento describe cada script del directorio `r/R/` con su código fuente, explicación de funciones clave, fragmentos de código comentados y ejemplos de uso.

---

# Tabla de contenidos

1. [00_main.R — `preprocesar()` (orquestador del pipeline)](#00_mainr)
2. [01_lectura.R — Lectura de archivos y diccionarios](#01_lecturarr)
3. [02_estructura.R — Etapa 2: Normalización de estructura y formatos](#02_estructurarr)
4. [03_calidad.R — Etapas 3-5: Duplicados, valores faltantes y outliers](#03_calidadr)
5. [04_publicidad.R — Etapa 6: Detección de publicidad](#04_publicidadr)
6. [05_emojis.R — Etapa 7: Emojis](#05_emojisr)
7. [06_texto.R — Etapas 8-10: Limpieza de texto, género, tokenización y stopwords](#06_textor)
8. [07_sentimientos.R — Etapa 11: Sentimientos con diccionario propio](#07_sentimientosr)
9. [08_salida.R — Etapas 12-13: Valores faltantes, validación y exportación](#08_salidar)
10. [09_periodos.R — Parte 2: Periodos y nivel de sentimientos](#09_periodosr)
11. [10_tfidf.R — TF-IDF y stopwords](#10_tfidfr)
12. [11_shallow.R — Shallow linguistic con udpipe](#11_shallowr)
13. [12_topicos.R — Topic modeling LDA](#12_topicosr)
14. [13_libreria.R — Sentimientos de la librería syuzhet](#13_libreria)
15. [14_graficos.R — 25 gráficos con ggplot2](#14_graficosr)
16. [15_oracion.R — Análisis de una sola oración](#15_oracionr)
17. [16_analisis.R — Funciones principales de la parte 2](#16_analisisr)
18. [18_top25.R — Las 25 mejores gráficas autónomas](#18_top25r)
19. [bitacora.R — Motor de las dos bitácoras](#bitacorar)

---

<a name="00_mainr"></a>
## 1. `00_main.R` — `preprocesar()`: Orquestador del pipeline

Este archivo contiene la función principal `preprocesar()` que ejecuta todo el pipeline en una secuencia de 13 etapas. Es el punto de entrada tanto desde R console como desde la API de Plumber.

### Firma de la función

```r
preprocesar <- function(ruta_archivo,
                        fecha_inicio = NULL, fecha_fin = NULL,
                        responsable = Sys.getenv("RESPONSABLE", ""),
                        dir_config = "config", dir_salida = file.path("client", "src", "views", "salida"),
                        dir_bitacoras = "bitacoras",
                        sentimientos_activos = NULL,
                        excluir_publicidad = TRUE, umbral_publicidad = 4,
                        anonimizar_autor = TRUE, min_chars_duplicado = 25,
                        nuevos_emojis = c("marcar", "detener"),
                        consola = c("didactico", "resumen", "silencioso"),
                        csv_para_excel = TRUE,
                        preguntar_cambios = interactive(), motivo_cambios = NULL,
                        chat = NULL) {
```

### Explicación de los parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `ruta_archivo` | (requerido) | Ruta al archivo de entrada (result.json de Telegram o CSV) |
| `fecha_inicio` / `fecha_fin` | `NULL` | Rango de fechas opcional para recortar el dataset |
| `responsable` | `Sys.getenv("RESPONSABLE", "")` | Nombre de quien ejecuta, para la bitácora |
| `dir_config` | `"config"` | Carpeta con los diccionarios de configuración |
| `dir_salida` | `"client/src/views/salida"` | Carpeta donde se escriben los CSV de salida |
| `dir_bitacoras` | `"bitacoras"` | Carpeta de las bitácoras de Excel |
| `sentimientos_activos` | `NULL` | Vector de nombres de sentimientos activos; si NULL, usa todos los del JSON |
| `excluir_publicidad` | `TRUE` | Si excluir mensajes detectados como publicidad |
| `umbral_publicidad` | `4` | Puntaje mínimo para considerar un mensaje como publicidad |
| `anonimizar_autor` | `TRUE` | Si reemplazar nombres reales por seudónimos (hash MD5) |
| `min_chars_duplicado` | `25` | Mínimo de caracteres para considerar un mensaje como duplicado |
| `consola` | `"silencioso"` | Nivel de verbosidad: "didactico", "resumen" o "silencioso" |

### Cuerpo de la función (fragmentos clave)

**Inicialización y validación de argumentos:**

```r
  nuevos_emojis <- match.arg(nuevos_emojis)
  consola <- match.arg(consola)
  dir.create(dir_salida, recursive = TRUE, showWarnings = FALSE)
  old <- options(sentimientos.bom = csv_para_excel)   # BOM = Excel abre bien tildes y emojis
  on.exit(options(old), add = TRUE)
```

- `match.arg()` valida que `nuevos_emojis` y `consola` sean valores válidos.
- `dir.create()` asegura que exista la carpeta de salida.
- `options()` y `on.exit()` configuran y restauran la opción BOM para archivos CSV (Excel necesita BOM para leer tildes y emojis correctamente).

**Cálculo del MD5 del archivo de entrada:**

```r
  t_ini <- Sys.time()
  md5_entrada <- tryCatch(digest::digest(file = ruta_archivo, algo = "md5"), error = function(e) "")
```

- Guarda el tiempo de inicio para calcular la duración al final.
- Calcula el hash MD5 del archivo para detectar si es el mismo dataset o uno nuevo (útil para la bitácora).

**Detección de cambios en código y diccionarios:**

```r
  try(vigilar_cambios(dir_bitacoras, dir_config, responsable, preguntar_cambios, motivo_cambios), silent = FALSE)
```

- Llama a `vigilar_cambios()` (definida en `bitacora.R`) que compara los archivos actuales con la última versión guardada y registra cualquier modificación.

**Configuración de seguimiento de progreso:**

```r
  prog <- new.env()                      # seguimiento: en qué paso estamos
  prog$paso <- "inicio"; prog$ctx <- NULL
  etapa <- function(titulo) {
    prog$paso <- titulo
    if (consola == "didactico") cat("\n", strrep("=", 98), "\n  ", titulo, "\n", strrep("=", 98), "\n", sep = "")
    else if (consola == "resumen") message(format(Sys.time(), "%H:%M:%S"), "  ", titulo)
  }
```

- Crea un entorno `prog` para rastrear en qué etapa se encuentra el proceso.
- La función `etapa()` imprime un encabezado visual si el modo es "didactico" o un mensaje simple si es "resumen".

**Almacenamiento de parámetros:**

```r
  params <- list(ruta_archivo = ruta_archivo, archivo_md5 = md5_entrada,
                 fecha_inicio = fecha_inicio, fecha_fin = fecha_fin,
                 responsable = responsable, dir_config = dir_config, dir_salida = dir_salida,
                 dir_bitacoras = dir_bitacoras,
                 sentimientos_activos = sentimientos_activos %||% "(todos los activos del json)",
                 excluir_publicidad = excluir_publicidad, umbral_publicidad = umbral_publicidad,
                 anonimizar_autor = anonimizar_autor, min_chars_duplicado = min_chars_duplicado,
                 nuevos_emojis = nuevos_emojis, consola = consola, csv_para_excel = csv_para_excel)
```

- Guarda todos los parámetros en una lista `params` que se almacenará en el contexto `ctx` para que todas las etapas posteriores puedan acceder a ellos.

**Función interna `cuerpo()` — las 13 etapas:**

```r
  cuerpo <- function() {
    etapa("Cargando diccionarios (config/)")
    cfg <- cargar_config(dir_config, sentimientos_activos)
    ctx <- nuevo_ctx(params, cfg)
    ...
  }
```

1. **Carga diccionarios:** Llama a `cargar_config()` (de `01_lectura.R`) para leer todos los archivos de `config/`.
2. **Crea contexto:** `nuevo_ctx()` (de `bitacora.R`) crea el entorno `ctx` con parámetros y configuración.
3. **ETAPA 1:** `auditar_entrada()` — perfilado inicial.
4. **ETAPA 2:** `estructurar()` — normalización de fechas, autores, variables descriptivas.
5. **ETAPAS 3-5:** `control_calidad()` — duplicados, valores faltantes, outliers.
6. **ETAPA 6:** `detectar_publicidad()` — detección de anuncios.
7. **ETAPA 7:** `procesar_emojis()` — extracción y traducción de emojis.
8. **ETAPA 8:** `normalizar_texto()` — limpieza de texto.
9. **ETAPA 9:** `marcar_genero()` — referencias de género.
10. **ETAPA 10:** `tokenizar_y_filtrar()` — tokenización y stopwords.
11. **ETAPA 11:** `calcular_sentimientos()` — sentimientos con diccionario propio.
12. **ETAPA 12:** `rellenar_nulos()` — valores faltantes finales.
13. **ETAPA 13:** `validar_consistencia()` — validaciones finales.

**Exportación y resumen:**

```r
    out <- exportar_salidas(ctx, d, dir_salida)
    b <- exportar_bitacora(ctx, dir_bitacoras, parametros_df(ctx))
```

- `exportar_salidas()` escribe los CSV de salida.
- `exportar_bitacora()` escribe `bitacora_limpia.xlsx` con los pasos de la ejecución.

**Manejo de errores:**

```r
  res <- tryCatch(cuerpo(), error = function(e) {
    anotar("error", conditionMessage(e))
    ...
    stop(conditionMessage(e), call. = FALSE)
  })
```

- Toda la ejecución está envuelta en `tryCatch` para registrar errores en la bitácora completa antes de detenerse.

### Ejemplo de uso

```r
source("cargar_proyecto.R")
res <- preprocesar("data/result.json",
                   fecha_inicio = "2023-01-01",
                   fecha_fin = "2023-03-31",
                   responsable = "analista",
                   consola = "didactico")
```

---

<a name="01_lecturarr"></a>
## 2. `01_lectura.R` — Lectura de archivos y diccionarios

Este script maneja la lectura del archivo de entrada (JSON de Telegram o CSV), la carga de diccionarios de configuración y la auditoría inicial (Etapa 1).

### Función `aplanar_texto()`

```r
aplanar_texto <- function(t) {
  if (is.null(t)) return(list(texto = "", era_lista = FALSE))
  if (is.character(t)) return(list(texto = paste(t, collapse = ""), era_lista = FALSE))
  partes <- vapply(t, function(p) {
    if (is.character(p)) paste(p, collapse = "")
    else if (is.list(p) && !is.null(p$text)) as.character(p$text)
    else ""
  }, character(1))
  list(texto = paste(partes, collapse = ""), era_lista = TRUE)
}
```

**Explicación:**
- En el JSON de Telegram, el campo `text` puede ser un string simple o una lista de fragmentos (cuando hay enlaces, negritas, etc.).
- Si es `NULL`, devuelve texto vacío.
- Si ya es `character`, lo une con `paste()`.
- Si es una lista, itera sobre cada elemento extrayendo el texto o el campo `$text` si es una sub-lista.
- Devuelve una lista con el texto plano y un booleano indicando si era originalmente una lista.

### Función `leer_entrada()`

```r
leer_entrada <- function(ruta, chat = NULL) {
  if (!file.exists(ruta)) stop("No existe el archivo: ", ruta,
                               "\n  (carpeta de trabajo actual: ", getwd(), ")")
  ext <- tolower(tools::file_ext(ruta))
  if (ext == "json") leer_telegram_json(ruta, chat)
  else if (ext %in% c("csv", "tsv")) leer_csv_generico(ruta)
  else stop("Formato no soportado (usa el .json de Telegram o un .csv): ", ext)
}
```

- Valida que el archivo exista.
- Detecta la extensión y despacha al lector correspondiente.

### Función `leer_telegram_json()`

```r
leer_telegram_json <- function(ruta, chat = NULL) {
  j <- jsonlite::fromJSON(ruta, simplifyVector = FALSE)
  if (!is.null(j$chats)) {
    lista <- j$chats$list
    nombres <- vapply(lista, function(c) c$name %||% "(sin nombre)", character(1))
    if (is.null(chat)) {
      if (length(lista) == 1) chat <- 1
      else stop("El archivo tiene varios chats: ... Usa preprocesar(..., chat = <número>).")
    }
    j <- lista[[chat]]
  }
  ...
}
```

- Lee el JSON con `simplifyVector = FALSE` para preservar listas anidadas.
- Si el archivo tiene múltiples chats (`j$chats`), permite seleccionar uno por número o nombre.
- Extrae el campo `$messages` del chat seleccionado.

**Construcción del data.frame:**

```r
  txt <- lapply(msgs, function(m) aplanar_texto(m$text))
  ...
  data.frame(
    id_mensaje      = vapply(msgs, function(m) as.numeric(g(m, "id")), numeric(1)),
    tipo_registro   = chr(function(m) g(m, "type")),
    fecha_raw       = chr(function(m) g(m, "date")),
    autor_raw       = chr(function(m) g(m, "from")),
    ...
    texto_raw       = vapply(txt, function(x) x$texto, character(1)),
    ...
    stringsAsFactors = FALSE
  )
```

- Usa `vapply()` para extraer cada campo de forma segura, devolviendo `NA` si el campo no existe.
- `aplanar_texto()` se aplica a cada mensaje para obtener `texto_raw`.

### Función `leer_csv_generico()`

```r
leer_csv_generico <- function(ruta) {
  d <- readr::read_delim(ruta, delim = if (grepl("\\.tsv$", ruta, ignore.case = TRUE)) "\t" else ",",
                         col_types = readr::cols(.default = "c"), progress = FALSE,
                         show_col_types = FALSE)
  names(d) <- tolower(names(d))
  pick <- function(opts) { h <- intersect(opts, names(d)); if (length(h)) d[[h[1]]] else NULL }
  txt <- pick(c("texto_original", "text", "texto", "mensaje", "message"))
  fec <- pick(c("fecha_hora", "date", "fecha", "datetime"))
  ...
}
```

- Detecta automáticamente si es CSV o TSV por la extensión.
- Lee todas las columnas como caracter para evitar problemas de tipos.
- La función `pick()` busca nombres de columnas alternativos (ej. "text" o "texto" o "mensaje").

### Función `cargar_config()`

```r
cargar_config <- function(dir_config, sentimientos_activos = NULL) {
  ruta <- function(f) file.path(dir_config, f)
  req <- c("sentimientos.json", "emojis.csv", "stopwords.csv", "palabras_anuncio.csv", "genero.csv",
           "abreviaturas.csv", "emoticonos.csv", "codigos_materia.csv")
  falta <- req[!file.exists(ruta(req))]
  if (length(falta)) stop("Faltan archivos en '", dir_config, "': ", paste(falta, collapse = ", "), ...)
  
  sj <- jsonlite::fromJSON(ruta("sentimientos.json"), simplifyVector = TRUE)$sentimientos
  if (!is.null(sentimientos_activos)) {
    desconocidos <- setdiff(sentimientos_activos, sj$nombre)
    if (length(desconocidos)) stop("Sentimientos que no existen en el diccionario: ...")
    sj$activo <- sj$nombre %in% sentimientos_activos
  }
  sj <- sj[order(sj$orden), ]
  
  leer <- function(f) readr::read_csv(ruta(f), col_types = readr::cols(.default = "c"),
                                      progress = FALSE, na = character())
  emo <- leer("emojis.csv")
  ...
  list(sent = sj, emojis = emo, stop = leer("stopwords.csv"), anuncio = leer("palabras_anuncio.csv"),
       genero = leer("genero.csv"), abrev = leer("abreviaturas.csv"),
       emoticonos = leer("emoticonos.csv"), materias = leer("codigos_materia.csv"), hashes = hashes, dir = dir_config)
}
```

**Explicación clave:**
1. Valida que existan los 8 archivos requeridos en `config/`.
2. Lee `sentimientos.json` y opcionalmente filtra por `sentimientos_activos` (si se pasa, solo esos se marcan como `activo = TRUE`).
3. Ordena por el campo `orden`.
4. Lee cada archivo CSV con `readr::read_csv()` como caracteres.
5. Valida que los sentimientos de los emojis existan en el diccionario de sentimientos.
6. Calcula hashes MD5 de cada archivo para la bitácora.
7. Devuelve una lista con todos los diccionarios cargados.

### Función `auditar_entrada()`

Etapa 1: realiza auditoría y perfilado inicial sin modificar los datos. Registra hallazgos en la bitácora sobre volumen, rango de fechas, tipos de registro, mensajes sin texto, autores nulos, mensajes reenviados, etc.

---

<a name="02_estructurarr"></a>
## 3. `02_estructura.R` — Etapa 2: Normalización de estructura y formatos

Contiene la función `estructurar()` que normaliza el texto, fechas, separa mensajes de servicio, maneja stickers, recorta por periodo, anonimiza autores y deriva variables descriptivas.

### Patrones regex definidos

```r
RX_URL  <- "(?i:https?://|www\\.|t\\.me/)\\S+"
RX_MAIL <- "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
RX_MENC <- "(?<![A-Za-z0-9._%+-])@[A-Za-z0-9_]{3,}"
RX_TEL  <- "(?<![0-9])(?:\\+?591[ -]?)?[67][0-9]{7}(?![0-9])|\\+[0-9][0-9 -]{7,}[0-9]"
RX_HASH <- "#[\\p{L}\\p{N}_]+"
```

- `RX_URL`: Detecta URLs (http, https, www, t.me).
- `RX_MAIL`: Detecta direcciones de correo electrónico.
- `RX_MENC`: Detecta menciones de Telegram (@usuario).
- `RX_TEL`: Detecta números de teléfono (formato boliviano e internacional).
- `RX_HASH`: Detecta hashtags.

### Función `estructurar()`

```r
estructurar <- function(ctx, d) {
  M <- "2. Normalización de estructura y formatos"
  p <- ctx$p
  
  # ── 2.1 Unicode ────────────────────────────────────────────────────────────────
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_raw -> texto_original", atributo = "texto",
    problema = "Codificación y normalización Unicode",
    accion = "Se convirtió el texto a UTF-8 y se normalizó a forma NFC...",
    justificacion = "Una misma palabra con tilde puede estar escrita de dos formas internas distintas...",
    ejemplo_col = "texto_original", texto_ref = "texto_raw",
    codigo = {
      datos$texto_original <- stringi::stri_trans_nfc(enc2utf8(datos$texto_raw))
      datos$texto_original[is.na(datos$texto_original)] <- ""
    })
  
  # ── 2.2 Fechas ─────────────────────────────────────────────────────────────────
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "fecha_raw -> fecha_hora, fecha, anio, mes, anio_mes, trimestre, dia_semana, hora",
    atributo = "fecha", problema = "Fecha como texto ISO",
    accion = "Se convirtió la fecha de texto a fecha-hora (hora local de La Paz)...",
    justificacion = "El análisis por periodos y las gráficas de tendencia necesitan fechas reales...",
    ejemplo_col = "fecha_hora", texto_ref = "fecha_raw",
    codigo = {
      f <- as.POSIXct(strptime(datos$fecha_raw, "%Y-%m-%dT%H:%M:%S", tz = "America/La_Paz"))
      datos$fecha_hora <- f
      datos$fecha <- as.Date(format(f, "%Y-%m-%d"))
      datos$anio <- as.integer(format(f, "%Y"))
      datos$mes <- as.integer(format(f, "%m"))
      datos$anio_mes <- format(f, "%Y-%m")
      datos$trimestre <- paste0(datos$anio, "-T", (datos$mes - 1) %/% 3 + 1)
      datos$dia_semana <- c("domingo", "lunes", "martes", "miércoles", "jueves",
                            "viernes", "sábado")[as.POSIXlt(f)$wday + 1]
      datos$hora <- as.integer(format(f, "%H"))
    })
  ...
}
```

**Puntos clave:**
- **Unicode:** Convierte a UTF-8 y normaliza a NFC (forma compuesta) para que "á" sea siempre el mismo código interno.
- **Fechas:** Usa `strptime()` con zona horaria "America/La_Paz". La columna `fecha` (Date) se calcula desde `fecha_hora` para evitar el problema de que `as.Date()` en UTC desplace mensajes de la noche al día siguiente.
- **Autores:** Si `anonimizar_autor = TRUE`, reemplaza nombres por seudónimos `U<6 primeros caracteres del MD5>`.
- **Variables descriptivas:** Calcula `n_caracteres`, `n_palabras`, `n_enlaces`, `n_hashtags`, `n_menciones`, `tiene_telefono`, `n_emojis`, `emojis_lista`, `es_respuesta`, `reenviado`, `responde_a`.

**Recorte por periodo:**

```r
  if (!is.null(p$fecha_inicio) || !is.null(p$fecha_fin)) {
    ini <- if (!is.null(p$fecha_inicio)) as.Date(p$fecha_inicio) else as.Date("1900-01-01")
    fin <- if (!is.null(p$fecha_fin)) as.Date(p$fecha_fin) else as.Date("2999-12-31")
    ...
    codigo = {
      fuera <- is.na(datos$fecha) | datos$fecha < ini | datos$fecha > fin
      excluir(ctx, datos[fuera, ], "Fuera del periodo seleccionado")
      datos <- datos[!fuera, ]
    })
  }
```

Los mensajes fuera del rango se excluyen y se registran en `mensajes_excluidos.csv`.

---

<a name="03_calidadr"></a>
## 4. `03_calidad.R` — Etapas 3-5: Duplicados, valores faltantes y outliers

Función principal: `control_calidad(ctx, d)`.

### Etapa 3: Duplicados

```r
  # ── 3.1 Duplicados ─────────────────────────────────────────────────────────────
  M <- "3. Gestión de duplicados"
  minc <- ctx$p$min_chars_duplicado
  
  registrar_hallazgo(ctx, metodologia = M, campo = "texto_original, autor_id", atributo = "texto",
    problema = "Repeticiones cortas (saludos, 'gracias', 'jaja')",
    accion = sprintf("Se contaron mensajes cortos (menos de %d caracteres) repetidos por el mismo autor. NO se eliminan.", minc),
    justificacion = "Repetir 'gracias' o 'jaja' es una expresión genuina de sentimiento; borrarlo subestimaría la gratitud o la alegría.",
    valor = sum(duplicated(paste(d$autor_id, stringi::stri_trans_tolower(stringi::stri_trim_both(d$texto_original)), sep = "||")) &
                  d$n_caracteres < minc),
    base = nrow(d))
  
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original, autor_id", atributo = "texto",
    problema = "Duplicado exacto (mismo autor y mismo texto)",
    accion = sprintf("Se eliminaron las repeticiones exactas de un mismo autor con %d o más caracteres; se conserva la primera aparición.", minc),
    justificacion = "Un mensaje largo repetido (spam o reposteo del mismo anuncio) infla artificialmente frecuencias y TF-IDF sin aportar un sentimiento nuevo.",
    codigo = {
      clave <- paste(datos$autor_id, stringi::stri_trans_tolower(stringi::stri_trim_both(datos$texto_original)), sep = "||")
      dup <- duplicated(clave) & datos$n_caracteres >= minc
      excluir(ctx, datos[dup, ], sprintf("Duplicado exacto (mismo autor y texto, >= %d caracteres)", minc))
      datos <- datos[!dup, ]
    })
```

**Regla:** Los mensajes cortos (< min_chars) repetidos NO se eliminan (pueden ser expresión genuina). Los mensajes largos (>= min_chars) repetidos por el mismo autor SÍ se eliminan (probable spam).

### Etapa 4: Valores faltantes

```r
  # ── 4.1 Valores faltantes ──────────────────────────────────────────────────────
  M <- "4. Tratamiento de valores faltantes"
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "texto_original", atributo = "texto",
    problema = "Mensajes sin texto (solo multimedia)",
    accion = "Se separaron los mensajes sin texto (foto, video, archivo, nota de voz...). Quedan en mensajes_excluidos.csv.",
    justificacion = "El análisis de sentimiento es textual y no hay imputación válida para un texto ausente; se descarta la fila pero se documenta.",
    codigo = {
      vacio <- !nzchar(stringi::stri_trim_both(datos$texto_original))
      tb <- table(datos$tipo_contenido[vacio])
      ctx$nota <- paste0("Detalle por tipo: ", paste(names(tb), tb, sep = "=", collapse = ", "), ".")
      excluir(ctx, datos[vacio, ], "Sin texto (solo foto, video, archivo, audio u otro contenido multimedia)")
      datos <- datos[!vacio, ]
    })
```

Mensajes sin texto (solo multimedia) se excluyen del dataset limpio.

### Etapa 5: Outliers

```r
  # ── 5.1 Outliers de longitud ───────────────────────────────────────────────────
  M <- "5. Detección y tratamiento de outliers"
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "n_caracteres -> outlier_longitud", atributo = "numérica",
    problema = "Mensajes de longitud extrema",
    accion = "Se marcaron como outlier los mensajes cuya longitud supera Q3 + 1.5*IQR (calculado sobre log(1 + caracteres)). Se CONSERVAN, solo se marcan.",
    justificacion = "La longitud es muy asimétrica, por eso se usa escala logarítmica...",
    ejemplo_col = "outlier_longitud",
    codigo = {
      lg <- log1p(datos$n_caracteres)
      q <- stats::quantile(lg, c(0.25, 0.75), names = FALSE)
      lim <- q[2] + 1.5 * (q[2] - q[1])
      datos$outlier_longitud <- lg > lim
      ctx$nota <- sprintf("Umbral calculado: %d caracteres.", round(expm1(lim)))
    })
  
  # ── 5.2 Outliers: ráfagas ──────────────────────────────────────────────────────
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "autor_id, fecha_hora -> outlier_rafaga", atributo = "numérica",
    problema = "Ráfagas de mensajes (posible spam)",
    accion = sprintf("Se marcaron los mensajes de un autor que envió %d o más mensajes en el mismo minuto. Se CONSERVAN, solo se marcan.", rafaga_min),
    justificacion = "Una ráfaga puede ser un debate real o spam; marcarla permite revisarla sin perder datos.",
    ejemplo_col = "outlier_rafaga",
    codigo = {
      k <- paste(datos$autor_id, format(datos$fecha_hora, "%Y-%m-%d %H:%M"))
      n_k <- stats::ave(seq_along(k), k, FUN = length)
      datos$outlier_rafaga <- n_k >= rafaga_min
    })
```

**Nota importante:** Los outliers se MARCAN pero NO se eliminan. La decisión de excluirlos se deja para la etapa de publicidad (etapa 6).

---

<a name="04_publicidadr"></a>
## 5. `04_publicidad.R` — Etapa 6: Detección de publicidad

Función principal: `detectar_publicidad(ctx, d)`.

### Función `puntaje_publicidad()`

```r
puntaje_publicidad <- function(d, reglas) {
  n <- nrow(d)
  tn <- stringi::stri_trans_general(stringi::stri_trans_tolower(d$texto_original), "Latin-ASCII")
  score <- numeric(n)
  motivos <- character(n)
  empieza_emoji <- stringi::stri_detect_regex(d$texto_original, "^\\s*[\\p{Extended_Pictographic}]")
  
  for (i in seq_len(nrow(reglas))) {
    r <- reglas[i, ]
    peso <- as.numeric(r$peso)
    par <- suppressWarnings(as.numeric(r$parametro))
    hit <- switch(r$tipo,
      estructura = switch(r$patron,
        reenviado     = d$reenviado,
        enlace        = d$n_enlaces > 0,
        largo         = d$n_caracteres >= par,
        muchos_emojis = d$n_emojis >= par,
        empieza_emoji = empieza_emoji,
        hashtag       = d$n_hashtags > 0,
        telefono      = d$tiene_telefono,
        rep(FALSE, n)),
      frase = stringi::stri_detect_regex(tn, paste0("(?<![a-z0-9])", .esc(stringi::stri_trans_general(tolower(r$patron), "Latin-ASCII")))),
      regex = stringi::stri_detect_regex(tn, r$patron),
      rep(FALSE, n))
    hit[is.na(hit)] <- FALSE
    score <- score + hit * peso
    motivos[hit] <- paste0(motivos[hit], ifelse(nzchar(motivos[hit]), "; ", ""), r$patron)
  }
  list(puntaje = score, motivo = motivos)
}
```

**Explicación:**
- Cada regla en `config/palabras_anuncio.csv` tiene: `tipo` (estructura/frase/regex), `patron`, `peso` y `parametro`.
- `tipo = "estructura"`: evalúa condiciones como `reenviado`, `enlace`, `largo >= parametro`, etc.
- `tipo = "frase"`: busca la frase exacta como palabra completa (no dentro de otra palabra).
- `tipo = "regex"`: busca con expresión regular personalizada.
- El puntaje total es la suma de `hit * peso` para todas las reglas que coinciden.
- Un mensaje es publicidad si `puntaje >= umbral_publicidad`.

### Función `detectar_publicidad()`

```r
detectar_publicidad <- function(ctx, d) {
  M <- "6. Limpieza de publicidad y anuncios (propia del texto)"
  umbral <- ctx$p$umbral_publicidad
  reglas <- ctx$cfg$anuncio
  
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "puntaje_publicidad, motivo_publicidad, posible_publicidad", atributo = "texto / booleana",
    problema = "Publicidad y anuncios de cursos/eventos",
    accion = sprintf("Se calculó un puntaje de publicidad por mensaje ... y se marcó como posible publicidad si puntaje >= %s.", umbral),
    justificacion = "Un puntaje compuesto evita borrar preguntas legítimas que solo contienen palabras como 'inscripción' o 'cupos'.",
    ejemplo_col = "posible_publicidad",
    codigo = {
      pp <- puntaje_publicidad(datos, reglas)
      datos$puntaje_publicidad <- pp$puntaje
      datos$motivo_publicidad <- pp$motivo
      datos$posible_publicidad <- pp$puntaje >= umbral
    })
  
  if (isTRUE(ctx$p$excluir_publicidad)) {
    d <- registrar_paso(ctx, d, metodologia = M,
      campo = "posible_publicidad", atributo = "booleana", problema = "Publicidad detectada",
      accion = "Se separaron los mensajes marcados como publicidad; quedan en mensajes_excluidos.csv con su puntaje y motivo...",
      justificacion = "Eliminar publicidad es lo único que la licenciada permitió quitar; guardarlos aparte permite auditar falsos positivos.",
      codigo = {
        pub <- datos$posible_publicidad
        excluir(ctx, datos[pub, ], sprintf("Publicidad / anuncio (puntaje >= %s)", umbral))
        datos <- datos[!pub, ]
      })
  }
  d
}
```

---

<a name="05_emojisr"></a>
## 6. `05_emojis.R` — Etapa 7: Emojis

Función principal: `procesar_emojis(ctx, d)`.

### Funciones clave

```r
emoji_clave <- function(x) {
  stringi::stri_replace_all_regex(x, "[\\x{1F3FB}-\\x{1F3FF}\\x{FE0F}\\x{FE0E}]", "")
}
```

Quita tonos de piel (👍🏽 → 👍) y selectores de variación para normalizar emojis.

```r
extraer_emojis <- function(textos) {
  textos[is.na(textos)] <- ""
  res <- rep(list(character(0)), length(textos))
  cand <- which(stringi::stri_detect_regex(
    textos, "[\\x{00A9}\\x{00AE}\\x{203C}-\\x{3299}\\x{1F000}-\\x{1FAFF}\\x{1F1E6}-\\x{1F1FF}\\x{20E3}]"))
  if (length(cand)) {
    gr <- stringi::stri_extract_all_boundaries(textos[cand], type = "character")
    for (k in seq_along(cand)) {
      g <- gr[[k]]
      res[[cand[k]]] <- emoji_clave(g[.es_emoji(g)])
    }
  }
  res
}
```

Extrae todos los emojis de cada texto como una lista de claves normalizadas.

```r
actualizar_emoji <- function(emoji, significado_es, sentimiento = "neutral", polaridad = NULL,
                             dir_config = "config") {
  f <- file.path(dir_config, "emojis.csv")
  e <- readr::read_csv(f, col_types = readr::cols(.default = "c"), progress = FALSE, na = character())
  s <- jsonlite::fromJSON(file.path(dir_config, "sentimientos.json"))$sentimientos
  if (is.null(polaridad))
    polaridad <- if (sentimiento %in% s$nombre) s$polaridad[match(sentimiento, s$nombre)] else 0
  k <- match(emoji_clave(emoji), emoji_clave(e$emoji))
  if (is.na(k)) {
    e <- rbind(e[, c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")],
               data.frame(emoji = emoji_clave(emoji), significado_es = "", sentimiento = "neutral",
                          polaridad = "0", nombre_unicode = .nombre_unicode(emoji),
                          stringsAsFactors = FALSE))
    k <- nrow(e)
  }
  e$significado_es[k] <- significado_es
  e$sentimiento[k] <- sentimiento
  e$polaridad[k] <- as.character(polaridad)
  escribir_csv(e[, c("emoji", "significado_es", "sentimiento", "polaridad", "nombre_unicode")], f)
  invisible(e[k, ])
}
```

Función pública para agregar o actualizar la traducción de un emoji en `config/emojis.csv`. Usada por el dashboard.

### Función `procesar_emojis()`

```r
procesar_emojis <- function(ctx, d) {
  M <- "7. Traducción de emojis (diccionario maestro)"
  p <- ctx$p
  dic <- ctx$cfg$emojis
  
  en_texto <- unlist(strsplit(d$emojis_lista[nzchar(d$emojis_lista)], " ", fixed = TRUE))
  rl <- reacciones_largo(d$reacciones)
  usados <- unique(c(en_texto, rl$emoji))
  nuevos <- setdiff(usados, dic$emoji)
  
  if (length(nuevos)) {
    nuevo_df <- data.frame(
      emoji = nuevos, significado_es = "", sentimiento = "neutral", polaridad = 0,
      nombre_unicode = .nombre_unicode(nuevos), stringsAsFactors = FALSE)
    dic <- rbind(dic, nuevo_df)
    ctx$cfg$emojis <- dic
    .guardar_emojis(ctx)
  }
  pend_usados <- dic[dic$emoji %in% usados & !nzchar(dic$significado_es), ]
  ctx$emojis_pendientes <- pend_usados
  
  if (p$nuevos_emojis == "detener" && nrow(pend_usados) > 0) {
    ctx$detenido <- TRUE
    return(d)
  }
  ...
}
```

**Flujo:**
1. Extrae emojis del texto y de las reacciones.
2. Detecta emojis nuevos (no en el diccionario) y los agrega como pendientes.
3. Si `nuevos_emojis == "detener"` y hay pendientes, detiene el proceso para que el usuario los traduzca.
4. Traduce emojis en el texto a tokens `emoji_<significado>`.
5. Asigna sentimiento y polaridad de emojis por mensaje.
6. Cuenta reacciones positivas y negativas.

---

<a name="06_textor"></a>
## 7. `06_texto.R` — Etapas 8-10: Limpieza de texto, género, tokenización y stopwords

### Etapa 8: `normalizar_texto()`

Limpia el texto eliminando enlaces, correos, menciones, teléfonos, hashtags, signos, abreviaturas, etc.

**Sub-etapas clave:**

```r
  # ── 8.1 Enlaces, correos, menciones, teléfonos ─────────────────────────────────
  RX_RUIDO <- paste(RX_URL, RX_MAIL, RX_DOM, RX_MENC, RX_TEL, sep = "|")
  codigo = {
    x <- datos$texto_traducido
    deco <- which(stringi::stri_detect_regex(x, "[\\x{1D400}-\\x{1D7FF}\\x{FF01}-\\x{FF5E}]"))
    x[deco] <- stringi::stri_trans_nfkc(x[deco])
    x <- stringi::stri_replace_all_regex(x, RX_URL, " ")
    x <- stringi::stri_replace_all_regex(x, RX_MAIL, " ")
    x <- stringi::stri_replace_all_regex(x, RX_DOM, " ", opts_regex = stringi::stri_opts_regex(case_insensitive = TRUE))
    x <- stringi::stri_replace_all_regex(x, RX_MENC, " ")
    x <- stringi::stri_replace_all_regex(x, RX_TEL, " telefono ")
    datos$texto_limpio <- x
  }
```

- `RX_DOM`: detecta dominios sueltos como `umsa.bo`.
- Letras decoradas Unicode (negrita matemática) se normalizan con NFKC solo en esos bloques.
- Teléfonos se reemplazan por la palabra "telefono".

```r
  # ── 8.2 Minúsculas ─────────────────────────────────────────────────────────────
  codigo = {
    datos$texto_limpio <- stringi::stri_trans_tolower(datos$texto_limpio)
  }
```

Convierte todo a minúsculas (conservando tildes por ahora).

```r
  # ── 8.5 Letras alargadas ───────────────────────────────────────────────────────
  codigo = {
    datos$texto_limpio <- stringi::stri_replace_all_regex(datos$texto_limpio, "(\\p{L})\\1{2,}", "$1")
  }
```

Reduce repeticiones de 3+ letras iguales ("graciasss" → "gracias").

### Etapa 9: `marcar_genero()`

```r
marcar_genero <- function(ctx, d) {
  M <- "9. Referencias de género (antes de quitar stopwords)"
  g <- ctx$cfg$genero
  g$palabra <- stringi::stri_trans_tolower(g$palabra)
  patron <- function(gen) {
    w <- unique(g$palabra[g$genero == gen])
    paste0("(?<![\\p{L}\\p{N}_])(?:", paste(w[order(-nchar(w))], collapse = "|"), ")(?![\\p{L}\\p{N}_])")
  }
  pat_f <- patron("femenino"); pat_m <- patron("masculino")
  ...
  datos$n_ref_femenino <- stringi::stri_count_regex(datos$texto_limpio, pat_f)
  datos$n_ref_masculino <- pmax(0, stringi::stri_count_regex(datos$texto_limpio, pat_m) - inc_m)
  datos$genero_mencionado <- ifelse(datos$n_ref_femenino > 0 & datos$n_ref_masculino > 0, "ambos",
                             ifelse(datos$n_ref_femenino > 0, "femenino",
                             ifelse(datos$n_ref_masculino > 0, "masculino",
                             ifelse(datos$n_ref_inclusivo > 0, "inclusivo", "ninguno"))))
}
```

Cuenta referencias de género usando `config/genero.csv`. Las formas con @ (compañer@s) se cuentan como inclusivas, no masculinas.

### Etapa 10: `tokenizar_y_filtrar()`

```r
tokenizar_y_filtrar <- function(ctx, d) {
  M <- "10. Tokenización y stopwords personalizadas"
  
  # ── 10.1 Tokenización ──────────────────────────────────────────────────────────
  codigo = {
    tk <- strsplit(datos$texto_limpio, " ", fixed = TRUE)
    tk <- lapply(tk, function(t) t[nzchar(t) & (!grepl("[0-9]", t) | grepl("_", t) | grepl("^x[0-9]+$", t))])
    ctx$tokens <- tk
    datos$n_tokens_brutos <- lengths(tk)
  }
```

Tokeniza por espacios. Descarta tokens con números excepto códigos de materia (con `_`) y respuestas tipo `x2`.

```r
  # ── 10.2 Stopwords personalizadas ──────────────────────────────────────────────
  sw <- preparar_stopwords(ctx)
  tk <- ctx$tokens
  ...
  u <- unique(unlist(tk))
  u_ascii <- .ascii(u)
  rx_raiz <- if (length(sw$prot_raiz)) paste0("^(", paste(sw$prot_raiz, collapse = "|"), ")") else "^$a"
  es_emoji <- startsWith(u, "emoji_")
  en_cons <- u %in% sw$cons
  en_prot <- u_ascii %in% sw$prot_pal | grepl(rx_raiz, u_ascii)
  en_elim <- u %in% sw$elim | u_ascii %in% sw$elim
  quitar_u <- en_elim & !en_cons & !en_prot & !es_emoji
  quitar <- u[quitar_u]
  tk_f <- lapply(tk, function(t) t[!(t %in% quitar)])
```

**Reglas de stopwords:**
- Se eliminan palabras de la lista base (`sw$elim`).
- Se conservan: palabras en `sw$cons` (reglas propias), palabras protegidas por el diccionario de sentimientos (`sw$prot_pal` y `sw$prot_raiz`), y emojis.
- Se registra qué pasó con cada palabra en `stopwords_aplicadas.csv`.

```r
  # ── 10.3 Quitar tildes de los tokens ───────────────────────────────────────────
  codigo = {
    tk2 <- strsplit(datos$texto_tokens, " ", fixed = TRUE)
    u2 <- unique(unlist(tk2))
    proteger <- sw$cons[sw$cons != .ascii(sw$cons) & .ascii(sw$cons) %in% sw$elim]   # solo "él"
    mapa <- stats::setNames(ifelse(u2 %in% proteger, u2, .sin_tilde(u2)), u2)
    datos$texto_tokens <- vapply(tk2, function(t) paste(mapa[t], collapse = " "), character(1))
  }
```

Las tildes se quitan DESPUÉS de las stopwords. Solo se conserva "él" (porque sin tilde sería "el", el artículo).

---

<a name="07_sentimientosr"></a>
## 8. `07_sentimientos.R` — Etapa 11: Sentimientos con diccionario propio

### Función `patron_sentimiento()`

```r
patron_sentimiento <- function(palabras, raices, negado = FALSE) {
  pal <- unique(.ascii(tolower(palabras)))
  pal <- pal[nzchar(pal)]
  pal <- pal[order(-nchar(pal))]
  pal <- gsub(" ", "\\\\s+", .esc(pal))
  rai <- unique(.ascii(tolower(raices)))
  rai <- rai[nzchar(rai)]
  rai <- if (length(rai)) paste0(.esc(rai), "[a-z0-9]*") else character(0)
  alt <- c(pal, rai)
  if (!length(alt)) return(NULL)
  nucleo <- paste0("(?:", paste(alt, collapse = "|"), ")")
  if (!negado) return(paste0("(?<![a-z0-9_])", nucleo, "(?![a-z0-9_])"))
  paste0("(?<![a-z0-9_])(?:", NEGADORES, ")\\s+(?:[a-z0-9_]+\\s+)?(?!(?:", NO_NEGABLES, ")(?![a-z0-9_]))",
         nucleo, "(?![a-z0-9_])")
}
```

Construye una expresión regular para buscar las palabras y raíces de un sentimiento.
- Las palabras se ordenan por longitud descendente para que coincidan las más largas primero.
- Espacios en frases se convierten a `\\s+`.
- Si `negado = TRUE`, busca patrón de "negador + término" (ej. "no estoy feliz").
- `NO_NEGABLES`: términos que no se niegan aunque tenga "no" antes ("gracias", "para nada", "xd", etc.).

### Función `calcular_sentimientos()`

```r
calcular_sentimientos <- function(ctx, d) {
  M <- "11. Sentimientos con diccionario propio"
  cfg_sent <- if (exists("config_sentimientos_cargada", envir = globalenv()) &&
                   !is.null(get("config_sentimientos_cargada", envir = globalenv()))) {
    get("config_sentimientos_cargada", envir = globalenv())$sent
  } else {
    ctx$cfg$sent
  }
  sj <- cfg_sent[cfg_sent$activo, ]
  dic_emo <- ctx$cfg$emojis
  nombres <- sj$nombre
  
  txt <- .ascii(datos$texto_limpio)        # coincidencia sobre texto sin tildes
  n <- nrow(datos)
  emo_lst <- strsplit(datos$emojis_lista, " ", fixed = TRUE)
  sent_emo <- stats::setNames(dic_emo$sentimiento, dic_emo$emoji)
  hits <- matrix(0, n, length(nombres), dimnames = list(NULL, nombres))
  negs <- matrix(0, n, length(nombres), dimnames = list(NULL, nombres))
  
  for (i in seq_along(nombres)) {
    pat <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]])
    if (!is.null(pat)) {
      bruto <- stringi::stri_count_regex(txt, pat)
      pat_neg <- patron_sentimiento(sj$palabras[[i]], sj$raices[[i]], negado = TRUE)
      negs[, i] <- pmin(stringi::stri_count_regex(txt, pat_neg), bruto)
      hits[, i] <- bruto - negs[, i]
    }
    hits[, i] <- hits[, i] + vapply(emo_lst, function(k) sum(sent_emo[k] == nombres[i], na.rm = TRUE), numeric(1))
  }
  
  unidades <- pmax(datos$n_tokens, 1)
  pol <- stats::setNames(sj$polaridad, nombres)
  for (i in seq_along(nombres)) {
    datos[[paste0("sent_", nombres[i])]] <- hits[, i]
    datos[[paste0("pct_", nombres[i])]] <- round(pmin(100, 100 * hits[, i] / unidades), 2)
  }
  datos$hits_total <- rowSums(hits)
  datos$n_negados <- rowSums(negs)
  base_pol <- datos$hits_total + datos$n_negados
  num_pol <- as.vector(hits %*% pol[nombres]) - as.vector(negs %*% pol[nombres])
  datos$polaridad_score <- ifelse(base_pol > 0, round(num_pol / base_pol, 3), 0)
  datos$polaridad_msg <- ifelse(datos$polaridad_score > 0, "positivo",
                                ifelse(datos$polaridad_score < 0, "negativo", "neutral"))
  datos$sentimiento_dominante <- ifelse(datos$hits_total > 0, nombres[max.col(hits, ties.method = "first")], NA)
  d
}
```

**Cambio reciente:** Lee de `config_sentimientos_cargada` (variable global en Plumber) si existe, permitiendo actualizar sentimientos sin reejecutar el preprocesamiento completo.

**Cálculo:**
- `hits[, i]`: coincidencias brutas menos negadas.
- `pct_*`: 100 * hits / n_tokens (coteado a 100).
- `polaridad_score`: suma ponderada de polaridades (+1, 0, -1) dividida por total de hits.
- `sentimiento_dominante`: el sentimiento con más hits en cada mensaje.

### Otras funciones

```r
resumen_periodo <- function(datos, inicio = NULL, fin = NULL) {
  f <- datos$fecha
  if (!is.null(inicio)) datos <- datos[f >= as.Date(inicio), ]
  f <- datos$fecha
  if (!is.null(fin)) datos <- datos[f <= as.Date(fin), ]
  cols <- grep("^sent_", names(datos), value = TRUE)
  nom <- sub("^sent_", "", cols)
  unidades <- sum(pmax(datos$n_tokens, 1))
  data.frame(sentimiento = nom,
             coincidencias = vapply(cols, function(c) sum(datos[[c]]), numeric(1)),
             pct_periodo = round(100 * vapply(cols, function(c) sum(datos[[c]]), numeric(1)) / unidades, 2),
             n_mensajes = nrow(datos), row.names = NULL, stringsAsFactors = FALSE)
}
```

Calcula el nivel de cada sentimiento para un periodo (promedio de pct_*).

---

<a name="08_salidar"></a>
## 9. `08_salida.R` — Etapas 12-13: Valores faltantes, validación y exportación

### Reglas de nulos (`REGLAS_NULOS`)

```r
REGLAS_NULOS <- list(
  reenviado_de          = "original",
  responde_a            = 0,
  reacciones            = "ninguna",
  emojis_lista          = "ninguno",
  sentimiento_emoji     = "sin_emoji",
  polaridad_emoji       = 0,
  sentimiento_dominante = "ninguno",
  motivo_publicidad     = "ninguno"
)
```

Cada columna del dataset limpio tiene un valor de relleno específico para celdas vacías.

### Función `columnas_limpio()`

```r
columnas_limpio <- function(ctx, d) {
  nom <- ctx$cfg$sent$nombre[ctx$cfg$sent$activo]
  cols <- c("id_mensaje", "fecha_hora", "fecha", "anio", "mes", "anio_mes", "trimestre",
            "dia_semana", "hora", "autor", if (!isTRUE(ctx$p$anonimizar_autor)) "autor_id",
            "tipo_contenido", "es_respuesta", "responde_a", "editado", "reenviado", "reenviado_de",
            "n_caracteres", "n_palabras", "n_tokens", "n_enlaces", "n_hashtags", "n_menciones",
            "tiene_telefono", "n_emojis", "emojis_lista", "sentimiento_emoji", "polaridad_emoji",
            "reacciones", "reacciones_total", "reacciones_pos", "reacciones_neg",
            "outlier_longitud", "outlier_rafaga", "puntaje_publicidad", "motivo_publicidad",
            "posible_publicidad", "n_ref_femenino", "n_ref_masculino", "n_ref_inclusivo", "genero_mencionado",
            "texto_original", "texto_traducido", "texto_limpio", "texto_tokens",
            "polaridad_msg", "polaridad_score", "sentimiento_dominante", "hits_total", "n_negados",
            paste0("sent_", nom), paste0("pct_", nom))
  cols[cols %in% names(d)]
}
```

Define las columnas del dataset limpio. Las columnas `sent_*` y `pct_*` son dinámicas según los sentimientos activos.

### Función `rellenar_nulos()`

```r
rellenar_nulos <- function(ctx, d) {
  M <- "12. Valores faltantes del dataset final"
  d <- registrar_paso(ctx, d, metodologia = M,
    campo = "reenviado_de, responde_a, reacciones, emojis_lista, sentimiento_emoji, polaridad_emoji, sentimiento_dominante, motivo_publicidad",
    atributo = "texto / numérica",
    problema = "Celdas vacías (NA) en columnas derivadas",
    accion = "Se rellenaron las celdas vacías con un valor que significa 'no aplica'...",
    justificacion = "Un NA aquí no es un dato perdido sino 'no corresponde'...",
    codigo = {
      cols <- columnas_limpio(ctx, datos)
      vacio <- function(x) if (is.character(x)) is.na(x) | !nzchar(x) else is.na(x)
      detalle <- character(0); n_llenos <- 0
      for (cn in cols) {
        if (cn == "texto_tokens") next
        v <- datos[[cn]]
        m <- vacio(v)
        if (!any(m)) next
        val <- if (!is.null(REGLAS_NULOS[[cn]])) REGLAS_NULOS[[cn]]
               else if (is.numeric(v)) 0 else if (is.logical(v)) FALSE else "ninguno"
        datos[[cn]][m] <- val
        n_llenos <- n_llenos + sum(m)
        detalle <- c(detalle, sprintf("%s: %s -> '%s'", cn, .fmt(sum(m)), val))
      }
      ctx$nota <- paste0("Reglas aplicadas (columna: celdas vacías -> valor): ", paste(detalle, collapse = "; "), ".")
    })
  d
}
```

Rellena todas las celdas vacías con valores explícitos ("no aplica") para evitar NAs en el dataset limpio.

### Función `validar_consistencia()`

Valida:
- IDs únicos (no duplicados).
- Fechas presentes en todos los mensajes.
- Textos limpios no vacíos.
- Porcentajes de sentimiento en [0, 100].
- Sin celdas vacías en el dataset limpio.
- Conservación de filas: leídos = limpios + excluidos.

### Función `exportar_salidas()`

Escribe los archivos CSV de salida:
- `mensajes_limpios.csv`
- `mensajes_excluidos.csv`
- `tokens.csv`
- `stopwords_aplicadas.csv`
- `emojis_en_uso.csv`
- `emojis_pendientes.csv`

---

<a name="09_periodosr"></a>
## 10. `09_periodos.R` — Parte 2: Periodos y nivel de sentimientos

Este script pertenece a la **parte 2 del análisis**. El preprocesamiento se corre UNA vez con todo el dataset; aquí solo se filtran los datos por fechas para generar análisis por periodo.

### Función `cargar_datos_analisis()`

```r
cargar_datos_analisis <- function(dir_salida = "salida") {
  fm <- file.path(dir_salida, "mensajes_limpios.csv")
  ft <- file.path(dir_salida, "tokens.csv")
  if (!file.exists(fm)) stop("No existe ", fm, ". Corre primero preprocesar().", call. = FALSE)
  m <- readr::read_csv(fm, show_col_types = FALSE, progress = FALSE, guess_max = 100000)
  m$fecha <- as.Date(m$fecha)
  tk <- NULL
  if (file.exists(ft)) {
    tk <- readr::read_csv(ft, show_col_types = FALSE, progress = FALSE, guess_max = 100000)
    tk$fecha <- as.Date(tk$fecha)
  }
  list(mensajes = m, tokens = tk)
}
```

Carga los archivos CSV de salida generados por el preprocesamiento.

### Función `resolver_periodo()`

```r
resolver_periodo <- function(periodo = NULL, periodos = cargar_periodos(), fechas = NULL) {
  if (is.null(periodo)) {
    if (is.null(fechas)) stop("Para usar todo el dataset indica fechas = datos$mensajes$fecha", call. = FALSE)
    r <- range(fechas, na.rm = TRUE)
    return(list(nombre = "todo el dataset", inicio = r[1], fin = r[2]))
  }
  if (is.list(periodo) && !is.null(periodo$inicio))
    return(list(nombre = periodo$nombre %||% "periodo", inicio = as.Date(periodo$inicio), fin = as.Date(periodo$fin)))
  if (is.character(periodo) && length(periodo) == 1) {
    i <- match(periodo, periodos$nombre)
    if (is.na(i)) stop("El periodo '", periodo, "' no está en config/periodos.csv", call. = FALSE)
    return(list(nombre = periodo, inicio = as.Date(periodos$inicio[i]), fin = as.Date(periodos$fin[i])))
  }
  if (length(periodo) == 2)
    return(list(nombre = paste(periodo[1], "a", periodo[2]), inicio = as.Date(periodo[1]), fin = as.Date(periodo[2])))
  stop("No entiendo el periodo. Usa NULL, un nombre, o c('inicio', 'fin').", call. = FALSE)
}
```

Acepta periodo como: NULL (todo), nombre (de config/periodos.csv), lista con inicio/fin, o vector c("inicio", "fin").

### Función `nivel_sentimiento()`

```r
nivel_sentimiento <- function(m) {
  nom <- nombres_sentimientos(m)
  if (!nrow(m) || !length(nom))
    return(data.frame(sentimiento = character(), nivel_pct = numeric(), mensajes_pct = numeric(),
                      n_mensajes = integer(), stringsAsFactors = FALSE))
  data.frame(
    sentimiento  = nom,
    nivel_pct    = unname(vapply(nom, function(s) mean(m[[paste0("pct_", s)]], na.rm = TRUE), numeric(1))),
    mensajes_pct = unname(vapply(nom, function(s) 100 * mean(m[[paste0("sent_", s)]] > 0, na.rm = TRUE), numeric(1))),
    n_mensajes   = nrow(m), stringsAsFactors = FALSE)
}
```

Calcula:
- `nivel_pct`: promedio de pct_* por mensaje.
- `mensajes_pct`: % de mensajes con al menos una coincidencia del sentimiento.

---

<a name="10_tfidfr"></a>
## 11. `10_tfidf.R` — TF-IDF y stopwords

### Función `tfidf_docs()`

```r
tfidf_docs <- function(tokens, doc, min_freq = 2, suavizado = FALSE) {
  ok <- !is.na(doc) & !is.na(tokens$token) & nzchar(tokens$token)
  if (!any(ok)) return(data.frame())
  tab <- .contar(doc[ok], tokens$token[ok])
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  n_doc <- length(unique(tab$doc))
  tot   <- tapply(tab$Freq, tab$doc, sum)
  dfreq <- table(tab$token)
  tab$tf  <- tab$Freq / as.numeric(tot[tab$doc])
  df_t    <- as.numeric(dfreq[tab$token])
  tab$idf <- if (suavizado) log((1 + n_doc) / (1 + df_t)) + 1 else log(n_doc / df_t)
  tab$tf_idf <- tab$tf * tab$idf
  tab <- tab[tab$Freq >= min_freq, , drop = FALSE]
  names(tab)[names(tab) == "Freq"] <- "n"
  tab[order(tab$doc, -tab$tf_idf), , drop = FALSE]
}
```

**Fórmula TF-IDF:**
- `tf = n / total_terminos_del_documento`
- `idf = log(N / df)` donde N = número de documentos, df = documentos que contienen el término.
- `tf_idf = tf * idf`
- Con suavizado: `idf = log((1+N)/(1+df)) + 1`

### Función `tfidf_comparar()`

```r
tfidf_comparar <- function(tokens, perA, perB, top = 15) {
  ta <- filtrar_periodo(tokens, perA); tb <- filtrar_periodo(tokens, perB)
  ta <- ta[!ta$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  tb <- tb[!tb$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  ...
  d <- rbind(data.frame(token = ta$token, doc = rep(na, nrow(ta)), stringsAsFactors = FALSE),
             data.frame(token = tb$token, doc = rep(nb, nrow(tb)), stringsAsFactors = FALSE))
  tfidf_top(tfidf_docs(d, d$doc, suavizado = TRUE), top)
}
```

Compara dos periodos y devuelve los términos más distintivos de cada uno (usando IDF suavizado).

---

<a name="11_shallowr"></a>
## 12. `11_shallow.R` — Shallow linguistic con udpipe

### Función `modelo_udpipe()`

```r
modelo_udpipe <- function(dir_modelos = "modelos") {
  .requiere("udpipe")
  dir.create(dir_modelos, showWarnings = FALSE, recursive = TRUE)
  f <- list.files(dir_modelos, pattern = "spanish.*\\.udpipe$", full.names = TRUE)
  if (!length(f)) {
    message("Descargando el modelo de español de udpipe (solo la primera vez; necesita internet)...")
    f <- udpipe::udpipe_download_model(language = "spanish", model_dir = dir_modelos)$file_model
  }
  udpipe::udpipe_load_model(f[1])
}
```

Descarga el modelo de español de udpipe la primera vez y lo guarda en `modelos/`.

### Función `shallow_linguistic()`

```r
shallow_linguistic <- function(m, modelo = NULL, max_mensajes = 1500, semilla = 1) {
  .requiere("udpipe")
  if (is.null(modelo)) modelo <- modelo_udpipe()
  x <- m[!is.na(m$texto_limpio) & nzchar(m$texto_limpio), c("id_mensaje", "texto_limpio"), drop = FALSE]
  if (!nrow(x)) stop("No hay texto para analizar.", call. = FALSE)
  if (nrow(x) > max_mensajes) { set.seed(semilla); x <- x[sample(nrow(x), max_mensajes), , drop = FALSE] }
  a <- as.data.frame(udpipe::udpipe_annotate(modelo, x = x$texto_limpio, doc_id = as.character(x$id_mensaje)),
                     stringsAsFactors = FALSE)
  a <- a[, c("doc_id", "sentence_id", "token_id", "token", "lemma", "upos")]
  
  upos <- as.data.frame(table(clase = a$upos), stringsAsFactors = FALSE)
  names(upos)[2] <- "n"
  upos$pct <- round(100 * upos$n / sum(upos$n), 1)
  
  lemas <- do.call(rbind, lapply(c("NOUN", "VERB", "ADJ"), function(u) {
    s <- a$lemma[a$upos == u & !is.na(a$lemma)]
    if (!length(s)) return(NULL)
    h <- utils::head(sort(table(tolower(s)), decreasing = TRUE), 15)
    data.frame(clase = u, lema = names(h), n = as.integer(h), stringsAsFactors = FALSE)
  }))
  
  frases <- tryCatch({
    fase <- udpipe::as_phrasemachine(a$upos, type = "upos")
    fr <- udpipe::keywords_phrases(fase, term = tolower(a$token), pattern = "(A|N)*N(P+D*(A|N)*N)*",
                                   is_regex = TRUE, ngram_max = 4, detailed = FALSE)
    fr <- fr[fr$ngram > 1, , drop = FALSE]
    utils::head(fr[order(-fr$freq), ], 20)
  }, error = function(e) NULL)
  
  list(paso = "Shallow linguistic: udpipe (R/11_shallow.R) sobre texto_limpio", n_mensajes = nrow(x),
       anotado = a, upos = upos, lemas = lemas, frases_nominales = frases)
}
```

**Salida:**
- `anotado`: tabla completa con token, lema y upos por mensaje.
- `upos`: distribución de categorías gramaticales.
- `lemas`: top 15 lemas por categoría (sustantivo, verbo, adjetivo).
- `frases_nominales`: top 20 frases nominales extraídas.

**Nota:** Se aplica sobre `texto_limpio` (con stopwords) porque la gramática necesita palabras de enlace. El preprocesamiento NO lematiza.

---

<a name="12_topicosr"></a>
## 13. `12_topicos.R` — Topic modeling LDA

### Función `topicos_lda()`

```r
topicos_lda <- function(tokens, k = 6, agrupar = c("dia", "mes"), min_tokens_doc = 5,
                        min_freq_termino = 3, iter = 400, semilla = 123, top = 10) {
  .requiere(c("topicmodels", "slam"))
  agrupar <- match.arg(agrupar)
  doc <- if (agrupar == "dia") format(tokens$fecha, "%Y-%m-%d") else tokens$anio_mes
  ok <- !is.na(doc) & !is.na(tokens$token) & nzchar(tokens$token)
  tab <- .contar(doc[ok], tokens$token[ok])
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  tot_t <- tapply(tab$Freq, tab$token, sum)
  tab <- tab[tab$token %in% names(tot_t)[tot_t >= min_freq_termino], , drop = FALSE]
  tot_d <- tapply(tab$Freq, tab$doc, sum)
  tab <- tab[tab$doc %in% names(tot_d)[tot_d >= min_tokens_doc], , drop = FALSE]
  docs <- sort(unique(tab$doc)); terms <- sort(unique(tab$token))
  if (length(docs) < k + 1)
    stop("Hay muy pocos documentos (", length(docs), ") para ", k, " tópicos. ", ...)
  
  dtm <- slam::simple_triplet_matrix(i = match(tab$doc, docs), j = match(tab$token, terms),
                                     v = as.integer(tab$Freq), nrow = length(docs), ncol = length(terms),
                                     dimnames = list(docs, terms))
  mod <- topicmodels::LDA(dtm, k = k, method = "Gibbs",
                          control = list(seed = semilla, burnin = 100, iter = iter, thin = 10))
  post  <- topicmodels::posterior(mod)
  beta  <- post$terms      # tópico x término
  gamma <- post$topics     # documento x tópico
  
  etiqueta <- apply(beta, 1, function(b) paste(names(sort(b, decreasing = TRUE))[1:3], collapse = " / "))
  ids <- paste0("T", seq_len(k))
  terminos <- do.call(rbind, lapply(seq_len(k), function(t) {
    b <- sort(beta[t, ], decreasing = TRUE)[seq_len(top)]
    data.frame(topico = ids[t], etiqueta = etiqueta[t], termino = names(b), beta = as.numeric(b),
               stringsAsFactors = FALSE)
  }))
  dominante <- data.frame(doc = rownames(gamma), topico = ids[max.col(gamma, ties.method = "first")],
                          peso = apply(gamma, 1, max), stringsAsFactors = FALSE)
  
  list(paso = "Topic modeling: LDA con Gibbs (R/12_topicos.R) sobre tokens.csv", k = k, agrupar = agrupar,
       n_documentos = length(docs), n_terminos = length(terms), modelo = mod, beta = beta,
       etiquetas = data.frame(topico = ids, etiqueta = etiqueta, stringsAsFactors = FALSE),
       terminos = terminos, dominante = dominante, peso_mes = peso_mes)
}
```

**Notas:**
- Los mensajes de chat son muy cortos, así que se agrupan por día o mes para formar documentos con suficientes palabras.
- `k` = número de tópicos (default 6).
- `beta`: matriz tópico × término con probabilidades.
- `gamma`: matriz documento × tópico con proporción de cada tópico en cada documento.
- La etiqueta de cada tópico son las 3 palabras con mayor beta.

### Función `topico_de_texto()`

```r
topico_de_texto <- function(tokens_oracion, lda) {
  b <- lda$beta
  v <- intersect(tokens_oracion, colnames(b))
  if (!length(v)) return(NULL)
  s <- rowSums(b[, v, drop = FALSE])
  data.frame(topico = lda$etiquetas$topico, etiqueta = lda$etiquetas$etiqueta,
             probabilidad_pct = round(100 * s / sum(s), 1), palabras_usadas = paste(v, collapse = " "),
             stringsAsFactors = FALSE)[order(-s), ]
}
```

Para una oración nueva, suma las probabilidades beta de sus palabras en cada tópico sin reentrenar el modelo.

---

<a name="13_libreria"></a>
## 14. `13_libreria.R` — Sentimientos de la librería syuzhet

### Función `sentimientos_libreria()`

```r
sentimientos_libreria <- function(m, texto = "texto_limpio", idioma = "spanish", max_mensajes = NULL, semilla = 1) {
  .requiere("syuzhet")
  if (!is.null(max_mensajes) && nrow(m) > max_mensajes) { set.seed(semilla); m <- m[sample(nrow(m), max_mensajes), , drop = FALSE] }
  x <- m[[texto]]; x[is.na(x)] <- ""
  nrc <- syuzhet::get_nrc_sentiment(x, language = idioma)
  ES <- c(anger = "enojo", anticipation = "anticipacion", disgust = "asco", fear = "miedo", joy = "alegria",
          sadness = "tristeza", surprise = "sorpresa", trust = "confianza", negative = "negativo", positive = "positivo")
  den <- if ("n_tokens" %in% names(m)) pmax(m$n_tokens, 1) else pmax(stringi::stri_count_words(x), 1)
  for (nm in names(ES)) {
    m[[paste0("libn_", ES[[nm]])]] <- nrc[[nm]]
    m[[paste0("lib_", ES[[nm]])]]  <- round(100 * nrc[[nm]] / den, 3)
  }
  m$lib_polaridad <- ifelse(nrc$positive > nrc$negative, "positivo",
                     ifelse(nrc$negative > nrc$positive, "negativo", "neutral"))
  m
}
```

Aplica el léxico NRC de syuzhet (8 emociones + 2 polaridad) y calcula el nivel como porcentaje de tokens.

**8 emociones (Plutchik):** enojo, anticipación, asco, miedo, alegría, tristeza, sorpresa, confianza.
**2 polaridades:** negativo, positivo.

### Función `comparar_con_sin_libreria()`

```r
comparar_con_sin_libreria <- function(m) {
  if (!all(c("polaridad_msg", "lib_polaridad") %in% names(m))) stop("Primero usa sentimientos_libreria().", call. = FALSE)
  tabla <- as.data.frame(table(propio = m$polaridad_msg, libreria = m$lib_polaridad), stringsAsFactors = FALSE)
  d <- m[m$polaridad_msg != "neutral" & m$lib_polaridad != "neutral", , drop = FALSE]
  list(
    propios = nivel_sentimiento(m),
    libreria = nivel_libreria(m),
    polaridad_cruzada = tabla,
    acuerdo_polaridad_pct = if (nrow(d)) round(100 * mean(d$polaridad_msg == d$lib_polaridad), 1) else NA_real_,
    mensajes_comparados = nrow(d),
    distribucion = data.frame(
      polaridad = c("positivo", "negativo", "neutral"),
      propios_pct = round(100 * as.numeric(table(factor(m$polaridad_msg, c("positivo", "negativo", "neutral")))) / nrow(m), 1),
      libreria_pct = round(100 * as.numeric(table(factor(m$lib_polaridad, c("positivo", "negativo", "neutral")))) / nrow(m), 1)))
}
```

Compara la polaridad del diccionario propio vs. la librería syuzhet y calcula el porcentaje de acuerdo.

---

<a name="14_graficosr"></a>
## 15. `14_graficos.R` — 25 gráficos con ggplot2

Este archivo contiene un catálogo de 25 funciones de graficación que devuelven objetos ggplot.

### Paleta de colores

```r
.PAL <- c("#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51", "#8E5572", "#3A86FF", "#8338EC",
          "#FF006E", "#06D6A0", "#6D597A", "#B56576", "#355070", "#00B4D8", "#90BE6D")
.COL_SENT <- c(alegria = "#F4C20D", gratitud = "#2A9D8F", esperanza = "#06D6A0", seguridad = "#3A86FF",
               admiracion = "#8338EC", satisfaccion_tranquilidad = "#90BE6D", sorpresa = "#FF9F1C",
               confusion = "#8E5572", preocupacion = "#6D597A", tristeza = "#355070", enojo = "#E63946",
               decepcion = "#B56576", frustracion_cansancio = "#C2571A", ironia = "#FF006E",
               curiosidad = "#00B4D8")
```

Cada sentimiento tiene un color fijo en todos los gráficos.

### Catálogo de gráficos

| # | Función | Descripción |
|---|---------|-------------|
| G01 | `g_barras(niv)` | Barras horizontales con % de cada sentimiento |
| G02 | `g_barras_comparar(niv_largo)` | Barras agrupadas: periodo A vs B |
| G03 | `g_tiempo(serie)` | Líneas: evolución de sentimientos en el tiempo |
| G04 | `g_apilado(serie)` | Áreas apiladas por periodo |
| G05 | `g_polar(niv)` | Coordenadas polares (rosa de sentimientos) |
| G06 | `g_arana(niv_largo)` | Gráfico de araña (radar) |
| G07 | `g_dispersion(serie, x, y)` | Dispersión: sentimiento X vs sentimiento Y |
| G08 | `g_sankey(m)` | Sankey: tópico → sentimiento dominante |
| G09 | `g_tfidf(top)` | Términos más distintivos (TF-IDF) |
| G10 | `g_topicos(terminos)` | Palabras de cada tópico (LDA) |
| G11 | `g_topicos_tiempo(peso_mes)` | Peso de cada tópico en el tiempo |
| G12 | `g_upos(upos)` | Categorías gramaticales (shallow linguistic) |
| G13 | `g_nivel_mensaje(df)` | Mensaje frente a su periodo |
| G14 | `g_calor(m)` | Mapa de calor día de semana × hora |
| G15 | `g_volumen(m)` | Volumen de mensajes en el tiempo |
| G16 | `g_evolucion_anual(m)` | Evolución año por año |
| G17 | `g_sent_heat(m)` | Mapa de calor sentimiento × tiempo |
| G18 | `g_dominante(m)` | Qué emoción domina cada unidad de tiempo |
| G19 | `g_polaridad_tiempo(m)` | Polaridad en el tiempo |
| G20 | `g_sent_hora_heat(m)` | Ánimo durante el día (sentimiento × hora) |
| G21 | `g_correlacion(m)` | Qué sentimientos aparecen juntos |
| G22 | `g_palabras(m, n)` | Palabras más usadas |
| G23 | `g_emojis(m, n)` | Emojis más usados y su sentimiento |
| G24 | `g_libreria_vs_propios(dist)` | Propios vs librería (syuzhet) |
| G25 | `g_diferencia(niv_largo)` | Qué sube y qué baja entre dos periodos |

### Función `graficos_todos()`

```r
graficos_todos <- function(a, cmp = NULL, solo = NULL, verbose = TRUE) {
  m <- a$mensajes; niv <- a$nivel; nom <- niv$sentimiento
  top2 <- nom[order(-niv$nivel_pct)][1:2]
  ser <- tryCatch(serie_periodo(m), error = function(e) NULL)
  ...
  L <- list(
    G01_barras         = function() g_barras(niv, paste("Sentimientos propios:", a$periodo$nombre)),
    G02_barras_comparar = function() g_barras_comparar(.necesita(cmp, "cmp (usa comparar_periodos)")$niveles),
    ...
  )
  if (!is.null(solo)) {
    if (is.numeric(solo)) solo <- names(L)[solo]
    L <- L[intersect(names(L), solo)]
  }
  out <- list(); fallos <- character()
  for (nm in names(L)) {
    r <- tryCatch(L[[nm]](), error = function(e) conditionMessage(e))
    if (inherits(r, "ggplot")) out[[nm]] <- r else fallos[nm] <- as.character(r)
  }
  ...
  out
}
```

Devuelve una lista con todos los gráficos que se pudieron dibujar. Cada gráfico se envuelve en `tryCatch` para que un fallo no detenga los demás.

---

<a name="15_oracionr"></a>
## 16. `15_oracion.R` — Análisis de una sola oración

### Función `analizar_oracion()`

```r
analizar_oracion <- function(texto, datos = NULL, lda = NULL, modelo = NULL,
                             usar_udpipe = TRUE, usar_libreria = TRUE) {
  stopifnot(is.character(texto), length(texto) == 1, nzchar(trimws(texto)))
  tmp <- tempfile("oracion_")
  tmp <- tempfile("oracion_")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  csv <- file.path(tmp, "oracion.csv")
  
  utils::write.csv(data.frame(id = 1, date = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), from = "demo",
                              text = texto, stringsAsFactors = FALSE),
                   csv, row.names = FALSE, fileEncoding = "UTF-8")
  sal <- file.path(tmp, "salida")
  r <- try(suppressMessages(preprocesar(csv, dir_salida = sal, dir_bitacoras = file.path(tmp, "bitacoras"),
                                        consola = "silencioso", preguntar_cambios = FALSE,
                                        nuevos_emojis = "marcar")), silent = TRUE)
  out <- list(texto = texto)
  f_limpio <- file.path(sal, "mensajes_limpios.csv")
  fila <- if (file.exists(f_limpio)) readr::read_csv(f_limpio, show_col_types = FALSE, progress = FALSE) else NULL
  ...
}
```

**Flujo:**
1. Crea un CSV temporal con la oración.
2. Ejecuta `preprocesar()` sobre ese CSV (misma lógica que el dataset completo).
3. Extrae stopwords, shallow, TF-IDF (con idf del corpus), tópicos y sentimientos.
4. Las bitácoras van a carpeta temporal (no ensucian `bitacoras/` ni `salida/`).

**Salida:** Objeto de clase `analisis_oracion` con todos los resultados del análisis.

---

<a name="16_analisisr"></a>
## 17. `16_analisis.R` — Funciones principales de la parte 2

### Función `analizar_periodo()`

```r
analizar_periodo <- function(datos, fecha_inicio = NULL, fecha_fin = NULL,
                             periodo = NULL, periodos = cargar_periodos(), k = 6, agrupar = "dia",
                             shallow = TRUE, libreria = TRUE, max_mensajes_shallow = 1500,
                             max_mensajes_libreria = 5000, modelo_udpipe = NULL,
                             registrar = TRUE, dir_bitacoras = "bitacoras", dir_salida = "salida") {
  if (!is.null(fecha_inicio) || !is.null(fecha_fin)) {
    fi <- as.Date(fecha_inicio %||% min(datos$mensajes$fecha, na.rm = TRUE))
    ff <- as.Date(fecha_fin %||% max(datos$mensajes$fecha, na.rm = TRUE))
    per <- list(nombre = paste0(format(fi, "%Y-%m-%d"), "_a_", format(ff, "%Y-%m-%d")),
                inicio = fi, fin = ff)
    m <- subset(datos$mensajes, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
    tk <- subset(datos$tokens, as.Date(fecha) >= fi & as.Date(fecha) <= ff)
  } else {
    per <- resolver_periodo(periodo, periodos, datos$mensajes$fecha)
    m  <- filtrar_periodo(datos$mensajes, per)
    tk <- filtrar_periodo(datos$tokens, per)
  }
  if (!is.null(tk)) tk <- tk[!tk$token %in% PALABRAS_SIN_TEMA, , drop = FALSE]
  if (!nrow(m)) stop("No hay mensajes en el periodo ", per$nombre, ".", call. = FALSE)
  res <- list(periodo = per, n_mensajes = nrow(m))
  
  res$nivel <- nivel_sentimiento(m)
  res$serie <- serie_sentimientos(m)
  res$interpretacion <- interpretar_periodo(res$nivel, per$nombre)
  res$stopwords <- tryCatch(mostrar_stopwords(dir_salida), error = function(e) NULL)
  res$tfidf <- tryCatch(tfidf_mensual(tk, per), error = function(e) { message("TF-IDF: ", conditionMessage(e)); NULL })
  res$topicos <- tryCatch(topicos_lda(tk, k = k, agrupar = agrupar), error = function(e) { message("Tópicos: ", conditionMessage(e)); NULL })
  ...
  if (shallow) {
    res$shallow <- tryCatch(shallow_linguistic(m, modelo = modelo_udpipe, max_mensajes = max_mensajes_shallow),
                            error = function(e) { message("Shallow: ", conditionMessage(e)); NULL })
  }
  if (libreria) {
    ml <- tryCatch(sentimientos_libreria(m, max_mensajes = max_mensajes_libreria), error = function(e) { message("Librería: ", conditionMessage(e)); NULL })
    if (!is.null(ml)) {
      res$libreria <- nivel_libreria(ml)
      res$comparacion <- comparar_con_sin_libreria(ml)
    }
  }
  res$mensajes <- m
  class(res) <- c("analisis_periodo", "list")
  res
}
```

Cada paso está envuelto en `tryCatch` para que un fallo en TF-IDF, LDA o shallow no detenga el análisis completo.

### Función `comparar_periodos()`

Compara dos periodos y devuelve niveles, serie, TF-IDF comparativo y interpretación textual.

### Función `guardar_analisis()`

```r
guardar_analisis <- function(a, dir = "salida/analisis", graficos = TRUE) {
  nom <- if (inherits(a, "comparacion_periodos")) paste(a$periodos[[1]]$nombre, a$periodos[[2]]$nombre, sep = " vs ") else a$periodo$nombre
  d <- file.path(dir, gsub("[^A-Za-z0-9_-]+", "_", nom)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  w <- function(x, f) if (!is.null(x) && is.data.frame(x) && nrow(x)) escribir_csv(x, file.path(d, f))
  ...
  for (nm in names(gr)) try(.gg()$ggsave(file.path(d, paste0(nm, ".png")), gr[[nm]], width = 9, height = 6, dpi = 120), silent = TRUE)
  message("Análisis guardado en ", d)
  invisible(d)
}
```

Guarda CSV y PNG en `salida/analisis/<nombre_periodo>/` para que el dashboard los lea.

---

<a name="18_top25r"></a>
## 18. `18_top25.R` — Las 25 mejores gráficas autónomas

Este script es **autocontenido** y no depende del archivo 14. Contiene 25 funciones de graficación adicionales organizadas en 5 grupos:

| Grupo | Rango | Descripción |
|-------|-------|-------------|
| A. Actividad | 01-09 | Volumen, reloj, punchcard, polar heat, calendario, autores, pareto, bump, ridgeline |
| B. Sentimientos por mensaje | 10-15 | Heat, dominante, correlación, autor, media móvil |
| C. Perfil del periodo | 16-19 | Lollipop, rosa, ranking, waffle |
| D. Serie mensual | 20-22 | Facetas, heat, stream |
| E. Palabras y emojis | 23-25 | Palabras, emojis, sunburst |

### Función `ver_top25()`

```r
ver_top25 <- function(datos, a, serie = NULL, emojis = NULL, guardar = TRUE, pausa = 0, solo = NULL) {
  m0 <- datos$mensajes
  ms <- tryCatch(.t_con_sent(datos), error = function(e) m0)
  m  <- .t_prep(ms)
  niv <- a$nivel
  tokens <- datos$tokens
  ...
  lista <- list(
    "01_volumen_mes"     = function() t01_volumen_mes(m),
    "02_reloj"           = function() t02_reloj(m),
    ...
    "25_sunburst_emojis" = req(emojis, "salida/emojis_en_uso.csv", t25_sunburst_emojis)
  )
  if (!is.null(solo)) lista <- lista[solo]
  if (guardar) dir.create("salida/top25", showWarnings = FALSE, recursive = TRUE)
  
  ok <- 0; malas <- character()
  for (nm in names(lista)) {
    g <- tryCatch(lista[[nm]](), error = function(e) {
      cat(sprintf("%-20s FALLA: %s\n", nm, conditionMessage(e))); NULL })
    if (is.null(g)) { malas <- c(malas, nm); next }
    r <- tryCatch({ print(g); TRUE }, error = function(e) {
      cat(sprintf("%-20s FALLA al dibujar: %s\n", nm, conditionMessage(e))); FALSE })
    if (!r) { malas <- c(malas, nm); next }
    ok <- ok + 1; cat(sprintf("%-20s OK\n", nm))
    if (guardar) tryCatch(ggsave(file.path("salida/top25", paste0(nm, ".png")), g,
                                 width = 11, height = 7, dpi = 150, bg = "white"),
                         error = function(e) cat("   (no se pudo guardar el PNG)\n"))
    if (pausa > 0) Sys.sleep(pausa)
  }
  cat("\nListos:", ok, "de", length(lista), "\n")
  if (length(malas)) cat("Fallaron:", paste(malas, collapse = ", "), "\n")
  invisible(NULL)
}
```

Dibuja las 25 gráficas, informa cuáles fallaron y guarda PNG en `salida/top25/`.

---

<a name="bitacorar"></a>
## 19. `bitacora.R` — Motor de las dos bitácoras

Este script gestiona dos archivos de Excel:

1. **`bitacora_limpia.xlsx`**: Pasos de la ÚLTIMA ejecución exitosa (se sobrescribe cada vez).
2. **`bitacora_completa.xlsx`**: Cambios, ejecuciones, pasos y experimentos (solo se agregan filas).

### Funciones principales

| Función | Descripción |
|---------|-------------|
| `escribir_csv(x, f)` | CSV con BOM para que Excel lea tildes y emojis correctamente |
| `nuevo_ctx(params, cfg)` | Crea el contexto de ejecución `ctx` |
| `registrar_paso(ctx, datos, ...)` | Ejecuta un bloque de código y registra el paso en la bitácora |
| `registrar_hallazgo(ctx, ...)` | Registra un hallazgo sin modificar datos |
| `excluir(ctx, df, motivo)` | Separa filas excluidas |
| `exportar_bitacora(ctx, dir_bitacoras, extra_params)` | Exporta `bitacora_limpia.xlsx` |
| `vigilar_cambios(...)` | Detecta cambios automáticos en código y diccionarios |
| `registrar_ejecucion(...)` | Registra una ejecución completa en `bitacora_completa.xlsx` |
| `registrar_experimento(...)` | Registra experimentos post-preprocesamiento |
| `anotar_cambio(...)` | Anota cambios que no son de archivo |

### Hojas de `bitacora_completa.xlsx`

| Hoja | Columnas | Descripción |
|------|----------|-------------|
| Cambios | id_cambio, fecha, hora, tipo, archivo, seccion, problema_detectado, ... | Cada cambio en código o diccionarios |
| Ejecuciones | id_ejecucion, fecha, hora_inicio, hora_fin, duracion_seg, responsable, archivo, ... | Una fila por cada intento de preprocesamiento |
| Pasos por ejecución | id_ejecucion, id_instancia, fecha, hora, id_paso, etapa, campo_columna, ... | Una fila por cada paso de cada ejecución |
| Experimentos | id_experimento, fecha, hora, metodo, parametros, n_documentos, ... | Experimentos posteriores (TF-IDF, LDA, shallow...) |

### Detección automática de cambios

`vigilar_cambios()` vigila:
- `R/*.R` (todos los scripts de este directorio)
- `cargar_proyecto.R`, `ejecutar.R` (raíz del proyecto R)
- `config/*` (todos los archivos de configuración)

Si algo cambia, describe el cambio, pide justificación al usuario y lo anota en la hoja "Cambios" de `bitacora_completa.xlsx`.

---

## Flujo completo del proyecto

```
┌─────────────────────────────────────────────────────────────────┐
│  PARTE 1: PREPROCESAMIENTO (una vez con todo el dataset)        │
│                                                                 │
│  preprocesar() [00_main.R]                                      │
│    ├── cargar_config() [01_lectura.R]                           │
│    ├── leer_entrada() [01_lectura.R]                            │
│    ├── Etapa 1: Auditoría [01_lectura.R]                        │
│    ├── Etapa 2: Estructura [02_estructura.R]                    │
│    ├── Etapas 3-5: Calidad [03_calidad.R]                       │
│    ├── Etapa 6: Publicidad [04_publicidad.R]                    │
│    ├── Etapa 7: Emojis [05_emojis.R]                            │
│    ├── Etapa 8: Texto [06_texto.R]                              │
│    ├── Etapa 9: Género [06_texto.R]                             │
│    ├── Etapa 10: Tokenización [06_texto.R]                      │
│    ├── Etapa 11: Sentimientos [07_sentimientos.R]               │
│    ├── Etapas 12-13: Salida [08_salida.R]                       │
│    └── Exportar bitácora [bitacora.R]                           │
│                                                                 │
│  Salida: salida/mensajes_limpios.csv, tokens.csv, etc.          │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  PARTE 2: ANÁLISIS (filtrar por fechas, sin reprocesar)         │
│                                                                 │
│  cargar_datos_analisis("salida") [09_periodos.R]                │
│  analizar_periodo(datos, fechas) [16_analisis.R]                │
│    ├── nivel_sentimiento() [07_sentimientos.R / 09_periodos.R]  │
│    ├── tfidf_docs() [10_tfidf.R]                                │
│    ├── topicos_lda() [12_topicos.R]                             │
│    ├── shallow_linguistic() [11_shallow.R]                      │
│    └── sentimientos_libreria() [13_libreria.R]                  │
│                                                                 │
│  guardar_analisis(a) [16_analisis.R]                            │
│    └── graficos_todos() [14_graficos.R]                         │
└─────────────────────────────────────────────────────────────────┘
```

### Ejecución desde consola R

```r
setwd("C:/CODIGO/AnSent/r")
source("cargar_proyecto.R")
res <- preprocesar("data/result.json", consola = "didactico")
datos <- cargar_datos_analisis("salida")
a <- analizar_periodo(datos, c("2023-01-01", "2023-03-31"))
guardar_analisis(a)
```

### Ejecución desde Plumber (API)

```bash
Rscript r/plumber_api.R
```

Endpoints disponibles: `POST /paso/preprocesar`, `POST /paso/analizar-periodo`, `POST /paso/comparar-periodos`, `POST /paso/analizar-oracion`, `GET /salida/archivos`, `GET /dashboard/graficos`, `PUT /sentimientos.json`.
