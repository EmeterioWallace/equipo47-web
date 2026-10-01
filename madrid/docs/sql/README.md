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
