-- =====================================================================
-- 39_permisos_anon_rollback.sql  ·  Producciones  ·  25/11/2026
-- Deshace 39_permisos_anon.sql: vuelve a dar a PUBLIC/anon exactamente los
-- permisos que quitó (guardados en privado.respaldo_permisos_39), comprueba
-- que están y borra el respaldo.
-- Nota: si entretanto se cambió "Automatically expose new tables", los permisos
-- por defecto que repone son solo los que quitó el 39.
-- Se ejecuta entero, de una vez. Todo va en una transacción.
-- =====================================================================

begin;

do $$
declare
  r     record;
  falta text;
begin
  if to_regclass('privado.respaldo_permisos_39') is null then
    raise exception 'No existe privado.respaldo_permisos_39: el 39 no está aplicado. No se cambia nada.';
  end if;

  for r in select * from privado.respaldo_permisos_39 order by tipo, objeto, rol, privilegio loop
    if r.tipo = 'funcion' then
      execute format('grant %s on function %s to %s', r.privilegio, r.objeto, r.rol);
    elsif r.tipo = 'tabla' then
      if to_regclass(r.objeto) is null then
        raise notice 'La tabla % ya no existe: se salta.', r.objeto;
        continue;
      end if;
      execute format('grant %s on table %s to %s', r.privilegio, r.objeto, r.rol);
    elsif r.tipo = 'por_defecto' then
      execute format('alter default privileges for role postgres in schema public grant %s on tables to %s',
                     r.privilegio, r.rol);
    else
      raise exception 'Tipo desconocido en el respaldo: %', r.tipo;
    end if;
  end loop;

  -- Verificación: cada permiso del respaldo vuelve a estar.
  select string_agg(format('%s %s %s→%s', b.tipo, b.objeto, b.privilegio, b.rol), '; ') into falta
  from privado.respaldo_permisos_39 b
  where case b.tipo
          when 'funcion' then not has_function_privilege(
                                case when b.rol = 'public' then 'anon' else b.rol end, b.objeto, b.privilegio)
          when 'tabla' then to_regclass(b.objeto) is not null
                            and not has_table_privilege(b.rol, b.objeto, b.privilegio)
          when 'por_defecto' then not exists (
                select 1 from pg_default_acl d cross join lateral aclexplode(d.defaclacl) a
                where d.defaclrole = 'postgres'::regrole
                  and d.defaclnamespace = 'public'::regnamespace
                  and d.defaclobjtype = 'r'
                  and a.grantee = b.rol::regrole
                  and a.privilege_type = b.privilegio)
        end;
  if falta is not null then
    raise exception 'Verificación: no se han repuesto: %', falta;
  end if;

  raise notice 'Rollback correcto: % permisos repuestos.', (select count(*) from privado.respaldo_permisos_39);
end;
$$;

drop table privado.respaldo_permisos_39;

notify pgrst, 'reload schema';

commit;
