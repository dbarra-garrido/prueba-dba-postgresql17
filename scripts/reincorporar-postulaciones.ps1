$ErrorActionPreference = "Stop"

$proyecto = Split-Path -Parent $PSScriptRoot
Set-Location $proyecto

$csv = Join-Path $proyecto "evidencias\postulaciones_posteriores.csv"
$contenedor = "laboratorio-postgres17"
$csvContenedor = "/tmp/postulaciones_posteriores.csv"

if (-not (Test-Path $csv)) {
    throw "No existe el archivo CSV."
}

$registros = @(Import-Csv $csv)

if ($registros.Count -ne 3) {
    throw "Se esperaban exactamente 3 postulaciones."
}

Write-Host "Preparando reincorporacion de postulaciones..." -ForegroundColor Cyan

docker cp $csv "${contenedor}:${csvContenedor}"

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible copiar el CSV al contenedor."
}

$sql = @"
BEGIN;

CREATE TEMP TABLE postulaciones_importadas (
    id BIGINT,
    nombre VARCHAR(100),
    correo VARCHAR(150),
    estado VARCHAR(30),
    fecha_postulacion TIMESTAMPTZ
) ON COMMIT DROP;

\copy postulaciones_importadas FROM '$csvContenedor' WITH (FORMAT csv, HEADER true)

DO `$`$
BEGIN
    IF (SELECT COUNT(*) FROM postulaciones_importadas) <> 3 THEN
        RAISE EXCEPTION 'Cantidad de postulaciones incorrecta';
    END IF;

    IF EXISTS (
        SELECT correo
        FROM postulaciones_importadas
        GROUP BY correo
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'El CSV contiene correos duplicados';
    END IF;
END
`$`$;

DO `$`$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM postulaciones_importadas i
        JOIN public.postulaciones p
          ON p.id = i.id OR p.correo = i.correo
    ) THEN
        RAISE EXCEPTION 'Conflicto: existen IDs o correos en la tabla destino';
    END IF;

    IF EXISTS (
        SELECT id
        FROM postulaciones_importadas
        GROUP BY id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'El CSV contiene IDs duplicados';
    END IF;
END
`$`$;

INSERT INTO public.postulaciones (
    id, nombre, correo, estado, fecha_postulacion
)
OVERRIDING SYSTEM VALUE
SELECT id, nombre, correo, estado, fecha_postulacion
FROM postulaciones_importadas
ORDER BY id;

SELECT setval(
    pg_get_serial_sequence('public.postulaciones', 'id'),
    (SELECT MAX(id) FROM public.postulaciones),
    true
);

COMMIT;

SELECT id, nombre, estado
FROM public.postulaciones
ORDER BY id;
"@

$sql | docker exec -i $contenedor `
    psql -X -U dba -d laboratorio -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    throw "Error al reincorporar postulaciones."
}

Write-Host "Proceso de reincorporacion finalizado." -ForegroundColor Green


