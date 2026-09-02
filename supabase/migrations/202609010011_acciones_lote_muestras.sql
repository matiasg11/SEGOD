-- Ejecuta una misma acción sobre todos los ensayos vigentes de varias muestras.
-- La función es invocadora: reutiliza los permisos y validaciones ya definidos por ensayo.
create or replace function public.bulk_sample_test_action(
  p_sample_ids uuid[],
  p_action text,
  p_notes text default null
)
returns integer
language plpgsql
set search_path to ''
as $$
declare
  v_test public.sample_tests;
  v_count integer := 0;
begin
  if coalesce(cardinality(p_sample_ids), 0) = 0 then
    raise exception 'Seleccioná al menos una muestra';
  end if;
  if p_action not in ('review', 'approve', 'observe', 'not_tested') then
    raise exception 'Acción en lote no válida';
  end if;

  for v_test in
    select *
    from public.sample_tests
    where sample_id = any(p_sample_ids)
      and not voided
      and status not in ('Aprobado', 'Anulado', 'No Ensayado', 'N/A')
    order by sample_id, created_at, id
  loop
    if p_action = 'review' then
      perform public.send_test_to_review(v_test.id);
    elsif p_action = 'approve' then
      if v_test.status <> 'Ejecutado' then
        raise exception 'El ensayo % de una muestra seleccionada no está listo para aprobar', v_test.test_name;
      end if;
      perform public.review_test(v_test.id, 'Aprobado', coalesce(p_notes, 'Aprobado en lote'));
    elsif p_action = 'observe' then
      perform public.review_test(v_test.id, 'Observado', coalesce(nullif(p_notes, ''), 'Observado en lote'));
    else
      perform public.set_test_status(v_test.id, 'No Ensayado');
    end if;
    v_count := v_count + 1;
  end loop;

  if v_count = 0 then
    raise exception 'No hay ensayos vigentes aplicables en las muestras seleccionadas';
  end if;
  return v_count;
end;
$$;

revoke all on function public.bulk_sample_test_action(uuid[], text, text) from public, anon;
grant execute on function public.bulk_sample_test_action(uuid[], text, text) to authenticated;
