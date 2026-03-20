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

if (navToggle) {
    navToggle.addEventListener('click', () => {
        navMenu.classList.toggle('active');
    });
}

// ===== PRODUCT DATA WITH REAL COLOR VARIANTS =====
const products = [
    {
        id: 'product1',
        title: 'Running Tee 47 - Hombre',
        description: 'Camiseta técnica con diseño E47. Tejido transpirable y de secado rápido.',
        sport: 'running',
        category: 'camisetas',
        image: productImages['running-tee-hombre-negro'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['running-tee-hombre-negro'] },
            { name: 'Gris', hex: '#808080', image: productImages['running-tee-hombre-gris'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['running-tee-hombre-blanco'] }
        ],
        options: ['Sublimación completa', 'Serigrafía', 'Bordado', 'Transfer']
    },
    {
        id: 'product2',
        title: 'Running Tee 47 - Mujer',
        description: 'Camiseta técnica con diseño E47. Tejido transpirable y de secado rápido.',
        sport: 'running',
        category: 'camisetas',
        image: productImages['running-tee-mujer-negro'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['running-tee-mujer-negro'] },
            { name: 'Gris', hex: '#808080', image: productImages['running-tee-mujer-gris'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['running-tee-mujer-blanco'] }
        ],
        options: ['Sublimación completa', 'Serigrafía', 'Bordado', 'Transfer']
    },
    {
        id: 'product3',
        title: 'Wind Jacket 47',
        description: 'Chaqueta cortavientos ligera y resistente. Perfecta para running y deportes al aire libre.',
        sport: 'running',
        category: 'chaquetas',
        image: productImages['wind-jacket-negro'],
        badge: 'Más Vendido',
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['wind-jacket-negro'] },
            { name: 'Azul', hex: '#0066CC', image: productImages['wind-jacket-azul'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['wind-jacket-blanco'] },
            { name: 'Verde', hex: '#7FFF00', image: productImages['wind-jacket-verde'] },
            { name: 'Naranja', hex: '#FF8C00', image: productImages['wind-jacket-naranja'] }
        ],
        options: ['Sublimación', 'Bordado', 'Serigrafía']
    },
    {
        id: 'product4',
        title: 'Sudadera Training Pro',
        description: 'Tejido cálido, transpirable y de secado rápido. Ideal para entrenamientos.',
        sport: 'running',
        category: 'sudaderas',
        image: productImages['sudadera-training'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['sudadera-training'] },
            { name: 'Gris', hex: '#808080', image: productImages['sudadera-training'] },
            { name: 'Azul Marino', hex: '#001F3F', image: productImages['sudadera-training'] }
        ],
        options: ['Bordado premium', 'Serigrafía', 'Sublimación parcial']
    },
    {
        id: 'product5',
        title: 'Sudadera Lifestyle Premium',
        description: 'Interior afelpado y corte entallado. Máxima comodidad.',
        sport: 'running',
        category: 'sudaderas',
        image: productImages['sudadera-lifestyle'],
        colors: [
            { name: 'Verde', hex: '#6B8E23', image: productImages['sudadera-lifestyle'] },
            { name: 'Negro', hex: '#000000', image: productImages['sudadera-lifestyle'] },
            { name: 'Gris', hex: '#808080', image: productImages['sudadera-lifestyle'] }
        ],
        options: ['Bordado', 'Transfer', 'Serigrafía']
    },
    {
        id: 'product6',
        title: 'Chaqueta Cortavientos - Hombre',
        description: 'Ligera y resistente al viento. Ideal para uso urbano y deportivo.',
        sport: 'running',
        category: 'chaquetas',
        image: productImages['cortavientos-training-hombre'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['cortavientos-training-hombre'] },
            { name: 'Azul Marino', hex: '#001F3F', image: productImages['cortavientos-training-hombre'] }
        ],
        options: ['Sublimación', 'Bordado', 'Serigrafía']
    },
    {
        id: 'product7',
        title: 'Chaqueta Cortavientos - Mujer',
        description: 'Ligera y resistente al viento. Perfecta para cualquier actividad.',
        sport: 'running',
        category: 'chaquetas',
        image: productImages['cortavientos-training-mujer'],
        colors: [
            { name: 'Gris', hex: '#A9A9A9', image: productImages['cortavientos-training-mujer'] },
            { name: 'Negro', hex: '#000000', image: productImages['cortavientos-training-mujer'] }
        ],
        options: ['Sublimación', 'Transfer', 'Serigrafía']
    },
    {
        id: 'product8',
        title: 'Mallas Training Pro - Hombre',
        description: 'Compresión ligera. Ideal para running y entrenamientos intensos.',
        sport: 'running',
        category: 'mallas',
        image: productImages['mallas-training-hombre'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['mallas-training-hombre'] },
            { name: 'Azul Marino', hex: '#001F3F', image: productImages['mallas-training-hombre'] }
        ],
        options: ['Sublimación 360°', 'Diseños personalizados']
    },
    {
        id: 'product9',
        title: 'Leggings Training Pro - Mujer',
        description: 'Tejido transpirable y de secado rápido. Ajuste perfecto.',
        sport: 'running',
        category: 'mallas',
        image: productImages['mallas-training-mujer'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['mallas-training-mujer'] },
            { name: 'Burdeos', hex: '#800020', image: productImages['mallas-training-mujer'] },
            { name: 'Azul', hex: '#0066CC', image: productImages['mallas-training-mujer'] }
        ],
        options: ['Sublimación completa', 'Logo personalizado']
    },
    {
        id: 'product10',
        title: 'Manguitos Comfort Pro',
        description: 'Protección UV y térmica. MOQ: 100 unidades.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['manguitos'],
        badge: 'MOQ 100',
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['manguitos'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['manguitos'] },
            { name: 'Azul', hex: '#0066CC', image: productImages['manguitos'] }
        ],
        options: ['Sublimación', 'Logo impreso', 'Varios colores']
    },
    {
        id: 'product11',
        title: 'Chaleco HydraPro 47',
        description: 'Ideal para trail y running. MOQ: 500 unidades.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['chaleco'],
        badge: 'MOQ 500',
        options: ['Personalización completa', 'Logo bordado']
    },
    {
        id: 'product12',
        title: 'Botella Plegable HydraFlex 47',
        description: 'Ligera y compacta. Perfecta para trail y running.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['botella'],
        badge: 'Nuevo',
        colors: [
            { name: 'Azul', hex: '#0066CC', image: productImages['botella'] },
            { name: 'Verde', hex: '#00AA00', image: productImages['botella'] },
            { name: 'Rojo', hex: '#DC0000', image: productImages['botella'] }
        ],
        options: ['Logo personalizado', 'Varios colores']
    },
    {
        id: 'product13',
        title: 'Cinta Running HeadFit Pro',
        description: 'Ligera, transpirable y antideslizante. Controla el sudor eficazmente.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['cinta'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['cinta'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['cinta'] },
            { name: 'Azul', hex: '#0066CC', image: productImages['cinta'] },
            { name: 'Rojo', hex: '#DC0000', image: productImages['cinta'] }
        ],
        options: ['Logo personalizado', 'Diversos colores']
    },
    {
        id: 'product14',
        title: 'Guantes ThermalRun 47',
        description: 'Tejido térmico y transpirable. Perfectos para correr en invierno.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['guantes'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['guantes'] },
            { name: 'Gris', hex: '#808080', image: productImages['guantes'] }
        ],
        options: ['Logo bordado', 'Serigrafía']
    },
    {
        id: 'product15',
        title: 'Gorro Lifestyle 47',
        description: 'Tejido suave y cálido. Ideal para uso diario y deportivo.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['gorro'],
        colors: [
            { name: 'Azul', hex: '#0066CC', image: productImages['gorro'] },
            { name: 'Negro', hex: '#000000', image: productImages['gorro'] },
            { name: 'Gris', hex: '#808080', image: productImages['gorro'] }
        ],
        options: ['Bordado personalizado', 'Logo tejido']
    },
    {
        id: 'product16',
        title: 'Vaso Plegable HydraFlex 47',
        description: 'Ultraligero y compacto. Ideal para carreras y entrenamientos.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['vaso'],
        badge: 'Nuevo',
        colors: [
            { name: 'Azul', hex: '#0066CC', image: productImages['vaso'] },
            { name: 'Verde', hex: '#00AA00', image: productImages['vaso'] },
            { name: 'Naranja', hex: '#FF8C00', image: productImages['vaso'] }
        ],
        options: ['Logo impreso', 'Varios colores']
    },
    {
        id: 'product17',
        title: 'Race Singlet 47 - Hombre',
        description: 'Camiseta sin mangas ultraligera. Máxima transpirabilidad para competición.',
        sport: 'running',
        category: 'camisetas',
        image: productImages['race-singlet-47-hombre-negro'],
        badge: 'Competición',
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['race-singlet-47-hombre-negro'] },
            { name: 'Gris', hex: '#808080', image: productImages['race-singlet-47-hombre-gris'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['race-singlet-47-hombre-blanco'] }
        ],
        options: ['Sublimación completa', 'Serigrafía', 'Transfer']
    },
    {
        id: 'product18',
        title: 'Race Singlet 47 - Mujer',
        description: 'Camiseta sin mangas ultraligera. Diseñada para máximo rendimiento.',
        sport: 'running',
        category: 'camisetas',
        image: productImages['race-singlet-47-mujer-negro'],
        badge: 'Competición',
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['race-singlet-47-mujer-negro'] },
            { name: 'Gris', hex: '#808080', image: productImages['race-singlet-47-mujer-gris'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['race-singlet-47-mujer-blanco'] }
        ],
        options: ['Sublimación completa', 'Serigrafía', 'Transfer']
    },
    {
        id: 'product19',
        title: 'Performance Socks 47',
        description: 'Calcetines de alto rendimiento con compresión suave. Acolchado estratégico.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['performance-socks-negros'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['performance-socks-negros'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['performance-socks-blancos'] }
        ],
        options: ['Logo tejido', 'Diseño personalizado']
    },
    {
        id: 'product20',
        title: 'AnkleFit 47',
        description: 'Calcetines tobilleros ligeros. Perfectos para running y entrenamientos.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['anklefit-negros'],
        colors: [
            { name: 'Negro', hex: '#000000', image: productImages['anklefit-negros'] },
            { name: 'Blanco', hex: '#FFFFFF', image: productImages['anklefit-blancos'] }
        ],
        options: ['Logo personalizado', 'Varios diseños']
    },
    {
        id: 'product21',
        title: 'Sport Towel 47',
        description: 'Toalla deportiva de microfibra. Absorción rápida y secado ultrarrápido.',
        sport: 'running',
        category: 'accesorios',
        image: productImages['toalla'],
        colors: [
            { name: 'Azul', hex: '#0066CC', image: productImages['toalla'] },
            { name: 'Gris', hex: '#808080', image: productImages['toalla'] },
            { name: 'Negro', hex: '#000000', image: productImages['toalla'] }
        ],
        options: ['Bordado personalizado', 'Sublimación']
    }
];

// ===== PRODUCT DISPLAY & FILTERING =====
const productsGrid = document.querySelector('.products-grid');
const sportFilters = document.querySelectorAll('.sport-filter');
const categoryFilters = document.querySelectorAll('.category-filter');
let currentSport = 'running'; // Por defecto mostrar Running
let currentCategory = 'todos';

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
            <div class="product-price">
                <span class="price-from">Consultar</span>
                <span class="price-amount">Precio</span>
            </div>
            ${colorDotsHTML}
            ${optionsHTML}
        </div>
    `;
    
    return card;
}

function renderProducts(sport = 'running', category = 'todos') {
    if (!productsGrid) return;
    
    productsGrid.innerHTML = '';
    
    // Filtrar por deporte y categoría
    let filteredProducts = products.filter(p => p.sport === sport);
    
    if (category !== 'todos') {
        filteredProducts = filteredProducts.filter(p => p.category === category);
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
// Filtros de deporte (Running, Urban, Lucha, etc.)
if (sportFilters.length > 0) {
    sportFilters.forEach(button => {
        button.addEventListener('click', () => {
            sportFilters.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            currentSport = button.dataset.sport;
            currentCategory = 'todos'; // Reset category filter
            
            // Reset category buttons
            if (categoryFilters.length > 0) {
                categoryFilters.forEach(btn => btn.classList.remove('active'));
                const todosBtn = document.querySelector('.category-filter[data-filter="todos"]');
                if (todosBtn) todosBtn.classList.add('active');
            }
            
            renderProducts(currentSport, currentCategory);
        });
    });
}

// Filtros de categoría (Camisetas, Chaquetas, etc.)
if (categoryFilters.length > 0) {
    categoryFilters.forEach(button => {
        button.addEventListener('click', () => {
            categoryFilters.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            currentCategory = button.dataset.filter;
            renderProducts(currentSport, currentCategory);
        });
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

// ===== CALCULATOR FUNCTIONALITY =====
const calcProduct = document.getElementById('calc-product');
const calcQuantity = document.getElementById('calc-quantity');
const calcSlider = document.getElementById('calc-slider');
const calcCustomization = document.getElementById('calc-customization');
const basePrice = document.getElementById('base-price');
const customPrice = document.getElementById('custom-price');
const totalPrice = document.getElementById('total-price');
const unitPrice = document.getElementById('unit-price');

function updateCalculator() {
    const productPrice = parseFloat(calcProduct.value);
    const quantity = parseInt(calcQuantity.value);
    const customizationPrice = parseFloat(calcCustomization.value);
    
    if (productPrice === 0 || isNaN(productPrice)) {
        basePrice.textContent = '0,00€';
        customPrice.textContent = '0,00€';
        totalPrice.textContent = '0,00€';
        unitPrice.textContent = '0,00€';
        return;
    }
    
    const base = productPrice * quantity;
    const custom = customizationPrice * quantity;
    const total = base + custom;
    const unit = total / quantity;
    
    basePrice.textContent = base.toFixed(2).replace('.', ',') + '€';
    customPrice.textContent = custom.toFixed(2).replace('.', ',') + '€';
    totalPrice.textContent = total.toFixed(2).replace('.', ',') + '€';
    unitPrice.textContent = unit.toFixed(2).replace('.', ',') + '€';
}

if (calcProduct && calcQuantity && calcSlider && calcCustomization) {
    calcProduct.addEventListener('change', updateCalculator);
    calcQuantity.addEventListener('input', (e) => {
        calcSlider.value = e.target.value;
        updateCalculator();
    });
    calcSlider.addEventListener('input', (e) => {
        calcQuantity.value = e.target.value;
        updateCalculator();
    });
    calcCustomization.addEventListener('change', updateCalculator);
    
    updateCalculator();
}

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
document.addEventListener('DOMContentLoaded', () => {
    renderProducts('running', 'todos'); // Iniciar con Running, todas las categorías
    console.log('✅ Equipo 47 - Eventos + Tienda loaded! 🎨🏃');
    console.log('📦 Products loaded:', products.length);
    console.log('🎨 Products with color variants:', products.filter(p => p.colors && p.colors.length > 0).length);
    console.log('🏃 Running products:', products.filter(p => p.sport === 'running').length);
});
