-- ============================================================
-- BLOQUE "ADMIN BYPASS" · A — DATOS: promover a las 2 cuentas blindadas a rol='admin'
-- ============================================================
-- ESTADO: PREPARADO, NO APLICADO. No ejecutar sin aprobación explícita.
--
-- Contexto
--   mi_rol() devuelve 'admin' por email para dos cuentas ANTES de consultar
--   personas_equipo, y en la tabla ambas tienen rol='consulta'. Mientras exista el
--   bypass, promoverlas a 'admin' NO cambia el acceso de nadie (ya eran admin). Es el
--   requisito previo para poder retirar el bypass (script B).
--
-- Qué hace (una transacción)
--   1. Guardas de entorno, de identidad de mi_rol() y de estado esperado de las 2 filas.
--   2. Crea (si no existen) en _hardening_1b: admin_bypass_control,
--      admin_bypass_mi_rol_backup y admin_bypass_personas_backup (RLS activa, sin
--      acceso para PUBLIC/anon/authenticated). NO toca ningún snapshot de 1B/1B-bis.
--   3. Respalda: definición completa y propiedades de mi_rol(), huella (md5) del
--      cuerpo de sus dependientes, y el estado previo de las 2 filas.
--   4. UPDATE personas_equipo SET rol='admin' sobre exactamente esas 2 filas.
--   5. Verifica: 2 filas afectadas, el resto de la tabla intacto, mi_rol() intacta.
--
-- Qué NO hace
--   Sin cambios de lógica, de ACL ni de triggers; sin auth.uid(); sin tocar `activo`;
--   no toca D4a ni D4b. Las 2 filas se identifican por email (única dependencia de este
--   script; no se usan ids).
--
-- CÓMO EJECUTARLO (rol postgres, SQL Editor)
--   1. Primera vez con v_modo := 'DRY_RUN' (valor por defecto). Termina con un error
--      deliberado "DRY_RUN OK ..." y NO deja nada: eso es el ÉXITO del ensayo.
--   2. Revisar los NOTICE. Cambiar v_modo a 'COMMIT' (única edición) y ejecutar de nuevo.
--   Reejecutable mientras mi_rol() conserve el bypass: si A ya consta como aplicado y las
--   2 cuentas son admin activas, comprueba el estado y no cambia nada. Después de B
--   (bypass retirado) fallará a propósito en el guard de identidad de mi_rol().
--   Tampoco es reaplicable tras un rollback completo (C2): las tablas admin_bypass_* conservan
--   sus filas y A aborta con "estado inconsistente". Es un fallo seguro deliberado.
--
-- Rollback: 1B-10_admin_bypass_C_rollback.sql (ver el ORDEN: primero la lógica, luego los datos).
-- Nota: los emails de la lista v_emails son los que este bloque retira; ya figuran en el
--   historial del repo. Este archivo no contiene ningún otro dato de personas_equipo.
-- ============================================================

begin;

-- Propiedades relevantes de una función, normalizadas (temporal; desaparece con la sesión).
create function pg_temp._adm_props(p_oid oid) returns jsonb language sql stable as $f$
  select jsonb_build_object(
    'prosecdef', p.prosecdef,
    'owner',     p.proowner::regrole::text,
    'config',    coalesce(to_jsonb(p.proconfig), '[]'::jsonb),
    'acl',       (select coalesce(jsonb_agg(x order by x collate "C"), '[]'::jsonb)
                    from (select (case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end)
                                 || ':' || a.privilege_type || ':' || a.is_grantable::text
                                 || ':' || a.grantor::regrole::text as x
                            from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a) s),
    'volatile',  p.provolatile::text,
    'strict',    p.proisstrict,
    'leakproof', p.proleakproof,
    'parallel',  p.proparallel::text,
    'lang',      l.lanname,
    'ret',       p.prorettype::regtype::text,
    'cost',      p.procost,
    'rows',      p.prorows,
    'kind',      p.prokind::text,
    'nargs',     p.pronargs)
  from pg_proc p join pg_language l on l.oid = p.prolang
  where p.oid = p_oid
$f$;

-- Tablas privadas del bloque (se crean dentro de la transacción: el DRY_RUN las revierte).
create table if not exists _hardening_1b.admin_bypass_control (
  step text primary key,
  at   timestamptz not null default now(),
  note text);
create table if not exists _hardening_1b.admin_bypass_mi_rol_backup (
  id          int primary key default 1 check (id = 1),
  at          timestamptz not null default now(),
  def         text  not null,
  prosrc_md5  text  not null,
  props       jsonb not null,
  dependientes jsonb not null);
create table if not exists _hardening_1b.admin_bypass_personas_backup (
  email         text primary key,
  rol_previo    text not null,
  activo_previo boolean,
  at            timestamptz not null default now());
alter table _hardening_1b.admin_bypass_control          enable row level security;
alter table _hardening_1b.admin_bypass_mi_rol_backup    enable row level security;
alter table _hardening_1b.admin_bypass_personas_backup  enable row level security;
revoke all on _hardening_1b.admin_bypass_control, _hardening_1b.admin_bypass_mi_rol_backup,
              _hardening_1b.admin_bypass_personas_backup from public, anon, authenticated;

do $$
declare
  v_modo   text   := 'DRY_RUN';   -- 'DRY_RUN' (ensayo, revierte) | 'COMMIT' (aplica)
  v_emails text[] := array['guillermomartinez@equipo47.com', 'alejandromartinez@equipo47.com'];
  v_oid    oid    := to_regprocedure('public.mi_rol()')::oid;
  e        text;
  n        int;
  r        record;
  v_total_antes int;  v_total_despues int;
  v_hash_antes text;  v_hash_despues text;
  v_md5_antes  text;
  v_props  jsonb;
  v_src    text;
begin
  if v_modo not in ('DRY_RUN', 'COMMIT') then raise exception 'v_modo debe ser DRY_RUN o COMMIT'; end if;

  -- ── Guardas de entorno ───────────────────────────────────
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  if not exists (select 1 from _hardening_1b.d4_control where step = 'D4a_aplicado') then
    raise exception 'D4a no consta como aplicado (d4_control)'; end if;
  if exists (select 1 from _hardening_1b.d4_control where step = 'D4b_aplicado') then
    raise notice 'AVISO: D4b consta como aplicado; este script no depende de ello.'; end if;

  -- ── Guardas de identidad de mi_rol() ─────────────────────
  if v_oid is null then raise exception 'No existe public.mi_rol()'; end if;
  v_props := pg_temp._adm_props(v_oid);
  if not (v_props->>'prosecdef')::boolean or v_props->>'owner' <> 'postgres' then
    raise exception 'mi_rol() no es SECURITY DEFINER con owner postgres: %', v_props; end if;
  if (v_props->'config')::text not like '%search_path=%' then
    raise exception 'mi_rol() no tiene search_path fijado: %', v_props->'config'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  foreach e in array v_emails loop
    if position(e in lower(v_src)) = 0 then
      raise exception 'mi_rol() no contiene el bypass de %: la definición desplegada no es la auditada', e; end if;
  end loop;

  -- Estado D4a preservado: mi_rol() sin EXECUTE efectivo para PUBLIC ni anon (el respaldo
  -- que se guarda más abajo debe capturar ese estado, no uno ya degradado).
  select count(*) into n
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.oid = v_oid and a.privilege_type = 'EXECUTE'
     and (a.grantee = 0 or a.grantee = 'anon'::regrole);
  if n <> 0 or has_function_privilege('anon', v_oid, 'EXECUTE') then
    raise exception 'mi_rol() tiene EXECUTE para PUBLIC o anon: el estado D4a no está preservado; no se respalda ni se cambia nada'; end if;

  -- ── Idempotencia: ya aplicado ────────────────────────────
  if exists (select 1 from _hardening_1b.admin_bypass_control where step = 'A_aplicado') then
    select count(*) into n from public.personas_equipo
     where lower(email) = any(v_emails) and rol = 'admin' and activo is true;
    if n <> 2 then raise exception 'A consta como aplicado pero hay % admins activos entre las 2 cuentas', n; end if;
    raise notice 'A ya estaba aplicado y el estado es correcto: no se cambia nada.';
    return;
  end if;

  -- ── Estado inconsistente: restos de un intento previo sin marcador A_aplicado ──
  if exists (select 1 from _hardening_1b.admin_bypass_mi_rol_backup)
     or exists (select 1 from _hardening_1b.admin_bypass_personas_backup)
     or exists (select 1 from _hardening_1b.admin_bypass_control) then
    raise exception 'ESTADO INCONSISTENTE: existen filas en las tablas admin_bypass_* pero no consta el marcador A_aplicado (¿rollback completo previo o intento a medias?). A no se reaplica automáticamente: revisar a mano antes de continuar.';
  end if;

  -- ── Guardas de estado de las 2 filas ─────────────────────
  foreach e in array v_emails loop
    select count(*) into n from public.personas_equipo where lower(email) = e;
    if n <> 1 then raise exception 'Se esperaba exactamente 1 fila para % y hay %', e, n; end if;
    select count(*) into n from public.personas_equipo
     where lower(email) = e and rol = 'consulta' and activo is true;
    if n <> 1 then raise exception 'La fila de % no está en (rol=consulta, activo=true)', e; end if;
  end loop;
  select count(*) into n from public.personas_equipo where lower(email) = any(v_emails);
  if n <> 2 then raise exception 'Se esperaban 2 filas entre las dos cuentas y hay %', n; end if;

  select count(*) into n from pg_trigger
   where tgrelid = 'public.personas_equipo'::regclass and not tgisinternal;
  if n > 0 then raise notice 'AVISO: personas_equipo tiene % trigger(s) de usuario; revisar que el UPDATE no tenga efectos laterales.', n; end if;

  -- Huella del resto de la tabla (antes).
  select count(*), md5(coalesce(string_agg(id::text || '|' || coalesce(rol, '~') || '|' || coalesce(activo::text, '~'),
                                           ',' order by id::text), ''))
    into v_total_antes, v_hash_antes
    from public.personas_equipo
   where email is null or lower(email) <> all(v_emails);
  select md5(prosrc) into v_md5_antes from pg_proc where oid = v_oid;

  -- ── Respaldos ────────────────────────────────────────────
  insert into _hardening_1b.admin_bypass_mi_rol_backup (def, prosrc_md5, props, dependientes)
  select pg_get_functiondef(v_oid), v_md5_antes, pg_temp._adm_props(v_oid),
         (select jsonb_object_agg(p.proname, md5(p.prosrc))
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.pronargs = 0
             and p.proname in ('mi_nivel', 'es_admin', 'es_min_gestor', 'es_min_responsable', 'es_min_operario'));
  if (select count(*) from jsonb_object_keys((select dependientes from _hardening_1b.admin_bypass_mi_rol_backup))) <> 5 then
    raise exception 'No se localizaron las 5 funciones dependientes de mi_rol()'; end if;

  insert into _hardening_1b.admin_bypass_personas_backup (email, rol_previo, activo_previo)
  select lower(email), rol, activo from public.personas_equipo where lower(email) = any(v_emails);

  -- ── Cambio de DATOS ──────────────────────────────────────
  update public.personas_equipo set rol = 'admin'
   where lower(email) = any(v_emails) and rol = 'consulta' and activo is true;
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'El UPDATE afectó a % filas (se esperaban 2)', n; end if;

  -- ── Aserciones posteriores ───────────────────────────────
  select count(*) into n from public.personas_equipo
   where lower(email) = any(v_emails) and rol = 'admin' and activo is true;
  if n <> 2 then raise exception 'Tras el UPDATE no hay 2 admins activos (hay %)', n; end if;

  select count(*), md5(coalesce(string_agg(id::text || '|' || coalesce(rol, '~') || '|' || coalesce(activo::text, '~'),
                                           ',' order by id::text), ''))
    into v_total_despues, v_hash_despues
    from public.personas_equipo
   where email is null or lower(email) <> all(v_emails);
  if v_total_despues <> v_total_antes or v_hash_despues <> v_hash_antes then
    raise exception 'El resto de personas_equipo ha cambiado'; end if;
  if (select md5(prosrc) from pg_proc where oid = v_oid) <> v_md5_antes then
    raise exception 'mi_rol() ha cambiado durante el script A'; end if;

  insert into _hardening_1b.admin_bypass_control (step, note)
  values ('A_aplicado', 'Las 2 cuentas blindadas pasan de consulta a admin (datos); mi_rol() sin cambios');

  raise notice 'A: 2 filas promovidas a admin; resto de la tabla (% filas) intacto; mi_rol() intacta.', v_total_despues;

  if v_modo = 'DRY_RUN' then
    raise exception 'DRY_RUN OK: todas las guardas y aserciones pasaron; transacción REVERTIDA (esto es el éxito del ensayo). Cambiar v_modo a COMMIT para aplicar.';
  end if;
end $$;

drop function pg_temp._adm_props(oid);
commit;
