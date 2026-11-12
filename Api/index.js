require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { router: auth, autenticar } = require('./auth');

for (const variable of ['APP_PASSWORD', 'JWT_SECRET']) {
  if (!process.env[variable]) {
    console.error(`Falta ${variable} en Api/.env`);
    process.exit(1);
  }
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/salud', (req, res) => res.json({ ok: true }));

app.use('/api/auth', auth);
app.use('/api', autenticar);

app.use('/api/clientes', require('./routes/clientes'));
app.use('/api/productos', require('./routes/productos'));
app.use('/api/proveedores', require('./routes/proveedores'));
app.use('/api/ventas', require('./routes/ventas'));
app.use('/api/estadisticas', require('./routes/estadisticas'));
app.use('/api/catalogos', require('./routes/catalogos'));

const puerto = process.env.PORT || 3001;
app.listen(puerto, () => console.log(`API en http://localhost:${puerto}`));
