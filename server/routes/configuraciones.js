import { Router } from 'express';
import * as configService from '../services/configService.js';

const router = Router();

/** GET /api/configuraciones — listar todas */
router.get('/', (_req, res) => {
  res.json(configService.listarConfiguraciones());
});

/** GET /api/configuraciones/:id — obtener una */
router.get('/:id', (req, res) => {
  const c = configService.obtenerConfiguracion(parseInt(req.params.id, 10));
  if (!c) return res.status(404).json({ error: 'Configuracion no encontrada' });
  res.json(c);
});

/** POST /api/configuraciones — guardar una configuracion */
router.post('/', (req, res) => {
  const { nombre, paso, parametros } = req.body ?? {};
  if (!nombre || paso === undefined) {
    return res.status(400).json({ error: 'Se requieren nombre y paso' });
  }
  const c = configService.guardarConfiguracion({ nombre, paso: parseInt(paso, 10), parametros: parametros ?? {} });
  res.status(201).json(c);
});

/** DELETE /api/configuraciones/:id */
router.delete('/:id', (req, res) => {
  configService.eliminarConfiguracion(parseInt(req.params.id, 10));
  res.json({ ok: true });
});

export default router;
