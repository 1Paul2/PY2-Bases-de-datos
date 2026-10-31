import { useState } from 'react';
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

  if (modulo === 'inicio') {
    return <Inicio onNavegar={setModulo} />;
  }
  return (
    <div className="App">
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
          {Object.entries(modulosNav).map(([key, name]) => (
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