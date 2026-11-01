-- Laboratorio DBA PostgreSQL 17
-- Proyecto: Conecta Rural
-- Simulacion del incidente: UPDATE sin WHERE
-- ATENCION: ejecutar solamente en un entorno de prueba.

-- Registrar el momento del incidente
SELECT clock_timestamp() AS hora_incidente;

-- Simular el error del operador
BEGIN;

UPDATE public.postulaciones
SET estado = 'RECHAZADA';

COMMIT;

-- Verificar los registros afectados
SELECT id, nombre, estado
FROM public.postulaciones
ORDER BY id;
