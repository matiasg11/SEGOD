-- Formularios de ensayo y selección automática completamente administrables.

create table if not exists public.test_form_fields (
  id uuid primary key default gen_random_uuid(),
  test_catalog_id uuid not null references public.test_catalog(id) on delete cascade,
  field_key text not null,
  label text not null,
  input_type text not null default 'number'
    check (input_type in ('number','text','textarea','list','boolean','date')),
  requirement text not null default 'optional'
    check (requirement in ('required','optional','fixed')),
  fixed_value text,
  choices jsonb not null default '[]'::jsonb
    check (jsonb_typeof(choices) = 'array'),
  allow_custom boolean not null default false,
  unit text,
  sort_order integer not null default 100,
  active boolean not null default true,
  unique(test_catalog_id, field_key)
);

create table if not exists public.test_selection_rules (
  id uuid primary key default gen_random_uuid(),
  trigger_value text not null,
  test_catalog_id uuid not null references public.test_catalog(id) on delete cascade,
  selected_by_default boolean not null default false,
  sort_order integer not null default 100,
  unique(trigger_value, test_catalog_id)
);

alter table public.test_form_fields enable row level security;
alter table public.test_selection_rules enable row level security;

revoke all on table public.test_form_fields, public.test_selection_rules
  from public, anon;
grant select, insert, update, delete on table
  public.test_form_fields, public.test_selection_rules
  to authenticated;

create policy test_form_fields_read on public.test_form_fields
for select to authenticated
using ((select auth.uid()) is not null);
create policy test_form_fields_manage on public.test_form_fields
for all to authenticated
using (private.has_lab_permission('manage'))
with check (private.has_lab_permission('manage'));

create policy test_selection_rules_read on public.test_selection_rules
for select to authenticated
using ((select auth.uid()) is not null);
create policy test_selection_rules_manage on public.test_selection_rules
for all to authenticated
using (private.has_lab_permission('manage'))
with check (private.has_lab_permission('manage'));

create index if not exists test_form_fields_catalog_order_idx
  on public.test_form_fields(test_catalog_id, sort_order) where active;
create index if not exists test_selection_rules_trigger_idx
  on public.test_selection_rules(trigger_value, sort_order);

-- La lista activa queda limitada a los veinte ensayos solicitados.
update public.test_catalog set active=false;

insert into public.test_catalog
  (name,standard,method,required_equipment,available_in_house,raw_schema_key,active,primary_equipment_id,default_unit)
values
  ('Abrasion','IRAM 3607',null,'Martindale',true,'abrasion',true,(select id from public.equipment where code='AB01L' limit 1),'ciclos'),
  ('Abrasion Doble','Ensayos de rutina',null,'Martindale',true,'abrasion',true,(select id from public.equipment where code='AB01L' limit 1),'ciclos'),
  ('Absorción de vapor de agua','IRAM 3608','5.4','Balanza',false,'vapor_agua',true,(select id from public.equipment where code='BA01L' limit 1),'mg/cm²'),
  ('Transmisión de vapor de agua','IRAM 3608','5.3','Balanza',false,'vapor_agua',true,(select id from public.equipment where code='BA01L' limit 1),'mg/(cm²·h)'),
  ('Corte por cuchilla','IRAM 3607',null,'Corte por cuchilla',true,'corte_cuchilla',true,(select id from public.equipment where code='CO01L' limit 1),'Índice'),
  ('Cromo VI','IRAM 3608',null,null,false,'cromo_vi',true,null,'mg/kg'),
  ('Desteridad','IRAM 3608','5.2','Varillas de acero inoxidable',true,'desteridad',true,(select id from public.equipment where code='DE01L' limit 1),'mm'),
  ('Determinación del talle','IRAM 3608','5.1','Regla y cinta métrica calibradas',true,'medicion',true,(select id from public.equipment where code='RG01L' limit 1),'mm'),
  ('Determinación de medidas de las mangas','IRAM 3608','5.1','Regla y cinta métrica calibradas',true,'medicion',true,(select id from public.equipment where code='RG01L' limit 1),'mm'),
  ('Determinación del pH','IRAM 3608','IRAM 8508','pHmetro',true,'ph',true,(select id from public.equipment where code='PH01L' limit 1),'pH'),
  ('Ensayo de Impacto IRAM 3607:2019','IRAM 3607:2019',null,null,true,'impacto',true,null,'kN'),
  ('Ensayo de Impacto IRAM 3607:2023','IRAM 3607:2023',null,null,true,'impacto',true,null,'kN'),
  ('Marcado, Rotulado y Embalaje','IRAM 3608','6.0',null,true,'marcado',true,null,'N/A'),
  ('Resistencia al corte TDM','IRAM 3607',null,'Corte TDM',false,'corte_cuchilla',true,(select id from public.equipment where code='CO01L' limit 1),'N'),
  ('Perforación','IRAM 3607',null,'PUN01L - Punzón',true,'perforacion',true,(select id from public.equipment where code='PUN01L' limit 1),'N'),
  ('Perforación Doble','Ensayos de rutina',null,'PUN01L - Punzón',true,'perforacion',true,(select id from public.equipment where code='PUN01L' limit 1),'N'),
  ('Rasgado','IRAM 3607',null,'Dinamómetro',true,'rasgado',true,(select id from public.equipment where code='RGI01L' limit 1),'N'),
  ('Rasgado Doble','Ensayos de rutina',null,'Dinamómetro',true,'rasgado',true,(select id from public.equipment where code='RGI01L' limit 1),'N'),
  ('Suavidad de Cueros','Ensayos de rutina',null,null,true,'medicion',true,null,'N/A'),
  ('Hidrofugado','Ensayos de rutina',null,null,true,'medicion',true,null,'N/A')
on conflict (name,standard) do update set
  method=excluded.method,
  required_equipment=excluded.required_equipment,
  available_in_house=excluded.available_in_house,
  raw_schema_key=excluded.raw_schema_key,
  active=true,
  primary_equipment_id=excluded.primary_equipment_id,
  default_unit=excluded.default_unit;

-- Campos iniciales equivalentes a los formularios que ya utilizaba la app.
with templates(schema_key,fields) as (
 values
 ('ph','[
   {"key":"ph-medido","label":"pH medido","type":"number","requirement":"required"},
   {"key":"ph-dilucion","label":"pH dilución","type":"number","requirement":"optional"}
 ]'::jsonb),
 ('desteridad','[
   {"key":"talle","label":"Talle","type":"text","requirement":"optional"},
   {"key":"varilla","label":"Varilla","type":"text","requirement":"optional"},
   {"key":"diametro","label":"Diámetro","type":"number","requirement":"required"},
   {"key":"nivel","label":"Nivel","type":"text","requirement":"optional"}
 ]'::jsonb),
 ('cromo_vi','[
   {"key":"medicion","label":"Medición","type":"number","requirement":"optional"},
   {"key":"limite-de-cuantificacion","label":"Límite de cuantificación","type":"number","requirement":"optional"},
   {"key":"debajo-del-limite","label":"Debajo del límite","type":"list","requirement":"optional","choices":["Sí","No","N/A"]}
 ]'::jsonb),
 ('medicion','[
   {"key":"tipo-de-medida","label":"Tipo de medida","type":"list","requirement":"optional","allow_custom":true},
   {"key":"talle","label":"Talle","type":"text","requirement":"optional"},
   {"key":"medida-esperada","label":"Medida esperada","type":"number","requirement":"optional"},
   {"key":"m1","label":"M1","type":"number","requirement":"optional"},
   {"key":"m2","label":"M2","type":"number","requirement":"optional"},
   {"key":"m3","label":"M3","type":"number","requirement":"optional"},
   {"key":"m4","label":"M4","type":"number","requirement":"optional"}
 ]'::jsonb),
 ('impacto','[
   {"key":"magnitud","label":"Magnitud","type":"text","requirement":"optional"},
   {"key":"m1","label":"M1","type":"number","requirement":"optional"},{"key":"m2","label":"M2","type":"number","requirement":"optional"},
   {"key":"m3","label":"M3","type":"number","requirement":"optional"},{"key":"m4","label":"M4","type":"number","requirement":"optional"},
   {"key":"m5","label":"M5","type":"number","requirement":"optional"},{"key":"m6","label":"M6","type":"number","requirement":"optional"},
   {"key":"m7","label":"M7","type":"number","requirement":"optional"},{"key":"m8","label":"M8","type":"number","requirement":"optional"},
   {"key":"m9","label":"M9","type":"number","requirement":"optional"},{"key":"m10","label":"M10","type":"number","requirement":"optional"}
 ]'::jsonb),
 ('corte_cuchilla','[
   {"key":"c1","label":"C1","type":"number","requirement":"optional"},{"key":"c2","label":"C2","type":"number","requirement":"optional"},
   {"key":"c3","label":"C3","type":"number","requirement":"optional"},{"key":"c4","label":"C4","type":"number","requirement":"optional"},
   {"key":"c5","label":"C5","type":"number","requirement":"optional"},{"key":"c6","label":"C6","type":"number","requirement":"optional"},
   {"key":"t1","label":"T1","type":"number","requirement":"optional"},{"key":"t2","label":"T2","type":"number","requirement":"optional"},
   {"key":"t3","label":"T3","type":"number","requirement":"optional"},{"key":"t4","label":"T4","type":"number","requirement":"optional"},
   {"key":"t5","label":"T5","type":"number","requirement":"optional"},
   {"key":"cuchilla-o-lote","label":"Cuchilla o lote","type":"text","requirement":"optional"},
   {"key":"material-de-referencia","label":"Material de referencia","type":"text","requirement":"optional"}
 ]'::jsonb),
 ('perforacion','[
   {"key":"probeta-1","label":"Probeta 1","type":"number","requirement":"optional"},
   {"key":"probeta-2","label":"Probeta 2","type":"number","requirement":"optional"},
   {"key":"probeta-3","label":"Probeta 3","type":"number","requirement":"optional"},
   {"key":"probeta-4","label":"Probeta 4","type":"number","requirement":"optional"},
   {"key":"punzon","label":"Punzón","type":"text","requirement":"fixed","fixed":"PUN01L"}
 ]'::jsonb),
 ('rasgado','[
   {"key":"probeta-1","label":"Probeta 1","type":"number","requirement":"optional"},
   {"key":"probeta-2","label":"Probeta 2","type":"number","requirement":"optional"},
   {"key":"probeta-3","label":"Probeta 3","type":"number","requirement":"optional"},
   {"key":"probeta-4","label":"Probeta 4","type":"number","requirement":"optional"},
   {"key":"direccion-de-corte","label":"Dirección de corte","type":"list","requirement":"optional","allow_custom":true}
 ]'::jsonb),
 ('abrasion','[
   {"key":"probeta-1","label":"Probeta 1","type":"number","requirement":"optional"},
   {"key":"probeta-2","label":"Probeta 2","type":"number","requirement":"optional"},
   {"key":"probeta-3","label":"Probeta 3","type":"number","requirement":"optional"},
   {"key":"probeta-4","label":"Probeta 4","type":"number","requirement":"optional"},
   {"key":"ciclos","label":"Ciclos","type":"number","requirement":"optional"},
   {"key":"lote-de-lija","label":"Lote de lija","type":"text","requirement":"optional"},
   {"key":"adhesivo","label":"Adhesivo","type":"text","requirement":"optional"}
 ]'::jsonb),
 ('vapor_agua','[
   {"key":"masa-inicial","label":"Masa inicial","type":"number","requirement":"optional"},
   {"key":"masa-final","label":"Masa final","type":"number","requirement":"optional"},
   {"key":"tiempo","label":"Tiempo","type":"number","requirement":"optional"},
   {"key":"area-de-ensayo","label":"Área de ensayo","type":"number","requirement":"optional"},
   {"key":"temperatura","label":"Temperatura","type":"number","requirement":"optional"},
   {"key":"humedad-relativa","label":"Humedad relativa","type":"number","requirement":"optional"}
 ]'::jsonb),
 ('marcado','[
   {"key":"fabricante","label":"Fabricante","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]},
   {"key":"articulo","label":"Artículo","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]},
   {"key":"talle-o-medidas","label":"Talle o medidas","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]},
   {"key":"vencimiento","label":"Vencimiento","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]},
   {"key":"normativas","label":"Normativas","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]},
   {"key":"envase","label":"Envase","type":"list","requirement":"required","choices":["Cumple","No Cumple","N/A"]}
 ]'::jsonb)
)
insert into public.test_form_fields
  (test_catalog_id,field_key,label,input_type,requirement,fixed_value,choices,allow_custom,sort_order)
select c.id,
       f.item->>'key',
       f.item->>'label',
       f.item->>'type',
       f.item->>'requirement',
       f.item->>'fixed',
       coalesce(f.item->'choices','[]'::jsonb),
       coalesce((f.item->>'allow_custom')::boolean,false),
       f.ord::integer * 10
from public.test_catalog c
join templates t on t.schema_key=c.raw_schema_key
cross join lateral jsonb_array_elements(t.fields) with ordinality f(item,ord)
where c.active
on conflict (test_catalog_id,field_key) do nothing;

-- Presets iniciales. Todos sus casilleros quedan almacenados, marcados o no.
with preset(trigger_value,selected_names) as (
 values
 ('IRAM 3607:2019',array['Abrasion','Corte por cuchilla','Rasgado','Perforación','Ensayo de Impacto IRAM 3607:2019']::text[]),
 ('IRAM 3607:2023',array['Abrasion','Corte por cuchilla','Rasgado','Perforación','Ensayo de Impacto IRAM 3607:2023']::text[]),
 ('IRAM 3608',array['Absorción de vapor de agua','Transmisión de vapor de agua','Cromo VI','Desteridad','Determinación del talle','Determinación de medidas de las mangas','Determinación del pH','Marcado, Rotulado y Embalaje']::text[]),
 ('Ensayos de rutina',array['Abrasion Doble','Perforación Doble','Rasgado Doble','Suavidad de Cueros','Hidrofugado']::text[])
)
insert into public.test_selection_rules
  (trigger_value,test_catalog_id,selected_by_default,sort_order)
select p.trigger_value,c.id,c.name=any(p.selected_names),
       row_number() over(partition by p.trigger_value order by c.name)::integer * 10
from preset p cross join public.test_catalog c
where c.active
on conflict (trigger_value,test_catalog_id) do update set
  selected_by_default=excluded.selected_by_default,
  sort_order=excluded.sort_order;

comment on table public.test_form_fields is
  'Campos administrables solicitados por cada formulario de ensayo.';
comment on table public.test_selection_rules is
  'Ensayos que cada norma o tipo de solicitud marca automáticamente.';
