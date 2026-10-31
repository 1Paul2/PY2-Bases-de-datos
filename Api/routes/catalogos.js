const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');

// Catálogos para las listas de selección y los buscadores de los formularios.
// Cada ruta llama a un único procedimiento almacenado y devuelve el resultado tal cual.

function limite(valor) {
  const n = Number.parseInt(valor, 10);
  if (!Number.isInteger(n) || n < 1) return 20;
  return Math.min(n, 50);
}

async function responder(res, ejecutar) {
  try {
    const pool = await poolPromise;
    const result = await ejecutar(pool.request());
    res.json({ total: result.recordset.length, data: result.recordset });
  } catch (err) {
    const status = err.number >= 50000 ? 400 : 500;
    res.status(status).json({ error: err.message });
  }
}

// Listas completas (son pequeñas)
const listas = {
  '/categorias-clientes': 'SP_GetCustomerCategories',
  '/categorias-proveedores': 'SP_GetSupplierCategories',
  '/grupos-compra': 'SP_GetBuyingGroups',
  '/metodos-entrega': 'SP_GetDeliveryMethods',
  '/grupos-productos': 'SP_GetStockGroups',
  '/colores': 'SP_GetColors',
  '/tipos-paquete': 'SP_GetPackageTypes',
  '/proveedores': 'SP_GetSuppliersCatalog'
};

// Opciones para los filtros: solo las que tienen registros asociados
const filtros = {
  '/filtros/categorias-clientes': ['SP_GetCustomerCategoriesInUse'],
  '/filtros/categorias-proveedores': ['SP_GetSupplierCategoriesInUse'],
  '/filtros/metodos-clientes': ['SP_GetDeliveryMethodsInUse', 'clientes'],
  '/filtros/metodos-proveedores': ['SP_GetDeliveryMethodsInUse', 'proveedores'],
  '/filtros/grupos-productos': ['SP_GetStockGroupsInUse']
};

Object.entries(filtros).forEach(([ruta, [sp, tipo]]) => {
  router.get(ruta, (req, res) => responder(res, request => {
    if (tipo) request.input('Tipo', sql.VarChar(20), tipo);
    return request.execute(sp);
  }));
});

Object.entries(listas).forEach(([ruta, sp]) => {
  router.get(ruta, (req, res) => responder(res, request => request.execute(sp)));
});

router.get('/meses', (req, res) => responder(res, request => request.execute('SP_GetMonths')));

// GET /api/catalogos/anios?tipo=ventas|compras|inventario
router.get('/anios', (req, res) =>
  responder(res, request => request
    .input('Tipo', sql.VarChar(20), req.query.tipo || 'ventas')
    .execute('SP_GetYears')));

// Buscadores: ?criterio=texto&cantidad=20
router.get('/ciudades', (req, res) =>
  responder(res, request => request
    .input('Criterio', sql.NVarChar(50), req.query.criterio || null)
    .input('Cantidad', sql.Int, limite(req.query.cantidad))
    .execute('SP_SearchCities')));

router.get('/personas', (req, res) =>
  responder(res, request => request
    .input('Criterio', sql.NVarChar(50), req.query.criterio || null)
    .input('SoloVendedores', sql.Bit, req.query.soloVendedores === '1' ? 1 : 0)
    .input('Cantidad', sql.Int, limite(req.query.cantidad))
    .execute('SP_SearchPeople')));

router.get('/clientes', (req, res) =>
  responder(res, request => request
    .input('Criterio', sql.NVarChar(100), req.query.criterio || null)
    .input('Cantidad', sql.Int, limite(req.query.cantidad))
    .execute('SP_SearchCustomers')));

router.get('/productos', (req, res) =>
  responder(res, request => request
    .input('Criterio', sql.NVarChar(100), req.query.criterio || null)
    .input('Cantidad', sql.Int, limite(req.query.cantidad))
    .execute('SP_SearchStockItems')));

module.exports = router;
