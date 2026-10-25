# Integración PostgreSQL y migraciones EF Core

**Fecha:** 2026-10-25
**Estado:** completo. P1, P2 y P3 se desplegaron sucesivamente; P3 (`3.1.6-build.91`, esquema 004) es la versión activa después de resiliencia, backup/restore off-host y rollback P3→P1→P3.

## Objetivos

- Incorporar PostgreSQL como persistencia del tablero y EF Core como gestor versionado del esquema.
- Demostrar releases compatibles P1, P2 y P3, con respaldo y recuperación separados del rollback de aplicación.
- Ejecutar pruebas de integración con PostgreSQL descartable en CI y desplegar base y aplicación en stages distintos.

## Evidencia disponible

- La inspección SSH de solo lectura documentada en el plan confirmó el estado previo en EC2: aplicación `3.0.3-build.85`, Redis con cero tareas, 1.158 MiB de memoria disponible y aproximadamente 15 GiB libres. PostgreSQL aún no estaba instalado/probado durante esa inspección.
- `npm run build` del frontend pasó localmente, según la ejecución registrada por el agente coordinador.
- `npm run docs:build` pasó localmente en 50,34 s. La vista previa de Azure DevOps aceptó el YAML con cinco stages; esto valida el parseo/preview, no una ejecución del pipeline.
- En local, .NET terminó con 46/46 pruebas aprobadas, 0 fallidas y 0 omitidas; el build fue limpio y `dotnet ef has-pending-model-changes` no encontró diferencias.
- El agente backend revisó el SQL de avance e inverso. El SQL de `004` aplica `NOT NULL` sin un backfill implícito y conserva `003` como paso explícito.
- La prueba de reserva concurrente en EC2 pasó en un directorio aislado de `/tmp`: tras liberarse `flock`, impidió que un segundo build tomara la reserva. No modificó la aplicación.
- El build 86 se canceló para incluir correcciones. El [build Azure DevOps 87](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=87) terminó correctamente con sus cinco stages para P1, desde el commit `524b5b9fce0c71e6a4c4a752e185fdc82b713cb3`, tag `3.1.1-build.87`; reportó 46 pruebas unitarias y 13 de integración aprobadas.
- P1 quedó desplegado en EC2 el 25/10/2026: PostgreSQL healthy y diez servicios en ejecución; esquema `20261025000100_001_InitialTasks`; recibo de preparación y verificación de aplicación aprobados. La preparación duró 21 s según el recibo.
- El backup custom se restauró y verificó en una base separada; el registro mostró 0 s por resolución a segundos enteros. Ese valor no representa una promesa de RTO cero.
- Los artefactos `migrations/postgresql-evidence` y `database-backup` se publicaron en Azure Pipelines, fuera de EC2. La preparación se registró a las 21:48:13 UTC y el despliegue a las 21:49:37 UTC (18:48 y 18:49 hora de Argentina, respectivamente).
- Durante `verify-deployment.sh --resilience`, detener PostgreSQL produjo HTTP 504 en Nginx: el timeout de conexión del backend (5 s) coincidía con el timeout del proxy (5 s). El bloque `finally` volvió a iniciar PostgreSQL y comprobó que la tarea marcador siguiera allí.
- El primer intento, `d47b0d4`, redujo a 2 s el timeout de conexión, pero no cubrió toda la operación: build89 siguió observando 504. `e7376d4` agregó Nginx real a la prueba de CI para exigir 503.
- El commit `07e6c9a` implementó un deadline de ASP.NET de 2 s con `CancellationToken` propagado a EF/Npgsql y `CancellationTimeout` de 500 ms para operaciones de tareas y readiness; Chaos Lab queda excluido. Tres pruebas nuevas comprueban cancelación en GET, cancelación en POST y que Chaos Lab mantenga respuesta 200 tras 2.100 ms. El total local fue 49/49 pruebas aprobadas.
- Build 88 P2: `QualityGate` y `Packaging` pasaron; el stage PostgreSQL migró a `20261025000200_002_AddPriorityNullable`. En la ventana previa al CD, una aplicación P1 respondió `/api/ready` como `UP` frente al esquema 002, evidencia de compatibilidad durante esa ventana.
- El [build Azure DevOps 88](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=88) terminó correctamente con los cinco stages para P2, desde el commit `1e930c4d1aeef8274f134dbbc8ee797b3a7864ee`, tag `3.1.2-build.88`. El esquema pasó de `20261025000100_001_InitialTasks` a `20261025000200_002_AddPriorityNullable`; preparación 11 s, `task_count=1`, backup/restore verificado y verificación final aprobada.
- Preparación registrada a las 22:37:46 UTC y despliegue a las 22:39:07 UTC del 25/10/2026 (19:37 y 19:39 en Argentina).
- Una copia del backup de build88 se descargó desde Azure Pipelines fuera de EC2. Su SHA-256 coincide con el manifiesto y la evidencia de restore está presente.
- El marcador P1 `c7bd9b93-d336-42b4-a6b1-ac36900741a1` conservó sus campos iniciales durante el cambio. Ya en P2 se asignó `priority = NULL` únicamente a ese marcador temporal, mediante SQL protegido por una guarda que requería esquema 002. SQL confirmó NULL y la API P2 lo presentó como prioridad 2 (media). P3 completó el valor con el backfill; luego rollback P3→P1→P3 lo preservó con prioridad 3. La tarea se eliminó por API después de las pruebas.
- El [build Azure DevOps 89](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=89) para P3 falló en `QualityGate`: la prueba de gateway esperaba `503` al hacer `POST /api/tasks` con PostgreSQL detenido, pero recibió `504`. Nueve pruebas de integración pasaron y la décima falló; las pruebas restantes no se ejecutaron. `Packaging`, `PostgreSQL` y `CD` quedaron `SKIPPED`, por lo que este build no modificó EC2.
- El [build Azure DevOps 90](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=90) volvió a fallar el caso de gateway `POST /api/tasks` con 504, pese a 49 pruebas unitarias y nueve pruebas de integración aprobadas; los stages posteriores se omitieron. El log indicó que la resolución DNS Unix/musl (`GetHostEntryOrAddressesCore`) bloqueó aproximadamente 5,1 s; la cancelación cooperativa no interrumpió esa llamada bloqueante.
- En un probe descartable de EC2, sin consultar ni modificar la base activa, la misma imagen P2 intentó resolver un host inexistente. Con opciones DNS por defecto, GET respondió 503 tras 5,717 s y POST tras 5,320 s y 5,083 s. Con `timeout:1` y `attempts:1`, GET respondió 503 tras 1,663 s y POST tras 1,256 s y 1,099 s. El contenedor y la red del probe se limpiaron al terminar. Estas mediciones describen ese entorno y no son una garantía general.
- La evidencia concuerda con la implementación Unix de .NET, el comportamiento de DNS de Docker/Compose y el comportamiento de musl; no garantiza idénticos tiempos en todos los hosts: [Docker DNS services](https://docs.docker.com/engine/network/#dns-services), [Compose `dns_opt`](https://docs.docker.com/reference/compose-file/services/#dns_opt), [implementación Unix de .NET 10](https://github.com/dotnet/runtime/blob/v10.0.0/src/libraries/System.Net.NameResolution/src/System/Net/NameResolutionPal.Unix.cs) y [discusión de musl](https://www.openwall.com/lists/musl/2026/04/27/1).
- El commit `bdb2dca` agrega opciones DNS `timeout:1` y `attempts:1` a los tres backends y reproduce las mismas opciones en CI. Se conserva el deadline de 2 s y la cancelación cooperativa de operaciones de aplicación; las opciones DNS complementan ese control para la resolución bloqueante.
- El [build Azure DevOps 91](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=91) para P3 terminó correctamente con los cinco stages, desde el commit `bdb2dca0e02a06e05378aba6741a3c01b14f917f`, tag `3.1.6-build.91`. Pasaron 49/49 pruebas unitarias y 13/13 de integración; incluyeron HTTP 503 a través de Nginx al detener PostgreSQL.
- El stage PostgreSQL tomó 10 s, avanzó el esquema de `20261025000200_002_AddPriorityNullable` a `20261025000400_004_RequirePriority`, registró `task_count=1` y verificó backup/restore. El backfill convirtió la prioridad NULL del marcador en 2; SQL/API confirmaron el valor y se conservaron id, título, estado, fecha y nodo de creación.
- La versión P2 respondió `/api/ready` como `UP` frente al esquema 004 en la ventana previa a CD, una segunda evidencia de compatibilidad entre versiones. El runtime de DNS se inspeccionó y mostró `timeout:1` y `attempts:1`.
- Preparación registrada a las 23:05:47 UTC y despliegue a las 23:07:13 UTC del 25/10/2026 (20:05 y 20:07 en Argentina).
- Un segundo probe aislado con Nginx real y la imagen P2 usando las nuevas opciones DNS respondió GET 503 en 1,717 s y POST 503 en 1,273 s y 1,110 s. No usó la base activa; sus contenedores/red se limpiaron al terminar. Son mediciones de este probe, no una garantía general.
- Los comandos de inspección de solo lectura listados abajo se ejecutaron correctamente contra EC2 en P2: historial `__EFMigrationsHistory`, descripción de `tasks` y `curl localhost/api/ready`. Confirmaron migración 002, columna `priority` nullable con default 2 y readiness UP; luego P3 aplicó `NOT NULL`/`CHECK` y backfill al marcador.
- `verify-deployment.sh --resilience` pasó: al detener PostgreSQL el gateway devolvió 503; el marcador persistió después de recrear PostgreSQL y un backend. También pasaron tráfico con un frontend y un backend detenidos, diez toggles atómicos y balanceo entre los tres backends.
- El backup P3 del build91 se descargó de Azure a Windows, se validó por SHA-256 y se copió a EC2. `restore-postgresql.sh` lo restauró en la base nueva `restore_offhost_91_20261025`; el fingerprint completo coincidió en 0,462 s medidos (una fila). Esa duración corresponde a esta prueba, no es un RTO general. La base restaurada se limpió después. También se copió fuera de EC2 el backup manual previo al rollback P3 y se validó su SHA-256.
- Se hizo rollback real de aplicación P3→P1 (`3.1.1-build.87`, `BUILD_ID=demo-rollback-p1-91`): el esquema 004 se conservó y el marcador mantuvo `priority=3`. Después se volvió a P3 (`3.1.6-build.91`) consumiendo el recibo 91, sin ejecutar otra migración. La verificación final de P3 pasó a las 23:13:21 UTC del 25/10/2026 (20:13 hora de Argentina).
- Se eliminó por API el marcador demo `c7bd9b93-d336-42b4-a6b1-ac36900741a1`; la consulta final mostró `remainingTasks=0`.
- En la inspección final quedaron 993 MiB de memoria disponibles y 13 GiB libres (5,7 GiB usados) en disco. Backends: 52,29–59,23 MiB RSS por réplica frente a 128 MiB; PostgreSQL: 51,59 MiB frente a 384 MiB; 12 conexiones de 30 máximas. OOM=false y cero reinicios en PostgreSQL y los tres backends. PostgreSQL no publica puerto del host. Son observaciones de esta ejecución en una VM, no capacidad ni disponibilidad garantizadas.

## Flujo implementado en el repositorio

El pipeline declara cinco stages: `Versioning`, `QualityGate`, `Packaging`, `PostgreSQL` y `CD`. Sus parámetros son `deployDemo` (default `false`) y `releasePhase` (`P1`, `P2` o `P3`, default `P3`). El mismo SHA produce backend, frontend y migrador; `TASK_RELEASE` y `VITE_TASK_RELEASE` seleccionan la fase.

Los objetivos exactos están en [`schema-compatibility.json`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/backend/schema-compatibility.json). El Quality Gate llama a [`test-postgresql.sh`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/scripts/test-postgresql.sh), que utiliza PostgreSQL descartable. PostgreSQL se prepara con [`prepare-postgresql.sh`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/scripts/prepare-postgresql.sh) y [`backup-postgresql.sh`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/scripts/backup-postgresql.sh); CD llama a [`deploy-ec2.sh`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/scripts/deploy-ec2.sh) y consume el recibo del mismo BuildId/SHA. La infraestructura persistente está separada en [`compose.data.yaml`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/bdb2dca0e02a06e05378aba6741a3c01b14f917f/compose.data.yaml). El default actual de `releasePhase` es P3 para evitar retroceder versiones; P1 se selecciona explícitamente en una primera instalación.

## Redis legado

P3 ya está desplegado y PostgreSQL es la persistencia activa del backend. La inspección anterior al corte encontró Redis sin tareas; su servicio/volumen se conserva como legado y no se usa como rollback automático. Una vez escritas tareas en PostgreSQL, volver a Redis exige una transferencia inversa consistente.

## Recuperación y próximos pasos

El rollback de aplicación conserva esquema PostgreSQL compatible. `Down` puede perder datos de una columna y no sustituye un backup. El restore se valida en una base separada antes del corte.

P1, P2 y P3 se desplegaron sucesivamente; P3 es la versión activa. P2 demostró compatibilidad P1/P2 y lectura de NULL como media, y P3 completó el backfill y las restricciones. Builds 89 y 90 muestran que QualityGate bloquea releases defectuosos. Build91 pasó los cinco stages. Las pruebas manuales de resiliencia, restore off-host y rollback P3→P1→P3 también pasaron; luego se eliminó el marcador y el tablero quedó sin tareas. El sistema sigue siendo una demo de una VM, sin alta disponibilidad; Podman en Windows/WSL no se validó. No extrapolar mediciones puntuales como SLO/RTO.

### Inspección de solo lectura en EC2

Por SSH, estos comandos consultan estado sin modificarlo:

```bash
docker exec lab-postgres psql -X -U postgres -d devops -c 'TABLE "__EFMigrationsHistory";'
docker exec lab-postgres psql -X -U postgres -d devops -c '\d tasks'
curl -i http://localhost/api/ready
```
