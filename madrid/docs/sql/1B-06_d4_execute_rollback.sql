-- ============================================================
-- BLOQUE 1B-bis · D4 — ROLLBACK de EXECUTE
-- ============================================================
-- ESTADO: PREPARADO, NO EJECUTADO. Solo se usaría para revertir D4a y/o D4b.
--
-- Restaura lo registrado en _hardening_1b.acl_snapshot_d4 (D4-0, 1B-04).
--   R4b  Revierte SOLO D4b: devuelve EXECUTE a authenticated en los 4 helpers.
--        Efecto inmediato; no toca nada más. Dejaría el sistema en estado D4a.
--   R4a  Revierte D4a (y, si hiciera falta, también D4b): deja las 19 funciones
--        exactamente como en la instantánea (PUBLIC, anon, authenticated, postgres,
--        service_role) y comprueba que la diferencia con ella es 0.
--
-- Orden para revertir todo: R4b -> R4a (cada uno en su transacción). R4a por sí
-- solo ya restaura authenticated desde la instantánea, así que es válido aunque
-- D4b no se hubiera aplicado.
--
-- Qué NO toca: service_role, postgres, default privileges, tablas, policies,
-- search_path. No borra la instantánea (decisión posterior y explícita).
-- Ejecutar con el rol postgres, un paso cada vez.
-- ============================================================


-- ── R4b: devolver EXECUTE a authenticated en los 4 helpers ──
begin;
do $$
declare f text; n int;
begin
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if (select count(*) from _hardening_1b.acl_snapshot_d4) <> 95 then
    raise exception 'No hay instantánea D4 completa: no se puede restaurar con fidelidad';
  end if;
  foreach f in array array['public.fichaje_mi_persona()','public.mi_cliente_id()',
                           'public.mi_nivel()','public.mi_rol()'] loop
    if to_regprocedure(f) is null then raise exception 'No existe la función %', f; end if;
    -- Solo se restaura lo que la instantánea tenía: authenticated sin grant option.
    if not exists (select 1 from _hardening_1b.acl_snapshot_d4 s
                    where s.obj = to_regprocedure(f)::text and s.grantee = 'authenticated'
                      and s.privilege = 'EXECUTE' and not s.grantable) then
      raise exception 'La instantánea no contiene authenticated/EXECUTE para %', f;
    end if;
    execute format('grant execute on function %s to authenticated', f);
    if not has_function_privilege('authenticated', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'authenticated no recuperó EXECUTE en %', f; end if;
  end loop;
  delete from _hardening_1b.d4_control where step = 'D4b_aplicado';
  raise notice 'R4b: authenticated recupera EXECUTE en los 4 helpers.';
end $$;
commit;


-- ── R4a: restaurar las 19 funciones al estado de la instantánea ──
begin;
do $$
declare r record; n int; oids oid[];
begin
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if (select count(*) from _hardening_1b.acl_snapshot_d4) <> 95 then
    raise exception 'No hay instantánea D4 completa: no se puede restaurar con fidelidad';
  end if;
  -- Todas las firmas de la instantánea deben seguir existiendo (19).
  select count(distinct s.obj) into n from _hardening_1b.acl_snapshot_d4 s
   where to_regprocedure(s.obj) is not null;
  if n <> 19 then raise exception 'La instantánea referencia % funciones existentes, se esperaban 19', n; end if;
  select array_agg(distinct to_regprocedure(s.obj)::oid) into oids from _hardening_1b.acl_snapshot_d4 s;

  -- Limpiar los tres grantees afectados y reponer exactamente lo guardado.
  for r in select distinct obj from _hardening_1b.acl_snapshot_d4 loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.obj);
  end loop;
  for r in select * from _hardening_1b.acl_snapshot_d4
            where grantee in ('PUBLIC', 'anon', 'authenticated') loop
    execute format('grant execute on function %s to %s%s', r.obj,
                   case when r.grantee = 'PUBLIC' then 'public' else quote_ident(r.grantee) end,
                   case when r.grantable then ' with grant option' else '' end);
  end loop;

  -- Aserción: diferencia 0 con la instantánea (en ambos sentidos).
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
  if n <> 0 then raise exception 'La restauración no es exacta (% filas de diferencia)', n; end if;

  delete from _hardening_1b.d4_control where step in ('D4a_aplicado', 'D4a_verificado', 'D4b_aplicado');
  raise notice 'R4a: las 19 funciones vuelven al estado previo a D4.';
end $$;
commit;


-- ── (Opcional, solo cuando D4 esté cerrado y validado) eliminar instantánea D4 ──
-- drop table _hardening_1b.acl_snapshot_d4;
-- drop table _hardening_1b.d4_control;
