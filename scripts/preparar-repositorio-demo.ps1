$ErrorActionPreference = "Stop"

$proyecto = Split-Path -Parent $PSScriptRoot
Set-Location $proyecto

Write-Host "Preparando repositorio pgBackRest de la demo..." -ForegroundColor Cyan

$volumen = "prueba-dba-postgresql17-demo_pgbackrest_repo_demo"

docker volume inspect $volumen *> $null

if ($LASTEXITCODE -ne 0) {
    throw "No existe el volumen de respaldo de la demo."
}

docker run --rm `
    --user root `
    -v "${volumen}:/var/lib/pgbackrest" `
    --entrypoint chown `
    postgres17-pgbackrest:lab `
    -R postgres:postgres /var/lib/pgbackrest

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible configurar los permisos."
}

Write-Host "REPOSITORIO DEMO PREPARADO" -ForegroundColor Green
