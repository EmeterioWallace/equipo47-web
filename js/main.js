// =====================================================
// EQUIPO 47 - Main JavaScript
// Scripts comunes para todas las páginas
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

if (nav) {
    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;
        
        if (currentScroll > 100) {
            nav.style.boxShadow = '0 2px 20px rgba(0,0,0,0.1)';
        } else {
            nav.style.boxShadow = 'none';
        }
        
        lastScroll = currentScroll;
    });
}

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

    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        }
    });

    // Close menu when clicking on a link
    navMenu.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        });
    });
}

// ===== FORM SUBMISSIONS =====
const contactForms = document.querySelectorAll('.contact-form, .volunteer-form');

contactForms.forEach(form => {
    form.addEventListener('submit', (e) => {
        e.preventDefault();
        
        // Show success message
        alert('¡Gracias por tu solicitud! Nos pondremos en contacto contigo lo antes posible.');
        
        // Reset form
        form.reset();
        
        // Scroll to top
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    });
});

// ===== INTERSECTION OBSERVER FOR SCROLL ANIMATIONS =====
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const fadeInObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe elements with fade-in animation
document.querySelectorAll('.process-step, .case-card, .evento-card, .benefit-card, .service-card').forEach(el => {
    if (el) {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        fadeInObserver.observe(el);
    }
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

if (sections.length > 0) {
    window.addEventListener('scroll', highlightNavigation);
}

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
        
        // Handle different formats
        if (element.textContent.includes('%')) {
            element.textContent = displayValue + '%';
        } else if (element.textContent.includes('+')) {
            element.textContent = displayValue + '+';
        } else if (element.textContent.includes('K')) {
            element.textContent = displayValue + 'K+';
        } else {
            element.textContent = displayValue;
        }
    }, 16);
}

// Trigger stats animation when visible
const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const statNumber = entry.target.querySelector('.stat-number, .stat-big');
            if (statNumber && !statNumber.classList.contains('animated')) {
                statNumber.classList.add('animated');
                const text = statNumber.textContent;
                const targetValue = parseInt(text.replace(/\D/g, ''));
                animateValue(statNumber, 0, targetValue, 2000);
            }
        }
    });
}, { threshold: 0.5 });

document.querySelectorAll('.stat-item, .stat-box').forEach(stat => {
    if (stat) {
        statsObserver.observe(stat);
    }
});

// ===== SMOOTH REVEAL ON PAGE LOAD =====
window.addEventListener('load', () => {
    document.body.classList.add('loaded');
});

// ===== CALCULATOR FUNCTIONALITY (only on tienda.html) =====
const calcProduct = document.getElementById('calc-product');
const calcQuantity = document.getElementById('calc-quantity');
const calcCustomization = document.getElementById('calc-customization');
const basePrice = document.getElementById('base-price');
const customPrice = document.getElementById('custom-price');
const totalPrice = document.getElementById('total-price');
const unitPrice = document.getElementById('unit-price');

if (calcProduct && calcQuantity && calcCustomization) {
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

    calcProduct.addEventListener('change', updateCalculator);
    calcQuantity.addEventListener('input', updateCalculator);
    calcCustomization.addEventListener('change', updateCalculator);
    
    updateCalculator();
}

// ===== CONSOLE LOG =====
console.log('✅ Equipo 47 - Main scripts loaded');

// ===== PREVENIR ZOOM ACCIDENTAL EN MÓVILES =====
// Prevenir doble-tap zoom en elementos específicos
document.addEventListener('touchstart', function(e) {
    if (e.touches.length > 1) {
        return;
    }
    
    const t2 = e.timeStamp;
    const t1 = this.lastTouch || t2;
    const dt = t2 - t1;
    const fingers = e.touches.length;
    
    this.lastTouch = t2;
    
    if (!dt || dt > 500 || fingers > 1) {
        return;
    }
    
    e.preventDefault();
    e.target.click();
});

// ===== FIX: Prevenir scroll al cambiar de campo en formularios =====
document.addEventListener('DOMContentLoaded', function() {
    // Eliminar comportamiento de scroll automático en blur
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
