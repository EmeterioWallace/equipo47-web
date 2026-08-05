// ===== CARGA DEL CATÁLOGO DESDE catalogo_web (Supabase) =====
//
// NOTA sobre el futuro selector de cantidad (todavía no construido):
// la función RPC calcular_precio_publico(p_producto_id, p_cantidad) NO
// devuelve un número suelto. Devuelve un array con un solo objeto:
//   [{ precio: 5.5, aproximado: false }]
// Hay que desestructurar así:
//   const { data } = await sb.rpc('calcular_precio_publico', {...});
//   const { precio, aproximado } = data[0] || {};
// Si `aproximado` es true, aplicar la misma regla que en las tarjetas:
// mostrar "Precio orientativo" sin mencionar el tramo.
//
// Este módulo sustituye al array `products` escrito a mano en tienda.js.
// Mientras Producciones no tenga el script ejecutado en Supabase real,
// SUPABASE_CATALOGO_ACTIVO se queda en false y se usan los datos de
// prueba locales (catalogo-web-mock.json), con la MISMA forma exacta que
// tendrán los datos reales, para poder probar la web sin depender de
// que el otro lado esté ya conectado.
//
// Cuando Producciones confirme que el script ya está ejecutado:
//   1. Rellenar SUPABASE_URL y SUPABASE_ANON_KEY más abajo (la clave
//      "anon" es segura de exponer en el navegador, no es la de servicio).
//   2. Cambiar SUPABASE_CATALOGO_ACTIVO a true.
// No hace falta tocar nada más: el resto del código funciona igual con
// datos reales o de prueba, porque ambos pasan por el mismo adaptador.

const SUPABASE_CATALOGO_ACTIVO = true; // conectado a datos reales de Producciones
const SUPABASE_URL = 'https://ciszgyorsveumnrtcejn.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpc3pneW9yc3ZldW1ucnRjZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3ODk0MDYsImV4cCI6MjA5NzM2NTQwNn0.O56WDFFdtZMc1mXpgCEkgQF8ZTT5tnCpzg8xN4H_qK8';

const RUTA_IMAGENES_BASE = 'images/products/';
const RUTA_MOCK_LOCAL = 'prototipo-catalogo/data/catalogo-web-mock.json';

// Convierte el precio numérico (o null) al formato que ya usa la web:
// "7,70 €" o el literal "Consultar".
function formatearPrecio(precioFinal) {
    if (precioFinal === null || precioFinal === undefined) return 'Consultar';
    return precioFinal.toFixed(2).replace('.', ',') + ' €';
}

// Adapta una fila de catalogo_web al formato interno que ya usan
// createProductCard, renderProducts, openProductModal, etc. en tienda.js.
// Si algo de este mapeo cambia el día que Producciones ajuste el
// esquema real, este es el único sitio que hay que tocar.
function adaptarProductoDesdeCatalogoWeb(fila) {
    const colores = (fila.colores || []).map(c => ({
        name: c.nombre,
        hex: resolverHexDeColor(c.nombre),
        image: RUTA_IMAGENES_BASE + c.imagen
    }));

    return {
        id: fila.id,
        title: fila.titulo,
        description: fila.descripcion || '',
        specifications: fila.especificaciones || [],
        details: fila.detalles || [],
        options: fila.opciones || [],
        sport: fila.sport,
        category: fila.category,
        subcategory: fila.subcategory,
        gender: fila.gender,
        moq: fila.moq,
        image: RUTA_IMAGENES_BASE + fila.image,
        price: formatearPrecio(fila.precio_final),
        // precio_aproximado: pendiente de que Producciones lo añada a la
        // vista (ver nota-actualizacion-tramos-precio.md). Si no viene en
        // la fila, se asume false para no romper nada mientras tanto.
        approxPrice: fila.precio_aproximado === true,
        colors: colores
    };
}

async function cargarDesdeMock() {
    const res = await fetch(RUTA_MOCK_LOCAL);
    if (!res.ok) throw new Error('No se pudo cargar el catálogo de prueba: ' + res.status);
    const filas = await res.json();
    console.info(`ℹ️ Catálogo de PRUEBA cargado (${filas.length} productos) — SUPABASE_CATALOGO_ACTIVO está en false`);
    return filas;
}

async function cargarDesdeSupabase() {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
        throw new Error('SUPABASE_URL / SUPABASE_ANON_KEY no configurados todavía');
    }
    const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data, error } = await sb.from('catalogo_web').select('*');
    if (error) throw error;
    console.info(`ℹ️ Catálogo REAL cargado desde Supabase (${data.length} productos)`);
    return data;
}

// Punto de entrada: devuelve la lista de productos ya adaptada,
// lista para usar exactamente como se usaba el array `products` de antes.
async function cargarCatalogoWeb() {
    try {
        const filas = SUPABASE_CATALOGO_ACTIVO
            ? await cargarDesdeSupabase()
            : await cargarDesdeMock();
        return filas.map(adaptarProductoDesdeCatalogoWeb);
    } catch (err) {
        console.error('❌ Error cargando el catálogo:', err);
        return [];
    }
}
