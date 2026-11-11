-- ============================================================
-- BLOQUE "SECUENCIAS ANON" · C — VERIFICACIÓN (SOLO LECTURA)
-- ============================================================
-- CÓMO EJECUTARLO: las consultas V9.1 a V9.8 se ejecutan UNA A UNA en el SQL Editor de Supabase
-- (seleccionar el texto de una sola consulta y ejecutar). Si se pega el archivo entero, el editor
-- puede mostrar solo el resultado de la ÚLTIMA sentencia y el resto de resultados se pierden sin
-- aviso. Si V9.4 o V9.5 dan error "relation ... does not exist", 1B-12 no está aplicado (o se
-- ensayó solo en DRY_RUN): es esperado.
--
-- Seguro de repetir en cualquier momento. Ninguna consulta modifica nada ni devuelve datos de
-- negocio ni de personas: solo nombres de roles y objetos, privilegios y contadores.
-- V9.4 y V9.5 (diferencia y marcadores) requieren las tablas de 1B-12; antes de aplicarlo darán
-- error. El resto no depende de ellas.
--
-- Esperado según la fase:
--                                       antes de 1B-12   tras 1B-12   tras 1B-13
--   anon: privilegios (de 12 posibles)         12             0            12
--   authenticated / service_role / postgres    12 c/u       12 c/u        12 c/u
--   authenticator                               0             0             0
--   Filas de ACL en las 4 secuencias           48            36            48
-- ============================================================

-- V9.1 Inventario: public debe tener exactamente 4 secuencias, todas del owner postgres,
--      y cada una ligada a <tabla>.id (tipo de dependencia y tipo de identity).
--      Esperado: 4 filas; dependencia i/a/i/a en el orden alfabético de abajo.
select c.relname as secuencia, pg_get_userbyid(c.relowner) as owner,
       (select d.deptype::text || ' -> ' || d.refobjid::regclass::text || '.' || a.attname
               || case a.attidentity when 'a' then ' (identity ALWAYS)' when 'd' then ' (identity BY DEFAULT)' else '' end
          from pg_depend d
          join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
         where d.classid = 'pg_class'::regclass and d.objid = c.oid
           and d.refclassid = 'pg_class'::regclass and d.deptype in ('a', 'i')) as ligada_a
  from pg_class c
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
 order by 1;

-- V9.2 ACL por secuencia y rol (con grantor y grant option).
--      Esperado tras 1B-12: ninguna fila de anon ni de PUBLIC; authenticated, postgres y
--      service_role con SELECT, UPDATE y USAGE, grantor postgres, grantable = false.
select c.relname as secuencia,
       case x.grantee when 0 then 'PUBLIC' else x.grantee::regrole::text end as grantee,
       x.privilege_type, x.grantor::regrole::text as grantor, x.is_grantable
  from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) x
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
 order by 1, 2, 3;

-- V9.3 Privilegios EFECTIVOS (incluye herencia y PUBLIC) por rol y secuencia.
--      Esperado tras 1B-12: anon false/false/false; authenticated, service_role y postgres
--      true/true/true; authenticator false/false/false.
select c.relname as secuencia, r.rolname,
       has_sequence_privilege(r.oid, c.oid, 'USAGE')  as usage,
       has_sequence_privilege(r.oid, c.oid, 'SELECT') as sel,
       has_sequence_privilege(r.oid, c.oid, 'UPDATE') as upd
  from pg_class c, pg_roles r
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
   and r.rolname in ('anon', 'authenticated', 'service_role', 'postgres', 'authenticator')
 order by 1, 2;

-- V9.4 Diferencia con la instantánea de 1B-12.
--      Esperado tras 1B-12: 12 'retirado' (todos grantee = anon) y 0 'añadido'.
--      Esperado tras 1B-13: 0 y 0.
with actual as (
  select 'public.' || c.relname::text as obj, c.relowner::regrole::text as owner,
         x.grantor::regrole::text as grantor,
         case x.grantee when 0 then 'PUBLIC' else x.grantee::regrole::text end as grantee,
         x.privilege_type::text as privilege, x.is_grantable as grantable
    from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) x
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'),
snap as (
  select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot)
select 'retirado' as sentido, grantee, count(*) as filas
  from (select * from snap except select * from actual) y group by grantee
union all
select 'añadido', grantee, count(*)
  from (select * from actual except select * from snap) z group by grantee
order by 1, 2;

-- V9.5 Marcadores de control del bloque.
--      Esperado tras 1B-12: SEQ_ANON_aplicado. Tras 1B-13: SEQ_ANON_revertido.
select step, at, note from _hardening_1b.seq_control order by at;

-- V9.6 Deriva futura (informativo): secuencias de public accesibles para anon o PUBLIC.
--      Esperado: 0 filas. Si aparece alguna (p. ej. una secuencia nueva creada con los default
--      privileges de la plataforma), NO es un fallo de 1B-12: pertenece al problema separado
--      de los permisos por defecto de objetos futuros.
select c.relname as secuencia,
       case x.grantee when 0 then 'PUBLIC' else x.grantee::regrole::text end as grantee,
       x.privilege_type
  from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) x
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
   and (x.grantee = 0 or x.grantee = 'anon'::regrole)
 order by 1, 2, 3;

-- V9.7 Premisa del cambio: anon sin privilegios sobre ninguna tabla de public. Esperado: 0.
select count(*) as tablas_con_privilegios_de_anon
  from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r'
   and has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN');

-- V9.8 D4a intacto: ninguna función SECURITY DEFINER de public ejecutable por PUBLIC ni anon. Esperado: 0.
select count(*) as sin_public_anon
  from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
 where p.pronamespace = 'public'::regnamespace and p.prosecdef
   and (a.grantee = 0 or a.grantee = 'anon'::regrole);

-- ============================================================
-- PRUEBAS MANUALES posteriores a 1B-12 (con usuario autenticado)
-- ============================================================
--  * Login, dashboard y lectura de solicitudes y de fichajes (select sobre las 4 tablas).
--  * Portal de clientes: login y carga del catálogo/solicitudes.
--  * NO crear fichajes ni solicitudes solo para probar el cambio: son escrituras reales (un
--    fichaje no se puede borrar). Las altas pasan por funciones SECURITY DEFINER del owner y
--    no dependen de los permisos de anon. Si se quiere una prueba de alta real, una solicitud
--    del portal puede cancelarse después.
--  * Una llamada anónima a /rest/v1/rpc/nextval daría 404 antes y después del cambio (las
--    secuencias no se exponen): no sirve para demostrar el efecto del REVOKE.
