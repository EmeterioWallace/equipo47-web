// =====================================================
// EQUIPO 47 - White Label Platform
// Main JavaScript with Real Color Variants
// =====================================================

// ===== SMOOTH SCROLL FOR NAVIGATION =====
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            const offsetTop = target.offsetTop - 80;
            window.scrollTo({
                top: offsetTop,
                behavior: 'smooth'
            });
        }
    });
});

// ===== NAVIGATION SCROLL EFFECT =====
let lastScroll = 0;
const nav = document.querySelector('.nav');

window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;
    
    if (nav) {
        nav.style.boxShadow = currentScroll > 100 ? '0 2px 20px rgba(0,0,0,0.1)' : 'none';
    }
    
    lastScroll = currentScroll;
});

// ===== MOBILE MENU TOGGLE =====
const navToggle = document.querySelector('.nav-toggle');
const navMenu = document.querySelector('.nav-menu');

if (navToggle && navMenu) {
    // Abrir/cerrar menú al hacer click en hamburguesa
    navToggle.addEventListener('click', (e) => {
        e.stopPropagation();
        navMenu.classList.toggle('active');
        navToggle.classList.toggle('active');
    });
    
    // Cerrar menú al hacer click en un enlace
    const menuLinks = navMenu.querySelectorAll('a');
    menuLinks.forEach(link => {
        link.addEventListener('click', () => {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        });
    });
    
    // Cerrar menú al hacer click fuera
    document.addEventListener('click', (e) => {
        if (!navMenu.contains(e.target) && !navToggle.contains(e.target)) {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        }
    });
}

// ===== PRODUCT DATA WITH REAL COLOR VARIANTS =====
let products = []; // se rellena de forma asíncrona desde catalogo-web.js, ver INITIALIZATION al final

// ===== PRODUCT DISPLAY & FILTERING =====
// Las categorías NO están escritas aquí: vienen de la vista
// categorias_web_publica, que Fátima gestiona desde Producciones
// (crear, renombrar, ordenar, "Próximamente"). Ver INTEGRACION_PRODUCCIONES.md.
const productsGrid = document.querySelector('.products-grid');
const genderFilters = document.querySelectorAll('.gender-filter');
const searchInput = document.getElementById('product-search');
const sportFiltersContainer = document.querySelector('.sport-filters-section .filters');
const subcategoryFiltersSection = document.getElementById('subcategory-filters');
let currentGender = 'todos'; // Por defecto todos los géneros
let currentSearchTerm = ''; // Término de búsqueda

// Ruta de categorías seleccionada: [deporte, tipo?, subcategoría?] (ids).
// Mostrar una categoría incluye todos los productos de sus descendientes.
let rutaSeleccionada = [];

// Árbol de categorías (se rellena en la inicialización)
let categorias = [];                 // ordenadas por nivel, orden, nombre
const categoriaPorId = new Map();    // id -> categoría
const hijosPorId = new Map();        // id (o 'raiz') -> [categorías hijas, en orden]
const rangoPorId = new Map();        // id -> posición global (para ordenar productos)

function prepararArbolCategorias(lista) {
    categorias = lista.slice().sort((a, b) =>
        (a.nivel - b.nivel) || ((a.orden ?? 0) - (b.orden ?? 0)) || String(a.nombre).localeCompare(String(b.nombre), 'es')
    );
    categoriaPorId.clear();
    hijosPorId.clear();
    rangoPorId.clear();
    categorias.forEach((c, i) => {
        categoriaPorId.set(c.id, c);
        rangoPorId.set(c.id, i);
        const clavePadre = c.padre_id || 'raiz';
        if (!hijosPorId.has(clavePadre)) hijosPorId.set(clavePadre, []);
        hijosPorId.get(clavePadre).push(c);
    });
}

// Respaldo: si categorias_web_publica no responde (o se usan datos de prueba),
// se deduce un árbol de dos niveles a partir de sport/subcategory de los productos,
// en el orden en que aparecen. No hay "Próximamente" en este modo.
function construirCategoriasDesdeProductos(lista) {
    const resultado = [];
    const vistos = new Set();
    lista.forEach(p => {
        if (!p.sport) return;
        const idDeporte = 'deporte:' + p.sport;
        if (!vistos.has(idDeporte)) {
            vistos.add(idDeporte);
            resultado.push({ id: idDeporte, slug: p.sport, nombre: capitalizar(p.sport), padre_id: null, nivel: 1, orden: resultado.length, proximamente: false });
        }
        if (p.subcategory) {
            const idSub = idDeporte + '/' + p.subcategory;
            if (!vistos.has(idSub)) {
                vistos.add(idSub);
                resultado.push({ id: idSub, slug: p.subcategory, nombre: capitalizar(p.subcategory.replace(/-/g, ' ')), padre_id: idDeporte, nivel: 2, orden: resultado.length, proximamente: false });
            }
        }
    });
    return resultado;
}

function capitalizar(texto) {
    return texto ? texto.charAt(0).toUpperCase() + texto.slice(1) : '';
}

// Categoría del producto dentro del árbol cargado. Usa categoria_id y, si el
// producto no lo tiene, intenta encontrarla por los slugs de compatibilidad.
function categoriaDeProducto(p) {
    if (p.categoriaId && categoriaPorId.has(p.categoriaId)) return p.categoriaId;
    const deporte = (hijosPorId.get('raiz') || []).find(c => c.slug === p.sport);
    if (!deporte) return null;
    if (!p.subcategory) return deporte.id;
    const buscarEn = (padreId, profundidad) => {
        for (const hijo of hijosPorId.get(padreId) || []) {
            if (hijo.slug === p.subcategory) return hijo.id;
            if (profundidad < 2) {
                const encontrado = buscarEn(hijo.id, profundidad + 1);
                if (encontrado) return encontrado;
            }
        }
        return null;
    };
    return buscarEn(deporte.id, 1) || deporte.id;
}

// Ids de la categoría y de todos sus antepasados, de la raíz hacia abajo.
function rutaDeCategoria(id) {
    const ruta = [];
    let actual = categoriaPorId.get(id);
    while (actual) {
        ruta.unshift(actual.id);
        actual = actual.padre_id ? categoriaPorId.get(actual.padre_id) : null;
    }
    return ruta;
}

// Se calcula una vez tras cargar: ruta de categorías de cada producto.
function asignarRutasAProductos() {
    products.forEach(p => {
        const id = categoriaDeProducto(p);
        p._ruta = id ? rutaDeCategoria(id) : [];
    });
}

function productosDeCategoria(id) {
    return products.filter(p => p._ruta.includes(id));
}

// Una categoría se muestra si está en "Próximamente" (botón deshabilitado)
// o si tiene productos. Así una categoría recién creada aparece en la tienda
// en cuanto Fátima le publica el primer producto, y no antes.
function categoriaVisible(c) {
    return c.proximamente || productosDeCategoria(c.id).length > 0;
}

// Orden: primero por la posición de cada categoría de la ruta (orden de
// Fátima, de deporte a subcategoría), después por orden_web y por último
// por título.
function compararProductos(a, b) {
    const largo = Math.max(a._ruta.length, b._ruta.length);
    for (let i = 0; i < largo; i++) {
        const ra = a._ruta[i] === undefined ? -1 : rangoPorId.get(a._ruta[i]);
        const rb = b._ruta[i] === undefined ? -1 : rangoPorId.get(b._ruta[i]);
        if (ra !== rb) return ra - rb;
    }
    const oa = a.ordenWeb === null ? Infinity : a.ordenWeb;
    const ob = b.ordenWeb === null ? Infinity : b.ordenWeb;
    if (oa !== ob) return oa - ob;
    return String(a.title).localeCompare(String(b.title), 'es');
}


// Botones de deporte (nivel 1), en el orden de Producciones.
function renderSportFilters() {
    if (!sportFiltersContainer) return;
    sportFiltersContainer.innerHTML = '';

    // En la tienda solo deportes con productos; los "Próximamente" ya salen en la portada.
    (hijosPorId.get('raiz') || []).filter(c => !c.proximamente && productosDeCategoria(c.id).length > 0).forEach(deporte => {
        const button = document.createElement('button');
        button.type = 'button';
        const activo = rutaSeleccionada[0] === deporte.id;
        button.className = 'sport-filter n-chip' + (activo ? ' active' : '');
        button.setAttribute('aria-pressed', String(activo));
        button.dataset.categoriaId = deporte.id;
        button.dataset.sport = deporte.slug;
        button.textContent = deporte.nombre;
        button.addEventListener('click', () => seleccionarCategoria([deporte.id]));
        sportFiltersContainer.appendChild(button);
    });
}

// Filas de subcategorías: una por cada nivel bajo el deporte seleccionado
// (tipo y, si el tipo elegido se subdivide, subcategoría).
function renderSubcategoryFilters() {
    if (!subcategoryFiltersSection) return;
    const contenedor = subcategoryFiltersSection.querySelector('.filters');
    contenedor.innerHTML = '';

    let hayFilas = false;
    for (let nivel = 0; nivel < rutaSeleccionada.length && nivel < 2; nivel++) {
        const padreId = rutaSeleccionada[nivel];
        const hijos = (hijosPorId.get(padreId) || []).filter(categoriaVisible);
        if (hijos.length === 0) break;

        hayFilas = true;
        const fila = document.createElement('div');
        fila.className = 'n-fila-chips';
        const seleccionadoEnFila = rutaSeleccionada[nivel + 1];

        const crearBoton = (texto, activo, onClick, deshabilitado) => {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'subcategory-filter n-chip n-chip-sub' + (activo ? ' active' : '');
            b.setAttribute('aria-pressed', String(!!activo));
            b.textContent = texto;
            if (deshabilitado) {
                b.disabled = true;
            } else {
                b.addEventListener('click', onClick);
            }
            return b;
        };

        const rutaHastaPadre = rutaSeleccionada.slice(0, nivel + 1);
        fila.appendChild(crearBoton('Todas', !seleccionadoEnFila, () => seleccionarCategoria(rutaHastaPadre)));
        hijos.forEach(hijo => {
            const texto = hijo.proximamente ? `${hijo.nombre} (Próximamente)` : hijo.nombre;
            fila.appendChild(crearBoton(texto, seleccionadoEnFila === hijo.id,
                () => seleccionarCategoria([...rutaHastaPadre, hijo.id]), hijo.proximamente));
        });
        contenedor.appendChild(fila);
    }

    subcategoryFiltersSection.style.display = hayFilas ? 'block' : 'none';
}

function seleccionarCategoria(ruta) {
    rutaSeleccionada = ruta;
    renderSportFilters();
    renderSubcategoryFilters();
    renderProducts();
}

// Enlaces desde la portada: ?categoria=<slug> abre esa categoría;
// ?producto=<id> abre su categoría y su ficha.
function aplicarParametrosDeUrl() {
    const params = new URLSearchParams(window.location.search);
    const slug = params.get('categoria');
    const productoId = params.get('producto');
    let aplicado = false;

    if (productoId) {
        const producto = products.find(p => String(p.id) === productoId);
        if (producto && producto._ruta.length) {
            seleccionarCategoria([producto._ruta[0]]);
            openProductModal(producto.id);
            aplicado = true;
        }
    } else if (slug) {
        const categoria = categorias.find(c => c.slug === slug && !c.proximamente);
        if (categoria) {
            const ruta = rutaDeCategoria(categoria.id);
            // Solo si la categoría (o su deporte) se ve en la tienda
            if (ruta.every(id => categoriaVisible(categoriaPorId.get(id)))) {
                seleccionarCategoria(ruta);
                aplicado = true;
            }
        }
    }

    if (aplicado && !productoId) {
        const catalogo = document.getElementById('catalog');
        if (catalogo) catalogo.scrollIntoView({ behavior: 'auto', block: 'start' });
    }
}

// Primer deporte en el orden de Producciones que no esté en "Próximamente"
// y tenga productos.
function deportePorDefecto() {
    const deporte = (hijosPorId.get('raiz') || []).find(c => !c.proximamente && productosDeCategoria(c.id).length > 0);
    return deporte ? deporte.id : null;
}

// ===== PRECIO DE REFERENCIA =====
// Decisión 25/11 (Guille y Alex): un solo precio por producto, el del pedido
// mínimo (precio_final de catalogo_web). Sin escala por cantidades en la web:
// el descuento por volumen va en el presupuesto. Ver INTEGRACION_PRODUCCIONES.md.
function formatoUnidades(n) {
    return Number(n).toLocaleString('es-ES');
}

function precioReferenciaHTML(product) {
    const hayPrecio = product.price && product.price !== 'Consultar';
    if (!hayPrecio) {
        return `<p class="product-price"><span class="price-amount price-consultar">Precio a consultar</span></p>`;
    }
    const nota = product.moq
        ? `${product.approxPrice ? 'orientativo · ' : ''}ref. ${formatoUnidades(product.moq)} uds · sin IVA`
        : (product.approxPrice ? 'orientativo · sin IVA' : 'sin IVA');
    return `<p class="product-price"><span class="price-amount">${product.price}</span><span class="price-ref">${nota}</span></p>`;
}

const MAX_COLORES_TARJETA = 6;

function escaparTexto(texto) {
    return String(texto ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function createProductCard(product) {
    const card = document.createElement('div');
    card.className = 'product-card';
    card.dataset.category = product.category;
    card.dataset.sport = product.sport;
    
    // Badge HTML
    const badgeHTML = product.badge ? `<span class="product-badge">${product.badge}</span>` : '';
    
    // Muestras de color: como mucho MAX_COLORES_TARJETA en la tarjeta; el resto, "+N" que abre la ficha.
    let colorDotsHTML = '';
    if (product.colors && product.colors.length > 0) {
        const visibles = product.colors.slice(0, MAX_COLORES_TARJETA);
        const resto = product.colors.length - visibles.length;
        colorDotsHTML = `
            <div class="product-colors">
                <span class="colors-label">Color: <strong class="color-nombre">${escaparTexto(product.colors[0].name)}</strong></span>
                <div class="color-swatches" role="group" aria-label="Colores de ${escaparTexto(product.title)}">
                    ${visibles.map((color, index) => `
                        <button type="button"
                            class="color-dot ${index === 0 ? 'active' : ''}"
                            style="--muestra: ${color.hex}"
                            data-product-id="${product.id}"
                            data-color-index="${index}"
                            data-color-name="${escaparTexto(color.name)}"
                            aria-label="${escaparTexto(color.name)}"
                            aria-pressed="${index === 0}"
                            title="${escaparTexto(color.name)}"></button>
                    `).join('')}
                    ${resto > 0 ? `<button type="button" class="color-mas" onclick="openProductModal('${product.id}')" aria-label="Ver los ${product.colors.length} colores">+${resto}</button>` : ''}
                </div>
            </div>
        `;
    }
    
    // Categoría visible (deporte · subcategoría) en el orden de Producciones
    const nombresCategorias = (product._ruta || []).map(id => (categoriaPorId.get(id) || {}).nombre).filter(Boolean);
    const etiquetaCategoria = nombresCategorias.slice(-2).join(' · ');

    // Segunda vista (MER001_2…) al pasar el ratón, si existe
    const segundaVista = product.views && product.views.length > 1 ? product.views[1] : null;
    const sinFoto = !product.image || product.image.includes('placeholder-proximamente');

    card.innerHTML = `
        ${badgeHTML}
        <div class="product-image${sinFoto ? ' sin-foto' : ''}${segundaVista ? ' con-segunda-vista' : ''}">
            ${sinFoto
                ? `<span class="product-sin-foto">Foto próximamente</span>`
                : `<img class="foto-principal" src="${product.image}" alt="${escaparTexto(product.title)}" loading="lazy">`}
            ${segundaVista && !sinFoto ? `<img class="foto-segunda" src="${segundaVista}" alt="" aria-hidden="true" loading="lazy">` : ''}
            <div class="product-overlay">
                <button class="btn-quick-view" type="button" onclick="openProductModal('${product.id}')">
                    Ver detalles
                </button>
            </div>
        </div>
        <div class="product-info">
            ${etiquetaCategoria ? `<p class="product-cat">${escaparTexto(etiquetaCategoria)}</p>` : ''}
            <h3 class="product-name"><button type="button" class="product-name-btn" onclick="openProductModal('${product.id}')">${escaparTexto(product.title)}</button></h3>
            ${precioReferenciaHTML(product)}
            ${colorDotsHTML}
        </div>
    `;
    
    return card;
}

// Pinta los productos según el estado actual (categoría, género y búsqueda).
function renderProducts() {
    if (!productsGrid) return;

    const gender = currentGender;
    const searchTerm = currentSearchTerm;

    productsGrid.innerHTML = '';

    // Filtrar por la categoría seleccionada (incluye sus subcategorías)
    const categoriaActual = rutaSeleccionada[rutaSeleccionada.length - 1];
    let filteredProducts = categoriaActual ? productosDeCategoria(categoriaActual) : [];

    // Filtrar por género
    if (gender !== 'todos') {
        filteredProducts = filteredProducts.filter(p => {
            // Si el producto tiene la propiedad gender, usarla
            if (p.gender) {
                if (gender === 'hombre') {
                    return p.gender === 'hombre' || p.gender === 'unisex';
                } else if (gender === 'mujer') {
                    return p.gender === 'mujer' || p.gender === 'unisex';
                } else if (gender === 'unisex') {
                    return p.gender === 'unisex';
                }
            }
            // Fallback: usar el título para productos sin propiedad gender
            const title = p.title.toLowerCase();
            if (gender === 'hombre') {
                return title.includes('hombre') || title.includes('masculin');
            } else if (gender === 'mujer') {
                return title.includes('mujer') || title.includes('femenin');
            } else if (gender === 'unisex') {
                return !title.includes('hombre') && !title.includes('mujer');
            }
            return true;
        });
    }
    
    // Filtrar por búsqueda
    if (searchTerm) {
        const term = searchTerm.toLowerCase();
        filteredProducts = filteredProducts.filter(p => {
            const nombresCategorias = p._ruta.map(id => (categoriaPorId.get(id) || {}).nombre || '').join(' ').toLowerCase();
            return p.title.toLowerCase().includes(term) ||
                   (p.description || '').toLowerCase().includes(term) ||
                   (p.category || '').toLowerCase().includes(term) ||
                   nombresCategorias.includes(term) ||
                   (p.options && p.options.some(opt => opt.toLowerCase().includes(term)));
        });
    }
    
    const contador = document.getElementById('n-contador');
    if (contador) contador.textContent = filteredProducts.length === 1 ? '1 producto' : `${filteredProducts.length} productos`;

    // Si no hay productos, mostrar mensaje
    if (filteredProducts.length === 0) {
        productsGrid.innerHTML = '<p class="no-products">No hay productos con estos filtros. Prueba con otra categoría o borra la búsqueda.</p>';
        return;
    }
    
    filteredProducts.slice().sort(compararProductos).forEach(product => {
        const card = createProductCard(product);
        productsGrid.appendChild(card);
    });
    
    // Re-attach color swatch event listeners
    attachColorSwatchListeners();
}

// ===== COLOR DOT FUNCTIONALITY =====
function attachColorSwatchListeners() {
    const colorDots = document.querySelectorAll('.color-dot');
    colorDots.forEach(dot => {
        dot.addEventListener('click', function(e) {
            e.stopPropagation();
            const productId = this.dataset.productId;
            const colorIndex = parseInt(this.dataset.colorIndex);
            changeProductColor(productId, colorIndex);
        });
    });
}

function changeProductColor(productId, colorIndex) {
    const product = products.find(p => p.id === productId);
    if (!product || !product.colors || !product.colors[colorIndex]) return;
    
    const newColor = product.colors[colorIndex];
    const card = document.querySelector(`.color-dot[data-product-id="${productId}"]`).closest('.product-card');
    
    if (card) {
        // Update image
        const img = card.querySelector('.product-image img.foto-principal');
        if (img && newColor.image) {
            img.src = newColor.image;
        }
        const zona = card.querySelector('.product-image');
        if (zona) zona.classList.toggle('con-segunda-vista', colorIndex === 0 && !!card.querySelector('.foto-segunda'));
        
        // Muestra activa y nombre del color elegido
        const dots = card.querySelectorAll('.color-dot');
        dots.forEach((d, i) => {
            d.classList.toggle('active', i === colorIndex);
            d.setAttribute('aria-pressed', String(i === colorIndex));
        });
        const nombre = card.querySelector('.color-nombre');
        if (nombre) nombre.textContent = newColor.name;
    }
}

// ===== FILTER BUTTONS =====
// Filtros de género (Todos, Hombre, Mujer, Unisex)
if (genderFilters.length > 0) {
    genderFilters.forEach(button => {
        button.addEventListener('click', () => {
            // Actualizar estilos de botones
            genderFilters.forEach(btn => {
                btn.classList.remove('active');
                btn.setAttribute('aria-pressed', 'false');
            });
            button.classList.add('active');
            button.setAttribute('aria-pressed', 'true');
            
            currentGender = button.dataset.gender;
            renderProducts();
        });
    });
}

// Filtros de deporte y subcategoría: se pintan desde categorias_web_publica
// (renderSportFilters / renderSubcategoryFilters, más arriba).

// Buscador de productos
if (searchInput) {
    searchInput.addEventListener('input', (e) => {
        currentSearchTerm = e.target.value.trim();
        renderProducts();
    });
    
    // Focus styles
    searchInput.addEventListener('focus', () => {
        searchInput.style.borderColor = '#FF4B1F';
    });
    
    searchInput.addEventListener('blur', () => {
        searchInput.style.borderColor = '#e0e0e0';
    });
}

// ===== PRODUCT MODAL =====
const modal = document.getElementById('productModal');
const modalClose = document.querySelector('.modal-close');
let currentModalProduct = null;
let currentModalColor = 0;
let currentModalViews = [];   // rutas de las vistas de la foto actual
let currentModalView = 0;     // índice de la vista mostrada

function openProductModal(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;

    currentModalProduct = product;
    currentModalColor = 0;
    currentModalView = 0;
    updateModalContent();
    
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function updateModalContent() {
    if (!currentModalProduct) return;
    
    const product = currentModalProduct;
    const currentColor = product.colors && product.colors[currentModalColor] 
        ? product.colors[currentModalColor] 
        : null;
    
    // Vistas de la foto actual: las del color elegido o, si no hay color, las del producto.
    // Si el color no tiene vistas propias, se usa su imagen sola.
    currentModalViews = currentColor
        ? (currentColor.views && currentColor.views.length ? currentColor.views : [currentColor.image])
        : (product.views && product.views.length ? product.views : [product.image]);
    if (currentModalView >= currentModalViews.length) currentModalView = 0;
    renderModalGallery();
    
    // Update title and description
    document.getElementById('modal-title').textContent = product.title;
    document.getElementById('modal-description').textContent = product.description;

    // Update price (antes era texto fijo que nunca se actualizaba)
    const hayPrecio = product.price && product.price !== 'Consultar';
    const priceLabel = !hayPrecio ? 'Precio' : (product.approxPrice ? 'Precio orientativo' : 'Precio de referencia');
    const priceValue = hayPrecio ? product.price : 'A consultar';
    document.getElementById('modal-price-label').textContent = priceLabel;
    document.getElementById('modal-price').textContent = priceValue;

    const moqEl = document.getElementById('modal-moq');
    if (moqEl) {
        moqEl.textContent = product.moq
            ? `Pedido mínimo: ${formatoUnidades(product.moq)} uds. ${hayPrecio ? 'Precio por unidad para el pedido mínimo, sin IVA. ' : ''}El precio final depende de la cantidad y la personalización: te lo damos en el presupuesto.`
            : '';
    }
    
    // Create color selector if product has colors
    let colorSelectorHTML = '';
    if (product.colors && product.colors.length > 0) {
        const elegido = product.colors[currentModalColor] || product.colors[0];
        colorSelectorHTML = `
            <div class="modal-colors">
                <h4>Color: <span class="modal-color-nombre">${escaparTexto(elegido.name)}</span></h4>
                <div class="modal-color-options" role="group" aria-label="Colores disponibles">
                    ${product.colors.map((color, index) => `
                        <button type="button"
                            class="modal-color-dot ${index === currentModalColor ? 'active' : ''}"
                            style="--muestra: ${color.hex}"
                            onclick="changeModalColor(${index})"
                            aria-label="${escaparTexto(color.name)}"
                            aria-pressed="${index === currentModalColor}"
                            title="${escaparTexto(color.name)}"></button>
                    `).join('')}
                </div>
            </div>
        `;
    }
    
    // Update modal info section
    const modalInfo = document.querySelector('.modal-info');
    const existingColors = modalInfo.querySelector('.modal-colors');
    if (existingColors) {
        existingColors.remove();
    }
    
    // Insert color selector after description
    const descElement = document.getElementById('modal-description');
    if (colorSelectorHTML) {
        descElement.insertAdjacentHTML('afterend', colorSelectorHTML);
    }
    
    // Add specifications if product has them
    let specificationsHTML = '';
    if (product.specifications && product.specifications.length > 0) {
        specificationsHTML = `
            <div class="modal-specifications">
                <h4>Especificaciones:</h4>
                <ul class="specifications-list">
                    ${product.specifications.map(spec => `<li>✓ ${spec}</li>`).join('')}
                </ul>
            </div>
        `;
    }
    
    // Add details if product has them
    let detailsHTML = '';
    if (product.details && product.details.length > 0) {
        detailsHTML = `
            <div class="modal-details">
                <h4>Detalles del pedido:</h4>
                <ul class="details-list">
                    ${product.details.map(detail => `<li>• ${detail}</li>`).join('')}
                </ul>
            </div>
        `;
    }
    
    // Remove existing specifications and details
    const existingSpecs = modalInfo.querySelector('.modal-specifications');
    const existingDetails = modalInfo.querySelector('.modal-details');
    if (existingSpecs) existingSpecs.remove();
    if (existingDetails) existingDetails.remove();
    
    // Insert specifications and details after colors (or description if no colors)
    const insertAfter = modalInfo.querySelector('.modal-colors') || descElement;
    if (specificationsHTML) {
        insertAfter.insertAdjacentHTML('afterend', specificationsHTML);
    }
    if (detailsHTML) {
        const insertAfterSpecs = modalInfo.querySelector('.modal-specifications') || insertAfter;
        insertAfterSpecs.insertAdjacentHTML('afterend', detailsHTML);
    }
    
    // Update options
    const optionsList = document.getElementById('modal-options');
    optionsList.innerHTML = '';
    product.options.forEach(option => {
        const span = document.createElement('span');
        span.className = 'option';
        span.textContent = option;
        optionsList.appendChild(span);
    });
}

function changeModalColor(colorIndex) {
    currentModalColor = colorIndex;
    currentModalView = 0; // cada color empieza por su primera vista
    updateModalContent();
}

// ===== CARRUSEL DE VISTAS EN LA FICHA =====
// Con una sola vista se ve la imagen tal cual, sin flechas ni miniaturas.
function renderModalGallery() {
    const galeria = document.querySelector('#productModal .modal-gallery');
    const modalImage = document.getElementById('modal-image');
    if (!galeria || !modalImage || !currentModalProduct) return;

    const total = currentModalViews.length;
    modalImage.src = currentModalViews[currentModalView];
    modalImage.alt = total > 1
        ? `${currentModalProduct.title} (vista ${currentModalView + 1} de ${total})`
        : currentModalProduct.title;

    galeria.querySelectorAll('.carrusel-flecha, .carrusel-miniaturas, .carrusel-contador').forEach(el => el.remove());
    galeria.classList.toggle('con-carrusel', total > 1);
    if (total <= 1) return;

    const crearFlecha = (sentido, etiqueta, simbolo) => {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = `carrusel-flecha carrusel-flecha-${sentido}`;
        b.setAttribute('aria-label', etiqueta);
        b.textContent = simbolo;
        b.addEventListener('click', (e) => { e.stopPropagation(); moverVistaModal(sentido === 'prev' ? -1 : 1); });
        return b;
    };
    galeria.appendChild(crearFlecha('prev', 'Vista anterior', '‹'));
    galeria.appendChild(crearFlecha('next', 'Vista siguiente', '›'));

    const contador = document.createElement('div');
    contador.className = 'carrusel-contador';
    contador.textContent = `${currentModalView + 1} / ${total}`;
    galeria.appendChild(contador);

    const miniaturas = document.createElement('div');
    miniaturas.className = 'carrusel-miniaturas';
    currentModalViews.forEach((ruta, i) => {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'carrusel-miniatura' + (i === currentModalView ? ' active' : '');
        b.setAttribute('aria-label', `Ver vista ${i + 1}`);
        const img = document.createElement('img');
        img.src = ruta;
        img.alt = '';
        img.loading = 'lazy';
        b.appendChild(img);
        b.addEventListener('click', (e) => { e.stopPropagation(); currentModalView = i; renderModalGallery(); });
        miniaturas.appendChild(b);
    });
    galeria.appendChild(miniaturas);
}

function moverVistaModal(paso) {
    const total = currentModalViews.length;
    if (total <= 1) return;
    currentModalView = (currentModalView + paso + total) % total;
    renderModalGallery();
}

function closeProductModal() {
    modal.classList.remove('active');
    document.body.style.overflow = '';
    currentModalProduct = null;
}

if (modalClose) {
    modalClose.addEventListener('click', closeProductModal);
}

if (modal) {
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            closeProductModal();
        }
    });
}

// Deslizar con el dedo para cambiar de vista (móvil)
(function () {
    const galeria = document.querySelector('#productModal .modal-gallery');
    if (!galeria) return;
    let inicioX = null;
    galeria.addEventListener('touchstart', (e) => { inicioX = e.touches[0].clientX; }, { passive: true });
    galeria.addEventListener('touchend', (e) => {
        if (inicioX === null) return;
        const dx = e.changedTouches[0].clientX - inicioX;
        inicioX = null;
        if (Math.abs(dx) > 40) moverVistaModal(dx < 0 ? 1 : -1);
    });
})();

document.addEventListener('keydown', (e) => {
    if (!modal.classList.contains('active')) return;
    if (e.key === 'Escape') closeProductModal();
    else if (e.key === 'ArrowLeft') moverVistaModal(-1);
    else if (e.key === 'ArrowRight') moverVistaModal(1);
});

// ===== CALCULADORA PÚBLICA =====
// Pendiente de integrar con la lógica de márgenes de producciones (ver 22_contexto_producciones.md).
// No reconstruir aquí una calculadora con precios propios.

// ===== FORM SUBMISSION =====
// Netlify handles form POST natively — browser validates required fields automatically

// ===== INTERSECTION OBSERVER FOR SCROLL ANIMATIONS =====
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

document.querySelectorAll('.process-step, .case-card').forEach(el => {
    observer.observe(el);
});

// ===== ACTIVE NAVIGATION HIGHLIGHT =====
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('.nav-menu a');

function highlightNavigation() {
    const scrollY = window.pageYOffset;
    
    sections.forEach(section => {
        const sectionHeight = section.offsetHeight;
        const sectionTop = section.offsetTop - 100;
        const sectionId = section.getAttribute('id');
        
        if (scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${sectionId}`) {
                    link.classList.add('active');
                }
            });
        }
    });
}

window.addEventListener('scroll', highlightNavigation);

// ===== PARALLAX EFFECT FOR HERO =====
const hero = document.querySelector('.hero');
if (hero) {
    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        const heroContent = hero.querySelector('.hero-content');
        if (heroContent && scrolled < 700) {
            heroContent.style.transform = `translateY(${scrolled * 0.3}px)`;
            heroContent.style.opacity = 1 - (scrolled / 700);
        }
    });
}

// ===== NUMBER ANIMATION FOR STATS =====
function animateValue(element, start, end, duration) {
    const range = end - start;
    const increment = range / (duration / 16);
    let current = start;
    
    const timer = setInterval(() => {
        current += increment;
        if ((increment > 0 && current >= end) || (increment < 0 && current <= end)) {
            current = end;
            clearInterval(timer);
        }
        const displayValue = Math.floor(current);
        element.textContent = displayValue === 100 ? '100%' : displayValue + '+';
    }, 16);
}

// Trigger stats animation when visible
const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const statNumber = entry.target.querySelector('.stat-number');
            const text = statNumber.textContent;
            const isPercentage = text.includes('%');
            const targetValue = parseInt(text);
            animateValue(statNumber, 0, targetValue, 2000);
            statsObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.5 });

document.querySelectorAll('.stat-item').forEach(stat => {
    statsObserver.observe(stat);
});

// ===== SMOOTH REVEAL ON PAGE LOAD =====
window.addEventListener('load', () => {
    document.body.classList.add('loaded');
});

// ===== INITIALIZATION =====
// Antes 'products' venía ya relleno de forma síncrona (escrito a mano).
// Ahora hay que esperar a la respuesta de catalogo-web.js antes de poder
// renderizar nada, así que la inicialización pasa a ser async.
document.addEventListener('DOMContentLoaded', async () => {
    const grid = document.querySelector('.products-grid');
    if (grid) grid.innerHTML = '<p style="text-align:center; padding:60px 20px; color:#999;">Cargando catálogo...</p>';

    const [catalogo, listaCategorias] = await Promise.all([cargarCatalogoWeb(), cargarCategoriasWeb()]);
    products = catalogo;

    if (products.length === 0) {
        if (grid) grid.innerHTML = '<p style="text-align:center; padding:60px 20px; color:#999;">No se pudo cargar el catálogo. Inténtalo de nuevo más tarde.</p>';
        if (sportFiltersContainer) sportFiltersContainer.innerHTML = '';
        console.error('❌ El catálogo llegó vacío o falló la carga.');
        return;
    }

    prepararArbolCategorias(listaCategorias.length > 0 ? listaCategorias : construirCategoriasDesdeProductos(products));
    asignarRutasAProductos();

    const inicial = deportePorDefecto();
    seleccionarCategoria(inicial ? [inicial] : []);
    aplicarParametrosDeUrl();

    const sinCategoria = products.filter(p => p._ruta.length === 0);
    console.log('✅ Equipo 47 - Tienda (prototipo catalogo_web) cargada');
    console.log('📦 Productos:', products.length, '· Categorías:', categorias.length, listaCategorias.length ? '(Supabase)' : '(deducidas de los productos)');
    console.log('⚠️ Productos con precio aproximado:', products.filter(p => p.approxPrice).length);
    if (sinCategoria.length) {
        console.warn(`⚠️ ${sinCategoria.length} productos sin categoría visible (no se muestran):`, sinCategoria.map(p => p.title));
    }
});



// ===== FIX: Prevenir scroll al cambiar de campo en formularios =====
document.addEventListener('DOMContentLoaded', function() {
    const formFields = document.querySelectorAll('input, select, textarea');
    
    formFields.forEach(field => {
        // Prevenir que el blur cause scroll
        field.addEventListener('blur', function(e) {
            e.preventDefault();
        });
        
        // Mantener la posición de scroll al hacer focus
        field.addEventListener('focus', function(e) {
            const scrollY = window.scrollY;
            const scrollX = window.scrollX;
            
            // Restaurar scroll después de que el navegador haga el suyo
            setTimeout(() => {
                window.scrollTo(scrollX, scrollY);
            }, 0);
        });
    });
});
