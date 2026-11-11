-- =====================================================================
-- 35_catalogo_web_categorias.sql  ·  Producciones  ·  11/11/2026
-- catalogo_web pasa a leer la categoría desde categorias_web (INTEGRACION_PRODUCCIONES.md, 6.4).
-- REQUIERE: 34_categorias_web.sql ejecutado.
--
-- Parte de la definición del script 33 (copia de la real). Cambios, y nada más:
--   1. sport / category / subcategory: si el producto tiene categoria_id, salen del árbol
--      (categorias_web_ruta); si no, de los textos de siempre. Mismos nombres y tipos.
--   2. Los productos cuya categoría (o una superior) esté desactivada o en "Próximamente"
--      dejan de salir (decisión de Guille, 11/11/2026). Hoy: los de lucha.
--      La tienda no tiene que filtrar nada; categorias_web_publica sigue mostrando la
--      categoría con proximamente = true para pintar el botón deshabilitado.
--   3. ORDER BY usa las columnas calculadas en lugar de deporte_web / tipo_web.
--   4. Nueva columna al final: categoria_id.
--
-- Verifica que la tienda ve lo mismo que antes. Si no, aborta y no se guarda nada.
-- =====================================================================

begin;

-- 0. El script 34 tiene que estar ejecutado (con la columna rama_proximamente).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'categorias_web_ruta'
      and column_name = 'rama_proximamente'
  ) then
    raise exception 'Falta ejecutar 34_categorias_web.sql (versión con rama_proximamente) antes que este script.';
  end if;
end;
$$;

-- 1. Foto de lo que devuelve la vista ahora, para comparar después.
create temp table _catalogo_antes_35 on commit drop as
select id, sport, category, subcategory from public.catalogo_web;

-- 2. Nueva definición.
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
  p.categoria_id
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

-- 3. Verificación.
do $$
declare
  n_antes     integer;
  n_despues   integer;
  n_ocultos   integer;
  n           integer;
begin
  select count(*) into n_antes   from _catalogo_antes_35;
  select count(*) into n_despues from public.catalogo_web;

  -- No aparece ningún producto nuevo.
  select count(*) into n
  from public.catalogo_web d
  where not exists (select 1 from _catalogo_antes_35 a where a.id = d.id);
  if n > 0 then
    raise exception 'Verificación: % productos aparecen en la vista y antes no estaban.', n;
  end if;

  -- Los que desaparecen tienen que estar todos en una rama desactivada o en "Próximamente".
  select count(*) into n
  from _catalogo_antes_35 a
  join public.productos p on p.id = a.id
  left join public.categorias_web_ruta r on r.id = p.categoria_id
  where not exists (select 1 from public.catalogo_web d where d.id = a.id)
    and not coalesce(r.rama_proximamente or not r.rama_activa, false);
  if n > 0 then
    raise exception 'Verificación: % productos desaparecen sin estar en una rama oculta.', n;
  end if;

  n_ocultos := n_antes - n_despues;

  -- sport y subcategory (lo que usa la tienda para filtrar) no cambian.
  select count(*) into n
  from _catalogo_antes_35 a
  join public.catalogo_web d using (id)
  where a.sport is distinct from d.sport
     or a.subcategory is distinct from d.subcategory;
  if n > 0 then
    raise exception 'Verificación: % productos cambian de sport/subcategory.', n;
  end if;

  -- category solo cambia donde se decidió (6.7.3): merchandising → merchandising-eventos.
  select count(*) into n
  from _catalogo_antes_35 a
  join public.catalogo_web d using (id)
  where a.category is distinct from d.category
    and not (a.category = 'merchandising' and d.category = 'merchandising-eventos');
  if n > 0 then
    raise exception 'Verificación: % productos cambian de category sin estar previsto.', n;
  end if;

  raise notice 'Verificación correcta: % productos visibles; % ocultos por estar en "Próximamente" o desactivados; el resto, con los mismos filtros que antes.',
    n_despues, n_ocultos;
end;
$$;

commit;

-- Comprobación (solo lectura): categoria_id al final y los mismos productos.
-- select id, titulo, sport, category, subcategory, orden_web, categoria_id from public.catalogo_web limit 5;
