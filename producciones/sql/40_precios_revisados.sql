-- =====================================================================
-- 40_precios_revisados.sql  ·  Producciones  ·  25/11/2026
-- Petición de la web del 25/11 (fecha de revisión de precios) y decisión de
-- Guille del 25/11:
--   · Una sola fecha global, configuracion.precios_revisados (date), no por producto.
--   · Se actualiza sola, con triggers, cuando cambia algo que afecta al precio:
--       - producto_precios_referencia: altas, bajas y cambios de coste_proveedor,
--         transporte, modo (el tramo) o producto_id;
--       - tramos_precio: altas, bajas y cualquier cambio;
--       - productos: altas (un producto nuevo trae su precio, también en modo
--         general) y solo cambios de coste_proveedor, transporte_unitario, moq
--         y modo_calculo (añadido por Guille el 25/11).
--     Solo cuenta un cambio REAL de valor: la app reescribe todas las filas al
--     guardar un producto, y un guardado sin cambios no debe mover la fecha.
--   · La app tiene un botón "Marcar precios como revisados hoy" (Configuración).
--   · La web lee solo esa fecha en la vista nueva public.configuracion_web_publica.
--     catalogo_web no se toca.
--   · La función de trigger va en el esquema privado (regla del 39: nada
--     ejecutable por anon en public).
--   · La fecha empieza con la de hoy (hora de Madrid).
-- REQUIERE: scripts 38 y 39 ejecutados.
--
-- "Automatically expose new tables" está desactivado (25/11): la vista nueva
-- necesita sus grant explícitos, que van aquí.
-- Se ejecuta entero, de una vez. Todo va en una transacción.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Comprobaciones previas
-- ---------------------------------------------------------------------

do $$
declare
  falta text;
begin
  if to_regnamespace('privado') is null then
    raise exception 'No existe el esquema privado: faltan los scripts 38 y 39. No se cambia nada.';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'configuracion' and column_name = 'precios_revisados')
     or to_regclass('public.configuracion_web_publica') is not null
     or to_regprocedure('privado.marcar_precios_cambiados()') is not null then
    raise exception 'La columna, la vista o la función de este script ya existen: parece que ya se ejecutó. No se cambia nada.';
  end if;
  if not exists (select 1 from public.configuracion where id = 1) then
    raise exception 'configuracion no tiene la fila id = 1 que usa la app. No se cambia nada.';
  end if;

  -- Las columnas que vigilan los triggers existen.
  select string_agg(format('%s.%s', x.tabla, x.columna), ', ') into falta
  from (values ('productos', 'coste_proveedor'), ('productos', 'transporte_unitario'),
               ('productos', 'moq'), ('productos', 'modo_calculo'),
               ('producto_precios_referencia', 'producto_id'), ('producto_precios_referencia', 'modo'),
               ('producto_precios_referencia', 'coste_proveedor'), ('producto_precios_referencia', 'transporte'),
               ('tramos_precio', 'porcentaje_extra')) x(tabla, columna)
  where not exists (select 1 from information_schema.columns c
                    where c.table_schema = 'public' and c.table_name = x.tabla and c.column_name = x.columna);
  if falta is not null then
    raise exception 'No existen estas columnas: %. No se cambia nada.', falta;
  end if;
end;
$$;

-- 0.1 Foto de catalogo_web como anon, para comprobar al final que no cambia.
set local role anon;
select set_config('e47_40.catalogo_antes',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
reset role;

-- ---------------------------------------------------------------------
-- 1. Columna de la fecha
-- ---------------------------------------------------------------------

alter table public.configuracion add column precios_revisados date;

comment on column public.configuracion.precios_revisados is
  'Fecha de la última revisión o cambio de precios. La mueven los triggers precios_revisados_* '
  'y el botón "Marcar precios como revisados hoy" de la app. La web la lee en configuracion_web_publica.';

update public.configuracion
   set precios_revisados = (now() at time zone 'Europe/Madrid')::date
 where id = 1;

-- ---------------------------------------------------------------------
-- 2. Función de trigger (en privado) y triggers
-- ---------------------------------------------------------------------

-- SECURITY DEFINER: así funciona aunque las políticas de configuracion cambien
-- en el futuro. search_path vacío y nombres completos, para que no se le pueda
-- colar otra tabla con el mismo nombre.
create function privado.marcar_precios_cambiados()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.configuracion
     set precios_revisados = (now() at time zone 'Europe/Madrid')::date
   where id = 1
     and precios_revisados is distinct from (now() at time zone 'Europe/Madrid')::date;
  return null;   -- trigger AFTER: el valor devuelto no se usa
end;
$$;

comment on function privado.marcar_precios_cambiados() is
  'Pone configuracion.precios_revisados = hoy (Madrid) cuando cambia algo que afecta al precio. Script 40.';

-- Nadie necesita ejecutarla a mano: los triggers no comprueban EXECUTE al dispararse.
revoke execute on function privado.marcar_precios_cambiados() from public, anon, authenticated;

-- productos: altas siempre (un producto nuevo en modo general trae su coste en
-- la propia fila; los de tramos además mueven la fecha al cargar sus costes).
create trigger precios_revisados_productos_alta
after insert on public.productos
for each row
execute function privado.marcar_precios_cambiados();

-- productos: cambios solo de los cuatro campos, y solo si cambia el valor.
create trigger precios_revisados_productos
after update of coste_proveedor, transporte_unitario, moq, modo_calculo on public.productos
for each row
when (old.coste_proveedor     is distinct from new.coste_proveedor
   or old.transporte_unitario is distinct from new.transporte_unitario
   or old.moq                 is distinct from new.moq
   or old.modo_calculo        is distinct from new.modo_calculo)
execute function privado.marcar_precios_cambiados();

-- producto_precios_referencia: altas y bajas siempre; cambios solo si cambia el valor.
create trigger precios_revisados_referencia_alta_baja
after insert or delete on public.producto_precios_referencia
for each row
execute function privado.marcar_precios_cambiados();

create trigger precios_revisados_referencia_cambio
after update of producto_id, modo, coste_proveedor, transporte on public.producto_precios_referencia
for each row
when (old.producto_id     is distinct from new.producto_id
   or old.modo            is distinct from new.modo
   or old.coste_proveedor is distinct from new.coste_proveedor
   or old.transporte      is distinct from new.transporte)
execute function privado.marcar_precios_cambiados();

-- tramos_precio (márgenes): altas, bajas y cualquier cambio real.
create trigger precios_revisados_tramos_alta_baja
after insert or delete on public.tramos_precio
for each row
execute function privado.marcar_precios_cambiados();

create trigger precios_revisados_tramos_cambio
after update on public.tramos_precio
for each row
when (old.* is distinct from new.*)
execute function privado.marcar_precios_cambiados();

-- ---------------------------------------------------------------------
-- 3. Vista pública: solo la fecha
-- ---------------------------------------------------------------------

create view public.configuracion_web_publica
with (security_invoker = false, security_barrier = true) as
select c.precios_revisados
from public.configuracion c
where c.id = 1;

comment on view public.configuracion_web_publica is
  'Lo único de configuracion que ve la web: la fecha de revisión de precios. Script 40.';

revoke all on public.configuracion_web_publica from public, anon, authenticated;
-- authenticated también: la tienda y la app comparten dominio, y si alguien
-- tiene la sesión de la app abierta, la tienda consulta como authenticated.
grant select on public.configuracion_web_publica to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Verificación (incluye una prueba de los triggers que se deshace sola)
-- ---------------------------------------------------------------------

set local role anon;
select set_config('e47_40.catalogo_despues',
  (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.catalogo_web c)::text, true);
select set_config('e47_40.vista_anon',
  coalesce((select jsonb_agg(to_jsonb(v)) from public.configuracion_web_publica v)::text, '[]'), true);
reset role;

do $$
declare
  hoy       date := (now() at time zone 'Europe/Madrid')::date;
  vieja     constant date := date '2000-01-01';
  columnas  text;
  fallos    text[] := '{}';
  id_prod   text;
  id_ref    text;
  hay_tramo boolean;
begin
  -- 4.1 La fecha está puesta y la vista la enseña, como anon, en una sola fila.
  if (select precios_revisados from public.configuracion where id = 1) is distinct from hoy then
    raise exception 'Verificación: configuracion.precios_revisados no es la fecha de hoy.';
  end if;
  if current_setting('e47_40.vista_anon')::jsonb <> jsonb_build_array(jsonb_build_object('precios_revisados', hoy)) then
    raise exception 'Verificación: como anon, configuracion_web_publica devuelve %.', current_setting('e47_40.vista_anon');
  end if;

  -- 4.2 La vista solo tiene la columna de la fecha.
  select string_agg(column_name, ',' order by ordinal_position) into columnas
  from information_schema.columns where table_schema = 'public' and table_name = 'configuracion_web_publica';
  if columnas <> 'precios_revisados' then
    raise exception 'Verificación: columnas inesperadas en configuracion_web_publica: %', columnas;
  end if;

  -- 4.3 Permisos: anon lee la vista y nada de configuracion; la app puede guardar la fecha.
  if not has_table_privilege('anon', 'public.configuracion_web_publica', 'SELECT') then
    raise exception 'Verificación: anon no puede leer configuracion_web_publica.';
  end if;
  if has_any_column_privilege('anon', 'public.configuracion', 'SELECT') then
    raise exception 'Verificación: anon puede leer columnas de configuracion.';
  end if;
  if not has_column_privilege('authenticated', 'public.configuracion', 'precios_revisados', 'SELECT')
     or not has_column_privilege('authenticated', 'public.configuracion', 'precios_revisados', 'UPDATE') then
    raise exception 'Verificación: la app (authenticated) no podría leer o guardar precios_revisados.';
  end if;
  if has_function_privilege('anon', 'privado.marcar_precios_cambiados()', 'EXECUTE') then
    raise exception 'Verificación: anon puede ejecutar privado.marcar_precios_cambiados().';
  end if;

  -- 4.3b Están los seis triggers (el de alta de productos no se prueba con un
  --      insert de verdad: depende de los campos obligatorios de productos).
  select string_agg(t.tgname::text, ',' order by t.tgname::text) into columnas
  from pg_trigger t
  where t.tgfoid = 'privado.marcar_precios_cambiados()'::regprocedure and not t.tgisinternal;
  if columnas is distinct from 'precios_revisados_productos,precios_revisados_productos_alta,'
                               'precios_revisados_referencia_alta_baja,precios_revisados_referencia_cambio,'
                               'precios_revisados_tramos_alta_baja,precios_revisados_tramos_cambio' then
    raise exception 'Verificación: triggers inesperados: %', columnas;
  end if;

  -- 4.4 catalogo_web no cambia.
  if current_setting('e47_40.catalogo_antes')::jsonb <> current_setting('e47_40.catalogo_despues')::jsonb then
    raise exception 'Verificación: como anon, catalogo_web no devuelve lo mismo que antes.';
  end if;

  -- 4.5 Prueba de los triggers sobre datos reales, dentro de un bloque que se
  --     deshace entero al final (no queda ningún cambio).
  select id::text into id_prod from public.productos where moq is not null limit 1;
  select id::text into id_ref from public.producto_precios_referencia limit 1;
  hay_tramo := exists (select 1 from public.tramos_precio);

  begin
    -- productos: guardado sin cambios → no mueve la fecha; cambio de moq → sí.
    if id_prod is not null then
      update public.configuracion set precios_revisados = vieja where id = 1;
      update public.productos set coste_proveedor = coste_proveedor, moq = moq where id::text = id_prod;
      if (select precios_revisados from public.configuracion where id = 1) <> vieja then
        fallos := array_append(fallos, 'productos: un guardado sin cambios movió la fecha');
      end if;
      update public.productos set moq = moq + 1 where id::text = id_prod;
      if (select precios_revisados from public.configuracion where id = 1) <> hoy then
        fallos := array_append(fallos, 'productos: un cambio de moq no movió la fecha');
      end if;
      update public.configuracion set precios_revisados = vieja where id = 1;
      update public.productos set nombre = nombre || ' ' where id::text = id_prod;
      if (select precios_revisados from public.configuracion where id = 1) <> vieja then
        fallos := array_append(fallos, 'productos: un cambio de nombre movió la fecha');
      end if;
    end if;

    -- producto_precios_referencia: sin cambios → no; cambio de coste → sí.
    if id_ref is not null then
      update public.configuracion set precios_revisados = vieja where id = 1;
      update public.producto_precios_referencia
         set coste_proveedor = coste_proveedor, transporte = transporte, modo = modo where id::text = id_ref;
      if (select precios_revisados from public.configuracion where id = 1) <> vieja then
        fallos := array_append(fallos, 'producto_precios_referencia: un guardado sin cambios movió la fecha');
      end if;
      update public.producto_precios_referencia
         set coste_proveedor = coalesce(coste_proveedor, 0) + 1 where id::text = id_ref;
      if (select precios_revisados from public.configuracion where id = 1) <> hoy then
        fallos := array_append(fallos, 'producto_precios_referencia: un cambio de coste no movió la fecha');
      end if;
    end if;

    -- tramos_precio: sin cambios → no; cambio de margen → sí.
    if hay_tramo then
      update public.configuracion set precios_revisados = vieja where id = 1;
      update public.tramos_precio set porcentaje_extra = porcentaje_extra
       where ctid = (select ctid from public.tramos_precio limit 1);
      if (select precios_revisados from public.configuracion where id = 1) <> vieja then
        fallos := array_append(fallos, 'tramos_precio: un guardado sin cambios movió la fecha');
      end if;
      update public.tramos_precio set porcentaje_extra = coalesce(porcentaje_extra, 0) + 0.01
       where ctid = (select ctid from public.tramos_precio limit 1);
      if (select precios_revisados from public.configuracion where id = 1) <> hoy then
        fallos := array_append(fallos, 'tramos_precio: un cambio de margen no movió la fecha');
      end if;
    end if;

    raise exception 'deshacer_prueba_40';
  exception
    when raise_exception then
      if sqlerrm <> 'deshacer_prueba_40' then
        raise;
      end if;
  end;

  if array_length(fallos, 1) > 0 then
    raise exception 'Verificación: los triggers no se comportan como se espera: %', array_to_string(fallos, ' · ');
  end if;
  if (select precios_revisados from public.configuracion where id = 1) is distinct from hoy then
    raise exception 'Verificación: la prueba no se deshizo bien (la fecha no es hoy).';
  end if;
  if id_prod is null or id_ref is null or not hay_tramo then
    raise notice 'Aviso: alguna tabla estaba vacía y su prueba de trigger se saltó.';
  end if;

  raise notice 'Verificación correcta: precios_revisados = %, visible como anon en configuracion_web_publica; triggers probados (y deshechos); catalogo_web sin cambios.', hoy;
end;
$$;

notify pgrst, 'reload schema';

commit;

-- Comprobación (solo lectura), después de ejecutar:
-- select * from public.configuracion_web_publica;
-- select tgname, tgrelid::regclass::text as tabla from pg_trigger where tgname like 'precios_revisados_%';
