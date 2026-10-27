# Análisis de Sentimientos — Dashboard + Bitácora

Web app (React + Express + SQLite) que consume gráficos JSON y eventos de un
pipeline de R vía **Plumber**, con **SSE** para actualización automática.

## Arquitectura

```
R (preprocesamiento + gráficos JSON)  ──Plumber :8765──┐
        │  registra cambios (POST /api/bitacora)       │
        v                                              v
Express + SQLite + SSE  :3000  ────────────>  React (Vite) :5173
```

- **R (`r/`)**: preprocesamiento del dataset, gráficos como JSON (ECharts), y al
  terminar cada lote registra el cambio en la bitácora y publica un evento SSE.
- **Node/Express (`server/`)**: API REST, persistencia SQLite (bitácora), hub SSE.
- **React (`client/`)**: navegación hash `#/dashboard` | `#/bitacora`, gráficos
  con ECharts, refresco automático por SSE.

## Puesta en marcha

```bash
# 1) Backend
npm install
npm run dev          # Express en http://localhost:3000

# 2) Frontend
npm install && npm run dev --prefix client   # http://localhost:5173

# 3) R/Plumber (después instalar plumber, jsonlite, httr)
rscript r/plumber_api.R     # Plumber en http://localhost:8765
```

Con R corriendo, el dashboard muestra los gráficos y la bitácora se llena sola
cuando ejecutes el preprocesamiento (botón del dashboard o cualquier lote en R).
