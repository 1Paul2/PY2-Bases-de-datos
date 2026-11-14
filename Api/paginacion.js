// La paginación y el conteo de resultados los hace SQL Server (OFFSET/FETCH y COUNT(*) OVER()).
// Aquí solo se leen los parámetros y se arma la respuesta.

function leerPagina(query) {
  const pagina = Math.max(Number.parseInt(query.pagina, 10) || 1, 1);
  const porPagina = Math.min(Math.max(Number.parseInt(query.porPagina, 10) || 10, 1), 100);
  return { pagina, porPagina };
}

// Cada fila trae TotalRegistros (calculado por el SP); se saca a la respuesta y no se repite por fila
function respuestaPaginada(recordset, pagina, porPagina) {
  const total = recordset.length > 0 ? recordset[0].TotalRegistros : 0;
  const data = recordset.map(({ TotalRegistros, ...fila }) => fila);
  return { total, pagina, porPagina, data };
}

module.exports = { leerPagina, respuestaPaginada };
