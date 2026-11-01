# Prueba técnica DBA — PostgreSQL 17 y recuperación PITR

## 1. Objetivo

Demostrar cómo recuperar una base de datos PostgreSQL 17 al estado inmediatamente anterior a una modificación masiva accidental, utilizando pgBackRest y archivado continuo de WAL.

Caso simulado: sistema de postulaciones de Conecta Rural.

## 2. Tecnologías

- PostgreSQL 17 (imagen oficial como base)
- Docker y Docker Compose
- pgBackRest
- PowerShell
- SQL

## 3. Escenario

La tabla `public.postulaciones` contiene cinco postulaciones válidas.

Se simula el incidente:

```sql
UPDATE public.postulaciones
SET estado = 'RECHAZADA';
```

Posteriormente se ingresan tres postulaciones legítimas.

El objetivo es recuperar el estado anterior al incidente y conservar, mediante exportación y reincorporación controlada, los tres registros posteriores.

## 4. Estrategia de recuperación

1. Configurar archivado continuo de WAL.
2. Crear la stanza y ejecutar respaldos completos con pgBackRest.
3. Cargar datos válidos.
4. Crear el punto de restauración `ANTES_UPDATE_ACCIDENTAL`.
5. Simular el UPDATE accidental.
6. Registrar tres postulaciones posteriores.
7. Exportar las postulaciones posteriores a CSV.
8. Detener PostgreSQL.
9. Ejecutar recuperación PITR al punto anterior al incidente.
10. Reiniciar PostgreSQL y validar los datos recuperados.
11. Reincorporar los registros rescatados.
12. Verificar el estado final.

## 5. Resultados observados

En los laboratorios ejecutados se consiguió:

| Indicador | Resultado |
|---|---:|
| Registros originales recuperados | 5 |
| Registros posteriores reincorporados | 3 |
| Total final de postulaciones | 8 |
| Registros en estado RECHAZADA | 0 |
| Recuperación PITR | Exitosa |

Las evidencias de las ejecuciones se conservan en el directorio `evidencias/`.

## 6. Reproducción

Requisitos:

- Docker Desktop funcionando.
- Docker Compose disponible.
- PowerShell.
- Puertos configurados libres.

Desde la raíz del proyecto:

```powershell
.\scripts\demo-completa.ps1
```

El script utiliza `docker-compose.automatico.yml` y está diseñado para no sobrescribir contenedores o volúmenes existentes.

**Estado de validación:** la sintaxis PowerShell fue verificada. La ejecución completa de esta versión automatizada todavía está pendiente de validación.

## 7. Recuperación y continuidad

### RPO

El RPO depende de la disponibilidad de los segmentos WAL archivados. Ante la pérdida del servidor y de su repositorio local, podría perderse información.

No se garantiza RPO cero.

### RTO

El RTO debe medirse desde el inicio de la intervención hasta que PostgreSQL vuelva a estar operativo y los datos sean validados.

El tiempo de ejecución aislado del comando de restauración no representa el RTO total.

### Conservación de datos posteriores

PITR recupera la base al punto elegido y descarta de esa línea temporal los cambios posteriores. Por eso se exportaron previamente tres postulaciones legítimas y se reincorporaron tras validar la recuperación.

En producción, el rescate debe evaluarse según la disponibilidad de una copia de la base afectada, los WAL y los requisitos de consistencia.

## 8. Limitaciones y mejoras

- El repositorio pgBackRest está en un volumen Docker local: no constituye protección suficiente ante la pérdida completa del host.
- En producción se recomienda un repositorio remoto o fuera del dominio de falla.
- Se requieren restauraciones periódicas de prueba.
- Conviene automatizar alertas sobre fallas de respaldo y archivado.
- Se debe medir y registrar el RTO completo.
- La automatización integral debe validarse en un entorno limpio antes de considerarla lista para producción.

## 9. Evidencias

Archivos generados durante las pruebas:

- `evidencias/resultado_final_auto.txt`
- `evidencias/postulaciones_posteriores_auto.csv`
- `evidencias/resultado_final_run.txt`
- `evidencias/postulaciones_posteriores_run.csv`

## 10. Colaboración con IA

Se utilizó ChatGPT como apoyo para estructurar el laboratorio, preparar comandos PowerShell y SQL, revisar errores, documentar decisiones y analizar resultados.

Las ejecuciones y validaciones técnicas fueron realizadas en el entorno local. Los resultados informados corresponden a pruebas efectivamente ejecutadas; no se atribuyen resultados a la automatización aún no probada.

Se debe adjuntar el historial de colaboración con IA como parte de la entrega.
