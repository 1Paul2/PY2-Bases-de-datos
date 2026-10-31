const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');

const camposVenta = [
  'CustomerID', 'DeliveryMethodID', 'CustomerPurchaseOrderNumber',
  'ContactPersonID', 'SalespersonPersonID', 'InvoiceDate', 'DeliveryInstructions'
];

function faltantes(body, campos) {
  return campos.filter(campo => body[campo] === undefined || body[campo] === null || body[campo] === '');
}

// Las líneas llegan como arreglo y se envían al SP en un solo texto:
// 'StockItemID|Cantidad|Precio|Impuesto|Descripción;...'
// (solo se da formato al texto; el cálculo de impuestos y totales lo hace el SP)
function textoLineas(lineas) {
  if (!Array.isArray(lineas) || lineas.length === 0) return null;
  return lineas
    .map(l => [
      Number.parseInt(l.StockItemID, 10),
      Number.parseInt(l.Quantity, 10),
      Number(l.UnitPrice),
      Number(l.TaxRate),
      String(l.Description ?? '').replace(/[|;]/g, ' ').trim()
    ].join('|'))
    .join(';');
}

function lineasInvalidas(lineas) {
  if (!Array.isArray(lineas) || lineas.length === 0) return 'Debe incluir al menos una línea de factura.';
  const mala = lineas.findIndex(l =>
    !Number.isInteger(Number.parseInt(l.StockItemID, 10)) ||
    !(Number.parseInt(l.Quantity, 10) > 0) ||
    !(Number(l.UnitPrice) >= 0) ||
    !(Number(l.TaxRate) >= 0)
  );
  return mala >= 0 ? `La línea ${mala + 1} tiene datos inválidos.` : null;
}

function parametrosVenta(request, body) {
  return request
    .input('CustomerID', sql.Int, body.CustomerID)
    .input('DeliveryMethodID', sql.Int, body.DeliveryMethodID)
    .input('CustomerPurchaseOrderNumber', sql.NVarChar(20), body.CustomerPurchaseOrderNumber)
    .input('ContactPersonID', sql.Int, body.ContactPersonID)
    .input('SalespersonPersonID', sql.Int, body.SalespersonPersonID)
    .input('InvoiceDate', sql.Date, body.InvoiceDate)
    .input('DeliveryInstructions', sql.NVarChar(500), body.DeliveryInstructions)
    .input('Lines', sql.NVarChar(sql.MAX), textoLineas(body.Lineas));
}

function estadoError(err) {
  return err.number >= 50000 || err.code === 'EREQUEST' ? 400 : 500;
}

// Listado con filtros acumulativos
router.get('/', async (req, res) => {
  try {
    const { cliente, desde, hasta, min, max } = req.query;
    const pagina = Math.max(Number.parseInt(req.query.pagina, 10) || 1, 1);
    const porPagina = Math.min(Math.max(Number.parseInt(req.query.porPagina, 10) || 10, 1), 100);

    const pool = await poolPromise;
    const filtros = request => request
      .input('CustomerName', sql.NVarChar(100), cliente || null)
      .input('InvoiceDateFrom', sql.Date, desde ? new Date(desde) : null)
      .input('InvoiceDateTo', sql.Date, hasta ? new Date(hasta) : null)
      .input('MinTotalAmount', sql.Decimal(18, 2), min ? parseFloat(min) : null)
      .input('MaxTotalAmount', sql.Decimal(18, 2), max ? parseFloat(max) : null);

    const [conteo, result] = await Promise.all([
      filtros(pool.request()).execute('SP_GetSalesCount'),
      filtros(pool.request())
        .input('Pagina', sql.Int, pagina)
        .input('PorPagina', sql.Int, porPagina)
        .execute('SP_GetSales')
    ]);

    res.json({ total: conteo.recordset[0]?.Total ?? 0, pagina, porPagina, data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  const requeridos = faltantes(req.body, camposVenta);
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }
  const errorLineas = lineasInvalidas(req.body.Lineas);
  if (errorLineas) {
    return res.status(400).json({ error: errorLineas });
  }

  try {
    const pool = await poolPromise;
    const result = await parametrosVenta(pool.request(), req.body)
      .execute('SP_InsertSale');
    res.status(201).json({ data: result.recordset[0] });
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const requeridos = faltantes(req.body, camposVenta);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'InvoiceID inválido' });
  }
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }
  const errorLineas = lineasInvalidas(req.body.Lineas);
  if (errorLineas) {
    return res.status(400).json({ error: errorLineas });
  }

  try {
    const pool = await poolPromise;
    await parametrosVenta(pool.request(), req.body)
      .input('InvoiceID', sql.Int, id)
      .input('BillToCustomerID', sql.Int, req.body.BillToCustomerID ?? req.body.CustomerID)
      .execute('SP_UpdateSale');
    res.status(204).send();
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'InvoiceID inválido' });
  }

  try {
    const pool = await poolPromise;
    await pool.request().input('InvoiceID', sql.Int, id).execute('SP_DeleteSale');
    res.status(204).send();
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

// Detalle: encabezado y líneas de la factura
router.get('/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const pool = await poolPromise;

    const encabezado = await pool.request()
      .input('InvoiceID', sql.Int, id)
      .execute('SP_GetSaleHeader');

    if (encabezado.recordset.length === 0) {
      return res.status(404).json({ error: 'Venta no encontrada' });
    }

    const lineas = await pool.request()
      .input('InvoiceID', sql.Int, id)
      .execute('SP_GetSaleDetails');

    res.json({
      encabezado: encabezado.recordset[0],
      lineas: lineas.recordset
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;