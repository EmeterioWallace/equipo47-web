#!/usr/bin/env node
// Regenera images/products/manifest.json a partir de los archivos reales.
//
// Clave:   nombre del archivo en minúsculas  (lo que escribe Fátima en producciones)
// Valor:   ruta real desde la raíz del sitio  (con mayúsculas originales)
//
// Se ejecuta en cada deploy de Netlify (netlify.toml → build.command), así que
// el manifest nunca queda desfasado respecto a las imágenes del repo.
// Sin dependencias: solo Node.js.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DIR_IMAGENES = path.join(ROOT, 'images', 'products');
const SALIDA = path.join(DIR_IMAGENES, 'manifest.json');
const EXTENSIONES = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif']);

function recorrer(dir) {
  const resultado = [];
  for (const entrada of fs.readdirSync(dir, { withFileTypes: true })) {
    const ruta = path.join(dir, entrada.name);
    if (entrada.isDirectory()) {
      resultado.push(...recorrer(ruta));
    } else if (EXTENSIONES.has(path.extname(entrada.name).toLowerCase())) {
      resultado.push(ruta);
    }
  }
  return resultado;
}

function generar() {
  if (!fs.existsSync(DIR_IMAGENES)) {
    console.error(`❌ No existe ${DIR_IMAGENES}`);
    process.exit(1);
  }

  const archivos = recorrer(DIR_IMAGENES).sort();
  const manifest = {};
  let colisiones = 0;

  for (const absoluta of archivos) {
    const clave = path.basename(absoluta).toLowerCase();
    const valor = path.relative(ROOT, absoluta).split(path.sep).join('/');

    if (manifest[clave] && manifest[clave] !== valor) {
      // Dos archivos con el mismo nombre (en distinta carpeta o solo en mayúsculas):
      // el manifest solo puede apuntar a uno. Se avisa para corregirlo en el repo.
      console.warn(`⚠️  Nombre duplicado "${clave}": ${manifest[clave]} y ${valor}. Se usa el primero.`);
      colisiones++;
      continue;
    }
    manifest[clave] = valor;
  }

  // Orden por clave, como el manifest original, para que los diffs sean limpios.
  const ordenado = {};
  for (const clave of Object.keys(manifest).sort()) ordenado[clave] = manifest[clave];

  const contenido = JSON.stringify(ordenado, null, 2) + '\n';
  const anterior = fs.existsSync(SALIDA) ? fs.readFileSync(SALIDA, 'utf8') : '';

  if (anterior === contenido) {
    console.log(`✓ manifest.json sin cambios (${Object.keys(manifest).length} imágenes)`);
  } else {
    fs.writeFileSync(SALIDA, contenido);
    console.log(`✓ manifest.json regenerado (${Object.keys(manifest).length} imágenes, ${colisiones} duplicados)`);
  }
}

generar();
