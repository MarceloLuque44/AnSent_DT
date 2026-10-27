/**
 * Hub de Server-Sent Events (SSE).
 * Los clientes se suscriben en GET /api/events y cualquier parte
 * (rutas de R, la bitacora, etc.) publica eventos con publish().
 */
const clients = new Set();

export function handler(req, res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.write(`event: connected\ndata: {"ok":true}\n\n`);
  clients.add(res);

  req.on('close', () => clients.delete(res));
}

/** Alps a todos los clientes: { event: string, data: object } */
export function publish(event, data = {}) {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  console.log(`[SSE] ${event} -> ${clients.size} cliente(s)`);
  for (const res of clients) {
    res.write(payload);
  }
}

export function clientCount() {
  return clients.size;
}
