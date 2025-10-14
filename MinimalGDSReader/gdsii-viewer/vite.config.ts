import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    headers: {
      // Enable Cross-Origin Embedder Policy for WASM
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin'
    },
    fs: {
      // Allow serving files from project root
      allow: ['..']
    }
  },
  build: {
    target: 'esnext',
    rollupOptions: {
      output: {
        // Ensure WASM files are treated as assets
        assetFileNames: (assetInfo) => {
          if (assetInfo.name && assetInfo.name.endsWith('.wasm')) {
            return 'assets/[name].[hash][extname]'
          }
          return 'assets/[name].[hash][extname]'
        }
      }
    }
  },
  assetsInclude: ['**/*.wasm'],
  optimizeDeps: {
    // Exclude WASM from optimization
    exclude: ['gds-parser']
  }
})