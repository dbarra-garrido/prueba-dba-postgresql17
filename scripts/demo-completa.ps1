$ErrorActionPreference = "Stop"

$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$compose = "docker-compose.automatico.yml"
$contenedor = "laboratorio-postgres17-automatico"
$proyecto = "prueba-dba-postgresql17-automatico"

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
Write-Host "El quinto laboratorio esta listo para automatizarse." -ForegroundColor Green
Write-Host "Creando el quinto laboratorio PostgreSQL 17..." -ForegroundColor Yellow

docker compose -f $compose up -d --build

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible crear el laboratorio automatico."
}

Write-Host "Contenedor iniciado correctamente." -ForegroundColor Green
Write-Host "Esperando PostgreSQL..." -ForegroundColor Yellow

$disponible = $false

for ($intento = 1; $intento -le 30; $intento++) {
    docker exec $contenedor pg_isready -U dba -d laboratorio 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $disponible = $true
        break
    }

    Start-Sleep -Seconds 2
}

if (-not $disponible) {
    throw "PostgreSQL no estuvo disponible."
}

Write-Host "PostgreSQL disponible." -ForegroundColor Green

$volumenRepositorio = "${proyecto}_pgbackrest_repo_automatico"

docker run --rm --user root `
    -v "${volumenRepositorio}:/var/lib/pgbackrest" `
    --entrypoint chown postgres17-pgbackrest:lab `
    -R postgres:postgres /var/lib/pgbackrest

if ($LASTEXITCODE -ne 0) {
    throw "Error configurando permisos pgBackRest."
}

docker exec -u postgres $contenedor `
    pgbackrest --stanza=lab stanza-create

if ($LASTEXITCODE -ne 0) {
    throw "Error creando stanza pgBackRest."
}

Write-Host "pgBackRest configurado correctamente." -ForegroundColor Green

Write-Host "Verificando archivado WAL..." -ForegroundColor Yellow

docker exec -u postgres $contenedor pgbackrest --stanza=lab check
if ($LASTEXITCODE -ne 0) {
    throw "Fallo la verificacion WAL."
}

Write-Host "Ejecutando primer respaldo FULL..." -ForegroundColor Yellow

docker exec -u postgres $contenedor pgbackrest --stanza=lab --type=full backup
if ($LASTEXITCODE -ne 0) {
    throw "Fallo el primer respaldo FULL."
}

Write-Host "Creando tabla postulaciones..." -ForegroundColor Yellow

Get-Content ".\sql\01_crear_tabla.sql" -Raw |
    docker exec -i $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    throw "Fallo la creacion de la tabla."
}

Write-Host "Cargando postulaciones iniciales..." -ForegroundColor Yellow

Get-Content ".\sql\02_datos_iniciales.sql" -Raw |
    docker exec -i $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    throw "Fallo la carga inicial."
}

Write-Host "Ejecutando segundo respaldo FULL..." -ForegroundColor Yellow

docker exec -u postgres $contenedor pgbackrest --stanza=lab --type=full backup
if ($LASTEXITCODE -ne 0) {
    throw "Fallo el segundo respaldo FULL."
}

Write-Host "Respaldos y datos iniciales preparados." -ForegroundColor Green

Write-Host "Creando punto de recuperacion..." -ForegroundColor Yellow

docker exec $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1 `
    -c "SELECT pg_create_restore_point('ANTES_UPDATE_ACCIDENTAL');"

if ($LASTEXITCODE -ne 0) { throw "Fallo la creacion del punto PITR." }

docker exec $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1 `
    -c "SELECT pg_switch_wal();"

if ($LASTEXITCODE -ne 0) { throw "Fallo el cambio de WAL." }

Write-Host "Comprobando archivado del punto PITR..." -ForegroundColor Yellow

$walListo = $false

for ($i = 1; $i -le 30; $i++) {
    docker exec -u postgres $contenedor pgbackrest --stanza=lab check 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $walListo = $true
        break
    }

    Start-Sleep -Seconds 2
}

if (-not $walListo) {
    throw "No se pudo verificar el archivado WAL."
}
Write-Host "Confirmando WAL del punto de recuperacion..." -ForegroundColor Yellow

# Forzar el archivado de todos los WAL generados hasta este momento.
docker exec $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1 `
    -c "SELECT pg_switch_wal();"

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible forzar el archivado WAL."
}

# Comprobar que pgBackRest puede acceder al archivo WAL.
docker exec -u postgres $contenedor pgbackrest --stanza=lab check

if ($LASTEXITCODE -ne 0) {
    throw "pgBackRest no pudo verificar el archivado."
}
Write-Host "Simulando incidente..." -ForegroundColor Yellow

Get-Content ".\sql\03_incidente.sql" -Raw |
    docker exec -i $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Fallo la simulacion del incidente." }

Write-Host "Creando postulaciones posteriores..." -ForegroundColor Yellow

Get-Content ".\sql\04_postulaciones_posteriores.sql" -Raw |
    docker exec -i $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Fallo la insercion posterior." }

Write-Host "Exportando registros posteriores..." -ForegroundColor Yellow

New-Item -ItemType Directory -Force -Path ".\evidencias" | Out-Null
$csv = ".\evidencias\postulaciones_posteriores_automatico.csv"

$datos = docker exec $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1 `
    -c "COPY (SELECT id,nombre,correo,estado,fecha_postulacion FROM public.postulaciones WHERE id IN (6,7,8) ORDER BY id) TO STDOUT WITH (FORMAT csv, HEADER true)"
if ($LASTEXITCODE -ne 0) { throw "Fallo la exportacion CSV." }

[System.IO.File]::WriteAllLines(
    (Join-Path (Get-Location).Path "evidencias\postulaciones_posteriores_automatico.csv"),
    [string[]]$datos,
    [System.Text.UTF8Encoding]::new($false)
)

$registros = @(Import-Csv $csv)
if ($registros.Count -ne 3 -or
    (@($registros | ForEach-Object { $_.id }) -join ",") -ne "6,7,8") {
    throw "CSV de rescate invalido."
}

docker cp $csv "${contenedor}:/tmp/postulaciones_posteriores_demo.csv"
if ($LASTEXITCODE -ne 0) { throw "Fallo la copia del CSV." }

Write-Host "Deteniendo PostgreSQL para PITR..." -ForegroundColor Yellow

docker compose -f $compose stop postgres
if ($LASTEXITCODE -ne 0) { throw "No fue posible detener PostgreSQL." }

Write-Host "Restaurando al punto anterior al incidente..." -ForegroundColor Yellow

docker compose -f $compose run --rm --no-deps `
    --user postgres --entrypoint pgbackrest postgres `
    --stanza=lab --type=name --target=ANTES_UPDATE_ACCIDENTAL `
    --target-action=promote --delta restore

if ($LASTEXITCODE -ne 0) { throw "Fallo la restauracion PITR." }

docker compose -f $compose start postgres
if ($LASTEXITCODE -ne 0) { throw "No fue posible iniciar PostgreSQL." }

Write-Host "Esperando PostgreSQL recuperado..." -ForegroundColor Yellow

$disponible = $false
for ($i = 1; $i -le 30; $i++) {
    docker exec $contenedor pg_isready -U dba -d laboratorio 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $disponible = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $disponible) { throw "PostgreSQL no quedo disponible." }

$antes = docker exec $contenedor psql -U dba -d laboratorio -At `
    -c "SELECT count(*) || ',' || count(*) FILTER (WHERE estado='RECHAZADA') FROM public.postulaciones;"
if ($LASTEXITCODE -ne 0 -or $antes -ne "5,0") {
    throw "La validacion posterior al PITR fallo: $antes"
}

docker cp $csv "${contenedor}:/tmp/postulaciones_posteriores_demo.csv"

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible copiar el CSV tras la recuperacion."
}

Write-Host "Reincorporando postulaciones posteriores..." -ForegroundColor Yellow

Get-Content ".\sql\05_reincorporar_demo.sql" -Raw |
    docker exec -i $contenedor psql -U dba -d laboratorio -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Fallo la reincorporacion." }

$final = docker exec $contenedor psql -U dba -d laboratorio -At `
    -c "SELECT count(*) || ',' || count(*) FILTER (WHERE estado='RECHAZADA') FROM public.postulaciones;"
if ($LASTEXITCODE -ne 0 -or $final -ne "8,0") {
    throw "Validacion final incorrecta: $final"
}

Write-Host "EXITO: 8 postulaciones, 0 rechazadas." -ForegroundColor Green
Write-Host "Demostracion PITR completada." -ForegroundColor Green


