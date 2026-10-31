import { useEffect, useMemo, useState } from 'react';
import { pedir, useCatalogo } from '../Api';
import Filtros from '../components/Filtros';
import Tabla from '../components/Tabla';
import Paginacion from '../components/Paginacion';

// Los filtros de año, mes y categorías son listas cargadas de la base,
// así el usuario solo puede elegir valores que existen.
function crearReportes({ aniosVentas, aniosCompras, aniosInventario, meses, grupos, categoriasCliente }) {
  const anio = (opciones, etiqueta = 'Año') => ({ nombre: 'anio', etiqueta, opciones });
  const mes = { nombre: 'mes', etiqueta: 'Mes', opciones: meses.map(m => ({ valor: m.Mes, texto: m.Nombre })) };
  const nombresGrupos = grupos.map(g => ({ valor: g.StockGroupName, texto: g.StockGroupName }));
  const idsGrupos = grupos.map(g => ({ valor: g.StockGroupID, texto: g.StockGroupName }));

  return {
    proveedor: {
      titulo: 'Estadística de proveedores',
      endpoint: '/estadisticas/proveedor',
      campos: [
        { nombre: 'proveedor', etiqueta: 'Proveedor', tipo: 'text' },
        { nombre: 'categoria', etiqueta: 'Categoría', tipo: 'text' }
      ]
    },

    cliente: {
      titulo: 'Estadística de clientes',
      endpoint: '/estadisticas/cliente',
      campos: [
        { nombre: 'cliente', etiqueta: 'Cliente', tipo: 'text' },
        { nombre: 'categoria', etiqueta: 'Categoría', tipo: 'text' }
      ]
    },

    productos: {
      titulo: 'Top 5 productos por ganancia',
      endpoint: '/estadisticas/top-productos',
      campos: [anio(aniosVentas, 'Año inicial'), { nombre: 'anioFin', etiqueta: 'Año final', opciones: aniosVentas }]
    },

    topClientes: {
      titulo: 'Top 5 clientes por facturas',
      endpoint: '/estadisticas/top-clientes',
      campos: [
        { nombre: 'anioInicio', etiqueta: 'Año inicial', opciones: aniosVentas },
        { nombre: 'anioFin', etiqueta: 'Año final', opciones: aniosVentas }
      ]
    },

    topProveedores: {
      titulo: 'Top 5 proveedores por órdenes',
      endpoint: '/estadisticas/top-proveedores',
      campos: [
        { nombre: 'anioInicio', etiqueta: 'Año inicial', opciones: aniosCompras },
        { nombre: 'anioFin', etiqueta: 'Año final', opciones: aniosCompras }
      ]
    },

    matriz: {
      titulo: 'Matriz de ventas por categoría y año',
      endpoint: '/estadisticas/matriz',
      campos: []
    },

    // Categoría y subcategoría son grupos de producto: el producto debe pertenecer a los dos
    seguimientoClientes: {
      titulo: 'Seguimiento de compras a clientes',
      endpoint: '/estadisticas/seguimiento-clientes',
      campos: [
        { nombre: 'cliente', etiqueta: 'Cliente', tipo: 'text' },
        anio(aniosVentas),
        mes,
        { nombre: 'categoriaId', etiqueta: 'Categoría', opciones: idsGrupos },
        { nombre: 'subcategoriaId', etiqueta: 'Subcategoría', opciones: idsGrupos }
      ]
    },

    seguimientoProveedores: {
      titulo: 'Seguimiento de compras a proveedores',
      endpoint: '/estadisticas/seguimiento-proveedores',
      campos: [
        { nombre: 'proveedor', etiqueta: 'Proveedor', tipo: 'text' },
        anio(aniosCompras),
        mes,
        { nombre: 'categoriaId', etiqueta: 'Categoría', opciones: idsGrupos },
        { nombre: 'subcategoriaId', etiqueta: 'Subcategoría', opciones: idsGrupos }
      ]
    },

    rotacion: {
      titulo: 'Rotación de inventario',
      endpoint: '/estadisticas/rotacion',
      campos: [
        anio(aniosInventario),
        { nombre: 'categoria', etiqueta: 'Categoría', opciones: nombresGrupos },
        { nombre: 'proveedor', etiqueta: 'Proveedor', tipo: 'text' }
      ]
    },

    envioFavorito: {
      titulo: 'Método de envío favorito',
      endpoint: '/estadisticas/envio-favorito',
      campos: [
        anio(aniosVentas),
        mes,
        {
          nombre: 'catCliente',
          etiqueta: 'Categoría cliente',
          opciones: categoriasCliente.map(c => ({ valor: c.CustomerCategoryName, texto: c.CustomerCategoryName }))
        },
        { nombre: 'catProducto', etiqueta: 'Categoría producto', opciones: nombresGrupos },
        { nombre: 'producto', etiqueta: 'Producto', tipo: 'text' }
      ]
    }
  };
}

const aOpcionesAnio = filas => filas.map(f => ({ valor: f.Anio, texto: String(f.Anio) }));

// Todos los filtros que usa algún reporte, para que los campos siempre estén controlados
const filtrosIniciales = {
  proveedor: '',
  cliente: '',
  categoria: '',
  anio: '',
  anioInicio: '',
  anioFin: '',
  mes: '',
  catCliente: '',
  catProducto: '',
  producto: '',
  categoriaId: '',
  subcategoriaId: ''
};

const POR_PAGINA = 10;

function tituloColumna(clave) {
  return clave
    .replaceAll('_', ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2');
}

export default function Estadisticas() {
  const [pagina, setPagina] = useState(1);
  const [reporte, setReporte] = useState('proveedor');
  const [filtros, setFiltros] = useState(filtrosIniciales);
  const [filas, setFilas] = useState([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState('');

  const aniosVentas = useCatalogo('/catalogos/anios?tipo=ventas');
  const aniosCompras = useCatalogo('/catalogos/anios?tipo=compras');
  const aniosInventario = useCatalogo('/catalogos/anios?tipo=inventario');
  const meses = useCatalogo('/catalogos/meses');
  const grupos = useCatalogo('/catalogos/grupos-productos');
  const categoriasCliente = useCatalogo('/catalogos/categorias-clientes');

  const reportes = useMemo(() => crearReportes({
    aniosVentas: aOpcionesAnio(aniosVentas),
    aniosCompras: aOpcionesAnio(aniosCompras),
    aniosInventario: aOpcionesAnio(aniosInventario),
    meses,
    grupos,
    categoriasCliente
  }), [aniosVentas, aniosCompras, aniosInventario, meses, grupos, categoriasCliente]);

  const configuracion = reportes[reporte];

  useEffect(() => {
    // La paginación la hace el SP; solo se envía la página que se quiere ver
    const params = new URLSearchParams({ pagina, porPagina: POR_PAGINA });

    configuracion.campos.forEach(campo => {
      const valor = filtros[campo.nombre];

      if (valor) {
        params.append(campo.nombre, valor);
      }
    });

    pedir(`${configuracion.endpoint}?${params}`)
      .then(res => {
        setFilas(res.data);
        setTotal(res.total);
        setError('');
      })
      .catch(err => {
        setFilas([]);
        setTotal(0);
        setError(err.message);
      });
  }, [reporte, filtros, pagina, configuracion.endpoint]); // eslint-disable-line react-hooks/exhaustive-deps

  const cambiarReporte = evento => {
    setReporte(evento.target.value);
    setFiltros(filtrosIniciales);
    setFilas([]);
    setPagina(1);
  };

  const cambiarFiltro = (nombre, valor) => {
    setFiltros(anterior => ({
      ...anterior,
      [nombre]: valor
    }));
    setPagina(1);
  };

  const restaurarFiltros = () => {
    setFiltros(filtrosIniciales);
    setPagina(1);
  };

  const columnas = filas.length > 0
    ? Object.keys(filas[0]).map(clave => ({
        clave,
        titulo: tituloColumna(clave)
      }))
    : [];


  return (
    <section className="modulo">
      <div className="modulo-header">
        <div className="modulo-header-texto">
          <p className="modulo-eyebrow">Reportes y Métricas</p>
          <h1 className="modulo-titulo">Estadísticas</h1>
          <span className="modulo-contador">
            {total} {total === 1 ? 'resultado' : 'resultados'}
          </span>
        </div>
      </div>

      <label className="selector-reporte">
        Reporte
        <select value={reporte} onChange={cambiarReporte}>
          {Object.entries(reportes).map(([clave, valor]) => (
            <option key={clave} value={clave}>
              {valor.titulo}
            </option>
          ))}
        </select>
      </label>

      <div className="barra-filtros">
        <Filtros campos={configuracion.campos} valores={filtros} onCambio={cambiarFiltro} />
        <button type="button" className="btn btn-fantasma" onClick={restaurarFiltros}>
          Restaurar filtros
        </button>
      </div>

      {error && <p className="mensaje mensaje-error">{error}</p>}

      <div className="tabla-wrapper">
        <Tabla columnas={columnas} filas={filas} />
      </div>

      <Paginacion
        total={total}
        pagina={pagina}
        porPagina={POR_PAGINA}
        onCambio={setPagina}
      />
    </section>
  );
}