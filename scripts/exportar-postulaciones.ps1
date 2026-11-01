$ErrorActionPreference = "Stop"

# Identificar la carpeta principal del proyecto
$proyecto = Split-Path -Parent $PSScriptRoot
Set-Location $proyecto

# Crear carpeta de evidencias si no existe
New-Item -ItemType Directory -Path ".\evidencias" -Force | Out-Null

$archivo = Join-Path $proyecto "evidencias\postulaciones_posteriores.csv"
$temporal = "$archivo.tmp"

Write-Host "Exportando postulaciones posteriores al incidente..." -ForegroundColor Cyan

# Exportar los registros desde PostgreSQL
docker exec laboratorio-postgres17 `
    psql -X -U dba -d laboratorio -v ON_ERROR_STOP=1 `
    -c "COPY (SELECT id, nombre, correo, estado, fecha_postulacion FROM public.postulaciones WHERE correo IN ('laura.fernandez@example.com', 'roberto.silva@example.com', 'camila.torres@example.com') ORDER BY id) TO STDOUT WITH (FORMAT csv, HEADER true)" |
    Set-Content $temporal -Encoding UTF8

if ($LASTEXITCODE -ne 0) {
    Remove-Item $temporal -ErrorAction SilentlyContinue
    throw "Error al exportar las postulaciones."
}

# Comprobar que el archivo contiene exactamente tres registros
$registros = @(Import-Csv $temporal)

if ($registros.Count -ne 3) {
    Remove-Item $temporal -ErrorAction SilentlyContinue
    throw "Se esperaban 3 registros, pero se encontraron $($registros.Count)."
}

# Conservar el CSV anterior y publicar el nuevo archivo
if (Test-Path $archivo) {
    $respaldo = "$archivo.anterior"
    Copy-Item $archivo $respaldo -Force
}

Move-Item $temporal $archivo -Force

Write-Host "Exportacion completada: 3 postulaciones." -ForegroundColor Green
Write-Host "Archivo: $archivo"
