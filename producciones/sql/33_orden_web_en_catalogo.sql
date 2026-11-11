-- 33 · Añade orden_web a la vista pública catalogo_web
--      y retira a anon permisos que nunca necesita.
-- La vista es copia exacta de la definición real (pg_get_viewdef, 11/11/2026)
-- con UNA columna nueva al final: orden_web. Nada más cambia.

begin;

create or replace view public.catalogo_web
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

-- anon (la clave pública) nunca necesita vaciar tablas, crear claves foráneas ni triggers.
revoke truncate, references, trigger on all tables in schema public from anon;

commit;

-- Comprobación (solo lectura): debe salir la columna orden_web al final
-- y productos de la tienda como antes.
select id, titulo, sport, category, orden_web from public.catalogo_web limit 5;
