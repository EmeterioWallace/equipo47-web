// =========================================================================
// Portada nueva (inicio-nuevo.html): categorías y productos destacados
// en vivo desde Producciones. Usa catalogo-web.js (mismos datos que la tienda).
//
// - Categorías: deportes de categorias_web_publica (nivel 1) en el orden de
//   Producciones. Con productos → tarjeta; en "Próximamente" → etiqueta.
//   Foto de la tarjeta: imagen_portada de la categoría (la elige Fátima) o,
//   si está vacía, la del primer producto con foto en el orden de la tienda.
//   Un deporte activo sin productos publicados no se muestra.
// - Destacados: productos con destacado_web = true, en el orden que pone Fátima
//   (orden_destacado). Se enseñan los 4 primeros; si no hay ninguno, la sección
//   se oculta. Ver INTEGRACION_PRODUCCIONES.md (script 37).
// =========================================================================

const MAX_DESTACADOS = 4;
const URL_TIENDA = 'tienda-prototipo.html';

function escaparHtml(texto) {
    return String(texto ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function tieneFotoReal(p) {
    return p.image && !p.image.includes('placeholder-proximamente');
}

// Árbol mínimo: posición global de cada categoría y su deporte (raíz).
function prepararCategorias(lista) {
    const ordenadas = lista.slice().sort((a, b) =>
        (a.nivel - b.nivel) || ((a.orden ?? 0) - (b.orden ?? 0)) || String(a.nombre).localeCompare(String(b.nombre), 'es'));
    const porId = new Map(ordenadas.map(c => [c.id, c]));
    const rango = new Map(ordenadas.map((c, i) => [c.id, i]));
    const ruta = (id) => {
        const r = [];
        let c = porId.get(id);
        while (c) { r.unshift(c.id); c = c.padre_id ? porId.get(c.padre_id) : null; }
        return r;
    };
    const deportes = ordenadas.filter(c => !c.padre_id);
    return { ordenadas, porId, rango, ruta, deportes };
}

// Ruta de categorías de un producto (con respaldo por slug, como en la tienda).
function rutaDeProducto(p, arbol) {
    if (p.categoriaId && arbol.porId.has(p.categoriaId)) return arbol.ruta(p.categoriaId);
    const deporte = arbol.deportes.find(d => d.slug === p.sport);
    return deporte ? [deporte.id] : [];
}

function compararProductos(arbol) {
    return (a, b) => {
        const largo = Math.max(a._ruta.length, b._ruta.length);
        for (let i = 0; i < largo; i++) {
            const ra = a._ruta[i] === undefined ? -1 : arbol.rango.get(a._ruta[i]);
            const rb = b._ruta[i] === undefined ? -1 : arbol.rango.get(b._ruta[i]);
            if (ra !== rb) return ra - rb;
        }
        const oa = a.ordenWeb === null ? Infinity : a.ordenWeb;
        const ob = b.ordenWeb === null ? Infinity : b.ordenWeb;
        if (oa !== ob) return oa - ob;
        return String(a.title).localeCompare(String(b.title), 'es');
    };
}

// Respaldo si categorias_web_publica no responde: deportes deducidos de los productos.
function categoriasDesdeProductos(productos) {
    const vistos = new Map();
    productos.forEach(p => {
        if (p.sport && !vistos.has(p.sport)) {
            vistos.set(p.sport, { id: 'deporte:' + p.sport, slug: p.sport, nombre: p.sport.charAt(0).toUpperCase() + p.sport.slice(1), padre_id: null, nivel: 1, orden: vistos.size, proximamente: false });
        }
    });
    return [...vistos.values()];
}

function pintarCategorias(arbol, productos) {
    const contenedor = document.getElementById('n-categorias');
    const proximas = document.getElementById('n-proximamente');
    if (!contenedor) return;

    const tarjetas = [];
    const etiquetas = [];
    arbol.deportes.forEach(d => {
        if (d.proximamente) { etiquetas.push(d); return; }
        const suyos = productos.filter(p => p._ruta[0] === d.id);
        if (suyos.length === 0) return;
        // Foto elegida por Fátima en Producciones (imagen_portada); si no hay, la del primer producto con foto.
        const elegida = d.imagen_portada ? resolverRutaImagen(d.imagen_portada) : null;
        const foto = (elegida && !elegida.includes('placeholder-proximamente'))
            ? { image: elegida }
            : suyos.slice().sort(compararProductos(arbol)).find(tieneFotoReal);
        tarjetas.push({ deporte: d, total: suyos.length, foto });
    });

    contenedor.innerHTML = tarjetas.map(({ deporte, total, foto }) => `
        <a class="n-categoria" href="${URL_TIENDA}?categoria=${encodeURIComponent(deporte.slug)}">
            <div class="n-categoria-texto">
                <p class="n-etiqueta">${total} ${total === 1 ? 'producto' : 'productos'}</p>
                <h3>${escaparHtml(deporte.nombre)} <span class="n-flecha" aria-hidden="true">→</span></h3>
            </div>
            ${foto ? `<img src="${escaparHtml(foto.image)}" alt="" loading="lazy">` : ''}
        </a>`).join('') || '<p class="n-cargando">El catálogo se está actualizando. <a href="' + URL_TIENDA + '">Ver la tienda</a>.</p>';

    if (proximas) {
        proximas.innerHTML = etiquetas.map(d => `<li>${escaparHtml(d.nombre)} · Próximamente</li>`).join('');
        proximas.hidden = etiquetas.length === 0;
    }
}

// Orden de los destacados (acordado con Producciones, 17/11): orden_destacado
// ascendente; los que no lo tienen, al final y por título.
function compararDestacados(a, b) {
    const oa = a.ordenDestacado === null ? Infinity : a.ordenDestacado;
    const ob = b.ordenDestacado === null ? Infinity : b.ordenDestacado;
    if (oa !== ob) return oa - ob;
    return String(a.title).localeCompare(String(b.title), 'es');
}

function pintarDestacados(arbol, productos) {
    const contenedor = document.getElementById('n-destacados');
    if (!contenedor) return;
    const seccion = contenedor.closest('section');

    // Producciones avisa si hay más de 4, pero no lo impide: se enseñan los 4 primeros.
    const destacados = productos.filter(p => p.destacado === true).sort(compararDestacados).slice(0, MAX_DESTACADOS);

    // Sin destacados elegidos, la sección no se muestra (mejor que una fila vacía).
    if (destacados.length === 0) {
        if (seccion) seccion.hidden = true;
        return;
    }
    if (seccion) seccion.hidden = false;

    contenedor.innerHTML = destacados.map(p => {
        const categorias = p._ruta.map(id => (arbol.porId.get(id) || {}).nombre).filter(Boolean);
        const etiqueta = categorias.slice(0, 2).join(' · ');
        const minimo = p.moq ? `Pedido mínimo: ${Number(p.moq).toLocaleString('es-ES')} uds` : 'Personalizable';
        return `
        <a class="n-producto" href="${URL_TIENDA}?producto=${encodeURIComponent(p.id)}">
            <img src="${escaparHtml(p.image)}" alt="${escaparHtml(p.title)}" loading="lazy">
            <div class="n-producto-info">
                <p class="n-etiqueta">${escaparHtml(etiqueta)}</p>
                <h3>${escaparHtml(p.title)}</h3>
                <p class="n-producto-mas">${minimo}</p>
            </div>
        </a>`;
    }).join('');
}

async function iniciarPortadaNueva() {
    let productos = [];
    let listaCategorias = [];
    try {
        [productos, listaCategorias] = await Promise.all([cargarCatalogoWeb(), cargarCategoriasWeb()]);
    } catch (err) {
        console.error('❌ Portada: error cargando el catálogo', err);
    }

    if (!productos || productos.length === 0) {
        const aviso = `<p class="n-cargando">No se pudo cargar el catálogo ahora mismo. <a href="${URL_TIENDA}">Ver la tienda</a>.</p>`;
        document.getElementById('n-categorias').innerHTML = aviso;
        document.getElementById('n-destacados').innerHTML = '';
        return;
    }

    const arbol = prepararCategorias(listaCategorias.length ? listaCategorias : categoriasDesdeProductos(productos));
    productos.forEach(p => { p._ruta = rutaDeProducto(p, arbol); });
    const visibles = productos.filter(p => p._ruta.length > 0);

    pintarCategorias(arbol, visibles);
    pintarDestacados(arbol, visibles);
    console.log(`✅ Portada nueva: ${visibles.length} productos, ${arbol.deportes.length} deportes${listaCategorias.length ? ' (Supabase)' : ' (deducidos)'}`);
}

document.addEventListener('DOMContentLoaded', iniciarPortadaNueva);
