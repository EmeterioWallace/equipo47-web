-- ============================================================
-- BLOQUE "SECUENCIAS ANON" · B — ROLLBACK
-- ============================================================
-- ESTADO: PREPARADO, NO EJECUTADO. Solo para revertir 1B-12.
--
-- Qué hace (UNA transacción, rol postgres)
--   Devuelve SELECT, UPDATE y USAGE a anon en las 4 secuencias y deja sus ACL EXACTAMENTE
--   como en _hardening_1b.seq_acl_snapshot (48 filas, tomada por 1B-12 antes del cambio).
--
-- Guardas (todas abortan sin cambiar nada)
--   * Rol postgres; existen seq_control y seq_acl_snapshot; la instantánea es EXACTAMENTE el
--     conjunto auditado (comparación en ambos sentidos): 4 secuencias x {anon, authenticated,
--     postgres, service_role} x {SELECT, UPDATE, USAGE} = 48 filas, owner y grantor postgres,
--     sin grant option (12 de ellas de anon).
--   * Cada secuencia sigue siendo la misma que al tomar la instantánea (mismo OID y owner).
--   * Existe el marcador SEQ_ANON_aplicado.
--   * Las 4 secuencias existen y su owner coincide con el de la instantánea.
--   * Estado actual = instantánea MENOS las 12 filas de anon, nada más (sin deriva). Si ya
--     coincide con la instantánea completa, solo corrige los marcadores y avisa.
--
-- Después del GRANT comprueba: diferencia con la instantánea = 0 en ambos sentidos (incluido
-- grantor y grant option), anon con los 3 privilegios, los demás roles sin cambios, y el relacl
-- actual igual (como conjunto de aclitem) al relacl original guardado.
-- El caso "YA_RESTAURADO" (estado ya igual a la instantánea) NO ejecuta ningún GRANT y solo
-- ajusta los marcadores; se identifica por su NOTICE.
--
-- Efectos secundarios y limitaciones
--   * Sustituye el marcador SEQ_ANON_aplicado por SEQ_ANON_revertido. Se CONSERVAN seq_control
--     y seq_acl_snapshot (borrarlas es una decisión posterior y explícita).
--   * Tras un rollback, 1B-12 NO es reaplicable tal cual: aborta si hay marcadores o
--     instantánea previos (fallo seguro deliberado). Reaplicar exige decidir antes qué hacer
--     con esas tablas.
--   * La fidelidad de la restauración depende de que el grantor original sea el owner (lo
--     comprueba). No toca authenticated, service_role ni postgres.
--   * No revierte nada de default privileges (este bloque no los modifica).
--
-- Efecto inmediato; no hay pérdida de datos. No ejecutar mientras 1B-12 siga en DRY_RUN.
-- ============================================================

begin;

create function pg_temp._seq_actual()
returns table (obj text, owner text, grantor text, grantee text, privilege text, grantable boolean)
language sql stable as $f$
  select 'public.' || c.relname::text, c.relowner::regrole::text, a.grantor::regrole::text,
         case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
         a.privilege_type::text, a.is_grantable
    from pg_class c, lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) a
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
     and c.relname::text = any (array['fichajes_id_seq', 'solicitud_items_id_seq',
                                      'solicitudes_correccion_id_seq', 'solicitudes_id_seq'])
$f$;

do $$
declare
  seqs     text[] := array['public.fichajes_id_seq', 'public.solicitud_items_id_seq',
                           'public.solicitudes_correccion_id_seq', 'public.solicitudes_id_seq'];
  privs    text[] := array['SELECT', 'UPDATE', 'USAGE'];
  s        text;
  p        text;
  n        int;
  n_falta  int;
  n_sobra  int;
begin
  -- ── Guardas ──────────────────────────────────────────────
  if current_user <> 'postgres' then raise exception 'Ejecutar como postgres (rol actual: %)', current_user; end if;
  if to_regclass('_hardening_1b.seq_control') is null or to_regclass('_hardening_1b.seq_acl_snapshot') is null then
    raise exception 'No existen seq_control / seq_acl_snapshot: no hay nada que revertir ni con qué restaurar'; end if;

  select count(*) into n from _hardening_1b.seq_acl_snapshot;
  if n <> 48 then raise exception 'La instantánea no tiene 48 filas (tiene %): no se puede restaurar con fidelidad', n; end if;
  select count(*) into n from _hardening_1b.seq_acl_snapshot where grantee = 'anon';
  if n <> 12 then raise exception 'La instantánea debía tener 12 filas de anon y tiene %', n; end if;
  select count(*) into n from _hardening_1b.seq_acl_snapshot where grantable or grantor <> owner;
  if n <> 0 then raise exception 'La instantánea contiene % filas con grant option o grantor distinto del owner: no es reproducible con GRANT del owner', n; end if;

  -- La instantánea es EXACTAMENTE el conjunto auditado: 4 secuencias x {anon, authenticated,
  -- postgres, service_role} x {SELECT, UPDATE, USAGE}, owner y grantor postgres, sin grant option.
  select count(*) into n from (
      select o.v, 'postgres'::text, 'postgres'::text, g.v, q.v, false
        from unnest(seqs) as o(v),
             unnest(array['anon', 'authenticated', 'postgres', 'service_role']) as g(v),
             unnest(privs) as q(v)
      except select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot) x;
  if n <> 0 then raise exception 'La instantánea no contiene el conjunto esperado (faltan % filas)', n; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select o.v, 'postgres'::text, 'postgres'::text, g.v, q.v, false
        from unnest(seqs) as o(v),
             unnest(array['anon', 'authenticated', 'postgres', 'service_role']) as g(v),
             unnest(privs) as q(v)) x;
  if n <> 0 then raise exception 'La instantánea contiene % filas fuera del conjunto esperado', n; end if;

  foreach s in array seqs loop
    if to_regclass(s) is null then raise exception 'No existe la secuencia %', s; end if;
    -- Misma secuencia que al tomar la instantánea (mismo OID, no recreada) y mismo owner.
    select count(*) into n from _hardening_1b.seq_acl_snapshot sn
      join pg_class c on c.oid = to_regclass(s)::oid
     where sn.obj = s and sn.seq_oid = c.oid and sn.owner = c.relowner::regrole::text;
    if n <> 12 then raise exception 'La secuencia % no coincide con la instantánea (OID u owner distintos: ¿recreada?)', s; end if;
  end loop;

  -- ── ¿Qué diferencia hay hoy con la instantánea? ──────────
  select count(*) into n_falta from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()) x;
  select count(*) into n_sobra from (
      select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()
      except select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot) x;

  if n_falta = 0 and n_sobra = 0 then
    raise notice 'YA_RESTAURADO: las 4 secuencias ya coinciden con la instantánea; NO se ha ejecutado ningún GRANT. Solo se actualizan los marcadores.';
    delete from _hardening_1b.seq_control where step = 'SEQ_ANON_aplicado';
    insert into _hardening_1b.seq_control (step, note) values ('SEQ_ANON_revertido', 'detectado ya restaurado')
      on conflict (step) do update set at = now();
    return;
  end if;

  if not exists (select 1 from _hardening_1b.seq_control where step = 'SEQ_ANON_aplicado') then
    raise exception 'No consta SEQ_ANON_aplicado y el estado difiere de la instantánea: estado inesperado, revisar a mano'; end if;
  if n_sobra <> 0 then raise exception 'Hay % privilegios que no están en la instantánea (deriva): revisar a mano', n_sobra; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()) x
   where grantee <> 'anon';
  if n_falta <> 12 or n <> 0 then
    raise exception 'El estado actual no es "instantánea menos las 12 filas de anon" (faltan %, de ellas % ajenas a anon): deriva, revisar a mano', n_falta, n; end if;

  -- ── Restauración ─────────────────────────────────────────
  foreach s in array seqs loop
    execute format('grant select, update, usage on sequence %s to anon', s);
  end loop;

  -- ── Aserciones posteriores ───────────────────────────────
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot
      except select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()) x;
  if n <> 0 then raise exception 'Tras restaurar faltan % privilegios respecto a la instantánea', n; end if;
  select count(*) into n from (
      select obj, owner, grantor, grantee, privilege, grantable from pg_temp._seq_actual()
      except select obj, owner, grantor, grantee, privilege, grantable from _hardening_1b.seq_acl_snapshot) x;
  if n <> 0 then raise exception 'Tras restaurar sobran % privilegios respecto a la instantánea', n; end if;

  foreach s in array seqs loop
    foreach p in array privs loop
      if not has_sequence_privilege('anon', to_regclass(s)::oid, p)
         or not has_sequence_privilege('authenticated', to_regclass(s)::oid, p)
         or not has_sequence_privilege('service_role', to_regclass(s)::oid, p)
         or not has_sequence_privilege('postgres', to_regclass(s)::oid, p) then
        raise exception 'Tras restaurar falta % sobre % para algún rol', p, s; end if;
    end loop;
    if has_sequence_privilege('authenticator', to_regclass(s)::oid, 'SELECT')
       or has_sequence_privilege('authenticator', to_regclass(s)::oid, 'UPDATE')
       or has_sequence_privilege('authenticator', to_regclass(s)::oid, 'USAGE') then
      raise exception 'authenticator tiene privilegios sobre % tras restaurar', s; end if;
  end loop;

  -- Evidencia adicional: el relacl actual coincide, como CONJUNTO de aclitem (el orden interno del
  -- array puede variar tras un GRANT), con el relacl original guardado en la instantánea.
  select count(*) into n
    from _hardening_1b.seq_acl_snapshot sn
    join pg_class c on c.oid = sn.seq_oid
   where (select array_agg(u.x::text order by u.x::text) from unnest(c.relacl) as u(x))
         is distinct from
         (select array_agg(u.x::text order by u.x::text) from unnest(sn.relacl_original::aclitem[]) as u(x));
  if n <> 0 then raise exception 'Tras restaurar, el relacl de % filas de la instantánea difiere del original guardado', n; end if;

  delete from _hardening_1b.seq_control where step = 'SEQ_ANON_aplicado';
  insert into _hardening_1b.seq_control (step, note) values ('SEQ_ANON_revertido', 'rollback: ACL restauradas desde la instantánea')
    on conflict (step) do update set at = now();
  raise notice 'Rollback: las 4 secuencias coinciden exactamente con la instantánea (anon con SELECT, UPDATE y USAGE).';
end $$;

drop function pg_temp._seq_actual();
commit;
