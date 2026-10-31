import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './Mapa.css';

// Fix para los iconos de Leaflet con bundlers modernos (Vite/Webpack)
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl:
    'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl:
    'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl:
    'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// Marcador personalizado verde
const iconoVerde = new L.DivIcon({
  className: 'marcador-verde',
  html: `
    <div class="marcador-pin">
      <div class="marcador-punto"></div>
    </div>
  `,
  iconSize: [30, 42],
  iconAnchor: [15, 42],
  popupAnchor: [0, -42],
});

export default function Mapa({ latitud, longitud, titulo, subtitulo }) {
  const lat = Number(latitud);
  const lng = Number(longitud);

  const coordenadasValidas =
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 &&
    lng >= -180 && lng <= 180 &&
    !(lat === 0 && lng === 0);

  if (!coordenadasValidas) {
    return (
      <div className="mapa-vacio">
        <span className="mapa-vacio-icono">📍</span>
        <p>Este cliente no tiene coordenadas de ubicación registradas.</p>
      </div>
    );
  }

  return (
    <div className="mapa-contenedor">
      <MapContainer
        center={[lat, lng]}
        zoom={13}
        scrollWheelZoom={false}
        style={{ height: '100%', width: '100%', borderRadius: '12px' }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <Marker position={[lat, lng]} icon={iconoVerde}>
          <Popup>
            <strong>{titulo || 'Cliente'}</strong>
            <br />
            {subtitulo && <span>{subtitulo}</span>}
            <br />
            <small>
              {lat.toFixed(5)}, {lng.toFixed(5)}
            </small>
          </Popup>
        </Marker>
      </MapContainer>

      <a
        className="mapa-enlace"
        href={`https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=15/${lat}/${lng}`}
        target="_blank"
        rel="noopener noreferrer"
      >
        Ver en OpenStreetMap →
      </a>
    </div>
  );
}