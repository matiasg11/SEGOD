import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/postcss';
import {defineConfig} from 'vite';

export default defineConfig({
  base:'/SEGOD/',
  root:'github-pages',
  css:{postcss:{plugins:[tailwindcss()]}},
  plugins:[react()],
  build:{outDir:'../pages-dist',emptyOutDir:true},
});
