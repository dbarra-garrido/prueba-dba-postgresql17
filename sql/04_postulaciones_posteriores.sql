-- Laboratorio DBA PostgreSQL 17
-- Proyecto: Conecta Rural
-- Postulaciones ingresadas despues del incidente
-- Ejecutar solamente durante una simulacion nueva.

BEGIN;

INSERT INTO public.postulaciones (nombre, correo, estado)
VALUES
    ('Laura Fernandez', 'laura.fernandez@example.com', 'RECIBIDA'),
    ('Roberto Silva', 'roberto.silva@example.com', 'RECIBIDA'),
    ('Camila Torres', 'camila.torres@example.com', 'RECIBIDA');

COMMIT;

-- Verificar las postulaciones posteriores
SELECT id, nombre, correo, estado, fecha_postulacion
FROM public.postulaciones
WHERE correo IN (
    'laura.fernandez@example.com',
    'roberto.silva@example.com',
    'camila.torres@example.com'
)
ORDER BY id;
