import { useEffect, useState } from 'react';

// Ventana para confirmar un borrado. onConfirmar debe lanzar un error si el borrado falla;
// el mensaje se muestra dentro de la misma ventana.
export default function ConfirmarEliminar({ tipo, nombre, onConfirmar, onCancelar }) {
  const [eliminando, setEliminando] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const alPresionar = e => { if (e.key === 'Escape' && !eliminando) onCancelar(); };
    window.addEventListener('keydown', alPresionar);
    return () => window.removeEventListener('keydown', alPresionar);
  }, [eliminando, onCancelar]);

  const confirmar = async () => {
    setEliminando(true);
    setError('');
    try {
      await onConfirmar();
    } catch (err) {
      setError(err.message);
      setEliminando(false);
    }
  };

  return (
    <div className="fondo" onClick={() => !eliminando && onCancelar()}>
      <div
        className="ventana ventana-confirmar"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="confirmar-titulo"
        aria-describedby="confirmar-texto"
        onClick={e => e.stopPropagation()}
      >
        <div className="confirmar-icono" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 6h18" />
            <path d="M8 6V4h8v2" />
            <path d="M19 6l-1 14H6L5 6" />
            <path d="M10 11v6M14 11v6" />
          </svg>
        </div>

        <h3 id="confirmar-titulo">¿Eliminar {tipo}?</h3>
        <p id="confirmar-texto">
          Se eliminará <strong>{nombre}</strong>. Esta acción no se puede deshacer.
        </p>

        {error && <p className="mensaje mensaje-error confirmar-error">{error}</p>}

        <div className="confirmar-acciones">
          <button type="button" className="btn btn-fantasma" onClick={onCancelar} disabled={eliminando} autoFocus>
            Cancelar
          </button>
          <button type="button" className="btn btn-eliminar" onClick={confirmar} disabled={eliminando}>
            {eliminando ? 'Eliminando…' : 'Sí, eliminar'}
          </button>
        </div>
      </div>
    </div>
  );
}
