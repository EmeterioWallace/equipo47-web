-- =====================================================================
-- 39_permisos_anon.sql  ·  Producciones  ·  25/11/2026
-- Hallazgos del diagnóstico del 25/11 (ver buzón, Respuestas 25/11 Producciones).
-- REQUIERE: script 38 ejecutado (usa el esquema privado para el respaldo).
-- ORDEN RECOMENDADO: primero desactivar en Supabase → Data API → Settings
-- "Automatically expose new tables"; después este script. Funciona en cualquier
-- orden: quita lo que haya y comprueba el estado final.
--
-- Qué hace:
--   A. Funciones de public que anon puede ejecutar: rls_auto_enable() y
--      categorias_web_antes_guardar(). Comprueba que son funciones de trigger
--      (devuelven trigger o event_trigger) y les quita EXECUTE a PUBLIC y anon.
--      Las de trigger no se pueden llamar desde la API, y PostgreSQL no comprueba
--      EXECUTE cuando salta un trigger: los triggers siguen funcionando igual.
--      Si alguna NO es de trigger, aborta: hay que leer qué hace antes de tocarla.
--   B. Permisos de anon TRUNCATE, REFERENCES, TRIGGER y MAINTAIN:
--      B1. en las tablas y vistas que ya existen en public (el 33 quitó los tres
--          primeros a las que había entonces; las posteriores los tienen);
--      B2. en los permisos por defecto de las tablas nuevas que cree postgres en public.
--   Guarda lo que quita en privado.respaldo_permisos_39 para el rollback.
--
-- Qué NO hace:
--   - No toca SELECT ni nada de lo que usan la tienda y la app.
--   - No toca los permisos por defecto de supabase_admin (Supabase no deja).
--   - No toca los de authenticated ni service_role.
--
-- Verificación: como anon, catalogo_web y categorias_web_publica devuelven lo
-- mismo que antes; anon ya no puede ejecutar ninguna función propia de public;
-- los triggers siguen activos; anon no tiene los cuatro permisos en ninguna tabla
-- ni en los permisos por defecto.
-- Se ejecuta entero, de una vez. Todo va en una transacción.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Comprobaciones previas
-- ---------------------------------------------------------------------

do $$
declare
  r     record;
  n     integer := 0;
  usos  text;
begin
  if to_regclass('privado.respaldo_permisos_39') is not null then
    raise exception 'privado.respaldo_permisos_39 ya existe: parece que este script ya se ejecutó. No se cambia nada.';
  end if;
  if to_regnamespace('privado') is null then
    raise exception 'No existe el esquema privado: falta ejecutar el script 38. No se cambia nada.';
  end if;

  for r in
    select p.oid, p.oid::regprocedure::text as firma, p.prorettype::regtype::text as devuelve,
           p.proowner::regrole::text as dueno, p.prosecdef
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('rls_auto_enable', 'categorias_web_antes_guardar')
  loop
    n := n + 1;

    if r.devuelve = 'trigger' then
      select string_agg(format('%s en %s', t.tgname::text, t.tgrelid::regclass::text), ', ') into usos
      from pg_trigger t where t.tgfoid = r.oid and not t.tgisinternal;
    elsif r.devuelve = 'event_trigger' then
      select string_agg(format('%s (%s)', e.evtname::text, e.evtevent::text), ', ') into usos
      from pg_event_trigger e where e.evtfoid = r.oid;
    else
      raise exception E'% devuelve % (no es de trigger): se podría llamar desde la API y no sabemos qué hace. No se cambia nada. Definición:\n%',
        r.firma, r.devuelve, pg_get_functiondef(r.oid);
    end if;

    if not pg_has_role(current_user, r.dueno::regrole::oid, 'MEMBER') then
      raise exception '% es de % y % no puede cambiar sus permisos. No se cambia nada.', r.firma, r.dueno, current_user;
    end if;

    raise notice '% · devuelve % · dueño % · security definer % · la usan: %',
      r.firma, r.devuelve, r.dueno, r.prosecdef, coalesce(usos, '(nadie)');
  end loop;

  if n <> 2 then
    raise exception 'Se esperaban public.rls_auto_enable() y public.categorias_web_antes_guardar(); hay %. No se cambia nada.', n;
  end if;
end;
$$;

-- 0.1 Foto de lo que ve la tienda ahora, como anon.
set local role anon;
select set_config('e47_39.catalogo_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
select set_config('e47_39.categorias_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.categorias_web_publica c)::text, true);
reset role;

-- 0.2 Triggers que usan las dos funciones (deben seguir igual al final).
select set_config('e47_39.triggers_antes',
  coalesce((select string_agg(x, ',' order by x) from (
     select format('%s/%s/%s', t.tgname::text, t.tgrelid::regclass::text, t.tgenabled::text) as x
     from pg_trigger t
     where t.tgfoid in (to_regprocedure('public.categorias_web_antes_guardar()'),
                        to_regprocedure('public.rls_auto_enable()'))
       and not t.tgisinternal
     union all
     select format('%s/%s/%s', e.evtname::text, e.evtevent::text, e.evtenabled::text)
     from pg_event_trigger e
     where e.evtfoid in (to_regprocedure('public.categorias_web_antes_guardar()'),
                         to_regprocedure('public.rls_auto_enable()'))
  ) t), ''),
  true);

-- ---------------------------------------------------------------------
-- 1. Respaldo de lo que se va a quitar
-- ---------------------------------------------------------------------

create table privado.respaldo_permisos_39 (
  tipo       text not null,   -- funcion | tabla | por_defecto
  objeto     text not null,
  rol        text not null,   -- public | anon
  privilegio text not null,
  guardado   timestamptz not null default now(),
  primary key (tipo, objeto, rol, privilegio)
);
alter table privado.respaldo_permisos_39 enable row level security;
revoke all on table privado.respaldo_permisos_39 from public, anon, authenticated;
comment on table privado.respaldo_permisos_39 is
  'Permisos que quitó el script 39. Los usa 39_permisos_anon_rollback.sql. No borrar.';

-- Funciones: EXECUTE de PUBLIC y de anon.
insert into privado.respaldo_permisos_39 (tipo, objeto, rol, privilegio)
select distinct 'funcion', p.oid::regprocedure::text,
       case when a.grantee = 0 then 'public' else 'anon' end, a.privilege_type
from pg_proc p
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
where p.oid in (to_regprocedure('public.rls_auto_enable()'),
                to_regprocedure('public.categorias_web_antes_guardar()'))
  and (a.grantee = 0 or a.grantee = 'anon'::regrole);

-- Tablas y vistas existentes de public: los cuatro permisos de anon.
insert into privado.respaldo_permisos_39 (tipo, objeto, rol, privilegio)
select distinct 'tabla', c.oid::regclass::text, 'anon', a.privilege_type
from pg_class c
cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
where c.relnamespace = 'public'::regnamespace
  and c.relkind in ('r', 'v', 'm', 'p', 'f')
  and a.grantee = 'anon'::regrole
  and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN');

-- Permisos por defecto de las tablas nuevas que cree postgres en public.
insert into privado.respaldo_permisos_39 (tipo, objeto, rol, privilegio)
select distinct 'por_defecto', 'tablas nuevas de public (postgres)', 'anon', a.privilege_type
from pg_default_acl d
cross join lateral aclexplode(d.defaclacl) a
where d.defaclrole = 'postgres'::regrole
  and d.defaclnamespace = 'public'::regnamespace
  and d.defaclobjtype = 'r'
  and a.grantee = 'anon'::regrole
  and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN');

-- ---------------------------------------------------------------------
-- 2. Quitar permisos
-- ---------------------------------------------------------------------

-- A. Funciones de trigger.
revoke execute on function public.rls_auto_enable()              from public, anon;
revoke execute on function public.categorias_web_antes_guardar() from public, anon;

-- B. Tablas existentes (B1) y por defecto (B2). MAINTAIN existe desde PostgreSQL 17.
do $$
declare
  privs text := 'truncate, references, trigger'
                || case when current_setting('server_version_num')::int >= 170000 then ', maintain' else '' end;
begin
  execute format('revoke %s on all tables in schema public from anon', privs);
  execute format('alter default privileges for role postgres in schema public revoke %s on tables from anon', privs);
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Verificación
-- ---------------------------------------------------------------------

set local role anon;
select set_config('e47_39.catalogo_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
select set_config('e47_39.categorias_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.categorias_web_publica c)::text, true);
reset role;

do $$
declare
  lista text;
begin
  -- 3.1 La tienda ve lo mismo.
  if current_setting('e47_39.catalogo_antes')::jsonb <> current_setting('e47_39.catalogo_despues')::jsonb then
    raise exception 'Verificación: como anon, catalogo_web no devuelve lo mismo que antes.';
  end if;
  if current_setting('e47_39.categorias_antes')::jsonb <> current_setting('e47_39.categorias_despues')::jsonb then
    raise exception 'Verificación: como anon, categorias_web_publica no devuelve lo mismo que antes.';
  end if;

  -- 3.2 anon no puede ejecutar ninguna función propia de public (sin contar extensiones).
  select string_agg(p.oid::regprocedure::text, ', ') into lista
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace
    and has_function_privilege('anon', p.oid, 'EXECUTE')
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e');
  if lista is not null then
    raise exception 'Verificación: anon todavía puede ejecutar: %', lista;
  end if;

  -- 3.3 Los triggers siguen como estaban.
  if coalesce((select string_agg(x, ',' order by x) from (
       select format('%s/%s/%s', t.tgname::text, t.tgrelid::regclass::text, t.tgenabled::text) as x
       from pg_trigger t
       where t.tgfoid in (to_regprocedure('public.categorias_web_antes_guardar()'),
                          to_regprocedure('public.rls_auto_enable()'))
         and not t.tgisinternal
       union all
       select format('%s/%s/%s', e.evtname::text, e.evtevent::text, e.evtenabled::text)
       from pg_event_trigger e
       where e.evtfoid in (to_regprocedure('public.categorias_web_antes_guardar()'),
                           to_regprocedure('public.rls_auto_enable()'))
     ) t), '') <> current_setting('e47_39.triggers_antes') then
    raise exception 'Verificación: los triggers de las dos funciones han cambiado.';
  end if;

  -- 3.4 anon sin TRUNCATE/REFERENCES/TRIGGER/MAINTAIN en tablas existentes de public.
  select string_agg(distinct c.oid::regclass::text, ', ') into lista
  from pg_class c
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r', 'v', 'm', 'p', 'f')
    and a.grantee = 'anon'::regrole
    and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN');
  if lista is not null then
    raise exception 'Verificación: anon conserva permisos de mantenimiento en: % (¿dueño distinto de postgres?)', lista;
  end if;

  -- 3.5 Ni en los permisos por defecto de postgres en public.
  if exists (select 1 from pg_default_acl d cross join lateral aclexplode(d.defaclacl) a
             where d.defaclrole = 'postgres'::regrole
               and d.defaclnamespace = 'public'::regnamespace
               and d.defaclobjtype = 'r'
               and a.grantee = 'anon'::regrole
               and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN')) then
    raise exception 'Verificación: los permisos por defecto siguen dando esos permisos a anon.';
  end if;

  -- 3.6 La tienda conserva lo que usa.
  if not has_table_privilege('anon', 'public.catalogo_web', 'SELECT')
     or not has_table_privilege('anon', 'public.categorias_web_publica', 'SELECT') then
    raise exception 'Verificación: anon ya no puede leer las vistas públicas.';
  end if;

  raise notice 'Verificación correcta: % permisos quitados (detalle en privado.respaldo_permisos_39). La tienda ve lo mismo.',
    (select count(*) from privado.respaldo_permisos_39);
end;
$$;

notify pgrst, 'reload schema';

commit;

-- Después de ejecutar: guardar una categoría en la app de Producciones
-- ("Categorías web") para confirmar que su trigger sigue funcionando, y
-- abrir la tienda con Ctrl+Shift+R.
