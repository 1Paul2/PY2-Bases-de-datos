import { useEffect, useState } from 'react';
import { enviar, pedir, useCatalogo } from '../Api';
import Filtros from '../components/Filtros';
import Tabla from '../components/Tabla';
import Paginacion from '../components/Paginacion';
import Factura from '../components/Factura';
import Mapa from '../components/Mapa';
import SelectorBusqueda from '../components/SelectorBusqueda';

const POR_PAGINA = 10;

const columnas = [
  { clave: 'InvoiceID', titulo: 'Factura' },
  { clave: 'InvoiceDate', titulo: 'Fecha' },
  { clave: 'CustomerName', titulo: 'Cliente' },
  { clave: 'DeliveryMethod', titulo: 'Método de entrega' },
  { clave: 'TotalAmount', titulo: 'Monto' }
];

// [etiqueta, columna que devuelve SP_CLIENTES]
const camposCliente = [
  ['Nombre', 'Nombre'],
  ['Categoría', 'Categoría'],
  ['Grupo de compra', 'Grupo_de_compra'],
  ['Contacto primario', 'Contacto_Primario'],
  ['Contacto alternativo', 'Contacto_Secundario'],
  ['Cliente por facturar', 'Cliente_por_facturar'],
  ['Método de entrega', 'Métodos_de_entrega'],
  ['Ciudad de entrega', 'Ciudad_de_entrega'],
  ['Código postal', 'Código_postal'],
  ['Teléfono', 'Telefono'],
  ['Fax', 'Fax'],
  ['Días de gracia para pagar', 'Días_de_gracia_para_pagar'],
  ['Sitio web', 'Sitio_web'],
  ['Dirección de entrega 1', 'Direccion_Entrega_1'],
  ['Dirección de entrega 2', 'Direccion_Entrega_2'],
  ['Dirección postal 1', 'Direccion_Postal_1'],
  ['Dirección postal 2', 'Direccion_Postal_2']
];

// [etiqueta, columna que devuelve SP_GetStockItemDetails]
const camposProducto = [
  ['Nombre del producto', 'StockItemName'],
  ['Proveedor', 'SupplierName'],
  ['Color', 'ColorName'],
  ['Unidad de empaquetamiento', 'UnitPackageTypeName'],
  ['Empaquetamiento', 'OuterPackageTypeName'],
  ['Cantidad de empaquetamiento', 'QuantityPerOuter'],
  ['Marca', 'BrandTexto'],
  ['Tallas / tamaño', 'SizeTexto'],
  ['Impuesto', 'TaxRate'],
  ['Precio unitario', 'UnitPrice'],
  ['Precio de venta recomendado', 'RecommendedRetailPrice'],
  ['Peso', 'TypicalWeightPerUnit'],
  ['Palabras clave', 'SearchDetails'],
  ['Cantidad disponible', 'QuantityOnHandTexto'],
  ['Ubicación', 'BinLocationTexto']
];

const dinero = v =>
  Number(v).toLocaleString('es-CR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Solo presentación: no se calcula ni agrupa nada
const FORMATOS_PRODUCTO = {
  TaxRate: v => `${Number(v)} %`,
  UnitPrice: dinero,
  RecommendedRetailPrice: dinero,
  TypicalWeightPerUnit: v => `${Number(v)} kg`
};

const filtrosIniciales = {
  cliente: '',
  desde: '',
  hasta: '',
  min: '',
  max: ''
};

// Fecha local (toISOString usa UTC y de noche daría el día siguiente)
const hoy = () => new Date().toLocaleDateString('en-CA');

const lineaVacia = { StockItemID: '', Nombre: '', Disponible: null, Quantity: '', UnitPrice: '', TaxRate: '', Description: '' };

const formularioInicial = () => ({
  CustomerID: '',
  DeliveryMethodID: '',
  CustomerPurchaseOrderNumber: '',
  ContactPersonID: '',
  SalespersonPersonID: '',
  InvoiceDate: hoy(),
  DeliveryInstructions: ''
});

export default function Ventas() {
  const [filtros, setFiltros] = useState(filtrosIniciales);
  const [ventas, setVentas] = useState([]);
  const [total, setTotal] = useState(0);
  const [textos, setTextos] = useState({});
  const metodos = useCatalogo('/catalogos/metodos-entrega');
  const [pagina, setPagina] = useState(1);
  const [detalle, setDetalle] = useState(null);
  const [cliente, setCliente] = useState(null);
  const [producto, setProducto] = useState(null);
  const [error, setError] = useState('');
  const [mensaje, setMensaje] = useState('');
  const [nueva, setNueva] = useState(false);
  const [formulario, setFormulario] = useState(formularioInicial());
  const [lineas, setLineas] = useState([{ ...lineaVacia }]);
  const [guardando, setGuardando] = useState(false);
  const [recarga, setRecarga] = useState(0);

  useEffect(() => {
    const params = new URLSearchParams();

    if (filtros.cliente) params.append('cliente', filtros.cliente);
    if (filtros.desde) params.append('desde', filtros.desde);
    if (filtros.hasta) params.append('hasta', filtros.hasta);
    if (filtros.min) params.append('min', filtros.min);
    if (filtros.max) params.append('max', filtros.max);
    // La paginación se hace en el SP (hay más de 70 000 facturas)
    params.append('pagina', pagina);
    params.append('porPagina', POR_PAGINA);

    pedir(`/ventas?${params}`)
      .then(res => {
        setVentas(res.data);
        setTotal(res.total ?? res.data.length);
        setError('');
      })
      .catch(err => setError(err.message));
  }, [filtros, recarga, pagina]);

  const cambiarFiltro = (nombre, valor) => {
    setPagina(1);
    setFiltros(anterior => ({
      ...anterior,
      [nombre]: valor
    }));
  };

  const restaurarFiltros = () => {
    setPagina(1);
    setFiltros(filtrosIniciales);
  };

  const verDetalle = async fila => {
    try {
      const res = await pedir(`/ventas/${fila.InvoiceID}`);
      setDetalle(res);
    } catch (err) {
      setError(err.message);
    }
  };

  // Enlace del nombre del cliente: abre su detalle (el SP lo busca por nombre)
  const verCliente = async encabezado => {
    const nombre = encabezado?.CustomerName ?? encabezado;
    try {
      const res = await pedir(`/clientes/${encodeURIComponent(nombre)}`);
      setCliente(res.data[0]);
    } catch (err) {
      setError(err.message);
    }
  };

  // Enlace del nombre del producto: abre su detalle
  const verProducto = async linea => {
    const id = linea?.StockItemID ?? linea;
    try {
      const res = await pedir(`/productos/${id}`);
      setProducto(res.data[0]);
    } catch (err) {
      setError(err.message);
    }
  };

  const abrirNueva = () => {
    setFormulario(formularioInicial());
    setLineas([{ ...lineaVacia }]);
    setTextos({});
    setError('');
    setMensaje('');
    setNueva(true);
  };

  const cambiarFormulario = evento => {
    const { name, value } = evento.target;
    setFormulario(anterior => ({ ...anterior, [name]: value }));
  };

  const cambiarLinea = (indice, nombre, valor) => {
    setLineas(actuales => actuales.map((l, i) => (i === indice ? { ...l, [nombre]: valor } : l)));
  };

  // Al elegir el cliente se proponen su método de entrega y su contacto primario
  const elegirCliente = opcion => {
    setFormulario(anterior => ({
      ...anterior,
      CustomerID: opcion ? opcion.CustomerID : '',
      DeliveryMethodID: opcion ? String(opcion.DeliveryMethodID) : anterior.DeliveryMethodID,
      ContactPersonID: opcion ? opcion.PrimaryContactPersonID : anterior.ContactPersonID
    }));
    if (opcion) setTextos(anterior => ({ ...anterior, ContactPersonID: opcion.PrimaryContactName }));
  };

  const elegirPersona = campo => opcion => {
    setFormulario(anterior => ({ ...anterior, [campo]: opcion ? opcion.PersonID : '' }));
  };

  // Al elegir el producto se proponen su precio e impuesto (se pueden cambiar)
  const elegirProducto = indice => opcion => {
    setLineas(actuales => actuales.map((l, i) => (i !== indice ? l : opcion
      ? {
          ...l,
          StockItemID: opcion.StockItemID,
          Nombre: opcion.StockItemName,
          Disponible: opcion.QuantityOnHand,
          UnitPrice: opcion.UnitPrice,
          TaxRate: opcion.TaxRate
        }
      : { ...l, StockItemID: '', Disponible: null })));
  };

  const agregarLinea = () => setLineas(actuales => [...actuales, { ...lineaVacia }]);

  const quitarLinea = indice =>
    setLineas(actuales => (actuales.length === 1 ? actuales : actuales.filter((_, i) => i !== indice)));

  // Se envían los datos tal cual; el impuesto y el total los calcula el procedimiento almacenado
  const guardar = async evento => {
    evento.preventDefault();
    setGuardando(true);
    setError('');
    setMensaje('');

    try {
      const res = await enviar('/ventas', 'POST', {
        ...formulario,
        Lineas: lineas.map(({ StockItemID, Quantity, UnitPrice, TaxRate, Description }) =>
          ({ StockItemID, Quantity, UnitPrice, TaxRate, Description }))
      });
      setNueva(false);
      setPagina(1);
      setRecarga(n => n + 1);
      const numero = res?.data?.NewInvoiceID;
      setMensaje(numero ? `Venta creada correctamente. Factura #${numero}.` : 'Venta creada correctamente.');
    } catch (err) {
      setError(err.message);
    } finally {
      setGuardando(false);
    }
  };

  const campos = [
    {
      nombre: 'cliente',
      etiqueta: 'Cliente',
      tipo: 'text'
    },
    {
      nombre: 'desde',
      etiqueta: 'Desde',
      tipo: 'date'
    },
    {
      nombre: 'hasta',
      etiqueta: 'Hasta',
      tipo: 'date'
    },
    {
      nombre: 'min',
      etiqueta: 'Monto mínimo',
      tipo: 'number'
    },
    {
      nombre: 'max',
      etiqueta: 'Monto máximo',
      tipo: 'number'
    }
  ];

  const ventasVisibles = ventas.map(v => ({
    ...v,
    InvoiceDate: v.InvoiceDate ? String(v.InvoiceDate).slice(0, 10) : ''
  }));

  return (
    <section className="modulo">
      <div className="modulo-header">
        <div className="modulo-header-texto">
          <p className="modulo-eyebrow">Facturación y Pedidos</p>
          <h1 className="modulo-titulo">Ventas</h1>
          <span className="modulo-contador">
            {total.toLocaleString('es-CR')} {total === 1 ? 'resultado' : 'resultados'}
          </span>
        </div>
        <div className="modulo-acciones">
          <button type="button" className="btn btn-primario" onClick={abrirNueva}>
            + Nueva venta
          </button>
        </div>
      </div>

      <div className="barra-filtros">
        <Filtros campos={campos} valores={filtros} onCambio={cambiarFiltro} />
        <button type="button" className="btn btn-fantasma" onClick={restaurarFiltros}>
          Restaurar filtros
        </button>
      </div>

      {error && <p className="mensaje mensaje-error">{error}</p>}
      {mensaje && <p className="mensaje mensaje-exito">{mensaje}</p>}

      <div className="tabla-wrapper">
        <Tabla
          columnas={columnas}
          filas={ventasVisibles}
          onFila={verDetalle}
          acciones={fila => (
            <div className="acciones-fila">
              <button
                type="button"
                onClick={e => { e.stopPropagation(); verDetalle(fila); }}
              >
                Ver detalles
              </button>
              <span aria-hidden="true" />
            </div>
          )}
        />
      </div>

      <Paginacion
        total={total}
        pagina={pagina}
        porPagina={POR_PAGINA}
        onCambio={setPagina}
      />

      {nueva && (
        <div className="fondo" onClick={() => setNueva(false)}>
          <form className="ventana formulario" onSubmit={guardar} onClick={e => e.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setNueva(false)} aria-label="Cerrar">✕</button>
            <h2>Nueva venta</h2>

            <SelectorBusqueda
              etiqueta="Cliente" ruta="/catalogos/clientes" campoId="CustomerID" campoTexto="CustomerName"
              valor={formulario.CustomerID} textoInicial={textos.CustomerID} onCambio={elegirCliente} requerido
            />
            <label>Método de entrega
              <select name="DeliveryMethodID" value={formulario.DeliveryMethodID} onChange={cambiarFormulario} required>
                <option value="">Seleccione...</option>
                {metodos.map(m => <option key={m.DeliveryMethodID} value={m.DeliveryMethodID}>{m.DeliveryMethodName}</option>)}
              </select>
            </label>
            <label>Número de orden<input name="CustomerPurchaseOrderNumber" type="text" maxLength={20} value={formulario.CustomerPurchaseOrderNumber} onChange={cambiarFormulario} required /></label>
            <SelectorBusqueda
              etiqueta="Persona de contacto" ruta="/catalogos/personas" campoId="PersonID" campoTexto="FullName"
              valor={formulario.ContactPersonID} textoInicial={textos.ContactPersonID}
              onCambio={elegirPersona('ContactPersonID')} requerido
            />
            <SelectorBusqueda
              etiqueta="Vendedor" ruta="/catalogos/personas" extra={{ soloVendedores: 1 }} campoId="PersonID" campoTexto="FullName"
              valor={formulario.SalespersonPersonID} textoInicial={textos.SalespersonPersonID}
              onCambio={elegirPersona('SalespersonPersonID')} requerido
            />
            <label>Fecha de la factura<input name="InvoiceDate" type="date" value={formulario.InvoiceDate} onChange={cambiarFormulario} required /></label>
            <label className="formulario-ancho">Instrucciones de entrega<input name="DeliveryInstructions" type="text" maxLength={500} value={formulario.DeliveryInstructions} onChange={cambiarFormulario} required /></label>

            <h3 className="formulario-ancho">Productos de la factura</h3>

            {lineas.map((l, i) => (
              <div key={i} className="formulario-ancho" style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 2.2fr) repeat(3, minmax(0, 1fr)) minmax(0, 1.4fr) auto', gap: '10px', alignItems: 'start' }}>
                <SelectorBusqueda
                  etiqueta="Producto" ruta="/catalogos/productos" campoId="StockItemID" campoTexto="StockItemName"
                  valor={l.StockItemID} textoInicial={l.Nombre} onCambio={elegirProducto(i)} requerido
                />
                <label>
                  Cantidad
                  <input type="number" min="1" max={l.Disponible ?? undefined} value={l.Quantity} onChange={e => cambiarLinea(i, 'Quantity', e.target.value)} required />
                  {l.Disponible !== null && <span className="ayuda">Disponible: {Number(l.Disponible).toLocaleString('es-CR')}</span>}
                </label>
                <label>Precio unitario<input type="number" min="0" step="0.01" value={l.UnitPrice} onChange={e => cambiarLinea(i, 'UnitPrice', e.target.value)} required /></label>
                <label>Impuesto (%)<input type="number" min="0" step="0.01" value={l.TaxRate} onChange={e => cambiarLinea(i, 'TaxRate', e.target.value)} required /></label>
                <label>Descripción<input type="text" value={l.Description} onChange={e => cambiarLinea(i, 'Description', e.target.value)} /></label>
                <button type="button" className="btn btn-fantasma" style={{ marginTop: '22px' }} onClick={() => quitarLinea(i)} disabled={lineas.length === 1}>Eliminar</button>
              </div>
            ))}

            <div className="formulario-ancho">
              <button type="button" className="btn btn-fantasma" onClick={agregarLinea}>+ Agregar producto</button>
            </div>

            {error && <p className="mensaje mensaje-error formulario-ancho">{error}</p>}

            <div className="formulario-ancho">
              <button type="submit" className="btn btn-primario" disabled={guardando}>
                {guardando ? 'Guardando...' : 'Guardar venta'}
              </button>
            </div>
          </form>
        </div>
      )}

      {detalle && (
        <div className="fondo" onClick={() => setDetalle(null)}>
          <div className="ventana ventana-factura" onClick={e => e.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setDetalle(null)} aria-label="Cerrar">✕</button>

            <Factura
              encabezado={detalle.encabezado}
              lineas={detalle.lineas || []}
              onVerCliente={verCliente}
              onVerProducto={verProducto}
            />
          </div>
        </div>
      )}

      {cliente && (
        <div className="fondo" onClick={() => setCliente(null)}>
          <div className="ventana" onClick={e => e.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setCliente(null)} aria-label="Cerrar">✕</button>

            <h2>Detalle del cliente</h2>

            <dl>
              {camposCliente.map(([etiqueta, clave]) => {
                const valor = cliente[clave];
                const vacio = valor === null || valor === undefined || valor === '';
                return (
                  <div key={clave}>
                    <dt>{etiqueta}</dt>
                    <dd>
                      {vacio
                        ? 'Vacío'
                        : clave === 'Sitio_web'
                          ? <a href={valor} target="_blank" rel="noreferrer">{valor}</a>
                          : String(valor)}
                    </dd>
                  </div>
                );
              })}
            </dl>

            <h2>Ubicación de entrega</h2>
            <Mapa
              latitud={cliente.Latitud}
              longitud={cliente.Longitud}
              titulo={cliente.Nombre}
              subtitulo={cliente.DeliveryAddressLine1}
            />
          </div>
        </div>
      )}

      {producto && (
        <div className="fondo" onClick={() => setProducto(null)}>
          <div className="ventana" onClick={e => e.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setProducto(null)} aria-label="Cerrar">✕</button>

            <h2>Detalle del producto</h2>

            <dl>
              {camposProducto.map(([etiqueta, clave]) => {
                const valor = producto[clave];
                const vacio = valor === null || valor === undefined || valor === '';
                const formatear = FORMATOS_PRODUCTO[clave];
                return (
                  <div key={clave}>
                    <dt>{etiqueta}</dt>
                    <dd>{vacio ? 'Vacío' : formatear ? formatear(valor) : String(valor)}</dd>
                  </div>
                );
              })}
            </dl>
          </div>
        </div>
      )}
    </section>
  );
}