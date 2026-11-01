\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE rescate_demo (
    id BIGINT,
    nombre VARCHAR(100),
    correo VARCHAR(150),
    estado VARCHAR(30),
    fecha_postulacion TIMESTAMPTZ
) ON COMMIT DROP;

\copy rescate_demo FROM '/tmp/postulaciones_posteriores_demo.csv' WITH (FORMAT csv, HEADER true)

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM rescate_demo) <> 3 THEN
        RAISE EXCEPTION 'Se esperaban exactamente 3 postulaciones';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rescate_demo
        GROUP BY id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'IDs duplicados en el CSV';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rescate_demo
        GROUP BY correo
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Correos duplicados en el CSV';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM postulaciones p
        JOIN rescate_demo r
          ON p.id = r.id OR p.correo = r.correo
    ) THEN
        RAISE EXCEPTION 'Existen postulaciones que colisionan con el rescate';
    END IF;
END
$$;

INSERT INTO public.postulaciones
    (id, nombre, correo, estado, fecha_postulacion)
OVERRIDING SYSTEM VALUE
SELECT id, nombre, correo, estado, fecha_postulacion
FROM rescate_demo
ORDER BY id;

SELECT setval(
    pg_get_serial_sequence('public.postulaciones', 'id'),
    (SELECT MAX(id) FROM public.postulaciones),
    true
);

COMMIT;
