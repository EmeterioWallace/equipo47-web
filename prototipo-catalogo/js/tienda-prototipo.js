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
const productsGrid = document.querySelector('.products-grid');
const sportFilters = document.querySelectorAll('.sport-filter');
const genderFilters = document.querySelectorAll('.gender-filter');
const searchInput = document.getElementById('product-search');
const subcategoryFiltersSection = document.getElementById('subcategory-filters');
let currentSport = 'running'; // Por defecto mostrar Running
let currentGender = 'todos'; // Por defecto todos los géneros
let currentSubcategory = 'todas'; // Por defecto todas las subcategorías
let currentSearchTerm = ''; // Término de búsqueda

// Definir subcategorías por deporte
const subcategoriesBySport = {
    running: [
        { id: 'todas', label: 'Todas' },
        { id: 'camisetas', label: 'Camisetas' },
        { id: 'chaquetas', label: 'Chaquetas' },
        { id: 'accesorios-running', label: 'Accesorios' },
        { id: 'hidratacion', label: 'Hidratación' },
        { id: 'bolsas-running', label: 'Bolsas' }
    ],
    merchandising: [
        { id: 'todas', label: 'Todas' },
        { id: 'merchandising-bolsas', label: 'Bolsas & Totes' },
        { id: 'merchandising-pulseras', label: 'Pulseras' },
        { id: 'merchandising-eventos', label: 'Eventos' }
    ],
    urban: [
        { id: 'todas', label: 'Todas' }
    ],
    lucha: [
        { id: 'todas', label: 'Todas' }
    ]
};

// Función para renderizar filtros de subcategoría
function renderSubcategoryFilters(sport) {
    if (!subcategoryFiltersSection) return;
    
    const subcategories = subcategoriesBySport[sport] || [];
    
    // Si solo hay "Todas", ocultar la sección
    if (subcategories.length <= 1) {
        subcategoryFiltersSection.style.display = 'none';
        return;
    }
    
    // Mostrar y renderizar subcategorías
    subcategoryFiltersSection.style.display = 'block';
    const filtersContainer = subcategoryFiltersSection.querySelector('.filters');
    filtersContainer.innerHTML = '';
    
    subcategories.forEach(subcat => {
        const button = document.createElement('button');
        button.className = 'subcategory-filter' + (subcat.id === 'todas' ? ' active' : '');
        button.dataset.subcategory = subcat.id;
        button.textContent = subcat.label;
        button.style.cssText = `
            padding: 10px 22px;
            background: ${subcat.id === 'todas' ? '#FF4B1F' : '#f5f5f5'};
            color: ${subcat.id === 'todas' ? 'white' : '#666'};
            border: none;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
        `;
        
        button.addEventListener('click', () => {
            currentSubcategory = subcat.id;
            
            // Actualizar botones activos
            filtersContainer.querySelectorAll('.subcategory-filter').forEach(btn => {
                btn.classList.remove('active');
                btn.style.background = '#f5f5f5';
                btn.style.color = '#666';
            });
            
            button.classList.add('active');
            button.style.background = '#FF4B1F';
            button.style.color = 'white';
            
            // Renderizar productos
            renderProducts(currentSport, currentGender, currentSubcategory, currentSearchTerm);
        });
        
        filtersContainer.appendChild(button);
    });
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
        pintarResultadoTramo(resultadoEl, cachePreciosPorTramo[claveCache], cantidad);
        return;
    }

    resultadoEl.textContent = 'Calculando...';

    try {
        const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        const { data, error } = await sb.rpc('calcular_precio_publico', {
            p_producto_id: productId,
            p_cantidad: cantidad
        });
        if (error) throw error;
        const resultado = (data && data[0]) ? data[0] : null; // {precio, aproximado} | null
        cachePreciosPorTramo[claveCache] = resultado;
        pintarResultadoTramo(resultadoEl, resultado, cantidad);
    } catch (err) {
        console.error('❌ Error consultando precio por cantidad:', err);
        resultadoEl.textContent = 'No se pudo calcular el precio ahora mismo.';
    }
}

function pintarResultadoTramo(resultadoEl, resultado, cantidad) {
    if (!resultado || resultado.precio === null || resultado.precio === undefined) {
        resultadoEl.innerHTML = `<span style="color:#999;">Consultar disponibilidad para ${cantidad} uds</span>`;
        return;
    }
    const precioTexto = Number(resultado.precio).toFixed(2).replace('.', ',') + ' €';
    const etiqueta = resultado.aproximado ? 'Precio orientativo' : 'Precio';
    resultadoEl.innerHTML = `<strong>${etiqueta} para ${cantidad} uds: ${precioTexto}</strong> <span style="color:#999;">/ unidad, sin IVA</span>`;
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

function renderProducts(sport = 'running', gender = 'todos', subcategory = 'todas', searchTerm = '') {
    if (!productsGrid) return;
    
    productsGrid.innerHTML = '';
    
    // Filtrar por deporte
    let filteredProducts = products.filter(p => p.sport === sport);
    
    // Filtrar por subcategoría
    if (subcategory !== 'todas') {
        filteredProducts = filteredProducts.filter(p => p.subcategory === subcategory);
    }
    
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
            return p.title.toLowerCase().includes(term) ||
                   p.description.toLowerCase().includes(term) ||
                   p.category.toLowerCase().includes(term) ||
                   (p.options && p.options.some(opt => opt.toLowerCase().includes(term)));
        });
    }
    
    // Si no hay productos, mostrar mensaje
    if (filteredProducts.length === 0) {
        productsGrid.innerHTML = '<p class="no-products">Próximamente en esta categoría...</p>';
        return;
    }
    
    filteredProducts.forEach(product => {
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
            renderProducts(currentSport, currentGender, currentSubcategory, currentSearchTerm);
        });
    });
}

// Filtros de deporte (Running, Urban, Lucha, etc.)
if (sportFilters.length > 0) {
    sportFilters.forEach(button => {
        button.addEventListener('click', () => {
            if (button.disabled) return;
            
            // Actualizar estilos de botones
            sportFilters.forEach(btn => {
                if (!btn.disabled) {
                    btn.style.background = '#f0f0f0';
                    btn.style.color = '#333';
                    btn.classList.remove('active');
                }
            });
            button.style.background = '#FF4B1F';
            button.style.color = 'white';
            button.classList.add('active');
            
            currentSport = button.dataset.sport;
            currentSubcategory = 'todas'; // Reset subcategoría al cambiar deporte
            
            // Renderizar subcategorías para el deporte seleccionado
            renderSubcategoryFilters(currentSport);
            
            // Renderizar productos
            renderProducts(currentSport, currentGender, currentSubcategory, currentSearchTerm);
        });
    });
}

// Buscador de productos
if (searchInput) {
    searchInput.addEventListener('input', (e) => {
        currentSearchTerm = e.target.value.trim();
        renderProducts(currentSport, currentGender, currentSubcategory, currentSearchTerm);
    });
    
    // Focus styles
    searchInput.addEventListener('focus', () => {
        searchInput.style.borderColor = '#FF4B1F';
    });
    
    searchInput.addEventListener('blur', () => {
        searchInput.style.borderColor = '#e0e0e0';
    });
}

// Mantener compatibilidad con filtros antiguos
const filterButtons = document.querySelectorAll('.filter-btn');
if (filterButtons.length > 0) {
    filterButtons.forEach(button => {
        button.addEventListener('click', () => {
            filterButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            const filter = button.dataset.filter;
            currentCategory = filter;
            renderProducts(currentSport, filter);
        });
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

    products = await cargarCatalogoWeb();

    if (products.length === 0) {
        if (grid) grid.innerHTML = '<p style="text-align:center; padding:60px 20px; color:#999;">No se pudo cargar el catálogo. Inténtalo de nuevo más tarde.</p>';
        console.error('❌ El catálogo llegó vacío o falló la carga.');
        return;
    }

    // Renderizar subcategorías para running (deporte por defecto)
    renderSubcategoryFilters('running');

    // Renderizar productos iniciales
    renderProducts('running', 'todos', 'todas', ''); // Iniciar con Running, todos los géneros, todas las subcategorías

    console.log('✅ Equipo 47 - Tienda (prototipo catalogo_web) loaded! 🎨🏃');
    console.log('📦 Products loaded:', products.length);
    console.log('🎨 Products with color variants:', products.filter(p => p.colors && p.colors.length > 0).length);
    console.log('🏃 Running products:', products.filter(p => p.sport === 'running').length);
    console.log('🛍️ Merchandising products:', products.filter(p => p.sport === 'merchandising').length);
    console.log('⚠️ Products con precio aproximado (tramo más bajo disponible):', products.filter(p => p.approxPrice).length);
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
