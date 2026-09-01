-- Catálogo, estados, responsable y equipo principal para las ejecuciones.
alter table public.test_catalog
  add column if not exists primary_equipment_id uuid references public.equipment(id);

update public.app_options set active=false where category='test_status';
insert into public.app_options(category,value,label,sort_order,active) values
  ('test_status','Pendiente','Pendiente',10,true),
  ('test_status','Ejecutado','Ejecutado',20,true),
  ('test_status','Datos Cargados','Datos Cargados',30,true),
  ('test_status','Observado','Observado',40,true),
  ('test_status','Aprobado','Aprobado',50,true),
  ('test_status','Anulado','Anulado',60,true),
  ('test_status','No Ensayado','No Ensayado',70,true),
  ('test_status','N/A','N/A',80,true)
on conflict(category,value) do update set label=excluded.label,sort_order=excluded.sort_order,active=true,updated_at=now();

update public.app_options set value='Ensayos de rutina',label='Ensayos de rutina',active=true
where category='standard' and lower(value)=lower('Ensayo de Rutina');
insert into public.app_options(category,value,label,sort_order,active)
values('standard','Ensayos de rutina','Ensayos de rutina',40,true)
on conflict(category,value) do update set label=excluded.label,sort_order=excluded.sort_order,active=true,updated_at=now();

-- Las denominaciones sin norma eran las opciones históricas de rutina.
update public.test_catalog set active=false
where standard is null and name in ('Marcado','Medición','Cromo VI','pH','Impacto','Corte por cuchilla','Perforación','Rasgado','Abrasión');

insert into public.test_catalog(name,standard,raw_schema_key,active) values
 ('Marcado (Rutina)','Ensayos de rutina','marcado',true),
 ('Medición (Rutina)','Ensayos de rutina','medicion',true),
 ('Cromo VI (Rutina)','Ensayos de rutina','cromo_vi',true),
 ('pH (Rutina)','Ensayos de rutina','ph',true),
 ('Impacto (Rutina)','Ensayos de rutina','impacto',true),
 ('Corte por cuchilla (Rutina)','Ensayos de rutina','corte_cuchilla',true),
 ('Perforación (Rutina)','Ensayos de rutina','perforacion',true),
 ('Rasgado (Rutina)','Ensayos de rutina','rasgado',true),
 ('Abrasión (Rutina)','Ensayos de rutina','abrasion',true),
 ('Perforación doble (Rutina)','Ensayos de rutina','perforacion',true),
 ('Rasgado doble (Rutina)','Ensayos de rutina','rasgado',true),
 ('Abrasión doble (Rutina)','Ensayos de rutina','abrasion',true)
on conflict(name,standard) do update set raw_schema_key=excluded.raw_schema_key,active=true;

update public.test_catalog set raw_schema_key='vapor_agua'
where name in ('Transmisión de vapor de agua','Absorción de vapor de agua');

-- Equipo principal, resuelto por código natural para no fijar UUID generados.
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='AB01L' and c.raw_schema_key='abrasion';
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='CC01L' and c.raw_schema_key='corte_cuchilla';
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='RGI01L' and c.raw_schema_key in ('perforacion','rasgado');
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='PH01L' and c.raw_schema_key='ph';
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='CM01' and c.raw_schema_key='medicion';
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='VAR-04' and c.raw_schema_key='desteridad';
update public.test_catalog c set primary_equipment_id=e.id,required_equipment=coalesce(c.required_equipment,e.name)
from public.equipment e where e.code='BC01L' and c.raw_schema_key='vapor_agua';

create or replace function public.create_sample_with_tests(p_sample jsonb,p_test_names text[])
returns uuid language plpgsql security invoker set search_path='' as $$
declare
  v_id uuid; v_name text; v_catalog uuid; v_standard text; v_equipment uuid; v_gonzalo uuid;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión autenticada'; end if;
  select id into v_gonzalo from public.staff
  where status='Activo' and (lower(email)='gonzalo.torti@segod.com.ar' or lower(full_name)='gonzalo torti')
  order by (lower(email)='gonzalo.torti@segod.com.ar') desc limit 1;
  if v_gonzalo is null then raise exception 'No se encontró al responsable Gonzalo Torti'; end if;

  insert into public.samples(received_at,product,requester,model,size,hand,lot,batch,work_order,quantity_received,requested_standard,status,location_and_storage,conservation_conditions,notes,requested_tests_list,created_by)
  values(coalesce(nullif(p_sample->>'received_at','')::date,current_date),p_sample->>'product',coalesce(nullif(p_sample->>'requester',''),'Calidad'),coalesce(nullif(p_sample->>'model',''),'N/A'),coalesce(nullif(p_sample->>'size',''),'N/A'),coalesce(nullif(p_sample->>'hand',''),'N/A'),nullif(p_sample->>'lot',''),nullif(p_sample->>'batch',''),nullif(p_sample->>'work_order',''),coalesce(nullif(p_sample->>'quantity_received','')::numeric,1),nullif(p_sample->>'requested_standard',''),'Recibida',coalesce(nullif(p_sample->>'location',''),'N/A'),coalesce(nullif(p_sample->>'conservation',''),'N/A'),nullif(p_sample->>'notes',''),coalesce(p_test_names,'{}'),(select auth.uid())) returning id into v_id;

  foreach v_name in array coalesce(p_test_names,'{}') loop
    select id,standard,primary_equipment_id into v_catalog,v_standard,v_equipment
    from public.test_catalog where name=v_name and active
    order by (standard=p_sample->>'requested_standard') desc nulls last,available_in_house desc limit 1;
    if v_catalog is null then raise exception 'Ensayo no encontrado o inactivo: %',v_name; end if;
    insert into public.sample_tests(sample_id,test_catalog_id,test_name,applied_standard,repetition_no,status,assigned_to,equipment_id,execution_reason,created_by)
    values(v_id,v_catalog,v_name,coalesce(nullif(p_sample->>'requested_standard',''),v_standard),1,'Pendiente',v_gonzalo,v_equipment,'Ensayo solicitado con el ingreso de la muestra',(select auth.uid()));
  end loop;
  return v_id;
end;
$$;
revoke all on function public.create_sample_with_tests(jsonb,text[]) from public,anon;
grant execute on function public.create_sample_with_tests(jsonb,text[]) to authenticated;

create or replace function private.refresh_test_raw_count()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_test uuid;
begin
  v_test := coalesce(new.sample_test_id,old.sample_test_id);
  update public.sample_tests t set
    raw_record_count=(select count(*) from public.raw_test_data r where r.sample_test_id=v_test and not r.voided),
    status=case when t.status in ('Pendiente','Ejecutado') then 'Datos Cargados' else t.status end,
    updated_at=now(), modified_by=(select auth.uid())
  where t.id=v_test;
  return coalesce(new,old);
end;
$$;

create or replace function public.send_test_to_review(p_test_id uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare v public.sample_tests; v_eq public.equipment;
begin
  if not private.has_lab_permission('run') then raise exception 'Sin permiso para enviar a revisión'; end if;
  select * into v from public.sample_tests where id=p_test_id;
  if v.raw_record_count<1 then raise exception 'Debe existir al menos un registro de datos crudos'; end if;
  if v.final_result is null or v.assigned_to is null then raise exception 'Faltan resultado o responsable'; end if;
  if v.equipment_id is not null then
    select * into v_eq from public.equipment where id=v.equipment_id;
    if v_eq.status is distinct from 'Apto' or (v_eq.expires_at is not null and v_eq.expires_at<current_date) then raise exception 'El equipo no está apto o está vencido'; end if;
  end if;
  update public.sample_tests set status='Ejecutado',modified_by=(select auth.uid()),updated_at=now() where id=p_test_id;
end;
$$;

create or replace function public.review_test(p_test_id uuid,p_decision text,p_notes text default null)
returns void language plpgsql security invoker set search_path='' as $$
declare v_staff uuid;
begin
  if p_decision='Aprobado' and not private.has_lab_permission('approve') then raise exception 'Sin permiso para aprobar'; end if;
  if p_decision='Observado' and not private.has_lab_permission('review') then raise exception 'Sin permiso para revisar'; end if;
  if p_decision not in ('Aprobado','Observado') then raise exception 'Decisión no válida'; end if;
  select id into v_staff from public.staff where auth_user_id=(select auth.uid()) or lower(email)=lower((select auth.jwt()->>'email')) limit 1;
  update public.sample_tests set status=p_decision,review_notes=p_notes,reviewed_at=now(),reviewed_by=v_staff,reviewed_result=final_result,locked=(p_decision='Aprobado'),modified_by=(select auth.uid()) where id=p_test_id;
end;
$$;

create or replace function public.repeat_test(p_test_id uuid,p_reason text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_old public.sample_tests; v_new uuid; v_rep int;
begin
  if not private.has_lab_permission('run') then raise exception 'Sin permiso para ejecutar ensayos'; end if;
  select * into v_old from public.sample_tests where id=p_test_id;
  select coalesce(max(repetition_no),0)+1 into v_rep from public.sample_tests where sample_id=v_old.sample_id and test_name=v_old.test_name;
  insert into public.sample_tests(sample_id,test_catalog_id,test_name,applied_standard,repetition_no,status,assigned_to,equipment_id,repetition_reason,execution_reason,created_by)
  values(v_old.sample_id,v_old.test_catalog_id,v_old.test_name,v_old.applied_standard,v_rep,'Pendiente',v_old.assigned_to,v_old.equipment_id,p_reason,'Repetición del ensayo '||p_test_id,(select auth.uid())) returning id into v_new;
  update public.sample_tests set status='Observado',replacement_test_id=v_new,modified_by=(select auth.uid()) where id=p_test_id;
  return v_new;
end;
$$;

grant execute on function public.repeat_test(uuid,text) to authenticated;
grant execute on function public.send_test_to_review(uuid) to authenticated;
grant execute on function public.review_test(uuid,text,text) to authenticated;

create index if not exists test_catalog_active_standard_idx on public.test_catalog(standard,name) where active;
