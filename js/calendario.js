// =====================================================
// EQUIPO 47 - Calendario de Eventos
// Lee eventos desde Google Sheets y los muestra
// =====================================================

// IMPORTANTE: Cambia este ID por el de tu Google Sheet
const SHEET_ID = '1FgwVSB1w9yJ4CEtot6q40TyQOyeLsG0oF_QCrmgh-2A';
const SHEET_NAME = 'EVENTOS';

// URL de la API de Google Sheets (pública)
const SHEET_URL = `https://docs.google.com/spreadsheets/d/${SHEET_ID}/gviz/tq?tqx=out:json&sheet=${SHEET_NAME}`;

// Variables globales
let allEvents = [];
let currentDate = new Date();
let selectedCategory = 'todas';
let selectedProvincia = 'todas';

// ===== DECODIFICAR SÍMBOLO € =====
function decodeEuro(value) {
    // Si es null o undefined, devolver vacío
    if (value === null || value === undefined) {
        return '';
    }
    
    // Si es número, añadir €
    if (typeof value === 'number') {
        return value + '€';
    }
    
    // Si es string
    if (typeof value === 'string') {
        // Limpiar el string
        let cleaned = value.trim();
        
        // Si está vacío después de limpiar, devolver vacío
        if (cleaned === '') {
            return '';
        }
        
        // Limpiar encoding raro del símbolo €
        cleaned = cleaned.replace(/â‚¬/g, '€');
        
        // Si ya tiene €, devolverlo tal cual
        if (cleaned.includes('€')) {
            return cleaned;
        }
        
        // Si no tiene €, añadirlo solo si parece un número o rango
        // Ejemplos: "10", "10-24", "10 - 24", "Desde 10"
        if (/\d/.test(cleaned)) {
            return cleaned + '€';
        }
        
        // Si no tiene números, devolver tal cual (por si es texto descriptivo)
        return cleaned;
    }
    
    // Para cualquier otro tipo, convertir a string
    return String(value);
}

// ===== CARGAR EVENTOS DESDE GOOGLE SHEETS =====
async function loadEventsFromSheet() {
    try {
        console.log('🔍 Intentando cargar desde:', SHEET_URL);
        const response = await fetch(SHEET_URL);
        console.log('🔍 Response status:', response.status);
        
        const text = await response.text();
        console.log('🔍 Primeros 200 caracteres de la respuesta:', text.substring(0, 200));
        console.log('🔍 Últimos 100 caracteres de la respuesta:', text.substring(text.length - 100));
        
        // Google Sheets devuelve JSON con prefix, lo limpiamos
        // El formato es: google.visualization.Query.setResponse({...});
        const jsonString = text.match(/google\.visualization\.Query\.setResponse\((.*)\);?$/s)?.[1];
        if (!jsonString) {
            console.error('❌ No se pudo extraer el JSON. Respuesta completa:', text);
            throw new Error('Formato de respuesta inválido del Google Sheet');
        }
        console.log('🔍 JSON extraído correctamente');
        const json = JSON.parse(jsonString);
        
        // Procesar las filas
        const rows = json.table.rows;
        allEvents = rows.map(row => {
            const cells = row.c;
            const fecha = cells[2]?.v ? parseGoogleDate(cells[2].v) : null;
            
            // Log para debug
            if (fecha) {
                console.log('📅 Evento:', cells[1]?.v, '| Fecha raw:', cells[2]?.v, '| Fecha parseada:', fecha.toLocaleDateString());
            }
            
            const precio = cells[9]?.v;
            const precioDetalle = cells[17]?.v; // Columna R: Precios Detalle
            console.log(`💰 Evento: ${cells[1]?.v} | Precio raw:`, precio, '| Tipo:', typeof precio, '| Detalle:', precioDetalle);
            
            return {
                id: cells[0]?.v || '',
                nombre: cells[1]?.v || '',
                fecha: fecha,
                hora: parseGoogleTime(cells[3]?.v),
                ubicacion: cells[4]?.v || '',
                provincia: cells[5]?.v || '',
                categoria: cells[6]?.v || '',
                descripcion: cells[7]?.v || '',
                distancias: cells[8]?.v || '',
                precios: decodeEuro(precio),
                preciosDetalle: precioDetalle || '', // Texto detallado de precios
                estado: cells[10]?.v || 'Abierto',
                urlInscripcion: cells[11]?.v || '',
                imagenUrl: cells[12]?.v || '',
                organizador: cells[13]?.v || 'Equipo 47',
                email: cells[14]?.v || '',
                telefono: cells[15]?.v || '',
                prioridad: cells[16]?.v || 999 // Columna Q: Prioridad (999 = sin prioridad)
            };
        }).filter(event => event.fecha); // Solo eventos con fecha válida
        
        console.log(`✅ ${allEvents.length} eventos cargados`);
        renderCalendar();
        renderEventsList();
        
    } catch (error) {
        console.error('❌ Error cargando eventos:', error);
        document.getElementById('calendar-grid').innerHTML = 
            '<p style="grid-column: 1/-1; text-align: center; color: #E74C3C; padding: 40px;">Error cargando eventos. Verifica la configuración del Google Sheet.</p>';
    }
}

// ===== PARSEAR FECHA DE GOOGLE SHEETS =====
function parseGoogleDate(value) {
    // Google Sheets puede devolver diferentes formatos
    if (typeof value === 'string') {
        // Formato especial de Google Sheets: "Date(2026,0,15)"
        const dateMatch = value.match(/Date\((\d+),(\d+),(\d+)\)/);
        if (dateMatch) {
            const year = parseInt(dateMatch[1]);
            const month = parseInt(dateMatch[2]); // Ya viene en formato 0-11
            const day = parseInt(dateMatch[3]);
            return new Date(year, month, day);
        }
        
        // Formato ISO: "2026-02-20"
        if (value.match(/^\d{4}-\d{2}-\d{2}/)) {
            return new Date(value);
        }
        // Formato europeo: "20/02/2026"
        if (value.match(/^\d{1,2}\/\d{1,2}\/\d{4}/)) {
            const [day, month, year] = value.split('/');
            return new Date(year, month - 1, day);
        }
        // Otros formatos
        return new Date(value);
    } else if (typeof value === 'number') {
        // Número de serie de fecha de Excel/Google Sheets
        return new Date((value - 25569) * 86400 * 1000);
    } else if (value && value.v !== undefined) {
        // A veces Google Sheets devuelve un objeto con propiedad 'v'
        return parseGoogleDate(value.v);
    }
    return null;
}

// ===== PARSEAR HORA DE GOOGLE SHEETS =====
function parseGoogleTime(value) {
    if (!value) return '';
    
    // Si es string con formato "Date(1899,11,30,10,30,0)"
    if (typeof value === 'string') {
        const timeMatch = value.match(/Date\(\d+,\d+,\d+,(\d+),(\d+),(\d+)\)/);
        if (timeMatch) {
            const hours = timeMatch[1].padStart(2, '0');
            const minutes = timeMatch[2].padStart(2, '0');
            return `${hours}:${minutes}h`;
        }
        // Si ya es texto normal como "10:30", añadir h si no la tiene
        if (value.match(/^\d{1,2}:\d{2}$/)) {
            return value + 'h';
        }
        // Si ya tiene h, devolverlo tal cual
        if (value.match(/^\d{1,2}:\d{2}h$/)) {
            return value;
        }
    }
    
    // Si es número (fracción del día)
    if (typeof value === 'number') {
        const totalMinutes = Math.round(value * 24 * 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}h`;
    }
    
    return value.toString();
}

// ===== RENDERIZAR CALENDARIO =====
function renderCalendar() {
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    
    // Actualizar título del mes
    const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                       'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    document.getElementById('current-month').textContent = `${monthNames[month]} ${year}`;
    
    // Obtener primer y último día del mes
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startDayOfWeek = firstDay.getDay() === 0 ? 6 : firstDay.getDay() - 1; // Lunes = 0
    
    // Limpiar grid
    const grid = document.getElementById('calendar-grid');
    grid.innerHTML = '';
    
    // Headers de días
    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    dayNames.forEach(day => {
        const header = document.createElement('div');
        header.className = 'calendar-day-header';
        header.textContent = day;
        grid.appendChild(header);
    });
    
    // Días vacíos al inicio
    for (let i = 0; i < startDayOfWeek; i++) {
        const emptyDay = document.createElement('div');
        emptyDay.className = 'calendar-day empty';
        grid.appendChild(emptyDay);
    }
    
    // Días del mes
    for (let day = 1; day <= daysInMonth; day++) {
        const dayDate = new Date(year, month, day);
        const dayElement = document.createElement('div');
        dayElement.className = 'calendar-day';
        
        // Verificar si hay eventos este día
        const dayEvents = getEventsForDay(dayDate);
        
        if (dayEvents.length > 0) {
            dayElement.classList.add('has-events');
            
            // Mostrar icono de categoría
            const categoryIcon = getCategoryIcon(dayEvents[0].categoria);
            
            // Si hay 1 o 2 eventos, mostrar nombre(s). Si hay más, mostrar cantidad
            let eventInfo = '';
            if (dayEvents.length === 1) {
                const shortName = dayEvents[0].nombre.length > 15 
                    ? dayEvents[0].nombre.substring(0, 15) + '...' 
                    : dayEvents[0].nombre;
                eventInfo = `<div class="day-event-name">${categoryIcon} ${shortName}</div>`;
            } else if (dayEvents.length === 2) {
                eventInfo = `<div class="day-event-name">${categoryIcon} ${dayEvents.length} eventos</div>`;
            } else {
                eventInfo = `<div class="day-event-name">${categoryIcon} ${dayEvents.length} eventos</div>`;
            }
            
            dayElement.innerHTML = `
                <div class="day-number">${day}</div>
                ${eventInfo}
            `;
            dayElement.onclick = () => showDayEvents(dayDate, dayEvents);
        } else {
            dayElement.innerHTML = `<div class="day-number">${day}</div>`;
        }
        
        // Marcar día actual
        const today = new Date();
        if (dayDate.toDateString() === today.toDateString()) {
            dayElement.classList.add('today');
        }
        
        grid.appendChild(dayElement);
    }
}

// ===== OBTENER EVENTOS DE UN DÍA =====
function getEventsForDay(date) {
    return allEvents.filter(event => {
        if (!event.fecha) return false;
        const eventDate = new Date(event.fecha);
        
        // Verificar si la fecha coincide
        const dateMatches = eventDate.toDateString() === date.toDateString();
        
        // Verificar categoría (soporta múltiples categorías separadas por comas)
        const categoryMatches = selectedCategory === 'todas' || 
            event.categoria.split(',').map(c => c.trim()).includes(selectedCategory);
        
        // Verificar provincia
        const provinciaMatches = selectedProvincia === 'todas' || event.provincia === selectedProvincia;
        
        return dateMatches && categoryMatches && provinciaMatches;
    });
}

// ===== MOSTRAR EVENTOS DE UN DÍA (MODAL) =====
function showDayEvents(date, events) {
    const modal = document.getElementById('event-modal');
    const modalContent = document.getElementById('modal-event-content');
    
    const monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                       'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    
    let html = `<h2>Eventos - ${date.getDate()} de ${monthNames[date.getMonth()]} ${date.getFullYear()}</h2>`;
    
    events.forEach(event => {
        html += renderEventCard(event, true);
    });
    
    modalContent.innerHTML = html;
    modal.style.display = 'flex';
}

// ===== RENDERIZAR TARJETA DE EVENTO =====
function renderEventCard(event, isModal = false) {
    const estadoClass = {
        'Abierto': 'estado-abierto',
        'Últimas plazas': 'estado-ultimas',
        'Agotado': 'estado-agotado',
        'Lista de espera': 'estado-lista-espera',
        'Finalizado': 'estado-finalizado'
    };
    
    const eventDate = new Date(event.fecha);
    const today = new Date();
    const daysUntil = Math.ceil((eventDate - today) / (1000 * 60 * 60 * 24));
    
    // Procesar múltiples categorías
    const categorias = event.categoria.split(',').map(c => c.trim());
    const categoriasHTML = categorias.map(cat => 
        `<span class="event-categoria">${getCategoryIcon(cat)} ${cat}</span>`
    ).join(' ');
    
    // Determinar texto del botón según estado
    let inscripcionButton = '';
    if (event.urlInscripcion && event.estado !== 'Finalizado') {
        let buttonText = 'Inscribirme';
        if (event.estado === 'Lista de espera') {
            buttonText = 'Unirme a lista de espera';
        } else if (event.estado === 'Agotado') {
            buttonText = 'Ver información';
        }
        inscripcionButton = `
            <a href="${event.urlInscripcion}" target="_blank" class="btn-event-register">
                ${buttonText}
            </a>`;
    }
    
    // Botón "Ver detalles" solo si NO estamos en modal
    let detailsButton = '';
    if (!isModal) {
        detailsButton = `
            <button class="btn-event-details" data-event-id="${event.id}">
                Ver detalles
            </button>`;
    }
    
    return `
        <div class="event-card ${isModal ? 'event-card-modal' : ''}">
            ${event.imagenUrl ? `<div class="event-image" style="background-image: url('${event.imagenUrl}')"></div>` : ''}
            <div class="event-content">
                <div class="event-header">
                    <div class="event-categorias">${categoriasHTML}</div>
                    <span class="event-estado ${estadoClass[event.estado]}">${event.estado}</span>
                </div>
                <h3 class="event-nombre">${event.nombre}</h3>
                <div class="event-info">
                    <div class="event-info-item">
                        <span class="event-icon">📅</span>
                        <span>${formatDate(event.fecha)} a las ${event.hora}</span>
                    </div>
                    <div class="event-info-item">
                        <span class="event-icon">📍</span>
                        <span>${event.ubicacion}, ${event.provincia}</span>
                    </div>
                    ${event.distancias ? `
                    <div class="event-info-item">
                        <span class="event-icon">🏁</span>
                        <span>${event.distancias}</span>
                    </div>` : ''}
                    ${event.precios ? `
                    <div class="event-info-item">
                        <span class="event-icon">💰</span>
                        <span>Desde ${event.precios}</span>
                    </div>` : ''}
                    ${daysUntil > 0 && daysUntil < 90 ? `
                    <div class="event-countdown">
                        ⏱️ Faltan ${daysUntil} día${daysUntil !== 1 ? 's' : ''}
                    </div>` : ''}
                </div>
                ${event.descripcion ? `<p class="event-descripcion">${event.descripcion}</p>` : ''}
                <div class="event-actions">
                    ${detailsButton}
                    ${inscripcionButton}
                </div>
            </div>
        </div>
    `;
}

// ===== MOSTRAR DETALLES COMPLETOS DEL EVENTO =====
function showEventDetails(eventId) {
    console.log('🔍 Ver detalles clicked - ID:', eventId, 'Tipo:', typeof eventId);
    console.log('🔍 IDs disponibles:', allEvents.map(e => ({id: e.id, tipo: typeof e.id})));
    
    // Comparación flexible (== en lugar de ===)
    const event = allEvents.find(e => e.id == eventId);
    
    if (!event) {
        console.error('❌ Evento no encontrado con ID:', eventId);
        return;
    }
    
    console.log('✅ Evento encontrado:', event.nombre);
    
    const modal = document.getElementById('event-modal');
    const modalContent = document.getElementById('modal-event-content');
    
    const estadoClass = {
        'Abierto': 'estado-abierto',
        'Últimas plazas': 'estado-ultimas',
        'Agotado': 'estado-agotado',
        'Lista de espera': 'estado-lista-espera',
        'Finalizado': 'estado-finalizado'
    };
    
    // Procesar múltiples categorías
    const categorias = event.categoria.split(',').map(c => c.trim());
    const categoriasHTML = categorias.map(cat => 
        `<span class="event-categoria-badge">${getCategoryIcon(cat)} ${cat}</span>`
    ).join(' ');
    
    // Determinar texto del botón según estado
    let inscripcionButton = '';
    if (event.urlInscripcion && event.estado !== 'Finalizado') {
        let buttonText = 'Inscribirme ahora';
        let buttonClass = 'btn btn-primary';
        
        if (event.estado === 'Lista de espera') {
            buttonText = 'Unirme a lista de espera';
            buttonClass = 'btn btn-secondary';
        } else if (event.estado === 'Agotado') {
            buttonText = 'Ver más información';
            buttonClass = 'btn btn-secondary';
        }
        
        inscripcionButton = `
            <a href="${event.urlInscripcion}" target="_blank" class="${buttonClass}">
                ${buttonText}
            </a>`;
    }
    
    modalContent.innerHTML = `
        <div class="event-details">
            ${event.imagenUrl ? `<img src="${event.imagenUrl}" alt="${event.nombre}" class="event-details-image">` : ''}
            <div class="event-details-header">
                <div class="event-categorias">${categoriasHTML}</div>
                <span class="event-estado ${estadoClass[event.estado]}">${event.estado}</span>
            </div>
            <h2 class="event-details-title">${event.nombre}</h2>
            
            <div class="event-details-info">
                <div class="info-row">
                    <span class="info-icon">📅</span>
                    <strong>Fecha:</strong> ${formatDate(event.fecha)}
                </div>
                <div class="info-row">
                    <span class="info-icon">🕐</span>
                    <strong>Hora:</strong> ${event.hora}
                </div>
                <div class="info-row">
                    <span class="info-icon">📍</span>
                    <strong>Ubicación:</strong> ${event.ubicacion}, ${event.provincia}
                </div>
                ${event.distancias ? `
                <div class="info-row">
                    <span class="info-icon">🏁</span>
                    <strong>Distancias:</strong> ${event.distancias}
                </div>` : ''}
                ${(event.preciosDetalle || event.precios) ? `
                <div class="info-row">
                    <span class="info-icon">💰</span>
                    <strong>Precios:</strong> ${event.preciosDetalle || event.precios}
                </div>` : ''}
                <div class="info-row">
                    <span class="info-icon">👥</span>
                    <strong>Organizador:</strong> ${event.organizador}
                </div>
            </div>
            
            ${event.descripcion ? `
            <div class="event-details-description">
                <h3>Descripción</h3>
                <p>${event.descripcion}</p>
            </div>` : ''}
            
            <div class="event-details-actions">
                ${inscripcionButton}
                ${event.email ? `
                <a href="mailto:${event.email}" class="btn btn-secondary">
                    Contactar por email
                </a>` : ''}
            </div>
        </div>
    `;
    
    modal.style.display = 'flex';
}

// ===== RENDERIZAR LISTA DE PRÓXIMOS EVENTOS =====
function renderEventsList() {
    const container = document.getElementById('events-list');
    
    // Filtrar y ordenar eventos
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const upcomingEvents = allEvents
        .filter(event => {
            const eventDate = new Date(event.fecha);
            
            // Verificar categoría (soporta múltiples)
            const categoryMatches = selectedCategory === 'todas' || 
                event.categoria.split(',').map(c => c.trim()).includes(selectedCategory);
            
            // Verificar provincia
            const provinciaMatches = selectedProvincia === 'todas' || event.provincia === selectedProvincia;
            
            return eventDate >= today && categoryMatches && provinciaMatches;
        })
        .sort((a, b) => {
            // Primero ordenar por prioridad (menor número = mayor prioridad)
            if (a.prioridad !== b.prioridad) {
                return a.prioridad - b.prioridad;
            }
            // Si tienen la misma prioridad, ordenar por fecha (más próximo primero)
            return new Date(a.fecha) - new Date(b.fecha);
        })
        .slice(0, 6); // Mostrar solo los 6 próximos
    
    if (upcomingEvents.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #666; padding: 40px;">No hay eventos próximos con los filtros seleccionados.</p>';
        return;
    }
    
    container.innerHTML = upcomingEvents.map(event => renderEventCard(event)).join('');
}

// ===== NAVEGACIÓN DEL CALENDARIO =====
function previousMonth() {
    currentDate.setMonth(currentDate.getMonth() - 1);
    renderCalendar();
}

function nextMonth() {
    currentDate.setMonth(currentDate.getMonth() + 1);
    renderCalendar();
}

// ===== FILTROS =====
function filterByCategory(categoria) {
    selectedCategory = categoria;
    
    // Actualizar botones activos
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
    
    renderCalendar();
    renderEventsList();
}

function filterByProvincia(provincia) {
    selectedProvincia = provincia;
    renderCalendar();
    renderEventsList();
}

// ===== CERRAR MODAL =====
function closeModal() {
    document.getElementById('event-modal').style.display = 'none';
}

// Cerrar modal al hacer clic fuera
window.onclick = function(event) {
    const modal = document.getElementById('event-modal');
    if (event.target === modal) {
        closeModal();
    }
}

// ===== UTILIDADES =====
function formatDate(date) {
    const d = new Date(date);
    const day = d.getDate();
    const monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                       'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    const month = monthNames[d.getMonth()];
    const year = d.getFullYear();
    return `${day} de ${month} de ${year}`;
}

function getCategoryIcon(categoria) {
    const icons = {
        'Running': '🏃',
        'Trail': '⛰️',
        'Ciclismo': '🚴',
        'Triatlón': '🏊',
        'Natación': '🏊',
        'Obstáculos': '🧗',
        'Solidaria': '❤️'
    };
    return icons[categoria] || '🏃';
}

// ===== INICIALIZAR =====
document.addEventListener('DOMContentLoaded', () => {
    loadEventsFromSheet();
    
    // Event listeners
    document.getElementById('prev-month').addEventListener('click', previousMonth);
    document.getElementById('next-month').addEventListener('click', nextMonth);
    document.getElementById('close-modal').addEventListener('click', closeModal);
    
    // Event delegation para botones "Ver detalles"
    document.addEventListener('click', (e) => {
        const button = e.target.closest('.btn-event-details');
        if (button) {
            const eventId = button.getAttribute('data-event-id');
            if (eventId) {
                showEventDetails(eventId);
            }
        }
    });
});

console.log('✅ Calendario script cargado');
