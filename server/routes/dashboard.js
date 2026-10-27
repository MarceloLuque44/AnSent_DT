import { Router } from 'express';
import { config } from '../config.js';
import * as rService from '../services/rService.js';

const router = Router();

/** Estado general del pipeline R */
router.get('/status', async (_req, res) => {
  res.json({
    plumberOnline: (await rService.healthCheck()) !== null,
    plumberUrl: config.plumberUrl,
  });
});

/** Devuelve la definicion JSON de los graficos desde Plumber */
router.get('/charts', async (_req, res) => {
  const charts = await rService.getCharts();
  if (charts === null) {
    return res.status(503).json({
      error: 'R/Plumber no disponible',
      hint: `Inicia Plumber en otra terminal:  Rscript r/plumber_api.R  (${config.plumberUrl})`,
    });
  }
  res.json(charts);
});

/** Resumen del dataset */
router.get('/dataset', async (_req, res) => {
  const summary = await rService.getDatasetSummary();
  if (summary === null) {
    return res.status(503).json({ error: 'R/Plumber no disponible' });
  }
  res.json(summary);
});

/** Dispara el preprocesamiento en R (boton manual del dashboard) */
router.post('/preprocesar', async (req, res) => {
  const result = await rService.runPreprocesamiento(req.body ?? {});
  if (result === null) {
    return res.status(503).json({ error: 'R/Plumber no disponible' });
  }
  res.json(result);
});

export default router;
