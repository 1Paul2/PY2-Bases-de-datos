const ADMINISTRADOR = 'Administrador';
const CORPORATIVO = 'Corporativo';
const AMBOS = [ADMINISTRADOR, CORPORATIVO];

const REGLAS = {
  clientes: { GET: AMBOS, POST: [CORPORATIVO], PUT: [CORPORATIVO], DELETE: [CORPORATIVO] },
  proveedores: { GET: AMBOS, POST: [CORPORATIVO], PUT: [CORPORATIVO], DELETE: [CORPORATIVO] },
  productos: { GET: AMBOS, POST: [ADMINISTRADOR], PUT: [ADMINISTRADOR], DELETE: [ADMINISTRADOR] },
  ventas: { GET: [ADMINISTRADOR], POST: [ADMINISTRADOR] },
  estadisticas: { GET: [CORPORATIVO] },
  catalogos: { GET: AMBOS }
};

function permitir(modulo) {
  const reglas = REGLAS[modulo];
  return (req, res, next) => {
    const roles = reglas[req.method] ?? [];
    if (roles.includes(req.usuario.Rol)) return next();
    res.status(403).json({ error: 'Su rol no tiene acceso a esta operación.' });
  };
}

module.exports = { permitir };
