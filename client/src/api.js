/**
 * Cliente de la API de Express.
 *
 * VITE_API_URL permite apuntar a otro backend. Si está vacío se usan rutas
 * relativas (/api/...), que es lo recomendado cuando Express sirve el build
 * del frontend en Render.
 */
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/+$/, '');

const urlApi = (path) => {
  if (!API_BASE) return path;
  return `${API_BASE}${path.startsWith('/') ? path : `/${path}`}`;
};

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
    headers: { 'Content-Type': 'application/json' },
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
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || `Error ${res.status}`);
  }
  return res.json();
}
