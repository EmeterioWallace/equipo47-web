-- ============================================================
-- BLOQUE "ADMIN BYPASS" · C — ROLLBACK
-- ============================================================
-- ESTADO: PREPARADO, NO EJECUTADO. Solo para revertir el bloque.
--
-- ORDEN OBLIGATORIO (inverso al de aplicación)
--   1. FRONTEND:  revertir el commit de admin.html (git revert). Sin SQL.
--   2. C1 (LÓGICA): restaura mi_rol() desde _hardening_1b.admin_bypass_mi_rol_backup.
--   3. C2 (DATOS):  devuelve las 2 cuentas a su rol previo ('consulta').
--
--   NUNCA ejecutar C2 con el bypass ya retirado de mi_rol(): las 2 cuentas quedarían
--   como 'consulta' y nadie podría reasignar roles. C2 lo comprueba y aborta.
--   Si aun así se perdiera todo acceso admin: desde el SQL Editor (postgres, no sujeto a
--   RLS) basta con `update public.personas_equipo set rol = 'admin' where lower(email) = ...`.
--
-- Cada paso es una transacción independiente; ejecutar uno cada vez como postgres.
-- No toca snapshots de 1B/1B-bis, D4a ni D4b. Las tablas admin_bypass_* se conservan
-- (borrarlas es una decisión posterior y explícita).
-- ============================================================


-- ============================================================
-- C1 — restaurar mi_rol() (lógica)
-- ============================================================
begin;

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

do $$
declare
  v_oid oid := to_regprocedure('public.mi_rol()')::oid;
  v_bk  record;
  v_src text;
begin
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  select * into v_bk from _hardening_1b.admin_bypass_mi_rol_backup where id = 1;
  if v_bk is null then raise exception 'No hay respaldo de mi_rol() (admin_bypass_mi_rol_backup)'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if md5(v_src) = v_bk.prosrc_md5 then
    raise notice 'C1: mi_rol() ya es la definición respaldada; nada que restaurar.';
    return;
  end if;
  if not exists (select 1 from _hardening_1b.admin_bypass_control where step = 'B_aplicado') then
    raise exception 'mi_rol() difiere del respaldo pero B no consta como aplicado: estado inesperado, revisar a mano'; end if;

  execute v_bk.def;   -- definición original (pg_get_functiondef), con SECURITY DEFINER y search_path propios

  select prosrc into v_src from pg_proc where oid = v_oid;
  if md5(v_src) <> v_bk.prosrc_md5 then raise exception 'La restauración no reproduce el cuerpo respaldado'; end if;
  if pg_temp._adm_props(v_oid) <> v_bk.props then
    raise exception 'Tras restaurar, propiedades/ACL difieren del respaldo: %', pg_temp._adm_props(v_oid); end if;

  delete from _hardening_1b.admin_bypass_control where step = 'B_aplicado';
  insert into _hardening_1b.admin_bypass_control (step, note) values ('B_revertido', 'C1: mi_rol() restaurada')
  on conflict (step) do update set at = now();
  raise notice 'C1: mi_rol() restaurada con su bypass original.';
end $$;

drop function pg_temp._adm_props(oid);
commit;


-- ============================================================
-- C2 — restaurar los roles previos de las 2 cuentas (datos)
-- SOLO tras C1 (el bypass debe estar de vuelta).
-- ============================================================
begin;

do $$
declare
  v_oid oid := to_regprocedure('public.mi_rol()')::oid;
  v_bk  record; r record; v_src text; n int;
begin
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  select * into v_bk from _hardening_1b.admin_bypass_mi_rol_backup where id = 1;
  if v_bk is null then raise exception 'No hay respaldo de mi_rol()'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if md5(v_src) <> v_bk.prosrc_md5 then
    raise exception 'ORDEN INCORRECTO: mi_rol() no es la definición con bypass. Ejecutar antes C1.'; end if;
  if not exists (select 1 from _hardening_1b.admin_bypass_control where step = 'A_aplicado') then
    raise exception 'A no consta como aplicado: nada que revertir'; end if;
  if (select count(*) from _hardening_1b.admin_bypass_personas_backup) <> 2 then
    raise exception 'El respaldo de personas no tiene 2 filas'; end if;

  select count(*) into n from public.personas_equipo p
   join _hardening_1b.admin_bypass_personas_backup k on k.email = lower(p.email)
   where p.rol = 'admin';
  if n <> 2 then raise exception 'Se esperaban las 2 cuentas en rol admin y hay % (alguien las cambió: revisar a mano)', n; end if;

  for r in select * from _hardening_1b.admin_bypass_personas_backup loop
    update public.personas_equipo set rol = r.rol_previo
     where lower(email) = r.email and rol = 'admin';
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'El UPDATE de % afectó a % filas (se esperaba 1)', r.email, n; end if;
  end loop;

  delete from _hardening_1b.admin_bypass_control where step in ('A_aplicado', 'frontend_verificado');
  insert into _hardening_1b.admin_bypass_control (step, note) values ('A_revertido', 'C2: roles previos restaurados')
  on conflict (step) do update set at = now();
  raise notice 'C2: roles de las 2 cuentas restaurados a su valor previo.';
end $$;

commit;
