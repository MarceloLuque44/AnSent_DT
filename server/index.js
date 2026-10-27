import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import dashboardRoutes from './routes/dashboard.js';
import bitacoraRoutes from './routes/bitacora.js';
import eventsRoutes from './routes/events.js';

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// API
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/bitacora', bitacoraRoutes);
app.use('/api/events', eventsRoutes);

app.get('/api/health', (_req, res) => res.json({ ok: true }));

app.listen(config.port, () => {
  console.log(`[Express] Servidor en http://localhost:${config.port}`);
  console.log(`[Express] Plumber configurado en ${config.plumberUrl}`);
  console.log(`[Express] Para iniciar Plumber:  Rscript r/plumber_api.R`);
});
