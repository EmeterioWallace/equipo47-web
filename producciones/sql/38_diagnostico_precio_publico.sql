-- =====================================================================
-- 38_diagnostico_precio_publico.sql  ·  Producciones  ·  25/11/2026
-- SOLO LECTURA. No cambia nada. Ejecutar ANTES del script 38.
--
-- Para qué sirve (petición de precios del 25/11 en el buzón):
--   · Punto 1: ver la definición REAL de calcular_precio_publico y de catalogo_web
--     para confirmar que precio_final es el precio del tramo del MOQ (o el
--     aproximado) y que ninguna columna deja deducir otros tramos.
--   · Punto 2: ver los permisos reales (de la función, de PUBLIC, por defecto)
--     antes de moverla al esquema "privado".
--
-- Devuelve UNA sola tabla (orden, seccion, detalle) porque el SQL Editor solo
-- enseña el resultado de la última consulta. Copiar el resultado entero
-- (botón "Copy" / exportar CSV) y pegarlo en el chat de Producciones.
-- =====================================================================

with f as (
  select p.oid
  from pg_proc p
  where p.proname = 'calcular_precio_publico'
)
select orden, seccion, detalle
from (
  -- ---- La función -------------------------------------------------------
  select 1 as orden, 'funcion: firma'::text as seccion,
         coalesce((select string_agg(oid::regprocedure::text, E'\n') from f), '(no existe)') as detalle
  union all
  select 2, 'funcion: definicion completa',
         coalesce((select string_agg(pg_get_functiondef(oid), E'\n-----\n') from f), '(no existe)')
  union all
  select 3, 'funcion: devuelve / security definer / config / dueño / volatilidad / idioma',
         (select string_agg(format('devuelve=%s · security_definer=%s · config=%s · dueño=%s · volatilidad=%s · idioma=%s',
                                   pg_get_function_result(p.oid), p.prosecdef,
                                   coalesce(p.proconfig::text, '(ninguna)'),
                                   p.proowner::regrole, p.provolatile, l.lanname), E'\n')
          from f join pg_proc p on p.oid = f.oid join pg_language l on l.oid = p.prolang)
  union all
  select 4, 'funcion: permisos (proacl; null = por defecto = EXECUTE para PUBLIC)',
         (select string_agg(coalesce(p.proacl::text, '(null)'), E'\n') from f join pg_proc p on p.oid = f.oid)
  union all
  select 5, 'funcion: roles que pueden ejecutarla (incluye lo heredado de PUBLIC)',
         (select string_agg(r, ', ' order by r)
          from f, unnest(array['anon', 'authenticated', 'service_role']) r
          where has_function_privilege(r::name, f.oid, 'EXECUTE'))
  union all
  select 6, 'funcion: objetos que dependen de ella (vistas, etc.)',
         coalesce((select string_agg(distinct coalesce(rw.ev_class::regclass::text,
                                                       d.classid::regclass::text || ' ' || d.objid), ', ')
                   from f
                   join pg_depend d on d.refclassid = 'pg_proc'::regclass and d.refobjid = f.oid and d.deptype = 'n'
                   left join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid),
                  '(ninguno)')
  union all
  select 7, 'funcion: otras funciones que la nombran en su código',
         coalesce((select string_agg(p.oid::regprocedure::text, ', ')
                   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname not in ('pg_catalog', 'information_schema')
                     and p.proname <> 'calcular_precio_publico'
                     and p.prosrc ilike '%calcular_precio_publico%'),
                  '(ninguna)')

  -- ---- La vista ----------------------------------------------------------
  union all
  select 10, 'catalogo_web: definicion', pg_get_viewdef('public.catalogo_web'::regclass, true)
  union all
  select 11, 'catalogo_web: opciones', coalesce((select reloptions::text from pg_class where oid = 'public.catalogo_web'::regclass), '(ninguna)')
  union all
  select 12, 'catalogo_web: columnas',
         (select string_agg(column_name || ' ' || data_type, ', ' order by ordinal_position)
          from information_schema.columns where table_schema = 'public' and table_name = 'catalogo_web')
  union all
  select 13, 'catalogo_web: resumen de precios',
         (select format('productos=%s · sin precio=%s · aproximados=%s · moq distintos=%s',
                        count(*), count(*) filter (where precio_final is null),
                        count(*) filter (where precio_aproximado), count(distinct moq))
          from public.catalogo_web)

  -- ---- Qué más ve anon ---------------------------------------------------
  union all
  select 20, 'public: funciones que anon puede ejecutar (sin las de extensiones)',
         coalesce((select string_agg(p.oid::regprocedure::text || case when p.prosecdef then '  [SECURITY DEFINER]' else '' end,
                                     E'\n' order by p.proname)
                   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public'
                     and has_function_privilege('anon', p.oid, 'EXECUTE')
                     and not exists (select 1 from pg_depend d
                                     where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')),
                  '(ninguna)')
  union all
  select 21, 'public: tablas y vistas en las que anon puede leer alguna columna',
         coalesce((select string_agg(c.relname || ' (' || c.relkind || ')', ', ' order by c.relname)
                   from pg_class c join pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f')
                     and has_any_column_privilege('anon', c.oid, 'SELECT')),
                  '(ninguna)')

  -- ---- Permisos por defecto y API ---------------------------------------
  union all
  select 30, 'permisos por defecto (pg_default_acl; tipo f = funciones, r = tablas)',
         coalesce((select string_agg(format('rol=%s · esquema=%s · tipo=%s · %s',
                                            d.defaclrole::regrole, coalesce(n.nspname, '(todos)'),
                                            d.defaclobjtype, d.defaclacl), E'\n'
                                     order by d.defaclrole::regrole::text, n.nspname, d.defaclobjtype)
                   from pg_default_acl d left join pg_namespace n on n.oid = d.defaclnamespace),
                  '(ninguno)')
  union all
  select 31, 'esquema privado: ya existe?', exists (select 1 from pg_namespace where nspname = 'privado')::text
  union all
  select 32, 'authenticator: configuración (esquemas expuestos si están aquí)',
         coalesce((select rolconfig::text from pg_roles where rolname = 'authenticator'), '(sin config)')
  union all
  select 33, 'extensiones instaladas',
         (select string_agg(extname || ' ' || extversion, ', ' order by extname) from pg_extension)
) x
order by orden;
