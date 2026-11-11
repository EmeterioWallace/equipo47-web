-- =====================================================================
-- 35_catalogo_web_categorias_rollback.sql  ·  Deshace 35_catalogo_web_categorias.sql
-- Deja catalogo_web exactamente como en el script 33.
-- create or replace no puede quitar la columna categoria_id: hay que borrar y recrear
-- la vista, y volver a dar el grant (desde el 30/10 no se hereda).
-- Si también hay que deshacer el 34, ejecutar este primero.
-- =====================================================================

begin;

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
  p.deporte_web as sport,
  p.tipo_web as category,
  p.subcategoria_web as subcategory,
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
  p.orden_web
from productos p
left join lateral calcular_precio_publico(p.id, p.moq) cp(precio, aproximado) on true
where p.publicado = true and p.activo = true
order by p.deporte_web, p.tipo_web, coalesce(p.orden_web, 999999), coalesce(p.titulo_publico, p.nombre);

grant select on public.catalogo_web to anon, authenticated;

commit;
