import { obtenerSesion } from './Api';

export const NOMBRE_SUCURSAL = { SJ: 'San José', LI: 'Limón' };

// Misma tabla que el middleware de la API (Api/roles.js) y la sección 7 del README
const MODULOS = {
  Administrador: ['clientes', 'proveedores', 'productos', 'ventas'],
  Corporativo: ['clientes', 'proveedores', 'productos', 'estadisticas']
};

const EDITA = {
  Administrador: ['productos', 'ventas'],
  Corporativo: ['clientes', 'proveedores']
};

function rolActual() {
  return obtenerSesion()?.usuario?.Rol;
}

export function modulosPermitidos() {
  return MODULOS[rolActual()] ?? [];
}

export function puedeEditar(modulo) {
  return (EDITA[rolActual()] ?? []).includes(modulo);
}
