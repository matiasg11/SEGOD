param(
  [Parameter(Mandatory = $true)][string]$DatabaseUrl,
  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\backups\$(Get-Date -Format 'yyyyMMdd-HHmmss')")
)

$ErrorActionPreference = "Stop"
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

supabase db dump --db-url $DatabaseUrl --file (Join-Path $resolvedOutput "roles.sql") --role-only
supabase db dump --db-url $DatabaseUrl --file (Join-Path $resolvedOutput "schema.sql")
supabase db dump --db-url $DatabaseUrl --file (Join-Path $resolvedOutput "data.sql") --data-only --use-copy

$tables = @("staff", "test_catalog", "equipment", "samples", "sample_tests", "raw_test_data")
foreach ($table in $tables) {
  $csvPath = (Join-Path $resolvedOutput "$table.csv").Replace("'", "''")
  psql $DatabaseUrl -v ON_ERROR_STOP=1 -c "\copy public.$table to '$csvPath' with (format csv, header true, encoding 'UTF8')"
}

Write-Output "Backup completo creado en $resolvedOutput"



