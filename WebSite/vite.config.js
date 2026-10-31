import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // En desarrollo, /api se reenvía a la API (así la web y la API comparten origen)
  server: {
    proxy: { '/api': 'http://localhost:3001' }
  },
})
