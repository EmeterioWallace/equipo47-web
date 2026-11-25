-- =====================================================================
-- 38_precio_publico_privado.sql  ·  Producciones  ·  25/11/2026
-- Petición de precios del 25/11 en el buzón, punto 2. La web confirmó el 25/11
-- que ya no llama a calcular_precio_publico.
-- REQUIERE: script 37 ejecutado. Antes, ejecutar 38_diagnostico_precio_publico.sql
-- y revisar su resultado.
--
-- Problema: con la clave pública cualquiera puede llamar a
--   /rest/v1/rpc/calcular_precio_publico con la cantidad que quiera y sacar la
--   escala completa de precios.
--
-- Por qué NO basta con revocar EXECUTE a anon: catalogo_web llama a la función
-- por dentro, y PostgreSQL comprueba el permiso EXECUTE de las funciones de una
-- vista con el rol que consulta (anon), no con el dueño de la vista. Sin EXECUTE,
-- la tienda dejaría de recibir productos.
--
-- Qué hace:
--   1. Crea el esquema "privado". No está en los esquemas expuestos por la API,
--      así que PostgREST (y GraphQL) no publican nada de lo que haya dentro.
--   2. Mueve la función ahí con ALTER FUNCTION ... SET SCHEMA. Es la misma
--      función (mismo OID, código, SECURITY DEFINER, search_path y dueño).
--      catalogo_web la tiene enlazada por OID, así que pasa a llamar a
--      privado.calcular_precio_publico sin recrear la vista: su texto solo cambia
--      en el nombre del esquema de la función. Nada más de la vista cambia.
--   3. Permisos de la función: se quita EXECUTE a PUBLIC (por defecto PostgreSQL
--      se lo da a todo el mundo) y se da explícitamente a anon, authenticated y
--      service_role (los que la usan a través de la vista). USAGE del esquema
--      para anon y authenticated.
--   4. Guarda los permisos originales en privado.respaldo_permisos_38 para que
--      el rollback los deje exactamente como estaban.
--
-- Verificación (si algo no cuadra, aborta y no se guarda nada):
--   · Como rol anon, catalogo_web devuelve los mismos productos con los mismos
--     valores (precios incluidos) que antes del cambio.
--   · public.calcular_precio_publico ya no existe.
--   · La función movida es idéntica a la original.
--   · La definición de catalogo_web es la del 37 con privado.calcular_precio_publico.
--
-- Qué NO hace:
--   - No cambia la fórmula de precio ni la vista.
--   - No cambia los permisos por defecto del esquema public (Supabase da EXECUTE
--     a anon en toda función nueva creada en public). Ver nota al final.
--
-- Se ejecuta entero, de una vez, en el SQL Editor. Todo va en una transacción.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Comprobaciones previas
-- ---------------------------------------------------------------------

do $$
declare
  f      oid := to_regprocedure('public.calcular_precio_publico(uuid, integer)');
  n      integer;
  lista  text;
begin
  if exists (select 1 from pg_namespace where nspname = 'privado') then
    raise exception 'El esquema "privado" ya existe: parece que este script ya se ejecutó. No se cambia nada.';
  end if;

  if f is null then
    raise exception 'No existe public.calcular_precio_publico(uuid, integer). No se cambia nada.';
  end if;

  -- Una sola función con ese nombre: si hubiera otra versión (otros parámetros),
  -- seguiría abierta al público.
  select count(*), string_agg(p.oid::regprocedure::text, ', ') into n, lista
  from pg_proc p where p.proname = 'calcular_precio_publico';
  if n <> 1 then
    raise exception 'Hay % funciones llamadas calcular_precio_publico (%). Se esperaba una. No se cambia nada.', n, lista;
  end if;

  -- Para moverla hay que ser su dueño (o miembro del rol dueño).
  if not pg_has_role(current_user, (select proowner from pg_proc where oid = f), 'MEMBER') then
    raise exception 'El usuario % no es dueño de la función (dueño: %). No se cambia nada.',
      current_user, (select proowner::regrole from pg_proc where oid = f);
  end if;

  -- Solo catalogo_web depende de ella.
  select string_agg(distinct coalesce(rw.ev_class::regclass::text, d.classid::regclass::text || ' ' || d.objid), ', ')
    into lista
  from pg_depend d
  left join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
  where d.refclassid = 'pg_proc'::regclass and d.refobjid = f and d.deptype = 'n'
    and rw.ev_class is distinct from 'public.catalogo_web'::regclass;
  if lista is not null then
    raise exception 'Además de catalogo_web, dependen de la función: %. No se cambia nada.', lista;
  end if;

  -- Ninguna otra función la llama por su nombre (dejaría de encontrarla).
  select string_agg(p.oid::regprocedure::text, ', ') into lista
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where p.oid <> f
    and ns.nspname not in ('pg_catalog', 'information_schema')
    and p.prosrc ilike '%calcular_precio_publico%';
  if lista is not null then
    raise exception 'Estas funciones llaman a calcular_precio_publico en su código: %. No se cambia nada.', lista;
  end if;

  if (select reloptions from pg_class where oid = 'public.catalogo_web'::regclass)
       is distinct from array['security_invoker=false'] then
    raise exception 'catalogo_web tiene otras opciones de seguridad. No se cambia nada.';
  end if;

  if not has_function_privilege('anon', f, 'EXECUTE') then
    raise exception 'anon ya no puede ejecutar la función: la tienda estaría fallando ahora mismo. Revisar antes de seguir.';
  end if;

  raise notice 'Permisos actuales de la función: %',
    coalesce((select proacl::text from pg_proc where oid = f), '(null: por defecto, EXECUTE para PUBLIC)');
end;
$$;

-- 0.1 catalogo_web es exactamente la del script 37 (copia literal de su SELECT).
create temp view _esperada_catalogo_web_38 as
select
  p.id,
  coalesce(p.titulo_publico, p.nombre) as titulo,
  p.descripcion_publica as descripcion,
  p.especificaciones_publicas as especificaciones,
  p.detalles_publicos as detalles,
  p.opciones_personalizacion as opciones,
  case when p.categoria_id is not null then r.sport       else p.deporte_web      end as sport,
  case when p.categoria_id is not null then r.category    else p.tipo_web         end as category,
  case when p.categoria_id is not null then r.subcategory else p.subcategoria_web end as subcategory,
  p.genero as gender,
  p.moq,
  p.imagen_archivo as image,
  cp.precio as precio_final,
  coalesce(cp.aproximado, false) as precio_aproximado,
  (
    select coalesce(json_agg(json_build_object('nombre', c.nombre_color, 'imagen', c.imagen_archivo)
                             order by coalesce(c.orden, 999999), c.nombre_color), '[]'::json)
    from public.producto_colores_web c
    where c.producto_id = p.id
  ) as colores,
  p.orden_web,
  p.categoria_id,
  p.destacado_web,
  p.orden_destacado
from public.productos p
left join public.categorias_web_ruta r on r.id = p.categoria_id
left join lateral public.calcular_precio_publico(p.id, p.moq) cp(precio, aproximado) on true
where p.publicado = true and p.activo = true
  and (p.categoria_id is null or (r.rama_activa and not r.rama_proximamente))
order by
  case when p.categoria_id is not null then r.sport    else p.deporte_web end,
  case when p.categoria_id is not null then r.category else p.tipo_web    end,
  coalesce(p.orden_web, 999999),
  coalesce(p.titulo_publico, p.nombre);

do $$
declare
  def_real     text := pg_get_viewdef('public.catalogo_web'::regclass, true);
  def_esperada text := pg_get_viewdef('pg_temp._esperada_catalogo_web_38'::regclass, true);
begin
  if regexp_replace(def_real, '[[:space:]]+', '', 'g') <> regexp_replace(def_esperada, '[[:space:]]+', '', 'g') then
    raise exception E'catalogo_web no es la del script 37. No se cambia nada. Definición actual:\n%', def_real;
  end if;
end;
$$;

drop view pg_temp._esperada_catalogo_web_38;

-- 0.2 Foto de lo que ve la tienda AHORA, consultando como anon (igual que la web).
--     Se guarda en una variable de la transacción, no en una tabla, para que
--     anon no necesite permisos de escritura.
set local role anon;
select set_config('e47_38.catalogo_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text,
  true);
reset role;

-- 0.3 Huella de la función (todo menos esquema y permisos), para comprobar que
--     después de moverla es la misma.
select set_config('e47_38.funcion_antes',
  (select md5((to_jsonb(p) - 'pronamespace' - 'proacl')::text)
   from pg_proc p where p.oid = to_regprocedure('public.calcular_precio_publico(uuid, integer)')),
  true);

do $$
begin
  if jsonb_array_length(current_setting('e47_38.catalogo_antes')::jsonb) = 0 then
    raise exception 'Como anon, catalogo_web devuelve 0 productos: la comparación no probaría nada. Revisar antes de seguir.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Esquema privado y respaldo de permisos
-- ---------------------------------------------------------------------

create schema privado;
comment on schema privado is
  'Funciones internas que usan las vistas públicas y que no deben poder llamarse desde la API. '
  'NO añadir a Settings → API → Exposed schemas. Script 38 (25/11/2026).';

grant usage on schema privado to anon, authenticated;

create table privado.respaldo_permisos_38 (
  objeto   text primary key,
  acl      aclitem[],
  guardado timestamptz not null default now()
);
alter table privado.respaldo_permisos_38 enable row level security;
revoke all on table privado.respaldo_permisos_38 from public, anon, authenticated;
comment on table privado.respaldo_permisos_38 is
  'Permisos de calcular_precio_publico antes del script 38. Los usa 38_precio_publico_privado_rollback.sql. No borrar.';

insert into privado.respaldo_permisos_38 (objeto, acl)
select 'calcular_precio_publico', p.proacl
from pg_proc p
where p.oid = to_regprocedure('public.calcular_precio_publico(uuid, integer)');

-- ---------------------------------------------------------------------
-- 2. Mover la función y ajustar sus permisos
-- ---------------------------------------------------------------------

alter function public.calcular_precio_publico(uuid, integer) set schema privado;

revoke execute on function privado.calcular_precio_publico(uuid, integer) from public;
grant  execute on function privado.calcular_precio_publico(uuid, integer) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Verificación: si algo no cuadra, aborta y no se guarda nada
-- ---------------------------------------------------------------------

-- 3.1 Definición esperada de catalogo_web: la del 37 con la función en privado.
create temp view _esperada_catalogo_web_38_despues as
select
  p.id,
  coalesce(p.titulo_publico, p.nombre) as titulo,
  p.descripcion_publica as descripcion,
  p.especificaciones_publicas as especificaciones,
  p.detalles_publicos as detalles,
  p.opciones_personalizacion as opciones,
  case when p.categoria_id is not null then r.sport       else p.deporte_web      end as sport,
  case when p.categoria_id is not null then r.category    else p.tipo_web         end as category,
  case when p.categoria_id is not null then r.subcategory else p.subcategoria_web end as subcategory,
  p.genero as gender,
  p.moq,
  p.imagen_archivo as image,
  cp.precio as precio_final,
  coalesce(cp.aproximado, false) as precio_aproximado,
  (
    select coalesce(json_agg(json_build_object('nombre', c.nombre_color, 'imagen', c.imagen_archivo)
                             order by coalesce(c.orden, 999999), c.nombre_color), '[]'::json)
    from public.producto_colores_web c
    where c.producto_id = p.id
  ) as colores,
  p.orden_web,
  p.categoria_id,
  p.destacado_web,
  p.orden_destacado
from public.productos p
left join public.categorias_web_ruta r on r.id = p.categoria_id
left join lateral privado.calcular_precio_publico(p.id, p.moq) cp(precio, aproximado) on true
where p.publicado = true and p.activo = true
  and (p.categoria_id is null or (r.rama_activa and not r.rama_proximamente))
order by
  case when p.categoria_id is not null then r.sport    else p.deporte_web end,
  case when p.categoria_id is not null then r.category else p.tipo_web    end,
  coalesce(p.orden_web, 999999),
  coalesce(p.titulo_publico, p.nombre);

-- 3.2 Lo que ve la tienda DESPUÉS, otra vez como anon.
set local role anon;
select set_config('e47_38.catalogo_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text,
  true);
reset role;

do $$
declare
  f          oid := to_regprocedure('privado.calcular_precio_publico(uuid, integer)');
  antes      jsonb := current_setting('e47_38.catalogo_antes')::jsonb;
  despues    jsonb := current_setting('e47_38.catalogo_despues')::jsonb;
  def_real     text := pg_get_viewdef('public.catalogo_web'::regclass, true);
  def_esperada text := pg_get_viewdef('pg_temp._esperada_catalogo_web_38_despues'::regclass, true);
  n          integer;
begin
  -- 3.3 public.calcular_precio_publico ya no existe (ni con otros parámetros).
  if to_regprocedure('public.calcular_precio_publico(uuid, integer)') is not null
     or exists (select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
                where ns.nspname = 'public' and p.proname = 'calcular_precio_publico') then
    raise exception 'Verificación: public.calcular_precio_publico sigue existiendo.';
  end if;

  -- 3.4 La función movida es la misma.
  if f is null then
    raise exception 'Verificación: no existe privado.calcular_precio_publico(uuid, integer).';
  end if;
  if (select md5((to_jsonb(p) - 'pronamespace' - 'proacl')::text) from pg_proc p where p.oid = f)
       <> current_setting('e47_38.funcion_antes') then
    raise exception 'Verificación: la función movida no es idéntica a la original.';
  end if;

  -- 3.5 catalogo_web: misma definición salvo el esquema de la función, mismas opciones.
  if regexp_replace(def_real, '[[:space:]]+', '', 'g') <> regexp_replace(def_esperada, '[[:space:]]+', '', 'g') then
    raise exception E'Verificación: catalogo_web no es la esperada. Definición actual:\n%', def_real;
  end if;
  if (select reloptions from pg_class where oid = 'public.catalogo_web'::regclass)
       is distinct from array['security_invoker=false'] then
    raise exception 'Verificación: catalogo_web ha perdido security_invoker=false.';
  end if;

  -- 3.6 Como anon: mismos productos, mismos valores, precios incluidos.
  if antes <> despues then
    select count(*) into n
    from (select e from jsonb_array_elements(antes) e
          except
          select e from jsonb_array_elements(despues) e) dif;
    raise exception 'Verificación: como anon, catalogo_web cambia. Antes % productos, después %; % filas distintas.',
      jsonb_array_length(antes), jsonb_array_length(despues), n;
  end if;

  -- 3.7 Permisos: los que necesita la vista, y PUBLIC fuera.
  if not has_function_privilege('anon', f, 'EXECUTE')
     or not has_function_privilege('authenticated', f, 'EXECUTE')
     or not has_schema_privilege('anon', 'privado', 'USAGE')
     or not has_table_privilege('anon', 'public.catalogo_web', 'SELECT') then
    raise exception 'Verificación: anon/authenticated no tienen los permisos que necesita catalogo_web.';
  end if;
  if exists (select 1 from aclexplode((select proacl from pg_proc where oid = f)) a where a.grantee = 0) then
    raise exception 'Verificación: PUBLIC sigue teniendo EXECUTE sobre la función.';
  end if;
  if has_table_privilege('anon', 'privado.respaldo_permisos_38', 'SELECT') then
    raise exception 'Verificación: anon puede leer la tabla de respaldo.';
  end if;

  -- 3.8 "privado" no está entre los esquemas expuestos (si la config está en la base).
  if exists (select 1 from pg_roles
             where rolname = 'authenticator' and rolconfig::text ilike '%privado%') then
    raise exception 'Verificación: el esquema privado aparece en la configuración de la API (authenticator).';
  end if;

  raise notice 'Verificación correcta: % productos en catalogo_web, iguales que antes (vistos como anon). public.calcular_precio_publico ya no existe.',
    jsonb_array_length(despues);
end;
$$;

drop view pg_temp._esperada_catalogo_web_38_despues;

-- Que la API olvide ya la función (Supabase suele hacerlo solo al cambiar el esquema).
notify pgrst, 'reload schema';

commit;

-- ---------------------------------------------------------------------
-- Después de ejecutar (fuera de la transacción):
--   1. Supabase → Settings → API → "Exposed schemas": comprobar que "privado" NO está.
--   2. La llamada pública debe fallar (404, PGRST202). Desde PowerShell:
--        $k = (Select-String -Path prototipo-catalogo\js\catalogo-web.js -Pattern "SUPABASE_ANON_KEY = '(.+)'").Matches[0].Groups[1].Value
--        Invoke-RestMethod -Method Post -Uri https://ciszgyorsveumnrtcejn.supabase.co/rest/v1/rpc/calcular_precio_publico `
--          -Headers @{ apikey = $k; Authorization = "Bearer $k" } -ContentType 'application/json' `
--          -Body '{"p_producto_id":"00000000-0000-0000-0000-000000000000","p_cantidad":50}'
--   3. Abrir tienda-prototipo.html con Ctrl+Shift+R: salen productos y precios.
--
-- NOTA para cambios futuros de la fórmula: la función vive en privado. Cualquier
-- "create or replace function" debe ir a privado.calcular_precio_publico. Si se
-- crea sin esquema, acabaría en public y Supabase le daría EXECUTE a anon por
-- defecto: volvería a quedar abierta (y la vista seguiría usando la de privado).
-- ---------------------------------------------------------------------
