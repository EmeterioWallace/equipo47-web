-- =====================================================================
-- 36_publicar_exige_categoria_rollback.sql  ·  Deshace 36_publicar_exige_categoria.sql
-- Deja publicado_validation como antes: título público y moq > 0 (sin categoría, sin imagen).
-- =====================================================================

begin;

alter table public.productos drop constraint publicado_validation;

alter table public.productos add constraint publicado_validation
  check (publicado is not true
         or (titulo_publico is not null and moq is not null and moq > 0));

commit;
