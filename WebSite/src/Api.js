import { useEffect, useState } from 'react';

// En desarrollo se usa el proxy de Vite (/api → localhost:3001); en la versión publicada, la API local
export const API = import.meta.env.DEV ? '/api' : 'http://localhost:3001/api';

export async function pedir(ruta) {
  const r = await fetch(`${API}${ruta}`);
  const json = await r.json();
  if (json.error) throw new Error(json.error);
  return json;
}

export async function enviar(ruta, metodo, datos) {
  const r = await fetch(`${API}${ruta}`, {
    method: metodo,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(datos)
  });

  const texto = await r.text();
  const json = texto ? JSON.parse(texto) : {};

  if (!r.ok || json.error) {
    throw new Error(json.error || 'La operación no pudo completarse');
  }

  return json;
}

// Carga una lista de catálogo (categorías, métodos de entrega, colores...) una sola vez por ruta
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
