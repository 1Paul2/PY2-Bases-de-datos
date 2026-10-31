function formatearValor(valor) {
  if (valor === null || valor === undefined || valor === '') return 'Vacío';

  // Fecha ISO
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(valor)) {
    const d = new Date(valor);
    if (!Number.isNaN(d.getTime())) {
      return d.toLocaleDateString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        timeZone: 'UTC', // SQL Server manda la fecha a medianoche UTC; sin esto sale un día antes
      });
    }
  }

  // Fecha YYYY-MM-DD
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(valor)) {
    const [y, m, d] = valor.split('-');
    return `${d}/${m}/${y}`;
  }

  // Booleanos
  if (typeof valor === 'boolean') return valor ? 'Sí' : 'No';

  // Números con decimales (precios)
  if (typeof valor === 'number' && !Number.isInteger(valor)) {
    return valor.toLocaleString('es-ES', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }

  return String(valor);
}

export default function Tabla({ columnas, filas, onFila, acciones }) {
  const totalColumnas = columnas.length + (acciones ? 1 : 0);

  return (
    <table>
      <thead>
        <tr>
          {columnas.map(c => <th key={c.clave}>{c.titulo}</th>)}
          {acciones && <th style={{ textAlign: 'right' }}>Acciones</th>}
        </tr>
      </thead>
      <tbody>
        {filas.length === 0 ? (
          <tr key="sin-resultados">
            <td className="tabla-vacia" colSpan={totalColumnas}>
              No hay resultados.
            </td>
          </tr>
        ) : (
          filas.map((f, i) => (
            <tr
              key={obtenerClave(f, i)}
              onClick={() => onFila && onFila(f)}
              style={{ cursor: onFila ? 'pointer' : 'default' }}
            >
              {columnas.map(c => (
                <td key={c.clave}>{formatearValor(f[c.clave])}</td>
              ))}
              {acciones && <td>{acciones(f)}</td>}
            </tr>
          ))
        )}
      </tbody>
    </table>
  );
}

function obtenerClave(fila, indice) {
  const clavesPreferidas = [
    'CustomerID',
    'SupplierID',
    'StockItemID',
    'InvoiceID',
    'Nombre',
  ];
  const clave = clavesPreferidas.find(
    c => fila[c] !== undefined && fila[c] !== null
  );
  return clave ? fila[clave] : `fila-${indice}`;
}