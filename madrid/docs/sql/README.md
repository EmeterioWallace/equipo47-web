# SQL del proyecto

## Qué hay aquí

- **`extraer_esquema_real.sql`** — script de solo lectura que consulta los
  catálogos internos de Postgres (`information_schema`/`pg_catalog`) para
  extraer los metadatos reales del esquema de Supabase: tablas, columnas,
  claves primarias y foráneas, índices, restricciones CHECK, enums, vistas,
  funciones (incluido su código), triggers, estado de RLS, políticas y
  grants. Es la misma herramienta que se usó para la auditoría del Bloque 0
  (octubre de 2026), y queda versionada aquí para poder repetir esa
  auditoría en el futuro sin tener que reconstruir las consultas desde
  cero.

- **`1B-01_nucleo_migracion.sql`**, **`1B-02_nucleo_rollback.sql`** y
  **`1B-03_nucleo_verificacion.sql`** — migración, rollback y verificación del
  núcleo del Bloque 1B (mínimo privilegio y endurecimiento de funciones
  `SECURITY DEFINER`). Ver la sección siguiente.

- **`1B-04` a `1B-07`** (1B-bis, `EXECUTE`) y **`1B-08` a `1B-11`** (eliminación
  del admin bypass): ver sus secciones más abajo.

## Bloque 1B (núcleo): migración, rollback y verificación

**Estado: aplicado y verificado en producción** (octubre 2026). El detalle de
lo que cambió y de lo que no está en `docs/SEGURIDAD.md`.

| Archivo | Para qué sirve |
|---|---|
| `1B-01_nucleo_migracion.sql` | Instantánea (PASO 0), `search_path` de 11 funciones (D1), 8 policies a `authenticated` (D2), `recepcion_lineas_select` alineada con su padre (D2b) y grants de tabla (D3). Cada paso es una transacción propia con guardas; se ejecutó **un paso cada vez**, con el rol `postgres`. Es exactamente el SQL ejecutado en producción |
| `1B-02_nucleo_rollback.sql` | Revierte la migración (R3 → R2 → R1) restaurando lo guardado en el esquema `_hardening_1b`. **No ejecutar ni eliminar** mientras se conserve la red de seguridad; solo se usaría para revertir el bloque |
| `1B-03_nucleo_verificacion.sql` | Consultas de **solo lectura** (V1–V5) que comparan el estado real con la instantánea. Seguro de repetir en cualquier momento |

Notas importantes:

- **Dependen de la instantánea.** El rollback y las comparaciones de V2, V4 y V5
  leen el esquema privado `_hardening_1b`, creado por el PASO 0. Ese esquema
  **debe conservarse por ahora**; eliminarlo (`drop schema _hardening_1b
  cascade`, comentado al final del rollback) es una decisión posterior y
  explícita.
- **Guardas con cifras exactas** (29 tablas, 102 policies, 8 `{public}`, 11
  funciones...). Si el esquema cambia, el PASO 0 aborta a propósito: hay que
  volver a auditar antes de reutilizar estos scripts.
- **Fuera de alcance, y no incluido en ninguno de los tres archivos:**
  `EXECUTE` de funciones y privilegio de `PUBLIC` (previsto como Bloque
  **1B-bis**, aplicado después), recorte fino de DML de `authenticated`, `FORCE
  RLS`, *default privileges* y secuencias. Los emails hardcodeados de `mi_rol()` se
  trataron después en el bloque admin bypass (abajo). Las ACL de funciones se guardan
  en la instantánea solo como evidencia para 1B-bis.
- **No contienen datos reales** (solo estructura y privilegios), igual que el
  resto de este directorio.

## Bloque 1B-bis (D4): `EXECUTE` de las 19 funciones — D4a APLICADO, D4b NO EJECUTADO

**Estado: D4-0 y D4a ejecutados en producción (D4a el 2026-10-02) y verificados (V6.1–V6.6 y prueba negativa
con `anon`). D4b (opcional) no se ha ejecutado y permanece aplazado.** Los scripts
`1B-05` (D4b) y `1B-06` (rollback) siguen sin ejecutar. Diseño, evidencia y resultado en
`docs/SEGURIDAD.md`, sección "1B-bis".

| Archivo | Para qué sirve |
|---|---|
| `1B-04_d4a_execute_migracion.sql` | PASO D4-0 (instantánea `acl_snapshot_d4` + tabla `d4_control`) y **D4a**: `REVOKE EXECUTE ... FROM PUBLIC, anon` en las 19 |
| `1B-05_d4b_execute_migracion.sql` | **D4b** (opcional, independiente): `REVOKE EXECUTE ... FROM authenticated` en `mi_rol`, `mi_nivel`, `fichaje_mi_persona`, `mi_cliente_id`. Paso D4b-0 (marcador manual) y D4b-1 (cambio) |
| `1B-06_d4_execute_rollback.sql` | R4b (solo D4b) y R4a (restaura las 19 a la instantánea, con diferencia 0) |
| `1B-07_d4_verificacion.sql` | Consultas de solo lectura (V6.1–V6.6) y lista de pruebas manuales |

Reglas de ejecución: rol `postgres`, **un paso cada vez**; D4b exige haber aplicado D4a,
el marcador `D4a_verificado` (D4b-0) y que hayan pasado 5 minutos antes de D4b-1, de modo
que D4a y D4b no puedan ejecutarse accidentalmente juntos. Tras D4, la consulta V5 de
`1B-03` deja de ser válida (las ACL cambian a propósito); usar V6.

## Bloque 1B — Eliminación del admin bypass: A y B APLICADOS, pruebas manuales pendientes

**Estado real:** A aplicado (`A_aplicado`, 2026-10-06 13:50:39 Madrid), frontend
verificado (`frontend_verificado`, 2026-10-07 10:33:08) y B aplicado (`B_aplicado`,
2026-10-07 13:40:55). Verificado con `1B-11` (V8.2–V8.7). C **no se ha ejecutado**.
**Las cabeceras de `1B-08` y `1B-09` siguen diciendo "NO APLICADO" y la de `1B-10`
"NO EJECUTADO"**: los scripts no se modificaron; este README y `docs/SEGURIDAD.md`
recogen el estado real. Commits: frontend `5c535a960148beea89d5c588b060a86e5e3a9774`,
scripts `d4e059b925de3f4302a5e6cf491f81e0101536e6`.

| Archivo | Para qué sirve |
|---|---|
| `1B-08_admin_bypass_A_datos.sql` | **A** (aplicado): las 2 cuentas blindadas pasan a `rol='admin'`, `activo=true` en `personas_equipo`; crea las tablas `admin_bypass_*` en `_hardening_1b` con el respaldo |
| `1B-09_admin_bypass_B_logica.sql` | **B-0** (marcador `frontend_verificado`, aplicado) y **B-1** (aplicado): `mi_rol()` sin la rama por email. `DRY_RUN` por defecto |
| `1B-10_admin_bypass_C_rollback.sql` | **C1** (restaura `mi_rol()`) y **C2** (devuelve las 2 cuentas a su rol previo). **No ejecutado** |
| `1B-11_admin_bypass_D_verificacion.sql` | Consultas de solo lectura V8.1–V8.7. Seguro de repetir; V8.1, V8.3–V8.5 requieren las tablas de A |

Orden de aplicación (seguido): A (`DRY_RUN` y `COMMIT`) → frontend → B-0 → esperar 5
min → B-1 `DRY_RUN` → B-1 `COMMIT`. Un paso cada vez, como `postgres`.

**Orden de rollback: C1 → frontend → C2.** C1 restaura `mi_rol()` y es seguro
primero (las cuentas ya son admin en la tabla). Después se restaura el `admin.html`
anterior (commit de retirada `5c535a9`): **antes revisar el diff y el estado de Git,
sin ejecutar un `git revert` automáticamente**; debe quedar desplegado y verificado.
C2 solo corresponde a una reversión completa, con el frontend anterior ya verificado
(el script no lo comprueba) y con `mi_rol()` ya con el bypass; nunca con el bypass
retirado. Para revertir solo la lógica basta C1.

Notas:

- **No reejecutables tal cual.** Tras B, A falla a propósito en el guard de identidad
  de `mi_rol()`; tras un rollback completo, A aborta por estado inconsistente.
- **Conservar** el esquema `_hardening_1b` y sus tablas `admin_bypass_*`; no hay
  limpieza prevista todavía.
- La verificación V8 coexiste con V6 (1B-bis); D4b sigue sin ejecutar.
- **Pendiente (no es de este bloque):** protección frente a la pérdida del último
  administrador y semántica de `activo=false` (ver `docs/DEUDA-TECNICA.md`).

## Qué es exactamente `extraer_esquema_real.sql`, y qué NO es

Es un **auditor de metadatos**, reproducible: se ejecuta contra Supabase y
devuelve la *forma* del esquema en ese momento (estructura, no datos).

**No es**, y no se debe tratar como, un volcado capaz de reconstruir el
esquema desde cero. No sustituye a un `pg_dump --schema-only` ni a la
exportación de esquema del propio panel de Supabase: esas herramientas
generan sentencias `CREATE TABLE`/`CREATE FUNCTION`/etc. ejecutables, con
todo el detalle de sintaxis y opciones. `extraer_esquema_real.sql` no genera
eso — genera una fotografía legible de los metadatos, pensada para auditar
y documentar, no para recrear el esquema en una base de datos nueva. Esta
distinción es importante y no debe difuminarse.

## Los resultados de la auditoría de octubre de 2026 (CSV/TXT A–I) no se versionan

Al ejecutar `extraer_esquema_real.sql` durante el Bloque 0, cada uno de sus
9 bloques (A–I) se exportó como un archivo CSV/TXT suelto, que sirvió para
documentar `docs/MODELO-DATOS.md`, `docs/DEUDA-TECNICA.md` y
`docs/SEGURIDAD.md`. Esos archivos fueron **salidas temporales de esa
auditoría concreta**, no artefactos del proyecto: no se incorporan al
repositorio. Si en el futuro hace falta una fotografía nueva del esquema,
se vuelve a ejecutar `extraer_esquema_real.sql` y se generan de nuevo.

## Los scripts SQL del desarrollo (fichaje, recepciones, calendario)

Los scripts que se fueron entregando y ejecutando a lo largo del desarrollo
(fichaje, recepciones, calendario) hoy viven sueltos, fuera del
repositorio. Incorporarlos aquí de forma ordenada (con su propio numerado,
`01_fichaje.sql`, `02_recepciones.sql`, `03_calendario.sql`...) queda
pendiente para un bloque posterior — no se ha hecho en el Bloque 0.

## Qué NO debe pasar nunca con estos archivos

Ni `extraer_esquema_real.sql`, ni ningún resultado que genere, ni ningún
`.sql` futuro que se añada aquí, deben contener **datos reales** — ni una
fila de `fichajes`, `clientes`, `personas_equipo`, `stock`, etc. Lo
ejecutado en el Bloque 0, confirmado, solo devolvió estructura (ver
`docs/SEGURIDAD.md`, auditoría pre-Git).
