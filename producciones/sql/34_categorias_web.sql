-- =====================================================================
-- 34_categorias_web.sql  ·  Producciones  ·  11/11/2026
-- Categorías gestionadas desde Producciones (INTEGRACION_PRODUCCIONES.md, sección 6).
--
-- Qué hace:
--   0. Copia en _backup_categorias_34 los valores antiguos y aplica las
--      correcciones de datos acordadas por Guille (decisiones 6.7.1 y 6.7.2).
--   1. Tabla categorias_web + trigger (slug fijo, nivel 1-3, sin mover ramas con hijos).
--   2. RLS y permisos (anon sin acceso a la tabla).
--   3. productos.categoria_id (FK, ON DELETE RESTRICT).
--   4. Vista interna categorias_web_ruta y vista pública categorias_web_publica.
--   5. Migración de los textos actuales al árbol.
--   6. Verificación: si algo no cuadra, aborta y no se guarda nada.
--
-- Qué NO hace:
--   - No toca catalogo_web (eso va en el script 35, a partir de su definición real).
--   - No borra deporte_web / tipo_web / subcategoria_web ni productos_deporte_web_check (fase 3).
--   - No cambia publicado_validation (paso posterior, decisión 6.7.6).
--
-- Se ejecuta entero, de una vez, en el SQL Editor. Todo va en una transacción.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Correcciones de datos (decisiones de Guille, 11/11/2026)
-- ---------------------------------------------------------------------

-- 0a. Copia de los valores antiguos de los productos que se corrigen,
--     para que 34_categorias_web_rollback.sql los pueda restaurar.
--     Tabla interna: RLS activado, sin políticas y sin permisos para anon ni authenticated.
CREATE TABLE public._backup_categorias_34 (
  producto_id       uuid        PRIMARY KEY,
  deporte_web       text,
  tipo_web          text,
  subcategoria_web  text,
  copiado_en        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public._backup_categorias_34 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._backup_categorias_34 FROM anon, authenticated, public;

INSERT INTO public._backup_categorias_34 (producto_id, deporte_web, tipo_web, subcategoria_web)
SELECT id, deporte_web, tipo_web, subcategoria_web
FROM public.productos
WHERE deporte_web = 'running'
  AND ( (tipo_web IS NULL AND subcategoria_web = 'Accesorio running')
     OR (tipo_web = 'accesorios' AND subcategoria_web = 'accesorios') );

-- 6.7.1  "Accesorio running" sin tipo  →  accesorios / accesorios-running   (1 producto)
UPDATE public.productos
SET tipo_web = 'accesorios', subcategoria_web = 'accesorios-running'
WHERE deporte_web = 'running' AND tipo_web IS NULL AND subcategoria_web = 'Accesorio running';

-- 6.7.2  running / accesorios / accesorios  →  accesorios-running   (2 productos)
UPDATE public.productos
SET subcategoria_web = 'accesorios-running'
WHERE deporte_web = 'running' AND tipo_web = 'accesorios' AND subcategoria_web = 'accesorios';

-- ---------------------------------------------------------------------
-- 1. Tabla categorias_web
-- ---------------------------------------------------------------------

CREATE TABLE public.categorias_web (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          text        NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  nombre        text        NOT NULL CHECK (btrim(nombre) <> ''),
  padre_id      uuid        REFERENCES public.categorias_web(id) ON DELETE RESTRICT,
  nivel         smallint    NOT NULL DEFAULT 1 CHECK (nivel BETWEEN 1 AND 3),
  orden         integer     NOT NULL DEFAULT 0,
  activa        boolean     NOT NULL DEFAULT true,
  proximamente  boolean     NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT categorias_web_no_autopadre CHECK (padre_id IS DISTINCT FROM id)
);

COMMENT ON TABLE  public.categorias_web IS 'Árbol de categorías de la tienda (deporte > tipo > subcategoría). Se gestiona desde Producciones.';
COMMENT ON COLUMN public.categorias_web.slug IS 'Identificador que usa la web para filtrar. No cambia nunca (lo impide un trigger).';
COMMENT ON COLUMN public.categorias_web.nivel IS '1 = deporte, 2 = tipo, 3 = subcategoría. Lo calcula el trigger.';
COMMENT ON COLUMN public.categorias_web.proximamente IS 'La web muestra el botón deshabilitado ("Próximamente").';

-- Slug único entre hermanas: "accesorios" existe en varios deportes.
-- Dos índices parciales en lugar de NULLS NOT DISTINCT (no depende de la versión de Postgres).
CREATE UNIQUE INDEX categorias_web_slug_raiz_uq ON public.categorias_web (slug)           WHERE padre_id IS NULL;
CREATE UNIQUE INDEX categorias_web_slug_hijo_uq ON public.categorias_web (padre_id, slug) WHERE padre_id IS NOT NULL;
CREATE INDEX        categorias_web_padre_idx    ON public.categorias_web (padre_id);

CREATE FUNCTION public.categorias_web_antes_guardar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_nivel_padre smallint;
BEGIN
  NEW.nombre := btrim(NEW.nombre);

  IF TG_OP = 'INSERT' THEN
    -- Slug automático a partir del nombre si no viene dado.
    IF NEW.slug IS NULL OR btrim(NEW.slug) = '' THEN
      NEW.slug := btrim(
        regexp_replace(
          translate(lower(NEW.nombre), 'áàäâéèëêíìïîóòöôúùüûñç', 'aaaaeeeeiiiioooouuuunc'),
          '[^a-z0-9]+', '-', 'g'),
        '-');
    END IF;
  ELSE
    IF NEW.slug IS DISTINCT FROM OLD.slug THEN
      RAISE EXCEPTION 'El slug de una categoría no se puede cambiar (%). Cambia el nombre.', OLD.slug;
    END IF;
    -- Mover una categoría con subcategorías podría pasar de 3 niveles o crear un ciclo.
    IF NEW.padre_id IS DISTINCT FROM OLD.padre_id
       AND EXISTS (SELECT 1 FROM public.categorias_web h WHERE h.padre_id = OLD.id) THEN
      RAISE EXCEPTION 'No se puede mover "%" porque tiene subcategorías.', OLD.nombre;
    END IF;
    NEW.created_at := OLD.created_at;
    NEW.updated_at := now();
  END IF;

  -- Nivel según el padre (máximo 3).
  IF NEW.padre_id IS NULL THEN
    NEW.nivel := 1;
  ELSE
    SELECT c.nivel INTO v_nivel_padre FROM public.categorias_web c WHERE c.id = NEW.padre_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'La categoría padre no existe.';
    END IF;
    IF v_nivel_padre >= 3 THEN
      RAISE EXCEPTION 'Máximo 3 niveles: deporte > tipo > subcategoría.';
    END IF;
    NEW.nivel := v_nivel_padre + 1;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER categorias_web_antes_guardar
BEFORE INSERT OR UPDATE ON public.categorias_web
FOR EACH ROW EXECUTE FUNCTION public.categorias_web_antes_guardar();

-- ---------------------------------------------------------------------
-- 2. RLS y permisos
--    Desde el 30/10 las tablas nuevas no heredan permisos: se dan explícitos.
--    Revisar que la política coincide con la de productos (consulta al final).
-- ---------------------------------------------------------------------

ALTER TABLE public.categorias_web ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.categorias_web FROM anon, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categorias_web TO authenticated;

CREATE POLICY categorias_web_equipo
  ON public.categorias_web
  FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 3. productos.categoria_id
--    ON DELETE RESTRICT: no se puede borrar una categoría con productos.
-- ---------------------------------------------------------------------

ALTER TABLE public.productos
  ADD COLUMN categoria_id uuid REFERENCES public.categorias_web(id) ON DELETE RESTRICT;

COMMENT ON COLUMN public.productos.categoria_id IS 'Categoría más concreta del producto (subcategoría o, si no hay, tipo). Sustituye a deporte_web/tipo_web/subcategoria_web.';

CREATE INDEX productos_categoria_id_idx ON public.productos (categoria_id);

-- ---------------------------------------------------------------------
-- 4. Vistas
-- ---------------------------------------------------------------------

-- 4a. Interna: ruta completa de cada categoría. La usará catalogo_web (script 35)
--     para las columnas de compatibilidad sport / category / subcategory.
CREATE VIEW public.categorias_web_ruta AS
SELECT
  c.id,
  c.nivel,
  CASE c.nivel WHEN 1 THEN c.slug WHEN 2 THEN p.slug ELSE a.slug END AS sport,
  CASE c.nivel WHEN 1 THEN NULL   WHEN 2 THEN c.slug ELSE p.slug END AS category,
  -- Si el producto cuelga del tipo, subcategory = slug del tipo (era lo que había en esos casos).
  CASE c.nivel WHEN 1 THEN NULL   ELSE c.slug END                    AS subcategory,
  (c.activa AND coalesce(p.activa, true) AND coalesce(a.activa, true)) AS rama_activa,
  -- true si la categoría o alguna superior está en "Próximamente".
  (c.proximamente OR coalesce(p.proximamente, false) OR coalesce(a.proximamente, false)) AS rama_proximamente
FROM public.categorias_web c
LEFT JOIN public.categorias_web p ON p.id = c.padre_id
LEFT JOIN public.categorias_web a ON a.id = p.padre_id;

REVOKE ALL ON public.categorias_web_ruta FROM anon, public;
GRANT SELECT ON public.categorias_web_ruta TO authenticated;

-- 4b. Pública: solo categorías activas cuyos padres también lo estén.
--     La web ordena por nivel, orden y nombre.
CREATE VIEW public.categorias_web_publica
WITH (security_barrier = true) AS
SELECT c.id, c.slug, c.nombre, c.padre_id, c.nivel, c.orden, c.proximamente
FROM public.categorias_web c
JOIN public.categorias_web_ruta r ON r.id = c.id
WHERE r.rama_activa;

REVOKE ALL ON public.categorias_web_publica FROM anon, public;
GRANT SELECT ON public.categorias_web_publica TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Migración
-- ---------------------------------------------------------------------

-- 5a. Deportes, en el orden actual de la tienda.
--     Urban, Lucha (decisión 6.7.5: hasta que tenga fotos), Tenis y Pádel: próximamente.
INSERT INTO public.categorias_web (slug, nombre, orden, proximamente) VALUES
  ('running',       'Running',       10, false),
  ('merchandising', 'Merchandising', 20, false),
  ('urban',         'Urban',         30, true),
  ('lucha',         'Lucha',         40, true),
  ('tenis',         'Tenis',         50, true),
  ('padel',         'Pádel',         60, true);

-- 5b. Mapa texto → árbol.
--     - Gym se queda sin categoría (decisión 6.7.4).
--     - merchandising / merchandising / merchandising-eventos → un único tipo "Eventos"
--       con slug merchandising-eventos (decisión 6.7.3).
--     - Si tipo = subcategoría (o no hay subcategoría), solo se crea el tipo.
CREATE TEMP TABLE _mapa_categorias ON COMMIT DROP AS
SELECT DISTINCT
  deporte_web       AS d,
  tipo_web          AS t,
  subcategoria_web  AS s,
  CASE WHEN deporte_web = 'merchandising' AND tipo_web = 'merchandising'
            AND subcategoria_web = 'merchandising-eventos'
       THEN 'merchandising-eventos'
       ELSE tipo_web
  END AS n2,
  CASE WHEN deporte_web = 'merchandising' AND tipo_web = 'merchandising'
            AND subcategoria_web = 'merchandising-eventos' THEN NULL
       WHEN subcategoria_web IS NULL OR subcategoria_web = tipo_web THEN NULL
       ELSE subcategoria_web
  END AS n3
FROM public.productos
WHERE deporte_web IS NOT NULL
  AND tipo_web IS NOT NULL
  AND tipo_web <> 'gym';

-- 5c. Tipos (nivel 2). Nombre inicial = slug con mayúscula; Fátima puede renombrar.
INSERT INTO public.categorias_web (slug, nombre, padre_id, orden)
SELECT
  x.n2,
  CASE WHEN x.n2 = 'merchandising-eventos' THEN 'Eventos'
       ELSE upper(left(x.n2, 1)) || replace(substr(x.n2, 2), '-', ' ')
  END,
  dep.id,
  10 * row_number() OVER (PARTITION BY x.d ORDER BY x.n2)
FROM (SELECT DISTINCT d, n2 FROM _mapa_categorias) x
JOIN public.categorias_web dep ON dep.padre_id IS NULL AND dep.slug = x.d;

-- 5d. Subcategorías (nivel 3).
INSERT INTO public.categorias_web (slug, nombre, padre_id, orden)
SELECT
  x.n3,
  upper(left(x.n3, 1)) || replace(substr(x.n3, 2), '-', ' '),
  tipo.id,
  10 * row_number() OVER (PARTITION BY x.d, x.n2 ORDER BY x.n3)
FROM (SELECT DISTINCT d, n2, n3 FROM _mapa_categorias WHERE n3 IS NOT NULL) x
JOIN public.categorias_web dep  ON dep.padre_id IS NULL AND dep.slug = x.d
JOIN public.categorias_web tipo ON tipo.padre_id = dep.id AND tipo.slug = x.n2;

-- 5e. Asignar categoria_id: la subcategoría si existe; si no, el tipo.
UPDATE public.productos p
SET categoria_id = coalesce(sub.id, tipo.id)
FROM _mapa_categorias m
JOIN public.categorias_web dep  ON dep.padre_id IS NULL AND dep.slug = m.d
JOIN public.categorias_web tipo ON tipo.padre_id = dep.id AND tipo.slug = m.n2
LEFT JOIN public.categorias_web sub ON sub.padre_id = tipo.id AND sub.slug = m.n3
WHERE p.deporte_web = m.d
  AND p.tipo_web = m.t
  AND p.subcategoria_web IS NOT DISTINCT FROM m.s;

-- 5f. Productos con deporte pero sin tipo ni subcategoría (4 de running, sin publicar):
--     cuelgan del deporte para no perder ese dato. Fátima les pondrá tipo.
UPDATE public.productos p
SET categoria_id = dep.id
FROM public.categorias_web dep
WHERE dep.padre_id IS NULL
  AND dep.slug = p.deporte_web
  AND p.tipo_web IS NULL
  AND p.subcategoria_web IS NULL
  AND p.categoria_id IS NULL;

-- ---------------------------------------------------------------------
-- 6. Verificación. Si falla, la transacción se aborta y no queda nada guardado.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  n integer;
BEGIN
  -- Ningún producto con deporte se queda sin categoría (salvo gym, decisión 6.7.4).
  SELECT count(*) INTO n FROM public.productos
  WHERE deporte_web IS NOT NULL AND tipo_web IS DISTINCT FROM 'gym' AND categoria_id IS NULL;
  IF n > 0 THEN
    RAISE EXCEPTION 'Verificación: % productos con deporte se han quedado sin categoría.', n;
  END IF;

  -- Todos los publicados tienen categoría.
  SELECT count(*) INTO n FROM public.productos WHERE publicado AND categoria_id IS NULL;
  IF n > 0 THEN
    RAISE EXCEPTION 'Verificación: % productos publicados sin categoría.', n;
  END IF;

  -- Compatibilidad: el árbol devuelve el mismo sport y subcategory que los textos actuales.
  SELECT count(*) INTO n
  FROM public.productos p
  JOIN public.categorias_web_ruta r ON r.id = p.categoria_id
  WHERE r.sport IS DISTINCT FROM p.deporte_web
     OR r.subcategory IS DISTINCT FROM p.subcategoria_web;
  IF n > 0 THEN
    RAISE EXCEPTION 'Verificación: % productos cambiarían de sport/subcategory en la tienda.', n;
  END IF;

  -- La copia de seguridad tiene los 3 productos corregidos (1 + 2, consulta del 11/11).
  SELECT count(*) INTO n FROM public._backup_categorias_34;
  IF n <> 3 THEN
    RAISE EXCEPTION 'Verificación: la copia tiene % productos y se esperaban 3. Revisar antes de seguir.', n;
  END IF;

  RAISE NOTICE 'Verificación correcta.';
END;
$$;

COMMIT;


-- =====================================================================
-- DESPUÉS DE EJECUTAR (solo lectura). Ejecutar cada consulta por separado.
-- =====================================================================

-- A) Árbol resultante con el número de productos de cada categoría.
-- SELECT r.sport, c.nivel, c.slug, c.nombre, c.orden, c.activa, c.proximamente,
--        (SELECT count(*) FROM public.productos p WHERE p.categoria_id = c.id)                  AS productos,
--        (SELECT count(*) FROM public.productos p WHERE p.categoria_id = c.id AND p.publicado)  AS publicados
-- FROM public.categorias_web c
-- JOIN public.categorias_web_ruta r ON r.id = c.id
-- ORDER BY r.sport, coalesce(r.category, ''), c.nivel, c.orden;

-- B) Lo que verá anon (debe excluir categorías inactivas; hoy salen todas).
-- SET ROLE anon; SELECT * FROM public.categorias_web_publica ORDER BY nivel, orden; RESET ROLE;

-- C) anon NO debe poder leer la tabla ni la vista interna (las dos deben dar "permission denied").
-- SET ROLE anon; SELECT 1 FROM public.categorias_web LIMIT 1; RESET ROLE;
-- SET ROLE anon; SELECT 1 FROM public.categorias_web_ruta LIMIT 1; RESET ROLE;

-- D) Comparar la política nueva con las de productos.
-- SELECT tablename, policyname, cmd, roles, qual, with_check
-- FROM pg_policies WHERE tablename IN ('productos', 'categorias_web') ORDER BY tablename, policyname;
