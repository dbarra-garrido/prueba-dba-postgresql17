-- Laboratorio DBA PostgreSQL 17
-- Proyecto: Conecta Rural
-- Datos iniciales y cambios legitimos

BEGIN;

INSERT INTO public.postulaciones (nombre, correo, estado)
VALUES
    ('Juan Perez', 'juan.perez@example.com', 'RECIBIDA'),
    ('Maria Gonzalez', 'maria.gonzalez@example.com', 'RECIBIDA'),
    ('Pedro Ramirez', 'pedro.ramirez@example.com', 'RECIBIDA'),
    ('Ana Martinez', 'ana.martinez@example.com', 'RECIBIDA'),
    ('Carlos Soto', 'carlos.soto@example.com', 'RECIBIDA');

UPDATE public.postulaciones
SET estado = 'APROBADA'
WHERE correo IN (
    'juan.perez@example.com',
    'pedro.ramirez@example.com'
);

UPDATE public.postulaciones
SET estado = 'EN_REVISION'
WHERE correo = 'maria.gonzalez@example.com';

COMMIT;

SELECT id, nombre, estado
FROM public.postulaciones
ORDER BY id;
