import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // Reenvia /api al servidor Express durante desarrollo
      '/api': 'http://localhost:3000',
      // Reenvia las imagenes del dashboard al servidor Express
      '/salida-cliente': 'http://localhost:3000',
    },
  },
});
