export default function Filtros({ campos, valores, onCambio }) {
  return (
    <div className="filtros">
      {campos.map(c => {
        const id = `filtro-${c.nombre}`;
        const valor = valores[c.nombre] || '';

        return (
          <label key={c.nombre} htmlFor={id}>
            {c.etiqueta}
            <div className="filtro-control">
              {c.opciones ? (
                <select
                  id={id}
                  value={valor}
                  onChange={e => onCambio(c.nombre, e.target.value)}
                >
                  <option value="">Todos</option>
                  {c.opciones.map(o => (
                    <option key={o.valor} value={o.valor}>
                      {o.texto}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  id={id}
                  type={c.tipo || 'text'}
                  value={valor}
                  placeholder={c.placeholder || ''}
                  autoComplete="off"
                  onChange={e => onCambio(c.nombre, e.target.value)}
                />
              )}

              {valor && (
                <button
                  type="button"
                  className="filtro-limpiar"
                  onClick={() => onCambio(c.nombre, '')}
                  aria-label={`Limpiar ${c.etiqueta}`}
                  title="Limpiar"
                >
                  ✕
                </button>
              )}
            </div>
          </label>
        );
      })}
    </div>
  );
}