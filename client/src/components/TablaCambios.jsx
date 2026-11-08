const texto = (v) => (v == null || v === '' ? '—' : String(v));

/** Tabla compartida por las vistas Cambios y Bitácora. */
export default function TablaCambios({ filas }) {
  return (
    <div className="tabla-scroll">
      <table className="tabla">
        <thead>
          <tr>
            <th>Fecha</th>
            <th>Hora</th>
            <th>Tipo</th>
            <th>Archivo</th>
            <th>Problema</th>
            <th>Cambio</th>
            <th>Justificación</th>
            <th>Responsable</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          {filas.map((c) => (
            <tr key={c.id}>
              <td>{texto(c.fecha)}</td>
              <td>{texto(c.hora)}</td>
              <td>
                <span className="tag">{texto(c.tipo)}</span>
              </td>
              <td>{texto(c.archivo)}</td>
              <td title={texto(c.problema_detectado)}>
                {texto(c.problema_detectado)}
              </td>
              <td title={texto(c.cambio_realizado)}>
                {texto(c.cambio_realizado)}
              </td>
              <td title={texto(c.justificacion)}>{texto(c.justificacion)}</td>
              <td>{texto(c.responsable)}</td>
              <td>
                <span className="tag">{texto(c.estado_registro)}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
