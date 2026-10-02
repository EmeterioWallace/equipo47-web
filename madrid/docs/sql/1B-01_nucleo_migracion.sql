-- ============================================================
-- BLOQUE 1B (NÚCLEO) — MÍNIMO PRIVILEGIO · MIGRACIÓN
-- ============================================================
-- Qué hace:
--   PASO 0 (D0b)  Instantánea exacta (ACL, policies, config de funciones)
--   PASO 1 (D1)   search_path = public, pg_temp en las 11 SECURITY DEFINER auditadas
--   PASO 2 (D2)   8 policies {public} -> authenticated (conserva USING / WITH CHECK)
--   PASO 3 (D2b)  recepcion_lineas_select: USING (NOT public.es_cliente())
--   PASO 4 (D3)   anon: sin privilegios de tabla;
--                 authenticated: sin TRUNCATE / TRIGGER / REFERENCES
--
-- Qué NO hace (queda fuera de este bloque):
--   * EXECUTE de funciones (D4 -> 1B-bis; depende de PUBLIC y de roles internos de Supabase)
--   * emails hardcodeados de mi_rol(), recorte fino de DML de authenticated,
--     default privileges, FORCE RLS, secuencias.
--
-- CÓMO EJECUTARLO
--   * UN PASO CADA VEZ (cada paso es un BEGIN ... COMMIT independiente), con el
--     rol postgres (SQL Editor de Supabase).
--   * Tras cada paso, ejecutar la sección correspondiente de
--     1B-03_nucleo_verificacion.sql y las pruebas funcionales del paso.
--   * Si una guarda falla, el paso no cambia nada (la transacción se revierte).
--     No continuar hasta entender el motivo.
--   * Rollback: 1B-02_nucleo_rollback.sql (requiere haber ejecutado el PASO 0).
--
-- REPETIBILIDAD (por paso; no hay una garantía global):
--   * PASO 0  Si ya existe instantánea, no la sobrescribe (solo avisa).
--   * PASO 1  Solo toca funciones que aún no tienen search_path.
--   * PASO 2  ALTER POLICY ... TO fija la lista de roles de la policy (no la
--             acumula): repetirlo con el mismo rol deja el mismo estado. La
--             guarda acepta 8 policies {public} (por aplicar) o 0 (ya aplicado).
--   * PASO 3  ALTER POLICY ... USING sustituye la expresión: repetirlo es igual.
--   * PASO 4  REVOKE sobre privilegios ya retirados no hace nada.
-- ============================================================


-- ============================================================
-- PASO 0 (D0b) — INSTANTÁNEA
-- No modifica permisos. Crea un esquema privado (sin acceso para anon /
-- authenticated) con el estado previo. Las ACL de funciones se guardan solo
-- como evidencia para 1B-bis: este bloque no las modifica.
-- ============================================================
begin;

create schema if not exists _hardening_1b;
revoke all on schema _hardening_1b from public, anon, authenticated;

create table if not exists _hardening_1b.acl_snapshot (
  kind text not null, obj text not null, owner text not null, grantor text not null,
  grantee text not null, privilege text not null, grantable boolean not null,
  taken_at timestamptz not null default now()
);
create table if not exists _hardening_1b.policy_snapshot (
  tablename text not null, policyname text not null, cmd text, roles text[],
  qual text, with_check text, taken_at timestamptz not null default now()
);
create table if not exists _hardening_1b.funcconf_snapshot (
  obj text not null, proname text not null, proconfig text[],
  taken_at timestamptz not null default now()
);
alter table _hardening_1b.acl_snapshot      enable row level security;
alter table _hardening_1b.policy_snapshot   enable row level security;
alter table _hardening_1b.funcconf_snapshot enable row level security;
revoke all on all tables in schema _hardening_1b from public, anon, authenticated;

do $$
declare
  fn11 text[] := array['mi_rol','mi_nivel','es_admin','es_min_gestor','es_min_responsable',
    'es_min_operario','fichaje_mi_persona','fichar','solicitar_correccion_fichaje',
    'aprobar_correccion_fichaje','rechazar_correccion_fichaje'];
  n int;
begin
  if exists (select 1 from _hardening_1b.acl_snapshot) then
    raise notice 'Instantánea ya existente: no se sobrescribe.';
    return;
  end if;

  -- El estado actual debe coincidir con lo auditado; si no, no se toma instantánea.
  select count(*) into n from pg_class
   where relnamespace = 'public'::regnamespace and relkind in ('r','p','v','m','f');
  if n <> 29 then raise exception 'Se esperaban 29 relaciones en public, hay %', n; end if;
  select count(*) into n from pg_class
   where relnamespace = 'public'::regnamespace and relkind = 'r';
  if n <> 29 then raise exception 'Se esperaban 29 tablas ordinarias, hay %', n; end if;
  select count(*) into n from pg_policies where schemaname = 'public';
  if n <> 102 then raise exception 'Se esperaban 102 policies, hay %', n; end if;
  select count(*) into n from pg_policies where schemaname = 'public' and roles = '{public}';
  if n <> 8 then raise exception 'Se esperaban 8 policies {public}, hay %', n; end if;
  select count(*) into n from pg_proc
   where pronamespace = 'public'::regnamespace and prosecdef and proname = any(fn11);
  if n <> 11 then raise exception 'Se esperaban 11 funciones SECURITY DEFINER, hay %', n; end if;
  -- Precondición de seguridad de D1 (search_path = public, pg_temp en SECURITY DEFINER):
  -- ni anon, ni authenticated, ni PUBLIC pueden tener CREATE efectivo en el esquema public,
  -- porque entonces podrían plantar objetos que una función resolvería antes que los reales.
  -- has_schema_privilege devuelve el privilegio EFECTIVO (grants directos, herencia y PUBLIC);
  -- para PUBLIC (que no es un rol consultable) se mira además su entrada en la ACL del esquema.
  if has_schema_privilege('anon', 'public', 'CREATE') then
    raise exception 'anon tiene CREATE efectivo en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  if has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'authenticated tiene CREATE efectivo en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  if exists (select 1
               from pg_namespace ns,
                    lateral aclexplode(coalesce(ns.nspacl, acldefault('n', ns.nspowner))) a
              where ns.nspname = 'public' and a.grantee = 0 and a.privilege_type = 'CREATE') then
    raise exception 'PUBLIC tiene CREATE en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  -- Esta comprobación es la que hace exacto el rollback R1 (RESET search_path):
  select count(*) into n from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = any(fn11)
     and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if n <> 0 then raise exception 'Alguna de las 11 ya tiene search_path: el estado no es el auditado'; end if;

  insert into _hardening_1b.acl_snapshot (kind, obj, owner, grantor, grantee, privilege, grantable)
  select 'table', c.oid::regclass::text, c.relowner::regrole::text, a.grantor::regrole::text,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
         a.privilege_type, a.is_grantable
    from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p','v','m','f');

  insert into _hardening_1b.acl_snapshot (kind, obj, owner, grantor, grantee, privilege, grantable)
  select 'function', p.oid::regprocedure::text, p.proowner::regrole::text, a.grantor::regrole::text,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
         a.privilege_type, a.is_grantable
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e');

  insert into _hardening_1b.policy_snapshot (tablename, policyname, cmd, roles, qual, with_check)
  select tablename, policyname, cmd, roles::text[], qual, with_check
    from pg_policies where schemaname = 'public';

  insert into _hardening_1b.funcconf_snapshot (obj, proname, proconfig)
  select p.oid::regprocedure::text, p.proname, p.proconfig
    from pg_proc p where p.pronamespace = 'public'::regnamespace;

  -- Para que el rollback de tablas sea fiel, todo grant debe haberlo concedido el dueño.
  if exists (select 1 from _hardening_1b.acl_snapshot
              where kind = 'table' and grantor <> owner) then
    raise exception 'Hay grants de tabla con grantor distinto del dueño: el rollback no sería fiel';
  end if;
end $$;

commit;
-- Recomendado: exportar las 3 tablas de _hardening_1b a CSV como copia fuera de la BD.


-- ============================================================
-- PASO 1 (D1) — search_path en las 11 SECURITY DEFINER auditadas
-- No cambia su lógica: solo fija dónde se resuelven los nombres no cualificados
-- (auth.jwt() ya está cualificado; los objetos de negocio están en public).
-- pg_temp va el último para que una tabla temporal no pueda tapar a una real.
-- ============================================================
begin;

do $$
declare
  fn11 text[] := array['mi_rol','mi_nivel','es_admin','es_min_gestor','es_min_responsable',
    'es_min_operario','fichaje_mi_persona','fichar','solicitar_correccion_fichaje',
    'aprobar_correccion_fichaje','rechazar_correccion_fichaje'];
  r record; n int := 0; total int;
begin
  if not exists (select 1 from _hardening_1b.acl_snapshot) then
    raise exception 'Falta la instantánea (PASO 0)';
  end if;
  -- Misma precondición que en el PASO 0, repetida aquí para cerrar la ventana entre pasos
  -- (antes de cualquier ALTER FUNCTION).
  if has_schema_privilege('anon', 'public', 'CREATE') then
    raise exception 'anon tiene CREATE efectivo en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  if has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'authenticated tiene CREATE efectivo en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  if exists (select 1
               from pg_namespace ns,
                    lateral aclexplode(coalesce(ns.nspacl, acldefault('n', ns.nspowner))) a
              where ns.nspname = 'public' and a.grantee = 0 and a.privilege_type = 'CREATE') then
    raise exception 'PUBLIC tiene CREATE en el esquema public: no se aplica D1 hasta revisarlo';
  end if;
  select count(*) into total from pg_proc
   where pronamespace = 'public'::regnamespace and prosecdef and proname = any(fn11);
  if total <> 11 then
    raise exception 'Se esperaban 11 funciones (sin sobrecargas), hay %', total;
  end if;

  for r in
    select p.oid::regprocedure as firma
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.proname = any(fn11)
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function %s set search_path = public, pg_temp', r.firma);
    n := n + 1;
  end loop;

  if exists (select 1 from pg_proc p
              where p.pronamespace = 'public'::regnamespace and p.prosecdef
                and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%'))
  then raise exception 'Quedan funciones SECURITY DEFINER sin search_path'; end if;
  raise notice 'D1: % funciones actualizadas (0 = ya estaban)', n;
end $$;

commit;


-- ============================================================
-- PASO 2 (D2) — 8 policies {public} -> authenticated
-- ALTER POLICY ... TO conserva USING y WITH CHECK.
-- ============================================================
begin;

do $$
declare total int; previstas int;
begin
  if not exists (select 1 from _hardening_1b.policy_snapshot) then
    raise exception 'Falta la instantánea (PASO 0)';
  end if;
  select count(*) into total
    from pg_policies where schemaname = 'public' and roles = '{public}';
  select count(*) into previstas
    from pg_policies pol
    join (values ('calendario_config',      'calendario_config_select'),
                 ('calendario_config',      'calendario_config_update'),
                 ('fichajes',               'fichajes_select'),
                 ('recepcion_lineas',       'recepcion_lineas_select'),
                 ('recepcion_lineas',       'recepcion_lineas_insert'),
                 ('recepcion_lineas',       'recepcion_lineas_update'),
                 ('recepcion_lineas',       'recepcion_lineas_delete'),
                 ('solicitudes_correccion', 'solicitudes_select')) v(t, p)
      on pol.tablename = v.t and pol.policyname = v.p
   where pol.schemaname = 'public' and pol.roles = '{public}';
  if total <> previstas then
    raise exception 'Hay policies {public} fuera de las 8 previstas';
  end if;
  if previstas not in (0, 8) then
    raise exception 'Estado parcial inesperado: % de 8 policies aún en {public}', previstas;
  end if;
end $$;

alter policy calendario_config_select on public.calendario_config      to authenticated;
alter policy calendario_config_update on public.calendario_config      to authenticated;
alter policy fichajes_select          on public.fichajes               to authenticated;
alter policy recepcion_lineas_select  on public.recepcion_lineas       to authenticated;
alter policy recepcion_lineas_insert  on public.recepcion_lineas       to authenticated;
alter policy recepcion_lineas_update  on public.recepcion_lineas       to authenticated;
alter policy recepcion_lineas_delete  on public.recepcion_lineas       to authenticated;
alter policy solicitudes_select       on public.solicitudes_correccion to authenticated;

commit;


-- ============================================================
-- PASO 3 (D2b) — recepcion_lineas_select alineada con recepciones_ver
-- Antes: USING (true). Ahora: USING (NOT es_cliente()), igual que la tabla padre.
-- ============================================================
begin;

do $$ begin
  if not exists (select 1 from _hardening_1b.policy_snapshot) then
    raise exception 'Falta la instantánea (PASO 0)';
  end if;
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'recepciones'
                    and policyname = 'recepciones_ver' and cmd = 'SELECT' and qual ~* 'es_cliente')
  then raise exception 'recepciones_ver no usa es_cliente(): revisar antes de alinear'; end if;
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'recepcion_lineas'
                    and policyname = 'recepcion_lineas_select' and roles = '{authenticated}')
  then raise exception 'recepcion_lineas_select no está en {authenticated}: ejecutar antes el PASO 2'; end if;
end $$;

alter policy recepcion_lineas_select on public.recepcion_lineas
  using (not public.es_cliente());

commit;


-- ============================================================
-- PASO 4 (D3) — GRANTs de tabla
--   anon:          se retiran TODOS los privilegios de las 29 tablas.
--   authenticated: se retiran TRUNCATE, TRIGGER y REFERENCES.
--                  SELECT / INSERT / UPDATE / DELETE se mantienen en este bloque
--                  (su recorte queda para una fase posterior).
--   service_role y postgres no se tocan.
-- ============================================================
begin;

do $$ begin
  if not exists (select 1 from _hardening_1b.acl_snapshot where kind = 'table') then
    raise exception 'Falta la instantánea (PASO 0)';
  end if;
  if (select count(*) from pg_class
       where relnamespace = 'public'::regnamespace and relkind in ('r','p','v','m','f')) <> 29
     or (select count(*) from pg_class
          where relnamespace = 'public'::regnamespace and relkind = 'r') <> 29
  then raise exception 'public no contiene exactamente 29 tablas ordinarias'; end if;
  if exists (select 1 from pg_attribute
              where attrelid in (select oid from pg_class where relnamespace = 'public'::regnamespace)
                and attacl is not null and not attisdropped)
  then raise exception 'Hay ACL a nivel de columna: el REVOKE de tabla no las cubriría'; end if;
end $$;

revoke all on all tables in schema public from anon;
revoke truncate, trigger, references on all tables in schema public from authenticated;

commit;
