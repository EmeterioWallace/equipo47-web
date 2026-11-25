-- =====================================================================
-- 38_precio_publico_privado_rollback.sql  ·  Producciones  ·  25/11/2026
-- Deshace 38_precio_publico_privado.sql:
--   1. Devuelve calcular_precio_publico al esquema public (misma función, mismo OID;
--      catalogo_web la sigue por OID y vuelve a llamar a la de public).
--   2. Le devuelve exactamente los permisos que tenía (guardados por el 38 en
--      privado.respaldo_permisos_38). OJO: vuelve a quedar abierta al público
--      por /rest/v1/rpc/calcular_precio_publico.
--   3. Borra la tabla de respaldo y el esquema privado.
-- Aborta si en "privado" hay algo más que lo que creó el 38.
-- Verifica como anon que catalogo_web devuelve lo mismo que antes del rollback.
-- Se ejecuta entero, de una vez. Todo va en una transacción.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Comprobaciones previas
-- ---------------------------------------------------------------------

do $$
declare
  lista text;
begin
  if to_regprocedure('privado.calcular_precio_publico(uuid, integer)') is null then
    raise exception 'No existe privado.calcular_precio_publico(uuid, integer): el 38 no está aplicado. No se cambia nada.';
  end if;
  if exists (select 1 from pg_proc where proname = 'calcular_precio_publico'
             and pronamespace = 'public'::regnamespace) then
    raise exception 'Ya hay una calcular_precio_publico en public. No se cambia nada.';
  end if;
  if to_regclass('privado.respaldo_permisos_38') is null
     or not exists (select 1 from privado.respaldo_permisos_38 where objeto = 'calcular_precio_publico') then
    raise exception 'Falta el respaldo de permisos (privado.respaldo_permisos_38). No se cambia nada.';
  end if;

  -- En privado solo puede estar lo que creó el 38.
  select string_agg(x, ', ') into lista
  from (
    select p.oid::regprocedure::text as x from pg_proc p
    where p.pronamespace = 'privado'::regnamespace and p.proname <> 'calcular_precio_publico'
    union all
    select c.relname from pg_class c
    where c.relnamespace = 'privado'::regnamespace
      and c.relname not in ('respaldo_permisos_38', 'respaldo_permisos_38_pkey')
  ) o;
  if lista is not null then
    raise exception 'En el esquema privado hay más cosas que las del 38 (%). No se cambia nada.', lista;
  end if;
end;
$$;

-- 0.1 Foto como anon de lo que ve la tienda ahora.
set local role anon;
select set_config('e47_38r.catalogo_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text,
  true);
reset role;

-- ---------------------------------------------------------------------
-- 1. Devolver la función a public con sus permisos originales
-- ---------------------------------------------------------------------

alter function privado.calcular_precio_publico(uuid, integer) set schema public;

do $$
declare
  f         oid := to_regprocedure('public.calcular_precio_publico(uuid, integer)');
  dueno     oid := (select proowner from pg_proc where oid = to_regprocedure('public.calcular_precio_publico(uuid, integer)'));
  acl_antes aclitem[] := (select acl from privado.respaldo_permisos_38 where objeto = 'calcular_precio_publico');
  r         record;
begin
  -- Quitar los permisos actuales (salvo los del dueño)...
  for r in
    select distinct a.grantee
    from aclexplode((select proacl from pg_proc where oid = f)) a
    where a.grantee <> dueno
  loop
    execute format('revoke all on function %s from %s', f::regprocedure,
                   case when r.grantee = 0 then 'public' else r.grantee::regrole::text end);
  end loop;

  -- ...y poner los de antes. acl null = permisos por defecto (EXECUTE para PUBLIC).
  for r in
    select a.grantee, bool_or(a.is_grantable) as con_grant
    from aclexplode(coalesce(acl_antes, acldefault('f', dueno))) a
    where a.grantee <> dueno and a.privilege_type = 'EXECUTE'
    group by a.grantee
  loop
    execute format('grant execute on function %s to %s%s', f::regprocedure,
                   case when r.grantee = 0 then 'public' else r.grantee::regrole::text end,
                   case when r.con_grant then ' with grant option' else '' end);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 2. Borrar el respaldo y el esquema
-- ---------------------------------------------------------------------

-- Se guarda el respaldo en una variable para verificar después de borrarlo.
select set_config('e47_38r.acl_antes',
  coalesce((select acl::text from privado.respaldo_permisos_38 where objeto = 'calcular_precio_publico'), ''),
  true);

drop table privado.respaldo_permisos_38;
drop schema privado;   -- sin CASCADE: si quedara algo dentro, falla y no se guarda nada.

-- ---------------------------------------------------------------------
-- 3. Verificación
-- ---------------------------------------------------------------------

set local role anon;
select set_config('e47_38r.catalogo_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text,
  true);
reset role;

do $$
declare
  f        oid := to_regprocedure('public.calcular_precio_publico(uuid, integer)');
  dueno    oid;
  acl_txt  text := current_setting('e47_38r.acl_antes');
  esperado text;
  real_    text;
begin
  if f is null then
    raise exception 'Verificación: public.calcular_precio_publico no existe.';
  end if;
  if exists (select 1 from pg_namespace where nspname = 'privado') then
    raise exception 'Verificación: el esquema privado sigue existiendo.';
  end if;
  if not has_function_privilege('anon', f, 'EXECUTE') then
    raise exception 'Verificación: anon no puede ejecutar la función; catalogo_web fallaría.';
  end if;

  -- Mismos permisos que antes del 38 (quién y qué; el "concedido por" puede variar).
  select proowner into dueno from pg_proc where oid = f;
  select string_agg(format('%s:%s:%s', a.grantee, a.privilege_type, a.is_grantable), ',' order by a.grantee, a.privilege_type)
    into esperado
  from aclexplode(coalesce(nullif(acl_txt, '')::aclitem[], acldefault('f', dueno))) a;
  select string_agg(format('%s:%s:%s', a.grantee, a.privilege_type, a.is_grantable), ',' order by a.grantee, a.privilege_type)
    into real_
  from aclexplode(coalesce((select proacl from pg_proc where oid = f), acldefault('f', dueno))) a;
  if esperado is distinct from real_ then
    raise exception 'Verificación: permisos distintos a los de antes del 38. Antes: % · Ahora: %', esperado, real_;
  end if;

  if current_setting('e47_38r.catalogo_antes')::jsonb <> current_setting('e47_38r.catalogo_despues')::jsonb then
    raise exception 'Verificación: como anon, catalogo_web no devuelve lo mismo que antes del rollback.';
  end if;

  raise notice 'Rollback correcto: % productos en catalogo_web, iguales que antes. calcular_precio_publico vuelve a estar en public (y abierta por la API).',
    jsonb_array_length(current_setting('e47_38r.catalogo_despues')::jsonb);
end;
$$;

notify pgrst, 'reload schema';

commit;
