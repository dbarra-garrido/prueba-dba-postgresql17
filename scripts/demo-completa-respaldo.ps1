$ErrorActionPreference = "Stop"

$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$compose = "docker-compose.run.yml"
$contenedor = "laboratorio-postgres17-run"
$proyecto = "prueba-dba-postgresql17-run"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DEMOSTRACION AUTOMATICA POSTGRESQL 17" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Verificando Docker..." -ForegroundColor Yellow

docker info --format "{{.ServerVersion}}" | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Docker no esta disponible."
}

Write-Host "Validando Docker Compose..." -ForegroundColor Yellow

docker compose -f $compose config --quiet

if ($LASTEXITCODE -ne 0) {
    throw "La configuracion Docker Compose es invalida."
}

Write-Host "Comprobando recursos existentes..." -ForegroundColor Yellow

$contenedorExistente = docker ps -a --filter "name=^/${contenedor}$" --format "{{.Names}}"

if ($contenedorExistente) {
    throw "El contenedor $contenedor ya existe. No se modificara."
}

$volumenes = @(docker volume ls --filter "name=${proyecto}_" --format "{{.Name}}" | Where-Object { $_ })

if ($volumenes.Count -gt 0) {
    throw "Existen volumenes del laboratorio. No se sobrescribiran."
}

Write-Host "Validaciones iniciales correctas." -ForegroundColor Green
Write-Host "El cuarto laboratorio esta listo para automatizarse." -ForegroundColor Green
Write-Host "Creando el cuarto laboratorio PostgreSQL 17..." -ForegroundColor Yellow

docker compose -f $compose up -d --build

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible crear el laboratorio automatico."
}

Write-Host "Contenedor iniciado correctamente." -ForegroundColor Green