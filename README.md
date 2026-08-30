# SEGOD — Sistema de Laboratorio

Backend reproducible en Supabase para gestionar muestras, ensayos y datos crudos del laboratorio de SEGOD.

## Proyecto remoto

- Supabase project ref: `bpanhapwtdsnjsdiyyro`
- Esquema principal: `public`
- Migraciones: `supabase/migrations/`

## Identificación de muestras

Cada muestra tiene dos identificadores:

- `id`: UUID interno único y estable.
- `sample_name`: rótulo automático legible, por ejemplo `M-2026-000001`.

Las relaciones siempre usan el UUID interno.

## Datos de AppSheet

El script `scripts/extract_appsheet_excel.py` convierte cada hoja del Excel original en CSV UTF-8. `scripts/build_seed_from_excel.py` genera `supabase/seed.sql` con los catálogos de personal, ensayos y equipos.

## Backup

`scripts/backup_supabase.ps1` genera:

- roles SQL;
- esquema SQL;
- datos SQL con `COPY`;
- un CSV por tabla, incluido `raw_test_data.csv` con todas las mediciones crudas.

No guardar URLs de conexión, contraseñas ni backups reales en Git.

## Desarrollo

1. Instalar Supabase CLI y Docker.
2. Ejecutar `supabase link --project-ref bpanhapwtdsnjsdiyyro`.
3. Ejecutar `supabase db reset` para recrear la base local.
4. Usar `supabase db push` para aplicar nuevas migraciones remotas.

Consultar `docs/SUPABASE_MIGRATION.md` para el procedimiento completo.

