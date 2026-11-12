-- =====================================================================
-- 36_publicar_exige_categoria.sql  ·  Producciones  ·  12/11/2026
-- Un producto publicado tiene que tener categoría (decisión 6.7.6 del buzón).
-- REQUIERE: 34_categorias_web.sql ejecutado (columna productos.categoria_id).
--
-- Cambia publicado_validation, y nada más:
--   antes:   publicado IS NOT TRUE OR (titulo_publico, moq > 0)
--   después: publicado IS NOT TRUE OR (titulo_publico, moq > 0, categoria_id)
-- Sigue sin exigir imagen. Vale cualquier nivel del árbol (deporte, tipo o subcategoría),
-- igual que en la app. No toca catalogo_web ni los permisos.
--
-- ANTES DE EJECUTAR, la consulta de solo lectura del final (bloque "Consulta previa")
-- tiene que devolver 0 productos. Si devuelve alguno, el script aborta igualmente.
--
-- Se ejecuta entero, de una vez. Todo va en una transacción: si algo falla, no se guarda nada.
-- =====================================================================

begin;

-- 0. Comprobaciones previas.
do $$
declare
  def        text;
  def_norm   text;
  n          integer;
  lista      text;
begin
  -- 0.1 Existe categoria_id (script 34).
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'productos' and column_name = 'categoria_id'
  ) then
    raise exception 'Falta ejecutar 34_categorias_web.sql: productos no tiene categoria_id.';
  end if;

  -- 0.2 La regla actual es la que documenta el buzón (sección 1). Se compara sin
  --     paréntesis, espacios ni conversiones de tipo, para no depender del formato
  --     con que Postgres la devuelve. Si es otra, no se pisa: se aborta y se enseña.
  select pg_get_constraintdef(c.oid) into def
  from pg_constraint c
  where c.conrelid = 'public.productos'::regclass and c.conname = 'publicado_validation';

  if def is null then
    raise exception 'No existe la restricción publicado_validation en productos. No se cambia nada.';
  end if;

  def_norm := regexp_replace(lower(def), '::[a-z_ ]+|[()[:space:]]', '', 'g');
  if def_norm <> 'checkpublicadoisnottrueortitulo_publicoisnotnullandmoqisnotnullandmoq>0' then
    raise exception 'publicado_validation no es la esperada. Definición actual: %', def;
  end if;

  -- 0.3 Ningún producto publicado sin categoría (incluidos los inactivos: la regla
  --     se aplica a todas las filas).
  select count(*), string_agg(id::text || ' · ' || coalesce(titulo_publico, nombre), E'\n' order by nombre)
    into n, lista
  from public.productos
  where publicado is true and categoria_id is null;

  if n > 0 then
    raise exception E'Hay % producto(s) publicados sin categoría. Asígnales una (o despublícalos) en la app y vuelve a ejecutar:\n%', n, lista;
  end if;
end;
$$;

-- 1. Nueva regla (mismo nombre).
alter table public.productos drop constraint publicado_validation;

alter table public.productos add constraint publicado_validation
  check (publicado is not true
         or (titulo_publico is not null and moq is not null and moq > 0 and categoria_id is not null));

-- 2. Verificación.
do $$
declare
  def text;
begin
  select pg_get_constraintdef(c.oid) into def
  from pg_constraint c
  where c.conrelid = 'public.productos'::regclass and c.conname = 'publicado_validation';

  if def is null or position('categoria_id' in def) = 0 then
    raise exception 'Verificación: publicado_validation no ha quedado con categoria_id.';
  end if;

  raise notice 'Verificación correcta. publicado_validation = %', def;
end;
$$;

commit;

-- =====================================================================
-- Consulta previa (solo lectura). Ejecutarla antes, por separado.
-- =====================================================================
-- -- a) Definición actual de la regla:
-- select pg_get_constraintdef(oid) from pg_constraint
-- where conrelid = 'public.productos'::regclass and conname = 'publicado_validation';
--
-- -- b) Productos publicados sin categoría (tiene que salir vacío):
-- select id, nombre, titulo_publico, activo, deporte_web, tipo_web, subcategoria_web
-- from public.productos
-- where publicado is true and categoria_id is null
-- order by nombre;
