// =====================================================
// EQUIPO 47 - Product Images Database
// =====================================================
// Este archivo contiene todas las rutas a las imágenes de productos
// Usar archivos externos es más profesional que base64: mejor rendimiento, 
// mejor SEO, y código más limpio y mantenible.
// =====================================================

const productImages = {
    // ===== RUNNING TEE 47 =====
    'running-tee-47-hombre-blanco': 'images/products/running/running-tee-47-hombre-blanco.jpg',
    'running-tee-47-hombre-gris': 'images/products/running/running-tee-47-hombre-gris.jpg',
    'running-tee-47-hombre-negro': 'images/products/running/running-tee-47-hombre-negro.jpg',
    
    'running-tee-47-mujer-blanco': 'images/products/running/running-tee-47-mujer-blanco.jpg',
    'running-tee-47-mujer-gris': 'images/products/running/running-tee-47-mujer-gris.jpg',
    'running-tee-47-mujer-negro': 'images/products/running/running-tee-47-mujer-negro.jpg',
    
    // Alias para compatibilidad con código existente
    'running-tee-hombre-blanco': 'images/products/running/running-tee-47-hombre-blanco.jpg',
    'running-tee-hombre-gris': 'images/products/running/running-tee-47-hombre-gris.jpg',
    'running-tee-hombre-negro': 'images/products/running/running-tee-47-hombre-negro.jpg',
    
    'running-tee-mujer-blanco': 'images/products/running/running-tee-47-mujer-blanco.jpg',
    'running-tee-mujer-gris': 'images/products/running/running-tee-47-mujer-gris.jpg',
    'running-tee-mujer-negro': 'images/products/running/running-tee-47-mujer-negro.jpg',
    
    // ===== RACE SINGLET 47 =====
    'race-singlet-47-hombre-blanco': 'images/products/running/race-singlet-47-hombre-blanco.jpg',
    'race-singlet-47-hombre-gris': 'images/products/running/race-singlet-47-hombre-gris.jpg',
    'race-singlet-47-hombre-negro': 'images/products/running/race-singlet-47-hombre-negro.jpg',
    
    'race-singlet-47-mujer-blanco': 'images/products/running/race-singlet-47-mujer-blanco.jpg',
    'race-singlet-47-mujer-gris': 'images/products/running/race-singlet-47-mujer-gris.jpg',
    'race-singlet-47-mujer-negro': 'images/products/running/race-singlet-47-mujer-negro.jpg',
    
    // ===== WIND JACKET 47 =====
    'wind-jacket-47-azul': 'images/products/running/wind-jacket-47-azul.jpg',
    'wind-jacket-47-blanco': 'images/products/running/wind-jacket-47-blanco.jpg',
    'wind-jacket-47-naranja': 'images/products/running/wind-jacket-47-naranja.jpg',
    'wind-jacket-47-negro': 'images/products/running/wind-jacket-47-negro.jpg',
    'wind-jacket-47-verde': 'images/products/running/wind-jacket-47-verde.jpg',
    
    // Alias para compatibilidad
    'wind-jacket-azul': 'images/products/running/wind-jacket-47-azul.jpg',
    'wind-jacket-blanco': 'images/products/running/wind-jacket-47-blanco.jpg',
    'wind-jacket-naranja': 'images/products/running/wind-jacket-47-naranja.jpg',
    'wind-jacket-negro': 'images/products/running/wind-jacket-47-negro.jpg',
    'wind-jacket-verde': 'images/products/running/wind-jacket-47-verde.jpg',
    
    // ===== RAIN JACKET 47 (CHUBASQUERO) =====
    'chubasquero-rain-jacket-47-amarilla': 'images/products/running/chubasquero-rain-jacket-47-amarilla.jpg',
    'chubasquero-rain-jacket-47-azul': 'images/products/running/chubasquero-rain-jacket-47-azul.jpg',
    'chubasquero-rain-jacket-47-azulclaro': 'images/products/running/chubasquero-rain-jacket-47-azulclaro.jpg',
    'chubasquero-rain-jacket-47-blanco': 'images/products/running/chubasquero-rain-jacket-47-blanco.jpg',
    'chubasquero-rain-jacket-47-granate': 'images/products/running/chubasquero-rain-jacket-47-granate.jpg',
    'chubasquero-rain-jacket-47-gris': 'images/products/running/chubasquero-rain-jacket-47-gris.jpg',
    'chubasquero-rain-jacket-47-naranja': 'images/products/running/chubasquero-rain-jacket-47-naranja.jpg',
    'chubasquero-rain-jacket-47-negro': 'images/products/running/chubasquero-rain-jacket-47-negro.jpg',
    'chubasquero-rain-jacket-47-rosaclaro': 'images/products/running/chubasquero-rain-jacket-47-rosaclaro.jpg',
    'chubasquero-rain-jacket-47-rosaoscuro': 'images/products/running/chubasquero-rain-jacket-47-rosaoscuro.jpg',
    'chubasquero-rain-jacket-47-verde': 'images/products/running/chubasquero-rain-jacket-47-verde.jpg',
    
    // ===== SUDADERAS =====
    'sudadera-training-pro': 'images/products/running/sudadera-training-pro.jpg',
    'sudadera-training': 'images/products/running/sudadera-training-pro.jpg', // Alias
    
    'sudadera-lifestyle-premium': 'images/products/running/sudadera-lifestyle-premium.jpg',
    'sudadera-lifestyle': 'images/products/running/sudadera-lifestyle-premium.jpg', // Alias
    
    // ===== CORTAVIENTOS =====
    'cortavientos-training-pro-hombre': 'images/products/running/cortavientos-training-pro-hombre.jpg',
    'cortavientos-training-hombre': 'images/products/running/cortavientos-training-pro-hombre.jpg', // Alias
    
    'cortavientos-training-pro-mujer': 'images/products/running/cortavientos-training-pro-mujer.jpg',
    'cortavientos-training-mujer': 'images/products/running/cortavientos-training-pro-mujer.jpg', // Alias
    
    // ===== MALLAS / LEGGINGS =====
    'mallas-training-pro-hombre': 'images/products/running/mallas-training-pro-hombre.jpg',
    'mallas-training-hombre': 'images/products/running/mallas-training-pro-hombre.jpg', // Alias
    
    'mallas-training-pro-mujer': 'images/products/running/mallas-training-pro-mujer.jpg',
    'mallas-training-mujer': 'images/products/running/mallas-training-pro-mujer.jpg', // Alias
    
    // ===== ACCESORIOS =====
    // Manguitos
    'manguitos-01': 'images/products/running/manguitos-01.jpg',
    'manguitos-02': 'images/products/running/manguitos-02.jpg',
    'manguitos': 'images/products/running/manguitos-01.jpg', // Alias por defecto
    
    // Chaleco
    'chaleco-hydrapro-47': 'images/products/running/chaleco-hydrapro-47.jpg',
    'chaleco': 'images/products/running/chaleco-hydrapro-47.jpg', // Alias
    
    // Botella plegable
    'botella-plegable-hydraflex-47': 'images/products/running/botella-plegable-hydraflex-47.jpg',
    'botella': 'images/products/running/botella-plegable-hydraflex-47.jpg', // Alias
    
    // Vaso plegable
    'vaso-plegable-hydraflex-47': 'images/products/running/vaso-plegable-hydraflex-47.jpg',
    'vaso': 'images/products/running/vaso-plegable-hydraflex-47.jpg', // Alias
    
    // Cinta running
    'cinta-running-headfit-pro': 'images/products/running/cinta-running-headfit-pro.jpg',
    'cinta': 'images/products/running/cinta-running-headfit-pro.jpg', // Alias
    
    // Gorro
    'gorro-lifestyle-47-azul': 'images/products/running/gorro-lifestyle-47-azul.jpg',
    'gorro': 'images/products/running/gorro-lifestyle-47-azul.jpg', // Alias
    
    // Guantes
    'guantes-thermalrun-47': 'images/products/running/guantes-thermalrun-47.jpg',
    'guantes': 'images/products/running/guantes-thermalrun-47.jpg', // Alias
    
    // Toalla deportiva
    'toalla-sport-towel-47': 'images/products/running/toalla-sport-towel-47.jpg',
    'toalla': 'images/products/running/toalla-sport-towel-47.jpg', // Alias
    
    // Calcetines Performance Socks
    'calcetines-performance-socks-47-blancos': 'images/products/running/calcetines-performance-socks-47-blancos.jpg',
    'calcetines-performance-socks-47-negros': 'images/products/running/calcetines-performance-socks-47-negros.jpg',
    'performance-socks-blancos': 'images/products/running/calcetines-performance-socks-47-blancos.jpg', // Alias
    'performance-socks-negros': 'images/products/running/calcetines-performance-socks-47-negros.jpg', // Alias
    
    // Calcetines AnkleFit
    'calcetines-anklefit-47-blancos': 'images/products/running/calcetines-anklefit-47-blancos.jpg',
    'calcetines-anklefit-47-negros': 'images/products/running/calcetines-anklefit-47-negros.jpg',
    'anklefit-blancos': 'images/products/running/calcetines-anklefit-47-blancos.jpg', // Alias
    'anklefit-negros': 'images/products/running/calcetines-anklefit-47-negros.jpg', // Alias
    
    // ===== CAMISETAS TÉCNICAS GENÉRICAS =====
    'camiseta-técnica-hombre': 'images/products/running/camiseta-técnica-hombre.jpg',
    'camiseta-tecnica-hombre': 'images/products/running/camiseta-técnica-hombre.jpg', // Sin tilde
    'tech-shirt-hombre': 'images/products/running/camiseta-técnica-hombre.jpg', // Alias
    
    'camiseta-técnica-mujer': 'images/products/running/camiseta-técnica-mujer.jpg',
    'camiseta-tecnica-mujer': 'images/products/running/camiseta-técnica-mujer.jpg', // Sin tilde
    'tech-shirt-mujer': 'images/products/running/camiseta-técnica-mujer.jpg', // Alias
    
    // ===== RUNNING TANK =====
    'e47-running-tank-hombre': 'images/products/running/E47-Running-Tank-Hombre.jpg',
    'running-tank-hombre': 'images/products/running/E47-Running-Tank-Hombre.jpg', // Alias
    'e47-running-tank-mujer': 'images/products/running/E47-Running-Tank-Mujer.jpg',
    'running-tank-mujer': 'images/products/running/E47-Running-Tank-Mujer.jpg', // Alias
    
    // ===== RUNNING TEE SUBLIMACIÓN =====
    'e47-running-tee-hombre': 'images/products/running/E47-Running-Tee-Sublimación-Hombre.jpg',
    'running-tee-sublimacion-hombre': 'images/products/running/E47-Running-Tee-Sublimación-Hombre.jpg', // Alias
    'e47-running-tee-mujer': 'images/products/running/E47-Running-Tee-Sublimación-Mujer.jpg',
    'running-tee-sublimacion-mujer': 'images/products/running/E47-Running-Tee-Sublimación-Mujer.jpg', // Alias
    
    // ===== RUNNING LONG SLEEVE =====
    'e47-running-long-sleeve-hombre': 'images/products/running/E47-Running-Long-Sleeve-Hombre.jpg',
    'running-long-sleeve-hombre': 'images/products/running/E47-Running-Long-Sleeve-Hombre.jpg', // Alias
    'e47-running-long-sleeve-mujer': 'images/products/running/E47-Running-Long-Sleeve-Mujer.jpg',
    'running-long-sleeve-mujer': 'images/products/running/E47-Running-Long-Sleeve-Mujer.jpg', // Alias
    
    // ===== WINDBREAKER =====
    'e47-windbreaker': 'images/products/running/E47-Windbreaker.png',
    'windbreaker-running': 'images/products/running/E47-Windbreaker.png', // Alias
    
    // ===== RAIN JACKET =====
    'e47-running-rainjacket': 'images/products/running/E47-Running-RainJacket.jpg',
    'rainjacket-running': 'images/products/running/E47-Running-RainJacket.jpg', // Alias
    
    // ===== ACCESORIOS =====
    'e47-running-cap': 'images/products/running/E47-Running-Cap-Personalizable.jpg',
    'running-cap': 'images/products/running/E47-Running-Cap-Personalizable.jpg', // Alias
    'e47-winter-running-beanie': 'images/products/running/E47-Winter-Running-Beanie.jpg',
    'winter-beanie': 'images/products/running/E47-Winter-Running-Beanie.jpg', // Alias
    'guantes-thermalrun-47': 'images/products/running/Guantes-ThermalRun-47.jpg',
    'performance-gloves': 'images/products/running/Guantes-ThermalRun-47.jpg', // Alias
    'e47-expandable-running-belt': 'images/products/running/E47-Expandable-Running-Belt.jpg',
    'expandable-belt': 'images/products/running/E47-Expandable-Running-Belt.jpg', // Alias
    'e47-running-bandana': 'images/products/running/E47-Running-Bandana.jpg',
    'running-bandana': 'images/products/running/E47-Running-Bandana.jpg', // Alias
    'e47-milk-silk-bandana': 'images/products/running/Buff_MilkSilk.png',
    'milk-silk-bandana': 'images/products/running/Buff_MilkSilk.png', // Alias
    'e47-performance-running-socks': 'images/products/running/E47-Performance-Running-Socks.jpg',
    'performance-socks': 'images/products/running/E47-Performance-Running-Socks.jpg', // Alias
    'e47-performance-running-socks-terry': 'images/products/running/E47-Performance-Running-Socks-Terry.jpg',
    'performance-socks-terry': 'images/products/running/E47-Performance-Running-Socks-Terry.jpg', // Alias
    'e47-cooling-towel': 'images/products/running/E47-Cooling-Towel.jpg',
    'cooling-towel': 'images/products/running/E47-Cooling-Towel.jpg', // Alias
    'e47-running-armband': 'images/products/running/E47-Running-Armband.jpg',
    'running-armband': 'images/products/running/E47-Running-Armband.jpg', // Alias
    'e47-everyday-tote': 'images/products/running/E47-Everyday-Tote.jpg',
    'everyday-tote': 'images/products/running/E47-Everyday-Tote.jpg', // Alias
    'e47-everyday-tote-colors': 'images/products/running/E47-Everyday-Tote-Colors.jpg',
    'everyday-tote-colors': 'images/products/running/E47-Everyday-Tote-Colors.jpg', // Alias
    'e47-gymsac-210d': 'images/products/running/E47-Gymsac-210D-Sublimación.jpg',
    'gymsac-210d': 'images/products/running/E47-Gymsac-210D-Sublimación.jpg', // Alias
    'e47-gymsac-420d': 'images/products/running/E47-Gymsac-420D-Sublimación.jpg',
    'gymsac-420d': 'images/products/running/E47-Gymsac-420D-Sublimación.jpg', // Alias
    'e47-zip-gymsac-210d': 'images/products/running/E47-Zip-Gymsac-210D-Sublimación.jpg',
    'zip-gymsac-210d': 'images/products/running/E47-Zip-Gymsac-210D-Sublimación.jpg', // Alias
    'e47-zip-gymsac-420d': 'images/products/running/E47-Zip-Gymsac-420D-Sublimación.jpg',
    'zip-gymsac-420d': 'images/products/running/E47-Zip-Gymsac-420D-Sublimación.jpg', // Alias
    'e47-soft-flask-250ml': 'images/products/running/E47-Running-Soft-Flask-250ml.jpg',
    'soft-flask-250ml': 'images/products/running/E47-Running-Soft-Flask-250ml.jpg', // Alias
    'e47-soft-flask-500ml': 'images/products/running/E47-Running-Soft-Flask-500ml.jpg',
    'soft-flask-500ml': 'images/products/running/E47-Running-Soft-Flask-500ml.jpg', // Alias
    'e47-folding-cup-200ml': 'images/products/running/E47-Folding-Cup-200ml.jpg',
    'folding-cup': 'images/products/running/E47-Folding-Cup-200ml.jpg', // Alias
    'e47-led-silicone-wristband': 'images/products/running/E47-LED-Silicone-Wristband.jpg',
    'led-wristband': 'images/products/running/E47-LED-Silicone-Wristband.jpg', // Alias
    'e47-rgb-led-wristband': 'images/products/running/E47-RGB-LED-Wristband.jpg',
    'rgb-led-wristband': 'images/products/running/E47-RGB-LED-Wristband.jpg', // Alias
    'e47-sync-rgb-led-wristband': 'images/products/running/E47-Sync-RGB-LED-Wristband.jpg',
    'sync-rgb-led-wristband': 'images/products/running/E47-Sync-RGB-LED-Wristband.jpg', // Alias
    'e47-race-bib-magnets': 'images/products/running/E47-Race-Bib-Magnets.jpg',
    'race-bib-magnets': 'images/products/running/E47-Race-Bib-Magnets.jpg', // Alias
    'e47-fabric-wristband': 'images/products/running/E47-Fabric-Wristband.jpg',
    'fabric-wristband': 'images/products/running/E47-Fabric-Wristband.jpg', // Alias
    'e47-silicone-wristband': 'images/products/running/E47-Silicone-Wristband.jpg',
    'silicone-wristband': 'images/products/running/E47-Silicone-Wristband.jpg' // Alias
};

// Exportar para usar en otros archivos si es necesario
if (typeof module !== 'undefined' && module.exports) {
    module.exports = productImages;
}

console.log('✅ Product Images loaded:', Object.keys(productImages).length, 'images registered');
