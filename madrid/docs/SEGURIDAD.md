# Seguridad

> Basado en la extracción real de Supabase (octubre 2026). Las secciones
> descriptivas reflejan el estado auditado en el **Bloque 0** (donde no se
> modificó nada en RLS, grants ni funciones). El **núcleo del Bloque 1B** se
> aplicó después en producción: su resultado está en la sección
> [Bloque 1B — núcleo aplicado](#bloque-1b--núcleo-aplicado-y-verificado-en-producción),
> en la de [1B-bis](#bloque-1b-bis--execute-de-las-19-funciones-d4-d4a-aplicado-y-verificado-d4b-no-ejecutado)
> y en la de [eliminación del admin bypass](#bloque-1b--eliminación-del-admin-bypass-aplicado-con-pruebas-manuales-pendientes);
> donde procede, cada sección antigua lleva una nota de estado.

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
> (`EXECUTE`) no se tocaron en el núcleo; D4a (1B-bis) retiró después `PUBLIC` y
> `anon`, y D4b sigue aplazado. Lo que sigue es el análisis
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
| `mi_rol()` | — | text | ✅ Sí (`public, pg_temp`, desde 1B). Desde 2026-10-07 ya no contiene emails hardcodeados: el rol sale solo de `personas_equipo` |
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
  (D4) en el núcleo.** *(Actualización: D4a se aplicó después en 1B-bis, el
  2026-10-02; D4b sigue aplazado. Lo que sigue describe la situación al cierre del
  núcleo.)* Quedaba para el **Bloque 1B-bis**: `PUBLIC` tenía `EXECUTE` en las 19
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
- No se tocaron los emails de administrador hardcodeados dentro de este
  bloque. Se abordaron después como bloque propio; ver
  [Eliminación del admin bypass](#bloque-1b--eliminación-del-admin-bypass-aplicado-con-pruebas-manuales-pendientes).

### Red de seguridad: instantánea y rollback

- El esquema `_hardening_1b` **debe conservarse por ahora**. Es lo que permite
  el rollback exacto.
- `docs/sql/1B-02_nucleo_rollback.sql` **no debe ejecutarse ni eliminarse**
  mientras se conserve esta red de seguridad. Solo se ejecutaría si fuera
  necesario revertir el bloque, paso a paso (R3 → R2 → R1).
- La eliminación del esquema (`drop schema _hardening_1b cascade`, al final
  de ese script, comentada) es una decisión explícita posterior, no parte de
  este bloque.

## Bloque 1B-bis — `EXECUTE` de las 19 funciones (D4): D4a APLICADO y verificado; D4b NO ejecutado

> **Estado:** **D4a aplicado en producción el 2026-10-02 y verificado** (ver "Resultado de D4a").
> **D4b (opcional) NO se ha ejecutado** y permanece aplazado. Scripts en
> `docs/sql/1B-04` a `1B-07`.

### Evidencia (auditoría de solo lectura en producción)

| Ref. | Resultado |
|---|---|
| A1 | 19 `SECURITY DEFINER` en `public`, owner `postgres`, una sobrecarga por nombre |
| A3/A3b, M1 | Solo `es_admin`, `es_cliente`, `es_min_gestor`, `es_min_operario` y `es_min_responsable` tienen dependencias registradas, y todas son `pg_policy`. Ninguna dependencia de tipo `pg_attrdef`, `pg_constraint`, `pg_rewrite`, `pg_trigger`, `pg_proc` u otro |
| A4/A4b | Sin triggers normales; los 6 event triggers son de infraestructura y ninguno usa nuestras funciones |
| A5/M3c | ACL idéntica en las 19: `EXECUTE` a `PUBLIC`, `anon`, `authenticated`, `postgres`, `service_role`; sin grant option |
| A7/A8 | Sin `pgrst.*` específico; sin Auth Hooks |
| M2a | Los 4 helpers solo los nombran funciones `SECURITY DEFINER` con owner `postgres`: `fichaje_mi_persona` ← `fichar` y las 3 de corrección; `mi_cliente_id` ← las 6 RPC del portal; `mi_nivel` ← `es_admin` y los 3 `es_min_*`; `mi_rol` ← `mi_nivel`. Ninguna `SECURITY INVOKER`, ninguna de otro esquema |
| M2b/M2c/M2d | Sin vistas; `pg_cron` no instalado; ninguna policy (todos los esquemas) nombra los 4 helpers |
| M3a/M3b | `authenticator` es `NOINHERIT` (`set_option = true`, `inherit_option = false` hacia `anon`, `authenticated`, `service_role`); `anon` y `authenticated` heredan; `postgres` hereda de todos |
| M3d | Excluyendo `PUBLIC`: `anon`, `authenticated` y `service_role` 19/19 (grants directos); `authenticator`, `dashboard_user`, `pgbouncer`, `supabase_auth_admin`, `supabase_etl_admin`, `supabase_privileged_role` y `supabase_storage_admin` 0/19: hoy solo tienen `EXECUTE` por `PUBLIC` |
| Repo | 10 `.rpc(...)` en Madrid (4 en `admin.html`, 6 en `portal.html`); ningún helper se llama desde el navegador; sin storage, realtime, Edge Functions ni `fetch` directo; los demás proyectos del repo usan otros proyectos Supabase |

### Semántica en la que se apoya el diseño

- Una función usada en una policy se ejecuta **como el rol que consulta**: `authenticated` necesita `EXECUTE` en las 5 `es_*()`. *(Semántica estándar de Postgres; los scripts la comprueban con sondas.)*
- Una llamada anidada desde una `SECURITY DEFINER` se comprueba contra el **owner** (`postgres`, que conserva su grant): los helpers internos no necesitan `EXECUTE` para `authenticated`.
- Las 102 policies son `{authenticated}` y `anon` no tiene privilegios de tabla: `anon` no necesita `EXECUTE` en ninguna.
- PostgREST hace `SET ROLE anon/authenticated`: `authenticator` no ejecuta las funciones de aplicación, y con `NOINHERIT` ya no hereda nada de esos roles. Tras un `SET ROLE` mandan los privilegios del rol destino, no los de `authenticator`. `SET` está permitido y `INHERIT` no, que es lo que PostgREST necesita y nada más.

### Modelo propuesto

- **D4a** — `REVOKE EXECUTE FROM PUBLIC, anon` en las 19. `authenticated`, `service_role` y `postgres` no cambian. Efecto: 38 filas de ACL menos (19 PUBLIC + 19 anon).
- **D4b (opcional)** — `REVOKE EXECUTE FROM authenticated` en `mi_rol`, `mi_nivel`, `fichaje_mi_persona` y `mi_cliente_id`. Efecto: 4 filas más (42 en total). Se mantiene como paso separado: su ganancia es menor (esos helpers solo devuelven datos del propio llamante) y su fallo, si lo hubiera, sería de alto impacto (RLS). Se aplica tras D4a verificado, con pruebas reales y reversible con un `GRANT`.
- **No se tocan:** `service_role`, `postgres`, *default privileges*, tablas, policies, `search_path`.

### Resultado de D4a (aplicado y verificado)

- **D4-0:** instantánea `_hardening_1b.acl_snapshot_d4` de 95 filas.
- **D4a (aplicado el 2026-10-02, según el marcador `D4a_aplicado` de V6.6):**
  `REVOKE EXECUTE ... FROM PUBLIC, anon` en las 19 funciones. Según V6.2 se
  retiraron únicamente 19 `EXECUTE` de `PUBLIC` y 19 de `anon`; `authenticated`,
  `service_role` y `postgres` no cambiaron.
- **Verificaciones SQL V6.1–V6.6:** todas superadas.
- **Prueba negativa con la clave `anon`, sin sesión, contra la API real:**
  `mi_catalogo` → HTTP 401, `42501`, `permission denied for function mi_catalogo`;
  `es_admin` → HTTP 401, `42501`, `permission denied for function es_admin`.
  Se usó solo la clave pública, sin `service_role`, y las llamadas no modifican datos.
- **`fichar` no se probó a propósito** con `anon`, para evitar cualquier posibilidad de
  escritura en producción (es la única de las tres que escribe). Se considera redundante:
  las 19 funciones comparten la misma ACL y V6.2/V6.5 confirman que `anon` y `PUBLIC`
  ya no tienen `EXECUTE` en ninguna.
- **Pruebas funcionales con usuario autenticado:** login, dashboard y lectura de
  inventario correctos; `UPDATE` controlado (descripción de "Agua Zero Sodio" modificada
  y restaurada a vacío) sin errores; portal de cliente: login y carga básica sin errores
  de permisos (el portal sigue en desarrollo funcional).
- **No probado todavía** (no necesario para cerrar D4a, `authenticated` no cambió):
  fichajes (fichar, solicitar/aprobar/rechazar corrección), crear/editar/cancelar
  solicitudes del portal y comprobar disponibilidad, y pruebas por cada nivel de
  usuario. Pasan a ser **requisito previo de D4b**.
- **D4b:** no ejecutado, opcional y aplazado. No hay marcador `D4a_verificado` ni
  `D4b_aplicado` en `d4_control`.
- Mientras D4b no se aplique, V5 de `1B-03` no es válida; usar V6 (`1B-07`).

### Riesgos residuales y desconocidos

- **Consumidores externos** no versionados que usen la clave `anon` contra las 19 funciones: el repo no permite descartarlos. Tras D4a quedarían rechazados (prueba negativa verificada con `mi_catalogo` y `es_admin`); si existiera alguno, habría dejado de funcionar.
- Los **cuerpos** de las funciones no están versionados: A2/M2a son búsquedas textuales y no detectan SQL dinámico construido por concatenación. D4b lleva sondas dentro de la transacción, pero pueden fallar antes de llegar al helper; la prueba real es la de usuarios de cada nivel.
- **Deriva futura:** un `DROP` + `CREATE` de una función en `public` volvería a darle `EXECUTE` a `anon` y `authenticated` por los *default privileges* de Supabase. D4 no lo previene; `1B-07` (V6.5) lo detecta.
- El **linter de Supabase** seguirá avisando de las funciones `SECURITY DEFINER` que conservan `EXECUTE` para `authenticated` (esperado).
- Efecto en PostgREST de la pérdida del `EXECUTE` que `authenticator` obtenía vía `PUBLIC`: no se ha observado ningún problema tras D4a (la API responde, el login y las lecturas funcionan). `authenticator` no ejecuta estas funciones.

## Bloque 1B — Eliminación del admin bypass: aplicado, con pruebas manuales pendientes

> **Estado:** scripts A y B **aplicados en producción** y verificados por SQL
> (V8.2–V8.7). **Pendientes de prueba manual:** inicio de sesión de la segunda
> cuenta administradora y prueba con una cuenta de rol inferior. Scripts en
> `docs/sql/1B-08` a `1B-11`. Las cabeceras de `1B-08`, `1B-09` y `1B-10` siguen
> diciendo "PREPARADO, NO APLICADO / NO EJECUTADO" porque los scripts no se
> modificaron; **el estado real es el de esta sección**.

### Qué había y qué cambió

Antes, `mi_rol()` devolvía `'admin'` por email para dos cuentas "blindadas" **antes**
de consultar `personas_equipo` (donde ambas figuraban como `consulta`), y
`admin.html` repetía esa lista (`ADMINS_BLINDADOS`). Ahora el rol de todas las
cuentas, esas dos incluidas, sale únicamente de `personas_equipo`.

### Orden de aplicación y registros (hora de Madrid)

| Paso | Qué hizo | Fecha / marcador |
|---|---|---|
| A (`1B-08`) | Las 2 cuentas pasan a `rol='admin'`, `activo=true` en `personas_equipo`; respaldo en `_hardening_1b` | `A_aplicado`: 2026-10-06 13:50:39 |
| Frontend | `admin.html` sin `ADMINS_BLINDADOS`, desplegado y verificado. Commit `5c535a960148beea89d5c588b060a86e5e3a9774` | — |
| B-0 (`1B-09`) | Marcador manual de frontend verificado | `frontend_verificado`: 2026-10-07 10:33:08 |
| B-1 (`1B-09`) | `DRY_RUN` superado (guardas, comparación diferencial y aserciones; rollback verificado); después `COMMIT` | `B_aplicado`: 2026-10-07 13:40:55 |
| Scripts SQL versionados | Commit `d4e059b925de3f4302a5e6cf491f81e0101536e6` | — |

B se ejecutó antes que cualquier D4b, como exigía su procedimiento (D4b cambiaría
el ACL de `mi_rol()` y B abortaría por deriva).

### Verificaciones (`1B-11`, solo lectura)

| Ref. | Resultado confirmado |
|---|---|
| V8.2 | `mi_rol()` sin emails en el cuerpo; `SECURITY DEFINER`, owner `postgres`, `STABLE`, `search_path=public, pg_temp`, ACL intacta |
| V8.3 | Cuerpo nuevo distinto del respaldo; respaldo original conservado |
| V8.4 | Las 5 funciones dependientes (`mi_nivel`, `es_admin`, `es_min_gestor`, `es_min_responsable`, `es_min_operario`) presentes |
| V8.5 | Marcadores `A_aplicado`, `frontend_verificado` y `B_aplicado` registrados |
| V8.6 | 19 funciones `SECURITY DEFINER`; ninguna ejecutable por `PUBLIC`/`anon`; `authenticated` conserva `EXECUTE` sobre `mi_rol()` (D4b sin ejecutar) |
| V8.7a | Ninguna función de `public` contiene emails literales detectados |
| V8.7b | Cero políticas, vistas o vistas materializadas con emails literales detectados |

**Alcance de V8.7 (no es una garantía absoluta).** Son búsquedas por patrón
(forma de email y el texto `equipo47`) sobre el cuerpo de las funciones de `public`
y sobre las definiciones de políticas, vistas y vistas materializadas. No cubren
otros esquemas, ni datos en tablas, ni SQL construido dinámicamente por
concatenación. Se lee como "no se detectó ninguno con estas búsquedas".

### Pruebas manuales

| Prueba | Estado |
|---|---|
| Primera cuenta administradora en producción | ✅ Funciona con normalidad (2026-10-08) |
| Inicio de sesión de la **segunda** cuenta administradora | ⏳ **PENDIENTE — no realizada** |
| Cuenta de **rol inferior** (si está disponible) | ⏳ **PENDIENTE — no realizada** |

Hasta que se hagan, el bloque no debe darse por plenamente validado desde el punto
de vista del usuario final.

### Rollback (scripts `1B-10`)

Orden de ejecución: **C1 → frontend → C2**. C2 solo corresponde a una reversión
completa; para revertir únicamente la lógica basta C1.

1. **C1 — restaurar `mi_rol()`** (lógica). Recupera la definición original, con el
   bypass, desde `_hardening_1b.admin_bypass_mi_rol_backup`. Es seguro hacerlo primero
   porque las 2 cuentas ya son `admin` en la tabla: nadie pierde acceso. Aborta si B
   no consta aplicado, si el estado es inesperado, o si tras restaurar el cuerpo,
   las propiedades o el ACL no coinciden con el respaldo.
2. **Frontend** — restaurar el `admin.html` anterior (el commit de retirada es
   `5c535a9`). Sin SQL. **Antes**, revisar el diff y el estado de Git (cambios sin
   confirmar, commits posteriores que toquen `admin.html`); no ejecutar un `git
   revert` automáticamente sin comprobar sus efectos. Es **imprescindible antes de
   C2** y debe quedar restaurado, desplegado y verificado: el frontend lee el rol de
   `personas_equipo`, y sin él las 2 cuentas verían el menú de `consulta` aunque
   `mi_rol()` siga dándoles admin. Si solo se revierte la lógica (C1), no es
   necesario.
3. **C2 — devolver las 2 cuentas a su rol previo (`consulta`)**, **solo si se
   requiere una reversión completa**, con el frontend anterior ya verificado, y si
   se cumplen sus guardas (el script no comprueba el frontend): ejecutar como
   `postgres`; `mi_rol()` debe ser ya la definición con bypass (si no, aborta con
   "ORDEN INCORRECTO"); `A` debe constar aplicado; el respaldo debe tener 2 filas;
   las 2 cuentas deben seguir como `admin` (si alguien las cambió, aborta y exige
   revisar a mano).

**Precauciones.**
- **Nunca C2 con el bypass retirado de `mi_rol()`**: las 2 cuentas quedarían como
  `consulta` y nadie podría reasignar roles.
- Cada paso es una transacción independiente: un paso cada vez, como `postgres`.
- Tras un rollback completo, A **no** es reaplicable tal cual (las tablas
  `admin_bypass_*` conservan sus filas y A aborta por "estado inconsistente"): es un
  fallo seguro deliberado.
- Recuperación de emergencia si se perdiera todo acceso admin: desde el SQL Editor
  (`postgres`, no sujeto a RLS), un `update` de `personas_equipo.rol = 'admin'` sobre
  la cuenta afectada.

### Red de seguridad conservada

El esquema `_hardening_1b` **se conserva**, con `admin_bypass_control` (marcadores),
`admin_bypass_mi_rol_backup` (definición y propiedades originales de `mi_rol()` y
huellas de las dependientes) y `admin_bypass_personas_backup` (estado previo de las 2
filas). No se ha ejecutado ninguna limpieza. Borrarlas es una decisión explícita
posterior, que además eliminaría la base del rollback.

### Pendiente y deuda abierta (no resuelto por este bloque)

- **Pérdida del último administrador:** sin el bypass, no hay red de seguridad si la
  tabla se queda sin admins activos. Sin protección automática (ver
  `docs/DEUDA-TECNICA.md`).
- **Semántica de `activo=false`:** `mi_rol()` **no consulta `activo`**. Sin definir; se
  abordará por separado (ver `docs/DEUDA-TECNICA.md`).
- **D4b** sigue **sin ejecutar** (ver sección 1B-bis).

## Elementos sensibles — resultado de la auditoría pre-Git

| Elemento | Dónde | Gravedad | Estado |
|---|---|---|---|
| `SUPABASE_ANON_KEY` | `js/supabase.js` | Baja — es una clave pública por diseño, protegida por RLS, no un secreto que deba ocultarse | Identificada, **no movida** (fuera del alcance de este bloque, tal como se pidió) |
| `SUPABASE_URL` | `js/supabase.js` | Ninguna por sí sola — es pública por diseño | Identificada, no movida |
| `PASS_CORRECTA` (contraseña real) | `js/utils.js` | Media — contraseña real en texto plano, de un sistema sin uso | ✅ **Retirada en este bloque** |
| Emails de `ADMINS_BLINDADOS` | `admin.html` | Baja-media — datos personales (emails reales) publicados en el código fuente que llega a cualquier navegador, sin necesidad técnica de que sean públicos | ✅ **Retirados del frontend** (commit `5c535a9`, desplegado y verificado; marcador `frontend_verificado` 2026-10-07) y del cuerpo de `mi_rol()` (`B_aplicado` 2026-10-07). Los emails siguen en el historial de git. Ver la sección "Eliminación del admin bypass" |

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
