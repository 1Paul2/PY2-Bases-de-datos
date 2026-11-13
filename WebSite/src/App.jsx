import { useEffect, useState } from 'react';
import { cerrarSesion, obtenerSesion } from './Api';
import { modulosPermitidos, NOMBRE_SUCURSAL } from './permisos';
import Login from './pages/Login';
import AvisoNodos from './components/AvisoNodos';
import Inicio from './pages/Inicio';
import Clientes from './pages/Clientes';
import Proveedores from './pages/Proveedores';
import Productos from './pages/Productos';
import Ventas from './pages/Ventas';
import Estadisticas from './pages/Estadisticas';

import './App.css';

const modulosNav = {
  inicio: "Inicio",
  clientes: "Clientes",
  proveedores: "Proveedores",
  productos: "Productos",
  ventas: "Ventas",
  estadisticas: "Estadísticas",
};

export default function App() {
  const [modulo, setModulo] = useState('inicio');
  const [sesion, setSesion] = useState(obtenerSesion);

  useEffect(() => {
    const alCerrar = () => { setSesion(null); setModulo('inicio'); };
    window.addEventListener('sesion-cerrada', alCerrar);
    return () => window.removeEventListener('sesion-cerrada', alCerrar);
  }, []);

  if (!sesion) {
    return <Login onEntrar={setSesion} />;
  }

  const { FullName, Rol, Sucursal } = sesion.usuario;
  const permitidos = modulosPermitidos();
  const salir = (
    <div className="barra-usuario">
      <span>
        <strong>{FullName}</strong> · {Rol}{Sucursal ? ` · ${NOMBRE_SUCURSAL[Sucursal]}` : ''}
      </span>
      <button type="button" onClick={cerrarSesion}>Cerrar sesión</button>
    </div>
  );
  const barra = <>{salir}<AvisoNodos /></>;

  if (modulo === 'inicio' || !permitidos.includes(modulo)) {
    return <>{barra}<Inicio onNavegar={setModulo} /></>;
  }
  return (
    <div className="App">
      {barra}
      <header className="App-header">
        <div
          className="cabecera-marca"
          onClick={() => setModulo('inicio')}
          title="Ir al inicio"
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              setModulo('inicio');
            }
          }}
        >
          <p className="eyebrow">Wide World Importers</p>
          <h1>Sistema de Gestión</h1>
        </div>

        <nav className="menu" aria-label="Módulos">
          {Object.entries(modulosNav).filter(([key]) => key === 'inicio' || permitidos.includes(key)).map(([key, name]) => (
            <button
              key={key}
              type="button"
              className={modulo === key ? 'active' : ''}
              onClick={() => setModulo(key)}
              aria-current={modulo === key ? 'page' : undefined}
            >
              {name}
            </button>
          ))}
        </nav>
      </header>

      <main className="App-content" key={modulo}>
        {modulo === 'clientes' && <Clientes />}
        {modulo === 'proveedores' && <Proveedores />}
        {modulo === 'productos' && <Productos />}
        {modulo === 'ventas' && <Ventas />}
        {modulo === 'estadisticas' && <Estadisticas />}
      </main>
    </div>
  );
}