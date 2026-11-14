const express = require('express');
const jwt = require('jsonwebtoken');
const { sql, obtenerPool, nodoDelUsuario, estadoHttp } = require('./db');

const router = express.Router();

const NODOS_LOGIN = ['corporativo', 'sanjose', 'limon'];

router.post('/login', async (req, res) => {
  const { usuario, contrasena } = req.body ?? {};
  if (!usuario || !contrasena) {
    return res.status(400).json({ error: 'Indique el usuario y la contraseña.' });
  }

  for (const nodo of NODOS_LOGIN) {
    try {
      const pool = await obtenerPool(nodo, 'app_login');
      const result = await pool.request()
        .input('Username', sql.NVarChar(50), usuario)
        .input('Password', sql.NVarChar(128), contrasena)
        .execute('Seguridad.SP_IniciarSesion');

      const u = result.recordset[0];
      const datos = {
        IdUser: u.IdUser,
        Username: u.Username,
        FullName: u.FullName,
        Rol: u.Rol,
        Sucursal: u.Sucursal,
        nodo: nodoDelUsuario(u)
      };
      const token = jwt.sign(datos, process.env.JWT_SECRET, { expiresIn: '8h' });
      return res.json({ token, usuario: datos, nodoLogin: nodo });
    } catch (err) {
      if (err.number === 50044 || err.number === 50045) {
        return res.status(401).json({ error: err.message });
      }
      if (estadoHttp(err) !== 503) {
        return res.status(500).json({ error: err.message });
      }
    }
  }
  res.status(503).json({ error: 'Ningún nodo responde para iniciar sesión.' });
});

function autenticar(req, res, next) {
  const [tipo, token] = (req.headers.authorization || '').split(' ');
  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Inicie sesión para continuar.' });
  }
  try {
    req.usuario = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return res.status(401).json({ error: 'La sesión venció; inicie sesión de nuevo.' });
  }
  req.pool = () => obtenerPool(req.usuario.nodo);
  next();
}

router.get('/yo', autenticar, (req, res) => res.json(req.usuario));

module.exports = { router, autenticar };
