import React from 'react';

/* ============================================================
   ICONOS SVG 
   ============================================================ */

const IconoClientes = () => (
  <svg
    width="26" height="26" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
    <circle cx="9" cy="7" r="4" />
    <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
  </svg>
);

const IconoProveedores = () => (
  <svg
    width="26" height="26" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M1 3h15v13H1z" />
    <path d="M16 8h4l3 3v5h-7V8z" />
    <circle cx="5.5" cy="18.5" r="2.5" />
    <circle cx="18.5" cy="18.5" r="2.5" />
  </svg>
);

const IconoProductos = () => (
  <svg
    width="26" height="26" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
    <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
    <line x1="12" y1="22.08" x2="12" y2="12" />
  </svg>
);

const IconoVentas = () => (
  <svg
    width="26" height="26" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round"
    aria-hidden="true"
  >
    <line x1="12" y1="1" x2="12" y2="23" />
    <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
  </svg>
);

const IconoEstadisticas = () => (
  <svg
    width="26" height="26" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round"
    aria-hidden="true"
  >
    <line x1="18" y1="20" x2="18" y2="10" />
    <line x1="12" y1="20" x2="12" y2="4" />
    <line x1="6" y1="20" x2="6" y2="14" />
  </svg>
);

/* ============================================================
   DATOS DE LOS MÓDULOS
   ============================================================ */

const modulos = [
  {
    key: 'clientes',
    subtitulo: 'Gestión Comercial',
    titulo: 'CLIENTES',
    descripcion:
      'Consulta, registro y edición de clientes con filtros acumulativos, categorización y mapa de localización.',
    icono: <IconoClientes />,
    claseExtra: '',
  },
  {
    key: 'proveedores',
    subtitulo: 'Compras y Suministro',
    titulo: 'PROVEEDORES',
    descripcion:
      'Directorio de proveedores, cuentas bancarias asociadas, plazos de pago y logística de entrega.',
    icono: <IconoProveedores />,
    claseExtra: '',
  },
  {
    key: 'productos',
    subtitulo: 'Inventario y Almacén',
    titulo: 'PRODUCTOS',
    descripcion:
      'Catálogo de artículos en stock, control de existencias disponibles, empaquetado, impuestos y precios.',
    icono: <IconoProductos />,
    claseExtra: '',
  },
  {
    key: 'ventas',
    subtitulo: 'Facturación y Pedidos',
    titulo: 'VENTAS',
    descripcion:
      'Registro y gestión de ventas, encabezados de factura, órdenes de compra y detalles de líneas.',
    icono: <IconoVentas />,
    claseExtra: 'tarjeta-ventas',
  },
  {
    key: 'estadisticas',
    subtitulo: 'Reportes y Métricas',
    titulo: 'ESTADÍSTICAS',
    descripcion:
      'Análisis con ROLLUP, rankings Top 5 con dense_rank, matriz por categoría y año, y rotación de inventarios.',
    icono: <IconoEstadisticas />,
    claseExtra: 'tarjeta-estadisticas',
  },
];

/* ============================================================
   COMPONENTE PRINCIPAL
   ============================================================ */

export default function Inicio({ onNavegar }) {
  return (
    <div className="pagina-inicio">
      <div className="marco-principal">

        {/* ---------- Cabecera institucional ---------- */}
        <header className="cabecera-sistema">
          <p className="subtitulo-institucional">Wide World Importers</p>
          <h1 className="titulo-sistema">
            Sistema de Gestión <span className="acento">De Datos</span>
          </h1>
          <p className="descripcion-sistema">
            Seleccione el módulo administrativo para consultar registros,
            aplicar filtros o gestionar operaciones.
          </p>
        </header>

        {/* ---------- Rejilla de módulos ---------- */}
        <div className="contenedor-modulos">
          <div className="rejilla-modulos">
            {modulos.map((m) => (
              <button
                key={m.key}
                type="button"
                className={`tarjeta-modulo ${m.claseExtra}`.trim()}
                onClick={() => onNavegar?.(m.key)}
                aria-label={`Ingresar al módulo ${m.titulo}`}
              >
                <div className="tarjeta-cuerpo">
                  <span className="tarjeta-icono">{m.icono}</span>
                  <span className="tarjeta-subtitulo">{m.subtitulo}</span>
                  <h2 className="tarjeta-titulo">{m.titulo}</h2>
                  <p className="tarjeta-descripcion">{m.descripcion}</p>
                </div>

                <div className="tarjeta-pie">
                  <span>Ingresar</span>
                  <span className="flecha-accion" aria-hidden="true">→</span>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* ---------- Pie del sistema ---------- */}
        <footer className="pie-sistema">
          <div className="info-tecnologica">
            Wide World Importers
          </div>
        </footer>

      </div>
    </div>
  );
}