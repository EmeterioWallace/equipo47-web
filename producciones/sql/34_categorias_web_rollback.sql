-- =====================================================================
-- 34_categorias_web_rollback.sql  ·  Deshace 34_categorias_web.sql
-- Solo si hace falta, y ANTES de ejecutar el script 35 (catalogo_web dependerá de esto).
-- Restaura los textos de los productos corregidos en el paso 0 desde _backup_categorias_34.
-- =====================================================================

BEGIN;

-- 1. Restaurar los valores antiguos de los productos corregidos.
UPDATE public.productos p
SET deporte_web      = b.deporte_web,
    tipo_web         = b.tipo_web,
    subcategoria_web = b.subcategoria_web
FROM public._backup_categorias_34 b
WHERE p.id = b.producto_id;

-- 2. Quitar vistas, columna, tabla y trigger.
DROP VIEW IF EXISTS public.categorias_web_publica;
DROP VIEW IF EXISTS public.categorias_web_ruta;

ALTER TABLE public.productos DROP COLUMN IF EXISTS categoria_id;

DROP TABLE IF EXISTS public.categorias_web;
DROP FUNCTION IF EXISTS public.categorias_web_antes_guardar();

-- 3. La copia ya no hace falta.
DROP TABLE IF EXISTS public._backup_categorias_34;

COMMIT;
