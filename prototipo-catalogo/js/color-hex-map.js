// ===== MAPA DE NOMBRE DE COLOR -> CÓDIGO HEX =====
// catalogo_web solo trae el NOMBRE del color (ej. "Negro", "Rojo"), no un
// código hex para pintar el punto de color en la tarjeta de producto.
// En vez de pedir otro cambio de esquema a Producciones, resolvemos el hex
// aquí, en la web, a partir del nombre.
//
// Si aparece un nombre de color que no está en esta tabla, se usa
// COLOR_HEX_FALLBACK (gris neutro) y se avisa por consola, para poder
// detectar y añadir el color que falte sin que se rompa nada visualmente.

const COLOR_HEX_MAP = {
    'negro': '#1a1a1a',
    'blanco': '#ffffff',
    'gris': '#9e9e9e',
    'gris oscuro': '#4a4a4a',
    'gris claro': '#d5d5d5',
    'rojo': '#e63946',
    'azul': '#2c5f8a',
    'azul marino': '#1b2a4a',
    'azul claro': '#7ba7d9',
    'verde': '#3a7d44',
    'verde oscuro': '#2d5c33',
    'amarillo': '#f2c94c',
    'naranja': '#FF4B1F',
    'rosa': '#e8a0bf',
    'morado': '#6a4c93',
    'marrón': '#6b4423',
    'beige': '#d8c3a5',
    'burdeos': '#7b1e3a'
};

const COLOR_HEX_FALLBACK = '#cccccc';

function resolverHexDeColor(nombreColor) {
    if (!nombreColor) return COLOR_HEX_FALLBACK;
    const clave = nombreColor.trim().toLowerCase();
    const hex = COLOR_HEX_MAP[clave];
    if (!hex) {
        console.warn(`⚠️ Color sin hex mapeado: "${nombreColor}" — usando gris de reserva. Añadir a COLOR_HEX_MAP en color-hex-map.js`);
        return COLOR_HEX_FALLBACK;
    }
    return hex;
}
