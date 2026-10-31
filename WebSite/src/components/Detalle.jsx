const ETIQUETAS = {
  CustomerID: 'ID de cliente',
  CustomerName: 'Nombre',
  Nombre: 'Nombre',
  CustomerCategoryID: 'ID de categoría',
  CustomerCategoryName: 'Categoría',
  Categoria: 'Categoría',
  PrimaryContactPersonID: 'ID contacto primario',
  AlternateContactPersonID: 'ID contacto alternativo',
  BillToCustomerID: 'ID cliente por facturar',
  BuyingGroupID: 'ID grupo de compra',
  DeliveryMethodID: 'ID método de entrega',
  DeliveryMethodName: 'Método de entrega',
  Metodo_de_entrega: 'Método de entrega',
  DeliveryCityID: 'ID ciudad de entrega',
  PostalCityID: 'ID ciudad postal',
  DeliveryPostalCode: 'Código postal de entrega',
  PostalPostalCode: 'Código postal',
  PhoneNumber: 'Teléfono',
  FaxNumber: 'Fax',
  PaymentDays: 'Días de pago',
  StandardDiscountPercentage: 'Descuento estándar (%)',
  IsStatementSent: 'Enviar estado de cuenta',
  IsOnCreditHold: 'En retención de crédito',
  WebsiteURL: 'Sitio web',
  DeliveryAddressLine1: 'Dirección de entrega',
  DeliveryAddressLine2: 'Dirección de entrega (adicional)',
  PostalAddressLine1: 'Dirección postal',
  PostalAddressLine2: 'Dirección postal (adicional)',
  AccountOpenedDate: 'Fecha de apertura de cuenta',
  DeliveryLatitude: 'Latitud de entrega',
  DeliveryLongitude: 'Longitud de entrega',
  SupplierName: 'Proveedor',
  StockItemName: 'Producto',
  InvoiceID: 'Número de factura',
  InvoiceDate: 'Fecha de factura',
};

function formatearValor(clave, valor) {
  if (valor === null || valor === undefined || valor === '') return '—';

  // Booleanos
  if (typeof valor === 'boolean') return valor ? 'Sí' : 'No';

  // Fechas ISO
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(valor)) {
    const d = new Date(valor);
    if (!Number.isNaN(d.getTime())) {
      return d.toLocaleString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    }
  }

  // Fechas YYYY-MM-DD
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(valor)) {
    const [y, m, d] = valor.split('-');
    return `${d}/${m}/${y}`;
  }

  // Coordenadas
  if (clave.toLowerCase().includes('latitude') || clave.toLowerCase().includes('longitude')) {
    const n = Number(valor);
    if (Number.isFinite(n)) return n.toFixed(6);
  }

  // Números decimales
  if (typeof valor === 'number' && !Number.isInteger(valor)) {
    return valor.toLocaleString('es-ES', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }

  return String(valor);
}

export default function Detalle({ titulo, datos, onCerrar, children }) {
  if (!datos) return null;

  const entradas = Object.entries(datos).filter(
    ([clave]) => clave !== 'DeliveryLatitude' && clave !== 'DeliveryLongitude'
  );

  return (
    <div className="fondo" onClick={onCerrar}>
      <div className="ventana" onClick={e => e.stopPropagation()}>
        <button type="button" className="btn-cerrar" onClick={onCerrar} aria-label="Cerrar">
          ✕
        </button>

        <h2>{titulo}</h2>

        <dl>
          {entradas.map(([clave, valor]) => (
            <div key={clave}>
              <dt>{ETIQUETAS[clave] || clave.replaceAll('_', ' ')}</dt>
              <dd>{formatearValor(clave, valor)}</dd>
            </div>
          ))}
        </dl>

        {children}
      </div>
    </div>
  );
}