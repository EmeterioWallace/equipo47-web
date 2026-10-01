-- ============================================================
-- EXTRACCIÓN DEL ESQUEMA REAL DE SUPABASE — SOLO LECTURA
-- ============================================================
-- Esto NO modifica nada. Son consultas de solo lectura contra los
-- catálogos internos de Postgres (information_schema / pg_catalog).
-- No devuelve ningún dato real de vuestras tablas (ni fichajes, ni
-- clientes, ni inventario) — solo la ESTRUCTURA: nombres, tipos,
-- relaciones, reglas.
--
-- CÓMO EJECUTARLO:
-- Ejecuta cada bloque UNO A UNO (resáltalo y dale a Run, o usa el
-- separador "--" como viene). Después de cada uno, copia el
-- resultado (clic derecho sobre la tabla de resultados suele dar
-- opción de copiar, o usa el botón de exportar/descargar si lo ves)
-- y pégalo en un documento de texto, con el título del bloque encima
-- (A, B, C...). Al final, súbeme ese documento con todo junto.
--
-- Si algún bloque da error porque algo no existe (ej. no tenéis
-- vistas, o no tenéis triggers), no pasa nada — significa que esa
-- parte está vacía en vuestro proyecto. Dímelo y seguimos.
-- ============================================================


-- ── BLOQUE A: Tablas y columnas ──────────────────────────────
select
  c.table_name,
  c.ordinal_position as orden,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.character_maximum_length
from information_schema.columns c
where c.table_schema = 'public'
order by c.table_name, c.ordinal_position;


-- ── BLOQUE B: Claves primarias y foráneas ────────────────────
select 'PK' as tipo, tc.table_name, kcu.column_name,
       null::text as tabla_destino, null::text as columna_destino, tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
where tc.constraint_type = 'PRIMARY KEY' and tc.table_schema = 'public'
union all
select 'FK' as tipo, tc.table_name, kcu.column_name,
       ccu.table_name, ccu.column_name, tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
join information_schema.constraint_column_usage ccu
  on tc.constraint_name = ccu.constraint_name and tc.table_schema = ccu.table_schema
where tc.constraint_type = 'FOREIGN KEY' and tc.table_schema = 'public'
order by table_name, tipo;


-- ── BLOQUE C: Índices ─────────────────────────────────────────
select tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;


-- ── BLOQUE D1: Restricciones CHECK ───────────────────────────
select tc.table_name, tc.constraint_name, cc.check_clause
from information_schema.table_constraints tc
join information_schema.check_constraints cc
  on tc.constraint_name = cc.constraint_name and tc.table_schema = cc.constraint_schema
where tc.constraint_type = 'CHECK' and tc.table_schema = 'public'
order by tc.table_name;

-- ── BLOQUE D2: Tipos enum ────────────────────────────────────
select t.typname as nombre_enum, e.enumlabel as valor, e.enumsortorder
from pg_type t
join pg_enum e on t.oid = e.enumtypid
join pg_catalog.pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
order by t.typname, e.enumsortorder;


-- ── BLOQUE E: Vistas ──────────────────────────────────────────
select table_name as vista, view_definition
from information_schema.views
where table_schema = 'public';


-- ── BLOQUE F: Funciones y RPC (incluye su código) ────────────
select
  p.proname as nombre_funcion,
  pg_get_function_identity_arguments(p.oid) as argumentos,
  t.typname as tipo_retorno,
  p.prosecdef as es_security_definer,
  l.lanname as lenguaje,
  pg_get_functiondef(p.oid) as definicion
from pg_proc p
join pg_namespace n on p.pronamespace = n.oid
join pg_type t on p.prorettype = t.oid
join pg_language l on p.prolang = l.oid
where n.nspname = 'public'
order by p.proname;


-- ── BLOQUE G: Triggers ────────────────────────────────────────
select event_object_table as tabla, trigger_name, action_timing,
       event_manipulation, action_statement
from information_schema.triggers
where trigger_schema = 'public'
order by event_object_table, trigger_name;


-- ── BLOQUE H1: ¿RLS activado por tabla? ───────────────────────
select relname as tabla, relrowsecurity as rls_activado, relforcerowsecurity as rls_forzado
from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
order by relname;

-- ── BLOQUE H2: Políticas RLS ──────────────────────────────────
select tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;


-- ── BLOQUE I: Permisos relevantes (grants) ───────────────────
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'service_role')
order by table_name, grantee, privilege_type;
