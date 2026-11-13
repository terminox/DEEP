import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// One page per URL: the app and Google Play link to these documents directly, so each is a real
// file at its own path rather than a client-side route that needs a rewrite to resolve.
const page = (path: string) => resolve(import.meta.dirname, path)

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      input: {
        main: page('index.html'),
        privacy: page('privacy/index.html'),
        terms: page('terms/index.html'),
        deleteAccount: page('delete-account/index.html'),
      },
    },
  },
})
