-- ============================================================
-- BLOQUE 1B-bis · D4 — VERIFICACIÓN (solo lectura, repetible)
-- ============================================================
-- No modifica nada. Ejecutar tras D4a y de nuevo tras D4b (y antes de D4a para
-- ver el estado de partida). Requiere _hardening_1b.acl_snapshot_d4 (D4-0).
--
-- Resultado esperado según la fase:
--                                 antes   tras D4a   tras D4b
--   PUBLIC en la ACL (de 19)        19         0          0
--   anon con EXECUTE (de 19)        19         0          0
--   authenticated con EXECUTE       19        19         15
--   service_role con EXECUTE        19        19         19
--   postgres con EXECUTE            19        19         19
--   V6.2 retirado vs snapshot D4     0        38         42   (19 PUBLIC + 19 anon [+ 4 authenticated])
--   V6.2 añadido                     0         0          0
-- ============================================================

-- ── V6.1: matriz de EXECUTE por función ──
-- Esperado tras D4a: PUBLIC=false, anon=false, authenticated=true, service_role=true, postgres=true.
-- Tras D4b: authenticated=false SOLO en fichaje_mi_persona, mi_cliente_id, mi_nivel y mi_rol.
with f(sig, tipo) as (values
  ('public.aprobar_correccion_fichaje(bigint,timestamptz,text)',                  'RPC fichaje'),
  ('public.cancelar_solicitud(bigint)',                                           'RPC portal'),
  ('public.comprobar_disponibilidad(timestamp,timestamp,jsonb,bigint)',           'RPC portal'),
  ('public.crear_solicitud(text,timestamp,timestamp,text,jsonb)',                 'RPC portal'),
  ('public.editar_solicitud(bigint,text,timestamp,timestamp,text,jsonb)',         'RPC portal'),
  ('public.es_admin()',                                                           'RLS'),
  ('public.es_cliente()',                                                         'RLS'),
  ('public.es_min_gestor()',                                                      'RLS'),
  ('public.es_min_operario()',                                                    'RLS'),
  ('public.es_min_responsable()',                                                 'RLS'),
  ('public.fichaje_mi_persona()',                                                 'helper interno'),
  ('public.fichar(text,text)',                                                    'RPC fichaje'),
  ('public.mi_catalogo()',                                                        'RPC portal'),
  ('public.mi_cliente_id()',                                                      'helper interno'),
  ('public.mi_nivel()',                                                           'helper interno'),
  ('public.mi_rol()',                                                             'helper interno'),
  ('public.mis_solicitudes()',                                                    'RPC portal'),
  ('public.rechazar_correccion_fichaje(bigint,text)',                             'RPC fichaje'),
  ('public.solicitar_correccion_fichaje(text,timestamptz,text,text,text,bigint)', 'RPC fichaje'))
select f.sig, f.tipo,
       exists (select 1 from pg_proc p, lateral aclexplode(p.proacl) a
                where p.oid = to_regprocedure(f.sig)::oid and a.grantee = 0) as public_en_acl,
       has_function_privilege('anon',          to_regprocedure(f.sig)::oid, 'EXECUTE') as anon,
       has_function_privilege('authenticated', to_regprocedure(f.sig)::oid, 'EXECUTE') as authenticated,
       has_function_privilege('service_role',  to_regprocedure(f.sig)::oid, 'EXECUTE') as service_role,
       has_function_privilege('postgres',      to_regprocedure(f.sig)::oid, 'EXECUTE') as postgres
  from f order by f.tipo, f.sig;

-- ── V6.2: diferencia exacta frente a la instantánea D4 ──
-- Esperado: ver tabla de cabecera. 'añadido' debe ser siempre 0 filas.
with actual as (
  select p.oid::regprocedure::text as obj,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as grantee,
         a.privilege_type as priv, a.is_grantable as g
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.oid in (select to_regprocedure(s.obj)::oid from (select distinct obj from _hardening_1b.acl_snapshot_d4) s)),
snap as (
  select obj, grantee, privilege as priv, grantable as g from _hardening_1b.acl_snapshot_d4)
select 'retirado' as cambio, grantee, priv, count(*) as filas
  from (select * from snap except select * from actual) x group by grantee, priv
union all
select 'añadido', grantee, priv, count(*)
  from (select * from actual except select * from snap) y group by grantee, priv
 order by 1, 2, 3;

-- ── V6.3: ninguna OTRA función de public ha cambiado de ACL (frente al núcleo 1B) ──
-- Esperado: 0 filas (las 19 se excluyen porque cambian a propósito).
with actual as (
  select p.oid::regprocedure::text as obj,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as grantee,
         a.privilege_type as priv, a.is_grantable as g, p.oid as poid
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')),
snap as (
  select obj, grantee, privilege as priv, grantable as g
    from _hardening_1b.acl_snapshot where kind = 'function'),
otras as (select obj from actual union select obj from snap
          except select s.obj from (select distinct obj from _hardening_1b.acl_snapshot_d4) s)
select 'retirado' as cambio, obj, grantee, priv
  from (select * from snap except select obj, grantee, priv, g from actual) x
 where obj in (select obj from otras)
union all
select 'añadido', obj, grantee, priv
  from (select obj, grantee, priv, g from actual except select * from snap) y
 where obj in (select obj from otras);

-- ── V6.4: EXECUTE efectivo de roles internos sobre las 19 (equivalente a M3d, ya sin PUBLIC) ──
-- Esperado tras D4a: anon 0/19; authenticated 19/19 (15/19 tras D4b); service_role 19/19;
-- authenticator, dashboard_user, pgbouncer, supabase_auth_admin, supabase_etl_admin,
-- supabase_privileged_role y supabase_storage_admin 0/19 (ya era 0/19 excluyendo PUBLIC).
select r.rolname,
       count(*) filter (where has_function_privilege(r.oid, p.oid, 'EXECUTE')) as con_execute,
       count(*) as de
  from pg_roles r
  join pg_proc p on p.oid in (select to_regprocedure(s.obj)::oid
                                from (select distinct obj from _hardening_1b.acl_snapshot_d4) s)
 where r.rolname in ('anon','authenticated','service_role','postgres','authenticator',
                     'dashboard_user','pgbouncer','supabase_auth_admin','supabase_etl_admin',
                     'supabase_privileged_role','supabase_storage_admin')
 group by r.rolname order by r.rolname;

-- ── V6.5: deriva futura — funciones de public que anon o PUBLIC pueden ejecutar ──
-- Esperado tras D4a: ninguna de las 19. Si aparece otra (p. ej. una función nueva creada con
-- los default privileges de Supabase, que conceden EXECUTE a anon), decidir caso a caso.
select p.oid::regprocedure as funcion, p.prosecdef as security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
   and has_function_privilege('anon', p.oid, 'EXECUTE')
 order by 1;

-- ── V6.6: marcadores de control ──
-- Esperado: D4a_aplicado tras D4a; D4a_verificado tras el PASO D4b-0; D4b_aplicado tras D4b-1.
select step, at, note from _hardening_1b.d4_control order by at;


-- ============================================================
-- PRUEBAS FUNCIONALES MANUALES (no son SQL; hacerlas tras cada paso)
-- ============================================================
-- Tras D4a:
--   1. Petición con SOLO la clave anon, sin sesión:
--        POST {SUPABASE_URL}/rest/v1/rpc/mi_catalogo   (cabeceras apikey + Authorization: Bearer <anon>)
--      Esperado: 401/403 con código 42501 (permission denied for function mi_catalogo).
--      Repetir con /rpc/es_admin y /rpc/fichar.
--   2. admin.html con un usuario de cada nivel (operario, responsable, gestor, admin):
--      login, dashboard, lectura de inventario, una escritura permitida y una prohibida.
--   3. Fichajes: fichar, solicitar corrección y (gestor+) aprobar y rechazar.
--   4. portal.html con una cuenta de cliente: catálogo, comprobar disponibilidad, crear,
--      editar y cancelar una solicitud, y listar "mis solicitudes".
-- Tras D4b: repetir 2, 3 y 4 completos. Cualquier error "permission denied for function"
--   en el navegador => ejecutar R4b de inmediato (1B-06).
-- ============================================================
