# Integración Producciones ↔ Equipo47-Web

**Última actualización:** 2026-11-10 13:12 (UTC+1)

---

## 📊 ESTADO ACTUAL

| Componente | Estado | Notas |
|-----------|--------|-------|
| RLS Producciones | ✅ Auditado 11/11/2026 | Seguro. Registro abierto detectado y cerrado el mismo día |
| CHECK Constraints | ✅ Hecho 11/11 (`publicado_validation`) | Validación de servidor. La imagen ya no es obligatoria para publicar |
| Placeholder "imagen próximamente" | ⏳ Pendiente | Lo muestra la web cuando `image` viene null (equipo47-web) |
| Script Validación Imágenes | ⏳ Pendiente | Avisar si el archivo no existe en `images/products/` |
| Manifest.json | ⏳ Pendiente | Regeneración automática. Hay que decidir dónde corre (ver Fase 3) |
| Test con Fátima | ⏳ Pendiente | Crear producto y publicarlo |
| Cambio a Producción | ⏹️ Bloqueado | Espera todas las validaciones |

---

## 🔍 PROBLEMAS IDENTIFICADOS

### 1. ⚠️ IMÁGENES SIN VALIDACIÓN (Crítico)

**Problema:**
- Fátima escribe el nombre del archivo a mano en un `<input type="text">`
- NO hay validación de que el archivo existe
- Si el nombre no está en `manifest.json`, la imagen sale **rota** en la web

**Impacto:** Productos con imágenes rotas en la tienda

**Solución:** Script que verifique existencia antes de guardar

---

### 2. ⚠️ PRODUCTOS INCOMPLETOS PUEDEN PUBLICARSE (Crítico)

**Problema:**
- El checkbox "Publicado en la web" solo valida en el navegador (JavaScript)
- Las validaciones de servidor **no existen**
- Un producto se puede publicar sin descripción, sin especificaciones, sin nada

**Impacto:** Productos incompletos en tienda

**Solución:** CHECK constraints en Supabase (`productos` table)

---

### 3. ✅ RLS DE PRODUCCIONES AUDITADA (resuelto 11/11/2026)

**Resultado:** seguro. Detalle en la sección "RLS AUDIT RESULTS" más abajo.

- La anon key visible en el repo público no tiene ningún permiso sobre las tablas sensibles.
- Incidencia real encontrada y corregida el 11/11: el registro de usuarios estaba abierto. Desactivado; hay 4 cuentas, todas internas, sin acceso no autorizado.

---

## 🏗️ ARQUITECTURA ACTUAL

```
Fátima (producciones/admin.html)
  ↓ (login Supabase Auth)
  ↓ 
Tabla: productos (coste_proveedor, margen, etc.)
  ↓
Vista: catalogo_web (filtra publicado=true, expone solo campos públicos)
  ↓
tienda-prototipo.html (consume via SDK)
  ↓
equipo47.com/tienda-prototipo.html (cuando pasemos a prod)
```

### Flujo de Imágenes
```
Fátima entra: "camiseta-running.jpg" en productoImagenArchivo
  ↓
Se guarda en tabla productos.imagen_archivo
  ↓
tienda-prototipo.js busca en productImages.js → images/products/manifest.json
  ↓
<img src="images/products/running/camiseta-running.jpg">
```

---

## 📋 PRÓXIMAS ACCIONES

### Fase 1: Seguridad (BLOQUEADOR)
- [x] **Claude Producciones:** Auditar RLS de tablas — hecho 11/11/2026
- [ ] **Claude Producciones (no urgente):** Quitar `TRUNCATE`, `REFERENCES` y `TRIGGER` al rol `anon`
- [ ] **Claude Producciones (futuro):** Afinar permisos por persona si entran cuentas externas

### Fase 2: Validaciones en Servidor — ✅ HECHA (11/11, Claude producciones)
- [x] CHECK `publicado_validation` en `productos`, versión corregida. Un producto publicado necesita título y MOQ. **La imagen no es obligatoria** (opción 3 acordada).
  ```sql
  ALTER TABLE productos ADD CONSTRAINT publicado_validation
    CHECK (
      NOT publicado OR (
        titulo_publico IS NOT NULL
        AND moq > 0
        AND imagen_archivo IS NOT NULL
      )
    );
  ```

### Fase 3: Imágenes (equipo47-web)
Los archivos de esta fase están en el repo de equipo47-web, así que los hace este Claude, no producciones.
- [x] **Placeholder "imagen próximamente":** `resolverRutaImagen` devuelve `images/placeholder-proximamente.svg` cuando no hay imagen. Código hecho; pendiente comprobarlo en el deploy.
- [x] **Aviso de imagen inexistente:** si el nombre no está en el manifest, avisa en consola y muestra el placeholder en vez de una imagen rota.
- [x] **Regeneración de `manifest.json`:** `scripts/generate-manifest.js` se ejecuta en cada deploy de Netlify (`netlify.toml` → `build.command`). Decisión tomada por este Claude: no hay commits automáticos ni build paralelo, y el manifest no puede desfasarse.

### Fase 4: Testing
- [ ] **Guille:** Coordinar test con Fátima
  - Crear producto de prueba en producciones
  - Marcar como "Publicado en la web"
  - Verificar que aparezca en tienda-prototipo.html
  - Verificar imágenes se vean bien

### Fase 5: Producción
- [ ] **Claude Equipo47-web:** Cambiar enlace index.html
  - `tienda.html` → `tienda-prototipo.html`
  - Commit + push

---

## 🔐 RLS AUDIT RESULTS

**Status:** ✅ SEGURO (auditoría de producciones, `ciszgyorsveumnrtcejn`, 11/11/2026)

- Registro de usuarios nuevos e inicios de sesión anónimos: **desactivados**. Solo existen 4 cuentas internas.
- RLS activado en las 10 tablas: productos, clientes, cobros, pagos, presupuestos, presupuesto_lineas, lineas_negocio, producto_variantes, producto_colores_web, producto_precios_referencia.
- Política en todas: acceso total solo para `authenticated`.
- Rol `anon` (la clave pública del repo): sin SELECT/INSERT/UPDATE/DELETE en esas tablas.
- Vista `catalogo_web`: solo campos públicos; sin coste_proveedor, transporte ni margen. Filtra `publicado = true AND activo = true`.
- `calcular_precio_publico`: SECURITY DEFINER con `search_path` fijado; solo devuelve precio final de productos publicados y activos.
- Incidencia corregida: registro abierto (cualquiera podía crear una cuenta con acceso total). Revisadas las cuentas: sin acceso no autorizado.
- Nota operativa: las cuentas nuevas ya no se crean por registro. Se crean en Supabase → Authentication → Users → "Invite user" / "Add user".

---

## 📌 PENDIENTES AMPLIADOS (11/11/2026)

### A. Pedido mínimo (MOQ) de 50 → 10 unidades
- **Precios:** los introduce Fátima desde la interfaz de producciones. No requiere decisión de Guille.
- **Producciones:** las cantidades de la calculadora son una lista fija `MODOS_CALCULADORA = ['50', '100', '500', '1000', '5000', '10000']` en `producciones/admin.html` línea 1256. Hay que añadir `'10'` (y revisar la hoja de exportación a Excel, que usa las mismas cantidades).
- **Web:** `TRAMOS_CANTIDAD = [50, 100, 500, 1000, 5000, 10000]` en `prototipo-catalogo/js/tienda-prototipo.js` línea 167. Con MOQ 10 el selector seguiría empezando en 50, lo que contradice el pedido mínimo.
- **Acciones:** Claude producciones → añadir la cantidad 10 a la calculadora y a la exportación, y permitir MOQ 10 en el producto. Claude equipo47-web → añadir 10 a `TRAMOS_CANTIDAD`, después de que producciones confirme.

### B. Orden y creación de categorías
- **Deportes** (Running, Merchandising, Urban…) son una lista fija en tres sitios: `<select>` de `producciones/admin.html` (~línea 869), botones de `tienda-prototipo.html` (líneas 118-123, el orden de los botones es el orden del HTML) y la lógica de filtros. Crear un deporte nuevo hoy exige cambiar código en los dos proyectos.
- **Subcategorías:** texto libre en admin (con sugerencias). La web solo muestra botones de filtro para las subcategorías definidas en `subcategoriesBySport` (`tienda-prototipo.js` línea 82). Una subcategoría nueva aparece en "Todas" pero sin botón propio.
- **Orden de productos:** campo `orden_web`; si está vacío, por nombre. No existe orden de categorías en la base de datos.
- **Decidido (11/11):** tabla `categorias_web` en Supabase (deporte o subcategoría, nombre visible, orden, activa) que lean tanto la admin como la web. Crear o reordenar categorías no requerirá tocar código.
- **Pendiente:** diseño de la tabla y migración de las categorías actuales. Lo define el Claude de producciones (es su base de datos) y después lo adapta la web.

---

## 📮 BUZÓN ENTRE CLAUDES

**Cómo se usa:** cada Claude lee este documento al empezar. Lo que necesita del otro se escribe aquí, con fecha. Guille no reenvía mensajes; basta con decir "revisa el buzón".

### Para Claude producciones
- (11/11) Añadir la cantidad `10` a `MODOS_CALCULADORA` (`admin.html` ~línea 1256) y a la exportación a Excel, y permitir MOQ 10 en productos. Avisar cuando esté.
- (11/11) Diseñar la tabla `categorias_web` (deporte o subcategoría, nombre visible, orden, activa) y migrar las categorías actuales. Avisar antes de cambiar la lista de deportes.

### Para Claude equipo47-web
- (11/11) Cuando producciones confirme el MOQ 10: añadir `10` a `TRAMOS_CANTIDAD` (`tienda-prototipo.js` línea 167).
- (11/11) Cuando exista `categorias_web`: adaptar la tienda para leer categorías y orden de ahí.

### Respuestas
_(vacío)_

---

## 📝 NOTAS TÉCNICAS

### Variables Supabase (hardcodeadas)
- **Project:** `ciszgyorsveumnrtcejn`
- **Anon Key:** Visible en `producciones/admin.html` línea 1449
- **Ubicación:** Repo público en GitHub

### Campos que catalogo_web expone
- id, titulo_publico, descripcion_publica, especificaciones_publicas, detalles_publicos
- opciones_personalizacion, deporte_web, tipo_web, subcategoria_web, genero
- moq, imagen_archivo, precio_final, precio_aproximado
- colores (array de {nombre, imagen})

### Archivos clave
- `/producciones/admin.html` - App de Fátima (3688 líneas)
- `/prototipo-catalogo/js/catalogo-web.js` - Consumidor de catalogo_web
- `/js/productImages.js` - Mapeo de nombres a rutas de imágenes
- `/images/products/manifest.json` - Manifest de imágenes (necesita regeneración automática)

---

## 🚨 CAMBIOS NO PERMITIDOS

⛔ NO hacer cambios en `/producciones/` desde equipo47-web
⛔ NO hacer cambios en `/asics/` o `/madrid/`
⛔ NO modificar credenciales Supabase sin coordinación

---

## 📞 COMUNICACIÓN

**Este documento es la fuente única de verdad.**

Ambos Claudes deben:
1. Leer este documento antes de trabajar
2. Actualizar secciones relevantes cuando terminen tareas
3. Reportar bloqueadores o cambios de scope

**No hay "teléfono roto" si todos leen el mismo documento.**

---

**Creado por:** Claude (equipo47-web)  
**Última revisión:** 2026-11-11 (auditoría RLS incorporada)
