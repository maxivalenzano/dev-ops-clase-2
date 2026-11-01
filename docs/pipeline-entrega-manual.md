# Operación del pipeline con entrega manual

## Límites entre CI y CD

| Stage | Inicio | Entorno y efecto |
| --- | --- | --- |
| Versioning | Automático | Agente hospedado; calcula versión |
| QualityGate | Automático | Agente hospedado; pruebas y análisis |
| Packaging | Automático | Agente hospedado; construye imágenes, prueba migraciones en PostgreSQL descartable y publica artefactos |
| PostgreSQL | Manual | EC2; respaldo, migraciones y verificación de la aplicación anterior |
| CD | Manual independiente | EC2; reemplaza contenedores y verifica el despliegue |

La publicación de imágenes no cambia los contenedores que ya están ejecutándose. `prepare-postgresql.sh` es un coordinador de entrega de base de datos, aunque conserve su nombre histórico; nunca se ejecuta desde los stages automáticos de CI. Su provisión inicial de red, secretos, roles e importación desde Redis sigue dentro del coordinador existente; esta modificación no refactoriza esos procedimientos ni agrega migraciones.

## Inicio y autorizaciones

Después de CI, iniciar el stage PostgreSQL desde la ejecución de Azure Pipelines. Al finalizar, inspeccionar las evidencias y la aplicación anterior; después iniciar CD en el mismo build. Ambos stages tienen `trigger: manual`. No se utiliza una tarea de validación que reanude automáticamente por timeout.

`main`, `devel` y tags `v*` conservan su elegibilidad. Para otra rama se requiere una ejecución manual del pipeline y `deployDemo=true`. Ese parámetro no omite los inicios manuales. Las pull requests quedan excluidas. Los stages de CI y PostgreSQL no se pueden omitir; las condiciones también exigen QualityGate/Packaging exitosos antes de PostgreSQL y PostgreSQL exitoso antes de CD.

El inicio manual controla cuándo se ejecuta un stage. Si se requiere una aprobación de una persona o grupo específico, los administradores deben mantener/configurar **Approvals and checks** en el Environment `devops-ec2-env`. Ambos stages consumen ese Environment, por lo que sus checks aplican antes de cada stage. El YAML no configura ni verifica esos permisos externos.

## Reserva entre stages y recuperación

PostgreSQL conserva `/opt/devops-lab/.release-reservation.json` hasta que CD termina o el operador recupera explícitamente el flujo. Esta reserva evita que otro build migre o despliegue mientras se inspecciona el estado. En una actualización normal, al finalizar PostgreSQL se reinician los backends anteriores y se comprueba `/api/ready`; hacer además pruebas de lectura/escritura antes de continuar. En la primera instalación no se garantiza una aplicación operativa hasta completar CD.

Si CD falla, revisar su intento de rollback y las evidencias. Si se cancela el pipeline o se abandona CD, no borrar la reserva a ciegas: confirmar que no hay migrador ni despliegue activo, que el estado de la base es conocido y que se decidió cómo recuperar la aplicación. Después ejecutar en EC2, con el checkout de esta release:

```bash
BUILD_ID=<build_original> \
SOURCE_COMMIT=<sha_original_de_40_caracteres> \
IMAGE_TAG=<tag_original> \
bash scripts/release-reservation.sh --after-inspection
```

Usar valores reales en lugar de los marcadores. La operación exige la propiedad de la reserva, no revierte migraciones y no restaura datos ni inicia contenedores. Conservar las evidencias y el backup antes de autorizar otro build.

## Validación y alcance

La comprobación local del YAML y de sus dependencias no sustituye la validación de Azure Pipelines ni una ejecución real. La primera ejecución debe confirmar que CI finaliza sin jobs en EC2, que PostgreSQL espera inicio manual y que CD sigue esperando otro inicio después de PostgreSQL. No iniciar estos stages sobre EC2 únicamente para validar un cambio de YAML.

Referencias oficiales: [triggers manuales por stage](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/stages-stage?view=azure-pipelines) y [aprobaciones de recursos](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops).
