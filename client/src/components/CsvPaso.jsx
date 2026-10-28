/**
 * Lista los archivos CSV generados por un paso con enlace para descarga/visualizacion.
 */
export default function CsvPaso({ paso, csvs }) {
  return (
    <div className="tarjeta-csvs">
      {csvs.map((csv) => (
        <div key={csv.id} className="fila-csv">
          <span className="csv-nombre">{csv.archivo}</span>
          <span className="csv-ruta">{csv.ruta}</span>
          <a
            href={csv.ruta}
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-csv"
            download
          >
            Abrir / descargar
          </a>
        </div>
      ))}
    </div>
  );
}
