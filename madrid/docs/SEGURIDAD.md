# Seguridad

> Basado en la extracción real de Supabase (octubre 2026). Las secciones
> descriptivas reflejan el estado auditado en el **Bloque 0** (donde no se
> modificó nada en RLS, grants ni funciones). El **núcleo del Bloque 1B** se
> aplicó después en producción: su resultado está en la sección
> [Bloque 1B — núcleo aplicado](#bloque-1b--núcleo-aplicado-y-verificado-en-producción)
> y, donde procede, cada sección antigua lleva una nota de estado.

## Row Level Security (RLS)

**Las 29 tablas tienen RLS activado** (`relrowsecurity = true`). Ninguna
tiene RLS forzado (`relforcerowsecurity = false` en las 29) — esto es
relevante porque significa que el propietario de las tablas (el rol
`postgres`, dueño también de las funciones `SECURITY DEFINER`) **sigue
sin estar sujeto a RLS**, que es precisamente el mecanismo que permite que
funciones como `fichar()` escriban en `fichajes` aunque no exista ninguna
política de `INSERT` para `authenticated`.

102 políticas en total, repartidas así por rol declarado:

- **94 políticas** con rol `{authenticated}` — el patrón correcto y
  predominante.
- **8 políticas** con rol `{public}` (es decir: se aplican a *cualquier*
  rol de conexión, incluido `anon`, el anónimo sin login).

## Las 8 políticas con rol `{public}` — análisis, no alarma

> **Estado (Bloque 1B): resuelto.** Las 8 políticas pasaron a `{authenticated}`
> conservando sus condiciones, y `recepcion_lineas_select` además dejó de ser
> `USING (true)` y se alineó con su tabla padre. Lo que sigue es el análisis
> original del Bloque 0, conservado como registro.

Todas pertenecen a tablas construidas este año (`calendario_config`,
`fichajes`, `recepcion_lineas`, `solicitudes_correccion`) y comparten un
origen común: se escribieron sin la cláusula `TO authenticated` explícita
en el `CREATE POLICY`, y Postgres, al no indicarse rol, las aplica a
`public` por defecto.

| Tabla | Política | Comando | Condición real |
|---|---|---|---|
| `calendario_config` | `calendario_config_select` | SELECT | `true` (sin condición) |
| `calendario_config` | `calendario_config_update` | UPDATE | `es_min_gestor()` |
| `fichajes` | `fichajes_select` | SELECT | tu propio fichaje, o `puede_corregir_fichajes`, o `es_min_gestor()` |
| `recepcion_lineas` | `recepcion_lineas_select` | SELECT | `true` (sin condición) |
| `recepcion_lineas` | `recepcion_lineas_insert` | INSERT | `es_min_responsable()` |
| `recepcion_lineas` | `recepcion_lineas_update` | UPDATE | `es_min_responsable()` |
| `recepcion_lineas` | `recepcion_lineas_delete` | DELETE | `es_min_responsable()` |
| `solicitudes_correccion` | `solicitudes_select` | SELECT | tu propio registro, o `puede_corregir_fichajes`, o `es_min_gestor()` |

**Por qué no parece explotable en la práctica**: todas las condiciones de
escritura dependen de `es_min_responsable()`/`es_min_gestor()`, que a su vez
comparan `auth.jwt() ->> 'email'` contra `personas_equipo.email`. Para una
petición de `anon` (sin sesión), `auth.jwt()` no tiene email, por lo que la
condición debería evaluar a falso igualmente. El riesgo real no es "alguien
sin cuenta puede escribir" (no debería poder), sino que:

1. Es una inconsistencia frente a las otras 94 políticas, que sí restringen
   el rol explícitamente — una capa de defensa de menos.
2. Dos políticas de `SELECT` (`calendario_config_select` y
   `recepcion_lineas_select`) tienen literalmente `USING: true` combinado
   con rol `{public}` — es decir, cualquiera con la clave `anon` (que es
   pública por diseño) puede leer esas dos tablas sin ninguna sesión. Para
   `calendario_config` esto es irrelevante (son solo colores de la interfaz).
   Para `recepcion_lineas` sí implica que el contenido de recepciones
   (qué productos, qué cantidades) es legible sin autenticar.

**Recomendación para una auditoría posterior** (no ejecutada en este
bloque): añadir `TO authenticated` a estas 8 políticas, y revisar si
`recepcion_lineas_select` debería requerir sesión.

## Grants de PostgreSQL — por qué no entran en contradicción con RLS

> **Estado (Bloque 1B): parcialmente resuelto.** `anon` ya no tiene ningún
> privilegio sobre las tablas de `public`, y `authenticated` perdió
> `TRUNCATE`, `TRIGGER` y `REFERENCES`. `authenticated` conserva
> `SELECT/INSERT/UPDATE/DELETE` en las 29 tablas **de forma deliberada en esta
> fase**; su recorte fino está pendiente. Los grants de **funciones**
> (`EXECUTE`) no se han tocado (ver 1B-bis). Lo que sigue es el análisis
> original del Bloque 0.

Los grants muestran privilegios amplios (`SELECT`, `INSERT`, `UPDATE`,
`DELETE`, `REFERENCES`, `TRIGGER`, `TRUNCATE`) concedidos a los tres roles
(`anon`, `authenticated`, `service_role`) en las 29 tablas — 609 filas en
total, 29 tablas × 7 privilegios × 3 roles exactamente.

Esto, por sí solo, **no es una vulnerabilidad**: los `GRANT` de Postgres son
el permiso "de fábrica" sobre la tabla, pero cuando RLS está activado (como
aquí, en las 29 tablas), **cada operación concreta pasa además el filtro de
sus políticas**. Un `GRANT INSERT` sin ninguna política de `INSERT` que lo
permita para ese rol equivale, en la práctica, a que esa inserción sea
rechazada — así es como funcionan, por ejemplo, `fichajes` o `cajas`: tienen
grant de escritura amplio pero ninguna política de `INSERT`/`UPDATE` para
`authenticated` en varias de ellas (la escritura real solo ocurre a través
de funciones `SECURITY DEFINER`, que sí tienen permiso al ser ejecutadas
"como" el propietario de la tabla).

Dicho esto, el patrón de "dar `GRANT ALL` a todos los roles y confiar
enteramente en RLS para todo" es el comportamiento por defecto que deja
Supabase al crear una tabla, no algo configurado a propósito en este
proyecto. **Queda como punto de auditoría posterior**: revisar tabla por
tabla si conviene recortar los grants de `anon` además de depender de RLS
(defensa en profundidad), especialmente en tablas sin ninguna política de
escritura real.

## Restricciones CHECK — solo 3 tablas tienen reglas de negocio a nivel de base de datos

De las 71 restricciones CHECK totales, la inmensa mayoría son
`NOT NULL` representadas como CHECK (comportamiento normal de Postgres). Las
únicas reglas de negocio reales son:

- `calendario_config`: fila única forzada (`id = 1`).
- `fichajes`: `tipo` y `modalidad` limitados a sus valores válidos.
- `solicitudes_correccion`: `tipo`, `modalidad`, `estado` y
  `solicitud_tipo` limitados a sus valores válidos.

Ninguna otra tabla (`salidas`, `recepciones`, `solicitudes`...) tiene sus
valores de `estado` protegidos a nivel de base de datos — ver
`docs/DEUDA-TECNICA.md`.

## Funciones `SECURITY DEFINER` — inventario completo

**Las 19 funciones del esquema son `SECURITY DEFINER`.** Esto es correcto y
necesario para su propósito (ejecutar con permisos elevados para saltarse
RLS de forma controlada, como hace `fichar()` para escribir en `fichajes`) —
`SECURITY DEFINER` no es, por sí solo, un problema; lo sería solo si la
función no controla bien quién la llama y qué datos toca, cosa que hay que
revisar función por función.

### Funciones del sistema de roles

| Función | Argumentos | Devuelve | `search_path` fijado |
|---|---|---|---|
| `mi_rol()` | — | text | ✅ Sí (`public, pg_temp`, desde 1B) |
| `mi_nivel()` | — | integer | ✅ Sí (`public, pg_temp`, desde 1B) |
| `es_admin()` | — | boolean | ✅ Sí (`public, pg_temp`, desde 1B) |
| `es_min_gestor()` | — | boolean | ✅ Sí (`public, pg_temp`, desde 1B) |
| `es_min_responsable()` | — | boolean | ✅ Sí (`public, pg_temp`, desde 1B) |
| `es_min_operario()` | — | boolean | ✅ Sí (`public, pg_temp`, desde 1B) |

Confirman, por fin con certeza y no por suposición, los nombres que se
asumieron en cada script SQL entregado a lo largo del proyecto — **todas
existían y existen con esos nombres exactos**.

### Funciones del fichaje

| Función | Argumentos | Devuelve | `search_path` fijado |
|---|---|---|---|
| `fichaje_mi_persona()` | — | personas_equipo | ✅ Sí (`public, pg_temp`, desde 1B) |
| `fichar()` | tipo, modalidad | fichajes | ✅ Sí (`public, pg_temp`, desde 1B) |
| `solicitar_correccion_fichaje()` | modalidad, hora_solicitada, motivo, solicitud_tipo, tipo, fichaje_original_id | solicitudes_correccion | ✅ Sí (`public, pg_temp`, desde 1B) |
| `aprobar_correccion_fichaje()` | solicitud_id, hora_final, motivo_ajuste | fichajes | ✅ Sí (`public, pg_temp`, desde 1B) |
| `rechazar_correccion_fichaje()` | solicitud_id, motivo_rechazo | solicitudes_correccion | ✅ Sí (`public, pg_temp`, desde 1B) |

### Funciones del portal de clientes

| Función | Argumentos | Devuelve | `search_path` fijado |
|---|---|---|---|
| `es_cliente()` | — | boolean | ✅ Sí (`public`) |
| `mi_cliente_id()` | — | bigint | ✅ Sí (`public`) |
| `mi_catalogo()` | — | tabla (producto, categoría, variante, disponible) | ✅ Sí (`public`) |
| `comprobar_disponibilidad()` | recogida, devolución, items (jsonb), excluir_solicitud_id | tabla de artículos en conflicto | ✅ Sí (`public`) |
| `crear_solicitud()` | evento, recogida, devolución, notas, items (jsonb) | bigint (id creado) | ✅ Sí (`public`) |
| `editar_solicitud()` | solicitud_id, evento, recogida, devolución, notas, items (jsonb) | void | ✅ Sí (`public`) |
| `cancelar_solicitud()` | solicitud_id | void | ✅ Sí (`public`) |
| `mis_solicitudes()` | — | registro (solicitudes del cliente) | ✅ Sí (`public`) |

**Observación directa de su lógica** (leída en el código real de las
funciones, no inferida): `mi_catalogo()` solo devuelve variantes presentes
en `cliente_visibilidad` para ese cliente con `tope > 0`.
`comprobar_disponibilidad()` calcula el compromiso ya existente sumando
`solicitud_items` de solicitudes en estado `pendiente`/`aceptada` que
solapan en fechas, y lo compara contra el `tope` — es una lógica de reserva
con control de solapamiento por fechas, razonablemente cuidada. Todas
obtienen la identidad del cliente a través de `mi_cliente_id()`, que
compara el email del JWT contra `clientes.email` con `activo = true`.

## El hallazgo real sobre `search_path`

> **Estado (Bloque 1B): resuelto.** Las 11 funciones quedaron con
> `search_path = public, pg_temp` (no `public` a secas: `pg_temp` va el último
> para que una tabla temporal no pueda tapar a una real). Hoy hay 0 funciones
> `SECURITY DEFINER` de `public` sin `search_path`. No se cambió la lógica de
> ninguna. Lo que sigue es el análisis original del Bloque 0.

**11 de las 19 funciones no fijan `search_path` explícitamente.** Son,
exactamente, las 6 funciones de roles y las 5 del fichaje — es decir, las
que yo mismo escribí a lo largo de este proyecto. Las 8 funciones del
portal de clientes (que no se construyeron en estas sesiones) sí lo hacen
correctamente (`SET search_path TO 'public'`).

**Por qué importa**: en Postgres, una función `SECURITY DEFINER` sin
`search_path` fijado puede, en teoría, ser engañada para ejecutar un objeto
(función, tabla) con el mismo nombre creado por un atacante en un esquema
que aparezca antes en el `search_path` de quien la ejecuta — un vector de
escalada de privilegios conocido y documentado (es, de hecho, uno de los
avisos estándar del linter de seguridad propio de Supabase). Requiere que
el atacante tenga permiso de `CREATE` en algún esquema del `search_path` del
invocador, lo cual en un proyecto Supabase estándar sin esquemas adicionales
personalizados no es trivial — pero no se ha verificado activamente si esa
condición se da aquí o no.

**No se ha corregido en este bloque** (modificar funciones estaba
explícitamente excluido). Queda registrado como el punto de seguridad más
concreto y accionable para una auditoría posterior, con una corrección
conocida y de bajo riesgo cuando se decida abordarla: añadir `SET
search_path = public` (o `= ''`) a esas 11 funciones.

## Bloque 1B — núcleo aplicado y verificado en producción

Aplicado en Supabase (octubre 2026) con los scripts versionados en
`docs/sql/` (`1B-01_nucleo_migracion.sql`, tal cual están en el repositorio,
sin modificaciones manuales). Cada paso fue una transacción independiente con
guardas de seguridad.

| Paso | Cambio | Resultado verificado |
|---|---|---|
| 0 (D0b) | Instantánea en el esquema privado `_hardening_1b` | `acl_snapshot` 1023 filas, `policy_snapshot` 102, `funcconf_snapshot` 19. Las 11 funciones objetivo estaban sin `search_path` |
| 1 (D1) | `search_path = public, pg_temp` en las 11 `SECURITY DEFINER` | 0 funciones `SECURITY DEFINER` de `public` sin `search_path`; las otras 8 conservan `public` |
| 2 (D2) | 8 policies `{public}` → `{authenticated}`, sin tocar `USING` / `WITH CHECK` | 0 policies `{public}`; 102 en total; 8 diferencias respecto a la instantánea, `cambia_with_check = false` en todas |
| 3 (D2b) | `recepcion_lineas_select`: `USING (NOT es_cliente())` (antes `true`) | Idéntica a `recepciones_ver`: `{authenticated}`, `USING (NOT es_cliente())`. Solo `recepcion_lineas_select` cambia `USING` |
| 4 (D3) | `anon`: se retiran todos los privilegios de las 29 tablas; `authenticated`: se retiran `TRUNCATE`, `TRIGGER`, `REFERENCES` | Ver abajo |

**Grants de tabla (V3 / V4).** `anon` sin ningún privilegio; `authenticated`
conserva `SELECT/INSERT/UPDATE/DELETE` en las 29 tablas y no tiene
`TRUNCATE/TRIGGER/REFERENCES`; `service_role` intacto en las 29. La diferencia
exacta frente a la instantánea fue de **319 privilegios retirados** y ninguno
añadido: `anon` 8 × 29 = 232 (los 7 clásicos más `MAINTAIN`, privilegio de
PostgreSQL 17+) y `authenticated` 3 × 29 = 87. El comentario original del
script esperaba 290 por no contar `MAINTAIN`; el resultado es coherente con
`REVOKE ALL ... FROM anon` y no requirió rollback (el comentario se corrigió).

**Funciones (V5).** Las ACL de las funciones no cambiaron (0 retiradas, 0
añadidas). `ALTER FUNCTION ... SET search_path` no modifica privilegios.

**Precondición de D1.** Antes de fijar `search_path`, el script comprueba que
`anon`, `authenticated` y `PUBLIC` no tienen `CREATE` sobre el esquema `public`
(si lo tuvieran, podrían plantar objetos que una función resolvería antes que
los reales). Estado auditado del esquema: `PUBLIC`, `postgres`, `anon`,
`authenticated` y `service_role` solo con `USAGE`; únicamente
`pg_database_owner` tiene `CREATE`.

**Prueba funcional registrada en producción.** Login, dashboard y carga de
datos, lectura de inventario, y un `UPDATE` real (descripción de un producto
modificada y restaurada después), todo correcto. Aquí no consta como
ejecutada ninguna prueba específica de portal de clientes, fichajes ni
recepciones con distintos roles, ni de las peticiones negativas con la clave
`anon`.

### Qué NO se ha hecho en este bloque (a propósito)

- **No se ha tocado `EXECUTE` de las funciones ni el privilegio de `PUBLIC`
  (D4).** Queda para el **Bloque 1B-bis**: `PUBLIC` tiene `EXECUTE` en las 19
  funciones, `anon` también (directo), y varios roles internos de Supabase
  (`authenticator`, `pgbouncer`, `supabase_auth_admin`, `dashboard_user`,
  `supabase_etl_admin`, `supabase_privileged_role`...) lo heredan aparentemente
  de `PUBLIC`; retirarlo podría afectarles y requiere evidencia previa.
- No se recortó el DML de `authenticated`: conservar `SELECT/INSERT/UPDATE/DELETE`
  en las 29 tablas es **deliberado en esta fase**, no el modelo final de mínimo
  privilegio. Hoy la separación equipo / clientes del portal descansa en RLS.
- No se habilitó `FORCE ROW LEVEL SECURITY`.
- No se modificaron los *default privileges*.
- No se modificaron permisos de secuencias.
- No se tocaron los emails de administrador hardcodeados (deuda separada, ver
  `docs/DEUDA-TECNICA.md`).

### Red de seguridad: instantánea y rollback

- El esquema `_hardening_1b` **debe conservarse por ahora**. Es lo que permite
  el rollback exacto.
- `docs/sql/1B-02_nucleo_rollback.sql` **no debe ejecutarse ni eliminarse**
  mientras se conserve esta red de seguridad. Solo se ejecutaría si fuera
  necesario revertir el bloque, paso a paso (R3 → R2 → R1).
- La eliminación del esquema (`drop schema _hardening_1b cascade`, al final
  de ese script, comentada) es una decisión explícita posterior, no parte de
  este bloque.

## Elementos sensibles — resultado de la auditoría pre-Git

| Elemento | Dónde | Gravedad | Estado |
|---|---|---|---|
| `SUPABASE_ANON_KEY` | `js/supabase.js` | Baja — es una clave pública por diseño, protegida por RLS, no un secreto que deba ocultarse | Identificada, **no movida** (fuera del alcance de este bloque, tal como se pidió) |
| `SUPABASE_URL` | `js/supabase.js` | Ninguna por sí sola — es pública por diseño | Identificada, no movida |
| `PASS_CORRECTA` (contraseña real) | `js/utils.js` | Media — contraseña real en texto plano, de un sistema sin uso | ✅ **Retirada en este bloque** |
| Emails de `ADMINS_BLINDADOS` | `admin.html` | Baja-media — datos personales (emails reales) publicados en el código fuente que llega a cualquier navegador, sin necesidad técnica de que sean públicos | Identificada, no modificada (es código funcional, fuera del alcance de "solo preparar el baseline") |

**No se ha encontrado**: ninguna `service_role key`, ningún token de API de
terceros, ninguna clave privada, ningún archivo `.env` ni de configuración
local con secretos, ningún export, dump, backup o log versionado por error,
ni datos reales de producción (clientes, empleados, fichajes, inventario)
en ninguno de los 5 archivos de código ni en los CSV de extracción del
esquema (que, tal como se pidió, solo contienen estructura).

No se han encontrado archivos inesperados fuera de los que ya se conocían
(los 5 de código + el `TRASPASO...md` + los 9 CSV/TXT del esquema + una
captura de pantalla de una conversación anterior, sin relación con el
código).
