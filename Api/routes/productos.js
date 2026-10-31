const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');
const { leerPagina, respuestaPaginada } = require('../paginacion');

const camposProducto = [
  'StockItemName', 'SupplierID', 'LeadTimeDays', 'UnitPackageID', 'OuterPackageID',
  'QuantityPerOuter', 'TaxRate', 'UnitPrice', 'IsChillerStock'
];

function faltantes(body, campos) {
  return campos.filter(campo => body[campo] === undefined || body[campo] === null || body[campo] === '');
}

function decimalOpcional(valor) {
  if (valor === undefined || valor === null || valor === '') return null;
  const numero = Number(valor);
  return Number.isFinite(numero) ? numero : null;
}

function enteroOpcional(valor) {
  if (valor === undefined || valor === null || valor === '') return null;
  const numero = Number(valor);
  return Number.isInteger(numero) && numero > 0 ? numero : null;
}

function textoOpcional(valor) {
  if (valor === undefined || valor === null) return null;
  const texto = String(valor).trim();
  return texto === '' ? null : texto;
}

function enteroNoNegativo(valor) {
  if (valor === undefined || valor === null || valor === '') return null;
  const numero = Number(valor);
  return Number.isInteger(numero) && numero >= 0 ? numero : null;
}

// Los grupos llegan como arreglo [1, 4] o texto '1,4'; el SP los recibe como '1,4'
function textoGrupos(valor) {
  if (valor === undefined || valor === null) return null;
  const lista = Array.isArray(valor) ? valor : String(valor).split(',');
  return lista.map(v => Number.parseInt(v, 10)).filter(Number.isInteger).join(',');
}

function parametrosProducto(request, body) {
  return request
    .input('StockItemName', sql.NVarChar(100), body.StockItemName)
    .input('SupplierID', sql.Int, body.SupplierID)
    .input('LeadTimeDays', sql.Int, body.LeadTimeDays)
    .input('ColorID', sql.Int, enteroOpcional(body.ColorID))
    .input('UnitPackageID', sql.Int, body.UnitPackageID)
    .input('OuterPackageID', sql.Int, body.OuterPackageID)
    .input('QuantityPerOuter', sql.Int, body.QuantityPerOuter)
    .input('Brand', sql.NVarChar(50), textoOpcional(body.Brand))
    .input('Size', sql.NVarChar(20), textoOpcional(body.Size))
    .input('TaxRate', sql.Decimal(18, 3), decimalOpcional(body.TaxRate))
    .input('UnitPrice', sql.Decimal(18, 2), decimalOpcional(body.UnitPrice))
    .input('IsChillerStock', sql.Bit, body.IsChillerStock ?? false)
    .input('RecommendedRetailPrice', sql.Decimal(18, 2), decimalOpcional(body.RecommendedRetailPrice))
    .input('TypicalWeightPerUnit', sql.Decimal(18, 3), decimalOpcional(body.TypicalWeightPerUnit))
    .input('MarketingComments', sql.NVarChar(sql.MAX), textoOpcional(body.MarketingComments))
    .input('BinLocation', sql.NVarChar(20), textoOpcional(body.BinLocation))
    .input('QuantityOnHand', sql.Int, enteroNoNegativo(body.QuantityOnHand))
    .input('StockGroups', sql.NVarChar(400), textoGrupos(body.StockGroups))
    .input('LastEditedBy', sql.Int, body.LastEditedBy ?? null);
}

function estadoError(err) {
  return err.number >= 50000 || err.code === 'EREQUEST' ? 400 : 500;
}

// Grupos para llenar el filtro (select) en React
router.get('/grupos', async (req, res) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request().execute('SP_GetStockGroupsInUse');
    res.json({ total: result.recordset.length, data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Listado con filtros acumulativos
router.get('/', async (req, res) => {
  try {
    const grupo = req.query.grupo ? parseInt(req.query.grupo) : null;

    const { pagina, porPagina } = leerPagina(req.query);
    const pool = await poolPromise;
    const result = await pool.request()
      .input('Pagina', sql.Int, pagina)
      .input('PorPagina', sql.Int, porPagina)
      .input('Name', sql.NVarChar(100), req.query.name || null)
      .input('StockGroupID', sql.Int, grupo)
      .input('CantidadMinima', sql.Int, enteroNoNegativo(req.query.min))
      .input('CantidadMaxima', sql.Int, enteroNoNegativo(req.query.max))
      .execute('SP_GetStockItems');

    res.json(respuestaPaginada(result.recordset, pagina, porPagina));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get, Post, Put, Delete routes para products
router.post('/', async (req, res) => {
  const requeridos = faltantes(req.body, camposProducto);
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }

  // insert product
  try {
    const pool = await poolPromise;
    const result = await parametrosProducto(pool.request(), req.body)
      .execute('SP_InsertStockItem');
    res.status(201).json({ data: result.recordset[0] });
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const requeridos = faltantes(req.body, camposProducto);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'StockItemID inválido' });
  }
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }

  // update product por id
  try {
    const pool = await poolPromise;
    await parametrosProducto(pool.request(), req.body)
      .input('StockItemID', sql.Int, id)
      .execute('SP_UpdateStockItem');
    res.status(204).send();
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'StockItemID inválido' });
  }
  
  // delete product por id 
  try {
    const pool = await poolPromise;
    await pool.request().input('StockItemID', sql.Int, id).execute('SP_DeleteStockItem');
    res.status(204).send();
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

// Detalle
router.get('/:id', async (req, res) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request()
      .input('StockItemID', sql.Int, parseInt(req.params.id))
      .execute('SP_GetStockItemDetails');

    res.json({ data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;