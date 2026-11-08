# Diccionario de Datos — AnSent

Esquema de base de datos relacional para el sistema de análisis de sentimientos **AnSent**.
Compatible con **PostgreSQL** (pgAdmin, ERD). Script SQL: `docs/schema_bbdd.sql`.

Este diccionario documenta todas las tablas, columnas, tipos de datos, restricciones y relaciones del esquema.

---

## Índice de Tablas

| Categoría | Tabla | Descripción |
|-----------|-------|-------------|
| Configuración | `codigos_materia` | Prefijos de códigos de materia |
| Configuración | `abreviaturas` | Abreviaturas de chat y su normalización |
| Configuración | `emoticonos` | Emoticonos de texto y su equivalente emoji |
| Configuración | `emojis` | Diccionario maestro de emojis |
| Configuración | `genero` | Diccionario de referencias de género |
| Configuración | `justificaciones_analisis` | Justificaciones teóricas del análisis |
| Configuración | `stopwords` | Stopwords personalizadas con acción |
| Configuración | `periodos` | Periodos predefinidos para análisis |
| Configuración | `palabras_anuncio` | Reglas de detección de publicidad |
| Sentimientos | `sentimientos` | Diccionario propio de sentimientos |
| Sentimientos | `sentimientos_palabras` | Palabras por sentimiento |
| Sentimientos | `sentimientos_raices` | Raíces por sentimiento |
| Dataset Entrada | `chats` | Metadata del chat de Telegram |
| Dataset Entrada | `mensajes_crudos` | Mensajes crudos del JSON de entrada |
| Dataset Limpio | `mensajes_limpios` | Dataset limpio final (una fila por mensaje) |
| Dataset Limpio | `sentimientos_por_mensaje` | Nivel de sentimiento por mensaje |
| Dataset Limpio | `tokens` | Tokens por mensaje |
| Análisis | `niveles_por_periodo` | Nivel de sentimientos por periodo |
| Análisis | `serie_sentimientos` | Serie temporal de sentimientos |
| Análisis | `tfidf_resultados` | Resultados TF-IDF |
| Análisis | `topicos` | Tópicos LDA |
| Análisis | `topicos_etiquetas` | Etiquetas de tópicos |
| Análisis | `topicos_terminos` | Términos por tópico (beta) |
| Análisis | `topicos_por_documento` | Tópico dominante por documento |
| Análisis | `libreria_sentimientos` | Sentimientos de librería syuzhet |
| Análisis | `comparacion_niveles` | Comparación entre dos periodos |
| Salidas | `salida_emojis_en_uso` | Emojis en uso por ejecución |
| Salidas | `salida_stopwords_aplicadas` | Stopwords aplicadas por ejecución |
| Salidas | `salida_mensajes_excluidos` | Mensajes excluidos por ejecución |
| Salidas | `salida_resumen` | Resumen de cada ejecución |
| Bitácoras | `ejecuciones` | Registro de ejecuciones del pipeline |
| Bitácoras | `ejecucion_pasos` | Pasos de cada ejecución |
| Bitácoras | `cambios` | Cambios en código y diccionarios |
| Bitácoras | `experimentos` | Experimentos post-preprocesamiento |
| Express | `bitacora_registros` | Bitácora de cambios del dataset (Express) |
| Express | `configuraciones` | Configuraciones guardadas desde frontend |
| Express | `graficos_info` | Archivos generados por cada paso |

Vistas | `v_resumen_sentimientos` | Resumen de sentimientos por ejecución |
Vistas | `v_ejecucion_resumen` | Resumen de ejecución con conteos |

---

## 1. TABLAS DE CONFIGURACIÓN Y DICCIONARIOS

### 1.1 `codigos_materia`

Prefijos de códigos de materia académica (INF, MAT, LAB, etc.) utilizados para agrupar tokens por materia en el análisis de texto.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `prefijo` | `VARCHAR(10)` | NO | PK | Prefijo del código de materia (ej. INF, MAT, LAB) |
| `creado_en` | `TIMESTAMP` | SÍ | | Fecha de creación del registro |

**Origen:** `r/config/codigos_materia.csv`

---

### 1.2 `abreviaturas`

Abreviaturas de lenguaje de chat y su forma normal para normalización léxica antes del análisis de sentimientos.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `abreviatura` | `VARCHAR(50)` | NO | UK | Abreviatura de chat (ej. q, xq, tmb) |
| `normal` | `VARCHAR(100)` | NO | | Forma normal escrita completa (ej. que, porque, también) |
| `categoria` | `VARCHAR(50)` | SÍ | | Categoría de la abreviatura (conector, cortesía, etc.) |
| `justificacion` | `TEXT` | SÍ | | Justificación de por qué se conserva o elimina |

**Origen:** `r/config/abreviaturas.csv`

---

### 1.3 `emoticonos`

Mapeo de emoticonos de texto (:), :(, :D, etc.) a su equivalente emoji Unicode.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `emoticono` | `VARCHAR(20)` | NO | UK | Emoticono de texto (ej. :), :D, <3) |
| `emoji` | `VARCHAR(20)` | SÍ | | Emoji equivalente (ej. 🙂, 😀, ❤) |
| `justificacion` | `TEXT` | SÍ | | Justificación de la equivalencia |

**Origen:** `r/config/emoticonos.csv`

---

### 1.4 `emojis`

Diccionario maestro de emojis con su significado en español, sentimiento asociado y polaridad.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `emoji` | `VARCHAR(20)` | NO | UK | Carácter emoji (ej. 👍, 😭, 😡) |
| `significado_es` | `VARCHAR(200)` | SÍ | | Significado en español del emoji |
| `sentimiento` | `VARCHAR(50)` | SÍ | | Sentimiento asociado (nombre de un sentimiento del diccionario propio) |
| `polaridad` | `INTEGER` | SÍ | CK | Polaridad: -1 (negativo), 0 (neutral), 1 (positivo) |
| `nombre_unicode` | `VARCHAR(200)` | SÍ | | Nombre oficial Unicode del emoji |
| `pendiente` | `BOOLEAN` | SÍ | DEFAULT FALSE | TRUE si el emoji aún no tiene significado asignado |

**Restricción CHECK:** `polaridad IN (-1, 0, 1)`

**Origen:** `r/config/emojis.csv`

---

### 1.5 `genero`

Diccionario de referencias de género para detectar a quién se refiere cada mensaje (femenino, masculino, ambos, inclusivo, ninguno).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `palabra` | `VARCHAR(100)` | NO | | Palabra de referencia (ej. ella, chicas, profesor) |
| `genero` | `VARCHAR(20)` | SÍ | CK | Género: femenino o masculino |
| `tipo` | `VARCHAR(50)` | SÍ | | Tipo gramatical: pronombre, sustantivo |
| `justificacion` | `TEXT` | SÍ | | Justificación de la inclusión |

**Restricción CHECK:** `genero IN ('femenino', 'masculino')`

**Origen:** `r/config/genero.csv`

---

### 1.6 `justificaciones_analisis`

Justificaciones teóricas para cada tipo de análisis realizado en el proyecto.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `VARCHAR(50)` | NO | PK | Identificador único (ej. stopwords, tfidf, lda, nivel_sentimiento) |
| `que_muestra` | `VARCHAR(200)` | SÍ | | Descripción breve de lo que muestra el análisis |
| `justificacion_teorica` | `TEXT` | SÍ | | Fundamento teórico o referencia académica |
| `referencia` | `TEXT` | SÍ | | Citación bibliográfica o fuente |

**Origen:** `r/config/justificaciones_analisis.csv`

---

### 1.7 `stopwords`

Lista de stopwords personalizadas con su acción (eliminar/conservar) y justificación.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `palabra` | `VARCHAR(100)` | NO | | Palabra vacía (ej. el, la, de, que) |
| `accion` | `VARCHAR(20)` | NO | CK | Acción: eliminar o conservar |
| `categoria` | `VARCHAR(50)` | SÍ | | Categoría: artículo, negación, intensificador, pronombre_género, etc. |
| `justificacion` | `TEXT` | SÍ | | Justificación de la acción tomada |

**Restricción CHECK:** `accion IN ('eliminar', 'conservar')`

**Origen:** `r/config/stopwords.csv`

---

### 1.8 `periodos`

Periodos predefinidos para el análisis temporal (ej. todo_2023, todo_2024).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `nombre` | `VARCHAR(100)` | NO | UK | Nombre del periodo (ej. todo_2023) |
| `fecha_inicio` | `DATE` | NO | | Fecha de inicio del periodo |
| `fecha_fin` | `DATE` | NO | | Fecha de fin del periodo |

**Origen:** `r/config/periodos.csv`

---

### 1.9 `palabras_anuncio`

Reglas para detectar publicidad y anuncios mediante puntaje compuesto de señales estructurales y frases.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `tipo` | `VARCHAR(30)` | NO | | Tipo de regla: estructura, frase, regex |
| `patron` | `VARCHAR(200)` | NO | | Patrón a buscar (frase, expresión regular, etc.) |
| `peso` | `INTEGER` | SÍ | DEFAULT 1 | Peso de la regla en el puntaje compuesto |
| `parametro` | `VARCHAR(50)` | SÍ | | Parámetro numérico (ej. 400 para largo, 4 para muchos_emojis) |
| `categoria` | `VARCHAR(50)` | SÍ | | Categoría: estructura, llamado_acción, invitación_grupo |
| `justificacion` | `TEXT` | SÍ | | Justificación de la regla |

**Origen:** `r/config/palabras_anuncio.csv`

---

## 2. TABLAS DE SENTIMIENTOS

### 2.1 `sentimientos`

Diccionario propio de sentimientos con estado activo/inactivo, polaridad y definiciones.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `orden` | `INTEGER` | NO | | Orden de presentación (1 a 15) |
| `nombre` | `VARCHAR(50)` | NO | UK | Nombre del sentimiento (ej. alegría, enojo, tristeza) |
| `polaridad` | `INTEGER` | SÍ | CK | Polaridad: -1 (negativo), 0 (neutral), 1 (positivo) |
| `activo` | `BOOLEAN` | SÍ | DEFAULT TRUE | Indica si el sentimiento está activo para el análisis |
| `definicion` | `TEXT` | SÍ | | Definición del sentimiento |
| `comentario_archivo` | `TEXT` | SÍ | | Comentario del archivo JSON (_comentario) |

**Restricción CHECK:** `polaridad IN (-1, 0, 1)`

**Origen:** `r/config/sentimientos.json`

---

### 2.2 `sentimientos_palabras`

Relación muchos a muchos entre sentimientos y las palabras que los identifican.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `sentimiento_id` | `INTEGER` | NO | FK | Referencia a `sentimientos.id` |
| `palabra` | `VARCHAR(100)` | NO | | Palabra asociada al sentimiento |

**Restricción UNIQUE:** `(sentimiento_id, palabra)`

**Origen:** Campo `palabras[]` de cada sentimiento en `sentimientos.json`

---

### 2.3 `sentimientos_raices`

Relación muchos a muchos entre sentimientos y las raíces de palabras (para búsqueda por prefijo).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `sentimiento_id` | `INTEGER` | NO | FK | Referencia a `sentimientos.id` |
| `raiz` | `VARCHAR(100)` | NO | | Raíz de palabra (ej. alegr, agradec, esperanz) |

**Restricción UNIQUE:** `(sentimiento_id, raiz)`

**Origen:** Campo `raices[]` de cada sentimiento en `sentimientos.json`

---

## 3. TABLAS DEL DATASET DE ENTRADA

### 3.1 `chats`

Metadata del chat de Telegram de donde provienen los mensajes.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `INTEGER` | NO | PK | ID del chat de Telegram |
| `name` | `VARCHAR(200)` | SÍ | | Nombre del chat |
| `type` | `VARCHAR(50)` | SÍ | | Tipo de chat (private_supergroup, group, etc.) |
| `fecha_ingesta` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de ingestión al sistema |

**Origen:** Campo raíz del archivo `r/data/result.json`

---

### 3.2 `mensajes_crudos`

Mensajes crudos leídos directamente del archivo JSON de entrada, antes de cualquier procesamiento.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id_mensaje` | `INTEGER` | NO | PK (parte) | ID del mensaje en Telegram |
| `chat_id` | `INTEGER` | NO | PK (parte), FK | Referencia a `chats.id` |
| `tipo_registro` | `VARCHAR(20)` | SÍ | | Tipo: message, service, etc. |
| `fecha_raw` | `TEXT` | SÍ | | Fecha original como texto ISO |
| `fecha_hora` | `TIMESTAMP` | SÍ | | Fecha parseada (hora local La Paz) |
| `autor_raw` | `VARCHAR(200)` | SÍ | | Nombre del autor original |
| `autor_id` | `VARCHAR(100)` | SÍ | | ID del autor en Telegram |
| `responde_a` | `INTEGER` | SÍ | | ID del mensaje al que responde |
| `editado` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si el mensaje fue editado |
| `reenviado_de` | `VARCHAR(200)` | SÍ | | Origen del reenvío |
| `texto_raw` | `TEXT` | SÍ | | Texto original del mensaje |
| `texto_era_lista` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si el texto venía como lista de fragmentos |
| `tipo_contenido` | `VARCHAR(50)` | SÍ | | Tipo: texto, foto, video, sticker, archivo, audio, encuesta |
| `sticker_emoji` | `VARCHAR(20)` | SÍ | | Emoji asociado al sticker |
| `reacciones` | `TEXT` | SÍ | | Reacciones del mensaje (formato "👍:2|👎:1") |
| `accion_servicio` | `VARCHAR(100)` | SÍ | | Acción de servicio (join_group_by_link, etc.) |

**Índices:** `idx_mensajes_crudos_fecha`, `idx_mensajes_crudos_autor`, `idx_mensajes_crudos_tipo`

**Origen:** Campo `messages[]` de `r/data/result.json`

---

## 4. TABLAS DEL DATASET LIMPIO

### 4.1 `mensajes_limpios`

Dataset limpio final: una fila por mensaje procesado con todas las variables derivadas del pipeline de 13 etapas.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id_mensaje` | `INTEGER` | NO | PK (parte) | ID del mensaje |
| `chat_id` | `INTEGER` | NO | PK (parte), FK | Referencia a `chats.id` |
| `fecha_hora` | `TIMESTAMP` | SÍ | | Fecha y hora del mensaje |
| `fecha` | `DATE` | SÍ | | Fecha del mensaje |
| `anio` | `INTEGER` | SÍ | | Año del mensaje |
| `mes` | `INTEGER` | SÍ | | Mes del mensaje |
| `anio_mes` | `VARCHAR(7)` | SÍ | | Formato YYYY-MM |
| `trimestre` | `VARCHAR(10)` | SÍ | | Formato YYYY-Tn |
| `dia_semana` | `VARCHAR(20)` | SÍ | | Nombre del día de la semana |
| `hora` | `INTEGER` | SÍ | | Hora del día (0-23) |
| `autor` | `VARCHAR(200)` | SÍ | | Autor (anonimizado si aplica) |
| `autor_id` | `VARCHAR(100)` | SÍ | | ID del autor |
| `tipo_contenido` | `VARCHAR(50)` | SÍ | | Tipo de contenido |
| `es_respuesta` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si es respuesta a otro mensaje |
| `responde_a` | `INTEGER` | SÍ | | ID del mensaje al que responde |
| `editado` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si fue editado |
| `reenviado` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si es reenvío |
| `reenviado_de` | `VARCHAR(200)` | SÍ | | Origen del reenvío |
| `n_caracteres` | `INTEGER` | SÍ | | Número de caracteres del texto limpio |
| `n_palabras` | `INTEGER` | SÍ | | Número de palabras |
| `n_tokens` | `INTEGER` | SÍ | | Número de tokens después de stopwords |
| `n_enlaces` | `INTEGER` | SÍ | | Número de enlaces URL |
| `n_hashtags` | `INTEGER` | SÍ | | Número de hashtags |
| `n_menciones` | `INTEGER` | SÍ | | Número de menciones @usuario |
| `tiene_telefono` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si contiene número de teléfono |
| `n_emojis` | `INTEGER` | SÍ | | Número de emojis |
| `emojis_lista` | `TEXT` | SÍ | | Lista de emojis separados por espacio |
| `sentimiento_emoji` | `VARCHAR(50)` | SÍ | | Sentimiento dominante de los emojis |
| `polaridad_emoji` | `NUMERIC(5,3)` | SÍ | | Polaridad promedio de los emojis |
| `reacciones_total` | `INTEGER` | SÍ | DEFAULT 0 | Total de reacciones recibidas |
| `reacciones_pos` | `INTEGER` | SÍ | DEFAULT 0 | Reacciones positivas |
| `reacciones_neg` | `INTEGER` | SÍ | DEFAULT 0 | Reacciones negativas |
| `outlier_longitud` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si es outlier por longitud |
| `outlier_rafaga` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si es outlier por ráfaga de mensajes |
| `puntaje_publicidad` | `NUMERIC(5,2)` | SÍ | | Puntaje de detección de publicidad |
| `motivo_publicidad` | `TEXT` | SÍ | | Motivo de la detección de publicidad |
| `posible_publicidad` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si se detectó como publicidad |
| `n_ref_femenino` | `INTEGER` | SÍ | DEFAULT 0 | Referencias femeninas detectadas |
| `n_ref_masculino` | `INTEGER` | SÍ | DEFAULT 0 | Referencias masculinas detectadas |
| `n_ref_inclusivo` | `INTEGER` | SÍ | DEFAULT 0 | Referencias inclusivas detectadas |
| `genero_mencionado` | `VARCHAR(20)` | SÍ | | Género mencionado: femenino, masculino, ambos, inclusivo, ninguno |
| `texto_original` | `TEXT` | SÍ | | Texto original normalizado (UTF-8 NFC) |
| `texto_traducido` | `TEXT` | SÍ | | Texto con emojis traducidos a significado |
| `texto_limpio` | `TEXT` | SÍ | | Texto limpio (sin enlaces, menciones, signos, etc.) |
| `texto_tokens` | `TEXT` | SÍ | | Tokens separados por espacio |
| `polaridad_msg` | `VARCHAR(20)` | SÍ | | Polaridad del mensaje: positivo, negativo, neutral |
| `polaridad_score` | `NUMERIC(5,3)` | SÍ | | Score de polaridad (-1 a 1) |
| `sentimiento_dominante` | `VARCHAR(50)` | SÍ | | Sentimiento dominante del mensaje |
| `hits_total` | `INTEGER` | SÍ | DEFAULT 0 | Total de coincidencias de sentimientos |
| `n_negados` | `INTEGER` | SÍ | DEFAULT 0 | Total de términos negados |

**Índices:** `idx_mensajes_limpios_fecha`, `idx_mensajes_limpios_anio_mes`, `idx_mensajes_limpios_autor`, `idx_mensajes_limpios_polaridad`, `idx_mensajes_limpios_dominante`, `idx_mensajes_limpios_genero`

**Origen:** Salida de `08_salida.R` (función `exportar_salidas`) → `salida/mensajes_limpios.csv`

---

### 4.2 `sentimientos_por_mensaje`

Nivel de sentimiento (%) por mensaje y por cada sentimiento activo del diccionario.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `id_mensaje` | `INTEGER` | NO | FK | Referencia a `mensajes_limpios.id_mensaje` |
| `chat_id` | `INTEGER` | NO | FK | Referencia a `mensajes_limpios.chat_id` |
| `sentimiento` | `VARCHAR(50)` | NO | | Nombre del sentimiento |
| `pct` | `NUMERIC(6,3)` | SÍ | | Porcentaje (0 a 100) = 100 * coincidencias / n_tokens |
| `hits` | `INTEGER` | SÍ | DEFAULT 0 | Número de coincidencias brutas |

**Índices:** `idx_sentimientos_por_mensaje_msg`, `idx_sentimientos_por_mensaje_sent`

**Origen:** `07_sentimientos.R` (función `calcular_sentimientos`) → columnas `sent_*` y `pct_*` en `mensajes_limpios.csv`

---

### 4.3 `tokens`

Tokens por mensaje para TF-IDF, n-gramas y topic modeling (LDA).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `id_mensaje` | `INTEGER` | NO | FK | Referencia a `mensajes_limpios.id_mensaje` |
| `chat_id` | `INTEGER` | NO | FK | Referencia a `mensajes_limpios.chat_id` |
| `fecha` | `DATE` | SÍ | | Fecha del mensaje |
| `anio_mes` | `VARCHAR(7)` | SÍ | | Formato YYYY-MM |
| `token` | `VARCHAR(100)` | NO | | Token (palabra) individual |

**Índices:** `idx_tokens_msg`, `idx_tokens_token`, `idx_tokens_anio_mes`

**Origen:** `salida/tokens.csv`

---

## 5. TABLAS DE ANÁLISIS

### 5.1 `niveles_por_periodo`

Nivel promedio de cada sentimiento para un período de análisis específico.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo` | `VARCHAR(100)` | NO | | Nombre del período |
| `fecha_inicio` | `DATE` | SÍ | | Fecha de inicio del período |
| `fecha_fin` | `DATE` | SÍ | | Fecha de fin del período |
| `sentimiento` | `VARCHAR(50)` | NO | | Nombre del sentimiento |
| `nivel_pct` | `NUMERIC(6,3)` | SÍ | | Nivel promedio de pct_* |
| `mensajes_pct` | `NUMERIC(6,3)` | SÍ | | % de mensajes con al menos una coincidencia |
| `n_mensajes` | `INTEGER` | SÍ | | Número de mensajes en el período |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Índices:** `idx_niveles_periodo`, `idx_niveles_sentimiento`

**Origen:** `09_periodos.R` (función `nivel_sentimiento`) y `16_analisis.R` (función `analizar_periodo`)

---

### 5.2 `serie_sentimientos`

Serie temporal de sentimientos (por mes, semana o día según el rango de fechas).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo` | `VARCHAR(100)` | NO | | Nombre del período |
| `fecha` | `DATE` | NO | | Fecha de la unidad temporal |
| `sentimiento` | `VARCHAR(50)` | NO | | Nombre del sentimiento |
| `pct` | `NUMERIC(6,3)` | SÍ | | Porcentaje promedio en esa fecha |
| `n_mensajes` | `INTEGER` | SÍ | | Número de mensajes en esa fecha |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Índices:** `idx_serie_periodo`, `idx_serie_sentimiento`

**Origen:** `09_periodos.R` (función `serie_sentimientos`) y `14_graficos.R` (función `serie_periodo`)

---

### 5.3 `tfidf_resultados`

Resultados del cálculo TF-IDF por documento y término.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo` | `VARCHAR(100)` | NO | | Nombre del período |
| `doc` | `VARCHAR(100)` | NO | | Documento (mes o período) |
| `token` | `VARCHAR(100)` | NO | | Término |
| `n` | `INTEGER` | SÍ | DEFAULT 1 | Frecuencia del término en el documento |
| `tf` | `NUMERIC(8,6)` | SÍ | | Term Frequency: n / total_términos_documento |
| `idf` | `NUMERIC(8,6)` | SÍ | | Inverse Document Frequency: log(N / df) |
| `tf_idf` | `NUMERIC(10,6)` | SÍ | | tf * idf |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Índices:** `idx_tfidf_periodo`, `idx_tfidf_token`

**Origen:** `10_tfidf.R` (función `tfidf_docs`)

---

### 5.3 `topicos`

Metadatos de cada modelo LDA entrenado por período.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo` | `VARCHAR(100)` | NO | | Nombre del período |
| `k` | `INTEGER` | NO | | Número de tópicos |
| `agrupar` | `VARCHAR(10)` | SÍ | CK | Unidad de agrupación: dia o mes |
| `n_documentos` | `INTEGER` | SÍ | | Número de documentos en el modelo |
| `n_terminos` | `INTEGER` | SÍ | | Número de términos únicos |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Restricción CHECK:** `agrupar IN ('dia', 'mes')`

**Índices:** `idx_topicos_periodo`

**Origen:** `12_topicos.R` (función `topicos_lda`)

---

### 5.4 `topicos_etiquetas`

Etiqueta descriptiva de cada tópico (las 3 palabras con mayor probabilidad beta).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `topico_id` | `INTEGER` | NO | FK | Referencia a `topicos.id` |
| `topico` | `VARCHAR(20)` | NO | | Identificador del tópico (ej. T1, T2) |
| `etiqueta` | `VARCHAR(200)` | SÍ | | Etiqueta generada automáticamente |

**Origen:** `12_topicos.R`

---

### 5.5 `topicos_terminos`

Términos y su probabilidad beta dentro de cada tópico LDA.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `topico_id` | `INTEGER` | NO | FK | Referencia a `topicos.id` |
| `termino` | `VARCHAR(100)` | NO | | Término |
| `beta` | `NUMERIC(10,6)` | SÍ | | Probabilidad del término en el tópico |

**Origen:** `12_topicos.R` (matriz beta de posterior del modelo LDA)

---

### 5.6 `topicos_por_documento`

Tópico dominante asignado a cada documento (fecha) del corpus.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `topico_id` | `INTEGER` | NO | FK | Referencia a `topicos.id` |
| `doc` | `VARCHAR(100)` | NO | | Identificador del documento (fecha o anio_mes) |
| `topico` | `VARCHAR(20)` | SÍ | | Tópico dominante asignado |
| `peso` | `NUMERIC(8,6)` | SÍ | | Proporción del tópico en el documento |

**Origen:** `12_topicos.R` (matriz gamma de posterior del modelo LDA)

---

### 5.7 `libreria_sentimientos`

Resultados del análisis de sentimientos usando la librería syuzhet (léxico NRC en español).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo` | `VARCHAR(100)` | NO | | Nombre del período |
| `sentimiento` | `VARCHAR(50)` | NO | | Sentimiento o emoción (8 emociones + 2 polaridades) |
| `tipo` | `VARCHAR(30)` | SÍ | | Tipo: emocion (8) o polaridad |
| `nivel_pct` | `NUMERIC(6,3)` | SÍ | | Nivel promedio (%) |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Índices:** `idx_libreria_periodo`

**Origen:** `13_libreria.R` (función `sentimientos_libreria`)

---

### 5.8 `comparacion_niveles`

Comparación del nivel de sentimientos entre dos periodos (A y B).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `periodo_a` | `VARCHAR(100)` | NO | | Nombre del período A |
| `periodo_b` | `VARCHAR(100)` | NO | | Nombre del período B |
| `sentimiento` | `VARCHAR(50)` | NO | | Nombre del sentimiento |
| `nivel_a` | `NUMERIC(6,3)` | SÍ | | Nivel en el período A |
| `nivel_b` | `NUMERIC(6,3)` | SÍ | | Nivel en el período B |
| `diferencia` | `NUMERIC(6,3)` | SÍ | | Diferencia (B - A) en puntos porcentuales |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Origen:** `16_analisis.R` (función `comparar_periodos`)

---

## 6. TABLAS DE SALIDAS GENERADAS

### 6.1 `salida_emojis_en_uso`

Frecuencia de emojis usados en texto y reacciones por cada ejecución.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `ejecucion_id` | `INTEGER` | SÍ | FK | Referencia a `ejecuciones.id` |
| `emoji` | `VARCHAR(20)` | NO | | Carácter emoji |
| `en_texto` | `INTEGER` | SÍ | DEFAULT 0 | Frecuencia en el texto de mensajes |
| `en_reacciones` | `INTEGER` | SÍ | DEFAULT 0 | Frecuencia en reacciones |
| `significado_es` | `VARCHAR(200)` | SÍ | | Significado en español |
| `sentimiento` | `VARCHAR(50)` | SÍ | | Sentimiento asociado |
| `polaridad` | `INTEGER` | SÍ | | Polaridad del emoji |
| `pendiente` | `BOOLEAN` | SÍ | DEFAULT FALSE | Si aún no tiene significado asignado |

**Origen:** `salida/emojis_en_uso.csv`

---

### 6.2 `salida_stopwords_aplicadas`

Registro de qué stopwords se eliminaron y cuáles se conservaron en cada ejecución.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `ejecucion_id` | `INTEGER` | SÍ | FK | Referencia a `ejecuciones.id` |
| `palabra` | `VARCHAR(100)` | NO | | Palabra procesada |
| `decision` | `VARCHAR(20)` | SÍ | | Decisión: eliminada o conservada |
| `motivo` | `VARCHAR(200)` | SÍ | | Motivo de la decisión |
| `ocurrencias` | `INTEGER` | SÍ | | Número de ocurrencias en el corpus |
| `justificacion` | `TEXT` | SÍ | | Justificación de la decisión |

**Origen:** `salida/stopwords_aplicadas.csv`

---

### 6.3 `salida_mensajes_excluidos`

Mensajes excluidos del dataset limpio con su motivo de exclusión.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `ejecucion_id` | `INTEGER` | SÍ | FK | Referencia a `ejecuciones.id` |
| `id_mensaje` | `INTEGER` | SÍ | | ID del mensaje excluido |
| `fecha_hora` | `TIMESTAMP` | SÍ | | Fecha del mensaje |
| `autor` | `VARCHAR(200)` | SÍ | | Autor del mensaje |
| `tipo_contenido` | `VARCHAR(50)` | SÍ | | Tipo de contenido |
| `motivo_exclusion` | `TEXT` | SÍ | | Motivo de la exclusión |
| `puntaje_publicidad` | `NUMERIC(5,2)` | SÍ | | Puntaje de publicidad si aplica |
| `motivo_publicidad` | `TEXT` | SÍ | | Motivo de detección de publicidad |
| `texto_original` | `TEXT` | SÍ | | Texto original truncado |

**Origen:** `salida/mensajes_excluidos.csv`

---

### 6.4 `salida_resumen`

Resumen estadístico de cada ejecución del pipeline.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `ejecucion_id` | `INTEGER` | SÍ | FK | Referencia a `ejecuciones.id` |
| `archivo` | `VARCHAR(200)` | SÍ | | Nombre del archivo de entrada |
| `registros_leidos` | `INTEGER` | SÍ | | Total de registros leídos |
| `mensajes_limpios` | `INTEGER` | SÍ | | Total de mensajes en dataset limpio |
| `mensajes_excluidos` | `INTEGER` | SÍ | | Total de mensajes excluidos |
| `rango_fechas_inicio` | `DATE` | SÍ | | Fecha inicial del rango |
| `rango_fechas_fin` | `DATE` | SÍ | | Fecha final del rango |
| `sentimientos_activos` | `TEXT` | SÍ | | Lista de nombres de sentimientos activos |
| `polaridad_distribucion` | `TEXT` | SÍ | | Distribución de polaridad (JSON) |
| `emojis_pendientes` | `INTEGER` | SÍ | DEFAULT 0 | Emojis pendientes de traducción |
| `pasos_bitacora` | `INTEGER` | SÍ | | Número de pasos registrados en bitácora |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Origen:** `salida/resumen.json`

---

## 7. TABLAS DE BITÁCORAS Y EJECUCIONES

### 7.1 `ejecuciones`

Registro de cada ejecución del pipeline `preprocesar()`.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `fecha` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha y hora de ejecución |
| `responsable` | `VARCHAR(200)` | SÍ | | Nombre de quien ejecutó |
| `archivo` | `VARCHAR(200)` | SÍ | | Nombre del archivo de entrada |
| `archivo_md5` | `VARCHAR(64)` | SÍ | | Hash MD5 del archivo de entrada |
| `evento` | `VARCHAR(50)` | SÍ | | Tipo de evento: primera ejecución, misma dataset, dataset nuevo, etc. |
| `parametros` | `TEXT` | SÍ | | Parámetros usados (JSON) |
| `estado` | `VARCHAR(20)` | SÍ | | Estado: ok, error, detenido |
| `paso_donde_paro` | `VARCHAR(100)` | SÍ | | Paso donde se detuvo si hubo error |
| `mensaje_error` | `TEXT` | SÍ | | Mensaje de error si falló |
| `pasos_registrados` | `INTEGER` | SÍ | DEFAULT 0 | Número de pasos ejecutados |
| `registros_leidos` | `INTEGER` | SÍ | | Registros leídos del archivo de entrada |
| `mensajes_limpios` | `INTEGER` | SÍ | | Mensajes en el dataset limpio |
| `mensajes_excluidos` | `INTEGER` | SÍ | | Mensajes excluidos |
| `emojis_pendientes` | `INTEGER` | SÍ | DEFAULT 0 | Emojis pendientes de traducción |
| `cambios_detectados` | `TEXT` | SÍ | | IDs de cambios asociados a esta ejecución |

**Origen:** `bitacora.R` (función `registrar_ejecucion`)

---

### 7.2 `ejecucion_pasos`

Detalle de cada paso ejecutado dentro de una ejecución del pipeline.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `ejecucion_id` | `INTEGER` | NO | FK | Referencia a `ejecuciones.id` |
| `id_instancia` | `VARCHAR(50)` | SÍ | | Identificador de instancia (ejecucion_id + id_paso) |
| `id_paso` | `VARCHAR(20)` | SÍ | | Identificador del paso (P01, P02, ...) |
| `etapa` | `VARCHAR(100)` | SÍ | | Nombre de la metodología del paso |
| `campo_columna` | `VARCHAR(100)` | SÍ | | Columna afectada por el paso |
| `tipo_problema` | `VARCHAR(100)` | SÍ | | Tipo de problema abordado |
| `accion_realizada` | `TEXT` | SÍ | | Acción que se realizó |
| `filas_antes` | `INTEGER` | SÍ | | Filas antes del paso |
| `filas_despues` | `INTEGER` | SÍ | | Filas después del paso |
| `filas_afectadas` | `INTEGER` | SÍ | | Filas afectadas por el paso |
| `impacto_dataset` | `TEXT` | SÍ | | Descripción del impacto en el dataset |
| `ejemplo_antes` | `TEXT` | SÍ | | Ejemplo antes del cambio |
| `ejemplo_despues` | `TEXT` | SÍ | | Ejemplo después del cambio |
| `mensaje_error` | `TEXT` | SÍ | | Mensaje de error si hubo fallo |
| `script` | `TEXT` | SÍ | | Código ejecutado en el paso |

**Índices:** `idx_ejecucion_pasos_ejecucion`

**Origen:** `bitacora.R` (función `registrar_paso`)

---

### 7.3 `cambios`

Cambios detectados automáticamente en código y diccionarios (vigilancia de cambios).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `fecha` | `DATE` | SÍ | | Fecha del cambio |
| `hora` | `TIME` | SÍ | | Hora del cambio |
| `tipo` | `VARCHAR(20)` | SÍ | | Tipo: código o diccionario |
| `archivo` | `VARCHAR(200)` | SÍ | | Ruta del archivo modificado |
| `seccion` | `VARCHAR(100)` | SÍ | | Sección del archivo donde ocurrió el cambio |
| `problema_detectado` | `TEXT` | SÍ | | Problema que se detectó |
| `como_se_detecto` | `TEXT` | SÍ | | Cómo se detectó el cambio |
| `cambio_realizado` | `TEXT` | SÍ | | Descripción del cambio realizado |
| `justificacion` | `TEXT` | SÍ | | Justificación proporcionada por el usuario |
| `resultado` | `TEXT` | SÍ | | Resultado después del cambio |
| `ejecucion_prueba` | `TEXT` | SÍ | | IDs de ejecuciones donde se probó el cambio |
| `responsable` | `VARCHAR(200)` | SÍ | | Responsable del cambio |
| `estado_registro` | `VARCHAR(30)` | SÍ | | Estado: completo, FALTA JUSTIFICAR |

**Origen:** `bitacora.R` (función `vigilar_cambios`)

---

### 7.4 `experimentos`

Experimentos realizados después del preprocesamiento (TF-IDF, shallow, LDA, librería).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `fecha` | `DATE` | SÍ | | Fecha del experimento |
| `hora` | `TIME` | SÍ | | Hora del experimento |
| `id_ejecucion_preprocesamiento` | `INTEGER` | SÍ | FK | Referencia a `ejecuciones.id` |
| `dataset` | `VARCHAR(200)` | SÍ | | Nombre del dataset usado |
| `dataset_md5` | `VARCHAR(64)` | SÍ | | Hash MD5 del dataset |
| `metodo` | `VARCHAR(100)` | SÍ | | Método: tfidf, topic modeling, shallow, libreria |
| `parametros` | `TEXT` | SÍ | | Parámetros del experimento |
| `n_documentos` | `INTEGER` | SÍ | | Número de documentos |
| `tamano_vocabulario` | `INTEGER` | SÍ | | Tamaño del vocabulario |
| `resultado_principal` | `TEXT` | SÍ | | Resultado principal del experimento |
| `archivo_resultado` | `VARCHAR(200)` | SÍ | | Archivo de resultado generado |
| `notas` | `TEXT` | SÍ | | Notas adicionales |
| `responsable` | `VARCHAR(200)` | SÍ | | Responsable del experimento |

**Origen:** `bitacora.R` (función `registrar_experimento`)

---

## 8. TABLAS EXISTENTES DE EXPRESS (compatibilidad)

### 8.1 `bitacora_registros`

Bitácora de cambios del dataset que escriben Plumber y Express.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `fecha` | `TEXT` | NO | | Fecha en formato ISO 8601 |
| `tipo_cambio` | `TEXT` | NO | | Tipo: preprocesamiento, analisis_periodo, comparacion_periodos, analisis_oracion |
| `descripcion` | `TEXT` | NO | | Descripción del cambio |
| `filas_afectadas` | `INTEGER` | SÍ | | Número de filas afectadas |
| `columnas_afectadas` | `TEXT` | SÍ | | Nombres de columnas afectadas (JSON) |
| `version_dataset` | `INTEGER` | SÍ | | Versión del dataset |
| `resumen_estadistico` | `TEXT` | SÍ | | Resumen estadístico (JSON libre) |
| `creado_por` | `TEXT` | SÍ | DEFAULT 'R-Plumber' | Origen del registro |

**Índices:** `idx_bitacora_fecha`, `idx_bitacora_tipo`

**Origen:** `server/db/schema.sql` (tabla existente)

---

### 8.2 `configuraciones`

Configuraciones guardadas desde el frontend (formularios de los 4 pasos).

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `nombre` | `TEXT` | NO | | Nombre dado por el usuario |
| `paso` | `INTEGER` | NO | | Paso: 1=preprocesar, 2=analizar-periodo, 3=comparar-periodos, 4=analizar-oracion |
| `parametros` | `TEXT` | NO | | Parámetros del formulario (JSON) |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |
| `actualizado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de última actualización |

**Índices:** `idx_configuraciones_paso`

**Origen:** `server/db/schema.sql` (tabla existente)

---

### 8.3 `graficos_info`

Información de archivos generados por cada paso del pipeline.

| Columna | Tipo | Nulo | Clave | Descripción |
|---------|------|------|-------|-------------|
| `id` | `SERIAL` | NO | PK | Identificador autoincremental |
| `paso` | `INTEGER` | NO | | Paso al que pertenece el archivo |
| `archivo` | `TEXT` | NO | | Nombre del archivo |
| `ruta` | `TEXT` | NO | | Ruta en memoria del archivo |
| `tipo` | `TEXT` | NO | | Tipo: png, csv, json, txt, etc. |
| `tamaño_bytes` | `INTEGER` | SÍ | | Tamaño en bytes |
| `creado_en` | `TIMESTAMP` | SÍ | DEFAULT CURRENT_TIMESTAMP | Fecha de creación |

**Índices:** `idx_graficos_info_paso`, `idx_graficos_info_tipo`

**Origen:** `server/db/schema.sql` (tabla existente)

---

## 9. VISTAS ÚTILES

### 9.1 `v_resumen_sentimientos`

Resumen de sentimientos por ejecución con nivel promedio y número de mensajes.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `ejecucion_id` | `INTEGER` | ID de la ejecución |
| `fecha` | `TIMESTAMP` | Fecha de la ejecución |
| `responsable` | `VARCHAR(200)` | Responsable |
| `sentimiento` | `VARCHAR(50)` | Nombre del sentimiento |
| `nivel_promedio` | `NUMERIC` | Nivel promedio de pct_* |
| `n_mensajes_con_sentimiento` | `BIGINT` | Número de mensajes con ese sentimiento |

---

### 9.2 `v_ejecucion_resumen`

Resumen de cada ejecución con conteos de cambios asociados.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | `INTEGER` | ID de la ejecución |
| `fecha` | `TIMESTAMP` | Fecha de ejecución |
| `responsable` | `VARCHAR(200)` | Responsable |
| `archivo` | `VARCHAR(200)` | Archivo de entrada |
| `estado` | `VARCHAR(20)` | Estado de la ejecución |
| `registros_leidos` | `INTEGER` | Registros leídos |
| `mensajes_limpios` | `INTEGER` | Mensajes limpios |
| `mensajes_excluidos` | `INTEGER` | Mensajes excluidos |
| `emojis_pendientes` | `INTEGER` | Emojis pendientes |
| `n_cambios` | `BIGINT` | Número de cambios asociados |

---

## 10. RELACIONES ENTRE TABLAS (Esquema ER)

```
chats 1───N mensajes_crudos
chats 1───N mensajes_limpios
mensajes_limpios 1───N sentimientos_por_mensaje
mensajes_limpios 1───N tokens
mensajes_limpios 1───N salida_emojis_en_uso (vía ejecuciones)
mensajes_limpios 1───N salida_stopwords_aplicadas (vía ejecuciones)
mensajes_limpios 1───N salida_mensajes_excluidos (vía ejecuciones)
ejecuciones 1───N ejecucion_pasos
ejecuciones 1───N salida_resumen
sentimientos 1───N sentimientos_palabras
sentimientos 1───N sentimientos_raices
topicos 1───N topicos_etiquetas
topicos 1───N topicos_terminos
topicos 1───N topicos_por_documento
```

### Claves foráneas principales

| Tabla Origen | Columna | Tabla Destino | Columna | Tipo de relación |
|--------------|---------|---------------|---------|------------------|
| `mensajes_crudos` | `chat_id` | `chats` | `id` | N:1 |
| `mensajes_limpios` | `chat_id` | `chats` | `id` | N:1 |
| `sentimientos_por_mensaje` | `(id_mensaje, chat_id)` | `mensajes_limpios` | `(id_mensaje, chat_id)` | N:1 |
| `tokens` | `(id_mensaje, chat_id)` | `mensajes_limpios` | `(id_mensaje, chat_id)` | N:1 |
| `sentimientos_palabras` | `sentimiento_id` | `sentimientos` | `id` | N:1 |
| `sentimientos_raices` | `sentimiento_id` | `sentimientos` | `id` | N:1 |
| `topicos_etiquetas` | `topico_id` | `topicos` | `id` | N:1 |
| `topicos_terminos` | `topico_id` | `topicos` | `id` | N:1 |
| `topicos_por_documento` | `topico_id` | `topicos` | `id` | N:1 |
| `ejecucion_pasos` | `ejecucion_id` | `ejecuciones` | `id` | N:1 |

---

## 11. EJEMPLOS DE CONSULTAS ÚTILES

```sql
-- 1. Sentimientos activos en el diccionario
SELECT nombre, polaridad, definicion
FROM sentimientos
WHERE activo = TRUE
ORDER BY orden;

-- 2. Nivel de sentimientos en un periodo específico
SELECT sentimiento, nivel_pct, mensajes_pct
FROM niveles_por_periodo
WHERE periodo = '2023-01-01_a_2023-03-31'
ORDER BY nivel_pct DESC;

-- 3. Evolución de un sentimiento en el tiempo
SELECT fecha, pct
FROM serie_sentimientos
WHERE periodo = '2023' AND sentimiento = 'alegria'
ORDER BY fecha;

-- 4. Top 10 términos más distintivos por TF-IDF en un periodo
SELECT doc, token, tf_idf
FROM tfidf_resultados
WHERE periodo = 'todo_2023'
ORDER BY tf_idf DESC
LIMIT 10;

-- 5. Últimas 10 ejecuciones del pipeline
SELECT id, fecha, responsable, estado, registros_leidos, mensajes_limpios, mensajes_excluidos
FROM ejecuciones
ORDER BY fecha DESC
LIMIT 10;

-- 6. Cambios sin justificar en la bitácora
SELECT id, archivo, cambio_realizado
FROM cambios
WHERE estado_registro = 'FALTA JUSTIFICAR';

-- 7. Mensajes con sentimiento dominante por género mencionado
SELECT genero_mencionado, sentimiento_dominante, COUNT(*) AS n
FROM mensajes_limpios
WHERE fecha BETWEEN '2023-01-01' AND '2023-03-31'
GROUP BY genero_mencionado, sentimiento_dominante
ORDER BY n DESC;

-- 8. Emojis más usados con su sentimiento
SELECT emoji, significado_es, sentimiento, en_texto + en_reacciones AS total_uso
FROM salida_emojis_en_uso
ORDER BY total_uso DESC
LIMIT 20;

-- 9. Comparación de sentimientos entre dos periodos
SELECT sentimiento, nivel_a, nivel_b, diferencia
FROM comparacion_niveles
WHERE periodo_a = 'todo_2023' AND periodo_b = 'todo_2024'
ORDER BY diferencia DESC;

-- 10. Palabras por sentimiento del diccionario
SELECT s.nombre AS sentimiento, sp.palabra
FROM sentimientos s
JOIN sentimientos_palabras sp ON sp.sentimiento_id = s.id
WHERE s.activo = TRUE
ORDER BY s.orden, sp.palabra;
```

---

## 12. NOTAS DE IMPLEMENTACIÓN

- **Motor recomendado:** PostgreSQL 14+ (compatible con pgAdmin para diseño ER visual)
- **Tipos de datos:** Usar `NUMERIC` para porcentajes y scores (precisión decimal exacta), `TEXT` para JSON libre, `TIMESTAMP` para fechas con hora
- **Índices:** Se crearon índices en columnas de fecha, autor, sentimiento y tipo para optimizar consultas de filtrado y agregación
- **Cascada:** Las claves foráneas de `sentimientos_palabras`, `sentimientos_raices`, `topicos_etiquetas`, `topicos_terminos` y `topicos_por_documento` usan `ON DELETE CASCADE`
- **Origen de datos:** Las tablas de configuración se cargan desde los archivos CSV y JSON en `r/config/`; las tablas de dataset se cargan desde `r/data/result.json` y los CSVs de salida en `salida/`
