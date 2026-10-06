-- ============================================================
-- BLOQUE 1B-bis · D4b — EXECUTE: retirar authenticated de los 4 helpers internos
-- ============================================================
-- ESTADO: PREPARADO, NO APLICADO. Paso OPCIONAL e INDEPENDIENTE de D4a.
-- No ejecutar sin aprobación explícita y sin haber aplicado y verificado D4a.
--
-- Qué hace
--   REVOKE EXECUTE FROM authenticated en:
--     mi_rol(), mi_nivel(), fichaje_mi_persona(), mi_cliente_id()
--   Estos 4 solo los llaman otras funciones SECURITY DEFINER con owner postgres
--   (cadenas es_* -> mi_nivel -> mi_rol; fichar y 3 correcciones -> fichaje_mi_persona;
--   6 RPC del portal -> mi_cliente_id). Una llamada anidada desde una SECURITY DEFINER
--   se comprueba contra el owner (postgres), que conserva su grant.
--
-- Qué NO hace
--   * No toca las 5 es_*() (las usa RLS como authenticated) ni las 10 RPC.
--   * No toca service_role, postgres, default privileges, tablas ni policies.
--
-- CÓMO EJECUTARLO (dos transacciones, deliberadamente separadas en el tiempo)
--   1. D4a aplicado y verificado (1B-07) + pruebas funcionales con usuarios reales.
--   2. PASO D4b-0: registra el marcador manual 'D4a_verificado'.
--   3. Esperar > 5 minutos (cerrojo de seguridad: el PASO D4b-1 lo exige).
--   4. PASO D4b-1: aplica el cambio. Incluye sondas funcionales dentro de la
--      transacción; si alguna da "permission denied", se revierte todo.
--   Este archivo NO debe pegarse y ejecutarse entero de una vez: D4b-1 abortará.
--   Rollback: R4b en 1B-06_d4_execute_rollback.sql (un GRANT; inmediato).
--
-- Honestidad sobre las sondas: los cuerpos de las funciones no están versionados.
-- Una sonda puede fallar antes de llegar al helper (falso "ok"). La validación
-- real es la prueba con usuarios de cada nivel y del portal justo después.
-- ============================================================


-- ============================================================
-- PASO D4b-0 — marcador manual: "D4a verificado"
-- Ejecutar SOLO tras verificar D4a (V6 de 1B-07) y probar la app con usuarios reales.
-- ============================================================
begin;

do $$
declare n int; f text;
begin
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if not exists (select 1 from _hardening_1b.d4_control where step = 'D4a_aplicado') then
    raise exception 'D4a no consta como aplicado (d4_control)';
  end if;
  -- D4a debe estar realmente en vigor: ninguna de las 19 con PUBLIC ni anon.
  select count(*) into n
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.prosecdef
     and (a.grantee = 0 or a.grantee = 'anon'::regrole);
  if n <> 0 then raise exception 'Quedan % grants a PUBLIC/anon en SECURITY DEFINER de public', n; end if;
  insert into _hardening_1b.d4_control (step, note)
  values ('D4a_verificado', 'marcador manual: V6 y pruebas funcionales de D4a correctas')
  on conflict do nothing;
  raise notice 'Marcador D4a_verificado registrado. D4b-1 solo se aceptará pasados 5 minutos.';
end $$;

commit;


-- ============================================================
-- PASO D4b-1 — REVOKE EXECUTE FROM authenticated (4 helpers)
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
  helpers text[] := array['public.fichaje_mi_persona()','public.mi_cliente_id()',
                          'public.mi_nivel()','public.mi_rol()'];
  es5 text[] := array['public.es_admin()','public.es_cliente()','public.es_min_gestor()',
                      'public.es_min_operario()','public.es_min_responsable()'];
  oids oid[]; helperoids oid[]; es5oids oid[];
  f text; nm text; n int; v_acl text[]; v_ok boolean; v_marker timestamptz;
  v_pre int := 0; v_done int := 0; denied boolean;
begin
  -- ── Guardas ──────────────────────────────────────────────
  if current_user <> 'postgres' then
    raise exception 'Ejecutar como postgres (rol actual: %)', current_user;
  end if;
  if (select count(*) from _hardening_1b.acl_snapshot_d4) <> 95 then
    raise exception 'Falta la instantánea D4 (acl_snapshot_d4)';
  end if;

  -- Cerrojo de orden: D4a aplicado + marcador manual con al menos 5 minutos de antigüedad.
  if not exists (select 1 from _hardening_1b.d4_control where step = 'D4a_aplicado') then
    raise exception 'D4a no consta como aplicado'; end if;
  select at into v_marker from _hardening_1b.d4_control where step = 'D4a_verificado';
  if v_marker is null then
    raise exception 'Falta el marcador D4a_verificado (ejecutar el PASO D4b-0 tras verificar D4a)'; end if;
  if v_marker > now() - interval '5 minutes' then
    raise exception 'El marcador D4a_verificado es demasiado reciente (%): D4b-1 no puede ir en la misma ejecución que D4b-0', v_marker;
  end if;

  -- Identidad de las 19 (igual que D4a).
  select count(*) into n from pg_proc where pronamespace = 'public'::regnamespace and prosecdef;
  if n <> 19 then raise exception 'Se esperaban 19 SECURITY DEFINER en public, hay %', n; end if;
  foreach f in array fns loop
    if to_regprocedure(f) is null then raise exception 'No existe la función %', f; end if;
  end loop;
  select array_agg(to_regprocedure(x)::oid) into oids       from unnest(fns) x;
  select array_agg(to_regprocedure(x)::oid) into helperoids from unnest(helpers) x;
  select array_agg(to_regprocedure(x)::oid) into es5oids    from unnest(es5) x;
  select count(*) into n from pg_proc p
   where p.oid = any(oids) and p.prosecdef and p.proowner = 'postgres'::regrole
     and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if n <> 19 then raise exception 'Las 19 deben ser SECURITY DEFINER, owner postgres y con search_path'; end if;

  -- M1: los 4 helpers no tienen NINGUNA dependencia registrada (ni policies);
  --     las 5 es_*() solo dependen de policies.
  select count(*) into n from pg_depend d
   where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(helperoids);
  if n <> 0 then raise exception 'Hay % dependencias registradas sobre los 4 helpers', n; end if;
  select count(*) into n from pg_depend d
   where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(oids)
     and d.classid <> 'pg_policy'::regclass;
  if n <> 0 then raise exception 'Hay dependencias que no son policies sobre las 19'; end if;
  select count(*) into n from pg_depend d
   where d.refclassid = 'pg_proc'::regclass and d.refobjid = any(oids)
     and d.classid = 'pg_policy'::regclass and d.refobjid <> all(es5oids);
  if n <> 0 then raise exception 'Hay policies que dependen de funciones distintas de las 5 es_*()'; end if;

  -- M2a: todo cuerpo de función (cualquier esquema, salvo catálogo) que nombre un helper
  --      pertenece a las 19 y es SECURITY DEFINER con owner postgres.
  select count(*) into n from pg_proc p
   where p.pronamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
     and p.prosrc ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M'
     and not (p.oid = any(oids) and p.prosecdef and p.proowner = 'postgres'::regrole);
  if n <> 0 then raise exception 'Hay % funciones fuera de las 19 (o no SECURITY DEFINER/postgres) que nombran un helper', n; end if;
  -- M2b: vistas y vistas materializadas.
  select count(*) into n from pg_views
   where definition ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M';
  if n <> 0 then raise exception 'Hay vistas que nombran un helper'; end if;
  select count(*) into n from pg_matviews
   where definition ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M';
  if n <> 0 then raise exception 'Hay vistas materializadas que nombran un helper'; end if;
  -- M2c: pg_cron (no instalado según M2c; se comprueba por si se instalara después).
  if to_regclass('cron.job') is not null then
    execute $q$select count(*) from cron.job
               where command ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M'$q$ into n;
    if n <> 0 then raise exception 'Hay jobs de pg_cron que nombran un helper'; end if;
  end if;
  -- M2d: policies de TODOS los esquemas (storage, realtime...).
  select count(*) into n from pg_policies
   where coalesce(qual, '') ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M'
      or coalesce(with_check, '') ~* '\m(fichaje_mi_persona|mi_cliente_id|mi_nivel|mi_rol)\M';
  if n <> 0 then raise exception 'Hay policies que nombran un helper'; end if;

  -- Estado de ACL: los 4 helpers en estado D4a ({authenticated, postgres, service_role})
  -- o ya en estado D4b ({postgres, service_role}); las otras 15 en estado D4a.
  foreach f in array fns loop
    select array_agg(g order by g collate "C"), bool_and(not gr and gor and pt = 'EXECUTE')
      into v_acl, v_ok
      from (select case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end as g,
                   a.is_grantable as gr, (a.grantor = p.proowner) as gor, a.privilege_type as pt
              from pg_proc p,
                   lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
             where p.oid = to_regprocedure(f)::oid) x;
    if not v_ok then raise exception 'ACL con grant option / grantor distinto del owner en %', f; end if;
    if f = any(helpers) then
      if v_acl = array['authenticated','postgres','service_role'] then v_pre := v_pre + 1;
      elsif v_acl = array['postgres','service_role'] then v_done := v_done + 1;
      else raise exception 'ACL inesperada en helper %: %', f, v_acl; end if;
    else
      if v_acl <> array['authenticated','postgres','service_role'] then
        raise exception 'ACL inesperada en %: % (se esperaba el estado D4a)', f, v_acl; end if;
    end if;
  end loop;
  if v_done = 4 then
    raise notice 'D4b ya estaba aplicado: no se cambia nada.';
    insert into _hardening_1b.d4_control (step, note) values ('D4b_aplicado', 'detectado ya aplicado')
      on conflict do nothing;
    return;
  end if;
  if v_pre <> 4 then raise exception 'Estado parcial en los helpers: % previos, % aplicados', v_pre, v_done; end if;

  -- ── Cambio ───────────────────────────────────────────────
  foreach f in array helpers loop
    execute format('revoke execute on function %s from authenticated', f);
  end loop;

  -- ── Aserciones posteriores ───────────────────────────────
  foreach f in array helpers loop
    if has_function_privilege('authenticated', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'authenticated conserva EXECUTE en % (directo o heredado)', f; end if;
    if has_function_privilege('anon', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'anon tiene EXECUTE en %', f; end if;
    if not has_function_privilege('service_role', to_regprocedure(f)::oid, 'EXECUTE')
       or not has_function_privilege('postgres', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'service_role o postgres han perdido EXECUTE en %', f; end if;
  end loop;
  foreach f in array fns loop
    if not (f = any(helpers)) and not has_function_privilege('authenticated', to_regprocedure(f)::oid, 'EXECUTE') then
      raise exception 'authenticated ha perdido EXECUTE en % (no debía)', f; end if;
  end loop;

  -- ── Sondas funcionales con rol simulado ──────────────────
  perform set_config('request.jwt.claims',
    '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000000","email":"d4-probe@invalid.example"}', true);

  -- (1) Los 4 helpers deben estar vedados a authenticated (42501).
  foreach nm in array array['mi_rol','mi_nivel','fichaje_mi_persona','mi_cliente_id'] loop
    denied := false;
    begin
      set local role authenticated;
      execute format('select * from public.%I()', nm);
    exception when insufficient_privilege then
      denied := true;
    end;
    reset role;
    if not denied then raise exception 'authenticated aún pudo ejecutar % tras D4b', nm; end if;
  end loop;

  -- (2) Cadena RLS: es_* -> mi_nivel -> mi_rol debe seguir funcionando para authenticated.
  set local role authenticated;
  foreach nm in array array['es_admin','es_cliente','es_min_gestor','es_min_operario','es_min_responsable'] loop
    execute format('select * from public.%I()', nm);
  end loop;
  reset role;

  -- (3) RPC que atraviesan los helpers. Cada sonda corre en una subtransacción que SIEMPRE
  --     se revierte (se fuerza un error con SQLSTATE D4B01). Solo "permission denied"
  --     (42501) cuenta como fallo; cualquier otro error (p. ej. "no autorizado" por no ser
  --     un usuario real) es aceptable. Las sondas de escritura usan ids inexistentes (-1).
  foreach nm in array array[
      'select * from public.mi_catalogo()',
      'select * from public.mis_solicitudes()',
      'select * from public.comprobar_disponibilidad(now()::timestamp, (now() + interval ''1 day'')::timestamp, ''[]''::jsonb, null::bigint)',
      'select public.cancelar_solicitud(-1::bigint)',
      'select * from public.rechazar_correccion_fichaje(-1::bigint, ''d4b-probe'')'] loop
    begin
      set local role authenticated;
      execute nm;
      raise exception using errcode = 'D4B01', message = 'sonda completada';
    exception when others then
      reset role;
      if sqlstate = '42501' then
        raise exception 'D4b: la sonda "%" falló por permisos: %', nm, sqlerrm;
      end if;
    end;
    reset role;
  end loop;

  perform set_config('request.jwt.claims', '', true);

  insert into _hardening_1b.d4_control (step, note)
  values ('D4b_aplicado', 'revoke authenticated sobre fichaje_mi_persona, mi_cliente_id, mi_nivel, mi_rol')
  on conflict do nothing;
  raise notice 'D4b aplicado: authenticated sin EXECUTE en los 4 helpers internos.';
end $$;

commit;
