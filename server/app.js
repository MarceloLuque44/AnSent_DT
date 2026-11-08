import express from 'express';
import cors from 'cors';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from './config.js';
import cambiosRoutes from './routes/cambios.js';
import analisisRoutes from './routes/analisis.js';
import { query } from './db/pg.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
app.set('trust proxy', 1);
app.use(express.json({ limit: '4mb' }));
app.use(
  cors({
    origin: config.corsOrigins.length ? config.corsOrigins : false,
  })
);

app.get('/api/health', async (_req, res) => {
  try {
    await query('SELECT 1');
    res.json({ ok: true, db: true, fase: 1 });
  } catch (err) {
    res.status(503).json({ ok: false, db: false, error: err.message });
  }
});

app.use('/api/cambios', cambiosRoutes);
app.use('/api/dashboard', analisisRoutes);

app.use('/api', (_req, res) => {
  res.status(404).json({ error: 'Endpoint no encontrado' });
});

const clientDist = path.join(__dirname, '..', 'client', 'dist');
const indexHtml = path.join(clientDist, 'index.html');

if (fs.existsSync(indexHtml)) {
  app.use(express.static(clientDist));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api/')) return next();
    res.sendFile(indexHtml);
  });
}

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('[API]', err);
  res.status(err.status || 500).json({ error: err.message || 'Error interno' });
});

export default app;
