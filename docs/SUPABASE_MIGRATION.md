# Migración del laboratorio a otra organización de Supabase

Este paquete parte de `Certificación de Laboratorio (1).xlsx`, la base de AppSheet.

## Diseño

- `samples.id`: UUID interno único, estable y no visible como nombre operativo.
- `samples.sample_name`: nombre automático `M-AAAA-000001`.
- `sample_tests`: un registro por ensayo solicitado/realizado.
- `raw_test_data`: conserva las mediciones crudas en `jsonb`, incluyendo tipo, secuencia y hoja/fila de origen.
- Catálogos separados para personal, equipos y ensayos.

La secuencia del nombre visible no es la clave primaria. Esto evita romper relaciones si cambia el formato de rotulado.

## Despliegue en la nueva organización

1. Crear un proyecto vacío dentro de la organización destino.
2. Vincular este directorio al proyecto con Supabase CLI.
3. Aplicar `supabase/migrations/202608300001_laboratorio_base.sql`.
4. Configurar los usuarios en Auth y revisar las políticas RLS antes de habilitar el cliente.
5. Extraer el Excel a CSV UTF-8 con:

   `python scripts/extract_appsheet_excel.py "C:\ruta\Certificación de Laboratorio (1).xlsx" staging_excel`

6. Importar los catálogos y luego muestras, ensayos y datos crudos respetando ese orden.

## Backup recuperable y datos crudos

Ejecutar:

`powershell -File scripts/backup_supabase.ps1 -DatabaseUrl "postgresql://..."`

El resultado incluye roles, esquema y datos en SQL, más un CSV por tabla. `raw_test_data.csv` contiene el JSON crudo completo de cada subensayo. Guardar la carpeta fuera del repositorio y nunca publicar la URL de conexión.

Los backups administrados de Supabase no reemplazan este export lógico: Storage requiere respaldo separado si más adelante se adjuntan certificados o archivos.


