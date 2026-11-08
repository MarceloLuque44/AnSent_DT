import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  const proxyTarget =
    env.VITE_API_PROXY_TARGET || env.VITE_API_URL || 'http://localhost:3000';

  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        // Reenvia /api al servidor Express durante desarrollo
        '/api': proxyTarget,
        // Reenvia las imagenes del dashboard al servidor Express
        '/salida-cliente': proxyTarget,
      },
    },
  };
});
