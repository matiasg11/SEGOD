create table if not exists public.app_options (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  value text not null,
  label text not null,
  sort_order integer not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(category,value)
);

alter table public.app_options enable row level security;
revoke all on table public.app_options from anon,authenticated;
grant select,insert,update on table public.app_options to authenticated;

create policy options_read on public.app_options for select to authenticated
  using ((select auth.uid()) is not null);
create policy options_insert on public.app_options for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy options_update on public.app_options for update to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));

drop trigger if exists options_touch on public.app_options;
create trigger options_touch before update on public.app_options
for each row execute function private.touch_updated_at();

insert into public.app_options(category,value,label,sort_order) values
('sample_product','Guantes','Guantes',10),('sample_product','Mangas','Mangas',20),
('sample_requester','Calidad','Calidad',10),('sample_requester','Producción','Producción',20),('sample_requester','Comercial','Comercial',30),('sample_requester','Desarrollo','Desarrollo',40),
('sample_size','XS','XS',10),('sample_size','S','S',20),('sample_size','M','M',30),('sample_size','L','L',40),('sample_size','XL','XL',50),('sample_size','XXL','XXL',60),
('sample_hand','Izquierda','Izquierda',10),('sample_hand','Derecha','Derecha',20),('sample_hand','Par','Par',30),
('standard','IRAM 3607:2019','IRAM 3607:2019',10),('standard','IRAM 3607:2023','IRAM 3607:2023',20),('standard','IRAM 3608','IRAM 3608',30),('standard','No normativa','No normativa',40),
('sample_location','Laboratorio','Laboratorio',10),('sample_location','Retención','Retención',20),('sample_location','Depósito','Depósito',30),
('conservation','Ambiente de laboratorio','Ambiente de laboratorio',10),('conservation','Acondicionada','Acondicionada',20),('conservation','Retenida','Retenida',30),
('test_status','Pendiente','Pendiente',10),('test_status','Asignado','Asignado',20),('test_status','En preparación','En preparación',30),('test_status','En ejecución','En ejecución',40),('test_status','Datos cargados','Datos cargados',50),('test_status','Pendiente de revisión','Pendiente de revisión',60),('test_status','Observado','Observado',70),('test_status','Revisado','Revisado',80),('test_status','Aprobado','Aprobado',90),('test_status','Repetición requerida','Repetición requerida',100),('test_status','Anulado','Anulado',110),
('equipment_category','Equipo','Equipo',10),('equipment_category','Instrumento','Instrumento',20),('equipment_category','Patrón','Patrón',30),('equipment_category','Accesorio','Accesorio',40),('equipment_category','Consumible','Consumible',50),
('equipment_status','Apto','Apto',10),('equipment_status','Fuera de servicio','Fuera de servicio',20),('equipment_status','En verificación','En verificación',30),
('equipment_location','Laboratorio','Laboratorio',10),('equipment_location','Calidad','Calidad',20),('equipment_location','Técnica','Técnica',30),('equipment_location','Depósito','Depósito',40),
('event_type','Calibración','Calibración',10),('event_type','Verificación interna','Verificación interna',20),('event_type','Mantenimiento','Mantenimiento',30),('event_type','Reparación','Reparación',40),('event_type','Puesta fuera de servicio','Puesta fuera de servicio',50),('event_type','Liberación para uso','Liberación para uso',60),('event_type','Validación de consumible','Validación de consumible',70),('event_type','Cambio de estado','Cambio de estado',80),
('training_type','Interna','Interna',10),('training_type','Externa','Externa',20),('training_type','Entrenamiento en puesto','Entrenamiento en puesto',30),
('training_result','Aprobado','Aprobado',10),('training_result','Pendiente','Pendiente',20),('training_result','No aprobado','No aprobado',30),
('document_type','Documento','Documento',10),('document_type','Procedimiento','Procedimiento',20),('document_type','Instructivo','Instructivo',30),('document_type','Registro','Registro',40),('document_type','Informe','Informe',50),('document_type','Norma','Norma',60),
('document_status','Vigente','Vigente',10),('document_status','Obsoleto','Obsoleto',20),('document_status','Borrador','Borrador',30),
('unit','ciclos','ciclos',10),('unit','Índice','Índice',20),('unit','N','N',30),('unit','kN','kN',40),('unit','mm','mm',50),('unit','pH','pH',60),('unit','mg/kg','mg/kg',70)
on conflict(category,value) do update set label=excluded.label,sort_order=excluded.sort_order;
