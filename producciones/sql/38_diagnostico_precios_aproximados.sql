-- =====================================================================
-- 38_diagnostico_precios_aproximados.sql  ·  Producciones  ·  25/11/2026
-- SOLO LECTURA. No cambia nada. Funciona igual antes y después del script 38.
--
-- Productos publicados (los que ve la tienda) con precio_aproximado = true:
-- nombre, MOQ, el tramo que le correspondería al MOQ, el tramo que se usa de
-- verdad para el precio y qué tramos tiene cargados.
--
-- Regla real de calcular_precio_publico (leída el 25/11 con el diagnóstico):
--   · Modo general: un solo precio, nunca aproximado.
--   · Por tramos: el tramo de producto_precios_referencia igual o inferior más
--     cercano al MOQ. Si no hay ninguno igual o inferior, el MÁS PEQUEÑO que haya
--     (siempre mayor que el MOQ) y aproximado = true.
-- Por eso aquí tramo_usado = el tramo más pequeño cargado.
--
-- v2 (25/11): la v1 deducía los tramos llamando a la función con cada cantidad,
-- y contaba como "con datos" cualquier tramo por encima del más pequeño cargado.
-- Ahora se leen directamente de producto_precios_referencia.
-- =====================================================================

select
  p.nombre                                                  as nombre_interno,
  c.titulo                                                  as titulo_web,
  c.category                                                as categoria,
  c.subcategory                                             as subcategoria,
  c.moq,
  (select max(t) from (values (50), (100), (500), (1000), (5000), (10000)) v(t)
    where t <= c.moq)                                       as tramo_que_le_toca,   -- null = MOQ por debajo de 50
  (select min(r.modo::int) from public.producto_precios_referencia r
    where r.producto_id = c.id)                             as tramo_usado,
  round(c.precio_final, 2)                                  as precio_en_web,
  (select string_agg(r.modo || case when r.coste_proveedor is null then ' (sin coste)' else '' end,
                     ', ' order by r.modo::int)
   from public.producto_precios_referencia r
   where r.producto_id = c.id)                              as tramos_cargados
from public.catalogo_web c
join public.productos p on p.id = c.id
where c.precio_aproximado
order by c.category, c.subcategory, p.nombre;
