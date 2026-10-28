/**
 * Renderiza una imagen PNG generada por un paso, usando la ruta en memoria
 * devuelta por la API de Express/Plumber.
 */
import React, { useEffect, useState } from 'react';

export default function ImagenPaso({ img }) {
  const [cargada, setCargada] = useState(false);
  const [error, setError] = useState(false);

  const ruta = img.ruta || img.archivo;

  return (
    <div className="tarjeta-imagen">
      <div className="imagen-contenedor">
        <img
          src={ruta}
          alt={img.archivo}
          onLoad={() => setCargada(true)}
          onError={() => setError(true)}
          className="imagen-paso"
        />
        {error && (
          <div className="imagen-error">
            No se pudo cargar la imagen: {img.archivo}<br />
            <small>Ruta: {ruta}</small>
          </div>
        )}
        {!error && !cargada && <div className="imagen-cargando">Cargando…</div>}
      </div>
      <p className="imagen-titulo">{img.archivo}</p>
      {img.tipo && <span className="imagen-tipo">{img.tipo.toUpperCase()}</span>}
    </div>
  );
}
