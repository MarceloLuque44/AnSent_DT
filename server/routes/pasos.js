import { Router } from 'express';
import * as configService from '../services/configService.js';

const router = Router();

/** POST /api/pasos/:paso — ejecutar un paso en Plumber */
router.post('/:paso', async (req, res) => {
  const paso = parseInt(req.params.paso, 10);
  const body = req.body ?? {};

  try {
    const resultado = await configService.ejecutarPaso(paso, body);
    res.json(resultado);
  } catch (err) {
    res.status(503).json({
      ok: false,
      paso,
      error: err.message,
      mensaje: err.message,
    });
  }
});

/** GET /api/pasos/:paso/archivos — listar archivos generados de un paso */
router.get('/:paso/archivos', (_req, res) => {
  const paso = parseInt(_req.params.paso, 10);
  res.json(configService.listarArchivosGenerados(paso));
});

/** GET /api/pasos/:paso/imagenes — obtener imagenes (PNG) de un paso para renderizar */
router.get('/:paso/imagenes', (_req, res) => {
  const paso = parseInt(_req.params.paso, 10);
  res.json(configService.obtenerImagenesPaso(paso));
});

/** GET /api/pasos/:paso/csvs — obtener CSVs de un paso */
router.get('/:paso/csvs', (_req, res) => {
  const paso = parseInt(_req.params.paso, 10);
  res.json(configService.obtenerCsvsPaso(paso));
});

export default router;
