# Infraestructura y red

P3 (`3.1.6-build.91`) está activa en Ubuntu EC2 con esquema PostgreSQL 004. Nginx enruta tráfico a tres réplicas frontend y tres backend. PostgreSQL se administra en un proyecto Compose persistente separado del rollback de aplicación mediante [`compose.data.yaml`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/compose.data.yaml). Redis y su volumen siguen presentes como legado, sin escrituras nuevas.

| Servicio | Réplicas | Exposición | Función |
|---|---:|---|---|
| Nginx gateway | 1 | Puerto 80 | Entrada HTTP; enruta `/` y `/api/` |
| Frontend React/Nginx | 3 | Interno, 8081 | Aplicación SPA |
| API .NET 10 | 3 | Interno, 3000 | Tareas, readiness, salud y Chaos Lab |
| PostgreSQL 17 | 1 | Red privada, sin puerto host | Fuente de verdad; volumen `postgres-data` |
| Redis 7 | 1 | Red privada, sin puerto host | Almacén legado; volumen `redis-data` conservado |
| Portainer CE | 1 | Loopback 9000/9443 | Administración visual |

Nginx balancea tráfico entre réplicas. PostgreSQL y los servicios de aplicación comparten una sola VM: el volumen y los backups no proporcionan alta disponibilidad del host.

## Pipeline y verificación

Azure Pipelines ejecuta cinco stages: `Versioning`, `QualityGate`, `Packaging`, `PostgreSQL` y `CD`. Packaging publica un manifiesto derivado del historial EF del build. PostgreSQL valida que ambos historiales compartan una cadena de prefijo y ejecuta el bundle sin destino cuando la base está atrasada; si ya está más avanzada, la conserva. Nunca ejecuta `Down`. P1/P2/P3 y build91 son evidencia de despliegues históricos; ya no son fases de ejecución del pipeline.

La integración local contra PostgreSQL descartable requiere Linux y Docker:

```bash
bash scripts/test-postgresql.sh
```

Podman sobre Windows/WSL tiene una limitación de red observada y no se validó para este stack. La demo oficial usa HTTP por IP; dominio y HTTPS de aplicación no se validaron.

## Antecedente histórico

Antes de P1, EC2 ejecutaba `3.0.3-build.85` con Redis como fuente de verdad y nueve contenedores. Los informes de CI81, Redis y Portainer en [bitácoras anteriores](/bitacora/) describen esa topología histórica. La inspección previa a PostgreSQL fue de solo lectura y no prueba por sí misma la operación actual.
