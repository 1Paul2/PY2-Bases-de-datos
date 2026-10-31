import { useState, useEffect } from 'react';
import { enviar, pedir, useCatalogo } from '../Api';
import Filtros from '../components/Filtros';
import Tabla from '../components/Tabla';
import Paginacion from '../components/Paginacion';
import ConfirmarEliminar from '../components/ConfirmarEliminar';
import Mapa from '../components/Mapa';
import SelectorBusqueda from '../components/SelectorBusqueda';

const POR_PAGINA = 10;

const columnas = [
  { clave: 'Nombre', titulo: 'Nombre' },
  { clave: 'Categoria', titulo: 'Categoría' },
  { clave: 'Metodo_de_entrega', titulo: 'Método de entrega' }
];

const filtrosIniciales = { apodo: '', categoria: '', metodo: '' };


const camposDetalle = [
  ['Nombre', 'Nombre'],
  ['Categoría', 'Categoría'],
  ['Grupo de compra', 'Grupo_de_compra'],
  ['Contacto primario', 'Contacto_Primario'],
  ['Contacto alternativo', 'Contacto_Secundario'],
  ['Cliente por facturar', 'Cliente_por_facturar'],
  ['Método de entrega', 'Métodos_de_entrega'],
  ['Ciudad de entrega', 'Ciudad_de_entrega'],
  ['Código postal de entrega', 'Código_postal'],
  ['Ciudad postal', 'Ciudad_postal'],
  ['Código postal (dirección postal)', 'PostalPostalCode'],
  ['Teléfono', 'Telefono'],
  ['Fax', 'Fax'],
  ['Días de gracia para pagar', 'Días_de_gracia_para_pagar'],
  ['Sitio web', 'Sitio_web'],
  ['Dirección de entrega 1', 'Direccion_Entrega_1'],
  ['Dirección de entrega 2', 'Direccion_Entrega_2'],
  ['Dirección postal 1', 'Direccion_Postal_1'],
  ['Dirección postal 2', 'Direccion_Postal_2']
];

const formularioInicial = {
  CustomerName: '', CustomerCategoryID: '', PrimaryContactPersonID: '', PrimaryContactName: '', AlternateContactName: '',
  AlternateContactPersonID: '', BillToCustomerID: '', BuyingGroupID: '',
  DeliveryMethodID: '', DeliveryCityID: '', PostalCityID: '', DeliveryPostalCode: '', PostalPostalCode: '',
  PhoneNumber: '', FaxNumber: '', PaymentDays: '', StandardDiscountPercentage: '', IsStatementSent: false, IsOnCreditHold: false, WebsiteURL: '',
  DeliveryAddressLine1: '', DeliveryAddressLine2: '', PostalAddressLine1: '',
  PostalAddressLine2: '', AccountOpenedDate: '', // vacío = la base pone la fecha de hoy
  DeliveryLatitude: '', DeliveryLongitude: ''
};

export default function Clientes() {
  const [filtros, setFiltros] = useState(filtrosIniciales);
  const [textos, setTextos] = useState({});
  const categorias = useCatalogo('/catalogos/categorias-clientes');
  const metodos = useCatalogo('/catalogos/metodos-entrega');
  // Para los filtros solo se ofrecen las opciones que tienen clientes
  const categoriasFiltro = useCatalogo('/catalogos/filtros/categorias-clientes');
  const metodosFiltro = useCatalogo('/catalogos/filtros/metodos-clientes');
  const gruposCompra = useCatalogo('/catalogos/grupos-compra');
  const [clientes, setClientes] = useState([]);
  const [total, setTotal] = useState(0);
  const [recarga, setRecarga] = useState(0);
  const [pagina, setPagina] = useState(1);
  const [detalle, setDetalle] = useState(null);
  const [error, setError] = useState('');
  const [mensaje, setMensaje] = useState('');
  const [porEliminar, setPorEliminar] = useState(null);
  const [formulario, setFormulario] = useState(formularioInicial);
  const [modoFormulario, setModoFormulario] = useState(null);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    pedir(`/clientes?${parametrosFiltro(filtros, pagina)}`)
      .then(res => { setClientes(res.data); setTotal(res.total); setError(''); })
      .catch(err => setError(err.message));
  }, [filtros, pagina, recarga]);

  const abrirNuevo = () => {
    setError('');
    setMensaje('');
    setFormulario(formularioInicial);
    setTextos({});
    setModoFormulario('nuevo');
  };

  const abrirEdicion = async fila => {
    try {
      const res = await pedir(`/clientes/${encodeURIComponent(fila.Nombre)}`);
      const datos = res.data[0];

      setError('');
      setMensaje('');
      setFormulario({
        ...formularioInicial,
        CustomerID: datos.CustomerID,
        CustomerName: datos.Nombre,
        CustomerCategoryID: datos.CustomerCategoryID ?? '',
        PrimaryContactPersonID: datos.PrimaryContactPersonID ?? '',
        AlternateContactPersonID: datos.AlternateContactPersonID ?? '',
        BillToCustomerID: datos.BillToCustomerID ?? '',
        BuyingGroupID: datos.BuyingGroupID ?? '',
        DeliveryMethodID: datos.DeliveryMethodID ?? '',
        DeliveryCityID: datos.DeliveryCityID ?? '',
        PostalCityID: datos.PostalCityID ?? '',
        DeliveryPostalCode: datos.DeliveryPostalCode ?? '',
        PostalPostalCode: datos.PostalPostalCode ?? '',
        PhoneNumber: datos.PhoneNumber ?? '',
        FaxNumber: datos.FaxNumber ?? '',
        PaymentDays: datos.PaymentDays ?? '',
        StandardDiscountPercentage: datos.StandardDiscountPercentage ?? '',
        IsStatementSent: datos.IsStatementSent ?? false,
        IsOnCreditHold: datos.IsOnCreditHold ?? false,
        WebsiteURL: datos.WebsiteURL ?? '',
        DeliveryAddressLine1: datos.DeliveryAddressLine1 ?? '',
        DeliveryAddressLine2: datos.DeliveryAddressLine2 ?? '',
        PostalAddressLine1: datos.PostalAddressLine1 ?? '',
        PostalAddressLine2: datos.PostalAddressLine2 ?? '',
        AccountOpenedDate: datos.AccountOpenedDate?.slice(0, 10) ?? '',
        DeliveryLatitude: datos.DeliveryLatitude ?? '',
        DeliveryLongitude: datos.DeliveryLongitude ?? ''
      });
      // Textos que se muestran en los buscadores al editar
      setTextos({
        PrimaryContactPersonID: datos.Contacto_Primario ?? '',
        AlternateContactPersonID: datos.AlternateContactName ?? '',
        BillToCustomerID: datos.Cliente_por_facturar ?? '',
        DeliveryCityID: datos.Ciudad_de_entrega ?? '',
        PostalCityID: datos.Ciudad_postal ?? ''
      });
      setModoFormulario('editar');
    } catch (err) {
      setError(err.message);
    }
  };

  const cambiarFormulario = evento => {
    const { name, value } = evento.target;
    setFormulario(anterior => ({ ...anterior, [name]: value }));
  };

  // Para los buscadores: guarda el ID de la opción elegida (o '' si se borra)
  const elegir = (campo, columnaId) => opcion => {
    setFormulario(anterior => ({ ...anterior, [campo]: opcion ? opcion[columnaId] : '' }));
  };

  const guardar = async evento => {
    evento.preventDefault();
    setGuardando(true);
    setError('');
    setMensaje('');

    try {
      const datos = { ...formulario };
      const id = datos.CustomerID;
      delete datos.CustomerID;

      if (modoFormulario === 'nuevo') {
        await enviar('/clientes', 'POST', datos);
        setMensaje('Cliente creado correctamente.');
      } else {
        await enviar(`/clientes/${id}`, 'PUT', datos);
        setMensaje('Cliente actualizado correctamente.');
      }

      setModoFormulario(null);
      setPagina(1);
      setRecarga(n => n + 1);
    } catch (err) {
      setError(err.message);
    } finally {
      setGuardando(false);
    }
  };

  const eliminar = fila => {
    setError('');
    setMensaje('');
    setPorEliminar(fila);
  };

  // Si falla, el error sube a la ventana de confirmación y se muestra ahí
  const confirmarEliminar = async () => {
    const fila = porEliminar;
    await enviar(`/clientes/${fila.CustomerID}`, 'DELETE');
    setPorEliminar(null);
    setMensaje('Cliente eliminado correctamente.');
    setRecarga(n => n + 1);
  };

  const verDetalle = async (fila) => {
    try {
      const res = await pedir(`/clientes/${encodeURIComponent(fila.Nombre)}`);
      setDetalle(res.data[0]);
    } catch (err) {
      setError(err.message);
    }
  };

  const cambiar = (nombre, valor) => {
    setPagina(1);
    setFiltros(prev => ({ ...prev, [nombre]: valor }));
  };

  const campos = [
    { nombre: 'apodo', etiqueta: 'Nombre' },
    {
      nombre: 'categoria',
      etiqueta: 'Categoría',
      opciones: categoriasFiltro.map(c => ({ valor: c.CustomerCategoryID, texto: c.CustomerCategoryName }))
    },
    {
      nombre: 'metodo',
      etiqueta: 'Método de entrega',
      opciones: metodosFiltro.map(m => ({ valor: m.DeliveryMethodID, texto: m.DeliveryMethodName }))
    }
  ];


  return (
    <section className="modulo">
      <div className="modulo-header">
        <div className="modulo-header-texto">
          <p className="modulo-eyebrow">Gestión Comercial</p>
          <h1 className="modulo-titulo">Clientes</h1>
          <span className="modulo-contador">
            {total} {total === 1 ? 'resultado' : 'resultados'}
          </span>
        </div>
        <div className="modulo-acciones">
          <button type="button" className="btn btn-primario" onClick={abrirNuevo}>
            + Nuevo cliente
          </button>
        </div>
      </div>

      <div className="barra-filtros">
        <Filtros campos={campos} valores={filtros} onCambio={cambiar} />
        <button type="button" className="btn btn-fantasma" onClick={() => { setFiltros(filtrosIniciales); setPagina(1); }}>
          Restaurar filtros
        </button>
      </div>

      {error && <p className="mensaje mensaje-error">{error}</p>}
      {mensaje && <p className="mensaje mensaje-exito">{mensaje}</p>}

      <div className="tabla-wrapper">
        <Tabla
          columnas={columnas}
          filas={clientes}
          onFila={verDetalle}
          acciones={fila => (
            <div className="acciones-fila">
              <button type="button" onClick={e => { e.stopPropagation(); verDetalle(fila); }}>Ver detalles</button>
              <button type="button" onClick={evento => { evento.stopPropagation(); abrirEdicion(fila); }}>
                Editar
              </button>
              <button type="button" onClick={evento => { evento.stopPropagation(); eliminar(fila); }}>
                Eliminar
              </button>
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

      {porEliminar && (
        <ConfirmarEliminar
          tipo="cliente"
          nombre={porEliminar.Nombre}
          onConfirmar={confirmarEliminar}
          onCancelar={() => setPorEliminar(null)}
        />
      )}

      {detalle && (
        <div className="fondo" onClick={() => setDetalle(null)}>
          <div className="ventana" onClick={e => e.stopPropagation()}>
            <button
              type="button"
              className="btn-cerrar"
              onClick={() => setDetalle(null)}
              aria-label="Cerrar"
            >
              ✕
            </button>

            <h2>Detalle del cliente</h2>

            <dl>
              {camposDetalle.map(([etiqueta, clave]) => {
                const valor = detalle[clave];
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
              latitud={detalle.Latitud}
              longitud={detalle.Longitud}
              titulo={detalle.Nombre || detalle.CustomerName}
              subtitulo={detalle.DeliveryAddressLine1}
            />
          </div>
        </div>
      )}

      {modoFormulario && (
        <div className="fondo" onClick={() => setModoFormulario(null)}>
          <form className="ventana formulario" onSubmit={guardar} onClick={evento => evento.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setModoFormulario(null)} aria-label="Cerrar">✕</button>
            <h2>{modoFormulario === 'nuevo' ? 'Nuevo cliente' : 'Editar cliente'}</h2>

            <label>Nombre<input name="CustomerName" value={formulario.CustomerName} onChange={cambiarFormulario} required /></label>
            <label>Categoría
              <select name="CustomerCategoryID" value={formulario.CustomerCategoryID} onChange={cambiarFormulario} required>
                <option value="">Seleccione...</option>
                {categorias.map(c => <option key={c.CustomerCategoryID} value={c.CustomerCategoryID}>{c.CustomerCategoryName}</option>)}
              </select>
            </label>
            <label>Grupo de compra
              <select name="BuyingGroupID" value={formulario.BuyingGroupID ?? ''} onChange={cambiarFormulario}>
                <option value="">Ninguno</option>
                {gruposCompra.map(g => <option key={g.BuyingGroupID} value={g.BuyingGroupID}>{g.BuyingGroupName}</option>)}
              </select>
            </label>
            <SelectorBusqueda
              etiqueta="Contacto primario" ruta="/catalogos/personas" campoId="PersonID" campoTexto="FullName"
              valor={formulario.PrimaryContactPersonID} textoInicial={textos.PrimaryContactPersonID}
              onCambio={elegir('PrimaryContactPersonID', 'PersonID')} requerido
              onTextoLibre={texto => setFormulario(a => ({ ...a, PrimaryContactName: texto }))}
              placeholder="Busque o escriba un nombre nuevo"
            />
            <SelectorBusqueda
              etiqueta="Contacto alternativo" ruta="/catalogos/personas" campoId="PersonID" campoTexto="FullName"
              valor={formulario.AlternateContactPersonID} textoInicial={textos.AlternateContactPersonID}
              onCambio={elegir('AlternateContactPersonID', 'PersonID')}
              onTextoLibre={texto => setFormulario(a => ({ ...a, AlternateContactName: texto }))}
              placeholder="Busque o escriba un nombre nuevo"
            />
            <label>Método de entrega
              <select name="DeliveryMethodID" value={formulario.DeliveryMethodID} onChange={cambiarFormulario} required>
                <option value="">Seleccione...</option>
                {metodos.map(m => <option key={m.DeliveryMethodID} value={m.DeliveryMethodID}>{m.DeliveryMethodName}</option>)}
              </select>
            </label>
            <SelectorBusqueda
              etiqueta="Cliente por facturar" ruta="/catalogos/clientes" campoId="CustomerID" campoTexto="CustomerName"
              valor={formulario.BillToCustomerID} textoInicial={textos.BillToCustomerID}
              onCambio={elegir('BillToCustomerID', 'CustomerID')}
              placeholder="Vacío = se factura a sí mismo"
            />
            <SelectorBusqueda
              etiqueta="Ciudad de entrega" ruta="/catalogos/ciudades" campoId="CityID" campoTexto="Texto"
              valor={formulario.DeliveryCityID} textoInicial={textos.DeliveryCityID}
              onCambio={elegir('DeliveryCityID', 'CityID')} requerido
            />
            <SelectorBusqueda
              etiqueta="Ciudad postal" ruta="/catalogos/ciudades" campoId="CityID" campoTexto="Texto"
              valor={formulario.PostalCityID} textoInicial={textos.PostalCityID}
              onCambio={elegir('PostalCityID', 'CityID')} requerido
            />
            <label>Código postal de entrega<input name="DeliveryPostalCode" value={formulario.DeliveryPostalCode} onChange={cambiarFormulario} required /></label>
            <label>Código postal<input name="PostalPostalCode" value={formulario.PostalPostalCode} onChange={cambiarFormulario} required /></label>
            <label>Días de pago<input name="PaymentDays" type="number" min="0" value={formulario.PaymentDays} onChange={cambiarFormulario} required /></label>
            <label>Descuento estándar (%)<input name="StandardDiscountPercentage" type="number" min="0" step="0.001" value={formulario.StandardDiscountPercentage} onChange={cambiarFormulario} placeholder="Vacío = 0" /></label>
            <label>
              <input name="IsStatementSent" type="checkbox" checked={formulario.IsStatementSent}
                onChange={e => setFormulario(a => ({ ...a, IsStatementSent: e.target.checked }))} />
              <span>Enviar estado de cuenta</span>
            </label>
            <label>
              <input name="IsOnCreditHold" type="checkbox" checked={formulario.IsOnCreditHold}
                onChange={e => setFormulario(a => ({ ...a, IsOnCreditHold: e.target.checked }))} />
              <span>Cliente en retención de crédito</span>
            </label>
            <label>Teléfono<input name="PhoneNumber" value={formulario.PhoneNumber} onChange={cambiarFormulario} required /></label>
            <label>Fax<input name="FaxNumber" value={formulario.FaxNumber} onChange={cambiarFormulario} required /></label>
            <label className="formulario-ancho">Sitio web<input name="WebsiteURL" type="url" value={formulario.WebsiteURL} onChange={cambiarFormulario} required /></label>
            <label>Dirección de entrega<input name="DeliveryAddressLine1" value={formulario.DeliveryAddressLine1} onChange={cambiarFormulario} required /></label>
            <label>Dirección de entrega adicional<input name="DeliveryAddressLine2" value={formulario.DeliveryAddressLine2} onChange={cambiarFormulario} /></label>
            <label>Dirección postal<input name="PostalAddressLine1" value={formulario.PostalAddressLine1} onChange={cambiarFormulario} required /></label>
            <label>Dirección postal adicional<input name="PostalAddressLine2" value={formulario.PostalAddressLine2} onChange={cambiarFormulario} /></label>
            <label>Fecha de apertura<input name="AccountOpenedDate" type="date" value={formulario.AccountOpenedDate} onChange={cambiarFormulario} /></label>
            <label>Latitud<input name="DeliveryLatitude" type="number" step="0.000001" value={formulario.DeliveryLatitude} onChange={cambiarFormulario} /></label>
            <label>Longitud<input name="DeliveryLongitude" type="number" step="0.000001" value={formulario.DeliveryLongitude} onChange={cambiarFormulario} /></label>

            {error && <p className="mensaje mensaje-error formulario-ancho">{error}</p>}
            <button type="submit" disabled={guardando}>
              {guardando ? 'Guardando...' : 'Guardar'}
            </button>
          </form>
        </div>
      )}
    </section>
  );
}

// Filtros y página que se envían a la API; la búsqueda, el orden y la paginación los hace el SP
function parametrosFiltro(filtros, pagina) {
  const params = new URLSearchParams({ pagina, porPagina: POR_PAGINA });
  if (filtros.apodo) params.append('apodo', filtros.apodo);
  if (filtros.categoria) params.append('categoria', filtros.categoria);
  if (filtros.metodo) params.append('metodo', filtros.metodo);
  return params;
}
