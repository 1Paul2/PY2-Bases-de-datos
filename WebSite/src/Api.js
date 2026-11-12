import { useEffect, useState } from 'react';

export const API = import.meta.env.DEV ? '/api' : 'http://localhost:3001/api';
const CLAVE_SESION = 'wwi-sesion';

export function obtenerSesion() {
  try {
    return JSON.parse(sessionStorage.getItem(CLAVE_SESION));
  } catch {
    return null;
  }
}

export function cerrarSesion() {
  try { sessionStorage.removeItem(CLAVE_SESION); } catch { /* sin almacenamiento */ }
  Object.keys(cacheCatalogos).forEach(ruta => delete cacheCatalogos[ruta]);
  window.dispatchEvent(new Event('sesion-cerrada'));
}

export async function iniciarSesion(usuario, contrasena) {
  const r = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ usuario, contrasena })
  });
  const json = await r.json();
  if (!r.ok) throw new Error(json.error || 'No se pudo iniciar sesión');
  const sesion = { token: json.token, usuario: json.usuario };
  try { sessionStorage.setItem(CLAVE_SESION, JSON.stringify(sesion)); } catch { /* sin almacenamiento */ }
  return sesion;
}

async function llamar(ruta, opciones = {}) {
  const sesion = obtenerSesion();
  const headers = { ...opciones.headers };
  if (sesion?.token) headers.Authorization = `Bearer ${sesion.token}`;

  const r = await fetch(`${API}${ruta}`, { ...opciones, headers });
  const texto = await r.text();
  const json = texto ? JSON.parse(texto) : {};

  if (r.status === 401) {
    cerrarSesion();
    throw new Error(json.error || 'Inicie sesión para continuar.');
  }
  if (!r.ok || json.error) {
    throw new Error(json.error || 'La operación no pudo completarse');
  }
  return json;
}

export function pedir(ruta) {
  return llamar(ruta);
}

export function enviar(ruta, metodo, datos) {
  return llamar(ruta, {
    method: metodo,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(datos)
  });
}

const cacheCatalogos = {};

export function cargarCatalogo(ruta) {
  if (!cacheCatalogos[ruta]) {
    cacheCatalogos[ruta] = pedir(ruta)
      .then(res => res.data)
      .catch(err => {
        delete cacheCatalogos[ruta];
        throw err;
      });
  }
  return cacheCatalogos[ruta];
}

export function useCatalogo(ruta) {
  const [datos, setDatos] = useState([]);

  useEffect(() => {
    let activo = true;
    cargarCatalogo(ruta)
      .then(lista => { if (activo) setDatos(lista); })
      .catch(() => { if (activo) setDatos([]); });
    return () => { activo = false; };
  }, [ruta]);

  return datos;
}
