// ============================================
// UTILIDADES - ALMACÉN MADRID v2
// ============================================

// ── TOAST NOTIFICATIONS ─────────────────────
function toast(message, duration = 3000) {
  // Remover toast anterior si existe
  const existing = document.querySelector('[role="status"]');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.setAttribute('role', 'status');
  toast.textContent = message;
  toast.style.cssText = `
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: #111;
    color: white;
    padding: 12px 24px;
    border-radius: 6px;
    font-size: 13px;
    z-index: 9999;
    animation: slideUp 0.3s ease;
  `;
  
  document.body.appendChild(toast);
  
  setTimeout(() => {
    toast.style.animation = 'slideDown 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// ── FORMATEO DE FECHAS ──────────────────────
function formatDate(date) {
  if (!date) return '—';
  const d = new Date(date);
  return d.toLocaleDateString('es-ES', { 
    day: '2-digit', 
    month: 'short', 
    year: 'numeric' 
  });
}

function formatDateTime(date) {
  if (!date) return '—';
  const d = new Date(date);
  return d.toLocaleDateString('es-ES', { 
    day: '2-digit', 
    month: 'short', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// ── MODAL ───────────────────────────────────
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('open');
    document.body.style.overflow = 'auto';
  }
}

// Cerrar modal al hacer click fuera
document.addEventListener('click', (e) => {
  const modal = e.target.closest('.modal.open');
  if (e.target.classList.contains('modal-overlay')) {
    closeModal(modal.id);
  }
});

// ── VALIDACIÓN ──────────────────────────────
function validarEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function validarFecha(fecha) {
  return !isNaN(Date.parse(fecha));
}

function limpiarString(str) {
  return str.trim().toLowerCase();
}

// ── NUMEROS ─────────────────────────────────
function formatNumber(n) {
  return n.toLocaleString('es-ES');
}

function parseNumber(str) {
  return parseInt(str.replace(/\D/g, '')) || 0;
}

// ── STOCK ───────────────────────────────────
async function calcularStockDisponible(varianteId) {
  const variante = await sb.from('variantes').select('stock_total').eq('id', varianteId).single();
  const cajas = await sb.from('cajas').select('cantidad').eq('variante_id', varianteId);
  
  if (!variante.data) return 0;
  
  const enCajas = (cajas.data || []).reduce((sum, c) => sum + c.cantidad, 0);
  return Math.max(0, variante.data.stock_total - enCajas);
}

// ── BÚSQUEDA ────────────────────────────────
function filtrarArray(array, query, fields) {
  if (!query) return array;
  const q = query.toLowerCase();
  return array.filter(item => 
    fields.some(field => {
      const value = item[field];
      return value && value.toString().toLowerCase().includes(q);
    })
  );
}

// ── EXPORTAR DATOS ──────────────────────────
function exportarCSV(datos, nombre) {
  if (!datos || datos.length === 0) {
    toast('No hay datos para exportar');
    return;
  }

  const headers = Object.keys(datos[0]);
  const csv = [
    headers.join(','),
    ...datos.map(row => 
      headers.map(header => {
        const value = row[header];
        if (typeof value === 'string' && value.includes(',')) {
          return `"${value}"`;
        }
        return value || '';
      }).join(',')
    )
  ].join('\n');

  const blob = new Blob([csv], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${nombre}_${new Date().getTime()}.csv`;
  a.click();
  window.URL.revokeObjectURL(url);
  
  toast('✓ CSV descargado');
}

// ── CONFIRMACIÓN ────────────────────────────
function confirmar(mensaje) {
  return window.confirm(mensaje);
}

// ── CÓDIGO QR (GENERADOR) ───────────────────
function generarCodigoQR(texto) {
  // Usar API externa para generar QR
  // Formato: https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=TEXTO
  return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(texto)}`;
}

// ── ANIMACIONES ─────────────────────────────
const styles = document.createElement('style');
styles.textContent = `
  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateX(-50%) translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
  }
  
  @keyframes slideDown {
    from {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
    to {
      opacity: 0;
      transform: translateX(-50%) translateY(20px);
    }
  }
  
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  
  @keyframes fadeOut {
    from { opacity: 1; }
    to { opacity: 0; }
  }
`;
document.head.appendChild(styles);

// ── LOADING ─────────────────────────────────
function mostrarLoading(elemento) {
  if (typeof elemento === 'string') {
    elemento = document.getElementById(elemento);
  }
  if (elemento) {
    elemento.innerHTML = '<div class="loading">Cargando...</div>';
  }
}

function ocultarLoading(elemento) {
  if (typeof elemento === 'string') {
    elemento = document.getElementById(elemento);
  }
  if (elemento) {
    elemento.innerHTML = '';
  }
}

// ── COPY TO CLIPBOARD ───────────────────────
async function copiarAlPortapapeles(texto) {
  try {
    await navigator.clipboard.writeText(texto);
    toast('✓ Copiado');
  } catch (err) {
    console.error('Error copiando:', err);
  }
}

// ── HELPERS DE ARRAYS ───────────────────────
function agruparPor(array, clave) {
  return array.reduce((acc, item) => {
    const key = item[clave];
    if (!acc[key]) acc[key] = [];
    acc[key].push(item);
    return acc;
  }, {});
}

function ordenar(array, clave, ascending = true) {
  return [...array].sort((a, b) => {
    if (ascending) {
      return a[clave] > b[clave] ? 1 : -1;
    } else {
      return a[clave] < b[clave] ? 1 : -1;
    }
  });
}

// ── AUTENTICACIÓN SIMPLE (PASSWORD) ─────────
const PASSWORD_ALMACEN = localStorage.getItem('almacen-pass') || null;

function requiereAutenticacion() {
  if (!PASSWORD_ALMACEN) {
    const pass = prompt('🔐 Contraseña del almacén:');
    if (!pass) {
      location.reload();
      return false;
    }
    // Aquí va la contraseña (la configuras en admin)
    const PASS_CORRECTA = 'E47almacen2024'; // ⚠️ Cambiar en producción
    if (pass !== PASS_CORRECTA) {
      alert('❌ Contraseña incorrecta');
      return false;
    }
    localStorage.setItem('almacen-pass', pass);
  }
  return true;
}

function cerrarSesion() {
  localStorage.removeItem('almacen-pass');
  location.reload();
}

// ── DEBUG ───────────────────────────────────
function debug(msg, data = null) {
  if (location.hostname === 'localhost' || new URLSearchParams(location.search).get('debug')) {
    console.log(`[DEBUG] ${msg}`, data || '');
  }
}

// ── UTILIDADES DE TIEMPO ────────────────────
function hace(fecha) {
  if (!fecha) return '—';
  const ms = new Date() - new Date(fecha);
  const minutos = Math.floor(ms / 60000);
  const horas = Math.floor(minutos / 60);
  const dias = Math.floor(horas / 24);
  
  if (minutos < 1) return 'ahora';
  if (minutos < 60) return `hace ${minutos}m`;
  if (horas < 24) return `hace ${horas}h`;
  return `hace ${dias}d`;
}

// ── INICIALIZACIÓN GLOBAL ───────────────────
console.log('✓ Utils cargado');
