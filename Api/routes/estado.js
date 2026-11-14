const express = require('express');
const { sql, NODOS } = require('../db');

const router = express.Router();
const VIGENCIA_MS = 10000;
let ultimo = null;

async function probarNodo(nodo) {
  const inicio = Date.now();
  const pool = new sql.ConnectionPool({
    user: 'app_login',
    password: process.env.APP_PASSWORD,
    server: process.env.DB_HOST || 'localhost',
    port: Number.parseInt(process.env[NODOS[nodo].puerto], 10),
    database: NODOS[nodo].base,
    connectionTimeout: 3000,
    requestTimeout: 3000,
    options: { encrypt: false, trustServerCertificate: true }
  });
  pool.on('error', () => {});
  try {
    await pool.connect();
    await pool.request().query('SELECT 1');
    return { nodo, responde: true, ms: Date.now() - inicio };
  } catch {
    return { nodo, responde: false, ms: Date.now() - inicio };
  } finally {
    pool.close().catch(() => {});
  }
}

router.get('/', async (req, res) => {
  if (!ultimo || Date.now() - ultimo.instante > VIGENCIA_MS) {
    const nodos = await Promise.all(Object.keys(NODOS).map(probarNodo));
    ultimo = { instante: Date.now(), nodos, revisado: new Date().toISOString() };
  }
  res.json({ nodos: ultimo.nodos, revisado: ultimo.revisado });
});

module.exports = router;
