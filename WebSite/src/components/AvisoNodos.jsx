import { useEffect, useState } from 'react';
import { obtenerSesion, pedir } from '../Api';

const NOMBRE_NODO = { corporativo: 'El corporativo', sanjose: 'San José', limon: 'Limón' };
const INTERVALO_MS = 20000;

function mensajes(caidos, usuario) {
  const lista = [];
  if (usuario.Rol === 'Administrador') {
    if (caidos.includes(usuario.nodo)) {
      lista.push(`${NOMBRE_NODO[usuario.nodo]} no responde: no se pueden consultar ni registrar datos hasta que vuelva.`);
    }
    if (caidos.includes('corporativo')) {
      lista.push('El corporativo no responde: los datos de contacto de clientes y proveedores no están disponibles. '
        + 'Ventas y productos siguen funcionando; los cambios de productos llegarán a la otra sucursal cuando vuelva.');
    }
  } else {
    if (caidos.includes('corporativo')) {
      lista.push('El corporativo no responde: las estadísticas no están disponibles hasta que vuelva.');
    }
    for (const sucursal of ['sanjose', 'limon']) {
      if (caidos.includes(sucursal)) {
        lista.push(`${NOMBRE_NODO[sucursal]} no responde: sus estadísticas muestran los datos hasta la última sincronización.`);
      }
    }
  }
  return lista;
}

export default function AvisoNodos() {
  const [caidos, setCaidos] = useState([]);

  useEffect(() => {
    let activo = true;
    const revisar = () => pedir('/estado-nodos')
      .then(res => { if (activo) setCaidos(res.nodos.filter(n => !n.responde).map(n => n.nodo)); })
      .catch(() => {});

    revisar();
    const temporizador = setInterval(revisar, INTERVALO_MS);
    window.addEventListener('nodo-caido', revisar);
    return () => {
      activo = false;
      clearInterval(temporizador);
      window.removeEventListener('nodo-caido', revisar);
    };
  }, []);

  const usuario = obtenerSesion()?.usuario;
  const lista = usuario ? mensajes(caidos, usuario) : [];
  if (lista.length === 0) return null;

  return (
    <div className="aviso-nodos" role="alert">
      {lista.map(texto => <p key={texto}>{texto}</p>)}
    </div>
  );
}
