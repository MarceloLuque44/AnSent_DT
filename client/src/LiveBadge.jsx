import { useSseStatus } from './sse.jsx';

/** Indicador de la conexión SSE en vivo, en la barra superior. */
export default function LiveBadge() {
  const estado = useSseStatus();
  return (
    <span className={`live ${estado}`}>
      {estado === 'conectado' ? '● En vivo' : '○ Reconectando...'}
    </span>
  );
}
