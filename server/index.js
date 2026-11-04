import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from './config.js';
import dashboardRoutes from './routes/dashboard.js';
import bitacoraRoutes from './routes/bitacora.js';
import eventosRoutes from './routes/events.js';
import configuracionesRoutes from './routes/configuraciones.js';
import pasosRoutes from './routes/pasos.js';
import sentimientosRoutes from './routes/sentimientos.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Servir archivos estaticos de r/salida (imagenes PNG generadas por R/Plumber)
app.use('/salida', express.static(path.join(__dirname, '..', 'r', 'salida')));

// Servir las imagenes del dashboard que viven en client/src/views/salida
app.use(
  '/salida-cliente',
  express.static(path.join(__dirname, '..', 'client', 'src', 'views', 'salida'))
);

// API
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/bitacora', bitacoraRoutes);
app.use('/api/events', eventosRoutes);
app.use('/api/configuraciones', configuracionesRoutes);
app.use('/api/pasos', pasosRoutes);
app.use('/api/sentimientos', sentimientosRoutes);

app.get('/api/health', (_req, res) => res.json({ ok: true }));

const server = app.listen(config.port, () => {
  console.log(`[Express] Servidor en http://localhost:${config.port}`);
  console.log(`[Express] Plumber configurado en ${config.plumberUrl}`);
  console.log(`[Express] Para iniciar Plumber:  Rscript r/plumber_api.R`);
});

// Los pasos 2 y 3 (LDA + udpipe + syuzhet + gráficos) pueden superar el
// requestTimeout por defecto de Node (5 min) y cortar la conexión.
server.requestTimeout = 900000;
