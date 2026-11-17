-- =====================================================================
-- 37_destacados_e_imagen_portada.sql  ·  Producciones  ·  17/11/2026
-- Petición de la web en el buzón (16/11 y 17/11) y decisiones de Guille (17/11):
--   · Productos destacados en la portada, con orden propio.
--   · Imagen de portada por categoría.
-- REQUIERE: scripts 34, 35 y 36 ejecutados.
--
-- Qué hace:
--   1. productos.destacado_web   boolean NOT NULL DEFAULT false
--      productos.orden_destacado integer (10, 20, 30... como orden_web; vacío = al final)
--   2. categorias_web.imagen_portada text (solo el nombre del archivo, como imagen_archivo;
--      vacío = la web usa la foto del primer producto de la categoría).
--   3. catalogo_web: añade destacado_web y orden_destacado AL FINAL.
--   4. categorias_web_publica: añade imagen_portada AL FINAL.
--   Las columnas existentes, su orden, los filtros, el ORDER BY, las opciones de
--   seguridad y los permisos de las dos vistas no cambian.
--
-- Partir de la definición real: antes de tocar nada, el paso 0 compara la definición
-- que hay HOY en Supabase (pg_get_viewdef) con la de los scripts 35 y 34. Si no son
-- idénticas, aborta y enseña la definición actual: no se pisa nada que no conozcamos.
--
-- Qué NO hace:
--   - No toca calcular_precio_publico ni ningún precio (en pausa, ver sección 3 del buzón).
--   - No limita el número de destacados: la web enseña 4 y la app avisa si hay más.
--
-- Se ejecuta entero, de una vez, en el SQL Editor. Todo va en una transacción:
-- si algo falla, no se guarda nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Comprobaciones previas
-- ---------------------------------------------------------------------

-- 0.1 Definiciones esperadas, como vistas temporales (desaparecen al terminar).
--     Copia literal de la SELECT del script 35 (catalogo_web) y del 34 (categorias_web_publica).
create temp view _esperada_catalogo_web_37 as
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
  p.categoria_id
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

create temp view _esperada_categorias_web_publica_37 as
select c.id, c.slug, c.nombre, c.padre_id, c.nivel, c.orden, c.proximamente
from public.categorias_web c
join public.categorias_web_ruta r on r.id = c.id
where r.rama_activa;

do $$
declare
  def_real      text;
  def_esperada  text;
  opciones      text[];
  -- Se comparan sin espacios ni saltos de línea, para no depender del formato.
  norm constant text := '[[:space:]]+';
begin
  -- 0.2 Las columnas nuevas no existen todavía (el script no se ha ejecutado antes).
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'productos'
               and column_name in ('destacado_web', 'orden_destacado'))
  or exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'categorias_web'
               and column_name = 'imagen_portada') then
    raise exception 'Las columnas de este script ya existen: parece que ya se ejecutó. No se cambia nada.';
  end if;

  -- 0.3 catalogo_web es exactamente la del script 35.
  def_real     := pg_get_viewdef('public.catalogo_web'::regclass, true);
  def_esperada := pg_get_viewdef('pg_temp._esperada_catalogo_web_37'::regclass, true);
  if regexp_replace(def_real, norm, '', 'g') <> regexp_replace(def_esperada, norm, '', 'g') then
    raise exception E'catalogo_web no es la del script 35. No se cambia nada. Definición actual:\n%', def_real;
  end if;

  select c.reloptions into opciones from pg_class c where c.oid = 'public.catalogo_web'::regclass;
  if opciones is distinct from array['security_invoker=false'] then
    raise exception 'catalogo_web tiene otras opciones de seguridad (%). No se cambia nada.', opciones;
  end if;

  -- 0.4 categorias_web_publica es exactamente la del script 34.
  def_real     := pg_get_viewdef('public.categorias_web_publica'::regclass, true);
  def_esperada := pg_get_viewdef('pg_temp._esperada_categorias_web_publica_37'::regclass, true);
  if regexp_replace(def_real, norm, '', 'g') <> regexp_replace(def_esperada, norm, '', 'g') then
    raise exception E'categorias_web_publica no es la del script 34. No se cambia nada. Definición actual:\n%', def_real;
  end if;

  select c.reloptions into opciones from pg_class c where c.oid = 'public.categorias_web_publica'::regclass;
  if opciones is distinct from array['security_barrier=true'] then
    raise exception 'categorias_web_publica tiene otras opciones de seguridad (%). No se cambia nada.', opciones;
  end if;
end;
$$;

drop view pg_temp._esperada_catalogo_web_37;
drop view pg_temp._esperada_categorias_web_publica_37;

-- 0.5 Foto de lo que devuelven las vistas ahora, para comparar al final.
create temp table _catalogo_antes_37 on commit drop as
select c.id, to_jsonb(c) as fila from public.catalogo_web c;

create temp table _categorias_antes_37 on commit drop as
select c.id, to_jsonb(c) as fila from public.categorias_web_publica c;

-- ---------------------------------------------------------------------
-- 1. Columnas nuevas
-- ---------------------------------------------------------------------

alter table public.productos
  add column destacado_web   boolean not null default false,
  add column orden_destacado integer;

comment on column public.productos.destacado_web   is 'Sale en la fila de destacados de la portada de la web (solo si está publicado y su categoría se ve). La web enseña 4.';
comment on column public.productos.orden_destacado is 'Posición entre los destacados (10, 20, 30...). Vacío = al final. Se cambia con las flechas en "Categorías web".';

alter table public.categorias_web
  add column imagen_portada text
  constraint categorias_web_imagen_portada_check
    check (imagen_portada is null
           or (imagen_portada = btrim(imagen_portada)
               and imagen_portada <> ''
               and imagen_portada !~ '[/\\]'));

comment on column public.categorias_web.imagen_portada is 'Foto de la tarjeta de la categoría en la portada. Solo el nombre del archivo (de cualquier carpeta de images/products/). Vacío = foto del primer producto.';

-- ---------------------------------------------------------------------
-- 2. catalogo_web: la del 35 + destacado_web y orden_destacado al final
-- ---------------------------------------------------------------------

create or replace view public.catalogo_web
with (security_invoker = false) as
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
    from producto_colores_web c
    where c.producto_id = p.id
  ) as colores,
  p.orden_web,
  p.categoria_id,
  p.destacado_web,
  p.orden_destacado
from productos p
left join categorias_web_ruta r on r.id = p.categoria_id
left join lateral calcular_precio_publico(p.id, p.moq) cp(precio, aproximado) on true
where p.publicado = true and p.activo = true
  and (p.categoria_id is null or (r.rama_activa and not r.rama_proximamente))
order by
  case when p.categoria_id is not null then r.sport    else p.deporte_web end,
  case when p.categoria_id is not null then r.category else p.tipo_web    end,
  coalesce(p.orden_web, 999999),
  coalesce(p.titulo_publico, p.nombre);

grant select on public.catalogo_web to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. categorias_web_publica: la del 34 + imagen_portada al final
-- ---------------------------------------------------------------------

create or replace view public.categorias_web_publica
with (security_barrier = true) as
select c.id, c.slug, c.nombre, c.padre_id, c.nivel, c.orden, c.proximamente, c.imagen_portada
from public.categorias_web c
join public.categorias_web_ruta r on r.id = c.id
where r.rama_activa;

grant select on public.categorias_web_publica to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Verificación: si algo no cuadra, aborta y no se guarda nada
-- ---------------------------------------------------------------------

do $$
declare
  n        integer;
  columnas text;
begin
  -- 4.1 Columnas de catalogo_web: las de antes, en el mismo orden, y las dos nuevas al final.
  select string_agg(column_name, ',' order by ordinal_position) into columnas
  from information_schema.columns
  where table_schema = 'public' and table_name = 'catalogo_web';
  if columnas <> 'id,titulo,descripcion,especificaciones,detalles,opciones,sport,category,subcategory,gender,moq,image,precio_final,precio_aproximado,colores,orden_web,categoria_id,destacado_web,orden_destacado' then
    raise exception 'Verificación: columnas de catalogo_web inesperadas: %', columnas;
  end if;

  select string_agg(column_name, ',' order by ordinal_position) into columnas
  from information_schema.columns
  where table_schema = 'public' and table_name = 'categorias_web_publica';
  if columnas <> 'id,slug,nombre,padre_id,nivel,orden,proximamente,imagen_portada' then
    raise exception 'Verificación: columnas de categorias_web_publica inesperadas: %', columnas;
  end if;

  -- 4.2 Mismos productos y mismos valores en las columnas de siempre.
  select count(*) into n
  from (
    select id, fila from _catalogo_antes_37
    except
    select c.id, to_jsonb(c) - 'destacado_web' - 'orden_destacado' from public.catalogo_web c
  ) dif;
  if n > 0 then
    raise exception 'Verificación: % productos de catalogo_web cambian o desaparecen.', n;
  end if;
  select count(*) into n from public.catalogo_web c
  where not exists (select 1 from _catalogo_antes_37 a where a.id = c.id);
  if n > 0 then
    raise exception 'Verificación: % productos aparecen en catalogo_web y antes no estaban.', n;
  end if;

  -- 4.3 Mismas categorías y mismos valores.
  select count(*) into n
  from (
    select id, fila from _categorias_antes_37
    except
    select c.id, to_jsonb(c) - 'imagen_portada' from public.categorias_web_publica c
  ) dif;
  if n > 0 or (select count(*) from public.categorias_web_publica) <> (select count(*) from _categorias_antes_37) then
    raise exception 'Verificación: categorias_web_publica no devuelve las mismas categorías que antes.';
  end if;

  -- 4.4 Opciones de seguridad intactas.
  if (select reloptions from pg_class where oid = 'public.catalogo_web'::regclass)
       is distinct from array['security_invoker=false'] then
    raise exception 'Verificación: catalogo_web ha perdido security_invoker=false.';
  end if;
  if (select reloptions from pg_class where oid = 'public.categorias_web_publica'::regclass)
       is distinct from array['security_barrier=true'] then
    raise exception 'Verificación: categorias_web_publica ha perdido security_barrier=true.';
  end if;

  -- 4.5 Permisos: anon puede leer las vistas; la app (authenticated) puede escribir las columnas nuevas.
  if not has_table_privilege('anon', 'public.catalogo_web', 'SELECT')
     or not has_table_privilege('anon', 'public.categorias_web_publica', 'SELECT') then
    raise exception 'Verificación: anon no puede leer las vistas públicas.';
  end if;
  if not has_column_privilege('authenticated', 'public.productos', 'destacado_web',   'UPDATE')
     or not has_column_privilege('authenticated', 'public.productos', 'orden_destacado', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.categorias_web', 'imagen_portada', 'UPDATE') then
    raise exception 'Verificación: la app no podría guardar las columnas nuevas (permisos de authenticated).';
  end if;

  raise notice 'Verificación correcta: % productos en catalogo_web y % categorías en categorias_web_publica, con los mismos datos que antes y las columnas nuevas al final.',
    (select count(*) from public.catalogo_web), (select count(*) from public.categorias_web_publica);
end;
$$;

commit;

-- Comprobación (solo lectura), después de ejecutar:
-- select id, titulo, orden_web, categoria_id, destacado_web, orden_destacado from public.catalogo_web limit 5;
-- select id, slug, nombre, nivel, orden, proximamente, imagen_portada from public.categorias_web_publica where nivel = 1;
