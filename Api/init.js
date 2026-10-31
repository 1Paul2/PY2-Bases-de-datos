// init.js
const fs = require('fs');
const path = require('path');
const sql = require('mssql');
require('dotenv').config();

const config = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  options: {
    encrypt: false,
    trustServerCertificate: true,
  },
};

const RAIZ_SCRIPT = path.join(__dirname, '..', 'Script');

const EXCLUIDOS = ['ejemplo_ejecucion.sql'];

const CARPETAS_SQL = [
  path.join(RAIZ_SCRIPT, 'sql'),
  path.join(RAIZ_SCRIPT, 'CRUD', 'PRODUCTOS'),
  path.join(RAIZ_SCRIPT, 'CRUD', 'CLIENTES'),
  path.join(RAIZ_SCRIPT, 'CRUD', 'PROVEEDORES'),
  path.join(RAIZ_SCRIPT, 'CRUD', 'VENTAS'),
  path.join(RAIZ_SCRIPT, 'estadisticas'),
];

// SPLIT ROBUSTO: tolera GO con espacios, tabs, mayusculas/minusculas, y al final del archivo
function dividirPorGO(contenido) {
  return contenido
    .split(/^\s*GO\s*;?\s*$/gim)
    .map(b => b.trim())
    .filter(b => b.length > 0);
}

async function ejecutarArchivo(pool, rutaCompleta) {
  const nombre = path.basename(rutaCompleta);
  const contenido = fs.readFileSync(rutaCompleta, 'utf8');

  const bloques = dividirPorGO(contenido);

  console.log(`   >> ${nombre} (${bloques.length} bloques)`);

  for (let i = 0; i < bloques.length; i++) {
    const bloque = bloques[i];
    try {
      await pool.request().query(bloque);
    } catch (err) {
      if (/already exists|ya existe/i.test(err.message)) continue;
      console.error(`      ERROR ${nombre} [bloque ${i + 1}]: ${err.message}`);
      console.error(`         -> ${bloque.substring(0, 200).replace(/\s+/g, ' ')}...`);
    }
  }
}

async function inicializarBD() {
  console.log('Inicializando base de datos...');

  if (!fs.existsSync(RAIZ_SCRIPT)) {
    console.error(`No encontre la carpeta: ${RAIZ_SCRIPT}`);
    process.exit(1);
  }
  console.log(`Script encontrado en: ${RAIZ_SCRIPT}`);

  let pool;
  try {
    pool = await sql.connect(config);
  } catch (err) {
    console.error('No se pudo conectar a SQL Server:', err.message);
    throw err;
  }

  for (const carpeta of CARPETAS_SQL) {
    if (!fs.existsSync(carpeta)) {
      console.warn(`No existe: ${carpeta}`);
      continue;
    }

    // ejemplo_ejecucion.sql es solo para correrlo a mano (prueba los SPs), no se ejecuta al iniciar
    const archivos = fs.readdirSync(carpeta)
      .filter(f => f.endsWith('.sql') && !EXCLUIDOS.includes(f))
      .sort();

    if (archivos.length === 0) continue;

    console.log(`${path.relative(RAIZ_SCRIPT, carpeta)}`);
    for (const archivo of archivos) {
      await ejecutarArchivo(pool, path.join(carpeta, archivo));
    }
  }

  await pool.close();
  console.log('Base de datos inicializada');
}

module.exports = inicializarBD;