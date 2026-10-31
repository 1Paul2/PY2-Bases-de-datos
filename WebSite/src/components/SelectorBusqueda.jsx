import { useEffect, useRef, useState } from 'react';
import { pedir } from '../Api';

/*
  Campo de texto con búsqueda: el usuario escribe parte del nombre y elige de la lista.
  Así no hay que escribir IDs a mano; el formulario guarda el ID de la opción elegida.

  Props:
    etiqueta     texto del label
    ruta         ruta de la API que busca (recibe ?criterio=)
    extra        parámetros fijos adicionales, p. ej. { soloVendedores: 1 }
    campoId      columna con el ID en cada fila
    campoTexto   columna con el texto a mostrar
    valor        ID seleccionado actualmente
    textoInicial texto del valor actual (al editar)
    onCambio     recibe la fila elegida, o null si se borra
    requerido    si es obligatorio
    ancho        ocupa las dos columnas del formulario
    onTextoLibre si se indica, permite escribir un nombre que no está en la lista
                 (p. ej. un contacto nuevo); recibe el texto escrito o '' al elegir una opción
*/
export default function SelectorBusqueda({
  etiqueta, ruta, extra = {}, campoId, campoTexto, valor, textoInicial = '',
  onCambio, requerido = false, ancho = false, placeholder = 'Escriba para buscar...', onTextoLibre
}) {
  const [texto, setTexto] = useState(textoInicial);
  const [opciones, setOpciones] = useState([]);
  const [abierto, setAbierto] = useState(false);
  const [cargando, setCargando] = useState(false);
  const [resaltado, setResaltado] = useState(0);
  const extraTexto = JSON.stringify(extra);
  const inputRef = useRef(null);

  // Si cambia el valor desde afuera (p. ej. se abre otro registro), se actualiza el texto
  useEffect(() => {
    setTexto(textoInicial ?? '');
  }, [textoInicial]);

  // Busca 300 ms después de que el usuario deja de escribir
  useEffect(() => {
    if (!abierto) return undefined;
    const temporizador = setTimeout(async () => {
      setCargando(true);
      try {
        const params = new URLSearchParams({ ...JSON.parse(extraTexto), criterio: texto.trim() });
        const res = await pedir(`${ruta}?${params}`);
        setOpciones(res.data);
        setResaltado(0);
      } catch {
        setOpciones([]);
      } finally {
        setCargando(false);
      }
    }, 300);
    return () => clearTimeout(temporizador);
  }, [texto, abierto, ruta, extraTexto]);

  // Valida con el mensaje nativo del navegador que se haya elegido una opción de la lista
  useEffect(() => {
    if (!inputRef.current) return;
    const sinValor = valor === '' || valor === null || valor === undefined;
    const textoNuevo = Boolean(onTextoLibre) && texto.trim() !== '';
    const falta = requerido && sinValor && !textoNuevo;
    const mensaje = onTextoLibre
      ? `Seleccione ${etiqueta.toLowerCase()} de la lista o escriba un nombre nuevo`
      : `Seleccione ${etiqueta.toLowerCase()} de la lista`;
    inputRef.current.setCustomValidity(falta ? mensaje : '');
  }, [valor, requerido, etiqueta, texto, onTextoLibre]);

  const elegir = opcion => {
    setTexto(opcion[campoTexto]);
    setAbierto(false);
    onCambio(opcion);
    if (onTextoLibre) onTextoLibre('');
  };

  const escribir = evento => {
    setTexto(evento.target.value);
    setAbierto(true);
    if (valor !== '' && valor !== null && valor !== undefined) onCambio(null);
    if (onTextoLibre) onTextoLibre(evento.target.value);
  };

  const teclas = evento => {
    if (!abierto || opciones.length === 0) return;
    if (evento.key === 'ArrowDown') {
      evento.preventDefault();
      setResaltado(i => Math.min(i + 1, opciones.length - 1));
    } else if (evento.key === 'ArrowUp') {
      evento.preventDefault();
      setResaltado(i => Math.max(i - 1, 0));
    } else if (evento.key === 'Enter') {
      evento.preventDefault();
      elegir(opciones[resaltado]);
    } else if (evento.key === 'Escape') {
      setAbierto(false);
    }
  };

  return (
    <label className={`selector-busqueda${ancho ? ' formulario-ancho' : ''}`}>
      {etiqueta}
      <div className="selector-busqueda-control">
        <input
          ref={inputRef}
          type="text"
          value={texto}
          placeholder={placeholder}
          autoComplete="off"
          required={requerido}
          onChange={escribir}
          onFocus={() => setAbierto(true)}
          onBlur={() => setAbierto(false)}
          onKeyDown={teclas}
        />
        {abierto && (
          <ul className="selector-busqueda-lista" role="listbox">
            {cargando && opciones.length === 0 && <li className="selector-busqueda-info">Buscando...</li>}
            {!cargando && opciones.length === 0 && !(onTextoLibre && texto.trim()) && (
              <li className="selector-busqueda-info">Sin resultados</li>
            )}
            {onTextoLibre && texto.trim() && !opciones.some(o => o[campoTexto] === texto.trim()) && (
              <li className="selector-busqueda-info">Si no lo elige de la lista, se creará «{texto.trim()}» como persona nueva</li>
            )}
            {opciones.map((opcion, i) => (
              <li
                key={opcion[campoId]}
                role="option"
                aria-selected={opcion[campoId] === valor}
                className={i === resaltado ? 'resaltado' : ''}
                onMouseDown={evento => { evento.preventDefault(); elegir(opcion); }}
                onMouseEnter={() => setResaltado(i)}
              >
                {opcion[campoTexto]}
              </li>
            ))}
          </ul>
        )}
      </div>
    </label>
  );
}
