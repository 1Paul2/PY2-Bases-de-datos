import { useEffect, useState } from 'react';
import { enviar, pedir, useCatalogo } from '../Api';
import Filtros from '../components/Filtros';
import Tabla from '../components/Tabla';
import Paginacion from '../components/Paginacion';
import ConfirmarEliminar from '../components/ConfirmarEliminar';
import Mapa from '../components/Mapa';
import SelectorBusqueda from '../components/SelectorBusqueda';

const POR_PAGINA = 10;

const columnas = [
  { clave: 'SupplierName', titulo: 'Proveedor' },
  { clave: 'SupplierCategoryName', titulo: 'Categoría' },
  { clave: 'DeliveryMethodName', titulo: 'Método de entrega' }
];

// [etiqueta que se muestra, columna que devuelve el SP del detalle]
const camposDetalle = [
  ['Código del proveedor', 'SupplierReference'],
  ['Nombre', 'SupplierName'],
  ['Categoría', 'SupplierCategoryName'],
  ['Contacto primario', 'PrimaryContactName'],
  ['Contacto alternativo', 'AlternateContactName'],
  ['Método de entrega', 'DeliveryMethodName'],
  ['Ciudad de entrega', 'DeliveryCityName'],
  ['Código postal de entrega', 'DeliveryPostalCode'],
  ['Ciudad postal', 'PostalCityName'],
  ['Código postal (dirección postal)', 'PostalPostalCode'],
  ['Teléfono', 'PhoneNumber'],
  ['Fax', 'FaxTexto'],
  ['Sitio web', 'WebsiteURL'],
  ['Dirección de entrega 1', 'DeliveryAddressLine1'],
  ['Dirección de entrega 2', 'DeliveryAddressLine2Texto'],
  ['Dirección postal 1', 'PostalAddressLine1'],
  ['Dirección postal 2', 'PostalAddressLine2Texto'],
  ['Nombre del banco', 'BankAccountBranch'],
  ['Titular de la cuenta', 'BankAccountName'],
  ['Número de cuenta corriente', 'BankAccountNumber'],
  ['Días de gracia para pagar', 'PaymentDays']
];

const filtrosIniciales = {
  name: '',
  categoria: '',
  metodo: ''
};

const formularioInicial = {
  SupplierReference: '', SupplierName: '', SupplierCategoryID: '',
  PrimaryContactPersonID: '', AlternateContactPersonID: '', DeliveryMethodID: '',
  PrimaryContactName: '', AlternateContactName: '',
  DeliveryCityID: '', PostalCityID: '', DeliveryPostalCode: '', PostalPostalCode: '',
  PhoneNumber: '', FaxNumber: '', WebsiteURL: '', DeliveryAddressLine1: '',
  DeliveryAddressLine2: '', PostalAddressLine1: '', PostalAddressLine2: '',
  DeliveryLatitude: '', DeliveryLongitude: '', BankAccountBranch: '',
  BankAccountName: '', BankAccountNumber: '', PaymentDays: '',
  // LastEditedBy no se envía: lo asigna el procedimiento almacenado
};

export default function Proveedores() {
  const [filtros, setFiltros] = useState(filtrosIniciales);
  const [categorias, setCategorias] = useState([]);
  const [proveedores, setProveedores] = useState([]);
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
  const [textos, setTextos] = useState({});
  const metodos = useCatalogo('/catalogos/metodos-entrega');
  const categoriasForm = useCatalogo('/catalogos/categorias-proveedores');
  // Para el filtro solo se ofrecen los métodos que tienen proveedores
  const metodosFiltro = useCatalogo('/catalogos/filtros/metodos-proveedores');

  useEffect(() => {
    pedir('/proveedores/categorias')
      .then(res => setCategorias(res.data))
      .catch(err => setError(err.message));
  }, []);

  useEffect(() => {
    pedir(`/proveedores?${parametrosFiltro(filtros, pagina)}`)
      .then(res => {
        setProveedores(res.data);
        setTotal(res.total);
        setError('');
      })
      .catch(err => setError(err.message));
  }, [filtros, pagina, recarga]);

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
      const res = await pedir(`/proveedores/${fila.SupplierID}`);
      setDetalle(res.data[0]);
    } catch (err) {
      setError(err.message);
    }
  };

  const abrirNuevo = () => {
    setError('');
    setMensaje('');
    setFormulario(formularioInicial);
    setTextos({});
    setModoFormulario('nuevo');
  };

  const abrirEdicion = async fila => {
    try {
      const res = await pedir(`/proveedores/${fila.SupplierID}`);
      const datos = res.data[0];
      setFormulario({
        ...formularioInicial,
        SupplierID: fila.SupplierID,
        SupplierReference: datos.SupplierReference ?? '',
        SupplierName: datos.SupplierName ?? '',
        SupplierCategoryID: datos.SupplierCategoryID ?? '',
        PrimaryContactPersonID: datos.PrimaryContactPersonID ?? '',
        AlternateContactPersonID: datos.AlternateContactPersonID ?? '',
        DeliveryMethodID: datos.DeliveryMethodID ?? '',
        DeliveryCityID: datos.DeliveryCityID ?? '',
        PostalCityID: datos.PostalCityID ?? '',
        DeliveryPostalCode: datos.DeliveryPostalCode ?? '',
        PostalPostalCode: datos.PostalPostalCode ?? '',
        PhoneNumber: datos.PhoneNumber ?? '', FaxNumber: datos.FaxNumber ?? '',
        WebsiteURL: datos.WebsiteURL ?? '',
        DeliveryAddressLine1: datos.DeliveryAddressLine1 ?? '',
        DeliveryAddressLine2: datos.DeliveryAddressLine2 ?? '',
        PostalAddressLine1: datos.PostalAddressLine1 ?? '',
        PostalAddressLine2: datos.PostalAddressLine2 ?? '',
        DeliveryLatitude: datos.DeliveryLatitude ?? '',
        DeliveryLongitude: datos.DeliveryLongitude ?? '',
        BankAccountBranch: datos.BankAccountBranch ?? '',
        BankAccountName: datos.BankAccountName ?? '',
        BankAccountNumber: datos.BankAccountNumber ?? '',
        PaymentDays: datos.PaymentDays ?? ''
      });
      // Textos que se muestran en los buscadores al editar
      setTextos({
        PrimaryContactPersonID: datos.PrimaryContactName ?? '',
        AlternateContactPersonID: datos.AlternateContactName ?? '',
        DeliveryCityID: datos.DeliveryCityName ?? '',
        PostalCityID: datos.PostalCityName ?? ''
      });
      setError('');
      setMensaje('');
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

  const recargar = () => setRecarga(n => n + 1);

  const guardar = async evento => {
    evento.preventDefault();
    setGuardando(true);
    setError('');
    setMensaje('');
    try {
      const datos = { ...formulario };
      const id = datos.SupplierID;
      delete datos.SupplierID;
      if (modoFormulario === 'nuevo') {
        await enviar('/proveedores', 'POST', datos);
        setMensaje('Proveedor creado correctamente.');
      } else {
        await enviar(`/proveedores/${id}`, 'PUT', datos);
        setMensaje('Proveedor actualizado correctamente.');
      }
      setModoFormulario(null);
      setPagina(1);
      await recargar();
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
    await enviar(`/proveedores/${fila.SupplierID}`, 'DELETE');
    setPorEliminar(null);
    setMensaje('Proveedor eliminado correctamente.');
    recargar();
  };

  const campos = [
    {
      nombre: 'name',
      etiqueta: 'Nombre',
      tipo: 'text'
    },
    {
      nombre: 'categoria',
      etiqueta: 'Categoría',
      opciones: categorias.map(categoria => ({
        valor: categoria.SupplierCategoryID,
        texto: categoria.SupplierCategoryName
      }))
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
          <p className="modulo-eyebrow">Compras y Suministro</p>
          <h1 className="modulo-titulo">Proveedores</h1>
          <span className="modulo-contador">
            {total} {total === 1 ? 'resultado' : 'resultados'}
          </span>
        </div>
        <div className="modulo-acciones">
          <button type="button" className="btn btn-primario" onClick={abrirNuevo}>
            + Nuevo proveedor
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
          filas={proveedores}
          onFila={verDetalle}
          acciones={fila => (
            <div className="acciones-fila">
              <button type="button" onClick={e => { e.stopPropagation(); verDetalle(fila); }}>Ver detalles</button>
              <button type="button" onClick={e => { e.stopPropagation(); abrirEdicion(fila); }}>Editar</button>
              <button type="button" onClick={e => { e.stopPropagation(); eliminar(fila); }}>Eliminar</button>
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
          tipo="proveedor"
          nombre={porEliminar.SupplierName}
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

            <h2>Detalle del proveedor</h2>

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
                        : clave === 'WebsiteURL'
                          ? <a href={valor} target="_blank" rel="noreferrer">{valor}</a>
                          : String(valor)}
                    </dd>
                  </div>
                );
              })}
            </dl>

            <h2>Ubicación de entrega</h2>
            <Mapa
              latitud={detalle.DeliveryLatitude ?? detalle.Latitud}
              longitud={detalle.DeliveryLongitude ?? detalle.Longitud}
              titulo={detalle.SupplierName}
              subtitulo={detalle.DeliveryAddressLine1}
            />
          </div>
        </div>
      )}

      {modoFormulario && (
        <div className="fondo" onClick={() => setModoFormulario(null)}>
          <form className="ventana formulario" onSubmit={guardar} onClick={e => e.stopPropagation()}>
            <button type="button" className="btn-cerrar" onClick={() => setModoFormulario(null)} aria-label="Cerrar">✕</button>
            <h2>{modoFormulario === 'nuevo' ? 'Nuevo proveedor' : 'Editar proveedor'}</h2>
            <label>Referencia<input name="SupplierReference" value={formulario.SupplierReference} onChange={cambiarFormulario} required /></label>
            <label>Nombre<input name="SupplierName" value={formulario.SupplierName} onChange={cambiarFormulario} required /></label>
            <label>Categoría
              <select name="SupplierCategoryID" value={formulario.SupplierCategoryID} onChange={cambiarFormulario} required>
                <option value="">Seleccione...</option>
                {categoriasForm.map(c => <option key={c.SupplierCategoryID} value={c.SupplierCategoryID}>{c.SupplierCategoryName}</option>)}
              </select>
            </label>
            <label>Método de entrega
              <select name="DeliveryMethodID" value={formulario.DeliveryMethodID ?? ''} onChange={cambiarFormulario} required>
                <option value="">Seleccione...</option>
                {metodos.map(m => <option key={m.DeliveryMethodID} value={m.DeliveryMethodID}>{m.DeliveryMethodName}</option>)}
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
              placeholder="Vacío = el mismo contacto primario"
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
            <label>Código postal entrega<input name="DeliveryPostalCode" value={formulario.DeliveryPostalCode} onChange={cambiarFormulario} required /></label>
            <label>Código postal<input name="PostalPostalCode" value={formulario.PostalPostalCode} onChange={cambiarFormulario} required /></label>
            <label>Teléfono<input name="PhoneNumber" value={formulario.PhoneNumber} onChange={cambiarFormulario} required /></label>
            <label>Fax<input name="FaxNumber" value={formulario.FaxNumber} onChange={cambiarFormulario} required /></label>
            <label>Sitio web<input name="WebsiteURL" type="url" value={formulario.WebsiteURL} onChange={cambiarFormulario} required /></label>
            <label>Dirección entrega<input name="DeliveryAddressLine1" value={formulario.DeliveryAddressLine1} onChange={cambiarFormulario} required /></label>
            <label>Dirección entrega adicional<input name="DeliveryAddressLine2" value={formulario.DeliveryAddressLine2} onChange={cambiarFormulario} /></label>
            <label>Dirección postal<input name="PostalAddressLine1" value={formulario.PostalAddressLine1} onChange={cambiarFormulario} required /></label>
            <label>Dirección postal adicional<input name="PostalAddressLine2" value={formulario.PostalAddressLine2} onChange={cambiarFormulario} /></label>
            <label>Sucursal bancaria<input name="BankAccountBranch" value={formulario.BankAccountBranch} onChange={cambiarFormulario} required /></label>
            <label>Nombre de cuenta<input name="BankAccountName" value={formulario.BankAccountName} onChange={cambiarFormulario} required /></label>
            <label>Número de cuenta<input name="BankAccountNumber" value={formulario.BankAccountNumber} onChange={cambiarFormulario} required /></label>
            <label>Días de pago<input name="PaymentDays" type="number" min="0" value={formulario.PaymentDays} onChange={cambiarFormulario} required /></label>
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
  if (filtros.name) params.append('name', filtros.name);
  if (filtros.categoria) params.append('categoria', filtros.categoria);
  if (filtros.metodo) params.append('metodo', filtros.metodo);
  return params;
}
