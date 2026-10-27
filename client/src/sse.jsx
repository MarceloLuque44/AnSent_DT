/**
 * Conexión SSE compartida (ui single EventSource).
 * - useSse(evento, handler): suscribirse a un evento concreto
 * - useSseStatus(): estado de conexion ('conectado' | 'reconectando' | 'sin-r')
 */
import { useEffect, useState } from 'react';

let source;
const listeners = new Set();

function conectar() {
  if (source) return source;
  source = new EventSource('/api/events');

  source.addEventListener('connected', () => {
    listeners.forEach((l) => l('conectado'));
  });
  // Cualquier otro evento establecido se notifica como 'conectado'
  source.onmessage = () => {};

  source.onerror = () => {
    listeners.forEach((l) => l('reconectando'));
  };
  return source;
}

function escuchar(evento, handler) {
  const src = conectar();
  src.addEventListener(evento, (e) => {
    let data;
    try {
      data = JSON.parse(e.data);
    } catch {
      data = null;
    }
    handler(data);
    listeners.forEach((l) => l('conectado'));
  });
  return () => src.removeEventListener(evento, handler);
}

function escucharStatus(handler) {
  const src = conectar();
  listeners.add(handler);
  return () => listeners.delete(handler);
}

export function useSse(evento, handler) {
  useEffect(() => escuchar(evento, handler), [evento, handler]);
}

export function useSseStatus() {
  const [estado, setEstado] = useState('reconectando');
  useEffect(() => {
    const cleanup = escucharStatus(setEstado);
    return cleanup;
  }, []);
  return estado;
}
