# 🏛️ ALMACÉN MADRID v2 - Equipo 47

Sistema de gestión de inventario para el almacén de Madrid. Datos en Supabase, acceso desde cualquier dispositivo.

---

## 🚀 INICIO RÁPIDO

### URLs
- **Almacén:** `equipo47.com/madrid`
- **Admin:** `equipo47.com/madrid/admin.html`

### Credenciales
- **Contraseña:** `E47almacen2024` (cambiar en `js/utils.js` línea 162)

---

## 📁 ESTRUCTURA

```
madrid/
├── index.html              ← App principal
├── admin.html              ← Panel administrativo
├── SCHEMA.sql              ← Estructura BD (SQL)
├── MIGRACION.js            ← Script migración v1→v2
├── js/
│   ├── supabase.js         ← Cliente Supabase + CRUD
│   └── utils.js            ← Funciones helper
├── assets/                 ← Imágenes, documentos
└── README.md               ← Este archivo
```

---

## 🛠️ CONFIGURACIÓN

### 1. Base de datos Supabase

```sql
-- Copiar TODO el contenido de SCHEMA.sql
-- Pegar en Supabase → SQL Editor
-- Ejecutar
```

### 2. Credenciales en código

Editar `js/supabase.js` (líneas 1-2):
```javascript
const SUPABASE_URL = 'https://dhbaeemqfctfzsuvddhi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOi...'; // Tu key aquí
```

### 3. Contraseña

Editar `js/utils.js` (línea 162):
```javascript
const PASS_CORRECTA = 'E47almacen2024'; // Cambiar
```

---

## 💾 MIGRACIÓN DE DATOS (v1 → v2)

### Exportar de v1

1. Abre la app v1 en el navegador
2. Abre consola: `F12 → Console`
3. Copia-pega TODO el archivo `MIGRACION.js` en la consola
4. Ejecuta: `exportarParaMigracion()`
5. Se copiará automáticamente

### Importar en v2

1. Abre `admin.html` en v2
2. Ve a "Importar datos"
3. Pega el JSON
4. Click "Importar"

---

## 📚 GUÍA DE USO

### ALMACÉN (index.html)

#### Productos
- Ver todos los productos con variantes
- Ver stock disponible por variante
- Filtro por nombre

#### Cajas
- Lista de todas las cajas
- Código, variante, cantidad, palé
- Editar/eliminar cajas

#### Palés
- Gestionar ubicaciones físicas
- Asociar cajas a palés
- Editar/eliminar

#### Salidas
- Registrar salidas/préstamos
- Múltiples artículos por salida
- Estados: pendiente → confirmada → entregada

#### Buscar
- Busca por código
- Busca por nombre
- Resultados en tiempo real

---

### ADMIN (admin.html)

#### Dashboard
- Resumen de estadísticas
- Total productos, cajas, palés, salidas
- Estado de conexión

#### Productos
- CRUD completo
- Crear/editar variantes
- Subir fotos

#### Importar
- Migración desde v1
- Pegar JSON exportado
- Log de errores

#### Exportar
- Descargar CSV de cualquier tabla
- Backup completo
- Para sincronizar con Google Sheets

#### Configuración
- Cambiar contraseña
- Opciones del sistema
- Reset de BD (⚠️ irreversible)

---

## 🔒 SEGURIDAD

- ✅ Contraseña en cada sesión
- ✅ localStorage no persistente
- ✅ Datos en Supabase (encriptados en tránsito)
- ⚠️ Cambiar contraseña por defecto
- ⚠️ No compartir credenciales de Supabase

---

## 🐛 TROUBLESHOOTING

### "Error de conexión a Supabase"
1. Verifica credenciales en `js/supabase.js`
2. Verifica que Supabase proyecto está activo
3. Comprueba conexión a internet

### "Contraseña incorrecta"
- Cambiar en `js/utils.js` línea 162
- Afecta a todos los usuarios

### "No se ven los productos"
1. Asegurate de haber ejecutado `SCHEMA.sql` en Supabase
2. Verifica que hay productos en BD
3. Recarga la página (Ctrl+F5)

### "Error importando datos"
1. Verifica que el JSON es válido
2. Comprueba que no hay IDs duplicadas
3. Revisa la consola para detalles

---

## 📊 API / FUNCIONES

### Obtener datos
```javascript
const productos = await obtenerProductos();
const variantes = await obtenerVariantes(productoId);
const cajas = await obtenerCajas(varianteId);
const pales = await obtenerPales();
const salidas = await obtenerSalidas(estado);
```

### Crear datos
```javascript
const prod = await crearProducto(nombre, descripcion, categoriaId, fotoUrl);
const var = await crearVariante(productoId, tipo, valor);
const caja = await crearCaja(varianteId, codigo, cantidad, paleId, esSuelto);
const pale = await crearPale(codigo, ubicacion, descripcion);
const salida = await crearSalida(tipo, destinatario, fechaSalida, fechaDev, notas);
```

### Actualizar datos
```javascript
await actualizarProducto(id, { nombre, descripcion });
await actualizarVariante(id, { stock_total });
await actualizarCaja(id, { cantidad, pale_id });
await actualizarSalida(id, { estado });
```

### Eliminar datos
```javascript
await eliminarProducto(id);
await eliminarVariante(id);
await eliminarCaja(id);
await eliminarSalida(id);
```

---

## 🔄 FLUJOS PRINCIPALES

### Registrar entrada de stock

1. **Almacén** → Productos → Ver producto
2. Click "Organizar stock"
3. Seleccionar variante
4. Ingresar cantidad
5. Seleccionar destino (caja/palé)
6. Guardar

### Registrar salida (préstamo)

1. **Almacén** → Salidas → Nueva salida
2. Completar: Tipo, destinatario, fechas
3. Añadir artículos
4. Guardar
5. **Admin** → Salidas → Confirmar/rechazar
6. Al confirmar: Se crean reservas automáticas

### Devolución

1. **Almacén** → Salidas → Ver salida
2. Click "Marcar como devuelta"
3. Se devuelve automáticamente al stock

---

## 📱 RESPONSIVE

- ✅ Desktop (1024px+)
- ✅ Tablet (768px - 1023px)
- ✅ Mobile (< 768px)

El sidebar se convierte en hamburguesa en móvil.

---

## 🔗 INTEGRACIÓN CON E47

La app está integrada en `equipo47.com/madrid`:

- Mismos estilos que Barcelona
- Mismo header + navegación
- Credenciales centralizadas

---

## 📝 CAMBIOS DESDE v1

| Feature | v1 (localStorage) | v2 (Supabase) |
|---------|-------------------|---------------|
| Datos | Local | Cloud ☁️ |
| Sincronización | Manual CSV | Real-time |
| Múltiples usuarios | ❌ | ✅ |
| Backups | Manual | Automático |
| Historial | ❌ | ✅ |
| Reportes | ❌ | ✅ (pronto) |
| Validación stock | Parcial | Estricta ✅ |

---

## 🚀 PRÓXIMAS FEATURES

- [ ] QR Scanner mejorado
- [ ] Webhooks → Google Sheets (sincronización automática)
- [ ] Reportes personalizados
- [ ] Alertas de stock bajo
- [ ] Historial completo
- [ ] Multi-almacén
- [ ] API pública

---

## 📞 SOPORTE

- **Documentación:** Este archivo
- **Problemas:** Revisar console (F12)
- **Contacto:** equipo47@gmail.com

---

## 📄 LICENCIA

© 2024 Equipo 47. Todos los derechos reservados.

---

**Última actualización:** Junio 2026
**Versión:** 2.0.0
**Estado:** ✅ En desarrollo activo
