$ErrorActionPreference = "Stop"

$proyecto = Split-Path -Parent $PSScriptRoot
Set-Location $proyecto

$proteccion = Join-Path $PSScriptRoot "PROTECCION_PITR.txt"
$csv = Join-Path $proyecto "evidencias\postulaciones_posteriores.csv"
$confirmacion = "AUTORIZO RESTAURACION PITR"

Write-Host "Preparacion de restauracion PITR" -ForegroundColor Cyan

# 1. Impedir restauraciones mientras exista la proteccion
if (Test-Path $proteccion) {
    throw "RESTAURACION BLOQUEADA: existe PROTECCION_PITR.txt."
}

# 2. Comprobar que el CSV este disponible
if (-not (Test-Path $csv)) {
    throw "No existe el CSV de postulaciones posteriores."
}

$registros = @(Import-Csv $csv)

if ($registros.Count -ne 3) {
    throw "El CSV no contiene las tres postulaciones esperadas."
}

# 3. Verificar disponibilidad del repositorio pgBackRest
docker exec --user postgres laboratorio-postgres17 `
    pgbackrest --stanza=lab info

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo verificar el repositorio pgBackRest."
}

# 4. Solicitar autorizacion explicita
Write-Host ""
Write-Host "ADVERTENCIA: esta operacion reemplazara el estado actual de PostgreSQL." -ForegroundColor Yellow

$respuesta = Read-Host "Escriba AUTORIZO RESTAURACION PITR para continuar"

if ($respuesta -cne $confirmacion) {
    throw "Restauracion cancelada: autorizacion no recibida."
}

# 5. Detener PostgreSQL
docker compose stop postgres

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo detener PostgreSQL."
}

# 6. Restaurar hasta el punto anterior al incidente
docker compose run --rm --no-deps `
    --user postgres `
    --entrypoint pgbackrest `
    postgres `
    --stanza=lab `
    --type=name `
    --target=ANTES_UPDATE_ACCIDENTAL `
    --target-action=promote `
    --delta `
    restore

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: la restauracion PITR no finalizo correctamente."
}

# 7. Iniciar PostgreSQL
docker compose up -d --no-build

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo iniciar PostgreSQL despues de la restauracion."
}

Write-Host "Restauracion fisica ejecutada. Verifique la recuperacion y los datos." -ForegroundColor Green
