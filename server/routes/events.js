import { Router } from 'express';
import { handler, publish, clientCount } from '../services/sseHub.js';

const router = Router();

/** GET /api/events — endpoint de suscripcion SSE */
router.get('/', handler);

/** POST /api/events/publish — para que R (Plumber) emita eventos generales */
router.post('/publish', (req, res) => {
  const { event = 'dataset:update', data = {} } = req.body ?? {};
  publish(event, data);
  res.json({ ok: true, clientes: clientCount() });
});

export default router;
