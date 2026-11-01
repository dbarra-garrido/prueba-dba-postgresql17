# Resultado de la recuperacion PITR

## Laboratorio
- Plataforma: Conecta Rural
- Motor: PostgreSQL 17
- Contenedores: Docker Compose
- Herramienta de respaldo: pgBackRest
- Metodo: Point-in-Time Recovery (PITR)

## Incidente
Se ejecuto accidentalmente un UPDATE sin clausula WHERE,
cambiando a RECHAZADA las cinco postulaciones existentes.

Posteriormente se registraron tres postulaciones nuevas.

## Recuperacion
Se utilizo el punto de restauracion:
ANTES_UPDATE_ACCIDENTAL

La restauracion fisica con pgBackRest finalizo correctamente.

Despues del PITR se reincorporaron las tres postulaciones
posteriores al incidente desde un archivo CSV.

## Resultado final
- Postulaciones originales recuperadas: 5
- Postulaciones posteriores reincorporadas: 3
- Total de postulaciones: 8
- Postulaciones en estado RECHAZADA: 0
- Estado del repositorio pgBackRest: ok

## Tiempo de recuperacion
El procedimiento manual completo registro aproximadamente
104,82 minutos, incluyendo esperas y verificaciones.

La operacion fisica de restore reporto aproximadamente
445 milisegundos. Este valor no representa el RTO completo.

## Limitaciones
- Los respaldos y archivos WAL se encuentran en volumenes
  locales de Docker, sin almacenamiento externo independiente.
- La reincorporacion posterior al incidente requiere disponer
  de una copia confiable de los registros nuevos.
- El script de restauracion permanece bloqueado para proteger
  el estado recuperado.
- Falta validar la automatizacion completa en un entorno aislado.

## Evidencias
- evidencias/estado_pgbackrest.txt
- evidencias/resultado_final_pitr.txt
- evidencias/postulaciones_posteriores.csv
- evidencias/postulaciones_posteriores_original.csv
