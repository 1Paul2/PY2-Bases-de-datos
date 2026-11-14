import { useState } from 'react';
import { iniciarSesion } from '../Api';

export default function Login({ onEntrar }) {
  const [usuario, setUsuario] = useState('');
  const [contrasena, setContrasena] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function entrar(e) {
    e.preventDefault();
    setError('');
    setEnviando(true);
    try {
      onEntrar(await iniciarSesion(usuario.trim(), contrasena));
    } catch (err) {
      setError(err.message);
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="pagina-login">
      <form className="tarjeta-login" onSubmit={entrar}>
        <p className="subtitulo-institucional">Wide World Importers</p>
        <h1 className="titulo-login">Iniciar sesión</h1>

        <label>
          Usuario
          <input value={usuario} onChange={e => setUsuario(e.target.value)} autoComplete="username" autoFocus required />
        </label>
        <label>
          Contraseña
          <input type="password" value={contrasena} onChange={e => setContrasena(e.target.value)} autoComplete="current-password" required />
        </label>

        {error && <p className="mensaje-error" role="alert">{error}</p>}

        <button type="submit" disabled={enviando}>{enviando ? 'Entrando...' : 'Entrar'}</button>
      </form>
    </div>
  );
}
