const express = require('express');
const router = express.Router();
const { sql, poolPromise } = require('../db');
const { leerPagina, respuestaPaginada } = require('../paginacion');

const camposProveedor = [
  'SupplierReference', 'SupplierName', 'SupplierCategoryID',
  'DeliveryCityID',
  'DeliveryMethodID', 'PostalCityID', 'DeliveryPostalCode', 'PostalPostalCode', 'PhoneNumber',
  'FaxNumber', 'WebsiteURL', 'DeliveryAddressLine1', 'PostalAddressLine1',
  'BankAccountBranch', 'BankAccountName', 'BankAccountNumber', 'PaymentDays'
];

function faltantes(body, campos) {
  return campos.filter(campo => body[campo] === undefined || body[campo] === null || body[campo] === '');
}

function decimalOpcional(valor) {
  if (valor === undefined || valor === null) return null;
  if (typeof valor === 'string' && valor.trim() === '') return null;
  const numero = Number(typeof valor === 'string' ? valor.trim() : valor);
  return Number.isFinite(numero) ? numero : null;
}

function textoParametro(valor) {
  if (valor === undefined || valor === null || valor === '') return null;
  return String(valor);
}

function parametrosProveedor(request, body) {
  return request
    .input('SupplierReference', sql.NVarChar(40), body.SupplierReference ?? null)
    .input('SupplierName', sql.NVarChar(100), body.SupplierName)
    .input('SupplierCategoryID', sql.Int, body.SupplierCategoryID)
    .input('PrimaryContactPersonID', sql.Int, Number(body.PrimaryContactPersonID) > 0 ? Number(body.PrimaryContactPersonID) : null)
    .input('AlternateContactPersonID', sql.Int, Number(body.AlternateContactPersonID) > 0 ? Number(body.AlternateContactPersonID) : null)
    // Si no se eligió una persona, el SP crea el contacto con el nombre escrito
    .input('PrimaryContactName', sql.NVarChar(50), textoNombre(body.PrimaryContactName))
    .input('AlternateContactName', sql.NVarChar(50), textoNombre(body.AlternateContactName))
    .input('DeliveryMethodID', sql.Int, body.DeliveryMethodID ?? null)
    .input('DeliveryCityID', sql.Int, body.DeliveryCityID)
    .input('PostalCityID', sql.Int, body.PostalCityID)
    .input('DeliveryPostalCode', sql.NVarChar(20), body.DeliveryPostalCode)
    .input('PostalPostalCode', sql.NVarChar(20), body.PostalPostalCode)
    .input('PhoneNumber', sql.NVarChar(40), body.PhoneNumber)
    .input('FaxNumber', sql.NVarChar(40), body.FaxNumber)
    .input('WebsiteURL', sql.NVarChar(512), body.WebsiteURL)
    .input('DeliveryAddressLine1', sql.NVarChar(120), body.DeliveryAddressLine1)
    .input('DeliveryAddressLine2', sql.NVarChar(120), body.DeliveryAddressLine2 ?? null)
    .input('PostalAddressLine1', sql.NVarChar(120), body.PostalAddressLine1)
    .input('PostalAddressLine2', sql.NVarChar(120), body.PostalAddressLine2 ?? null)
    .input('DeliveryLatitude', sql.Decimal(9, 6), decimalOpcional(body.DeliveryLatitude))
    .input('DeliveryLongitude', sql.Decimal(9, 6), decimalOpcional(body.DeliveryLongitude))
    .input('BankAccountBranch', sql.NVarChar(100), textoParametro(body.BankAccountBranch))
    .input('BankAccountName', sql.NVarChar(100), textoParametro(body.BankAccountName))
    .input('BankAccountNumber', sql.NVarChar(40), textoParametro(body.BankAccountNumber))
    .input('PaymentDays', sql.Int, body.PaymentDays)
    .input('LastEditedBy', sql.Int, body.LastEditedBy ?? null);
}

function textoNombre(valor) {
  if (valor === undefined || valor === null) return null;
  const texto = String(valor).trim();
  return texto === '' ? null : texto.slice(0, 50);
}

// El contacto primario puede ser una persona existente (ID) o un nombre nuevo
function faltaContacto(body) {
  return !(Number(body.PrimaryContactPersonID) > 0) && !textoNombre(body.PrimaryContactName);
}

function estadoError(err) {
  return err.number >= 50000 || err.code === 'EREQUEST' ? 400 : 500;
}

// Categorías para el filtro (select) en React
router.get('/categorias', async (req, res) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request().execute('SP_GetSupplierCategoriesInUse');
    res.json({ total: result.recordset.length, data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Listado con filtros acumulativos
router.get('/', async (req, res) => {
  try {
    const categoria = req.query.categoria ? parseInt(req.query.categoria) : null;

    const { pagina, porPagina } = leerPagina(req.query);
    const pool = await poolPromise;
    const result = await pool.request()
      .input('Pagina', sql.Int, pagina)
      .input('PorPagina', sql.Int, porPagina)
      .input('Name', sql.NVarChar(100), req.query.name || null)
      .input('SupplierCategoryID', sql.Int, categoria)
      .input('DeliveryMethodID', sql.Int, req.query.metodo ? parseInt(req.query.metodo) : null)
      .execute('SP_GetSuppliers');

    res.json(respuestaPaginada(result.recordset, pagina, porPagina));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  const requeridos = faltantes(req.body, camposProveedor);
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }
  if (faltaContacto(req.body)) {
    return res.status(400).json({ error: 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.' });
  }

  // insert proveedor
  try {
    const pool = await poolPromise;
    const result = await parametrosProveedor(pool.request(), req.body)
      .execute('SP_InsertSupplier');
    res.status(201).json({ data: result.recordset[0] });
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const requeridos = faltantes(req.body, camposProveedor);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'SupplierID inválido' });
  }
  if (requeridos.length > 0) {
    return res.status(400).json({ error: `Campos obligatorios: ${requeridos.join(', ')}` });
  }
  if (faltaContacto(req.body)) {
    return res.status(400).json({ error: 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.' });
  }

  // update proveedor
  try {
    const pool = await poolPromise;
    await parametrosProveedor(pool.request(), req.body)
      .input('SupplierID', sql.Int, id)
      .execute('SP_UpdateSupplier');
    res.status(204).send();
  } catch (err) {
    res.status(estadoError(err)).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'SupplierID inválido' });
  }

  // delete proveedor
  try {
    const pool = await poolPromise;
    await pool.request().input('SupplierID', sql.Int, id).execute('SP_DeleteSupplier');
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
      .input('SupplierID', sql.Int, parseInt(req.params.id))
      .execute('SP_GetSupplierDetails');

    res.json({ data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;