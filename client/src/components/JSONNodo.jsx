/**
 * Nodo del arbol JSON: muestra "clave: valor" recursivamente.
 * Reutilizado por las pantallas Salida y Bitacoras.
 */
export default function JSONNodo({ clave, valor, nivel = 0 }) {
  if (valor && typeof valor === 'object' && (Array.isArray(valor) || Object.keys(valor).length > 0)) {
    const esArr = Array.isArray(valor);
    const entradas = esArr ? valor.map((v, i) => [String(i), v]) : Object.entries(valor);
    return (
      <div className={nivel > 0 ? 'json-nodo-bloque' : 'json-nodo-raiz'}>
        {clave && (
          <p className="json-nodo-clave">
            {clave}
            <em className="json-nodo-clase">
              {' '}
              ({esArr ? `${entradas.length} elemento(s)` : `${entradas.length} clave(s)`})
            </em>
          </p>
        )}
        <div className="json-nodo-hijos">
          {entradas.map(([k, v]) => (
            <JSONNodo key={k} clave={k} valor={v} nivel={nivel + 1} />
          ))}
        </div>
      </div>
    );
  }
  const txt = valor == null ? '—' : typeof valor === 'number' ? valor.toLocaleString('es-ES') : String(valor);
  return (
    <div className="json-nodo-fila">
      <span className="json-nodo-clave-min">{clave}</span>
      <span className="json-nodo-valor">{txt}</span>
    </div>
  );
}
