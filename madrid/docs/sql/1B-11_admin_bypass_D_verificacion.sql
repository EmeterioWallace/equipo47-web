-- ============================================================
-- BLOQUE "ADMIN BYPASS" · D — VERIFICACIÓN (SOLO LECTURA)
-- ============================================================
-- Seguro de repetir en cualquier momento. Ninguna consulta modifica nada ni devuelve
-- datos personales: solo contadores, booleanos y nombres de funciones.
-- V8.1, V8.3, V8.4 y V8.5 usan las tablas admin_bypass_* creadas por el script A (V8.1 para
-- la identidad de los 2 admins, V8.3-V8.4 el respaldo de mi_rol(), V8.5 la tabla de control):
-- antes de A no existen y esas consultas darán error. V8.2, V8.6 y V8.7 no dependen de ellas.
-- ============================================================

-- V8.1 Estado de los datos: los 2 admins son exactamente las 2 cuentas respaldadas (sin emails).
--      Esperado tras A: 2 / 2 / 0 / 2 / 2 / true
select t.*,
       (t.admins_total = 2 and t.cuentas_respaldadas = 2 and t.respaldadas_admin_activas = 2)
         as admins_son_exactamente_las_respaldadas
  from (select (select count(*) from public.personas_equipo where rol = 'admin')                       as admins_total,
               (select count(*) from public.personas_equipo where rol = 'admin' and activo is true)    as admins_activos,
               (select count(*) from public.personas_equipo where rol = 'admin' and activo is not true) as admins_inactivos,
               (select count(*) from _hardening_1b.admin_bypass_personas_backup)                       as cuentas_respaldadas,
               (select count(*) from public.personas_equipo p
                  join _hardening_1b.admin_bypass_personas_backup k on k.email = lower(p.email)
                 where p.rol = 'admin' and p.activo is true)                                           as respaldadas_admin_activas) t;

-- V8.2 mi_rol(): propiedades y presencia del bypass en el cuerpo.
--      Esperado tras B: contiene_email = false, contiene_equipo47 = false, secdef = true,
--      owner = postgres, config = {search_path=public, pg_temp}.
select p.prosecdef as secdef,
       p.proowner::regrole::text as owner,
       p.proconfig as config,
       p.provolatile as volatilidad,
       p.proacl as acl,
       (lower(p.prosrc) ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}') as contiene_email,
       (lower(p.prosrc) like '%equipo47%')                          as contiene_equipo47,
       md5(p.prosrc) as md5_cuerpo
  from pg_proc p where p.oid = 'public.mi_rol()'::regprocedure;

-- V8.3 mi_rol() frente al respaldo: md5 distinto tras B (cuerpo cambiado), igual antes de B / tras C1.
select (md5(p.prosrc) = b.prosrc_md5) as cuerpo_igual_al_respaldo,
       b.at as respaldo_en
  from pg_proc p, _hardening_1b.admin_bypass_mi_rol_backup b
 where p.oid = 'public.mi_rol()'::regprocedure and b.id = 1;

-- V8.4 Funciones dependientes sin cambios (esperado: 5 filas, todas true).
select p.proname, (md5(p.prosrc) = (b.dependientes ->> p.proname)) as sin_cambios
  from pg_proc p, _hardening_1b.admin_bypass_mi_rol_backup b
 where p.pronamespace = 'public'::regnamespace and p.pronargs = 0 and b.id = 1
   and p.proname in ('mi_nivel','es_admin','es_min_gestor','es_min_responsable','es_min_operario')
 order by p.proname;

-- V8.5 Marcadores de control del bloque.
select step, at, note from _hardening_1b.admin_bypass_control order by at;

-- V8.6 ACL y D4a/D4b intactos. Esperado: sin_public_anon = 0; authenticated conserva EXECUTE
--      en mi_rol() mientras D4b siga NO ejecutado.
select (select count(*)
          from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
         where p.pronamespace = 'public'::regnamespace and p.prosecdef
           and (a.grantee = 0 or a.grantee = 'anon'::regrole))            as sin_public_anon,
       has_function_privilege('authenticated', 'public.mi_rol()'::regprocedure, 'EXECUTE') as authenticated_ejecuta_mi_rol,
       (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and prosecdef) as secdef_public;

-- V8.7 Emails literales en funciones, policies y vistas del esquema public (solo nombres/contadores;
--      mismo alcance que la consulta ya ejecutada en producción).
--      Esperado tras B: V8.7a sin filas; V8.7b con 0 y 0. Cualquier fila = otro hardcode oculto.
select 'public.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as funcion
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and lower(p.prosrc) ~ '[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+'
 order by 1;
select (select count(*) from pg_policies
         where schemaname = 'public'
           and lower(coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ '[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+') as policies_con_email,
       (select count(*) from pg_views
         where schemaname = 'public'
           and lower(definition) ~ '[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+') as vistas_con_email,
       (select count(*) from pg_matviews
         where schemaname = 'public'
           and lower(definition) ~ '[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+') as matviews_con_email;

-- ------------------------------------------------------------
-- PRUEBAS MANUALES tras B (con sesión real; no alteran a nadie)
--   1. Cada una de las 2 cuentas: iniciar sesión en madrid/admin.html y ver el menú
--      completo (Equipo, Importar, Exportar, Configuración).
--   2. Un usuario real de otro rol (p. ej. responsable): su menú y capacidades no cambian.
--   3. Una cuenta sin fila en personas_equipo, si existe una de prueba: nivel mínimo, como antes.
--   4. Desde Equipo, un admin puede cambiar el rol de otra persona.
-- ------------------------------------------------------------
