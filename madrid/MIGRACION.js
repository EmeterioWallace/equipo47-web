// ============================================
// SCRIPT DE MIGRACIÓN - Madrid v1 → v2
// ============================================
// 
// Uso:
// 1. Abre la consola en la app v1 (F12 → Console)
// 2. Copia TODO el contenido de este archivo
// 3. Pégalo en la consola
// 4. Ejecuta: exportarParaMigracion()
// 5. Copia el JSON que aparece
// 6. Ve a admin.html en v2 y pégalo en "Importar datos"
//

// Paso 1: Exportar datos de v1
function exportarParaMigracion() {
  const datos = {
    productos: JSON.parse(localStorage.getItem('productos_v3') || '[]'),
    variantes: JSON.parse(localStorage.getItem('variantes') || '[]'),
    cajas: JSON.parse(localStorage.getItem('cajas_v3') || '[]'),
    pales: JSON.parse(localStorage.getItem('pales') || '[]'),
    ubicaciones: JSON.parse(localStorage.getItem('ubicaciones_v3') || '[]'),
    salidas: JSON.parse(localStorage.getItem('salidas') || '[]'),
    categorias: JSON.parse(localStorage.getItem('categorias') || '[]'),
  };

  console.log('✓ Datos exportados. Total:');
  console.log(`  - Productos: ${datos.productos.length}`);
  console.log(`  - Variantes: ${datos.variantes.length}`);
  console.log(`  - Cajas: ${datos.cajas.length}`);
  console.log(`  - Palés: ${datos.pales.length}`);
  console.log(`  - Salidas: ${datos.salidas.length}`);
  console.log(`  - Categorías: ${datos.categorias.length}`);

  // Copiar al portapapeles
  const json = JSON.stringify(datos, null, 2);
  navigator.clipboard.writeText(json).then(() => {
    console.log('📋 JSON copiado al portapapeles');
    console.log('Pega esto en admin.html → Importar datos');
  });

  return datos;
}

// Paso 2: Importar en v2 (ejecutar en admin.html)
async function importarDatos() {
  const jsonStr = document.getElementById('import-json').value;
  if (!jsonStr) {
    toast('Pega los datos JSON primero');
    return;
  }

  try {
    const datos = JSON.parse(jsonStr);
    console.log('Iniciando migración...');

    // Migrar productos
    if (datos.productos && datos.productos.length > 0) {
      await migrarProductos(datos.productos);
    }

    // Migrar variantes
    if (datos.variantes && datos.variantes.length > 0) {
      await migrarVariantes(datos.variantes);
    }

    // Migrar cajas
    if (datos.cajas && datos.cajas.length > 0) {
      await migrarCajas(datos.cajas);
    }

    // Migrar palés
    if (datos.pales && datos.pales.length > 0) {
      await migrarPales(datos.pales);
    }

    // Migrar salidas
    if (datos.salidas && datos.salidas.length > 0) {
      await migrarSalidas(datos.salidas);
    }

    // Migrar categorías
    if (datos.categorias && datos.categorias.length > 0) {
      await migrarCategorias(datos.categorias);
    }

    toast('✅ Migración completada!');
    setTimeout(() => location.reload(), 2000);

  } catch (e) {
    console.error('Error en migración:', e);
    toast(`❌ Error: ${e.message}`);
  }
}

// ============================================
// FUNCIONES DE MIGRACIÓN
// ============================================

async function migrarProductos(productos) {
  console.log(`Migrando ${productos.length} productos...`);
  
  for (const prod of productos) {
    const { error } = await sb.from('productos').insert({
      id: prod.id,
      nombre: prod.nombre,
      descripcion: prod.descripcion || null,
      categoria_id: prod.categoriaId || null,
      subcategoria_id: prod.subcategoriaId || null,
      foto_url: prod.fotoUrl || null,
      created_at: new Date().toISOString()
    });

    if (error) {
      console.warn(`⚠️ Error importando producto ${prod.nombre}:`, error);
    } else {
      console.log(`✓ ${prod.nombre}`);
    }
  }
}

async function migrarVariantes(variantes) {
  console.log(`Migrando ${variantes.length} variantes...`);
  
  for (const var_item of variantes) {
    const { error } = await sb.from('variantes').insert({
      id: var_item.id,
      producto_id: var_item.productoId,
      tipo: var_item.tipo || null,
      valor: var_item.valor || null,
      stock_total: var_item.stockTotal || 0,
      created_at: new Date().toISOString()
    });

    if (error) {
      console.warn(`⚠️ Error importando variante ${var_item.id}:`, error);
    }
  }
  
  console.log(`✓ ${variantes.length} variantes importadas`);
}

async function migrarCajas(cajas) {
  console.log(`Migrando ${cajas.length} cajas...`);
  
  for (const caja of cajas) {
    const { error } = await sb.from('cajas').insert({
      id: caja.id,
      variante_id: caja.varianteId,
      codigo: caja.codigo,
      cantidad: caja.cantidad || 0,
      pale_id: caja.paleId || null,
      es_suelto: caja.esSuelto || false,
      created_at: new Date().toISOString()
    });

    if (error) {
      console.warn(`⚠️ Error importando caja ${caja.codigo}:`, error);
    }
  }
  
  console.log(`✓ ${cajas.length} cajas importadas`);
}

async function migrarPales(pales) {
  console.log(`Migrando ${pales.length} palés...`);
  
  for (const pale of pales) {
    const { error } = await sb.from('pales').insert({
      id: pale.id,
      codigo: pale.codigo,
      ubicacion: pale.ubicacion || null,
      descripcion: pale.descripcion || null,
      created_at: new Date().toISOString()
    });

    if (error) {
      console.warn(`⚠️ Error importando palé ${pale.codigo}:`, error);
    }
  }
  
  console.log(`✓ ${pales.length} palés importados`);
}

async function migrarSalidas(salidas) {
  console.log(`Migrando ${salidas.length} salidas...`);
  
  for (const salida of salidas) {
    // Insertar salida principal
    const { data: salidaCreada, error: errorSalida } = await sb
      .from('salidas')
      .insert({
        id: salida.id,
        tipo: salida.tipo || 'otro',
        destinatario: salida.destinatario || null,
        fecha_salida: salida.fechaSalida || null,
        fecha_devolucion: salida.fechaDevolucion || null,
        estado: salida.estado || 'pendiente',
        notas: salida.notas || null,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (errorSalida) {
      console.warn(`⚠️ Error importando salida ${salida.id}:`, errorSalida);
      continue;
    }

    // Insertar líneas de salida (si existen)
    if (salida.lineas && Array.isArray(salida.lineas)) {
      for (const linea of salida.lineas) {
        const { error: errorLinea } = await sb.from('salida_lineas').insert({
          salida_id: salida.id,
          variante_id: linea.productoId || linea.varianteId,
          cantidad: linea.cantidad || 0,
          created_at: new Date().toISOString()
        });

        if (errorLinea) {
          console.warn(`⚠️ Error importando línea de salida:`, errorLinea);
        }
      }
    }
  }
  
  console.log(`✓ ${salidas.length} salidas importadas`);
}

async function migrarCategorias(categorias) {
  console.log(`Migrando ${categorias.length} categorías...`);
  
  for (const cat of categorias) {
    // Insertar categoría
    const { data: catCreada, error: errorCat } = await sb
      .from('categorias')
      .insert({
        id: cat.id,
        nombre: cat.nombre,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (errorCat) {
      console.warn(`⚠️ Error importando categoría ${cat.nombre}:`, errorCat);
      continue;
    }

    // Insertar subcategorías
    if (cat.subcategorias && Array.isArray(cat.subcategorias)) {
      for (const subcat of cat.subcategorias) {
        const { error: errorSubcat } = await sb.from('subcategorias').insert({
          categoria_id: cat.id,
          nombre: subcat.nombre,
          created_at: new Date().toISOString()
        });

        if (errorSubcat) {
          console.warn(`⚠️ Error importando subcategoría ${subcat.nombre}:`, errorSubcat);
        }
      }
    }
  }
  
  console.log(`✓ ${categorias.length} categorías importadas`);
}

// ============================================
// INSTRUCCIONES
// ============================================

console.log(`
╔════════════════════════════════════════════════════════════╗
║          MIGRACIÓN MADRID v1 → v2 (Supabase)              ║
╚════════════════════════════════════════════════════════════╝

PASO 1: En la app v1 (localStorage)
────────────────────────────────────
1. Abre la consola: F12 → Tab "Console"
2. Copia TODO este código
3. Pégalo en la consola
4. Ejecuta: exportarParaMigracion()
5. Se copiará automáticamente al portapapeles

PASO 2: En admin.html v2 (Supabase)
─────────────────────────────────────
1. Abre admin.html (no la app normal)
2. Ve a "Importar datos"
3. Pega el JSON que copiaste
4. Click "Importar datos"
5. Espera a que termine

✅ Listo!
`);
