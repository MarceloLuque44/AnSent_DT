# 00_main.R — `preprocesar()`: explicación de funcionamiento

## Resumen

`r/R/00_main.R` define la función `preprocesar()`, que es el punto de entrada único para ejecutar todo el preprocesamiento del proyecto de análisis de sentimientos (AnSent). Lee un archivo de entrada (por defecto `data/result.json`), aplica una secuencia de 13 etapas de limpieza y normalización, exporta los resultados a `salida/` y registra todo en las dos bitácoras de `bitacoras/`.

---

## Firma de la función

```r
preprocesar <- function(ruta_archivo,
                        fecha_inicio = NULL, fecha_fin = NULL,
                        responsable = Sys.getenv("RESPONSABLE", ""),
                        dir_config = "config", dir_salida = "salida",
                        dir_bitacoras = "bitacoras",
                        sentimientos_activos = NULL,
                        excluir_publicidad = TRUE, umbral_publicidad = 4,
                        anonimizar_autor = TRUE, min_chars_duplicado = 25,
                        nuevos_emojis = c("marcar", "detener"),
                        consola = c("didactico", "resumen", "silencioso"),
                        csv_para_excel = TRUE,
                        preguntar_cambios = interactive(), motivo_cambios = NULL,
                        chat = NULL)
```

### Parámetros principales

| Parámetro | Por defecto | Descripción |
|-----------|-------------|-------------|
| `ruta_archivo` | — | Archivo de entrada (ej. `data/result.json`) |
| `fecha_inicio` / `fecha_fin` | `NULL` | Rango de fechas para filtrar mensajes |
| `responsable` | `RESPONSABLE` env var | Nombre que se registra en la bitácora |
| `dir_config` | `"config"` | Carpeta con diccionarios y configuración |
| `dir_salida` | `"salida"` | Carpeta donde se exportan los resultados |
| `dir_bitacoras` | `"bitacoras"` | Carpeta de las dos bitácoras |
| `sentimientos_activos` | `NULL` | Sentimientos a usar (`NULL` = todos los activos del json) |
| `excluir_publicidad` | `TRUE` | Si se detectan y excluyen anuncios/publicidad |
| `umbral_publicidad` | `4` | Umbral para la detección de publicidad |
| `anonimizar_autor` | `TRUE` | Si se anonimiza el autor de los mensajes |
| `min_chars_duplicado` | `25` | Mínimo de caracteres para considerar duplicado |
| `nuevos_emojis` | `c("marcar","detener")` | Qué hacer con emojis no reconocidos |
| `consola` | `"silencioso"` | `"didactico"`, `"resumen"` o `"silencioso"` |
| `csv_para_excel` | `TRUE` | Agrega BOM para que Excel lea bien tildes/emojis |
| `preguntar_cambios` | `interactive()` | Si se pregunta al usuario sobre cambios detectados |
| `motivo_cambios` | `NULL` | Justificación común aplicada a todos los cambios |
| `chat` | `NULL` | Datos de chat alternativos (para `leer_entrada`) |

---

## Flujo de ejecución

1. **Validación de parámetros**: `nuevos_emojis` y `consola` se resuelven con `match.arg()`.
2. **Creación de carpetas**: `dir.create(dir_salida, recursive = TRUE)`.
3. **Control de cambios**: se llama a `vigilar_cambios()` para detectar cambios en código/diccionarios respecto a la última ejecución.
4. **Ejecución del cuerpo** (`cuerpo()`): recorre 13 etapas de transformación.
5. **Anotación en bitácora completa**: siempre se escribe (ok, error o detenido).
6. **Retorno**: lista con `estado`, `datos`, `excluidos`, `tokens`, `bitacora`, `emojis_pendientes` y `resumen`.

---

## Las 13 etapas del cuerpo (`cuerpo()`)

Cada etapa se anuncia mediante `etapa(titulo)`, que imprime un encabezado según el modo de consola:

| Etapa | Acción |
|-------|--------|
| Cargando diccionarios (config/) | `cargar_config(dir_config, sentimientos_activos)` |
| Leer `<archivo>` | `leer_entrada(ruta_archivo, chat)` |
| ETAPA 1. Auditoría y perfilado inicial | `auditar_entrada(ctx, d)` |
| ETAPA 2. Normalización de estructura y formatos | `estructurar(ctx, d)` |
| ETAPAS 3-5. Duplicados, valores faltantes y outliers | `control_calidad(ctx, d)` |
| ETAPA 6. Publicidad y anuncios | `detectar_publicidad(ctx, d)` |
| ETAPA 7. Emojis | `procesar_emojis(ctx, d)` |
| ETAPA 8. Limpieza y normalización de texto | `normalizar_texto(ctx, d)` |
| ETAPA 9. Referencias de género | `marcar_genero(ctx, d)` |
| ETAPA 10. Tokenización, stopwords y tildes | `tokenizar_y_filtrar(ctx, d)` |
| ETAPA 11. Sentimientos con diccionario propio | `calcular_sentimientos(ctx, d)` |
| ETAPA 12. Valores faltantes del dataset final | `rellenar_nulos(ctx, d)` |
| ETAPA 13. Validación de consistencia y exportación | `validar_consistencia(ctx, d)` |

Al final se exportan salidas (`exportar_salidas`) y la bitácora limpia (`exportar_bitacora`), y se escribe `resumen.json` en `dir_salida`.

---

## Detección automática de cambios (`vigilar_cambios`)

Esta es la parte que el usuario consulta específicamente. `vigilar_cambios()` se encuentra en `r/R/bitacora.R` y se invoca al inicio de `preprocesar()`:

```r
try(vigilar_cambios(dir_bitacoras, dir_config, responsable, preguntar_cambios, motivo_cambios), silent = FALSE)
```

### ¿Qué archivos vigila?

La función `.archivos_vigilados(dir_config)` recopila:

1. Todos los archivos `R/*.R` (código del proyecto)
2. `cargar_proyecto.R` y `ejecutar.R` en la raíz (si existen)
3. Todos los archivos `.csv` y `.json` dentro de `dir_config` (diccionarios)

### ¿Cómo detecta un cambio?

Compara el contenido actual de cada archivo vigilado contra una "foto" guardada previamente en `bitacoras/_copia_de_control.json`:

- **Primera ejecución**: no existe el archivo de control. Se toma la versión actual de todos los archivos como punto de partida y se guarda la foto. No se pregunta nada.
- **Ejecuciones posteriores**: se lee la foto previa y se compara línea a línea con el contenido actual de cada archivo:
  - `nuevos`: archivos que ahora existen pero no estaban en la foto
  - `borrados`: archivos que estaban en la foto pero ya no existen
  - `modificados`: archivos comunes cuyo contenido difiere (usando `identical()` sobre el vector de líneas)

Si no hay cambios, solo avisa si hay cambios sin justificar pendientes y retorna.

### ¿Cómo pregunta al usuario (por lotes)?

Cuando `preguntar = TRUE` (modo interactivo, ej. R/RStudio) y se detectan cambios, para cada archivo cambiado:

1. Imprime un separador y describe el cambio:
   - Para `.R`: cuántas líneas se agregaron/quitaron, la primera línea modificada, la sección de código más cercana y un ejemplo de la nueva línea.
   - Para `sentimientos.json`: qué sentimientos se agregaron/eliminaron y qué campos cambiaron (palabras, raíces, activo, polaridad, definición, orden).
   - Para `.csv`: cambios en el encabezado, columnas agregadas/quitadas/modificadas.
2. Hace tres preguntas por archivo:
   - "¿Qué problema notaste o qué querías lograr?"
   - "¿Cómo lo detectaste? (Enter para omitir)"
   - "¿Por qué este cambio lo resuelve? (justificación)"
3. **Pregunta por lote**: después de responder para un archivo, si quedan más archivos por procesar, pregunta:

   > ¿Usar estas mismas respuestas para los N archivo(s) restantes? (s/n)

   Si el usuario responde `s`/`si`/`sí`, las mismas respuestas se aplican a todos los archivos restantes sin volver a preguntar individualmente.

4. Cada respuesta se guarda como una fila en la hoja **"Cambios"** de `bitacora_completa.xlsx` con campos: `id_cambio`, `fecha`, `hora`, `tipo`, `archivo`, `seccion`, `problema_detectado`, `como_se_detecto`, `cambio_realizado`, `justificacion`, `resultado`, `ejecucion_prueba`, `responsable`, `estado_registro`.

### Modo no interactivo (`Rscript`)

Cuando `preguntar = FALSE` (ej. ejecutando con `Rscript` desde la API de Plumber):

- No se hace ninguna pregunta al usuario.
- Si se proporcionó `motivo_cambios`, ese texto se usa como justificación (`porque`) para todos los cambios detectados.
- Si no hay `motivo_cambios`, los cambios se registran con justificación vacía (se pueden completar después en el Excel).

### Actualización de la foto

La foto de control (`_copia_de_control.json`) solo se actualiza si el registro de cambios se guardó exitosamente en `bitacora_completa.xlsx`. Así, si falla el guardado, en la próxima ejecución se vuelven a detectar los mismos cambios.

---

## Las dos bitácoras

1. **`bitacora_limpia.xlsx`**: pasos de la última ejecución exitosa. Se sobrescribe en cada ejecución exitosa.
2. **`bitacora_completa.xlsx`**: cambios, ejecuciones, pasos y experimentos. Solo se agrega (nunca se sobrescribe). Contiene las hojas:
   - **Cambios**: cada cambio detectado por `vigilar_cambios` o anotado con `anotar_cambio()`.
   - **Ejecuciones**: una fila por intento de `preprocesar()` (ok, error o detenido).
   - **Pasos por ejecución**: una fila por etapa ejecutada en cada intento.
   - **Experimentos**: análisis posteriores (TF-IDF, shallow, LDA, etc.) vinculados a una ejecución de preprocesamiento.

---

## Modos de consola

- `"didactico"`: imprime un encabezado detallado por etapa con separadores, y un resumen final con conteos.
- `"resumen"`: imprime una línea por etapa con el número de filas afectadas.
- `"silencioso"`: no imprime nada (usado por la API de Plumber).

---

## Salida del `resumen.json`

Se escribe en `dir_salida/resumen.json` con:

- `estado`, `archivo`, `responsable`
- `registros_leidos`, `mensajes_limpios`, `mensajes_excluidos`
- `excluidos_por_motivo` (conteo por motivo de exclusión)
- `rango_fechas` (mínimo y máximo)
- `sentimientos_activos`
- `polaridad` (conteo por polaridad)
- `emojis_pendientes`
- `pasos_bitacora`

---

## Integración con Plumber

En `r/plumber_api.R`, el endpoint `POST /paso/preprocesar` recibe los parámetros de `preprocesar()` en el cuerpo de la petición, los pasa a la función y devuelve, además del resultado habitual, un campo `parametros_usados` con todos los parámetros que se aplicaron, para que el frontend pueda mostrarlos al usuario.
