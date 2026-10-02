# Deuda técnica y problemas conocidos

> Lista viva. Nada de lo aquí descrito se corrigió en el Bloque 0 (salvo el
> punto marcado explícitamente como excepción) — es registro para decidir
> prioridades más adelante, no un backlog ya en marcha. Los puntos de
> seguridad marcados ✅ se resolvieron después, en el núcleo del Bloque 1B
> (ver `docs/SEGURIDAD.md`).

## ✅ Corregido: `exportarCSV` estaba roto

> **Estado: corregido** en el commit `39db3e2` (*fix(madrid): corregir
> colisión de nombres en exportarCSV*): la función de `admin.html` se renombró
> a `exportarTablaCSV` y los 5 botones de exportar pasaron a llamarla, de modo
> que `exportarCSV(datos, nombre)` de `js/utils.js` deja de quedar tapada. Lo
> que sigue es la descripción original del problema, conservada como registro.

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

No se corrigió en el Bloque 0 (excluido explícitamente); se corrigió después
(ver nota de estado arriba).

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
— 0 usos en `admin.html`. Solo `toast`, `confirmar`, `exportarCSV` (la
colisión de nombres con `admin.html` ya está corregida, ver arriba) y `hace` están realmente en uso.

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

## ✅ Resuelto en el Bloque 1B: políticas RLS con rol `{public}`

Las 8 políticas (de 102) pasaron a `{authenticated}` conservando sus
condiciones, y `recepcion_lineas_select` se alineó con su tabla padre
(`USING (NOT es_cliente())`, antes `true`). Detalle y verificación en
`docs/SEGURIDAD.md`.

## ✅ Resuelto en el Bloque 1B: 11 funciones `SECURITY DEFINER` sin `search_path`

Las 11 quedaron con `search_path = public, pg_temp`, sin cambiar su lógica.
Hoy no queda ninguna función `SECURITY DEFINER` de `public` sin `search_path`.
Ver `docs/SEGURIDAD.md`.

## 🟡 Pendiente (Bloque 1B-bis): `EXECUTE` de las 19 funciones y privilegio de `PUBLIC`

**No se ha tocado en el núcleo del Bloque 1B** (las ACL de funciones no
cambiaron). Hoy `PUBLIC` y `anon` tienen `EXECUTE` sobre las 19 funciones.
Retirar el de `PUBLIC` afectaría indirectamente a varios roles internos de
Supabase (`authenticator`, `pgbouncer`, `supabase_auth_admin`,
`dashboard_user`, `supabase_etl_admin`, `supabase_privileged_role`...), que
parecen heredarlo de `PUBLIC`. Requiere evidencia de solo lectura previa
(membresías, uso real, ACL de esquemas, configuración de PostgREST) y probablemente
una prueba en un entorno clonado antes de decidir entre revocar `PUBLIC`,
bloquear a `anon` a nivel de esquema, o aplazarlo.

## 🟡 Pendiente: recorte fino de DML de `authenticated`

`authenticated` conserva `SELECT/INSERT/UPDATE/DELETE` en las 29 tablas.
Es **deliberado en esta fase** (preserva el comportamiento actual, y
`1B-03_nucleo_verificacion.sql` lo vigila con `auth_con_dml = 29`), pero no es
el modelo final de mínimo privilegio: los clientes del portal y el equipo
comparten el rol `authenticated`, de modo que la separación descansa solo en
RLS (94 políticas). Revisar tabla por tabla qué operaciones necesita de
verdad el rol, apoyándose en la matriz de uso del frontend.

## 🟡 Deuda separada: emails de administrador hardcodeados

`mi_rol()` (función `SECURITY DEFINER`) contiene emails de administrador
escritos en el código de la función, y `ADMINS_BLINDADOS` en `admin.html`
publica emails reales en el código que llega al navegador. No se ha tocado
ninguno y **no debe resolverse dentro del Bloque 1B**; es una tarea propia.

## 🟡 Endurecimientos de seguridad no abordados

- `FORCE ROW LEVEL SECURITY` sin habilitar (el propietario sigue sin estar
  sujeto a RLS, necesario hoy para las funciones `SECURITY DEFINER`).
- *Default privileges*: sin revisar ni modificar.
- Permisos de secuencias: sin auditar ni modificar.
- Consumidores externos del proyecto: el repositorio no permite descartar
  scripts o integraciones no versionadas que usen la clave `anon`.
- Instantánea `_hardening_1b` y `1B-02_nucleo_rollback.sql`: conservar por
  ahora. Eliminar el esquema es una decisión explícita posterior.

## Qué NO es deuda técnica (para que no se confunda)

El diseño "solo-añadir" del fichaje (nunca editar/borrar, correcciones como
registros nuevos enlazados) es intencional y sólido — es la referencia de
cómo debería construirse el resto, no un problema.
