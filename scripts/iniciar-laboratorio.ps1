$ErrorActionPreference = "Stop"

# Ubicarse en la carpeta principal del proyecto
$proyecto = Split-Path -Parent $PSScriptRoot
Set-Location $proyecto

Write-Host "Iniciando laboratorio PostgreSQL 17..." -ForegroundColor Cyan

# Verificar disponibilidad de Docker
docker info --format '{{.ServerVersion}}' | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop no esta disponible."
}

# Verificar los volumenes existentes
$volumenes = @(
    "prueba-dba-postgresql17_postgres_data",
    "prueba-dba-postgresql17_pgbackrest_repo"
)

foreach ($volumen in $volumenes) {
    docker volume inspect $volumen *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "No existe el volumen requerido: $volumen"
    }
}

# Iniciar el contenedor
docker compose up -d --no-build

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible iniciar PostgreSQL."
}

# Esperar hasta 60 segundos a que PostgreSQL este listo
$disponible = $false

for ($intento = 1; $intento -le 30; $intento++) {

    docker exec laboratorio-postgres17 pg_isready -U dba -d laboratorio *> $null

    if ($LASTEXITCODE -eq 0) {
        $disponible = $true
        break
    }

    Start-Sleep -Seconds 2
}

if (-not $disponible) {
    throw "PostgreSQL no estuvo disponible dentro de 60 segundos."
}

Write-Host "PostgreSQL disponible." -ForegroundColor Green
Write-Host "Laboratorio iniciado correctamente." -ForegroundColor Green
