-- ============================================================
-- BLOQUE 1B-bis · D4a — EXECUTE: retirar PUBLIC y anon de las 19 SECURITY DEFINER
-- ============================================================
-- ESTADO: APLICADO el 2026-10-02 y verificado en producción (D4-0 y D4a; V6.1–V6.6 y prueba negativa anon OK).
--         No volver a ejecutar sin aprobación explícita.
--
-- Qué hace
--   PASO D4-0   Instantánea de las ACL de las 19 funciones (_hardening_1b.acl_snapshot_d4)
--               y tabla de control (_hardening_1b.d4_control). No modifica permisos.
--   PASO D4a    REVOKE EXECUTE ON FUNCTION <las 19> FROM PUBLIC, anon.
--
-- Qué NO hace
--   * No toca authenticated, service_role ni postgres (owner).
--   * No toca los 4 helpers internos para authenticated (eso es D4b, otro archivo).
--   * No toca default privileges, tablas, policies, search_path ni roles.
--
-- Evidencia en la que se apoya (ver docs/SEGURIDAD.md, "1B-bis")
--   A1–A8 y M1–M3: ninguna de las 19 está en triggers, event triggers, Auth Hooks,
--   vistas, cron ni defaults/constraints; solo las 5 es_*() aparecen en policies
--   (todas {authenticated}); anon no necesita EXECUTE en ninguna; los roles internos
--   de Supabase solo tienen EXECUTE por PUBLIC (M3d) y ninguna dependencia lo exige.
--
-- CÓMO EJECUTARLO
--   * Rol postgres (SQL Editor de Supabase). UN PASO CADA VEZ (cada paso es un
--     BEGIN ... COMMIT independiente). Tras cada paso, 1B-07_d4_verificacion.sql.
--   * Cada paso aborta (y no cambia nada) si una guarda falla. No continuar sin
--     entender el motivo.
--   * D4b (1B-05) NO debe ejecutarse en la misma sesión: exige un marcador manual
--     posterior a la verificación de D4a.
--   * Rollback: 1B-06_d4_execute_rollback.sql.
--
-- REPETIBILIDAD: D4-0 no sobrescribe una instantánea existente; D4a, si las 19 ya
-- están en el estado final de D4a, solo avisa. Tras D4b, D4a ya no es repetible
-- (la guarda de ACL lo rechaza a propósito).
-- ============================================================


-- ============================================================
-- PASO D4-0 — INSTANTÁNEA + TABLA DE CONTROL
-- ============================================================
begin;

create schema if not exists _hardening_1b;
revoke all on schema _hardening_1b from public, anon, authenticated;

create table if not exists _hardening_1b.acl_snapshot_d4 (
  obj text not null, owner text not null, grantor text not null,
  grantee text not null, privilege text not null, grantable boolean not null,
  taken_at timestamptz not null default now()
);
create table if not exists _hardening_1b.d4_control (
  step text primary key,
  at   timestamptz not null default now(),
  note text
);
alter table _hardening_1b.acl_snapshot_d4 enable row level security;
alter table _hardening_1b.d4_control      enable row level security;
revoke all on all tables in schema _hardening_1b from public, anon, authenticated;

do $$
declare
  fns text[] := array[
    'public.aprobar_correccion_fichaje(bigint,timestamptz,text)',
    'public.cancelar_solicitud(bigint)',
    'public.comprobar_disponibilidad(timestamp,timestamp,jsonb,bigint)',
    'public.crear_solicitud(text,timestamp,timestamp,text,jsonb)',
    'public.editar_solicitud(bigint,text,timestamp,timestamp,text,jsonb)',
    'public.es_admin()', 'public.es_cliente()', 'public.es_min_gestor()',
    'public.es_min_operario()', 'public.es_min_responsable()',
    'public.fichaje_mi_persona()', 'public.fichar(text,text)', 'public.mi_catalogo()',
    'public.mi_cliente_id()', 'public.mi_nivel()', 'public.mi_rol()',
    'public.mis_solicitudes()', 'public.rechazar_correccion_fichaje(bigint,text)',
    'public.solicitar_correccion_fichaje(text,timestamptz,text,text,text,bigint)'];
  f text; n int; v_acl text[]; v_ok boolean;
begin
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if not exists (select 1 from _hardening_1b.acl_snapshot where kind = 'function') then
    raise exception 'Falta la instantánea del núcleo 1B (acl_snapshot, kind = function)';
  end if;
  if exists (select 1 from _hardening_1b.acl_snapshot_d4) then
    raise notice 'Instantánea D4 ya existente: no se sobrescribe.';
    return;
  end if;

  select count(*) into n from pg_proc where pronamespace = 'public'::regnamespace and prosecdef;
  if n <> 19 then raise exception 'Se esperaban 19 SECURITY DEFINER en public, hay %', n; end if;

  foreach f in array fns loop
    if to_regprocedure(f) is null then raise exception 'No existe la función %', f; end if;
    -- Solo se toma instantánea del estado PREVIO a D4: PUBLIC, anon, authenticated,
    -- postgres y service_role, todo concedido por el owner y sin grant option.
    select array_agg(g order by g collate "C"), bool_and(not gr and gor and pt = 'EXECUTE')
      into v_acl, v_ok
      from (select case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as g,
                   a.is_grantable as gr, (a.grantor = p.proowner) as gor, a.privilege_type as pt
              from pg_proc p,
                   lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
             where p.oid = to_regprocedure(f)::oid) x;
    if not v_ok or v_acl <> array['PUBLIC','anon','authenticated','postgres','service_role'] then
      raise exception 'ACL de % no es la auditada (PUBLIC, anon, authenticated, postgres, service_role): %', f, v_acl;
    end if;
  end loop;

  insert into _hardening_1b.acl_snapshot_d4 (obj, owner, grantor, grantee, privilege, grantable)
  select p.oid::regprocedure::text, p.proowner::regrole::text, a.grantor::regrole::text,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
         a.privilege_type, a.is_grantable
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.oid in (select to_regprocedure(x)::oid from unnest(fns) x);

  select count(*) into n from _hardening_1b.acl_snapshot_d4;
  if n <> 95 then raise exception 'La instantánea D4 debía tener 19 x 5 = 95 filas, tiene %', n; end if;
end $$;

commit;
-- Recomendado: exportar acl_snapshot_d4 a CSV como copia fuera de la BD.


-- ============================================================
-- PASO D4a — REVOKE EXECUTE FROM PUBLIC, anon (19 funciones)
-- ============================================================
begin;

do $$
declare
  fns text[] := array[
    'public.aprobar_correccion_fichaje(bigint,timestamptz,text)',
    'public.cancelar_solicitud(bigint)',
    'public.comprobar_disponibilidad(timestamp,timestamp,jsonb,bigint)',
    'public.crear_solicitud(text,timestamp,timestamp,text,jsonb)',
    'public.editar_solicitud(bigint,text,timestamp,timestamp,text,jsonb)',
    'public.es_admin()', 'public.es_cliente()', 'public.es_min_gestor()',
    'public.es_min_operario()', 'public.es_min_responsable()',
    'public.fichaje_mi_persona()', 'public.fichar(text,text)', 'public.mi_catalogo()',
    'public.mi_cliente_id()', 'public.mi_nivel()', 'public.mi_rol()',
    'public.mis_solicitudes()', 'public.rechazar_correccion_fichaje(bigint,text)',
    'public.solicitar_correccion_fichaje(text,timestamptz,text,text,text,bigint)'];
  es5 text[] := array['public.es_admin()','public.es_cliente()','public.es_min_gestor()',
                      'public.es_min_operario()','public.es_min_responsable()'];
  oids oid[]; es5oids oid[];
  f text; nm text; n int; v_acl text[]; v_ok boolean;
  v_pre int := 0; v_done int := 0; denied boolean;
begin
  -- ── Guardas ──────────────────────────────────────────────
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if not exists (select 1 from _hardening_1b.acl_snapshot where kind = 'function') then
    raise exception 'Falta la instantánea del núcleo 1B';
  end if;
  select count(*) into n from _hardening_1b.acl_snapshot_d4;
  if n <> 95 then raise exception 'Falta la instantánea D4 (D4-0): % filas, se esperaban 95', n; end if;

  -- Identidad: exactamente las 19, SECURITY DEFINER, owner postgres, search_path fijado (D1).
  select count(*) into n from pg_proc where pronamespace = 'public'::regnamespace and prosecdef;
  if n <> 19 then raise exception 'Se esperaban 19 SECURITY DEFINER en public, hay %', n; end if;
  foreach f in array fns loop
    if to_regprocedure(f) is null then raise exception 'No existe la función %', f; end if;
  end loop;
  select array_agg(to_regprocedure(x)::oid) into oids   from unnest(fns) x;
  select array_agg(to_regprocedure(x)::oid) into es5oids from unnest(es5) x;
  select count(*) into n from pg_proc p
   where p.oid = any(oids) and p.prosecdef and p.proowner = 'postgres'::regrole
     and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if n <> 19 then raise exception 'Las 19 deben ser SECURITY DEFINER, owner postgres y con search_path'; end if;

  -- Núcleo 1B intacto (el modelo de D4a presupone anon sin acceso a tablas y policies {authenticated}).
  select count(*) into n from pg_policies where schemaname = 'public';
  if n <> 102 then raise exception 'Se esperaban 102 policies en public, hay %', n; end if;
  select count(*) into n from pg_policies where roles = '{public}';
  if n <> 0 then raise exception 'Hay % policies {public}: el núcleo 1B no está como se auditó', n; end if;
  select count(*) into n from pg_class
   where relnamespace = 'public'::regnamespace and relkind = 'r'
     and has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN');
  if n <> 0 then raise exception 'anon aún tiene privilegios de tabla en % tablas', n; end if;

  -- M1 (re-comprobación): solo policies dependen de las 19, y solo las 5 es_*().
  select count(*) into n from pg_depend d
   where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(oids)
     and d.classid <> 'pg_policy'::regclass;
  if n <> 0 then raise exception 'Hay % dependencias registradas que no son policies: revisar antes de D4', n; end if;
  select count(*) into n from pg_depend d
   where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(oids)
     and d.classid = 'pg_policy'::regclass and d.refobjid <> all(es5oids);
  if n <> 0 then raise exception 'Hay policies que dependen de funciones distintas de las 5 es_*()'; end if;

  -- Las ACL de TODAS las funciones de public coinciden con la instantánea del núcleo 1B (V5 = 0/0).
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
  select (select count(*) from (select * from snap except select * from actual) x)
       + (select count(*) from (select * from actual except select * from snap) y) into n;
  if n <> 0 then raise exception 'Las ACL de funciones difieren de la instantánea del núcleo 1B (% filas)', n; end if;

  -- Estado de ACL por función: PRE (auditado) o YA APLICADO (D4a). Nada intermedio.
  foreach f in array fns loop
    select array_agg(g order by g collate "C"), bool_and(not gr and gor and pt = 'EXECUTE')
      into v_acl, v_ok
      from (select case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as g,
                   a.is_grantable as gr, (a.grantor = p.proowner) as gor, a.privilege_type as pt
              from pg_proc p,
                   lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
             where p.oid = to_regprocedure(f)::oid) x;
    if not v_ok then raise exception 'ACL con grant option / grantor distinto del owner en %', f; end if;
    if v_acl = array['PUBLIC','anon','authenticated','postgres','service_role'] then v_pre := v_pre + 1;
    elsif v_acl = array['authenticated','postgres','service_role'] then v_done := v_done + 1;
    else raise exception 'ACL inesperada en %: %', f, v_acl;
    end if;
  end loop;
  if v_done = 19 then
    raise notice 'D4a ya estaba aplicado: no se cambia nada.';
    insert into _hardening_1b.d4_control (step, note) values ('D4a_aplicado', 'detectado ya aplicado')
      on conflict do nothing;
    return;
  end if;
  if v_pre <> 19 then raise exception 'Estado parcial: % en estado previo, % en estado D4a', v_pre, v_done; end if;

  -- La instantánea D4 coincide con el estado actual (el rollback será exacto).
  select (select count(*) from (
            select obj, grantee, privilege, grantable from _hardening_1b.acl_snapshot_d4
            except
            select p.oid::regprocedure::text,
                   case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                   a.privilege_type, a.is_grantable
              from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
             where p.oid = any(oids)) x)
       + (select count(*) from (
            select p.oid::regprocedure::text,
                   case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                   a.privilege_type, a.is_grantable
              from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
             where p.oid = any(oids)
            except
            select obj, grantee, privilege, grantable from _hardening_1b.acl_snapshot_d4) y) into n;
  if n <> 0 then raise exception 'La instantánea D4 no coincide con el estado actual (% filas)', n; end if;

  -- ── Cambio ───────────────────────────────────────────────
  foreach f in array fns loop
    execute format('revoke execute on function %s from public, anon', f);
  end loop;

  -- ── Aserciones posteriores (si falla alguna, se revierte todo) ──
  foreach f in array fns loop
    if has_function_privilege('anon', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'anon conserva EXECUTE en % (directo o heredado)', f; end if;
    if exists (select 1 from pg_proc p, lateral aclexplode(p.proacl) a
                where p.oid = to_regprocedure(f)::oid and a.grantee = 0) then
      raise exception 'PUBLIC conserva EXECUTE en %', f; end if;
    if not has_function_privilege('authenticated', to_regprocedure(f)::oid, 'EXECUTE')
       or not has_function_privilege('service_role', to_regprocedure(f)::oid, 'EXECUTE')
       or not has_function_privilege('postgres',     to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'authenticated, service_role o postgres han perdido EXECUTE en %', f; end if;
  end loop;

  -- ── Sondas funcionales (rol simulado, dentro de la misma transacción) ──
  -- anon: debe recibir "permission denied" (42501) en una RLS-helper y en una RPC del portal.
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  foreach nm in array array['es_admin', 'es_cliente', 'mi_catalogo'] loop
    denied := false;
    begin
      set local role anon;
      execute format('select * from public.%I()', nm);
    exception when insufficient_privilege then
      denied := true;
    end;
    reset role;
    if not denied then raise exception 'anon pudo ejecutar % tras D4a', nm; end if;
  end loop;
  -- authenticated: las 5 funciones de RLS deben seguir ejecutándose (su cadena interna corre como owner).
  perform set_config('request.jwt.claims',
    '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000000","email":"d4-probe@invalid.example"}', true);
  set local role authenticated;
  foreach nm in array array['es_admin','es_cliente','es_min_gestor','es_min_operario','es_min_responsable'] loop
    execute format('select * from public.%I()', nm);
  end loop;
  reset role;
  perform set_config('request.jwt.claims', '', true);

  insert into _hardening_1b.d4_control (step, note) values ('D4a_aplicado', 'revoke PUBLIC, anon sobre las 19')
    on conflict do nothing;
  raise notice 'D4a aplicado: PUBLIC y anon sin EXECUTE en las 19 funciones.';
end $$;

commit;
