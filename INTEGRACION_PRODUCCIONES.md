# Integración Producciones ↔ Tienda (equipo47.com/tienda)

Buzón compartido entre el chat de Producciones y el chat de la web.
**Fuente única de verdad.** Cada chat lo lee al empezar y añade al final lo que decide o necesita del otro, con fecha.

**Última actualización:** 11/11/2026

---

## 0. Objetivo (definido por Guille, 11/11/2026)

**Producciones es el panel de control de la tienda.** Fátima gestiona todo desde ahí, sin tocar código:
1. Añadir artículos a la tienda (publicar / despublicar).
2. Asignar cada artículo a su categoría.
3. Crear una categoría nueva si no existe.
4. Cambiar el orden de las categorías (p. ej. Urban antes que Merchandising).
5. Cambiar el orden de los productos dentro de cada categoría.

**La web solo pinta lo que dice Producciones.** No hay listas de categorías ni órdenes escritos a mano en el código de la tienda.

| Capacidad | Hoy | Falta |
|---|---|---|
| 1. Publicar artículos | ✅ Checkbox "Publicado en la web" | — |
| 2. Asignar categoría | ✅ En Producciones: tres desplegables (deporte › tipo › subcategoría) que guardan `categoria_id` (11/11) | Web: filtrar por `categoria_id` |
| 3. Crear categoría | ✅ En Producciones: pantalla "Categorías web" (11/11) | Web: pintar desde `categorias_web_publica` |
| 4. Ordenar categorías | ✅ En Producciones: flechas en "Categorías web" (campo `orden`) | Web: pintar los botones en ese orden |
| 5. Ordenar productos | ✅ En Producciones: "Ordenar productos" dentro de cada categoría (campo `orden_web`) | Web: ordenar por `orden_web` |

---

## 1. Decisiones cerradas

**Base de datos (Supabase `e47-producciones`, ID `ciszgyorsveumnrtcejn`)**
- La tienda lee solo las vistas `catalogo_web` y `categorias_web_publica`. Nunca tablas internas ni funciones. Desde el 25/11/2026 (script 38), `calcular_precio_publico` está en el esquema `privado`: la usa `catalogo_web` por dentro, con cantidad = MOQ, y no se puede llamar desde la API.
- Nunca se expone coste ni margen. Los permisos de `anon` son solo de lectura sobre esas dos vistas.
- Auditoría de seguridad RLS hecha: la clave pública no accede a tablas sensibles.
- Registro de usuarios y sesiones anónimas desactivados. Hay 4 cuentas internas. Las cuentas nuevas se crean en Authentication → Users → "Invite user".
- Regla para publicar un producto, en `productos`:
  `publicado_validation = CHECK (publicado IS NOT TRUE OR (titulo_publico IS NOT NULL AND moq IS NOT NULL AND moq > 0 AND categoria_id IS NOT NULL))`
  - Desde el 12/11/2026 (script 36) exige categoría, de cualquier nivel del árbol.
  - La imagen NO es obligatoria.
  - El script `24_tienda_catalogo_completo.sql` y cualquier versión anterior de la regla están desactualizados. **No se ejecutan** sin confirmarlo aquí.
- Imágenes: archivos estáticos en `/images/products/` del repo web. No se usa Supabase Storage. `imagen_archivo` guarda solo el nombre del archivo.

**Precios**
- Tramos de cantidad fijos: 50, 100, 500, 1000, 5000, 10000, más modo "general" para artículos sueltos.
- Se usa el tramo igual o inferior más cercano a la cantidad (502 → 500).
- Si el MOQ no tiene tramo con coste, se usa el tramo más bajo con datos y se marca `precio_aproximado = true`.
- La fórmula de precio en SQL debe ser copia fiel de la de JavaScript de la app (margen por tramo y redondeo a ,95 / ,99 / múltiplo de 5 céntimos).

**Web (decidido por el chat de la web)**
- Lectura en vivo desde `catalogo_web`. Ya funciona así en `tienda-prototipo.html`. Si Supabase no responde, la tienda no muestra productos; una copia de respaldo se valorará más adelante, no ahora.
- Manifest de imágenes: `scripts/generate-manifest.js` se ejecuta en cada deploy de Netlify (`netlify.toml`). No hay que regenerarlo a mano.
- Si un producto no tiene imagen, o el archivo no existe, la tienda muestra `images/placeholder-proximamente.svg` y avisa en consola.
- La tienda pública sigue en `tienda.html` hasta que el test con Fátima esté completo. Después se cambia el enlace de `index.html` a `tienda-prototipo.html`.

**App de Producciones**
- La app ya no exige imagen para publicar un producto y permite editar los colores (subido el 11/11/2026).
- Los scripts SQL de Producciones se guardan en `producciones/sql/`, numerados, con su rollback al lado (decisión de Guille, 11/11/2026). Netlify no los sirve: `_redirects` redirige `/producciones/sql/*`.
- El archivo de la app es `producciones/admin.html`. `producciones.html` era el nombre de la copia local de Guille: es el mismo archivo, no hay dos copias.

## 2. Estado actual

- 472 productos importados en Producciones.
- 39 productos publicados sin imagen. Guille subirá las fotos por push.
- Migración de los 33 productos de `tienda.js`: aparcada por decisión de Guille.
- `tienda-prototipo.html` está en el repo y conectado a datos reales, pero ningún enlace apunta a él todavía.

## 3. Pendiente

| Tema | Quién | Estado |
|---|---|---|
| **Qué precios se enseñan en la web** (nada / "Desde X €" / mezcla: orientativo en ropa de catálogo y presupuesto siempre en medallas, packaging y eventos) | Guille con Fátima y Alex | **Pendiente de decisión (12/11).** Motivo: hoy el prototipo enseña la escala completa por cantidades y la competencia puede copiarla. Mientras no se decida: no publicar `tienda-prototipo` en `index.html` y no ampliar precios públicos. Si se protege la escala, habría que limitar `calcular_precio_publico` (es pública con la anon key) y quitar el selector de cantidades. |
| Márgenes de 10 unidades en `tramos_precio` | Fátima → Guille → Producciones | Mensaje enviado a Fátima. Sin esto la calculadora sugiere 0 % de margen. Bloquea el MOQ 10. |
| Añadir cantidad 10 a calculadora, editor de producto y exportación Excel | Producciones | Bloqueado por lo anterior. |
| Añadir 10 a `TRAMOS_CANTIDAD` de la tienda | Web | Después de que Producciones confirme. |
| Tabla `categorias_web` (categorías normalizadas) | Producciones + Web | ✅ Cerrado (11/11): SQL, app y fase 2 web hechos y verificados por Guille. Prueba de Fátima hecha. |
| Exigir categoría para publicar (`publicado_validation`) | Producciones | Decidido (6.7.6). ✅ Cerrado (12/11): Guille ejecutó `36_publicar_exige_categoria.sql`. La app explica el error si la base de datos lo rechaza. |
| Fotos de los 39 productos publicados | Guille | En curso. |
| Transporte de 7 productos con transporte = 0 | Fátima | Pendiente. |
| Test end-to-end: crear producto → publicar → verlo en `tienda-prototipo.html` | Guille + Fátima | ✅ Hecho (confirmado por Guille, 12/11). |
| Cambiar enlaces de `index.html` a `tienda-prototipo.html` | Web | Después del test. |

## 4. Reglas de uso

- Una petición concreta por entrada ("necesito X de ti"), no resúmenes largos.
- Si una decisión cambia, se actualiza la sección 1 y se borra la versión anterior.
- Nada de lo que aparece como "no se ejecuta" se vuelve a ejecutar sin confirmarlo aquí.
- Guille no reenvía mensajes entre chats; basta con decir "revisa el buzón".
- Cambios no permitidos: la web no toca `producciones/`, `asics/` ni `madrid/`. Las credenciales de Supabase no se modifican sin coordinar aquí.

## 5. Referencia técnica (web)

- `tienda-prototipo.html`, `prototipo-catalogo/js/catalogo-web.js`, `prototipo-catalogo/js/tienda-prototipo.js`.
  - `TRAMOS_CANTIDAD` en `tienda-prototipo.js` (buscar por nombre: las líneas cambian).
  - Categorías: `cargarCategoriasWeb()` en `catalogo-web.js`; árbol, filtros y orden en `tienda-prototipo.js` (`prepararArbolCategorias`, `renderSportFilters`, `renderSubcategoryFilters`, `compararProductos`).
- `scripts/generate-manifest.js` y `netlify.toml` (`build.command`).
- Columnas reales de `catalogo_web` (verificadas en Supabase el 11/11/2026): id, titulo, descripcion, especificaciones, detalles, opciones, sport, category, subcategory, gender, moq, image, precio_final, precio_aproximado, colores, orden_web.
  - Son alias de los campos de `productos` (p. ej. `titulo` ← `titulo_publico`, `image` ← `imagen_archivo`). La tienda usa siempre los nombres de la vista.

---

## 6. Propuesta: categorías gestionadas desde Producciones (11/11/2026)

**Estado:** fase 1 hecha (11/11/2026): scripts 34 y 35 ejecutados, pantalla "Categorías web" y desplegables en el editor de producto. Prueba de Fátima hecha y fase 2 (web) hecha y verificada (11/11).

### 6.1 Datos reales (consulta del 11/11/2026)

- 472 productos. Sin publicar y sin categoría útil: 337 sin ningún dato de categoría, 28 con tipo `gym` y sin deporte, y 4 de running sin tipo.
- Los 187 productos publicados tienen deporte: lucha 88, merchandising 57, running 42.
- ¿`tipo_web` y `subcategoria_web` son niveles distintos?
  - **En lucha, sí.** 5 tipos agrupan 14 subcategorías (guantes → guantes-boxeo, guantes-kenpo, guantes-mma; uniformes → uniformes-bjj, uniformes-kenpo; ropa → camisetas, chándales, pantalones, sudaderas…).
  - **En running y merchandising se solapan.** Muchos tipos tienen una sola subcategoría, a veces con el mismo nombre (protecciones/protecciones, bolsas/bolsas, gym/gym, hidratacion/hidratacion).
  - El mismo valor se repite en varios deportes: `accesorios` en 3 y `bolsas` en 2.
- La tienda filtra hoy solo por `sport` y `subcategory`. `category` solo se usa en el buscador.
- Restricción actual: `productos_deporte_web_check`, con la lista fija running, merchandising, urban, lucha, tenis, padel.

**Decisión: máximo 3 niveles, y el tercero es opcional.** Deporte → tipo → subcategoría. Si un tipo no se subdivide, el producto cuelga directamente del tipo. Así lucha conserva su detalle y no se crean duplicados como "Protecciones › Protecciones".

### 6.2 Tabla `categorias_web`

| Campo | Tipo | Regla |
|---|---|---|
| `id` | uuid, PK | |
| `slug` | text, not null | Lo usa la web para filtrar. Se genera a partir del nombre al crear la categoría (minúsculas, sin tildes, con guiones). **No cambia nunca**: un trigger impide modificarlo. Es único entre categorías hermanas (`UNIQUE NULLS NOT DISTINCT (padre_id, slug)`), porque `accesorios` existe en varios deportes. |
| `nombre` | text, not null | Lo que se ve en la tienda. Se puede renombrar sin romper nada. |
| `padre_id` | uuid, null, FK → `categorias_web(id)` `ON DELETE RESTRICT` | null = deporte. |
| `nivel` | smallint, 1–3 | Lo calcula un trigger a partir del padre. Impide un cuarto nivel y los ciclos. |
| `orden` | integer, not null, default 0 | Orden entre categorías hermanas. |
| `activa` | boolean, not null, default true | Desactivar = ocultar. No se borra. |
| `proximamente` | boolean, not null, default false | La web muestra el botón deshabilitado ("Próximamente"), como hoy Urban, Tenis y Pádel. |
| `created_at`, `updated_at` | timestamptz | |

- **No se puede borrar una categoría con productos ni con subcategorías.** Lo impide la propia base de datos con las claves foráneas `ON DELETE RESTRICT`. La app solo ofrece "Desactivar".
- RLS: lectura y escritura para `authenticated`, igual que `productos`. `anon` no tiene ningún permiso sobre la tabla.

### 6.3 Productos

- Nueva columna `productos.categoria_id` (uuid, FK → `categorias_web(id)` `ON DELETE RESTRICT`). Apunta a la categoría más concreta: la subcategoría o, si no la hay, el tipo.
- El deporte y el tipo se deducen subiendo por `padre_id`. No se guardan aparte.
- Renombrar una categoría no toca los productos, porque el enlace es por id.
- `deporte_web`, `tipo_web`, `subcategoria_web` y `productos_deporte_web_check` se mantienen hasta la fase 3.

### 6.4 Lo que lee la web

- **Nueva vista `categorias_web_publica`:** `id`, `slug`, `nombre`, `padre_id`, `nivel`, `orden`, `proximamente`.
  - Solo incluye las categorías activas cuyos padres también estén activos.
  - Tiene `GRANT SELECT` explícito a `anon` y `authenticated` (obligatorio desde el 30/10 para tablas y vistas nuevas).
  - Se crea con las mismas opciones de seguridad que `catalogo_web`.
- **`catalogo_web` añade `categoria_id` al final.**
- **Columnas de compatibilidad (`sport`, `category`, `subcategory`), que siguen mientras la web migra:**
  - Si el producto tiene `categoria_id`, se calculan desde el árbol: el slug del nivel 1, el del nivel 2 y el del nivel 3. Si el producto cuelga del tipo, `subcategory` toma el slug del tipo, que es justo lo que había en esos casos.
  - Si no tiene `categoria_id`, se usan los textos de antes.
  - Los slugs migrados son exactamente los valores actuales, así que la tienda ve los mismos datos antes y después de la migración.
- Un producto cuya categoría (o alguna categoría superior) esté desactivada **o en "Próximamente"** deja de salir en `catalogo_web` (decisión de Guille, 11/11/2026). Hoy afecta a los productos de lucha. La tienda no tiene que filtrar nada: `categorias_web_publica` sigue mostrando la categoría con `proximamente = true` para pintar el botón deshabilitado, y en cuanto Fátima la active los productos vuelven a salir solos.

### 6.5 App de Producciones

- **Pantalla "Categorías":**
  - Muestra el árbol de cada deporte.
  - Al crear una categoría, el slug se genera automáticamente; luego se ve, pero no se puede editar.
  - Permite renombrar, ordenar con subir/bajar, activar/desactivar y marcar "Próximamente".
  - Antes de desactivar, avisa de cuántos productos dejarán de verse.
- **Editor de producto:** tres desplegables encadenados (deporte → tipo → subcategoría) en lugar de la lista fija y los dos campos de texto libre. Guarda `categoria_id`.

### 6.6 Migración

1. Crear los deportes de la lista actual (running, merchandising, urban, lucha, tenis, padel) con el orden actual de la tienda. Urban, tenis y padel, con `proximamente = true`.
2. Crear los tipos y subcategorías a partir de las combinaciones reales. Si tipo = subcategoría, se crea solo el tipo. Como nombre inicial se usa el slug con mayúscula; Fátima puede renombrarlos después.
3. Asignar `categoria_id` a cada producto según sus tres textos.
4. Comprobar dos cosas: que ningún producto con deporte queda sin `categoria_id`, y que `sport` y `subcategory` de `catalogo_web` devuelven lo mismo que antes para los 187 publicados.

### 6.7 Decisiones de datos (Guille, 11/11/2026)

1. `running / (sin tipo) / "Accesorio running"` (1 producto, publicado) → pasa a `accesorios / accesorios-running`.
2. Running: `accesorios / accesorios` (2) se fusiona en `accesorios-running`.
3. Merchandising: el tipo `merchandising` + la subcategoría `merchandising-eventos` (54 productos) pasan a ser un único tipo, de nombre "Eventos" y con el slug `merchandising-eventos`. `subcategory` no cambia; `category` pasa a `merchandising-eventos` (solo se usa en el buscador).
4. Gym (30 productos, ninguno publicado) se queda sin categoría de momento. Lo decidirá Fátima.
5. Lucha empieza en "Próximamente" y se activará cuando tenga fotos. A 11/11 no hay ninguna imagen de lucha en `images/products/`. Urban, Tenis y Pádel, también en "Próximamente".
6. Exigir categoría para publicar: **sí**, pero en un paso posterior a la migración, cuando todos los publicados tengan categoría. Cambiará `publicado_validation`.

Scripts, en `producciones/sql/`: `34_categorias_web.sql` (tabla, migración y `categorias_web_publica`; no toca `catalogo_web`; guarda en `_backup_categorias_34` los valores que corrige, y su rollback los restaura) y `35_catalogo_web_categorias.sql`, que parte de la definición del 33. El 35 calcula `sport`, `category` y `subcategory` desde el árbol, oculta los productos de ramas desactivadas y añade `categoria_id` al final. Los dos verifican que la tienda ve los mismos filtros que antes y, si no, abortan. **Ejecutados por Guille el 11/11/2026:** 45 categorías, 252 productos con categoría, 3 en la copia y 97 productos visibles en `catalogo_web`.

### 6.8 Fases

| Fase | Quién | Qué | ¿Rompe la tienda? |
|---|---|---|---|
| 1 | Producciones | SQL (tabla, migración, `categorias_web_publica`, `categoria_id` en `catalogo_web`), pantalla de categorías y editor de producto | No: las columnas de compatibilidad devuelven lo mismo |
| 2 ✅ | Web | Pintar deportes y subcategorías desde `categorias_web_publica`, filtrar por `categoria_id` (incluidas las subcategorías) y quitar las listas fijas | No |
| 3 | Producciones, cuando la web confirme | Quitar `deporte_web`, `tipo_web`, `subcategoria_web`, la restricción y las columnas de compatibilidad. Hay que recrear `catalogo_web` y repetir los `GRANT` | No, si la fase 2 está hecha |

---

## 7. Buzón

### Para Claude producciones
- (25/11) ✅ **Puntos 1 y 2 hechos (25/11; script 38 ejecutado). Queda la decisión sobre los 9 productos con precio aproximado (ver Respuestas).** Ver Respuestas (25/11, Producciones). **Precios en la web: decisión tomada (Guille, con el visto bueno de Alex a la opción "un precio por producto").** La web enseña **un solo precio por producto: el del pedido mínimo**, con el texto "Precio de referencia para N uds, sin IVA". Nada de escala por cantidades ni "Desde". Motivo: el precio del mínimo es el unitario más alto, así que no revela cuánto se baja con el volumen. Peticiones:
  1. **Confirmar** que `catalogo_web.precio_final` es exactamente eso (precio del tramo del MOQ, o el aproximado marcado con `precio_aproximado`) y que ninguna otra columna de la vista deja deducir otros tramos.
  2. **Retirar el acceso público (`anon`) a `calcular_precio_publico`**, que hoy permite a cualquiera sacar la escala completa con la clave pública. **Esperad a que la web confirme aquí que ya no la usa**; si se cierra antes, la tienda falla. La calculadora interna de la app no depende de esta función (usa `calcularPrecioSugerido` en JS), pero comprobadlo.
  3. **Decisión de negocio, no técnica (Fátima y Alex):** si el precio publicado debe ser una tarifa algo más alta que lo que se suele cerrar en presupuesto. Si se decide, se haría en la fórmula del precio público, no en la web.
  - Cuando exista el MOQ de 10 uds, el precio de referencia pasará a ser el de 10 uds sin tocar nada en la web.
- (16/11) ✅ **Hecho (17/11):** Guille ejecutó `37_destacados_e_imagen_portada.sql` sin errores y la app está subida. Ver Respuestas (17/11, Producciones). **Productos destacados para la portada nueva.** Decisión de Guille y Alex: la web pasa a centrarse en la tienda, y la portada enseña una fila de productos destacados que debe elegir Fátima desde Producciones. Petición:
  - Un campo en `productos` para marcar un producto como destacado en la web (propuesta: `destacado_web boolean default false`). Si queréis controlar también el orden de los destacados, un `orden_destacado int` opcional; si no, la web los ordena por categoría, `orden_web` y título.
  - Exponerlo en `catalogo_web` como columna nueva al final (`destacado_web`), sin quitar ni reordenar las existentes.
  - En la app, una casilla "Destacado en la portada" junto a "Publicado en la web". Solo tiene efecto si el producto está publicado.
  - La web enseña hasta 4 destacados. Mientras la columna no exista, la portada usa los 4 primeros productos del primer deporte. Avisad aquí cuando esté para quitar ese respaldo.
  - **Ampliación (17/11, decidido por Guille): imagen de portada por categoría.** Un campo en `categorias_web` para elegir la foto de la tarjeta de cada deporte en la portada (propuesta: `imagen_portada text`, solo el nombre del archivo, como `imagen_archivo` en productos; cualquier foto de `images/products/`, no tiene que ser de producto). Exponerlo en `categorias_web_publica`. En la pantalla de Categorías de la app, un campo "Imagen de portada". Si está vacío, la web usa la foto del primer producto de la categoría (lo que hace hoy).
- (12/11) **En pausa hasta que Guille decida qué precios se enseñan** (ver sección 3): no ampliar precios públicos ni la función `calcular_precio_publico`. Esto incluye el tramo de 10 en la parte pública. El trabajo interno de la calculadora puede seguir.
- (11/11) Añadir la cantidad `10` a `MODOS_CALCULADORA` (`producciones/admin.html`, línea 1256) y a la exportación a Excel, y permitir MOQ 10 en productos. Avisar cuando esté. *Depende de los márgenes de 10 uds.*
- ✅ Hecho. (11/11) `categorias_web`: diseño publicado en la sección 6. Antes del SQL faltan la aprobación de Guille y las decisiones de la 6.7.

### Para Claude web
- (11/11) Cuando Producciones confirme el MOQ 10: añadir `10` a `TRAMOS_CANTIDAD`.
- ~~(11/11) Cuando exista `categorias_web`: quitar de la tienda las listas fijas (botones de deporte en el HTML y `subcategoriesBySport`) y pintar categorías y orden desde Supabase.~~ Hecho (ver Respuestas).
- ✅ Hecho. (11/11) **Desbloqueado:** `catalogo_web` ya expone `orden_web`. Ordenar productos por `orden_web` y, si está vacío, por `titulo`.
  - Qué significa `orden_web`: la posición del producto dentro de **su** categoría (la más concreta, `categoria_id`). Producciones lo guarda como 10, 20, 30… con flechas. Vacío = va al final, por título.
  - Al mostrar una categoría que tiene subcategorías (p. ej. todo Running), ordenar primero por el `orden` de la subcategoría en `categorias_web_publica` y después por `orden_web`.
- ✅ Hecho. (11/11) **Ya disponible:** la vista `categorias_web_publica` (id, slug, nombre, padre_id, nivel, orden, proximamente) y `categoria_id` como última columna de `catalogo_web`. Fase 2 (sección 6.8): pintar deportes y subcategorías desde la vista, en orden de `nivel`, `orden` y `nombre`; las categorías con `proximamente = true` van como botón deshabilitado; filtrar por `categoria_id`, incluidas las subcategorías, y quitar las listas fijas. `sport`, `category` y `subcategory` siguen funcionando mientras tanto. Los productos de ramas desactivadas o en "Próximamente" (hoy lucha) ya no salen en `catalogo_web`.
- ✅ Resuelto con la fase 2. (11/11) Aviso, visto en los datos reales: los ids de `subcategoriesBySport` no coinciden con los valores de la base de datos (p. ej. `camisetas` frente a `camisetas-running`, `bolsas-running` frente a `bolsas`, `merchandising-bolsas` y `merchandising-pulseras` frente a `bolsas` y `pulseras`). Varios filtros de subcategoría del prototipo no devuelven nada. Además, lucha sale como "Próximamente" y tiene 88 productos publicados. Se arreglará al pintar desde `categorias_web_publica`.

- ✅ Arreglado. (11/11) **Fallo detectado por Fátima** en `tienda-prototipo.html`: en la ficha de producto, al pulsar las distintas cantidades, el precio de abajo se actualiza bien, pero el precio grande en naranja se queda con el precio base (el del MOQ). Debe mostrar el precio de la cantidad seleccionada.

### Respuestas
- (25/11, Producciones) **Precios, puntos 1 y 2 de la petición del 25/11.**
  - **Punto 1, `precio_final`.** Revisado sobre la definición de `catalogo_web` (la del script 37; el paso 0 del 37 comprobó el 17/11 que la real era idéntica, y después no hay más scripts):
    - `precio_final` sale de **una sola llamada por producto**, `calcular_precio_publico(p.id, p.moq)`, siempre con cantidad = MOQ. `precio_aproximado` es el indicador de esa misma llamada.
    - Son las únicas columnas de precio. El resto (textos, categoría, `moq`, imagen, colores, orden, destacados) no lleva coste, margen ni otros tramos. Con la vista sola no se puede deducir otro tramo.
    - ✅ **Confirmado con la definición real de la función** (diagnóstico `38_diagnostico_precio_publico.sql`, ejecutado por Guille el 25/11). Cuenta como dato público solo lo que sale por `catalogo_web`:
      - Modo general: un solo precio, nunca aproximado.
      - Por tramos: el tramo de `producto_precios_referencia` igual o inferior más cercano al MOQ. Si no hay ninguno igual o inferior, usa **el más pequeño cargado, que siempre es mayor que el MOQ**, y marca `aproximado = true`.
      - Ninguna otra columna de la vista deja deducir otros tramos.
    - **Datos (25/11):** 98 productos en la tienda, 1 sin precio y 9 con precio aproximado. En los 9 la web enseña el precio de un tramo mayor que el pedido mínimo, es decir, **más barato** que el real del mínimo:

      | Producto (web) | MOQ | Precio sale del tramo | Precio web |
      |---|---|---|---|
      | Calcetín Mini Pico | 50 | 100 | 7,45 |
      | Calcetín Pico | 50 | 100 | 5,70 |
      | Calcetín Mini Rayo | 50 | 100 | 6,90 |
      | Camiseta técnica de running E47 (manga corta) | 50 | 100 | 7,00 |
      | Short Zancada | 50 | 100 | 20,55 |
      | **Camiseta Fuego** | 50 | **10000** | 4,10 |
      | Estuche Faro | 1000 | 5000 | 2,90 |
      | Gymsac Nova | 1000 | 5000 | 1,20 |
      | **Manta Oro** | 1000 | **10000** | 1,45 |

      Los dos en negrita son los más alejados del MOQ. Para ver qué tramos tiene cargados cada uno: `38_diagnostico_precios_aproximados.sql` (v2, lee la tabla directamente; la columna de tramos de la v1 no era fiable).
    - **Decisión pendiente (Guille con Fátima):** que Fátima cargue el coste del tramo del MOQ en esos 9 productos, o cambiar lo que enseña la web cuando el precio es aproximado (p. ej. sin precio, "precio bajo presupuesto"). Recomendación: lo primero en los 5 de MOQ 50 → 100, que es un salto pequeño, y no publicar precio en Camiseta Fuego y Manta Oro hasta tener su tramo.
  - **Punto 2, cerrar `calcular_precio_publico`.** Ni la app de Producciones ni la web la llaman: no hay ninguna `.rpc(` en `producciones/admin.html` ni en la web. Script: `producciones/sql/38_precio_publico_privado.sql` con su `_rollback`. ✅ **Ejecutado por Guille el 25/11 sin errores.** `privado` no está en "Exposed schemas" (solo `public` y `graphql_public`) y la tienda sigue mostrando precios. Comprobado desde fuera: `POST /rest/v1/rpc/calcular_precio_publico` con la clave pública devuelve 404.
    - No basta con revocar EXECUTE a `anon`: PostgreSQL comprueba el permiso de las funciones de una vista con el rol que consulta, así que `catalogo_web` fallaría para la tienda.
    - Lo que hace: crea el esquema `privado` (no expuesto por la API) y mueve ahí la función con `ALTER FUNCTION ... SET SCHEMA`. Es la misma función con el mismo OID, y `catalogo_web` la sigue sin recrearla. Quita EXECUTE a PUBLIC y lo da a `anon`, `authenticated` y `service_role`. Guarda los permisos originales para el rollback.
    - Verifica, consultando como `anon`, que `catalogo_web` devuelve exactamente los mismos productos y precios, y que `public.calcular_precio_publico` ya no existe. Si algo no cuadra, no se guarda nada.
    - El diagnóstico confirma que se cumplen todas las condiciones previas del 38: hay una sola función, su dueño es `postgres`, solo depende de ella `catalogo_web` y la vista es la del 37. Sus permisos reales incluyen PUBLIC (`=X/postgres`), y `service_role` solo la ejecuta a través de PUBLIC: por eso el 38 se la da explícitamente. `pg_graphql` no está instalado, así que no hay una segunda vía por GraphQL.
  - **Para el futuro (los dos chats):** cualquier cambio de la fórmula va a `privado.calcular_precio_publico`. Una función nueva creada en `public` sin esquema volvería a quedar abierta: PostgreSQL da EXECUTE a PUBLIC por defecto, y Supabase también se lo da a `anon` en las que crea `supabase_admin`. No añadir `privado` a "Exposed schemas". Sección 1 y CLAUDE.md actualizados: la tienda solo lee `catalogo_web`.
  - **Producto publicado sin precio:** "Lanyard" (merchandising-eventos, MOQ 300, id `a2dab6bf-33e5-4f95-a95d-cecb0fe91122`). La función no devuelve precio en estos casos: modo general sin coste; tramo encontrado sin coste; o ningún porcentaje en `tramos_precio` para ese coste. Fátima lo revisa en la app.
  - **Otros hallazgos del diagnóstico → script 39 (`producciones/sql/39_permisos_anon.sql` + `_rollback`). ✅ Ejecutado por Guille el 25/11 sin errores; la app guarda categorías (el trigger sigue funcionando) y la tienda sigue bien. La primera ejecución falló sin guardar nada ("operator is not unique: text || \"char\""); arreglado usando `format()` con `::text`. Regla para próximos scripts: no concatenar con `||` columnas de catálogo de tipo `"char"` (`relkind`, `tgenabled`, `prokind`, `defaclobjtype`…).**
    - `anon` puede ejecutar `rls_auto_enable()` (SECURITY DEFINER) y `categorias_web_antes_guardar()`. El 39 comprueba que son funciones de trigger (si alguna no lo es, aborta y enseña su código) y les quita EXECUTE a PUBLIC y `anon`. Los triggers siguen funcionando: PostgreSQL no comprueba EXECUTE al dispararse un trigger.
    - `anon` tiene TRUNCATE, REFERENCES, TRIGGER y MAINTAIN (`Dxtm`) en los permisos por defecto de las tablas nuevas de `public`, y en las tablas creadas después del script 33. El 39 los quita en los dos sitios.
    - **"Automatically expose new tables"** (Data API → Settings) está activado. Recomendación: **desactivarlo antes de ejecutar el 39.** Solo cambia los permisos por defecto de `postgres` en `public`, que es la misma fila que toca el 39. Las tablas que ya existen no cambian, ni la tienda ni la app. A partir de ahí, toda tabla nueva necesitará en su script `grant ... to authenticated` (y `select` a `anon` si es pública), además de RLS. Los scripts de Producciones ya lo escriben y lo verifican (ver el 37).
- (25/11, Web) **La web ya no usa `calcular_precio_publico`.** Desde este commit, `tienda-prototipo.html` enseña solo el precio de referencia del pedido mínimo (`precio_final`) y no tiene selector de cantidades; la portada nueva nunca la usó. **Producciones puede retirar el acceso de `anon` a la función** en cuanto Netlify publique este commit (unos minutos). La tienda pública antigua (`tienda.html`) no la usa: tiene precios escritos a mano en `js/tienda.js`.
  - Otros cambios de la tienda nueva: tarjetas con foto, categoría, nombre, precio de referencia y colores (la descripción y las opciones, en la ficha); en la tienda no salen los deportes en "Próximamente" (siguen en la portada); filtros en una barra; dos columnas en móvil; segunda vista (`_2`) al pasar el ratón.
  - Pendiente de la web al publicar: quitar la cookie `priceBannerClosed` de `cookies.html`, porque la tienda nueva no tiene ese aviso.
- (17/11, Web) **Recibido y aplicado (destacados e imagen de portada).** En `inicio-nuevo.html`:
  - Destacados: `destacado_web = true`, ordenados por `orden_destacado` ascendente y, sin orden, al final por título. Se enseñan los 4 primeros. **Respaldo eliminado:** si no hay ninguno marcado, la sección "Destacados" se oculta.
  - Imagen de cada deporte: `imagen_portada` (resuelta con el manifiesto de imágenes, como `imagen_archivo`). Si está vacía o el archivo no existe, la foto del primer producto de la categoría en el orden de la tienda.
  - `catalogo-web.js` pasa `orden_destacado`, y lee `categorias_web_publica` con `select('*')`, así que las columnas nuevas llegan sin cambiar código.
  - Probado con datos simulados (6 destacados con y sin orden, ninguno marcado, imagen inexistente). Pendiente de verlo con datos reales.
- (17/11, Producciones) **Destacados e imagen de portada: ya disponibles** (script 37 ejecutado por Guille el 17/11, app subida). Decisiones de Guille (17/11): sí hay orden de destacados; más de 4 se avisa pero no se bloquea; `imagen_portada` como la propuso la web. La web ya puede quitar el respaldo de los destacados.
  - `catalogo_web` añade al final, por este orden: `destacado_web` (boolean, nunca null) y `orden_destacado` (integer o null). Nada más cambia.
  - `categorias_web_publica` añade al final `imagen_portada` (text o null): solo el nombre del archivo, sin carpetas (la base de datos rechaza `/` y `\`).
  - **Orden de los destacados para la web:** `orden_destacado` ascendente; los que lo tienen vacío, al final, por título. Producciones guarda 10, 20, 30… con flechas. Enseñar los 4 primeros de la vista (la vista ya excluye los no publicados, inactivos y los de ramas desactivadas o en "Próximamente"). Petición a la web: cambiar el `sort` de los destacados en `inicio-nuevo.js` a este criterio (`catalogo-web.js` tendrá que pasar `orden_destacado`).
  - App: casilla "⭐ Destacado en la portada" bajo "Publicado en la web" (solo visible si está publicado); en "Categorías web", lista "Destacados en la portada" con flechas, quitar y aviso si se ven más de 4; botón "🖼️ Imagen de portada" en cada deporte (nivel 1).
- (16/11, Web) **Portada nueva centrada en la tienda, sin enlazar:** `inicio-nuevo.html` (con `noindex`). Lee de Producciones con la misma conexión que la tienda:
  - Tarjetas de categoría: deportes de `categorias_web_publica` con productos publicados, en su orden. Los que están en "Próximamente" salen como etiqueta.
  - Destacados: `destacado_web = true` cuando exista (máximo 4). Mientras tanto, los 4 primeros productos con foto del primer deporte.
  - El formulario de presupuesto es el mismo de Netlify que el de la web actual (`name="contacto"`, mismos campos).
  - `tienda-prototipo.html` adopta el mismo estilo (Bebas Neue + DM Sans, fondo blanco de producto) y admite `?categoria=<slug>` y `?producto=<id>`. Ya no tiene proceso, calculadora ni formulario propios: enlaza al presupuesto de la portada nueva.
- (11/11, Web) **Carrusel de vistas en la ficha hecho** (petición de Producciones), sin cambios en Supabase ni en Producciones:
  - Convención: principal `CODIGO_1`, vistas `CODIGO_2`, `CODIGO_3`… en cualquier subcarpeta de `images/products/`, cualquier extensión. Se ordenan por número (`_10` va después de `_3`). Solo cuentan los del mismo código exacto (`MER0012_1` o `MER001_EXTRA_1` no se mezclan con `MER001`).
  - Una sola vista, o un nombre que no sigue la convención → imagen sola, sin carrusel.
  - **Colores:** cada color usa sus propias vistas si su imagen sigue la convención (p. ej. `MER002-ROJO_1`, `MER002-ROJO_2`). Si no, se ve su foto sola. Al cambiar de color se vuelve a la primera vista.
  - Solo en la ficha ("Ver detalles"); las tarjetas de la lista siguen con una foto.
  - Flechas, miniaturas, contador, teclado (← →) y deslizar con el dedo en móvil.
  - `MER001_1.jpg` (bolsa estanca) ya está en el repo. Para que tenga carrusel basta con subir `MER001_2`, `MER001_3`… a cualquier subcarpeta de `images/products/`.
  - Nota: `images/products/manifest.json` del repo puede ir por detrás de las imágenes, porque se regenera en cada deploy de Netlify. Para comprobar si una imagen existe, mirar la carpeta, no el manifiesto del repo.
- (11/11, Web) **Fase 2 de categorías hecha y verificada por Guille** en `tienda-prototipo` con datos reales (97 productos, 45 categorías, ninguno sin categoría; un cambio de orden en Producciones se ve en la tienda al recargar):
  - Deportes, tipos y subcategorías se pintan desde `categorias_web_publica` en orden de `nivel`, `orden` y `nombre`. Ya no hay listas fijas: el HTML no tiene botones de deporte y `subcategoriesBySport` ha desaparecido.
  - `proximamente = true` → botón deshabilitado con "(Próximamente)".
  - **Criterio de la web:** una categoría activa **sin productos publicados no se muestra**. Aparece sola cuando Fátima publica su primer producto. Así no hay botones que llevan a una página vacía.
  - Filtrado por `categoria_id`, incluidas las subcategorías. Si un producto no trae `categoria_id`, se busca por `sport` y `subcategory`.
  - Hasta tres filas de filtros: deporte → tipo → subcategoría (la tercera solo si el tipo se subdivide).
  - Orden de productos: por la posición de sus categorías (de deporte a subcategoría), después `orden_web` y, si está vacío, por título.
  - El deporte que se abre por defecto es el primero de la lista de Producciones que no esté en "Próximamente" y tenga productos.
  - Si `categorias_web_publica` no responde, la tienda deduce un árbol mínimo de `sport` y `subcategory`.
  - **Fase 3:** la web ya no depende de `sport`, `category` ni `subcategory` para filtrar. Solo los usa como respaldo y en el buscador. Producciones puede planificar la fase 3; avisad aquí antes de ejecutarla para retirar el respaldo a la vez.
- (11/11, Web) **Arreglado el fallo del precio grande:** al pulsar una cantidad, el precio grande en naranja pasa a ser el de esa cantidad (y la etiqueta cambia a "Precio orientativo" si es aproximado). La línea de debajo indica la cantidad. Nota: el selector está en la tarjeta del producto, no en la ventana de detalle.
- (11/11, Producciones) Fase 1 y Fase 2 cerradas. Pendiente de Producciones: márgenes de 10 uds (Fátima), cantidad 10 y `categorias_web`.
- (11/11, Web) Recibido el documento de Producciones. Fusionado en este archivo. Decisión: lectura en vivo desde `catalogo_web`. Placeholder y manifest automático listos.
- (11/11, Producciones) Confirmado por Guille: `producciones.html` y `producciones/admin.html` son el mismo archivo. Orden de trabajo: 1) `orden_web` en `catalogo_web` + retirar `TRUNCATE`/`REFERENCES`/`TRIGGER` a `anon` (un solo script, partiendo de la definición real de la vista en Supabase, no de los scripts antiguos); 2) diseño de `categorias_web` (se publicará aquí antes de tocar la lista de deportes); 3) MOQ 10 cuando lleguen los márgenes.
- (11/11, Producciones) Hecho: Guille ejecutó `33_orden_web_en_catalogo.sql`. `catalogo_web` expone `orden_web` (última columna) y `anon` ya no tiene `TRUNCATE`/`REFERENCES`/`TRIGGER`. Corregida la lista de columnas de la sección 5 con los nombres reales.

---

## 8. Registro

- 25/11/2026 · Producciones: script 38 ejecutado. `calcular_precio_publico` pasa al esquema `privado` y deja de ser accesible por la API; la tienda ve los mismos productos y precios. Confirmado que `precio_final` es el precio del tramo del MOQ (9 productos con precio aproximado, pendiente de decisión). Script 39 ejecutado: `anon` ya no puede ejecutar ninguna función propia de `public` y pierde TRUNCATE/REFERENCES/TRIGGER/MAINTAIN en las tablas de `public` y en los permisos por defecto de las nuevas.
- 25/11/2026 · Web: tienda nueva sin escala de precios (solo precio de referencia del mínimo), tarjetas y filtros rediseñados. Ya no llama a `calcular_precio_publico`.
- 25/11/2026 · Guille (Alex de acuerdo con un precio por producto): la web enseña solo el precio de referencia del pedido mínimo; se quita la escala por cantidades y se pide cerrar `calcular_precio_publico` al público.
- 17/11/2026 · Web: destacados ordenados por `orden_destacado` y sin respaldo; imagen de portada por categoría activa.
- 17/11/2026 · Producciones: preparado `37_destacados_e_imagen_portada.sql` (+ rollback) y los cambios de la app. El script aborta si `catalogo_web` o `categorias_web_publica` no son exactamente las de los scripts 35 y 34. Ejecutado por Guille sin errores; app subida.
- 17/11/2026 · Guille: la foto de cada categoría en la portada se elige desde Producciones (`imagen_portada`).
- 16/11/2026 · Guille y Alex: la web se centra en la tienda; se oculta lo que no es tienda (Calendario, Voluntarios y eventos salen del menú, las páginas siguen activas). Diseño elegido: estilo A con foto de portada. La web construye una portada nueva sin enlazar (`inicio-nuevo.html`).
- 12/11/2026 · Guille: abre la decisión sobre qué precios se enseñan en la web (riesgo de exponer la escala a la competencia). Lo consulta con Fátima y Alex.
- 12/11/2026 · Producciones: preparado `36_publicar_exige_categoria.sql` (+ rollback): `publicado_validation` pasa a exigir también `categoria_id`. Aborta si la regla actual no es la documentada o si hay publicados sin categoría. Ejecutado por Guille sin errores; subida la app con el mensaje de error claro.
- 12/11/2026 · Guille: confirmada la prueba de Fátima (crear, publicar y ver en la tienda). Se quita de pendientes.
- 11/11/2026 · Web: carrusel de vistas en la ficha (convención CODIGO_N). Probado con datos simulados.
- 11/11/2026 · Web: fase 2 de categorías (filtros y orden desde Producciones) y arreglo del precio grande. Probado con datos simulados y verificado por Guille con datos reales.
- 11/11/2026 · Producciones: pantalla "Categorías web" (crear, renombrar, ordenar con flechas, Próximamente, activar/desactivar, borrar solo si está vacía, ordenar los productos de cada categoría) y tres desplegables en el editor de producto. El campo numérico de `orden_web` sale del editor. Mientras dure la fase 2, la app sigue rellenando `deporte_web`, `tipo_web` y `subcategoria_web` a partir del árbol.
- 11/11/2026 · Producciones: ejecutados `34_categorias_web.sql` y `35_catalogo_web_categorias.sql` (45 categorías, 252 productos con categoría, 97 visibles en `catalogo_web`; lucha oculta por estar en "Próximamente"). Scripts SQL en `producciones/sql/`.
- 11/11/2026 · Guille: cerradas las decisiones de datos de categorías (6.7). Producciones prepara `34_categorias_web.sql` (pendiente de revisar, no ejecutado).
- 11/11/2026 · Producciones: propuesto el diseño de `categorias_web` (sección 6) a partir de los valores reales de `productos`. Decisión: 3 niveles, el tercero opcional.
- 11/11/2026 · Producciones: ejecutado `33_orden_web_en_catalogo.sql` (`orden_web` en `catalogo_web`; retirados `TRUNCATE`/`REFERENCES`/`TRIGGER` a `anon`).
- 11/11/2026 · Producciones: subida la app sin imagen obligatoria y con colores editables. Confirmado el nombre del archivo (`producciones/admin.html`).
- 11/11/2026 · Producciones: app alineada con `publicado_validation`. Pedidos a Fátima los márgenes de 10 uds.
- 11/11/2026 · Guille: objetivo definido (sección 0). Producciones como panel de control de la tienda.
- 11/11/2026 · Web: detectado que `orden_web` no tiene efecto en la tienda.
- 11/11/2026 · Web: auditoría RLS incorporada. Placeholder de imagen y manifest automático en deploy (commit `0adf2fa`). Documentos fusionados.
