# Deuda técnica y problemas conocidos

> Lista viva. Nada de lo aquí descrito se ha corregido en el Bloque 0 (salvo
> el punto marcado explícitamente como excepción) — es registro para decidir
> prioridades más adelante, no un backlog ya en marcha.

## 🔴 Bug activo confirmado: `exportarCSV` está roto

`admin.html` (línea ~3046) declara su propia `function exportarCSV(tabla)`,
con el mismo nombre que la de `js/utils.js` (`exportarCSV(datos, nombre)`).
Como `admin.html` se carga después, su versión sustituye por completo a la
de `utils.js` para toda la página. Dentro de su propio cuerpo, llama:

```js
exportarCSV(datos, tabla);
```

Esto no invoca la función de `utils.js` (ya no existe para la página) —
se llama a sí misma, con argumentos que no coinciden con su propia firma.
Resultado: recursión infinita en cuanto alguien pulse cualquiera de los 5
botones de "Exportar" (Productos, Variantes, Cajas, Palés, Salidas).

**No corregido en este bloque** (excluido explícitamente del Bloque 0).

## 🟡 Código legacy sin uso en `js/supabase.js`

Las funciones de escritura (`crearProducto`, `crearVariante`, `crearCaja`,
`crearPale`, `crearSalida`, `crearSalidaLinea`, `actualizarProducto`,
`actualizarVariante`, `actualizarCaja`, `actualizarSalida`,
`eliminarProducto`, `eliminarVariante`, `eliminarCaja`, `eliminarSalida`)
tienen **0 usos** en `admin.html`. Además, `crearCaja(varianteId, codigo,
cantidad, paleId, esSuelto)` asume un modelo de datos **distinto al real**:
la tabla `cajas` real no tiene columnas `variante_id`, `cantidad` ni
`es_suelto` — esas pertenecen conceptualmente a `stock`. Confirmado con el
esquema real: `cajas` solo tiene `id`, `codigo`, `pale_id`, `ubicacion_id`,
`descripcion`, `created_at`.

De las funciones de lectura (`obtener*`), `obtenerCategorias` se usa 1 vez y
`obtenerSalidaLineas` 0 veces; el resto sí están en uso.

## 🟡 Código legacy sin uso en `js/utils.js`

`filtrarArray`, `agruparPor`, `ordenar`, `formatDate`, `formatDateTime`,
`parseNumber`, `mostrarLoading`, `ocultarLoading`, `copiarAlPortapapeles`,
`debug`, `openModal`, `closeModal`, `validarEmail`, `validarFecha`,
`limpiarString`, `generarCodigoQR`, `formatNumber`, `calcularStockDisponible`
— 0 usos en `admin.html`. Solo `toast`, `confirmar`, `exportarCSV` (roto,
ver arriba) y `hace` están realmente en uso.

`calcularStockDisponible` tiene el mismo problema de modelo de datos
obsoleto que `crearCaja` (asume `cajas.cantidad`), pero como no se llama
nunca, no tiene efecto práctico.

## ✅ Resuelto en este bloque: `PASS_CORRECTA`

Contraseña real en texto plano, de un sistema de autenticación antiguo
(`requiereAutenticacion()`, `PASSWORD_ALMACEN`, localStorage) sin ningún
punto de llamada en los 5 archivos del proyecto. Se retiró el valor real en
el Bloque 0 (ver commit/cambio documentado en el informe de consolidación).
El resto del bloque legacy (la función en sí, `cerrarSesion()`) se deja para
un bloque de limpieza posterior, tal como se pidió explícitamente.

## 🟡 Tabla `historial` sin ningún punto de acceso en el código

Ver `docs/MODELO-DATOS.md` para el detalle. Resumen: existe en Supabase, con
una forma muy parecida a `actividad`, pero ninguna parte del código
(`admin.html`, `index.html`, `portal.html`, funciones RPC) la referencia.
Probable predecesora de `actividad`, nunca eliminada.

## 🟡 Relaciones sin clave foránea declarada

`productos.categoria_id` y `productos.subcategoria_id` no tienen FK real
hacia `categorias`/`subcategorias` en el esquema — la relación existe solo
por convención en el código JavaScript. Postgres no impide guardar un
`categoria_id` que no exista.

## 🟡 Estados sin CHECK constraint

`salidas.estado`, `recepciones.estado` y `solicitudes.estado` no tienen
ninguna restricción a nivel de base de datos sobre qué valores son válidos
(a diferencia de `fichajes` y `solicitudes_correccion`, que sí la tienen).
La validez de estos estados depende por completo de la disciplina del
código — un `update` mal escrito podría dejar un estado inesperado sin que
la base de datos lo impida.

## 🟡 Dos columnas `stock_minimo` (producto y variante)

`productos.stock_minimo` y `variantes.stock_minimo` existen ambas. Puede
ser intencionado (umbral por defecto a nivel de producto, con posibilidad de
ajustarlo por variante), pero no hay evidencia en el esquema de cuál manda
sobre cuál — merece confirmarse con Guille si ambas se usan de verdad o es
redundancia histórica.

## 🟡 Patrón de IDs inconsistente

La inmensa mayoría de tablas usa un `id` por defecto generado como
milisegundos desde epoch (`EXTRACT(epoch FROM now())::bigint * 1000`),
coherente con el `Date.now()` del frontend. `solicitudes` y
`solicitud_items` rompen el patrón y usan secuencias estándar de Postgres.
No es un bug, pero si algún día se combinan IDs de distintas tablas en el
mismo contexto, conviene saberlo.

## 🟡 Políticas RLS con rol `{public}` en vez de `{authenticated}`

Ver `docs/SEGURIDAD.md` para el análisis completo (incluye por qué, en la
práctica, no parece explotable). Afecta a 8 de las 102 políticas, todas
escritas en los bloques de fichaje, recepciones y calendario construidos
este año — es decir, deuda que yo mismo introduje, no algo heredado.

## 🟡 11 de 19 funciones `SECURITY DEFINER` sin `search_path` explícito

Ver `docs/SEGURIDAD.md`. Las 8 funciones del portal de clientes sí lo
establecen; las 11 que no lo hacen son, de nuevo, principalmente las que
escribí yo este año (fichaje + funciones de rol).

## Qué NO es deuda técnica (para que no se confunda)

El diseño "solo-añadir" del fichaje (nunca editar/borrar, correcciones como
registros nuevos enlazados) es intencional y sólido — es la referencia de
cómo debería construirse el resto, no un problema.
