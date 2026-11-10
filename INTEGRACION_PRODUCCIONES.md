# Integración Producciones ↔ Equipo47-Web

**Última actualización:** 2026-11-10 13:12 (UTC+1)

---

## 📊 ESTADO ACTUAL

| Componente | Estado | Notas |
|-----------|--------|-------|
| RLS Producciones | ⏳ Pendiente | Nunca auditado, riesgo de seguridad |
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

### 3. 🔒 RLS DE PRODUCCIONES NUNCA AUDITADO (Seguridad)

**Problema:**
- Proyecto Supabase `ciszgyorsveumnrtcejn` tiene políticas RLS no verificadas
- `producciones/admin.html` lee/escribe directamente (no vía RPC)
- Anon key está visible en GitHub (repo público)
- Si las políticas están mal: acceso a clientes, cobros, pagos, presupuestos

**Impacto:** Exposición de datos sensibles

**Solución:** Auditoría RLS como se hizo en Madrid (Bloque 1B)

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
- [ ] **Claude Producciones:** Auditar RLS de tablas (productos, clientes, cobros, pagos, presupuestos)
  - Usar mismo método que Bloque 1B
  - Verificar que anon key no puede leer datos sensibles
  - Documento: Actualizar sección "RLS Audit" abajo

### Fase 2: Validaciones en Servidor
- [ ] **Claude Producciones:** Añadir CHECK constraint en `productos`
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

**Status:** ⏳ Pendiente

Cuando el Claude de Producciones haga la auditoría:
- [ ] Política de `productos`: ✓ Solo autenticados, no expone coste/margen
- [ ] Política de `clientes`: ✓ Segura
- [ ] Política de `cobros`: ✓ Segura
- [ ] Política de `pagos`: ✓ Segura
- [ ] Política de `presupuestos`: ✓ Segura
- [ ] Conclusión general: ✓ SEGURO o ⚠️ RIESGO

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
**Última revisión:** 2026-11-10 13:12
