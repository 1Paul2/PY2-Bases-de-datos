require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { poolPromise } = require('./db');
const inicializarBD = require('./init');   

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/salud', (req, res) => res.json({ ok: true }));

app.get('/api/prueba-db', async (req, res) => {
  try {
    const pool = await poolPromise;
    const r = await pool.request().query('SELECT DB_NAME() AS base');
    res.json(r.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.use('/api/clientes', require('./routes/clientes'));
app.use('/api/productos', require('./routes/productos'));
app.use('/api/proveedores', require('./routes/proveedores'));
app.use('/api/ventas', require('./routes/ventas'));
app.use('/api/estadisticas', require('./routes/estadisticas'));
app.use('/api/catalogos', require('./routes/catalogos'));

inicializarBD()
  .then(() => {
    app.listen(process.env.PORT, () =>
      console.log(`API en http://localhost:${process.env.PORT}`)
    );
  })
  .catch(err => {
    console.error('Falló la inicialización:', err.message);
    process.exit(1);
  });