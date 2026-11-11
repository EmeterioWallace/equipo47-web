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
| 2. Asignar categoría | ⚠️ Deporte: lista fija en código. Subcategoría: texto libre | Elegir de `categorias_web` |
| 3. Crear categoría | ❌ Requiere cambiar código en los dos proyectos | Pantalla de categorías en Producciones + tabla `categorias_web` |
| 4. Ordenar categorías | ❌ Orden fijo en el HTML de la tienda | Campo `orden` en `categorias_web`; la web pinta los botones desde ahí |
| 5. Ordenar productos | ⚠️ `catalogo_web` ya expone `orden_web` (11/11), pero la tienda todavía no ordena por él | La web ordena por `orden_web` |

---

## 1. Decisiones cerradas

**Base de datos (Supabase `e47-producciones`, ID `ciszgyorsveumnrtcejn`)**
- La tienda lee solo la vista `catalogo_web` y la función `calcular_precio_publico(uuid, int)`. Nunca tablas internas.
- Nunca se expone coste ni margen. Los permisos de `anon` son solo sobre la vista y la función.
- Auditoría de seguridad RLS hecha: la clave pública no accede a tablas sensibles.
- Registro de usuarios y sesiones anónimas desactivados. Hay 4 cuentas internas. Las cuentas nuevas se crean en Authentication → Users → "Invite user".
- Regla para publicar un producto, en `productos`:
  `publicado_validation = CHECK (publicado IS NOT TRUE OR (titulo_publico IS NOT NULL AND moq IS NOT NULL AND moq > 0))`
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
- El archivo de la app es `producciones/admin.html`. `producciones.html` era el nombre de la copia local de Guille: es el mismo archivo, no hay dos copias.

## 2. Estado actual

- 472 productos importados en Producciones.
- 39 productos publicados sin imagen. Guille subirá las fotos por push.
- Migración de los 33 productos de `tienda.js`: aparcada por decisión de Guille.
- `tienda-prototipo.html` está en el repo y conectado a datos reales, pero ningún enlace apunta a él todavía.

## 3. Pendiente

| Tema | Quién | Estado |
|---|---|---|
| Márgenes de 10 unidades en `tramos_precio` | Fátima → Guille → Producciones | Mensaje enviado a Fátima. Sin esto la calculadora sugiere 0 % de margen. Bloquea el MOQ 10. |
| Añadir cantidad 10 a calculadora, editor de producto y exportación Excel | Producciones | Bloqueado por lo anterior. |
| Añadir 10 a `TRAMOS_CANTIDAD` de la tienda | Web | Después de que Producciones confirme. |
| Tabla `categorias_web` (categorías normalizadas) | Producciones + Web | Diseño propuesto (sección 6). Falta la aprobación de Guille y las decisiones de la 6.7. |
| Fotos de los 39 productos publicados | Guille | En curso. |
| Transporte de 7 productos con transporte = 0 | Fátima | Pendiente. |
| Test end-to-end: crear producto → publicar → verlo en `tienda-prototipo.html` | Guille + Fátima | Pendiente. |
| Cambiar enlaces de `index.html` a `tienda-prototipo.html` | Web | Después del test. |

## 4. Reglas de uso

- Una petición concreta por entrada ("necesito X de ti"), no resúmenes largos.
- Si una decisión cambia, se actualiza la sección 1 y se borra la versión anterior.
- Nada de lo que aparece como "no se ejecuta" se vuelve a ejecutar sin confirmarlo aquí.
- Guille no reenvía mensajes entre chats; basta con decir "revisa el buzón".
- Cambios no permitidos: la web no toca `producciones/`, `asics/` ni `madrid/`. Las credenciales de Supabase no se modifican sin coordinar aquí.

## 5. Referencia técnica (web)

- `tienda-prototipo.html`, `prototipo-catalogo/js/catalogo-web.js`, `prototipo-catalogo/js/tienda-prototipo.js`.
  - `TRAMOS_CANTIDAD` en la línea 167.
  - `subcategoriesBySport` en la línea 82.
  - Botones de deporte en `tienda-prototipo.html`, líneas 118-123.
- `scripts/generate-manifest.js` y `netlify.toml` (`build.command`).
- Columnas reales de `catalogo_web` (verificadas en Supabase el 11/11/2026): id, titulo, descripcion, especificaciones, detalles, opciones, sport, category, subcategory, gender, moq, image, precio_final, precio_aproximado, colores, orden_web.
  - Son alias de los campos de `productos` (p. ej. `titulo` ← `titulo_publico`, `image` ← `imagen_archivo`). La tienda usa siempre los nombres de la vista.

---

## 6. Propuesta: categorías gestionadas desde Producciones (11/11/2026)

**Estado:** propuesta de Producciones. Pendiente de que Guille la apruebe y la web la revise. Todavía no hay SQL.

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
- Un producto cuya categoría (o alguna categoría superior) esté desactivada deja de salir en `catalogo_web`.

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

### 6.7 Decisiones pendientes antes de escribir el SQL (Guille / Fátima)

1. `running / (sin tipo) / "Accesorio running"` (1 producto, publicado): ¿pasa a `accesorios / accesorios-running`?
2. Running tiene `accesorios / accesorios` (2) y `accesorios / accesorios-running` (8): ¿se fusionan en una sola subcategoría?
3. Merchandising tiene el tipo `merchandising` con la subcategoría `merchandising-eventos` (54 productos, 39 publicados). Propuesta: un único tipo "Eventos" (slug `merchandising-eventos`) dentro de merchandising. `subcategory` no cambia; `category` cambia, pero solo se usa en el buscador.
4. Gym: 28 productos sin deporte y 2 en merchandising, ninguno publicado. ¿Es un deporte nuevo, va dentro de merchandising o se queda sin categoría por ahora?
5. Lucha tiene 88 productos publicados, pero `tienda-prototipo.html` la muestra como "Próximamente". ¿Empieza activa o con `proximamente = true`? Urban no tiene productos: se propone dejarla en "Próximamente".
6. Para la fase 3: ¿exigir categoría para publicar? Cambiaría `publicado_validation`, que es una regla cerrada.

### 6.8 Fases

| Fase | Quién | Qué | ¿Rompe la tienda? |
|---|---|---|---|
| 1 | Producciones | SQL (tabla, migración, `categorias_web_publica`, `categoria_id` en `catalogo_web`), pantalla de categorías y editor de producto | No: las columnas de compatibilidad devuelven lo mismo |
| 2 | Web | Pintar deportes y subcategorías desde `categorias_web_publica`, filtrar por `categoria_id` (incluidas las subcategorías) y quitar las listas fijas | No |
| 3 | Producciones, cuando la web confirme | Quitar `deporte_web`, `tipo_web`, `subcategoria_web`, la restricción y las columnas de compatibilidad. Hay que recrear `catalogo_web` y repetir los `GRANT` | No, si la fase 2 está hecha |

---

## 7. Buzón

### Para Claude producciones
- (11/11) Añadir la cantidad `10` a `MODOS_CALCULADORA` (`producciones/admin.html`, línea 1256) y a la exportación a Excel, y permitir MOQ 10 en productos. Avisar cuando esté. *Depende de los márgenes de 10 uds.*
- (11/11) `categorias_web`: diseño publicado en la sección 6. Antes del SQL faltan la aprobación de Guille y las decisiones de la 6.7.

### Para Claude web
- (11/11) Cuando Producciones confirme el MOQ 10: añadir `10` a `TRAMOS_CANTIDAD`.
- (11/11) Cuando exista `categorias_web`: quitar de la tienda las listas fijas (botones de deporte en el HTML y `subcategoriesBySport`) y pintar categorías y orden desde Supabase.
- (11/11) **Desbloqueado:** `catalogo_web` ya expone `orden_web`. Ordenar productos por `orden_web` y, si está vacío, por `titulo`.
- (11/11) Revisar el diseño de categorías (sección 6), sobre todo la 6.4: lo que vas a leer y las columnas de compatibilidad. Si te falta algo, pídelo aquí antes de que se escriba el SQL.
- (11/11) Aviso, visto en los datos reales: los ids de `subcategoriesBySport` no coinciden con los valores de la base de datos (p. ej. `camisetas` frente a `camisetas-running`, `bolsas-running` frente a `bolsas`, `merchandising-bolsas` y `merchandising-pulseras` frente a `bolsas` y `pulseras`). Varios filtros de subcategoría del prototipo no devuelven nada. Además, lucha sale como "Próximamente" y tiene 88 productos publicados. Se arreglará al pintar desde `categorias_web_publica`.

### Respuestas
- (11/11, Producciones) Fase 1 y Fase 2 cerradas. Pendiente de Producciones: márgenes de 10 uds (Fátima), cantidad 10 y `categorias_web`.
- (11/11, Web) Recibido el documento de Producciones. Fusionado en este archivo. Decisión: lectura en vivo desde `catalogo_web`. Placeholder y manifest automático listos.
- (11/11, Producciones) Confirmado por Guille: `producciones.html` y `producciones/admin.html` son el mismo archivo. Orden de trabajo: 1) `orden_web` en `catalogo_web` + retirar `TRUNCATE`/`REFERENCES`/`TRIGGER` a `anon` (un solo script, partiendo de la definición real de la vista en Supabase, no de los scripts antiguos); 2) diseño de `categorias_web` (se publicará aquí antes de tocar la lista de deportes); 3) MOQ 10 cuando lleguen los márgenes.
- (11/11, Producciones) Hecho: Guille ejecutó `33_orden_web_en_catalogo.sql`. `catalogo_web` expone `orden_web` (última columna) y `anon` ya no tiene `TRUNCATE`/`REFERENCES`/`TRIGGER`. Corregida la lista de columnas de la sección 5 con los nombres reales.

---

## 8. Registro

- 11/11/2026 · Producciones: propuesto el diseño de `categorias_web` (sección 6) a partir de los valores reales de `productos`. Decisión: 3 niveles, el tercero opcional.
- 11/11/2026 · Producciones: ejecutado `33_orden_web_en_catalogo.sql` (`orden_web` en `catalogo_web`; retirados `TRUNCATE`/`REFERENCES`/`TRIGGER` a `anon`).
- 11/11/2026 · Producciones: subida la app sin imagen obligatoria y con colores editables. Confirmado el nombre del archivo (`producciones/admin.html`).
- 11/11/2026 · Producciones: app alineada con `publicado_validation`. Pedidos a Fátima los márgenes de 10 uds.
- 11/11/2026 · Guille: objetivo definido (sección 0). Producciones como panel de control de la tienda.
- 11/11/2026 · Web: detectado que `orden_web` no tiene efecto en la tienda.
- 11/11/2026 · Web: auditoría RLS incorporada. Placeholder de imagen y manifest automático en deploy (commit `0adf2fa`). Documentos fusionados.
