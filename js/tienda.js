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
const products = [
    {
        id: 'product1',
        title: 'E47 Running Tank - Hombre',
        price: '7,70 €',
        moq: 100,
        description: 'Camiseta de running sin mangas ligera y transpirable con tejido de secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'hombre',
        image: productImages['e47-running-tank-hombre'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product2',
        title: 'E47 Running Tank - Mujer',
        price: '7,70 €',
        moq: 100,
        description: 'Camiseta de running sin mangas ligera y transpirable con tejido de secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'mujer',
        image: productImages['e47-running-tank-mujer'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product3',
        title: 'E47 Running Tee Sublimación - Hombre',
        price: '7,70 €',
        moq: 100,
        description: 'Camiseta técnica de running de manga corta con tejido ligero y transpirable que ofrece secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'hombre',
        image: productImages['e47-running-tee-hombre'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product4',
        title: 'E47 Running Tee Sublimación - Mujer',
        price: '7,70 €',
        moq: 100,
        description: 'Camiseta técnica de running de manga corta con tejido ligero y transpirable que ofrece secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'mujer',
        image: productImages['e47-running-tee-mujer'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product5',
        title: 'E47 Running Long Sleeve - Hombre',
        price: '8,15 €',
        moq: 100,
        description: 'Camiseta técnica de running de manga larga con tejido ligero y transpirable que ofrece secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'hombre',
        image: productImages['e47-running-long-sleeve-hombre'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product6',
        title: 'E47 Running Long Sleeve - Mujer',
        price: '8,15 €',
        moq: 100,
        description: 'Camiseta técnica de running de manga larga con tejido ligero y transpirable que ofrece secado rápido.',
        sport: 'running',
        subcategory: 'camisetas',
        category: 'camisetas',
        gender: 'mujer',
        image: productImages['e47-running-long-sleeve-mujer'],
        specifications: [
            'Tejido técnico de poliéster de alta calidad',
            'Secado rápido',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product7',
        title: 'E47 Running Windbreaker',
        price: '16,65 €',
        moq: 100,
        description: 'Chaqueta técnica de running ligera con capucha diseñada para ofrecer protección contra el viento y comodidad.',
        sport: 'running',
        subcategory: 'chaquetas',
        category: 'chaquetas',
        gender: 'unisex',
        image: productImages['e47-windbreaker'],
        specifications: [
            'Tejido técnico de alta calidad',
            'Protección frente al viento',
            'Detalles reflectantes'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product8',
        title: 'E47 Running Rain Jacket',
        price: '10,60 €',
        moq: 100,
        description: 'Chubasquero ligero diseñado para ofrecer protección contra la lluvia y comodidad durante entrenamiento.',
        sport: 'running',
        subcategory: 'chaquetas',
        category: 'chaquetas',
        gender: 'unisex',
        image: productImages['e47-running-rainjacket'],
        specifications: [
            'Tejido impermeable',
            'Ligero y transpirable'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product9',
        title: 'E47 Running Cap Personalizable',
        price: '5,80 €',
        moq: 100,
        description: 'Gorra técnica ligera y transpirable con tejido de secado rápido y resistente al agua para mayor comodidad.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-running-cap'],
        specifications: [
            'Tejido técnico 100% nylon',
            'Tejido transpirable',
            'Secado rápido'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización',
            'Diseño compacto'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product10',
        title: 'E47 Winter Running Beanie',
        price: '6,30 €',
        moq: 100,
        description: 'Gorro técnico ligero y transpirable con tejido de secado rápido diseñado para entrenamientos en clima frío.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-winter-running-beanie'],
        specifications: [
            'Tejido técnico de Poliéster/Elastano',
            'Tejido Transpirable',
            'Secado Rápido'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Personalizable']
    },
    {
        id: 'product11',
        title: 'E47 Performance Gloves',
        price: '4,80 €',
        moq: 500,
        description: 'Guantes técnicos cálidos y elásticos diseñados para ofrecer comodidad en entrenamientos en clima frío.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['guantes-thermalrun-47'],
        specifications: [
            'Tejido técnico de Poliéster/Elastano de alta calidad',
            'Secado rápido',
            'Ajuste flexible'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Varios Colores']
    },
    {
        id: 'product12',
        title: 'E47 Expandable Running Belt',
        price: '2,55 €',
        moq: 1000,
        description: 'Riñonera técnica ligera y expansible con banda reflectante diseñada para transportar objetos esenciales.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-expandable-running-belt'],
        specifications: [
            'Material técnico de Neopreno',
            'Tejido elástico y resistente',
            'Banda Reflectante'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización',
            'Diseño compacto'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product13',
        title: 'E47 Running Bandana',
        price: '2,99 €',
        moq: 100,
        description: 'Bandana técnica de microfibra de poliéster ligera y transpirable diseñada para ofrecer comodidad y versatilidad.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-running-bandana'],
        specifications: [
            'Tejido técnico Microfibra de Poliéster 120 g',
            'Alta transpirabilidad',
            'Sin Costuras'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación Completa']
    },
    {
        id: 'product14',
        title: 'E47 Milk Silk Running Bandana',
        price: '3,45 €',
        moq: 100,
        description: 'Bandana técnica de poliéster elástico ligera y transpirable diseñada para ofrecer comodidad y versatilidad.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-milk-silk-bandana'],
        specifications: [
            'Tejido técnico de poliéster elástico',
            'Alta transpirabilidad',
            'Sin Costuras'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación Completa']
    },
    {
        id: 'product15',
        title: 'E47 Performance Socks',
        price: '7,60 €',
        moq: 100,
        description: 'Calcetines técnicos de nylon ligeros y transpirables diseñados para ofrecer comodidad durante el entrenamiento.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-performance-running-socks'],
        specifications: [
            'Tejido Técnico de Nylon',
            'Alta transpirabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación Completa', 'Diseño personalizable']
    },
    {
        id: 'product16',
        title: 'E47 Performance Socks Terry',
        price: '7,70 €',
        moq: 100,
        description: 'Calcetines técnicos de running con tejido de nylon y rizo terry para ofrecer mayor amortiguación y comodidad.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-performance-running-socks-terry'],
        specifications: [
            'Tejido Técnico de Nylon',
            'Alta transpirabilidad',
            'Amortiguación Terry'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación Completa', 'Diseño personalizable']
    },
    {
        id: 'product17',
        title: 'E47 Cooling Towel',
        price: '5,70 €',
        moq: 100,
        description: 'Toalla de microfibra ligera y transpirable diseñada para mantener la frescura durante el entrenamiento.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-cooling-towel'],
        specifications: [
            'Tejido de microfibra',
            'Peso ligero 155 g/m²',
            'Bordes reforzados'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product18',
        title: 'E47 Running Armband',
        price: '0,99 €',
        moq: 1000,
        description: 'Brazalete para smartphone diseñado para transportar el móvil con comodidad durante entrenamientos y carreras.',
        sport: 'running',
        subcategory: 'accesorios-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-running-armband'],
        specifications: [
            'Material resistente y ligero',
            'Ajuste Regulable',
            'Pantalla táctil compatible'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product19',
        title: 'E47 Everyday Tote',
        price: '4,35 €',
        moq: 100,
        description: 'Bolsa tote resistente diseñada para transportar cómodamente equipamiento deportivo y objetos del día a día.',
        sport: 'merchandising',
        subcategory: 'merchandising-bolsas',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-everyday-tote'],
        specifications: [
            'Tejido de algodón canvas'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Beige',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Personalización con Logo']
    },
    {
        id: 'product20',
        title: 'E47 Everyday Tote Colors',
        price: '4,50 €',
        moq: 100,
        description: 'Bolsa tote resistente diseñada para transportar cómodamente equipamiento deportivo y objetos del día a día.',
        sport: 'merchandising',
        subcategory: 'merchandising-bolsas',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-everyday-tote-colors'],
        specifications: [
            'Tejido de algodón canvas'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Personalización con Logo', 'Varios Colores']
    },
    {
        id: 'product21',
        title: 'E47 Gymsac 210D Sublimación',
        price: 'Consultar',
        description: 'Gymsac de poliéster ligero 210D y resistente para transportar equipamiento de forma cómoda y segura.',
        sport: 'running',
        subcategory: 'bolsas-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-gymsac-210d'],
        specifications: [
            'Tejido de poliéster 210D'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa', 'Diseño personalizable']
    },
    {
        id: 'product22',
        title: 'E47 Gymsac 420D Sublimación',
        price: 'Consultar',
        description: 'Gymsac de poliéster ligero 420D y resistente para transportar equipamiento de forma cómoda y segura.',
        sport: 'running',
        subcategory: 'bolsas-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-gymsac-420d'],
        specifications: [
            'Tejido de poliéster 420D',
            'Mayor Durabilidad'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa']
    },
    {
        id: 'product23',
        title: 'E47 Zip Gymsac 210D Sublimación',
        price: 'Consultar',
        moq: 500,
        description: 'Gymsac resistente con bolsillo con cremallera diseñado para transportar equipamiento de forma cómoda.',
        sport: 'running',
        subcategory: 'bolsas-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-zip-gymsac-210d'],
        specifications: [
            'Tejido de poliéster 210D',
            'Incluye Cremallera'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa', 'Diseño personalizable']
    },
    {
        id: 'product24',
        title: 'E47 Zip Gymsac 420D Sublimación',
        price: 'Consultar',
        moq: 500,
        description: 'Gymsac resistente con bolsillo con cremallera diseñado para transportar equipamiento con mayor durabilidad.',
        sport: 'running',
        subcategory: 'bolsas-running',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-zip-gymsac-420d'],
        specifications: [
            'Tejido de poliéster 420D',
            'Mayor durabilidad',
            'Incluye Cremallera'
        ],
        details: [
            'Tallas disponibles: XS - 2XL',
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Sublimación completa', 'Diseño personalizable']
    },
    {
        id: 'product25',
        title: 'E47 Running Soft Flask 250 ml',
        price: '4,20 €',
        moq: 100,
        description: 'Botella flexible de hidratación de 250 ml fabricada en TPU libre de BPA, ligera y plegable.',
        sport: 'running',
        subcategory: 'hidratacion',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-soft-flask-250ml'],
        specifications: [
            'Material de TPU libre de BPA',
            'Diseño plegable y Reutilizable',
            'Capacidad: 250 ml'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product26',
        title: 'E47 Running Soft Flask 500 ml',
        price: '4,55 €',
        moq: 100,
        description: 'Botella flexible de hidratación de 500 ml fabricada en TPU libre de BPA, ligera y plegable.',
        sport: 'running',
        subcategory: 'hidratacion',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-soft-flask-500ml'],
        specifications: [
            'Material de TPU libre de BPA',
            'Diseño plegable y Reutilizable',
            'Capacidad: 500 ml'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product27',
        title: 'E47 Folding Cup 200 ml',
        price: '3,80 €',
        moq: 100,
        description: 'Vaso plegable de 200 ml fabricado en TPU libre de BPA, ligero y flexible.',
        sport: 'running',
        subcategory: 'hidratacion',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-folding-cup-200ml'],
        specifications: [
            'Material de TPU libre de BPA',
            'Diseño plegable y Reutilizable',
            'Capacidad: 200 ml'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product28',
        title: 'E47 LED Silicone Wristband',
        price: 'Consultar',
        description: 'Pulsera con luz LED para eventos deportivos, promociones y mayor visibilidad en condiciones de poca luz.',
        sport: 'merchandising',
        subcategory: 'merchandising-pulseras',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-led-silicone-wristband'],
        specifications: [
            'Material de silicona',
            'Luz LED integrada'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product29',
        title: 'E47 RGB LED Wristband',
        price: 'Consultar',
        description: 'Pulsera con luz LED RGB para eventos deportivos y actividades nocturnas.',
        sport: 'merchandising',
        subcategory: 'merchandising-pulseras',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-rgb-led-wristband'],
        specifications: [
            'Material de silicona',
            'Luz LED RGB integrada',
            'Alta Visibilidad',
            'Varios efectos de luz'
        ],
        details: [
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product30',
        title: 'E47 Sync RGB LED Wristband',
        price: 'Consultar',
        description: 'Pulsera con luz LED RGB sincronizable para eventos deportivos y actividades nocturnas.',
        sport: 'merchandising',
        subcategory: 'merchandising-pulseras',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-sync-rgb-led-wristband'],
        specifications: [
            'Material de silicona',
            'Luz LED RGB integrada',
            'Alta Visibilidad',
            'Diseñada para crear efectos de luz coordinados',
            '* Requiere de un panel de control para sincronizar los efectos *'
        ],
        details: [
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product31',
        title: 'E47 Race Bib Magnets',
        price: 'Consultar',
        description: 'Imanes para dorsal diseñados para sujetar el número de carrera de forma segura sin necesidad de imperdibles.',
        sport: 'merchandising',
        subcategory: 'merchandising-eventos',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-race-bib-magnets'],
        specifications: [
            'Sistema Magnético',
            'Ligero y Reutilizable'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product32',
        title: 'E47 Fabric Wristband',
        price: 'Consultar',
        description: 'Pulsera de tela ligera y cómoda diseñada para eventos deportivos y promociones.',
        sport: 'merchandising',
        subcategory: 'merchandising-pulseras',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-fabric-wristband'],
        specifications: [
            'Tejido de poliéster',
            'Diseño ajustable'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    },
    {
        id: 'product33',
        title: 'E47 Silicone Wristband',
        price: 'Consultar',
        description: 'Pulsera de silicona flexible y resistente diseñada para eventos deportivos y promociones.',
        sport: 'merchandising',
        subcategory: 'merchandising-pulseras',
        category: 'accesorios',
        gender: 'unisex',
        image: productImages['e47-silicone-wristband'],
        specifications: [
            'Material de silicona'
        ],
        details: [
            'Colores base: Consultar disponibilidad',
            'Mínimo: Consultar según personalización'
        ],
        options: ['Diseño personalizable']
    }
];

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
        const moqText = product.moq ? `<div style="font-size: 0.85rem; color: #666; margin-top: 4px;">MOQ: ${product.moq} uds</div>` : '';
        priceHTML = `
            <div class="product-price">
                <span class="price-from">Precio:</span>
                <span class="price-amount">${priceAmount}</span>
                ${moqText}
            </div>
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

// ===== CALCULATOR FUNCTIONALITY =====
const calcProduct = document.getElementById('calc-product');
const calcQuantity = document.getElementById('calc-quantity');
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

if (calcProduct && calcQuantity && calcCustomization) {
    calcProduct.addEventListener('change', updateCalculator);
    calcQuantity.addEventListener('input', updateCalculator);
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
    // Renderizar subcategorías para running (deporte por defecto)
    renderSubcategoryFilters('running');
    
    // Renderizar productos iniciales
    renderProducts('running', 'todos', 'todas', ''); // Iniciar con Running, todos los géneros, todas las subcategorías
    
    console.log('✅ Equipo 47 - Eventos + Tienda loaded! 🎨🏃');
    console.log('📦 Products loaded:', products.length);
    console.log('🎨 Products with color variants:', products.filter(p => p.colors && p.colors.length > 0).length);
    console.log('🏃 Running products:', products.filter(p => p.sport === 'running').length);
    console.log('🛍️ Merchandising products:', products.filter(p => p.sport === 'merchandising').length);
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
