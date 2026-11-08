# install.packages("plotly")
# install.packages("htmlwidgets")
# install.packages("chromote")
# install.packages("httr2")
library(plotly)
library(htmlwidgets)
library(chromote)
library(httr2)   # Librería moderna para hacer peticiones HTTP en R

# 1. Generar el gráfico y extraer el SVG en la variable (como hicimos antes)
mi_grafico <- plot_ly(
  x = c(1, 2, 3, 4), 
  y = c(10, 15, 13, 17), 
  type = 'scatter', 
  mode = 'lines+markers'
)

archivo_temp <- tempfile(fileext = ".html")
saveWidget(mi_grafico, file = archivo_temp, selfcontained = TRUE)

b <- ChromoteSession$new()
b$go_to(paste0("file:///", normalizePath(archivo_temp)))

script_js <- "
  new Promise((resolve, reject) => {
    let gd = document.querySelector('.plotly.html-widget') || document.querySelector('div[id^=\"htmlwidget-\"]');
    if (!gd) { reject('No se encontró el gráfico'); return; }
    Plotly.toImage(gd, {format: 'svg', width: 800, height: 600})
      .then(url => resolve(url))
      .catch(err => reject(err));
  })
"
svg_data_url <- b$Runtime$evaluate(script_js, awaitPromise = TRUE)$result$value
b$close()
unlink(archivo_temp)

# Limpiar el SVG y dejarlo en texto plano
svg_limpio <- sub(".*,", "", svg_data_url)
svg_variable <- URLdecode(svg_limpio)


# 2. ENVIAR EL SVG A TU API MEDIANTE UNA PETICIÓN HTTP (POST)
url_endpoint <- "http://localhost:3000/api/recibir-grafico" # Reemplaza con tu URL real

# Construir y ejecutar la petición con httr2
respuesta <- request(url_endpoint) %>%
  req_body_json(list(
    svg_data = svg_variable,
    origen = "RStudio"
  )) %>%
  req_method("POST") %>%
  req_perform()

# 3. Comprobar si la API recibió los datos correctamente
if (resp_status(respuesta) == 200) {
  message("¡El gráfico SVG se envió exitosamente a tu API!")
} else {
  warning("Fallo al enviar. Código de estado: ", resp_status(respuesta))
}