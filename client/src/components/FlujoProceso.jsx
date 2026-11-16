/** Diagrama de flujo del preprocesamiento (contenido estático para exposición). */

const ETAPAS = [
  {
    n: '1',
    titulo: 'Auditoría inicial',
    etiqueta: 'Diagnóstico',
    tono: 'info',
    puntos: [
      { texto: 'Registros de servicio', valor: '3,466' },
      { texto: 'Enlaces', valor: '1,782' },
      { texto: 'Autor vacío', valor: '1,754' },
      { texto: 'Reenviados', valor: '601' },
    ],
  },
  {
    n: '2',
    titulo: 'Estructura y formatos',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    puntos: [
      { texto: 'Eliminación de los registros de servicio', valor: '3,466' },
      { texto: 'Autores anonimizados', valor: '✓' },
    ],
    salida: '22,564 mensajes',
    perdidos: '−3,466',
  },
  {
    n: '3',
    titulo: 'Duplicados',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    puntos: [
      { texto: 'Eliminación de mensajes largos', valor: '463' },
      { texto: 'Se conservan mensajes cortos repetidos', valor: '1,797' },
    ],
    salida: '22,101 mensajes',
    perdidos: '−463',
  },
  {
    n: '4',
    titulo: 'Valores faltantes',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    puntos: [{ texto: 'Eliminación de mensajes multimedia', valor: '1,356' }],
    salida: '20,745 mensajes',
    perdidos: '−1,356',
  },
  {
    n: '5',
    titulo: 'Outliers',
    etiqueta: 'Análisis',
    tono: 'info',
    puntos: [
      { texto: 'Mensajes muy largos (más de 549 caracteres)', valor: '248' },
    ],
  },
  {
    n: '6',
    titulo: 'Publicidad',
    etiqueta: 'Exclusión',
    tono: 'excluye',
    puntos: [
      {
        texto:
          'Cada mensaje recibe un puntaje: enlace, reenviado, muy largo, teléfono y frases de inscripción',
      },
      { texto: 'Eliminación de anuncios', valor: '615' },
    ],
    salida: '20,130 mensajes',
    perdidos: '−615',
  },
  {
    n: '7',
    titulo: 'Emojis y emoticonos',
    etiqueta: 'Análisis',
    tono: 'info',
    puntos: [
      { texto: 'Emojis distintos identificados', valor: '233' },
      {
        texto: 'Mensajes con reacciones contadas como positivas o negativas',
        valor: '1,922',
      },
    ],
  },
]

const PASOS_LIMPIEZA = [
  { paso: 'Enlaces, correos, menciones, teléfonos', hace: 'Se eliminan', mensajes: '734' },
  { paso: '“compañer@s” → “compañeros”', hace: 'Se completa la palabra', mensajes: '94' },
  { paso: 'Minúsculas', hace: '“Gracias” = “GRACIAS”', mensajes: '17,301' },
  { paso: 'Horas y fechas', hace: 'Se eliminan', mensajes: '422' },
  { paso: 'Códigos de materia', hace: '“inf 111” → inf_111', mensajes: '1,012' },
  { paso: 'Hashtags', hace: 'Se quita el #', mensajes: '6' },
  { paso: 'Puntuación y símbolos', hace: 'Se quitan', mensajes: '10,273' },
  { paso: 'Letras alargadas', hace: '“holaaaa” → “hola”', mensajes: '256' },
  { paso: 'Abreviaturas', hace: '“q” → “que”', mensajes: '1,047' },
  { paso: 'Espacios sobrantes', hace: 'Se unifican', mensajes: '11,958' },
  { paso: 'Mensajes vacíos', hace: 'Se apartan', mensajes: '634' },
];

const ETAPAS_FINALES = [
  {
    n: '9',
    titulo: 'Género',
    etiqueta: 'Análisis',
    tono: 'info',
    puntos: [
      { texto: 'Se marca a quién se refiere el mensaje', valor: null },
      { texto: 'Mensajes que mencionan a alguien', valor: '947' },
    ],
  },
  {
    n: '10',
    titulo: 'Tokenización y stopwords',
    etiqueta: 'Transformación',
    tono: 'limpia',
    puntos: [
      { texto: 'Se eliminan las stopwords', valor: '17,119 mensajes' },
      { texto: 'Al final se quitan las tildes', valor: '5,808 mensajes' },
    ],
  },
];

const ETAPA_8 = {
  n: '8',
  titulo: 'Limpieza del texto',
  etiqueta: '11 pasos',
  tono: 'limpia',
};

const TONO_COLOR = {
  info: 'var(--azul-oscuro)',
  excluye: 'var(--rojo)',
  limpia: 'var(--menta)',
  final: 'var(--azul)',
};

function Tarjeta({ etapa, children }) {
  return (
    <li className="flujo-item">
      <div className={`flujo-nodo flujo-nodo--${etapa.tono || 'info'}`}>{etapa.n}</div>
      <div className="flujo-tarjeta">
        <div className="flujo-cabecera">
          <h3 className="flujo-titulo">
            <span className="flujo-etapa">Etapa {etapa.n}</span>
            {etapa.titulo}
          </h3>
          {etapa.etiqueta && (
            <span className="flujo-badge" style={{ color: TONO_COLOR[etapa.tono || 'info'] }}>
              {etapa.etiqueta}
            </span>
          )}
        </div>
        {children}
        {(etapa.salida || etapa.perdidos) && (
          <div className="flujo-salida">
            {etapa.perdidos && <span className="flujo-perdida">{etapa.perdidos}</span>}
            {etapa.salida && (
              <span className="flujo-salida-texto">
                Quedan <strong>{etapa.salida}</strong>
              </span>
            )}
          </div>
        )}
      </div>
    </li>
  );
}

function Puntos({ puntos }) {
  return (
    <ul className="flujo-puntos">
      {puntos.map((p) => (
        <li key={p.texto}>
          <span>{p.texto}</span>
          {p.valor != null && <span className="flujo-valor">{p.valor}</span>}
        </li>
      ))}
    </ul>
  );
}

export default function FlujoProceso() {
  return (
    <div className="flujo">
      <div className="flujo-hero">
        <div>
          <p className="flujo-hero-etiqueta">Registros analizados</p>
          <p className="flujo-hero-numero">26,030</p>
          <p className="flujo-hero-rango">26/12/2022 al 20/10/2026</p>
        </div>
        <div className="flujo-hero-resumen">
          <div>
            <span className="flujo-hero-dato">19,496</span>
            <span className="flujo-hero-pie">mensajes limpios</span>
          </div>
          <span className="flujo-hero-mas">+</span>
          <div>
            <span className="flujo-hero-dato">6,534</span>
            <span className="flujo-hero-pie">excluidos</span>
          </div>
        </div>
      </div>

      <ol className="flujo-lista">
        {ETAPAS.map((etapa) => (
          <Tarjeta key={etapa.n} etapa={etapa}>
            <Puntos puntos={etapa.puntos} />
          </Tarjeta>
        ))}

        <Tarjeta etapa={ETAPA_8}>
          <div className="tabla-scroll flujo-tabla-scroll">
            <table className="tabla flujo-tabla">
              <thead>
                <tr>
                  <th>Paso</th>
                  <th>Qué hace</th>
                  <th>Mensajes</th>
                </tr>
              </thead>
              <tbody>
                {PASOS_LIMPIEZA.map((p) => (
                  <tr key={p.paso}>
                    <td>{p.paso}</td>
                    <td>{p.hace}</td>
                    <td className="flujo-tabla-num">{p.mensajes}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flujo-salida">
            <span className="flujo-salida-texto">
              Quedan <strong>19,496 mensajes</strong>
            </span>
          </div>
        </Tarjeta>

        {ETAPAS_FINALES.map((etapa) => (
          <Tarjeta key={etapa.n} etapa={etapa}>
            <Puntos puntos={etapa.puntos} />
          </Tarjeta>
        ))}

        <Tarjeta
          etapa={{
            n: '11',
            titulo: 'Sentimientos',
            etiqueta: 'Análisis',
            tono: 'info',
          }}
        >
          <Puntos
            puntos={[
              { texto: 'Mensajes con algún sentimiento', valor: '4,729 (24.3%)' },
            ]}
          />
          <div className="flujo-barra" aria-hidden="true">
            <span className="flujo-barra-pos" style={{ width: '11.18%' }} />
            <span className="flujo-barra-neg" style={{ width: '6.07%' }} />
            <span className="flujo-barra-neu" style={{ width: '82.75%' }} />
          </div>
          <div className="flujo-leyenda">
            <span>
              <i className="flujo-punto flujo-punto--pos" />
              Positivos <strong>2,179</strong>
            </span>
            <span>
              <i className="flujo-punto flujo-punto--neg" />
              Negativos <strong>1,184</strong>
            </span>
            <span>
              <i className="flujo-punto flujo-punto--neu" />
              Neutrales <strong>16,133</strong>
            </span>
          </div>
          <p className="flujo-nota">
            Neutral incluye los mensajes que no coinciden con ninguna palabra.
          </p>
        </Tarjeta>

        <Tarjeta
          etapa={{
            n: '12',
            titulo: 'Faltantes finales',
            etiqueta: 'Verificación',
            tono: 'final',
          }}
        >
          <p className="flujo-nota">Revisión de valores faltantes al cierre del proceso.</p>
        </Tarjeta>

        <Tarjeta
          etapa={{
            n: '13',
            titulo: 'Validaciones',
            etiqueta: 'Balance',
            tono: 'final',
          }}
        >
          <div className="flujo-balance">
            <span className="flujo-balance-total">26,030</span>
            <span className="flujo-balance-signo">=</span>
            <span className="flujo-balance-parte">
              19,496 <small>limpios</small>
            </span>
            <span className="flujo-balance-signo">+</span>
            <span className="flujo-balance-parte">
              6,534 <small>excluidos</small>
            </span>
          </div>
        </Tarjeta>
      </ol>
    </div>
  );
}
