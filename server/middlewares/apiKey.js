import crypto from 'node:crypto';
import { config } from '../config.js';

/**
 * Protege los endpoints que escribe R con la cabecera `x-api-key`.
 * Compara en tiempo constante para no filtrar la clave por temporización.
 */
export function requireApiKey(req, res, next) {
  if (!config.apiKey) {
    return res.status(503).json({ error: 'R_API_KEY no configurada en el servidor' });
  }
  const enviada = req.get('x-api-key') || '';
  const esperada = config.apiKey;
  const a = Buffer.from(enviada);
  const b = Buffer.from(esperada);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return res.status(401).json({ error: 'API key inválida' });
  }
  next();
}
