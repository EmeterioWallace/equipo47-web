-- =====================================================================
-- 37_destacados_e_imagen_portada_rollback.sql  ·  Deshace 37_destacados_e_imagen_portada.sql
-- Deja catalogo_web como en el script 35 y categorias_web_publica como en el 34,
-- y quita las columnas nuevas.
--
-- OJO: se pierden los destacados marcados, su orden y las imágenes de portada elegidas.
-- create or replace no puede quitar columnas de una vista: hay que borrarlas y recrearlas,
-- y volver a dar los permisos (desde el 30/10 no se heredan).
-- Antes de ejecutarlo, avisar en el buzón: la web dejará de recibir esas columnas
-- (la portada vuelve sola a su respaldo, sin romperse).
-- =====================================================================

begin;

-- 1. Vistas, exactamente como estaban.
drop view public.catalogo_web;

create view public.catalogo_web
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

drop view public.categorias_web_publica;

create view public.categorias_web_publica
with (security_barrier = true) as
select c.id, c.slug, c.nombre, c.padre_id, c.nivel, c.orden, c.proximamente
from public.categorias_web c
join public.categorias_web_ruta r on r.id = c.id
where r.rama_activa;

revoke all on public.categorias_web_publica from anon, public;
grant select on public.categorias_web_publica to anon, authenticated;

-- 2. Columnas.
alter table public.productos
  drop column destacado_web,
  drop column orden_destacado;

alter table public.categorias_web
  drop column imagen_portada;   -- arrastra categorias_web_imagen_portada_check

commit;
