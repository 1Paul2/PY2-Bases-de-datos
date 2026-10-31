const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');
const { leerPagina, respuestaPaginada } = require('../paginacion');

// Definidores de parámetros
const texto = (nombre, query, defecto = null) =>
  ({ nombre, query, defecto, tipo: sql.VarChar(100) });
const entero = (nombre, query) =>
  ({ nombre, query, defecto: null, tipo: sql.Int, convertir: parseInt });
const bit = (nombre, query, defecto) =>
  ({ nombre, query, defecto, tipo: sql.Bit,
     convertir: v => (v === 1 || v === '1' || v === 'true') ? 1 : 0 });

// Crea una ruta GET que ejecuta un SP con los parámetros indicados
function crearRuta(ruta, sp, parametros = []) {
  router.get(ruta, async (req, res) => {
    try {
      const { pagina, porPagina } = leerPagina(req.query);
      const pool = await poolPromise;
      const request = pool.request()
        .input('Pagina', sql.Int, pagina)
        .input('PorPagina', sql.Int, porPagina);

      for (const p of parametros) {
        const raw = req.query[p.query];
        let valor = (raw === undefined || raw === '') ? p.defecto : raw;
        if (valor !== null && p.convertir) valor = p.convertir(valor);
        request.input(p.nombre, p.tipo, valor);
      }

      const result = await request.execute(sp);
      res.json(respuestaPaginada(result.recordset, pagina, porPagina));
    } catch (err) {
      // Los THROW de los SPs (50001, 50002...) son errores del usuario, no del servidor
      const status = err.number >= 50000 ? 400 : 500;
      res.status(status).json({ error: err.message });
    }
  });
}

// #1 y #2: sin valor por defecto en el SP, así que '' en vez de null
crearRuta('/proveedor', 'sp_estadistica_proveedor',
  [texto('proveedor', 'proveedor', ''), texto('categoria', 'categoria', '')]);

crearRuta('/cliente', 'sp_estadistica_cliente',
  [texto('NomCliente', 'cliente', ''), texto('categoria', 'categoria', '')]);

// #3 a #5: tops
crearRuta('/top-productos', 'sp_top5_productos_ganancia',
  [entero('anio', 'anio'), entero('anioFin', 'anioFin')]);

crearRuta('/top-clientes', 'sp_top5_clientes_facturas',
  [entero('anioInicio', 'anioInicio'), entero('anioFin', 'anioFin')]);

crearRuta('/top-proveedores', 'sp_top5_proveedores_ordenes',
  [entero('anioInicio', 'anioInicio'), entero('anioFin', 'anioFin')]);

// #6: matriz, sin parámetros
crearRuta('/matriz', 'sp_matriz_ventas_categoria_anio');

// #7 y #8: seguimiento mensual
// Categoría y subcategoría son grupos de producto (por ID); el producto debe pertenecer a ambos
const seguimiento = [
  entero('anio', 'anio'), entero('mes', 'mes'),
  texto('categoria', 'categoria'),
  entero('categoriaId', 'categoriaId'), entero('subcategoriaId', 'subcategoriaId')
];
crearRuta('/seguimiento-clientes', 'sp_seguimiento_compras_cliente',
  [...seguimiento, texto('cliente', 'cliente')]);
crearRuta('/seguimiento-proveedores', 'sp_seguimiento_compras_proveedor',
  [...seguimiento, texto('proveedor', 'proveedor')]);

// #9: rotación de inventario
crearRuta('/rotacion', 'sp_rotacion_inventario',
  [entero('anio', 'anio'), texto('categoria', 'categoria'), texto('proveedor', 'proveedor')]);

// #10: método de envío favorito
crearRuta('/envio-favorito', 'sp_metodo_envio_favorito', [
  entero('anio', 'anio'), entero('mes', 'mes'),
  texto('catCliente', 'catCliente'), texto('catProducto', 'catProducto'),
  texto('producto', 'producto'), bit('soloFavorito', 'soloFavorito', 1)
]);

module.exports = router;