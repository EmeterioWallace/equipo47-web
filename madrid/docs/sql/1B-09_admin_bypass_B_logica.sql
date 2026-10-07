-- ============================================================
-- BLOQUE "ADMIN BYPASS" · B — LÓGICA: retirar el bypass por email de mi_rol()
-- ============================================================
-- ESTADO: PREPARADO (definición nueva incorporada), NO APLICADO.
-- No ejecutar sin aprobación explícita.
--
-- Definición nueva (v_new_def)
--   Es la definición REAL desplegada de mi_rol() (obtenida de producción con
--   pg_get_functiondef) con UN ÚNICO cambio lógico: se elimina la rama WHEN que devolvía
--   'admin' para los dos emails. Se conserva tal cual: RETURNS text, LANGUAGE sql, STABLE,
--   SECURITY DEFINER, SET search_path TO 'public', 'pg_temp', la búsqueda en personas_equipo
--   por lower(email) contra lower(coalesce(auth.jwt() ->> 'email', '')), el LIMIT 1 y el
--   valor 'consulta' cuando no hay fila. NO consulta `activo`. La rama CASE desaparece
--   porque, sin su WHEN, solo quedaba el ELSE (que pasa a ser la expresión completa).
--   El script no puede probar que el único cambio textual sea esa rama: revisar el diff
--   contra _hardening_1b.admin_bypass_mi_rol_backup.def. El comportamiento sí lo prueba la
--   comparación diferencial.
--
-- NOTAS DE PROCEDIMIENTO
--   * B DEBE EJECUTARSE ANTES DE CUALQUIER D4b. D4b (REVOKE EXECUTE de authenticated sobre
--     mi_rol() y otros 3 helpers) cambia el ACL de mi_rol(); B compara el ACL actual con el
--     respaldado por el script A y abortaría por deriva. D4b sigue NO ejecutado.
--   * B-1 SOLO PUEDE ENSAYARSE (DRY_RUN) DESPUÉS de A y de B-0: sus guardas exigen A_aplicado,
--     el marcador frontend_verificado y 5 minutos de antigüedad. Antes de eso aborta por
--     diseño (no es un fallo). Orden: A (DRY_RUN y COMMIT) -> frontend -> B-0 -> esperar 5 min
--     -> B-1 DRY_RUN -> B-1 COMMIT.
--
-- Requisitos previos (el script los comprueba)
--   * Script A aplicado (A_aplicado) y las 2 cuentas ya son admin activos en la tabla.
--   * Frontend sin bypass desplegado y verificado, y marcador B-0 registrado (PASO B-0).
--   * La función desplegada coincide con la respaldada en A (sin deriva) y aún contiene
--     el bypass.
--
-- Qué hace el PASO B-1 (una transacción)
--   1. Guardas. 2. Comparación diferencial ANTES (JWT simulado con set_config, SIN
--   modificar ningún usuario ni ninguna fila). 3. CREATE OR REPLACE de mi_rol().
--   4. Comparación diferencial DESPUÉS y diff estricto = 0. 5. Verifica que propiedades,
--   owner, ACL y funciones dependientes no cambian y que el cuerpo ya no contiene emails.
--   Sondas: los 9+ emails reales de personas_equipo (estrictas), un email inexistente y
--   una sesión sin email (estrictas), y variantes en MAYÚSCULAS (informativas: se
--   reportan, no abortan; en Supabase el email del JWT va en minúsculas).
--
-- Qué NO hace
--   Sin auth.uid(), sin triggers, sin tocar `activo` ni personas_equipo, sin ACL.
--
-- CÓMO EJECUTARLO (rol postgres)
--   B-0 (marcador, tras verificar el frontend) y B-1 en ejecuciones separadas.
--   B-1: v_modo := 'DRY_RUN' por defecto -> termina con el error "DRY_RUN OK..." y NO deja
--   nada (es el éxito del ensayo). Cambiar v_modo a 'COMMIT' (única edición) para aplicar.
--
-- Rollback: 1B-10_admin_bypass_C_rollback.sql (C1 restaura mi_rol()). Inmediato.
-- ============================================================


-- ============================================================
-- PASO B-0 — marcador manual: "frontend sin bypass desplegado y verificado"
-- Ejecutar SOLO tras desplegar admin.html sin ADMINS_BLINDADOS y comprobar con sesiones
-- reales de las 2 cuentas que ven el menú completo (rol leído de personas_equipo).
-- ============================================================
begin;

do $$
declare n int;
begin
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  if not exists (select 1 from _hardening_1b.admin_bypass_control where step = 'A_aplicado') then
    raise exception 'El script A no consta como aplicado'; end if;
  select count(*) into n from public.personas_equipo b
   join _hardening_1b.admin_bypass_personas_backup k on k.email = lower(b.email)
   where b.rol = 'admin' and b.activo is true;
  if n <> 2 then raise exception 'Las 2 cuentas respaldadas no son admins activos (hay %)', n; end if;
  insert into _hardening_1b.admin_bypass_control (step, note)
  values ('frontend_verificado', 'marcador manual: admin.html sin bypass desplegado y verificado con sesiones reales')
  on conflict do nothing;
  raise notice 'Marcador frontend_verificado registrado.';
end $$;

commit;


-- ============================================================
-- PASO B-1 — CREATE OR REPLACE public.mi_rol() sin el bypass
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

-- Resultados de las sondas (temporal; sin datos persistentes).
create temp table _adm_res (
  fase text, clase text, email text,
  rol text, nivel int, adm boolean, gest boolean, resp boolean, oper boolean
) on commit drop;

-- Evalúa la cadena mi_rol -> mi_nivel -> es_* con un JWT SIMULADO por sonda.
-- No modifica ninguna fila ni ningún usuario: solo set_config local a la transacción.
create function pg_temp._adm_probe(p_fase text) returns void language plpgsql as $f$
declare r record; v_claims jsonb;
begin
  for r in
    select lower(email) as email, 'estricta'::text as clase
      from public.personas_equipo where email is not null group by lower(email)
    union all select 'inexistente@invalid.example', 'estricta'
    union all select null::text, 'estricta'
    union all select upper(email), 'informativa'
      from public.personas_equipo where email is not null group by upper(email)
  loop
    v_claims := jsonb_build_object('role', 'authenticated', 'sub', '00000000-0000-0000-0000-000000000000');
    if r.email is not null then v_claims := v_claims || jsonb_build_object('email', r.email); end if;
    perform set_config('request.jwt.claims', v_claims::text, true);
    insert into pg_temp._adm_res
    select p_fase, r.clase, coalesce(r.email, '<sin email>'),
           public.mi_rol(), public.mi_nivel(), public.es_admin(),
           public.es_min_gestor(), public.es_min_responsable(), public.es_min_operario();
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $f$;

do $$
declare
  v_modo text := 'DRY_RUN';   -- 'DRY_RUN' (ensayo, revierte) | 'COMMIT' (aplica)

  -- ── DEFINICIÓN NUEVA: PEGAR AQUÍ (ver cabecera) ──────────────────────────────
  -- Debe ser la definición desplegada SIN la rama del bypass por email, con
  -- SECURITY DEFINER y SET search_path = public, pg_temp explícitos.
  v_new_def text := $def$
CREATE OR REPLACE FUNCTION public.mi_rol()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT rol FROM personas_equipo
     WHERE lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
     LIMIT 1),
    'consulta'  -- si no está en el equipo, lo mínimo
  );
$function$
  $def$;
  -- ─────────────────────────────────────────────────────────────────────────────

  v_oid    oid := to_regprocedure('public.mi_rol()')::oid;
  v_emails text[];
  v_bk     record;
  v_props_antes jsonb; v_props_despues jsonb;
  v_src text; e text; n int; nn int; r record;
  v_dep_antes jsonb; v_dep_despues jsonb;
  v_def_norm text;
begin
  -- ── Guardas de entorno y de orden ────────────────────────
  if v_modo not in ('DRY_RUN', 'COMMIT') then raise exception 'v_modo debe ser DRY_RUN o COMMIT'; end if;
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  if not exists (select 1 from _hardening_1b.admin_bypass_control where step = 'A_aplicado') then
    raise exception 'El script A no consta como aplicado'; end if;
  if not exists (select 1 from _hardening_1b.admin_bypass_control where step = 'frontend_verificado') then
    raise exception 'Falta el marcador frontend_verificado (PASO B-0)'; end if;
  if (select at from _hardening_1b.admin_bypass_control where step = 'frontend_verificado') > now() - interval '5 minutes' then
    raise exception 'El marcador frontend_verificado es demasiado reciente: B-1 no puede ir en la misma ejecución que B-0'; end if;
  if exists (select 1 from _hardening_1b.admin_bypass_control where step = 'B_aplicado') then
    raise notice 'B ya constaba como aplicado: no se cambia nada.'; return; end if;
  if not exists (select 1 from _hardening_1b.d4_control where step = 'D4a_aplicado') then
    raise exception 'D4a no consta como aplicado'; end if;

  -- ── Guardas sobre la definición nueva ────────────────────
  if position('PENDIENTE' in v_new_def) > 0 then
    raise exception 'v_new_def sigue con la marca PENDIENTE: pegar la definición real (ver cabecera)'; end if;
  -- Normaliza (minúsculas, sin comillas simples, espacios colapsados) para comparar la forma
  -- de pg_get_functiondef: SET search_path TO 'public', 'pg_temp'.
  v_def_norm := regexp_replace(replace(lower(v_new_def), '''', ''), '\s+', ' ', 'g');
  if v_def_norm not like '%create or replace function public.mi_rol()%' then
    raise exception 'v_new_def no define public.mi_rol()'; end if;
  if v_def_norm not like '%security definer%' then
    raise exception 'v_new_def no declara SECURITY DEFINER explícitamente'; end if;
  if v_def_norm not like '%set search_path = public, pg_temp%' and v_def_norm not like '%set search_path to public, pg_temp%' then
    raise exception 'v_new_def no declara SET search_path TO ''public'', ''pg_temp'' explícitamente'; end if;
  if v_def_norm not like '% returns text %' or v_def_norm not like '% language sql %' or v_def_norm not like '% stable %' then
    raise exception 'v_new_def debe conservar RETURNS text, LANGUAGE sql y STABLE'; end if;
  if v_def_norm ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' or v_def_norm like '%equipo47%' then
    raise exception 'v_new_def contiene algo con forma de email o referencia a equipo47'; end if;

  -- ── Guardas de datos: los 2 admins ya existen en la tabla ─
  select array_agg(email) into v_emails from _hardening_1b.admin_bypass_personas_backup;
  if coalesce(array_length(v_emails, 1), 0) <> 2 then raise exception 'El respaldo de personas no tiene 2 filas'; end if;
  foreach e in array v_emails loop
    select count(*) into n from public.personas_equipo where lower(email) = e;
    select count(*) into nn from public.personas_equipo where lower(email) = e and rol = 'admin' and activo is true;
    if n <> 1 or nn <> 1 then raise exception 'La cuenta % no es una única fila admin activa en personas_equipo', e; end if;
  end loop;

  -- ── Guardas de la función actual: sin deriva respecto al respaldo ─
  select * into v_bk from _hardening_1b.admin_bypass_mi_rol_backup where id = 1;
  if v_bk is null then raise exception 'Falta el respaldo de mi_rol() (script A)'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if md5(v_src) <> v_bk.prosrc_md5 then raise exception 'mi_rol() ha cambiado desde el respaldo (deriva)'; end if;
  v_props_antes := pg_temp._adm_props(v_oid);
  if v_props_antes <> v_bk.props then raise exception 'Las propiedades/ACL de mi_rol() difieren del respaldo'; end if;
  foreach e in array v_emails loop
    if position(e in lower(v_src)) = 0 then raise exception 'mi_rol() ya no contiene el bypass de % (estado inesperado)', e; end if;
  end loop;
  select jsonb_object_agg(p.proname, md5(p.prosrc)) into v_dep_antes
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.pronargs = 0
     and p.proname in ('mi_nivel','es_admin','es_min_gestor','es_min_responsable','es_min_operario');
  if v_dep_antes <> v_bk.dependientes then raise exception 'Las funciones dependientes difieren del respaldo'; end if;

  -- ── Comparación diferencial: ANTES ───────────────────────
  perform pg_temp._adm_probe('antes');

  -- ── Cambio de LÓGICA ─────────────────────────────────────
  execute v_new_def;

  -- ── Comparación diferencial: DESPUÉS ─────────────────────
  perform pg_temp._adm_probe('despues');

  with a as (select * from pg_temp._adm_res where fase = 'antes'   and clase = 'estricta'),
       d as (select * from pg_temp._adm_res where fase = 'despues' and clase = 'estricta')
  select count(*) into n from a full join d using (clase, email)
   where (a.rol, a.nivel, a.adm, a.gest, a.resp, a.oper) is distinct from (d.rol, d.nivel, d.adm, d.gest, d.resp, d.oper);
  if n <> 0 then raise exception 'La comparación diferencial ESTRICTA muestra % diferencias: abortado', n; end if;

  for r in
    with a as (select * from pg_temp._adm_res where fase = 'antes'   and clase = 'informativa'),
         d as (select * from pg_temp._adm_res where fase = 'despues' and clase = 'informativa')
    select coalesce(a.email, d.email) as email, a.rol as rol_antes, d.rol as rol_despues
      from a full join d using (clase, email)
     where (a.rol, a.nivel, a.adm, a.gest, a.resp, a.oper) is distinct from (d.rol, d.nivel, d.adm, d.gest, d.resp, d.oper)
  loop
    raise notice 'INFORMATIVA (variante en mayúsculas) % : % -> %', r.email, r.rol_antes, r.rol_despues;
  end loop;
  select count(*) into n from pg_temp._adm_res where fase = 'antes' and clase = 'estricta';
  raise notice 'Comparación diferencial estricta: % sondas, 0 diferencias.', n;

  -- ── Aserciones: propiedades, ACL, dependientes, ausencia del bypass ─
  v_props_despues := pg_temp._adm_props(v_oid);
  if v_props_despues <> v_props_antes then
    raise exception 'Cambian las propiedades/ACL de mi_rol(): antes % / después %', v_props_antes, v_props_despues; end if;
  if not (v_props_despues->>'prosecdef')::boolean then raise exception 'mi_rol() ya no es SECURITY DEFINER'; end if;
  if v_props_despues->'config' <> '["search_path=public, pg_temp"]'::jsonb then
    raise exception 'search_path inesperado: %', v_props_despues->'config'; end if;
  if v_props_despues->>'owner' <> 'postgres' then raise exception 'Owner distinto de postgres'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if md5(v_src) = v_bk.prosrc_md5 then raise exception 'El cuerpo de mi_rol() no ha cambiado'; end if;
  if lower(v_src) ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' or lower(v_src) like '%equipo47%' then
    raise exception 'El cuerpo desplegado aún contiene algo con forma de email'; end if;
  select jsonb_object_agg(p.proname, md5(p.prosrc)) into v_dep_despues
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.pronargs = 0
     and p.proname in ('mi_nivel','es_admin','es_min_gestor','es_min_responsable','es_min_operario');
  if v_dep_despues <> v_dep_antes then raise exception 'Han cambiado funciones dependientes'; end if;

  select count(*) into n from pg_proc
   where pronamespace = 'public'::regnamespace and prosecdef;
  if n <> 19 then raise exception 'Se esperaban 19 SECURITY DEFINER en public, hay %', n; end if;
  select count(*) into n
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.prosecdef and (a.grantee = 0 or a.grantee = 'anon'::regrole);
  if n <> 0 then raise exception 'D4a alterado: % grants a PUBLIC/anon', n; end if;

  insert into _hardening_1b.admin_bypass_control (step, note)
  values ('B_aplicado', 'mi_rol() redefinida sin el bypass por email; diferencial estricto = 0');
  raise notice 'B: mi_rol() sin bypass; propiedades, owner, ACL y dependientes intactos.';

  if v_modo = 'DRY_RUN' then
    raise exception 'DRY_RUN OK: guardas, diferencial y aserciones pasaron; transacción REVERTIDA (esto es el éxito del ensayo). Cambiar v_modo a COMMIT para aplicar.';
  end if;
end $$;

drop function pg_temp._adm_probe(text);
drop function pg_temp._adm_props(oid);
commit;
