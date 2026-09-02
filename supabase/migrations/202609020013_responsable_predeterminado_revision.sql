-- Completa el responsable operativo al enviar a revisión, para registros históricos sin asignación.
create or replace function public.send_test_to_review(p_test_id uuid)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v public.sample_tests;
  v_eq public.equipment;
  v_gonzalo uuid;
begin
  if not private.has_lab_permission('run') then
    raise exception 'Sin permiso para enviar a revisión';
  end if;
  select * into v from public.sample_tests where id = p_test_id and not voided;
  if v.id is null then raise exception 'Ensayo inexistente o anulado'; end if;
  if v.assigned_to is null then
    select id into v_gonzalo from public.staff
    where status='Activo' and can_run_tests
      and (lower(email)='gonzalo.torti@segod.com.ar' or lower(full_name)='gonzalo torti')
    order by (lower(email)='gonzalo.torti@segod.com.ar') desc limit 1;
    if v_gonzalo is null then raise exception 'No se encontró a Gonzalo Torti como responsable activo'; end if;
    update public.sample_tests set assigned_to=v_gonzalo,modified_by=(select auth.uid()),updated_at=now() where id=p_test_id;
    v.assigned_to:=v_gonzalo;
  end if;
  if v.raw_record_count < 1 then raise exception 'Debe existir al menos un registro de datos crudos'; end if;
  if v.final_result is null and coalesce(v.compliance,'') not in ('Cumple','No cumple','No Cumple','N/A') then raise exception 'Falta un resultado o evaluación de cumplimiento'; end if;
  if v.equipment_id is not null then
    select * into v_eq from public.equipment where id=v.equipment_id;
    if v_eq.status is distinct from 'Apto' or (v_eq.expires_at is not null and v_eq.expires_at<current_date) then raise exception 'El equipo no está apto o está vencido'; end if;
  end if;
  update public.sample_tests set status='Ejecutado',modified_by=(select auth.uid()),updated_at=now() where id=p_test_id;
end;
$$;
