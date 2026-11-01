-- Laboratorio DBA PostgreSQL 17
-- Proyecto: Conecta Rural
-- Creacion de tabla de postulaciones

CREATE TABLE IF NOT EXISTS public.postulaciones (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    estado VARCHAR(30) NOT NULL DEFAULT 'RECIBIDA',
    fecha_postulacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
