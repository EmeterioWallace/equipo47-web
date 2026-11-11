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
| 5. Ordenar productos | ⚠️ El campo `orden_web` existe en Producciones, pero **no tiene efecto**: `catalogo_web` no lo expone y la tienda no ordena | Exponer `orden_web` en la vista; la web ordena por él |

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
| Tabla `categorias_web` (categorías normalizadas) | Producciones + Web | Pendiente de diseño. Lista inicial: running, merchandising, urban, lucha, tenis, padel. |
| Fotos de los 39 productos publicados | Guille | En curso. |
| Transporte de 7 productos con transporte = 0 | Fátima | Pendiente. |
| Test end-to-end: crear producto → publicar → verlo en `tienda-prototipo.html` | Guille + Fátima | Pendiente. |
| Cambiar enlaces de `index.html` a `tienda-prototipo.html` | Web | Después del test. |
| Quitar `TRUNCATE`, `REFERENCES`, `TRIGGER` al rol `anon` | Producciones | No urgente. |

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
- Campos que expone `catalogo_web`: id, titulo_publico, descripcion_publica, especificaciones_publicas, detalles_publicos, opciones_personalizacion, deporte_web, tipo_web, subcategoria_web, genero, moq, imagen_archivo, precio_final, precio_aproximado, colores (array de {nombre, imagen}).

---

## 6. Buzón

### Para Claude producciones
- (11/11) Añadir la cantidad `10` a `MODOS_CALCULADORA` (`producciones/admin.html`, línea 1256) y a la exportación a Excel, y permitir MOQ 10 en productos. Avisar cuando esté. *Depende de los márgenes de 10 uds.*
- (11/11) Diseñar la tabla `categorias_web` y migrar las categorías actuales. Avisar antes de cambiar la lista de deportes. **Ver sección 0:** debe permitir crear categorías y ordenarlas desde la app. Propuesta de campos (ajústala si hace falta): `id`, `slug`, `nombre`, `padre_id` (null = deporte; con valor = subcategoría), `orden`, `activa`. La vista pública debe exponer solo las categorías activas.
- (11/11) Añadir `orden_web` a la vista `catalogo_web`. Hoy la tienda no puede respetar el orden que pone Fátima porque la vista no lo devuelve.

### Para Claude web
- (11/11) Cuando Producciones confirme el MOQ 10: añadir `10` a `TRAMOS_CANTIDAD`.
- (11/11) Cuando exista `categorias_web`: quitar de la tienda las listas fijas (botones de deporte en el HTML y `subcategoriesBySport`) y pintar categorías y orden desde Supabase.
- (11/11) Cuando `catalogo_web` exponga `orden_web`: ordenar productos por `orden_web` y, si está vacío, por título.

### Respuestas
- (11/11, Producciones) Fase 1 y Fase 2 cerradas. Pendiente de Producciones: márgenes de 10 uds (Fátima), cantidad 10 y `categorias_web`.
- (11/11, Web) Recibido el documento de Producciones. Fusionado en este archivo. Decisión: lectura en vivo desde `catalogo_web`. Placeholder y manifest automático listos.
- (11/11, Producciones) Confirmado por Guille: `producciones.html` y `producciones/admin.html` son el mismo archivo. Orden de trabajo: 1) `orden_web` en `catalogo_web` + retirar `TRUNCATE`/`REFERENCES`/`TRIGGER` a `anon` (un solo script, partiendo de la definición real de la vista en Supabase, no de los scripts antiguos); 2) diseño de `categorias_web` (se publicará aquí antes de tocar la lista de deportes); 3) MOQ 10 cuando lleguen los márgenes.

---

## 7. Registro

- 11/11/2026 · Producciones: subida la app sin imagen obligatoria y con colores editables. Confirmado el nombre del archivo (`producciones/admin.html`).
- 11/11/2026 · Producciones: app alineada con `publicado_validation`. Pedidos a Fátima los márgenes de 10 uds.
- 11/11/2026 · Guille: objetivo definido (sección 0). Producciones como panel de control de la tienda.
- 11/11/2026 · Web: detectado que `orden_web` no tiene efecto en la tienda.
- 11/11/2026 · Web: auditoría RLS incorporada. Placeholder de imagen y manifest automático en deploy (commit `0adf2fa`). Documentos fusionados.
