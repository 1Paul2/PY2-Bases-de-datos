import '../styles/Factura.css';

const EMPRESA = 'Wide World Importers';

const numero = n =>
  n === null || n === undefined || n === ''
    ? 'Vacío'
    : Number(n).toLocaleString('es-CR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const fecha = valor => {
  if (!valor) return 'Vacío';
  const [anio, mes, dia] = String(valor).slice(0, 10).split('-');
  return `${dia}/${mes}/${anio}`;
};

// Si se pasa onClick se muestra como enlace; si no, como texto normal
function Enlace({ onClick, children }) {
  if (!onClick) return children;
  return (
    <button type="button" className="factura-enlace" onClick={onClick}>
      {children}
    </button>
  );
}

function Ola({ posicion }) {
  return (
    <svg
      className={`factura-ola factura-ola-${posicion}`}
      viewBox="0 0 900 140"
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      <path className="factura-ola-frente" d="M0 0H900V72C760 124 640 22 470 56C300 92 150 42 0 98Z" />
      <path className="factura-ola-fondo" d="M0 0H900V42C740 88 620 6 450 32C280 58 140 22 0 64Z" />
    </svg>
  );
}

export default function Factura({ encabezado, lineas = [], onVerCliente, onVerProducto }) {
  const h = encabezado;
  // Los totales los calcula el SP (Subtotal, TotalTax, TotalAmount); aquí solo se muestran
  const subtotal = h.Subtotal ?? h.SubTotal;
  const impuestos = h.TotalTax ?? h.TotalImpuesto;
  const total = h.TotalAmount ?? h.TotalFactura;
  const hayTotales = total !== null && total !== undefined;

  return (
    <article className="factura">
      <Ola posicion="sup" />
      <div className="factura-marca">{EMPRESA}</div>

      <div className="factura-cuerpo">
        <div className="factura-partes">
          <section>
            <h3>Datos del cliente</h3>
            <p>
              Nombre:{' '}
              <Enlace onClick={onVerCliente && (() => onVerCliente(h))}>{h.CustomerName ?? 'Vacío'}</Enlace>
            </p>
            <p>Contacto: {h.ContactPerson ?? 'Vacío'}</p>
            <p>Orden de compra: {h.CustomerPurchaseOrderNumber || 'Vacío'}</p>
          </section>

          <section className="factura-der">
            <h3>Datos de la empresa</h3>
            <p>Nombre: {EMPRESA}</p>
            <p>Vendedor: {h.Salesperson ?? 'Vacío'}</p>
          </section>
        </div>

        <div className="factura-identif">
          <strong>Factura N.º {h.InvoiceID}</strong>
          <strong>Fecha: {fecha(h.InvoiceDate)}</strong>
        </div>

        <div className="factura-scroll">
          <table className="factura-tabla">
            <thead>
              <tr>
                <th className="izq">Producto</th>
                <th>Cantidad</th>
                <th>Precio unitario</th>
                <th>Impuesto</th>
                <th>Monto impuesto</th>
                <th>Total por línea</th>
              </tr>
            </thead>
            <tbody>
              {lineas.length === 0 ? (
                <tr>
                  <td colSpan={6} className="factura-vacio">Esta factura no tiene líneas.</td>
                </tr>
              ) : (
                lineas.map((l, i) => (
                  <tr key={`${l.StockItemID}-${i}`}>
                    <td className="izq">
                      <Enlace onClick={onVerProducto && (() => onVerProducto(l))}>{l.StockItemName}</Enlace>
                    </td>
                    <td className="num">{l.Quantity}</td>
                    <td className="num">{numero(l.UnitPrice)}</td>
                    <td className="num">{numero(l.TaxRate)} %</td>
                    <td className="num">{numero(l.TaxAmount)}</td>
                    <td className="num">{numero(l.ExtendedPrice)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="factura-resumen">
          <div className="factura-notas">
            <p>Método de entrega: {h.DeliveryMethod ?? 'Vacío'}</p>
            <p>Instrucciones de entrega: {h.DeliveryInstructions || 'Vacío'}</p>
          </div>

          {hayTotales && (
            <div className="factura-totales">
              <div><span>Subtotal</span><span>{numero(subtotal)}</span></div>
              <div><span>Impuestos</span><span>{numero(impuestos)}</span></div>
              <div className="factura-total"><span>Total</span><span>{numero(total)}</span></div>
            </div>
          )}
        </div>

        <div className="factura-firma">
          <span className="factura-linea" />
          <strong>{h.Salesperson ?? ''}</strong>
        </div>

        <div className="factura-pie">
          <button type="button" className="factura-imprimir" onClick={() => window.print()}>
            Imprimir
          </button>
        </div>
      </div>

      <Ola posicion="inf" />
    </article>
  );
}