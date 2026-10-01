# Modelo de datos

> **Fuente principal: el esquema real de Supabase**, extraído en octubre de
> 2026 mediante consultas de solo lectura a `information_schema`/`pg_catalog`
> (ver `docs/sql/README.md`). Donde el esquema por sí solo no explica el
> comportamiento (reglas que solo existen en el código JavaScript), se indica
> explícitamente con **[regla de negocio, no está en el esquema]**.

29 tablas, 203 columnas, 29 claves primarias, 34 claves foráneas, 57 índices,
102 políticas RLS, 19 funciones. Sin vistas, sin enums, sin triggers.

**Patrón de identificadores:** la gran mayoría de tablas usa como `id` un
`bigint` con valor por defecto `(EXTRACT(epoch FROM now())::bigint * 1000)` —
milisegundos desde epoch, generado por la propia base de datos, coherente con
el patrón `Date.now()` que usa el frontend. Dos tablas rompen este patrón:
`solicitudes` y `solicitud_items` usan secuencias estándar de Postgres
(`nextval(...)`). No es un error, pero sí una inconsistencia a tener en
cuenta si alguna vez se migra o se combinan IDs de distintas tablas.

---

## Inventario

### `productos`
| Columna | Tipo | Notas |
|---|---|---|
| id | bigint PK | |
| nombre | text NOT NULL | |
| descripcion | text | |
| categoria_id | bigint | **Sin FK declarada** hacia `categorias` — la relación existe solo por convención en el código, no está forzada en la base de datos |
| subcategoria_id | bigint | **Sin FK declarada** hacia `subcategorias`, mismo caso |
| foto_url | text | |
| tiene_variantes | text, default `'si'` | |
| stock_minimo | integer, default 0 | |
| created_at, updated_at | timestamp | |

### `variantes`
PK `id`. FK `producto_id` → `productos.id`. Columnas: `tipo`, `valor` (los dos
ejes de variante), `stock_total` (fuente de verdad del stock real),
`stock_minimo` (umbral de aviso **a nivel de variante**, distinto del
`stock_minimo` de `productos` — ambos existen, revisar con Guille si es
intencional tener los dos niveles o es redundante).

### `categorias` / `subcategorias`
Simples: `id`, `nombre`. `subcategorias.categoria_id` → `categorias.id` (esta
sí tiene FK declarada).

### `ubicaciones`, `pales`, `cajas`
- `ubicaciones`: `id`, `codigo`, `nombre`, `descripcion`.
- `pales`: `id`, `codigo`, `descripcion`, FK `ubicacion_id` → `ubicaciones.id`.
- `cajas`: `id`, `codigo`, `descripcion`, FK `pale_id` → `pales.id`, FK `ubicacion_id` → `ubicaciones.id`.

Las cajas y los palés son **contenedores** (metadato de dónde están), no
almacenan cantidades. El contenido vive en `stock`.

### `stock` — el núcleo del modelo de inventario
PK `id`. FK `variante_id` → `variantes.id`, FK `caja_id` → `cajas.id`, FK
`pale_id` → `pales.id`, FK `ubicacion_id` → `ubicaciones.id`. Columna
`cantidad` (int4).

**[Regla de negocio, no está en el esquema]**: cada fila de `stock` es una
*colocación* — una cantidad de una variante en un sitio concreto (caja, palé
o ubicación directa). `variantes.stock_total` es el total real; "disponible
sin organizar" = `stock_total − suma(colocaciones de esa variante)`. Borrar
una colocación nunca resta del inventario real, solo la deja sin organizar.
No hay ninguna restricción en el esquema que impida que la suma de
colocaciones supere `stock_total` — esa coherencia la vigila el código, no la
base de datos.

---

## Operaciones

### `salidas` / `salida_lineas`
`salidas`: 12 columnas, incluye `tipo`, `destinatario`, `fecha_salida`,
`fecha_devolucion`, `fecha_devolucion_real`, `estado` (default `'pendiente'`,
**sin CHECK que limite sus valores posibles** — a diferencia de `fichajes`,
aquí la validez de los estados depende solo del código).
`salida_lineas`: FK a `salidas` y a `variantes`, columna `cantidad`.

### `recepciones` / `recepcion_lineas` / `recepcion_incidencias`
`recepciones` tiene 15 columnas, entre ellas una curiosidad ya conocida:
`cantidad_esperada` es **texto libre** a nivel de cabecera (de cuando no
existía desglose por producto), mientras que `recepcion_lineas` tiene su
propio `cantidad_esperada` **numérico**, por línea — los dos coexisten
intencionadamente, documentado ya en su momento al construirlo.

`recepcion_lineas` (añadida en 2026): `cantidad_esperada`, `cantidad_recibida`,
`sumar_inventario` (bool, default true), `sumado` (bool, default false — para
no sumar dos veces al inventario). FK a `recepciones` y a `variantes`.

`recepcion_incidencias`: `recepcion_id`, `texto`, para anotar problemas.

---

## Personas y actividad

### `personas_equipo`
`id`, `nombre`, `email`, `activo`, `rol` (text, default `'consulta'`),
`puede_corregir_fichajes` (bool, default false — permiso suelto,
independiente del rol jerárquico, gestionable desde la pantalla Equipo).

### `actividad` — el log en uso
`id`, `usuario`, `accion`, `entidad`, `descripcion`, `created_at`. Es la
tabla que de verdad escribe `registrarActividad()` en todo `admin.html`.

### `historial` — tabla sin ningún punto de acceso en el código actual
`id`, `tipo`, `tabla`, `tabla_id`, `descripcion`, `usuario`, `created_at`.

**Esta es la tabla "nueva" que no aparecía en el recuento por código del
informe anterior** (el informe decía 27 por un error de conteo mío en el
texto — la lista real que generé entonces ya tenía 28 tablas; la única que
faltaba de verdad era esta). Ni una sola llamada `.from('historial')` en
`admin.html`, `index.html` ni `portal.html`, ninguna función RPC la
menciona, y no tiene ninguna clave foránea de entrada ni de salida — vive
aislada del resto del esquema.

**[Propuesta de interpretación, no una certeza]**: su forma (`tipo` / `tabla`
/ `tabla_id` / `descripcion` / `usuario` / `created_at`) es casi idéntica al
propósito de `actividad` (`usuario` / `accion` / `entidad` / `descripcion`),
con el mismo patrón de ID por epoch. Todo apunta a que es una versión
anterior del mismo concepto de "log de actividad", sustituida por `actividad`
en algún momento del desarrollo, y nunca eliminada de Supabase. No he podido
confirmarlo con una fuente directa (no estuvo en nuestras sesiones) — queda
como hipótesis bien fundada, no como hecho verificado.

---

## Fichaje

### `fichajes`
`id`, `persona_id` (FK), `tipo` (CHECK: entrada/salida/pausa_inicio/pausa_fin),
`modalidad` (CHECK: presencial/remoto), `hora` (timestamptz, la pone el
servidor), `es_correccion`, `motivo`, `aprobado_por` (FK a
`personas_equipo`), `solicitud_id` (FK a `solicitudes_correccion`),
`fichaje_original_id` (FK **a sí misma** — para las correcciones de "dato
incorrecto", enlaza con el fichaje que tenía el dato mal, sin tocarlo nunca).

### `solicitudes_correccion`
14 columnas. CHECKs sobre `tipo`, `modalidad`, `estado`
(pendiente/aprobada/rechazada) y `solicitud_tipo`
(faltante/dato_incorrecto). FKs hacia `fichajes` (dos: `fichaje_id` y
`fichaje_original_id`) y hacia `personas_equipo` (dos: `persona_id` y
`resuelta_por`).

Estas dos tablas tienen la cobertura de CHECK constraints más completa de
todo el esquema — son, junto con `calendario_config`, las únicas tablas con
reglas de negocio reforzadas a nivel de base de datos además de en el
código.

---

## Calendario

- `eventos`: `nombre`, `fecha_inicio`, `fecha_fin`, `lugar`, `notas`,
  `completado`, `hora_inicio` (time), `etiqueta` y `color_etiqueta` (texto
  libre, la alternativa ligera a un sistema de categorías).
- `evento_personas`: convocatorias — FK a `eventos`, a `salidas` y a
  `personas_equipo`, más `nombre_externo` para colaboradores puntuales sin
  cuenta.
- `calendario_config`: fila única (CHECK `id = 1`), 5 columnas de color.

---

## Clientes y portal

- `clientes`: `nombre`, `email`, `notas`, `activo`.
- `cliente_visibilidad`: qué variantes puede ver/pedir cada cliente y con
  qué `tope` (cantidad máxima). FK a `clientes` y a `variantes`.
- `solicitudes`: la petición de material de un cliente — `cliente_id` (FK),
  `evento`, `fecha_recogida`, `fecha_devolucion`, `estado`, `notas_admin`.
- `solicitud_items`: líneas de la solicitud — FK a `solicitudes` y a
  `variantes`, `cantidad`.

**[Comprobado en el código de las funciones RPC, no inferido]**: el acceso
del cliente a su propio catálogo (`mi_catalogo()`) y la comprobación de
disponibilidad (`comprobar_disponibilidad()`) tienen en cuenta solapes de
fechas entre solicitudes activas (`pendiente`/`aceptada`) y el `tope` fijado
en `cliente_visibilidad` — es una lógica de reservas con control de
solapamiento, no un simple descuento de stock. Ver `docs/SEGURIDAD.md` para
el detalle de cada función.

---

## Plantillas de salida

- `plantillas` / `plantilla_lineas`: una plantilla reutilizable de artículos
  para montar salidas rápido.
- `plantillas_visibilidad` / `plantilla_visibilidad_lineas`: mismo concepto
  pero aplicado a qué puede ver un cliente externo (visibilidad, con `tope`),
  paralelo a `cliente_visibilidad`.

---

## Relaciones — resumen visual

```
productos ──< variantes ──< stock >── cajas ── pales ── ubicaciones
                  │                                        │
                  │                                     (también)
                  ├──< salida_lineas >── salidas
                  ├──< recepcion_lineas >── recepciones ──< recepcion_incidencias
                  ├──< cliente_visibilidad >── clientes ──< solicitudes ──< solicitud_items
                  └──< plantilla_lineas >── plantillas

personas_equipo ──< fichajes ──< solicitudes_correccion
personas_equipo ──< evento_personas >── eventos
personas_equipo ──< evento_personas >── salidas   (convocatorias)
```

(`categoria_id`/`subcategoria_id` en `productos` no se dibujan como FK reales
porque no lo son a nivel de base de datos — ver arriba.)
