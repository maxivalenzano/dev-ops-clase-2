# Integración PostgreSQL y migraciones EF Core

**Fecha:** 2026-10-25
**Estado:** cambios locales en preparación; CI/CD y PostgreSQL en EC2 pendientes de resultado confirmado.

## Objetivos

- Incorporar PostgreSQL como persistencia del tablero y EF Core como gestor versionado del esquema.
- Demostrar releases compatibles P1, P2 y P3, con respaldo y recuperación separados del rollback de aplicación.
- Ejecutar pruebas de integración con PostgreSQL descartable en CI y desplegar base y aplicación en stages distintos.

## Evidencia disponible

- La inspección SSH de solo lectura documentada en el plan confirmó el estado previo en EC2: aplicación `3.0.3-build.85`, Redis con cero tareas, 1.158 MiB de memoria disponible y aproximadamente 15 GiB libres. PostgreSQL aún no estaba instalado/probado durante esa inspección.
- `npm run build` del frontend pasó localmente, según la ejecución registrada por el agente coordinador.
- `npm run docs:build` pasó localmente en 50,34 s. La vista previa de Azure DevOps aceptó el YAML con cinco stages; esto valida el parseo/preview, no una ejecución del pipeline.
- No se atribuye éxito a CI, al stage PostgreSQL, al despliegue de EC2 ni a las verificaciones de P1/P2/P3 hasta recibir evidencia de esas ejecuciones.

## Flujo implementado en el repositorio

El pipeline declara cinco stages: `Versioning`, `QualityGate`, `Packaging`, `PostgreSQL` y `CD`. Sus parámetros son `deployDemo` (default `false`) y `releasePhase` (`P1`, `P2` o `P3`, default `P1`). El mismo SHA produce backend, frontend y migrador; `TASK_RELEASE` y `VITE_TASK_RELEASE` seleccionan la fase.

Los objetivos exactos están en [`backend/schema-compatibility.json`](../../backend/schema-compatibility.json). El Quality Gate llama a [`scripts/test-postgresql.sh`](../../scripts/test-postgresql.sh), que utiliza PostgreSQL descartable. PostgreSQL se prepara con [`scripts/prepare-postgresql.sh`](../../scripts/prepare-postgresql.sh) y [`scripts/backup-postgresql.sh`](../../scripts/backup-postgresql.sh); CD llama a [`scripts/deploy-ec2.sh`](../../scripts/deploy-ec2.sh) y consume el recibo del mismo BuildId/SHA. La infraestructura persistente está separada en [`compose.data.yaml`](../../compose.data.yaml).

## Redis legado

Redis sigue siendo la fuente de verdad del despliegue existente hasta completar y verificar el primer corte P1. No se borra su servicio ni su volumen como parte del rollback de aplicación. En el primer corte planeado, las escrituras se pausan, se genera respaldo/exportación y se importan tareas preservando IDs antes de pasar el tráfico a PostgreSQL. Una vez escritas tareas nuevas en PostgreSQL, volver a Redis exige transferencia inversa; no es un rollback automático.

## Recuperación y próximos pasos

El rollback de aplicación conserva esquema PostgreSQL compatible. `Down` puede perder datos de una columna y no sustituye un backup. El restore se valida en una base separada antes del corte.

Pendiente: observar resultados del pipeline, verificar primera preparación P1 en EC2, confirmar recibo y despliegue CD, y luego realizar P2/P3 como releases independientes. Registrar comandos y salidas reales al contar con evidencia; nunca incluir credenciales o dumps.
