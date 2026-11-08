import app from './app.js';
import { config } from './config.js';

const server = app.listen(config.port, () => {
  console.log(`[Express] Servidor en http://localhost:${config.port}`);
  console.log(`[Express] Fase 1: Render + Postgres + /api/cambios`);
});

// Los pasos 2 y 3 (LDA + udpipe + syuzhet + gráficos) pueden superar el
// requestTimeout por defecto de Node (5 min) y cortar la conexión.
server.requestTimeout = 900000;
