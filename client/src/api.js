/**
 * Cliente de la API de Express.
 *
 * VITE_API_URL permite apuntar a otro backend. Si está vacío se usan rutas
 * relativas (/api/...), que es lo recomendado cuando Express sirve el build
 * del frontend en Render.
 */
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/+$/, '');
const API_KEY = import.meta.env.VITE_API_KEY || '';

export const urlApi = (path) => {
  if (!API_BASE) return path;
  return `${API_BASE}${path.startsWith('/') ? path : `/${path}`}`;
};

const headersConClave = (extra = {}) => ({
  'Content-Type': 'application/json',
  ...(API_KEY ? { 'x-api-key': API_KEY } : {}),
  ...extra,
});

export async function apiGet(path) {
  const res = await fetch(urlApi(path));
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Error ${res.status}`);
  }
  return res.json();
}

export async function apiPost(path, body) {
  const res = await fetch(urlApi(path), {
    method: 'POST',
    headers: headersConClave(),
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || `Error ${res.status}`);
  }
  return res.json();
}

export async function apiPut(path, body) {
  const res = await fetch(urlApi(path), {
    method: 'PUT',
    headers: headersConClave(),
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || `Error ${res.status}`);
  }
  return res.json();
}

export async function apiDelete(path) {
  const res = await fetch(urlApi(path), {
    method: 'DELETE',
    headers: headersConClave(),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || `Error ${res.status}`);
  }
  return res.json();
}

/** Helpers específicos para diccionarios de configuracion (POSTGRES via /api/diccionarios/:tipo). */
export function listarDiccionario(tipo, { limit = 100, offset = 0 } = {}) {
  const qs = new URLSearchParams({ limit: String(limit), offset: String(offset) });
  return apiGet(`/api/diccionarios/${tipo}?${qs.toString()}`);
}

export function obtenerDiccionario(tipo, id) {
  return apiGet(`/api/diccionarios/${tipo}/${id}`);
}

export function guardarDiccionario(tipo, datos) {
  return apiPost(`/api/diccionarios/${tipo}`, datos);
}

export function actualizarDiccionario(tipo, id, datos) {
  return apiPut(`/api/diccionarios/${tipo}/${id}`, datos);
}

export function eliminarDiccionario(tipo, id) {
  return apiDelete(`/api/diccionarios/${tipo}/${id}`);
}

export async function listarTiposDiccionarios() {
  const res = await apiGet('/api/diccionarios');
  return res.tipos ?? [];
}
