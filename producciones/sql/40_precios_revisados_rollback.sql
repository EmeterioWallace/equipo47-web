-- =====================================================================
-- 40_precios_revisados_rollback.sql  ·  Producciones  ·  25/11/2026
-- Deshace 40_precios_revisados.sql: borra los seis triggers, la función
-- privado.marcar_precios_cambiados(), la vista configuracion_web_publica y la
-- columna configuracion.precios_revisados (se pierde la fecha guardada).
-- OJO: si la web ya lee configuracion_web_publica, deja de enseñar la fecha
-- (la tienda lo tolera: sin fecha no enseña nada). Avisar en el buzón.
-- Verifica como anon que catalogo_web devuelve lo mismo que antes.
-- Se ejecuta entero, de una vez. Todo va en una transacción.
-- =====================================================================

begin;

do $$
begin
  if to_regprocedure('privado.marcar_precios_cambiados()') is null
     and to_regclass('public.configuracion_web_publica') is null
     and not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'configuracion'
                       and column_name = 'precios_revisados') then
    raise exception 'No hay nada del script 40: no está aplicado. No se cambia nada.';
  end if;
end;
$$;

set local role anon;
select set_config('e47_40r.catalogo_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
reset role;

drop trigger if exists precios_revisados_productos             on public.productos;
drop trigger if exists precios_revisados_productos_alta        on public.productos;
drop trigger if exists precios_revisados_referencia_alta_baja  on public.producto_precios_referencia;
drop trigger if exists precios_revisados_referencia_cambio     on public.producto_precios_referencia;
drop trigger if exists precios_revisados_tramos_alta_baja      on public.tramos_precio;
drop trigger if exists precios_revisados_tramos_cambio         on public.tramos_precio;

-- Sin CASCADE: si algo más usara la función o la vista, falla y no se guarda nada.
drop function if exists privado.marcar_precios_cambiados();
drop view if exists public.configuracion_web_publica;
alter table public.configuracion drop column if exists precios_revisados;

set local role anon;
select set_config('e47_40r.catalogo_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
reset role;

do $$
begin
  if exists (select 1 from pg_trigger where tgname like 'precios_revisados\_%') then
    raise exception 'Verificación: quedan triggers precios_revisados_*.';
  end if;
  if to_regprocedure('privado.marcar_precios_cambiados()') is not null
     or to_regclass('public.configuracion_web_publica') is not null
     or exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'configuracion'
                  and column_name = 'precios_revisados') then
    raise exception 'Verificación: queda algo del script 40.';
  end if;
  if current_setting('e47_40r.catalogo_antes')::jsonb <> current_setting('e47_40r.catalogo_despues')::jsonb then
    raise exception 'Verificación: como anon, catalogo_web no devuelve lo mismo que antes.';
  end if;
  raise notice 'Rollback correcto: script 40 deshecho; catalogo_web sin cambios.';
end;
$$;

notify pgrst, 'reload schema';

commit;
