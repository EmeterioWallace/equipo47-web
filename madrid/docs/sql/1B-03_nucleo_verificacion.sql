-- ============================================================
-- BLOQUE 1B (NÚCLEO) — VERIFICACIÓN (SOLO LECTURA)
-- ============================================================
-- No modifica nada. Ejecutar la sección correspondiente tras cada paso de
-- 1B-01_nucleo_migracion.sql. Los resultados esperados van en comentarios.
-- Requiere el PASO 0 (esquema _hardening_1b) para las comparaciones.
-- ============================================================


-- ── V1 (tras PASO 1 / D1): search_path de las funciones SECURITY DEFINER ──
select p.proname, p.proconfig
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.prosecdef
   and p.proname in ('mi_rol','mi_nivel','es_admin','es_min_gestor','es_min_responsable','es_min_operario',
     'fichaje_mi_persona','fichar','solicitar_correccion_fichaje','aprobar_correccion_fichaje',
     'rechazar_correccion_fichaje')
 order by 1;                          -- 11 filas, todas {"search_path=public, pg_temp"}

select count(*) as sin_search_path    -- esperado: 0
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.prosecdef
   and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');


-- ── V2 (tras PASO 2 / D2 y PASO 3 / D2b): policies ──
select count(*)                                  as total_policies,   -- 102
       count(*) filter (where roles = '{public}') as con_public       -- 0 (tras D2)
  from pg_policies where schemaname = 'public';

-- Diferencias frente a la instantánea.
--   Tras D2:  8 filas; solo cambia el rol (cambia_using = false en todas).
--   Tras D2b: las mismas 8; solo recepcion_lineas_select con cambia_using = true.
--   cambia_with_check debe ser false en todas.
select s.tablename, s.policyname, s.roles as antes, p.roles as ahora,
       s.qual       is distinct from p.qual       as cambia_using,
       s.with_check is distinct from p.with_check as cambia_with_check
  from _hardening_1b.policy_snapshot s
  full join (select * from pg_policies where schemaname = 'public') p
    on p.tablename = s.tablename and p.policyname = s.policyname
 where s.roles is distinct from p.roles::text[]
    or s.qual is distinct from p.qual
    or s.with_check is distinct from p.with_check
    or s.policyname is null or p.policyname is null
 order by 1, 2;

-- Policies de recepciones (padre) y recepcion_lineas (hija) lado a lado.
select tablename, policyname, cmd, roles, qual
  from pg_policies
 where schemaname = 'public' and tablename in ('recepciones', 'recepcion_lineas')
 order by 1, 2;


-- ── V3 (tras PASO 4 / D3): privilegios efectivos de tabla ──
--   anon_con_algun_priv  : 0   anon no conserva nada (comprueba los 8 privilegios de
--                              tabla de PostgreSQL 17+, incluido MAINTAIN).
--   auth_con_peligrosos  : 0   authenticated sin TRUNCATE / TRIGGER / REFERENCES.
--   auth_con_dml         : 29  NO es el modelo final de mínimo privilegio: es el estado
--                              PREVIO que este bloque quiere preservar (detecta una
--                              regresión accidental). El recorte fino de SELECT/INSERT/
--                              UPDATE/DELETE de authenticated queda para una fase posterior.
--   service_role_intacto : 29  service_role no se toca.
select count(*) filter (where has_table_privilege('anon', c.oid,
         'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')) as anon_con_algun_priv,
       count(*) filter (where has_table_privilege('authenticated', c.oid,
         'TRUNCATE,TRIGGER,REFERENCES'))                                as auth_con_peligrosos,
       count(*) filter (where has_table_privilege('authenticated', c.oid, 'SELECT')
                          and has_table_privilege('authenticated', c.oid, 'INSERT')
                          and has_table_privilege('authenticated', c.oid, 'UPDATE')
                          and has_table_privilege('authenticated', c.oid, 'DELETE')) as auth_con_dml,
       count(*) filter (where has_table_privilege('service_role', c.oid,
         'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'))   as service_role_intacto
  from pg_class c
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'r';


-- ── V4 (tras PASO 4 / D3): diferencia exacta de ACL de tablas frente a la instantánea ──
-- Esperado: filas 'retirado' = anon × 8 privilegios × 29 tablas
--             (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER y MAINTAIN)
--           + authenticated × (TRUNCATE, TRIGGER, REFERENCES) × 29 tablas
--           = 232 + 87 = 319 en total; ninguna fila 'añadido'.
-- MAINTAIN es un privilegio de PostgreSQL 17+ (VACUUM, ANALYZE, REINDEX, CLUSTER, REFRESH
-- MATERIALIZED VIEW, LOCK TABLE). La primera versión de este comentario esperaba 290
-- porque solo contaba los 7 privilegios clásicos; el resultado real en producción fue 319
-- y es coherente con REVOKE ALL ... FROM anon.
with actual as (
  select c.oid::regclass::text as obj,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as grantee,
         a.privilege_type as priv, a.is_grantable as g
    from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p','v','m','f')),
snap as (
  select obj, grantee, privilege as priv, grantable as g
    from _hardening_1b.acl_snapshot where kind = 'table')
select 'retirado' as cambio, grantee, priv, count(*) as filas
  from (select * from snap except select * from actual) x
 group by grantee, priv
union all
select 'añadido', grantee, priv, count(*)
  from (select * from actual except select * from snap) y
 group by grantee, priv
 order by 1, 2, 3;


-- ── V5 (al terminar): las ACL de funciones NO han cambiado (D4 / EXECUTE excluido) ──
-- Esperado: retirado = 0 y añadido = 0.
-- VÁLIDO SOLO HASTA QUE SE APLIQUE D4 (1B-bis): tras D4a/D4b las ACL de las 19 cambian a
-- propósito y esta consulta dejará de dar 0. Entonces usar V6 de 1B-07_d4_verificacion.sql.
with actual as (
  select p.oid::regprocedure::text as obj,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as grantee,
         a.privilege_type as priv, a.is_grantable as g
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')),
snap as (
  select obj, grantee, privilege as priv, grantable as g
    from _hardening_1b.acl_snapshot where kind = 'function')
select 'retirado' as cambio, count(*) as filas
  from (select * from snap except select * from actual) x
union all
select 'añadido', count(*)
  from (select * from actual except select * from snap) y;
