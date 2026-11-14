import { useState } from 'react';

export default function Paginacion({
  total,
  pagina,
  porPagina = 10,
  onCambio,
}) {
  const [salto, setSalto] = useState('');
  const totalPaginas = Math.ceil(total / porPagina);

  if (total === 0) return null;

  const inicio = (pagina - 1) * porPagina + 1;
  const fin = Math.min(pagina * porPagina, total);

  const irA = e => {
    e.preventDefault();
    const n = Number(salto);
    if (Number.isInteger(n) && n >= 1 && n <= totalPaginas) {
      onCambio(n);
      setSalto('');
    }
  };

  return (
    <div className="paginacion">
      <span className="paginacion-rango" aria-live="polite">
        Mostrando <strong>{inicio}</strong>–<strong>{fin}</strong> de{' '}
        <strong>{total}</strong>
      </span>

      <div className="paginacion-controles">
        <button
          type="button"
          disabled={pagina <= 1}
          onClick={() => onCambio(1)}
          aria-label="Primera página"
          title="Primera página"
        >
          «
        </button>

        <button
          type="button"
          disabled={pagina <= 1}
          onClick={() => onCambio(pagina - 1)}
        >
          Anterior
        </button>

        <form className="paginacion-salto" onSubmit={irA}>
          <input
            type="number"
            min="1"
            max={totalPaginas}
            value={salto}
            onChange={e => setSalto(e.target.value)}
            placeholder={String(pagina)}
            aria-label="Ir a página"
          />
          <span>/ {totalPaginas}</span>
        </form>

        <button
          type="button"
          disabled={pagina >= totalPaginas}
          onClick={() => onCambio(pagina + 1)}
        >
          Siguiente
        </button>

        <button
          type="button"
          disabled={pagina >= totalPaginas}
          onClick={() => onCambio(totalPaginas)}
          aria-label="Última página"
          title="Última página"
        >
          »
        </button>
      </div>
    </div>
  );
}