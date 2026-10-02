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
  **1B-bis**), recorte fino de DML de `authenticated`, emails hardcodeados de
  `mi_rol()`, `FORCE RLS`, *default privileges* y secuencias. Las ACL de
  funciones se guardan en la instantánea solo como evidencia para 1B-bis.
- **No contienen datos reales** (solo estructura y privilegios), igual que el
  resto de este directorio.

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
