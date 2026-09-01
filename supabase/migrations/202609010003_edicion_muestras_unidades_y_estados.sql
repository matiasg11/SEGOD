alter table public.samples
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id),
  add column if not exists deletion_reason text;

alter table public.test_catalog
  add column if not exists default_unit text;

update public.test_catalog set default_unit=case raw_schema_key
  when 'abrasion' then 'ciclos'
  when 'corte_cuchilla' then 'Índice'
  when 'perforacion' then 'N'
  when 'rasgado' then 'N'
  when 'impacto' then 'kN'
  when 'ph' then 'pH'
  when 'cromo_vi' then 'mg/kg'
  when 'desteridad' then 'mm'
  when 'medicion' then 'mm'
  when 'vapor_agua' then 'mg/(cm²·h)'
  when 'marcado' then 'N/A'
  else 'N/A' end;
update public.test_catalog set default_unit='mg/cm²' where name='Absorción de vapor de agua';
update public.test_catalog set default_unit='N' where name='Método de ensayo de resistencia al corte TDM';
update public.test_catalog set default_unit='Ω' where name='Propiedades electrostáticas';

create or replace function private.has_lab_permission(p_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when (select auth.uid()) is null then false
    else exists (
      select 1 from public.staff s
      where s.status='Activo' and s.participates_in_lab
        and (s.auth_user_id=(select auth.uid()) or lower(s.email)=lower((select auth.jwt()->>'email')))
        and case p_permission
          when 'run' then s.can_run_tests
          when 'review' then s.can_review
          when 'approve' then s.can_approve_reports
          when 'manage' then s.can_manage_records
          when 'manage_samples' then s.can_manage_records or lower(s.role)='responsable del laboratorio'
          when 'documents' then s.can_manage_documents or s.can_manage_records
          else false
        end
    )
  end;
$$;
revoke all on function private.has_lab_permission(text) from public,anon;
grant execute on function private.has_lab_permission(text) to authenticated;

drop policy if exists samples_update on public.samples;
create policy samples_update on public.samples for update to authenticated
using (created_by=(select auth.uid()) or (select private.has_lab_permission('manage_samples')))
with check (created_by=(select auth.uid()) or (select private.has_lab_permission('manage_samples')));

create or replace function public.archive_sample(p_sample_id uuid,p_reason text default null)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if not private.has_lab_permission('manage_samples') then
    raise exception 'Solo el administrador o responsable del laboratorio puede eliminar muestras';
  end if;
  update public.samples set status='Anulada',deleted_at=now(),deleted_by=(select auth.uid()),
    deletion_reason=coalesce(nullif(trim(p_reason),''),'Eliminada desde la aplicación'),
    modified_by=(select auth.uid()),updated_at=now()
  where id=p_sample_id and deleted_at is null;
  if not found then raise exception 'La muestra no existe o ya fue eliminada'; end if;
end;
$$;
revoke all on function public.archive_sample(uuid,text) from public,anon;
grant execute on function public.archive_sample(uuid,text) to authenticated;

create or replace function public.set_test_status(p_test_id uuid,p_status text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if not (private.has_lab_permission('run') or private.has_lab_permission('review') or private.has_lab_permission('approve') or private.has_lab_permission('manage')) then
    raise exception 'Sin permiso para modificar el estado del ensayo';
  end if;
  if not exists(select 1 from public.app_options where category='test_status' and active and value=p_status) then
    raise exception 'Estado de ensayo no válido';
  end if;
  if p_status='No Ensayado' then
    update public.raw_test_data set voided=true,status='Anulado',void_reason='Obsoleto: ensayo marcado como No Ensayado',
      voided_at=now(),voided_by=(select auth.uid()),modified_by=(select auth.uid()),updated_at=now()
    where sample_test_id=p_test_id and not voided;
    update public.sample_tests set status=p_status,final_result=null,units=null,classification='No ensayado',
      compliance='N/A',raw_record_count=0,modified_by=(select auth.uid()),updated_at=now()
    where id=p_test_id;
  else
    update public.sample_tests set status=p_status,modified_by=(select auth.uid()),updated_at=now() where id=p_test_id;
  end if;
  if not found then raise exception 'Ensayo no encontrado'; end if;
end;
$$;
revoke all on function public.set_test_status(uuid,text) from public,anon;
grant execute on function public.set_test_status(uuid,text) to authenticated;

create index if not exists samples_deleted_at_idx on public.samples(deleted_at) where deleted_at is not null;
create index if not exists samples_deleted_by_idx on public.samples(deleted_by) where deleted_by is not null;
