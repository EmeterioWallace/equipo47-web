-- ============================================================
-- BLOQUE 1B (NÚCLEO) — ROLLBACK
-- ============================================================
-- Revierte 1B-01_nucleo_migracion.sql en orden inverso (R3 -> R2 -> R1),
-- cada paso en su propia transacción. Ejecutar UN PASO CADA VEZ, con el rol
-- postgres.
--
-- Restaura lo registrado en el esquema _hardening_1b (PASO 0 de la migración):
--   R3  GRANTs de tabla de anon y authenticated: revoke all + re-grant exacto
--       de lo guardado (incluye grant option).
--   R2  Policies: vuelven a {public} y recepcion_lineas_select recupera su USING
--       original guardado.
--   R1  search_path de las 11 funciones: RESET.
--
-- Por qué R1 con RESET es exacto: el PASO 0 de la migración se niega a tomar la
-- instantánea si alguna de las 11 funciones ya tenía un search_path. Por tanto,
-- el estado previo de las 11 era "sin search_path", y RESET lo restaura
-- (ALTER FUNCTION ... RESET search_path solo afecta a ese parámetro).
--
-- No toca EXECUTE de funciones: la migración tampoco lo tocó.
-- ============================================================


-- ── R3: GRANTs de tabla ─────────────────────────────────────
begin;
do $$
declare r record; t text;
begin
  if not exists (select 1 from _hardening_1b.acl_snapshot where kind = 'table') then
    raise exception 'No hay instantánea de tablas: no se puede restaurar con fidelidad';
  end if;
  for t in select distinct obj from _hardening_1b.acl_snapshot where kind = 'table' loop
    execute format('revoke all on table %s from anon, authenticated', t);
  end loop;
  for r in select * from _hardening_1b.acl_snapshot
            where kind = 'table' and grantee in ('anon', 'authenticated') loop
    execute format('grant %s on table %s to %s%s', r.privilege, r.obj, r.grantee,
                   case when r.grantable then ' with grant option' else '' end);
  end loop;
end $$;
commit;


-- ── R2: policies (USING original de recepcion_lineas_select + roles {public}) ──
begin;
do $$
declare r record; q text;
begin
  if not exists (select 1 from _hardening_1b.policy_snapshot) then
    raise exception 'No hay instantánea de policies';
  end if;
  select qual into q from _hardening_1b.policy_snapshot
   where tablename = 'recepcion_lineas' and policyname = 'recepcion_lineas_select';
  if q is null then raise exception 'La instantánea no contiene el USING de recepcion_lineas_select'; end if;
  execute format('alter policy recepcion_lineas_select on public.recepcion_lineas using (%s)', q);

  for r in select * from _hardening_1b.policy_snapshot where roles = array['public'] loop
    execute format('alter policy %I on public.%I to public', r.policyname, r.tablename);
  end loop;
end $$;
commit;


-- ── R1: search_path de las 11 funciones ─────────────────────
begin;
do $$
declare
  fn11 text[] := array['mi_rol','mi_nivel','es_admin','es_min_gestor','es_min_responsable',
    'es_min_operario','fichaje_mi_persona','fichar','solicitar_correccion_fichaje',
    'aprobar_correccion_fichaje','rechazar_correccion_fichaje'];
  r record;
begin
  if not exists (select 1 from _hardening_1b.funcconf_snapshot) then
    raise exception 'No hay instantánea de funciones';
  end if;
  if exists (select 1 from _hardening_1b.funcconf_snapshot f
              where f.proname = any(fn11)
                and exists (select 1 from unnest(coalesce(f.proconfig, '{}')) c where c like 'search_path=%'))
  then raise exception 'La instantánea indica un search_path previo: restaurar a mano'; end if;

  for r in select p.oid::regprocedure as firma from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.proname = any(fn11)
  loop
    execute format('alter function %s reset search_path', r.firma);
  end loop;
end $$;
commit;


-- ── (Opcional, solo cuando la validación esté cerrada) eliminar la instantánea ──
-- drop schema _hardening_1b cascade;
