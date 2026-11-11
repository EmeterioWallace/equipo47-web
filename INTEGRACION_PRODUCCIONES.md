# Integración Producciones ↔ Equipo47-Web

**Última actualización:** 2026-11-10 13:12 (UTC+1)

---

## 📊 ESTADO ACTUAL

| Componente | Estado | Notas |
|-----------|--------|-------|
| RLS Producciones | ✅ Auditado 11/11/2026 | Seguro. Registro abierto detectado y cerrado el mismo día |
| CHECK Constraints | ⏳ Pendiente | Validación de servidor en Supabase |
| Script Validación Imágenes | ⏳ Pendiente | Verificar que archivos existan |
| Manifest.json | ⏳ Pendiente | Regeneración automática |
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

### Fase 2: Validaciones en Servidor
- [ ] **Claude Producciones:** Añadir CHECK constraint en `productos` (todavía no confirmado en su respuesta)
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

### Fase 3: Validación de Imágenes
- [ ] **Claude Equipo47-web:** Crear script que:
  - Verifique que archivos en `productoImagenArchivo` existen en `images/products/`
  - Regenere `manifest.json` automáticamente
  - Se ejecute en CI/pre-deploy

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
