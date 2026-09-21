import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'node:path';

const rootDir = import.meta.dirname;

/**
 * Vite configuration for the modular SPA.
 *
 * - `@apps/*` and `@shared/*` aliases make the module boundaries explicit in
 *   every import statement (`@apps/calculator/...`, `@shared/risk-intelligence/...`),
 *   which is what keeps the modular monolith extractable later on.
 * - The API proxy targets the Rails 8 API-only backend (see `apps/api`).
 */
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@apps': path.resolve(rootDir, 'src/apps'),
      '@shared': path.resolve(rootDir, 'src/shared'),
    },
  },
  server: {
    port: 5173,
    strictPort: false,
    proxy: {
      '/api': {
        target: process.env.VITE_API_PROXY_TARGET ?? 'http://127.0.0.1:3000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
    rollupOptions: {
      output: {
        // Keep the lazy-loaded module bundles separate from the vendor shell so
        // unopened modules are never downloaded.
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('recharts') || id.includes('d3-')) return 'vendor-charts';
            if (id.includes('@mui') || id.includes('@emotion')) return 'vendor-mui';
            return 'vendor-core';
          }
          return undefined;
        },
      },
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    css: false,
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/**/*.{test,spec}.{ts,tsx}', 'src/main.tsx', 'src/**/index.tsx'],
    },
  },
});