require('dotenv').config();
const sql = require('mssql');

const NODOS = {
  corporativo: { puerto: 'DB_PORT_CORPORATIVO', base: 'WWI_Corporativo', usuario: 'app_corporativo' },
  sanjose: { puerto: 'DB_PORT_SANJOSE', base: 'WWI_SanJose', usuario: 'app_admin_sj' },
  limon: { puerto: 'DB_PORT_LIMON', base: 'WWI_Limon', usuario: 'app_admin_li' }
};

const ERRORES_CONEXION = ['ESOCKET', 'ETIMEOUT', 'ECONNCLOSED', 'ENOTOPEN', 'ECONNRESET'];

const pools = {};

function nodoCaido(nodo) {
  const err = new Error(`El nodo ${nodo} no responde. Intente de nuevo en unos minutos.`);
  err.status = 503;
  return err;
}

// Un pool por nodo y usuario; si no conecta se descarta, así la siguiente petición reintenta
function obtenerPool(nodo, usuario = NODOS[nodo].usuario) {
  const clave = `${usuario}@${nodo}`;
  if (!pools[clave]) {
    const pool = new sql.ConnectionPool({
      user: usuario,
      password: process.env.APP_PASSWORD,
      server: process.env.DB_HOST || 'localhost',
      port: Number.parseInt(process.env[NODOS[nodo].puerto], 10),
      database: NODOS[nodo].base,
      connectionTimeout: 5000,
      requestTimeout: 30000,
      options: { encrypt: false, trustServerCertificate: true }
    });
    pool.on('error', () => {});
    pools[clave] = pool.connect().catch(err => {
      delete pools[clave];
      throw ERRORES_CONEXION.includes(err.code) ? nodoCaido(nodo) : err;
    });
  }
  return pools[clave];
}

function nodoDelUsuario(usuario) {
  if (usuario.Rol === 'Corporativo') return 'corporativo';
  return usuario.Sucursal === 'SJ' ? 'sanjose' : 'limon';
}

// 503 si el nodo no responde, 403 si el usuario de BD no tiene permiso (error 229)
function estadoHttp(err, porDefecto = 500) {
  if (err.status) return err.status;
  if (ERRORES_CONEXION.includes(err.code)) {
    err.message = 'El nodo de la base de datos no responde. Intente de nuevo en unos minutos.';
    return 503;
  }
  if (err.number === 229) return 403;
  return porDefecto;
}

module.exports = { sql, NODOS, obtenerPool, nodoDelUsuario, estadoHttp };
