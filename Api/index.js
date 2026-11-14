require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { router: auth, autenticar } = require('./auth');
const { permitir } = require('./roles');

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
app.use('/api/estado-nodos', require('./routes/estado'));

for (const modulo of ['clientes', 'productos', 'proveedores', 'ventas', 'estadisticas', 'catalogos']) {
  app.use(`/api/${modulo}`, permitir(modulo), require(`./routes/${modulo}`));
}

const puerto = process.env.PORT || 3001;
app.listen(puerto, () => console.log(`API en http://localhost:${puerto}`));
