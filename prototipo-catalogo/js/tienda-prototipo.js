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
    
    if (currentScroll > 100) {
        nav.style.boxShadow = '0 2px 20px rgba(0,0,0,0.1)';
    } else {
        nav.style.boxShadow = 'none';
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

const ESTILO_DEPORTE = 'padding: 12px 28px; border: none; border-radius: 25px; font-size: 0.95rem; font-weight: 600; transition: all 0.3s ease;';
const ESTILO_SUBCATEGORIA = 'padding: 10px 22px; border: none; border-radius: 20px; font-size: 0.9rem; font-weight: 500; cursor: pointer; transition: all 0.3s ease;';

// Botones de deporte (nivel 1), en el orden de Producciones.
function renderSportFilters() {
    if (!sportFiltersContainer) return;
    sportFiltersContainer.innerHTML = '';

    (hijosPorId.get('raiz') || []).filter(categoriaVisible).forEach(deporte => {
        const button = document.createElement('button');
        button.className = 'sport-filter';
        button.dataset.categoriaId = deporte.id;
        button.dataset.sport = deporte.slug;

        if (deporte.proximamente) {
            button.disabled = true;
            button.classList.add('coming-soon');
            button.style.cssText = ESTILO_DEPORTE + 'background: #e0e0e0; color: #999; cursor: not-allowed; opacity: 0.6;';
            button.textContent = deporte.nombre + ' ';
            const aviso = document.createElement('span');
            aviso.style.fontSize = '0.8rem';
            aviso.textContent = '(Próximamente)';
            button.appendChild(aviso);
        } else {
            const activo = rutaSeleccionada[0] === deporte.id;
            button.classList.toggle('active', activo);
            button.style.cssText = ESTILO_DEPORTE + `cursor: pointer; background: ${activo ? '#FF4B1F' : '#f0f0f0'}; color: ${activo ? 'white' : '#333'};`;
            button.textContent = deporte.nombre;
            button.addEventListener('click', () => seleccionarCategoria([deporte.id]));
        }
        sportFiltersContainer.appendChild(button);
    });
}

// Filas de subcategorías: una por cada nivel bajo el deporte seleccionado
// (tipo y, si el tipo elegido se subdivide, subcategoría).
function renderSubcategoryFilters() {
    if (!subcategoryFiltersSection) return;
    const contenedor = subcategoryFiltersSection.querySelector('.filters');
    contenedor.innerHTML = '';
    contenedor.style.flexDirection = 'column';
    contenedor.style.alignItems = 'center';

    let hayFilas = false;
    for (let nivel = 0; nivel < rutaSeleccionada.length && nivel < 2; nivel++) {
        const padreId = rutaSeleccionada[nivel];
        const hijos = (hijosPorId.get(padreId) || []).filter(categoriaVisible);
        if (hijos.length === 0) break;

        hayFilas = true;
        const fila = document.createElement('div');
        fila.style.cssText = 'display: flex; justify-content: center; gap: 12px; flex-wrap: wrap;';
        const seleccionadoEnFila = rutaSeleccionada[nivel + 1];

        const crearBoton = (texto, activo, onClick, deshabilitado) => {
            const b = document.createElement('button');
            b.className = 'subcategory-filter' + (activo ? ' active' : '');
            b.textContent = texto;
            if (deshabilitado) {
                b.disabled = true;
                b.style.cssText = ESTILO_SUBCATEGORIA + 'background: #eee; color: #aaa; cursor: not-allowed;';
            } else {
                b.style.cssText = ESTILO_SUBCATEGORIA + `background: ${activo ? '#FF4B1F' : '#f5f5f5'}; color: ${activo ? 'white' : '#666'};`;
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

// Primer deporte en el orden de Producciones que no esté en "Próximamente"
// y tenga productos.
function deportePorDefecto() {
    const deporte = (hijosPorId.get('raiz') || []).find(c => !c.proximamente && productosDeCategoria(c.id).length > 0);
    return deporte ? deporte.id : null;
}

// ===== SELECTOR DE CANTIDADES (precio por tramo, bajo demanda) =====
// Mismos 6 tramos fijos que usa Fátima en Producciones. No se precargan
// los precios de todos los tramos (evitaría 6 consultas por producto solo
// con cargar la página) — se consulta calcular_precio_publico() solo del
// tramo que el visitante pulse, y se guarda en caché en memoria para no
// volver a pedirlo si lo pulsa otra vez.
const TRAMOS_CANTIDAD = [50, 100, 500, 1000, 5000, 10000];
const cachePreciosPorTramo = {}; // "productId:cantidad" -> {precio, aproximado} | null

function crearSelectorCantidadesHTML(product) {
    // Nunca ofrecer una cantidad por debajo del pedido mínimo real del
    // producto (si el MOQ es 100, no tiene sentido mostrar un botón de 50
    // como si fuera pedible).
    const tramosValidos = TRAMOS_CANTIDAD.filter(cantidad => cantidad >= (product.moq || 0));
    if (tramosValidos.length === 0) return '';

    const botones = tramosValidos.map(cantidad => `
        <button
            type="button"
            class="tramo-cantidad-btn"
            data-product-id="${product.id}"
            data-cantidad="${cantidad}"
            onclick="consultarPrecioPorCantidad('${product.id}', ${cantidad}, this)"
            style="padding: 4px 10px; margin: 3px 4px 0 0; border: 1px solid #ddd; border-radius: 14px; background: #f8f8f8; color: #555; font-size: 0.75rem; cursor: pointer;"
        >${cantidad} uds</button>
    `).join('');

    return `
        <div class="selector-cantidades" style="margin-top: 10px;">
            <div style="font-size: 0.7rem; color: #999; margin-bottom: 2px;">Ver precio para otras cantidades:</div>
            <div style="display: flex; flex-wrap: wrap;">${botones}</div>
            <div class="resultado-tramo" data-product-id="${product.id}" style="font-size: 0.8rem; margin-top: 6px; min-height: 18px;"></div>
        </div>
    `;
}

async function consultarPrecioPorCantidad(productId, cantidad, botonEl) {
    const card = botonEl.closest('.product-card');
    const resultadoEl = card ? card.querySelector('.resultado-tramo') : null;
    if (!resultadoEl) return;

    // Marcar visualmente el botón activo
    card.querySelectorAll('.tramo-cantidad-btn').forEach(b => {
        b.style.background = '#f8f8f8';
        b.style.color = '#555';
        b.style.borderColor = '#ddd';
    });
    botonEl.style.background = '#FF4B1F';
    botonEl.style.color = '#fff';
    botonEl.style.borderColor = '#FF4B1F';

    const claveCache = `${productId}:${cantidad}`;
    if (cachePreciosPorTramo[claveCache] !== undefined) {
        pintarResultadoTramo(card, resultadoEl, cachePreciosPorTramo[claveCache], cantidad);
        return;
    }

    resultadoEl.textContent = 'Calculando...';

    try {
        const { data, error } = await clienteSupabase().rpc('calcular_precio_publico', {
            p_producto_id: productId,
            p_cantidad: cantidad
        });
        if (error) throw error;
        const resultado = (data && data[0]) ? data[0] : null; // {precio, aproximado} | null
        cachePreciosPorTramo[claveCache] = resultado;
        pintarResultadoTramo(card, resultadoEl, resultado, cantidad);
    } catch (err) {
        console.error('❌ Error consultando precio por cantidad:', err);
        resultadoEl.textContent = 'No se pudo calcular el precio ahora mismo.';
    }
}

// El precio grande de la tarjeta pasa a ser el de la cantidad elegida.
// La línea de debajo solo indica a qué cantidad corresponde.
function pintarResultadoTramo(card, resultadoEl, resultado, cantidad) {
    const etiquetaEl = card.querySelector('.product-price .price-from');
    const precioEl = card.querySelector('.product-price .price-amount');

    if (!resultado || resultado.precio === null || resultado.precio === undefined) {
        if (etiquetaEl) etiquetaEl.textContent = 'Precio:';
        if (precioEl) precioEl.textContent = 'A CONSULTAR';
        resultadoEl.innerHTML = `<span style="color:#999;">Consultar disponibilidad para ${cantidad} uds</span>`;
        return;
    }
    const precioTexto = Number(resultado.precio).toFixed(2).replace('.', ',') + ' €';
    if (etiquetaEl) etiquetaEl.textContent = resultado.aproximado ? 'Precio orientativo:' : 'Precio:';
    if (precioEl) precioEl.textContent = precioTexto;
    resultadoEl.innerHTML = `<span style="color:#666;">Precio para <strong>${cantidad} uds</strong></span>`;
}

function createProductCard(product) {
    const card = document.createElement('div');
    card.className = 'product-card';
    card.dataset.category = product.category;
    card.dataset.sport = product.sport;
    
    // Badge HTML
    const badgeHTML = product.badge ? `<span class="product-badge">${product.badge}</span>` : '';
    
    // Color dots HTML (según el CSS original)
    let colorDotsHTML = '';
    if (product.colors && product.colors.length > 0) {
        colorDotsHTML = `
            <div class="product-colors">
                <span class="colors-label">COLORES:</span>
                ${product.colors.map((color, index) => `
                    <div 
                        class="color-dot ${index === 0 ? 'active' : ''}" 
                        style="background-color: ${color.hex}"
                        data-product-id="${product.id}"
                        data-color-index="${index}"
                        data-color-name="${color.name}"
                        title="${color.name}">
                    </div>
                `).join('')}
            </div>
        `;
    }
    
    // Options HTML
    let optionsHTML = '';
    if (product.options && product.options.length > 0) {
        optionsHTML = `
            <div class="product-options">
                ${product.options.map(option => `
                    <span class="option">${option}</span>
                `).join('')}
            </div>
        `;
    }
    
    // Precio y MOQ HTML
    let priceHTML = '';
    if (product.price) {
        const priceAmount = product.price === 'Consultar' ? 'A CONSULTAR' : product.price;
        // De cara al cliente: cuando el precio es aproximado (viene del tramo
        // más bajo disponible, no del tramo real del MOQ publicado), la
        // etiqueta cambia a "Precio orientativo" — sin mencionar el tramo
        // ni ningún detalle interno de cómo se calculó.
        const priceLabel = product.approxPrice ? 'Precio orientativo:' : 'Precio:';
        // Misma aclaración que en el modal de detalle: dejar claro que el
        // precio mostrado es por unidad y sin IVA, no el total del pedido.
        const unitNote = product.price !== 'Consultar'
            ? `<span style="font-size: 0.75rem; color: #999; font-weight: 400;"> / unidad, sin IVA</span>`
            : '';
        priceHTML = `
            <div class="product-price">
                <span class="price-from">${priceLabel}</span>
                <span class="price-amount">${priceAmount}</span>${unitNote}
            </div>
            ${crearSelectorCantidadesHTML(product)}
        `;
    } else {
        priceHTML = `
            <div class="product-price">
                <span class="price-from">Precio:</span>
                <span class="price-amount">A CONSULTAR</span>
            </div>
        `;
    }
    
    card.innerHTML = `
        ${badgeHTML}
        <div class="product-image">
            <img src="${product.image}" alt="${product.title}" loading="lazy">
            <div class="product-overlay">
                <button class="btn-quick-view" onclick="openProductModal('${product.id}')">
                    Ver detalles
                </button>
            </div>
        </div>
        <div class="product-info">
            <h3 class="product-name">${product.title}</h3>
            <p class="product-desc">${product.description}</p>
            ${priceHTML}
            ${colorDotsHTML}
            ${optionsHTML}
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
    
    // Si no hay productos, mostrar mensaje
    if (filteredProducts.length === 0) {
        productsGrid.innerHTML = '<p class="no-products">Próximamente en esta categoría...</p>';
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
        const img = card.querySelector('.product-image img');
        if (img && newColor.image) {
            img.src = newColor.image;
        }
        
        // Update active color dot
        const dots = card.querySelectorAll('.color-dot');
        dots.forEach((d, i) => {
            d.classList.toggle('active', i === colorIndex);
        });
    }
}

// ===== FILTER BUTTONS =====
// Filtros de género (Todos, Hombre, Mujer, Unisex)
if (genderFilters.length > 0) {
    genderFilters.forEach(button => {
        button.addEventListener('click', () => {
            // Actualizar estilos de botones
            genderFilters.forEach(btn => {
                btn.style.color = '#666';
                btn.style.borderBottom = '3px solid transparent';
                btn.classList.remove('active');
            });
            button.style.color = '#2C3E50';
            button.style.borderBottom = '3px solid #FF4B1F';
            button.classList.add('active');
            
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

function openProductModal(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;
    
    currentModalProduct = product;
    currentModalColor = 0;
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
    
    const imageUrl = currentColor ? currentColor.image : product.image;
    
    // Update image
    const modalImage = document.getElementById('modal-image');
    if (modalImage) {
        modalImage.src = imageUrl;
        modalImage.alt = product.title;
    }
    
    // Update title and description
    document.getElementById('modal-title').textContent = product.title;
    document.getElementById('modal-description').textContent = product.description;

    // Update price (antes era texto fijo que nunca se actualizaba)
    const priceLabel = product.approxPrice ? 'Precio orientativo' : 'Precio';
    const priceValue = product.price === 'Consultar' ? 'A CONSULTAR' : (product.price || 'Consultar');
    document.getElementById('modal-price-label').textContent = priceLabel;
    document.getElementById('modal-price').textContent = priceValue;

    const moqEl = document.getElementById('modal-moq');
    if (moqEl) {
        moqEl.textContent = product.moq ? `Pedido mínimo: ${product.moq} unidades · precio por unidad, sin IVA` : '';
    }
    
    // Create color selector if product has colors
    let colorSelectorHTML = '';
    if (product.colors && product.colors.length > 0) {
        colorSelectorHTML = `
            <div class="modal-colors">
                <h4>Colores disponibles:</h4>
                <div class="modal-color-options">
                    ${product.colors.map((color, index) => `
                        <div 
                            class="modal-color-dot ${index === currentModalColor ? 'active' : ''}" 
                            style="background-color: ${color.hex}"
                            onclick="changeModalColor(${index})"
                            title="${color.name}">
                        </div>
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
    updateModalContent();
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

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
        closeProductModal();
    }
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
