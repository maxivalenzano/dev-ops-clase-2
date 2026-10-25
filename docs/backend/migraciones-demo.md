# Guion didáctico: migraciones PostgreSQL con EF Core

**Estado:** implementación local en curso; CI y despliegue PostgreSQL todavía pendientes de confirmación. Las fases y sus objetivos exactos se declaran en [`backend/schema-compatibility.json`](../../backend/schema-compatibility.json). El [plan de integración](./plan-integracion-postgresql-ef) conserva decisiones y criterios de aceptación.

## Objetivo

Mostrar cómo evoluciona PostgreSQL mientras varias versiones de la API siguen atendiendo solicitudes. P1 crea el esquema inicial; P2 agrega prioridad opcional; P3 completa datos previos y endurece las reglas. Backend, frontend y migrador se construyen desde un único SHA y etiqueta. `TASK_RELEASE` selecciona la versión del backend y `VITE_TASK_RELEASE` la del frontend.

## ¿Qué es una migración?

Una migración describe un cambio versionado del esquema: tablas, columnas, índices, restricciones o transformaciones de datos. EF Core registra las migraciones aplicadas en `__EFMigrationsHistory` y calcula cuáles faltan. Una migración no es un backup: puede quitar estructura o valores, pero no garantiza reconstruirlos.

## EF Core: `Up` y `Down`

- `Up` avanza del esquema anterior al nuevo. En P2 agrega `priority` nullable con `DEFAULT 2`.
- `Down` intenta revertir el cambio definido. Quitar `priority` elimina sus valores; agregarla otra vez no los reconstruye.
- Ambos son operaciones definidas en la migración; no son un backup ni una reversión transaccional general de la aplicación.
- El artefacto de migración se genera/revisa en Packaging. Las pruebas automatizadas contra PostgreSQL real descartable se ejecutan con `bash scripts/test-postgresql.sh`; no se documentan comandos `dotnet ef` inventados para una ruta de inicio que el repo no usa.

## Releases P1, P2 y P3

| Release | Migración objetivo | Evolución | Qué enseña |
| --- | --- | --- | --- |
| **P1** | `20261025000100_001_InitialTasks` | Tabla `tasks` inicial | CRUD y línea base |
| **P2** | `20261025000200_002_AddPriorityNullable` | `priority` nullable, default 2; API admite 1–3 y trata NULL como media | Cambio aditivo compatible |
| **P3** | `20261025000400_004_RequirePriority` | Incluye `003_BackfillPriority` y luego `NOT NULL` más `CHECK (priority BETWEEN 1 AND 3)` | Backfill y reglas de integridad |

Un default actúa cuando se omite el campo; no reemplaza un NULL explícito. El caso NULL heredado se prepara solo en la base descartable del script de pruebas. La compatibilidad se comprueba ejecutando las imágenes P1/P2/P3, no solo leyendo el código.

## Pipeline y parámetros

`azure-pipelines.yml` contiene cinco stages en orden: `Versioning`, `QualityGate`, `Packaging`, `PostgreSQL` y `CD`.

- `deployDemo`: booleano, valor predeterminado `false`; debe seleccionarse `true` para solicitar despliegue manual en EC2.
- `releasePhase`: `P1`, `P2` o `P3`, por defecto `P1`. Ejecutar releases por separado, con `deployDemo=true` y la fase deseada.
- `QualityGate` ejecuta [`scripts/test-postgresql.sh`](../../scripts/test-postgresql.sh), que construye backend para cada fase y el migrador; [`scripts/test-postgresql.py`](../../scripts/test-postgresql.py) prueba las imágenes contra PostgreSQL descartable.
- `Packaging` publica backend, frontend y migrador bajo la misma etiqueta/SHA; los args son `TASK_RELEASE` y `VITE_TASK_RELEASE`.
- `PostgreSQL` ejecuta [`scripts/prepare-postgresql.sh`](../../scripts/prepare-postgresql.sh), incluyendo respaldo a través de [`scripts/backup-postgresql.sh`](../../scripts/backup-postgresql.sh), migración y validaciones.
- `CD` ejecuta [`scripts/deploy-ec2.sh`](../../scripts/deploy-ec2.sh), consume el recibo correspondiente a `BUILD_ID`, `IMAGE_TAG`, `SOURCE_COMMIT`, `RELEASE_PHASE` y `MIGRATION_TARGET`, y no vuelve a migrar.

Los scripts de EC2 necesitan variables y reserva de release que proporciona el pipeline; no deben invocarse a mano con valores arbitrarios. PostgreSQL se mantiene en el proyecto persistente [`compose.data.yaml`](../../compose.data.yaml), separado del rollback de aplicación. Los secretos se generan fuera de Git bajo `/opt/devops-lab/secrets` (directorio 0700, archivos 0444). La aplicación consume el archivo montado mediante `DATABASE_CONNECTION_FILE`.

La aplicación previa debe tolerar el esquema aditivo P2 durante la ventana entre migración y despliegue. La reserva serializa esa ventana para que releases no intercalen cambios.

## Tres operaciones diferentes de recuperación

| Operación | Qué recupera | Ejemplo / límite |
| --- | --- | --- |
| **Rollback de aplicación** | Imagen anterior | P2 a P1 puede mantener esquema P2 si la versión P1 es compatible. No restaura datos ni revierte esquema. |
| **Reversión de esquema (`Down`)** | Estructura según el `Down` de EF | Puede quitar la columna y sus valores. No reconstruye prioridades anteriores. |
| **Restore de backup** | Estado de una copia | Restaurar a una base separada, validar y cortar controladamente. Las escrituras posteriores al snapshot pueden faltar. |

Si una migración falla, consultar `__EFMigrationsHistory` y el esquema real; no asumir que todas las operaciones forman una transacción indivisible. Corregir hacia adelante o reintentar tras resolver la causa. [`scripts/backup-postgresql.sh`](../../scripts/backup-postgresql.sh) genera un dump custom y ensaya restore separado, validando fingerprints. Para volver a verificar una copia existente, usar [`scripts/restore-postgresql.sh`](../../scripts/restore-postgresql.sh): `bash scripts/restore-postgresql.sh BACKUP_DIR restore_nombre_unico`. El nombre debe comenzar con `restore_` y ser nuevo; el script valida checksum y contenido restaurado en esa base aislada, sin sobrescribir ni cambiar la base productiva. El backup también guarda globals/roles aparte del dump de la base.

## Verificaciones

El script de CI comprueba migración desde cero y desde fases previas con datos, repetición idempotente, restricciones, CRUD compartido y compatibilidad de las imágenes. En EC2, el stage PostgreSQL exige consulta autenticada, esquema objetivo compatible, backup con restauración comprobada en base separada y recibo sin secretos. CD verifica las tres réplicas, readiness y datos; si PostgreSQL falla, CD no se ejecuta.

Volumen persistente y backups no son alta disponibilidad: PostgreSQL y la aplicación comparten una VM. El retorno a Redis tampoco es rollback automático; requeriría transferencia inversa consistente.
