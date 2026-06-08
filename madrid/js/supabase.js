// ============================================
// SUPABASE CLIENT - ALMACÉN MADRID v2
// ============================================

const SUPABASE_URL = 'https://dhbaeemqfctfzsuvddhi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYmFlZW1xZmN0ZnpzdXZkZGhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MDM5MzgsImV4cCI6MjA5NjQ3OTkzOH0.o3zYvEg_soASq7oK1HzIeuesiWFsZhHKTZggq92Qo08';

// Inicializar cliente Supabase
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Hacer accesible globalmente (para consola y otros scripts)
window.sb = sb;

// ============================================
// FUNCIONES GLOBALES DE SUPABASE
// ============================================

// Obtener todos los productos
async function obtenerProductos() {
  const { data, error } = await sb.from('productos').select('*');
  if (error) {
    console.error('Error obteniendo productos:', error);
    return [];
  }
  return data || [];
}

// Obtener variantes de un producto
async function obtenerVariantes(productoId = null) {
  let query = sb.from('variantes').select('*');
  if (productoId) {
    query = query.eq('producto_id', productoId);
  }
  const { data, error } = await query;
  if (error) {
    console.error('Error obteniendo variantes:', error);
    return [];
  }
  return data || [];
}

// Obtener cajas
async function obtenerCajas(varianteId = null) {
  let query = sb.from('cajas').select('*');
  if (varianteId) {
    query = query.eq('variante_id', varianteId);
  }
  const { data, error } = await query;
  if (error) {
    console.error('Error obteniendo cajas:', error);
    return [];
  }
  return data || [];
}

// Obtener palés
async function obtenerPales() {
  const { data, error } = await sb.from('pales').select('*');
  if (error) {
    console.error('Error obteniendo palés:', error);
    return [];
  }
  return data || [];
}

// Obtener salidas
async function obtenerSalidas(estado = null) {
  let query = sb.from('salidas').select('*').order('created_at', { ascending: false });
  if (estado) {
    query = query.eq('estado', estado);
  }
  const { data, error } = await query;
  if (error) {
    console.error('Error obteniendo salidas:', error);
    return [];
  }
  return data || [];
}

// Obtener líneas de una salida
async function obtenerSalidaLineas(salidaId) {
  const { data, error } = await sb
    .from('salida_lineas')
    .select('*, variantes(tipo, valor, producto_id, productos(nombre))')
    .eq('salida_id', salidaId);
  if (error) {
    console.error('Error obteniendo líneas de salida:', error);
    return [];
  }
  return data || [];
}

// Obtener ubicaciones
async function obtenerUbicaciones() {
  const { data, error } = await sb.from('ubicaciones').select('*');
  if (error) {
    console.error('Error obteniendo ubicaciones:', error);
    return [];
  }
  return data || [];
}

// Obtener categorías
async function obtenerCategorias() {
  const { data, error } = await sb.from('categorias').select('*');
  if (error) {
    console.error('Error obteniendo categorías:', error);
    return [];
  }
  return data || [];
}

// ============================================
// FUNCIONES DE INSERCIÓN
// ============================================

async function crearProducto(nombre, descripcion, categoriaId, foto_url) {
  const { data, error } = await sb.from('productos').insert({
    nombre,
    descripcion,
    categoria_id: categoriaId,
    foto_url
  }).select().single();
  if (error) {
    console.error('Error creando producto:', error);
    return null;
  }
  return data;
}

async function crearVariante(productoId, tipo, valor) {
  const { data, error } = await sb.from('variantes').insert({
    producto_id: productoId,
    tipo,
    valor,
    stock_total: 0
  }).select().single();
  if (error) {
    console.error('Error creando variante:', error);
    return null;
  }
  return data;
}

async function crearCaja(varianteId, codigo, cantidad, paleId, esSuelto = false) {
  const { data, error } = await sb.from('cajas').insert({
    variante_id: varianteId,
    codigo,
    cantidad,
    pale_id: paleId,
    es_suelto: esSuelto
  }).select().single();
  if (error) {
    console.error('Error creando caja:', error);
    return null;
  }
  return data;
}

async function crearPale(codigo, ubicacion, descripcion) {
  const { data, error } = await sb.from('pales').insert({
    codigo,
    ubicacion,
    descripcion
  }).select().single();
  if (error) {
    console.error('Error creando palé:', error);
    return null;
  }
  return data;
}

async function crearSalida(tipo, destinatario, fechaSalida, fechaDevolucion, notas) {
  const { data, error } = await sb.from('salidas').insert({
    tipo,
    destinatario,
    fecha_salida: fechaSalida,
    fecha_devolucion: fechaDevolucion,
    notas,
    estado: 'pendiente'
  }).select().single();
  if (error) {
    console.error('Error creando salida:', error);
    return null;
  }
  return data;
}

async function crearSalidaLinea(salidaId, varianteId, cantidad) {
  const { data, error } = await sb.from('salida_lineas').insert({
    salida_id: salidaId,
    variante_id: varianteId,
    cantidad
  }).select().single();
  if (error) {
    console.error('Error creando línea de salida:', error);
    return null;
  }
  return data;
}

// ============================================
// FUNCIONES DE ACTUALIZACIÓN
// ============================================

async function actualizarProducto(id, updates) {
  const { data, error } = await sb.from('productos').update(updates).eq('id', id).select().single();
  if (error) {
    console.error('Error actualizando producto:', error);
    return null;
  }
  return data;
}

async function actualizarVariante(id, updates) {
  const { data, error } = await sb.from('variantes').update(updates).eq('id', id).select().single();
  if (error) {
    console.error('Error actualizando variante:', error);
    return null;
  }
  return data;
}

async function actualizarCaja(id, updates) {
  const { data, error } = await sb.from('cajas').update(updates).eq('id', id).select().single();
  if (error) {
    console.error('Error actualizando caja:', error);
    return null;
  }
  return data;
}

async function actualizarSalida(id, updates) {
  const { data, error } = await sb.from('salidas').update(updates).eq('id', id).select().single();
  if (error) {
    console.error('Error actualizando salida:', error);
    return null;
  }
  return data;
}

// ============================================
// FUNCIONES DE ELIMINACIÓN
// ============================================

async function eliminarProducto(id) {
  const { error } = await sb.from('productos').delete().eq('id', id);
  if (error) {
    console.error('Error eliminando producto:', error);
    return false;
  }
  return true;
}

async function eliminarVariante(id) {
  const { error } = await sb.from('variantes').delete().eq('id', id);
  if (error) {
    console.error('Error eliminando variante:', error);
    return false;
  }
  return true;
}

async function eliminarCaja(id) {
  const { error } = await sb.from('cajas').delete().eq('id', id);
  if (error) {
    console.error('Error eliminando caja:', error);
    return false;
  }
  return true;
}

async function eliminarSalida(id) {
  const { error } = await sb.from('salidas').delete().eq('id', id);
  if (error) {
    console.error('Error eliminando salida:', error);
    return false;
  }
  return true;
}

// ============================================
// TEST DE CONEXIÓN
// ============================================

async function testConexionSupabase() {
  try {
    const { error } = await sb.from('productos').select('id', { count: 'exact', head: true });
    if (error) {
      console.error('❌ Error de conexión a Supabase:', error);
      return false;
    }
    console.log('✅ Conexión a Supabase exitosa');
    return true;
  } catch (e) {
    console.error('❌ Error al conectar con Supabase:', e);
    return false;
  }
}

// Test automático al cargar
document.addEventListener('DOMContentLoaded', async () => {
  if (document.querySelector('[data-test-supabase]')) {
    await testConexionSupabase();
  }
});
