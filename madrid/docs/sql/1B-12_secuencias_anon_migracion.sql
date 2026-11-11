-- ============================================================
-- BLOQUE "SECUENCIAS ANON" · A — retirar SELECT, UPDATE y USAGE a anon en 4 secuencias
-- ============================================================
-- ESTADO: PREPARADO, NO APLICADO. No ejecutar sin aprobación explícita.
--
-- Contexto
--   Las 4 secuencias de public están concedidas, por el owner (postgres) y sin grant option,
--   a anon, authenticated y service_role con SELECT, UPDATE y USAGE (más las del propio owner).
--   anon no tiene privilegios de tabla desde 1B (D3) y ninguna de las 4 tablas recibe INSERT
--   directo desde el frontend: las altas pasan por funciones SECURITY DEFINER (owner postgres),
--   a las que anon ya no puede llamar (D4a). Por tanto anon no necesita nada sobre ellas.
--     public.fichajes_id_seq                -> fichajes.id                (IDENTITY ALWAYS, dependencia 'i')
--     public.solicitud_items_id_seq         -> solicitud_items.id         (serial/default, dependencia 'a')
--     public.solicitudes_correccion_id_seq  -> solicitudes_correccion.id  (IDENTITY ALWAYS, dependencia 'i')
--     public.solicitudes_id_seq             -> solicitudes.id             (serial/default, dependencia 'a')
--
-- Qué hace (UNA transacción)
--   1. Guardas de entorno y de identidad (ver abajo).
--   2. Crea (si no existen) en _hardening_1b: seq_control (marcadores) y seq_acl_snapshot
--      (ACL originales de las 4 secuencias: 48 filas con grantor y grant option, más el OID de
--      la secuencia y su relacl original en texto como evidencia), ambas con RLS y sin acceso
--      para PUBLIC/anon/authenticated. No toca ninguna otra instantánea de 1B/1B-bis/admin bypass.
--   3. REVOKE SELECT, UPDATE, USAGE ON SEQUENCE <las 4> FROM anon.
--   4. Aserciones: anon sin ningún privilegio directo ni efectivo; diferencia exacta con la
--      instantánea = 12 filas retiradas (todas de anon) y 0 añadidas; authenticated,
--      service_role y postgres idénticos; authenticator sin privilegios; sondas currval.
--      Las aserciones de ACL y de permisos efectivos son INDEPENDIENTES de las sondas: las
--      sondas son una comprobación adicional, no la única.
--   5. Marcador SEQ_ANON_aplicado (evita aplicaciones duplicadas).
--
-- Qué NO hace
--   * No toca authenticated, service_role ni postgres.
--   * No toca tablas, funciones, policies, search_path ni default privileges (los permisos por
--     defecto de OBJETOS FUTUROS son un problema separado: ver docs/SEGURIDAD.md).
--   * No ejecuta nextval/setval: las sondas usan currval, que comprueba el permiso ANTES de
--     mirar el valor, de modo que no consumen ni alteran ninguna secuencia.
--
-- Guardas (todas abortan sin cambiar nada)
--   * Rol postgres; D4a consta aplicado (_hardening_1b.d4_control).
--   * public contiene EXACTAMENTE esas 4 secuencias (si hubiera otra, no está auditada).
--   * Las 4: relkind 'S', owner postgres, ligadas a <tabla>.id con la dependencia esperada
--     ('i' + identity ALWAYS, o 'a' + sin identity).
--   * anon sin privilegios de ninguna tabla de public (premisa de seguridad del cambio).
--   * ACL de cada una: EXACTAMENTE {anon, authenticated, postgres, service_role} x
--     {SELECT, UPDATE, USAGE}, concedido por el owner, sin grant option, sin PUBLIC.
--   * authenticator sin privilegio efectivo sobre ninguna de las 4.
--   * Estado coherente: las 4 en estado previo (se ensaya/aplica). Si las 4 YA están en estado
--     final con el marcador, el script aborta con un error que empieza por "YA_APLICADO" y
--     NO ensaya ni cambia nada (no es un DRY_RUN: no se verá nunca el mensaje "DRY_RUN OK").
--     Estado parcial, final sin marcador, o instantánea preexistente (p. ej. tras un
--     rollback): aborta; resolverlo es una decisión manual.
--   * Los fallos en la propia preparación de una sonda (p. ej. no poder hacer SET ROLE) abortan
--     el script; nunca se interpretan como una denegación de acceso a la secuencia.
--
-- PRECONDICIONES Y LIMITACIONES (importante)
--   * La premisa "nadie legítimo usa estas secuencias como anon" se apoya en el código del
--     repositorio y en una búsqueda TEXTUAL (nextval/setval/currval/lastval/_id_seq) sobre los
--     cuerpos de las funciones de public. NO detecta: SQL dinámico construido por
--     concatenación, consumidores externos no versionados, ni funciones que reciban el nombre
--     de una secuencia como parámetro y no lo mencionen literalmente.
--   * Un permiso de PostgreSQL no equivale a una operación accesible desde PostgREST: las
--     secuencias no se exponen como recursos de la API. Este cambio es defensa en profundidad y
--     cierra la deriva si algún día anon recuperara permisos de tabla; no corrige una
--     explotación demostrada.
--   * serial: un INSERT directo de authenticated necesita USAGE en la secuencia (default
--     nextval). Este script no lo toca. Si en el futuro se recorta authenticated, hay que
--     tenerlo en cuenta.
--   * Dependencias de tipo 'a'/'i' NO son una garantía de que no existan otros usos; solo
--     describen a quién pertenece cada secuencia.
--
-- CÓMO EJECUTARLO (rol postgres, SQL Editor)
--   1. Primera vez con v_modo := 'DRY_RUN' (valor por defecto). Termina con un error deliberado
--      "DRY_RUN OK ..." y NO deja nada (ni siquiera las tablas de _hardening_1b si eran nuevas):
--      eso es el ÉXITO del ensayo.
--   2. Revisar los NOTICE. Cambiar v_modo a 'COMMIT' (única edición) y ejecutar de nuevo.
--   3. Verificar con 1B-14_secuencias_anon_verificacion.sql (ejecutando cada consulta V9.x POR
--      SEPARADO: el SQL Editor muestra solo el resultado de la última sentencia) y probar la
--      aplicación.
--   Reejecutar con el bloque ya aplicado NO sirve para verificar: aborta con "YA_APLICADO".
--   Para comprobar el estado usar 1B-14.
--   Resultado de un DRY_RUN correcto: ÚNICAMENTE el error "DRY_RUN OK ..." (y los NOTICE). Cualquier
--   otro error, incluido "YA_APLICADO", significa que NO se ha ensayado la migración.
--
-- Rollback: 1B-13_secuencias_anon_rollback.sql (restaura exactamente la instantánea).
-- Este archivo no contiene datos de negocio ni de personas.
-- ============================================================

begin;

create schema if not exists _hardening_1b;
revoke all on schema _hardening_1b from public, anon, authenticated;

create table if not exists _hardening_1b.seq_control (
  step text primary key,
  at   timestamptz not null default now(),
  note text);
create table if not exists _hardening_1b.seq_acl_snapshot (
  obj text not null, owner text not null, grantor text not null,
  grantee text not null, privilege text not null, grantable boolean not null,
  seq_oid oid not null,              -- OID de la secuencia al tomar la instantánea
  relacl_original text not null,     -- pg_class.relacl original (texto), evidencia adicional
  taken_at timestamptz not null default now());
alter table _hardening_1b.seq_control      enable row level security;
alter table _hardening_1b.seq_acl_snapshot enable row level security;
revoke all on _hardening_1b.seq_control, _hardening_1b.seq_acl_snapshot from public, anon, authenticated;

-- ACL actual (una fila por privilegio) de las 4 secuencias. Temporal: desaparece con la sesión.
create function pg_temp._seq_actual()
returns table (obj text, owner text, grantor text, grantee text, privilege text, grantable boolean)
language sql stable as $f$
  select 'public.' || c.relname::text, c.relowner::regrole::text, a.grantor::regrole::text,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
         a.privilege_type::text, a.is_grantable
    from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) a
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
     and c.relname::text = any (array['fichajes_id_seq', 'solicitud_items_id_seq',
                                      'solicitudes_correccion_id_seq', 'solicitudes_id_seq'])
$f$;

do $$
declare
  v_modo   text   := 'DRY_RUN';   -- 'DRY_RUN' (ensayo, revierte) | 'COMMIT' (aplica)
  seqs     text[] := array['public.fichajes_id_seq', 'public.solicitud_items_id_seq',
                           'public.solicitudes_correccion_id_seq', 'public.solicitudes_id_seq'];
  tabs     text[] := array['public.fichajes', 'public.solicitud_items',
                           'public.solicitudes_correccion', 'public.solicitudes'];
  deps     text[] := array['i', 'a', 'i', 'a'];
  privs    text[] := array['SELECT', 'UPDATE', 'USAGE'];
  v_exp_pre  text[];
  v_exp_post text[];
  v_acl    text[];
  v_ok     boolean;
  v_oid    oid;
  v_pre    int := 0;
  v_post   int := 0;
  i        int;
  s        text;
  p        text;
  n        int;
  v_res    text;
begin
  if v_modo not in ('DRY_RUN', 'COMMIT') then raise exception 'v_modo debe ser DRY_RUN o COMMIT'; end if;

  -- ── Guardas de entorno ───────────────────────────────────
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  if to_regclass('_hardening_1b.d4_control') is null
     or not exists (select 1 from _hardening_1b.d4_control where step = 'D4a_aplicado') then
    raise exception 'D4a no consta como aplicado (d4_control)'; end if;

  -- anon sin privilegios de tabla en public (premisa del cambio; núcleo 1B/D3 preservado).
  select count(*) into n from pg_class
   where relnamespace = 'public'::regnamespace and relkind = 'r'
     and has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN');
  if n <> 0 then raise exception 'anon aún tiene privilegios de tabla en % tablas: la premisa del cambio no se cumple', n; end if;

  -- ── Guardas de identidad ─────────────────────────────────
  select count(*) into n from pg_class where relnamespace = 'public'::regnamespace and relkind = 'S';
  if n <> 4 then raise exception 'Se esperaban exactamente 4 secuencias en public y hay %: la auditoría no está al día', n; end if;

  for i in 1 .. 4 loop
    s := seqs[i];
    v_oid := to_regclass(s)::oid;
    if v_oid is null then raise exception 'No existe la secuencia %', s; end if;
    if to_regclass(tabs[i]) is null then raise exception 'No existe la tabla %', tabs[i]; end if;
    select count(*) into n from pg_class where oid = v_oid and relkind = 'S' and relowner = 'postgres'::regrole;
    if n <> 1 then raise exception '% no es una secuencia con owner postgres', s; end if;

    select count(*) into n
      from pg_depend d
      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
     where d.classid = 'pg_class'::regclass and d.objid = v_oid
       and d.refclassid = 'pg_class'::regclass and d.refobjid = to_regclass(tabs[i])::oid
       and d.deptype::text = deps[i] and a.attname = 'id'
       and ((deps[i] = 'i' and a.attidentity = 'a') or (deps[i] = 'a' and a.attidentity not in ('a', 'd')));
    if n <> 1 then raise exception '% no está ligada a %.id con la dependencia esperada (%)', s, tabs[i], deps[i]; end if;

    -- authenticator no debe tener privilegio efectivo (la cadena de herencia no está alterada).
    if has_sequence_privilege('authenticator', v_oid, 'SELECT')
       or has_sequence_privilege('authenticator', v_oid, 'UPDATE')
       or has_sequence_privilege('authenticator', v_oid, 'USAGE') then
      raise exception 'authenticator tiene privilegio efectivo sobre %: no es el estado auditado', s; end if;
  end loop;

  -- ── Estado de ACL: previo (auditado) o final. Nada intermedio ──
  select array_agg(x order by x collate "C") into v_exp_pre
    from (select g.v || ':' || q.v as x
            from unnest(array['anon', 'authenticated', 'postgres', 'service_role']) as g(v),
                 unnest(privs) as q(v)) t;
  select array_agg(x order by x collate "C") into v_exp_post
    from (select g.v || ':' || q.v as x
            from unnest(array['authenticated', 'postgres', 'service_role']) as g(v),
                 unnest(privs) as q(v)) t;

  foreach s in array seqs loop
    select array_agg(x order by x collate "C"), bool_and(not grantable and grantor = owner)
      into v_acl, v_ok
      from (select a.grantee || ':' || a.privilege as x, a.grantable, a.grantor, a.owner
              from pg_temp._seq_actual() a where a.obj = s) t;
    if v_acl is null or v_ok is null then raise exception 'No se pudo leer la ACL de % (vacía o ilegible)', s; end if;
    if not v_ok then raise exception 'ACL con grant option o grantor distinto del owner en %', s; end if;
    if v_acl is not distinct from v_exp_pre then v_pre := v_pre + 1;
    elsif v_acl is not distinct from v_exp_post then v_post := v_post + 1;
    else raise exception 'ACL inesperada en % (incluye PUBLIC u otros roles?): %', s, v_acl;
    end if;
  end loop;

  if v_post = 4 then
    if exists (select 1 from _hardening_1b.seq_control where step = 'SEQ_ANON_aplicado') then
      -- Se aborta (no se retorna con éxito) para que este estado NUNCA pueda confundirse con un
      -- DRY_RUN que haya ensayado la migración. No se ha cambiado ni ensayado nada.
      raise exception 'YA_APLICADO: marcador SEQ_ANON_aplicado presente y las 4 secuencias ya en estado final. NO se ha ensayado ni cambiado nada (esto NO es un DRY_RUN). Para comprobar el estado usar 1B-14.';
    end if;
    raise exception 'Las 4 secuencias ya están en estado final pero no consta SEQ_ANON_aplicado: revisar a mano (¿cambio manual previo?)';
  end if;
  if v_pre <> 4 then raise exception 'Estado parcial: % en estado previo, % en estado final', v_pre, v_post; end if;
  if exists (select 1 from _hardening_1b.seq_control where step in ('SEQ_ANON_aplicado', 'SEQ_ANON_revertido'))
     or exists (select 1 from _hardening_1b.seq_acl_snapshot) then
    raise exception 'Hay marcadores o instantánea de una ejecución anterior (¿tras un rollback?): resolver a mano antes de reaplicar';
  end if;

  -- Efectivo previo: anon tiene los 3 privilegios en las 4 (si no, el estado no es el auditado).
  foreach s in array seqs loop
    foreach p in array privs loop
      if not has_sequence_privilege('anon', to_regclass(s)::oid, p) then
        raise exception 'anon no tiene % sobre % (ACL previa inesperada)', p, s; end if;
    end loop;
  end loop;

  -- ── Instantánea ──────────────────────────────────────────
  insert into _hardening_1b.seq_acl_snapshot (obj, owner, grantor, grantee, privilege, grantable, seq_oid, relacl_original)
  select a.obj, a.owner, a.grantor, a.grantee, a.privilege, a.grantable, c.oid, c.relacl::text
    from pg_temp._seq_actual() a
    join pg_class c on c.oid = to_regclass(a.obj)::oid
   where c.relacl is not null;     -- las 4 tienen ACL explícita (anon figura en ella)
  select count(*) into n from _hardening_1b.seq_acl_snapshot;
  if n <> 48 then raise exception 'La instantánea debía tener 4 x 4 x 3 = 48 filas y tiene % (¿alguna sin relacl explícito?)', n; end if;
  select count(distinct obj) into n from _hardening_1b.seq_acl_snapshot;
  if n <> 4 then raise exception 'La instantánea debía cubrir 4 secuencias y cubre %', n; end if;
  -- La instantánea es exactamente el conjunto esperado (roles, privilegios, grantor y grant option).
  select count(*) into n from (
      select o.v, 'postgres'::text, 'postgres'::text, g.v, q.v, false
        from unnest(seqs) as o(v),
             unnest(array['anon', 'authenticated', 'postgres', 'service_role']) as g(v),
             unnest(privs) as q(v)
      except select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot) x;
  if n <> 0 then raise exception 'La instantánea no contiene el conjunto esperado (faltan % filas)', n; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select o.v, 'postgres'::text, 'postgres'::text, g.v, q.v, false
        from unnest(seqs) as o(v),
             unnest(array['anon', 'authenticated', 'postgres', 'service_role']) as g(v),
             unnest(privs) as q(v)) x;
  if n <> 0 then raise exception 'La instantánea contiene % filas fuera del conjunto esperado', n; end if;

  -- ── Cambio ───────────────────────────────────────────────
  foreach s in array seqs loop
    execute format('revoke select, update, usage on sequence %s from anon', s);
  end loop;

  -- ── Aserciones posteriores (si falla alguna, se revierte todo) ──
  foreach s in array seqs loop
    foreach p in array privs loop
      if has_sequence_privilege('anon', to_regclass(s)::oid, p) then
        raise exception 'anon conserva % sobre % (directo o heredado)', p, s; end if;
      if not has_sequence_privilege('authenticated', to_regclass(s)::oid, p)
         or not has_sequence_privilege('service_role', to_regclass(s)::oid, p)
         or not has_sequence_privilege('postgres',     to_regclass(s)::oid, p) then
        raise exception 'authenticated, service_role o postgres han perdido % sobre %', p, s; end if;
    end loop;
    if has_sequence_privilege('authenticator', to_regclass(s)::oid, 'SELECT')
       or has_sequence_privilege('authenticator', to_regclass(s)::oid, 'UPDATE')
       or has_sequence_privilege('authenticator', to_regclass(s)::oid, 'USAGE') then
      raise exception 'authenticator ha ganado privilegios sobre %', s; end if;

    select array_agg(x order by x collate "C"), bool_and(not grantable and grantor = owner)
      into v_acl, v_ok
      from (select a.grantee || ':' || a.privilege as x, a.grantable, a.grantor, a.owner
              from pg_temp._seq_actual() a where a.obj = s) t;
    if not coalesce(v_ok, false) or v_acl is distinct from v_exp_post then
      raise exception 'ACL final inesperada en %: %', s, v_acl; end if;
  end loop;

  -- Diferencia exacta con la instantánea: 12 retiradas (todas de anon), 0 añadidas.
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()) x;
  if n <> 12 then raise exception 'Se esperaban 12 privilegios retirados y hay %', n; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()) x
   where grantee <> 'anon';
  if n <> 0 then raise exception 'Se han retirado privilegios de roles distintos de anon (% filas)', n; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()
      except select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot) x;
  if n <> 0 then raise exception 'Se han añadido % privilegios', n; end if;

  -- anon sigue sin privilegios de tabla.
  select count(*) into n from pg_class
   where relnamespace = 'public'::regnamespace and relkind = 'r'
     and has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN');
  if n <> 0 then raise exception 'anon tiene privilegios de tabla tras el cambio (% tablas)', n; end if;

  -- ── Sondas con rol simulado (currval: comprueba el permiso antes que el valor; no consume nada) ──
  -- anon: debe recibir "permission denied" (42501). Si currval responde otra cosa, anon aún tiene permiso.
  -- Diseño de las sondas (son una comprobación ADICIONAL; la prueba principal son las ACL y los
  -- permisos efectivos de arriba):
  --   1. El cambio de rol se hace FUERA del bloque que captura excepciones y se confirma con
  --      current_user: si SET ROLE falla, el script aborta; nunca se toma por una denegación.
  --   2. Se comprueba antes que el rol puede ejecutar currval(): un 42501 por falta de EXECUTE
  --      sobre la función no puede hacerse pasar por una denegación sobre la secuencia.
  --   3. Solo se interpreta el SQLSTATE de la llamada a currval (42501 = denegado; 55000 = tiene
  --      permiso pero la sesión no tiene valor). Cualquier otro error se propaga y aborta.
  --      No se depende de textos de mensaje.
  if not has_function_privilege('anon', 'pg_catalog.currval(regclass)'::regprocedure, 'EXECUTE')
     or not has_function_privilege('authenticated', 'pg_catalog.currval(regclass)'::regprocedure, 'EXECUTE') then
    raise exception 'anon o authenticated no pueden ejecutar currval(): las sondas no serían concluyentes';
  end if;
  foreach s in array seqs loop
    v_oid := to_regclass(s)::oid;
    set local role anon;
    if current_user <> 'anon' then raise exception 'No se pudo cambiar al rol anon (current_user = %)', current_user; end if;
    begin
      perform currval(v_oid::regclass);
      v_res := 'valor';
    exception
      when insufficient_privilege then v_res := 'denegado';
      when object_not_in_prerequisite_state then v_res := 'permitido';
    end;
    reset role;
    if current_user <> 'postgres' then raise exception 'No se pudo restaurar el rol postgres tras la sonda (current_user = %)', current_user; end if;
    if v_res is distinct from 'denegado' then
      raise exception 'anon no recibió denegación de currval sobre % tras el cambio (resultado: %)', s, v_res; end if;
  end loop;
  -- authenticated: NO debe recibir 42501 (sin valor en la sesión responde 55000, que significa "tiene permiso").
  foreach s in array seqs loop
    v_oid := to_regclass(s)::oid;
    set local role authenticated;
    if current_user <> 'authenticated' then raise exception 'No se pudo cambiar al rol authenticated (current_user = %)', current_user; end if;
    begin
      perform currval(v_oid::regclass);
      v_res := 'valor';
    exception
      when insufficient_privilege then v_res := 'denegado';
      when object_not_in_prerequisite_state then v_res := 'permitido';
    end;
    reset role;
    if current_user <> 'postgres' then raise exception 'No se pudo restaurar el rol postgres tras la sonda (current_user = %)', current_user; end if;
    if v_res is distinct from 'valor' and v_res is distinct from 'permitido' then
      raise exception 'authenticated ha perdido el permiso sobre % (resultado de la sonda: %)', s, v_res; end if;
  end loop;

  insert into _hardening_1b.seq_control (step, note)
  values ('SEQ_ANON_aplicado', 'REVOKE SELECT, UPDATE, USAGE FROM anon en las 4 secuencias de public');
  raise notice 'SEQ_ANON: anon sin privilegios en las 4 secuencias (12 retirados, 0 añadidos); authenticated, service_role y postgres intactos.';

  if v_modo = 'DRY_RUN' then
    raise exception 'DRY_RUN OK: todas las guardas y aserciones pasaron; transacción REVERTIDA (esto es el éxito del ensayo). Cambiar v_modo a COMMIT para aplicar.';
  end if;
end $$;

drop function pg_temp._seq_actual();
commit;
