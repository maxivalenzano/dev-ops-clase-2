# Plan de integración: PostgreSQL y EF Core

Fecha: 25/10/2026. Estado: implementación y validación completadas para P1/P2/P3. Las fases se desplegaron sucesivamente; P3 (`3.1.6-build.91`) está activa con esquema 004 y backfill verificado. Pasaron resiliencia, restore off-host y rollback P3→P1→P3. Los límites son los de una demo en una sola VM, sin alta disponibilidad; Podman en Windows/WSL no está validado. Evidencia detallada en la [bitácora PostgreSQL/EF](../bitacora/2026-10-25-postgresql-ef-migraciones.md).

## Objetivo y alcance

Incorporar PostgreSQL como fuente de verdad del tablero, EF Core 10 como acceso a datos y herramienta de migraciones, y un migrador independiente integrado con Azure Pipelines. Conservar React, Nginx, tres réplicas de backend/frontend, GHCR y el despliegue con Docker Compose.

La demostración debe enseñar creación del esquema, actualización con datos existentes, restricciones, compatibilidad entre versiones, fallas controladas y recuperación. No incluye alta disponibilidad de base de datos ni cambios de motor mayor de PostgreSQL.

Este documento conserva la arquitectura y los criterios de aceptación originales. La sección 1 registra la inspección inicial previa a PostgreSQL; es evidencia histórica, no el estado actual. Los resultados de cada release y de las pruebas finales están en la [bitácora](../bitacora/2026-10-25-postgresql-ef-migraciones.md).

## 1. Inspección inicial del servidor (estado histórico previo a PostgreSQL)

Inspección SSH de solo lectura realizada el 25/10/2026 a las 17:48 de Argentina (20:48 UTC). Se usó la clave indicada por el usuario, sin leer ni copiar su contenido, con `BatchMode=yes` y `StrictHostKeyChecking=yes`. El acceso terminó con código 0 y el host coincidió con la identidad registrada.

| Comprobación | Resultado |
| --- | --- |
| Destino | `ubuntu@18.216.227.211` |
| Sistema y arquitectura | Ubuntu 24.04.5 LTS, x86_64 |
| CPU | 2 CPU lógicas |
| RAM | 1.896 MiB totales; 1.171 MiB disponibles durante la inspección |
| Swap | Sin swap |
| Disco raíz | 19 GiB, 4,2 GiB usados, aproximadamente 15 GiB libres |
| Docker / Compose | 29.9.2 / v5.6.1 |
| Servicios | Nueve contenedores activos; Redis healthy |
| Backend, consumo observado | Aproximadamente 24,4 MiB por réplica; límite actual 128 MiB |
| Portainer, consumo observado | Aproximadamente 89,9 MiB |
| Aplicación | `/api/health` UP; `/api/tasks` sin tareas; Redis `HLEN tasks = 0` |
| Versión activa | `3.0.3-build.85` |
| Commit activo | `42d6a2516050d2cc9e6ec26798998e7a68fbcd48` |
| Operación | Docker y agente Azure Pipelines activos; `/opt/devops-lab` escribible; `flock` disponible |
| Puertos del host | 22 y 80 públicos; Portainer ligado a loopback; sin listener en 5432 |

Conclusión: hay margen observado para una prueba pequeña de PostgreSQL en esta VM. No demuestra capacidad bajo carga ni que PostgreSQL ya arranque o migre correctamente. La aceptación final exige ejecutar las pruebas de las fases siguientes. No se modificaron servicios, volúmenes, reglas de red ni paquetes durante esta inspección.

## 2. Decisiones de arquitectura

- PostgreSQL 17 como versión mayor estable elegida para el laboratorio; resolver y fijar parche/digest de la imagen al implementar. No utilizar `latest` ni actualizar de versión mayor durante esta actividad.
- EF Core 10 y `Npgsql.EntityFrameworkCore.PostgreSQL` 10.x; seleccionar versiones de parche compatibles y fijarlas, junto con `dotnet-ef` en manifiesto local.
- PostgreSQL en Compose, servicio `postgres`, nombre `lab-postgres`, red `lab-network`, volumen persistente `postgres-data`. Para PostgreSQL 17, montar en `/var/lib/postgresql/data`.
- Sin publicar 5432 en el host; administración por `docker exec` o mecanismo explícito posterior mediante túnel.
- PostgreSQL almacena todas las tareas. Redis se conserva inicialmente con su volumen, pero no recibe escrituras de tareas nuevas. La caché se pospone para evitar agregar invalidación al ejercicio.
- Migrador temporal, ejecutado una vez por despliegue, con el mismo commit y tag de la aplicación. No ejecutar migraciones al iniciar cada réplica.
- Credenciales separadas para aprovisionamiento, migrador con DDL y aplicación con DML. Definir privilegios predeterminados para que el usuario de aplicación acceda a los objetos futuros creados por el migrador.
- Secretos fuera de Git y de logs; archivo protegido de credenciales en EC2, separado del `.env` de versión que el despliegue reemplaza. Documentar lectura y permisos de los archivos montados para el usuario no root del backend.
- La persistencia y los backups no implican alta disponibilidad: PostgreSQL y aplicación comparten una sola VM.

### Presupuesto inicial para validar

| Parámetro | Propuesta inicial, ajustable tras medición |
| --- | --- |
| Límite de memoria PostgreSQL | 384 MiB |
| `shared_buffers` | 64 MB |
| `work_mem` | 2 MB; se consume por operación, no como límite global |
| `maintenance_work_mem` | 32 MB |
| `max_connections` | 30 |
| Pool por backend | Máximo 5 conexiones; 15 entre las tres réplicas |
| Migrador y administración | Presupuesto dentro de las conexiones restantes |
| Migrador temporal | Medir con límite inicial de 256 MiB |
| Backends EF | Mantener inicialmente 128 MiB solo si pasan las pruebas; medir y ajustar con el presupuesto total |

Estos valores son hipótesis para una demo pequeña, no requisitos oficiales ni capacidad garantizada. Verificar también memoria compartida del contenedor, consumo de WAL, conexiones y espacio para imágenes y backups. No ejecutar Chaos Lab de memoria/CPU simultáneamente con la migración. Compilar exclusivamente en CI.

## 3. Fases de implementación

### Fase A: preparar una base reproducible

1. Crear rama `codex/postgresql-ef-migrations` desde el estado integrado y validado del laboratorio; no incorporar cambios ajenos.
2. Registrar imagen/commit actual, configuración Compose y cantidad de tareas al iniciar la ejecución. La observación actual de cero tareas no autoriza borrar datos que aparezcan después.
3. Definir secretos y crear PostgreSQL con volumen y healthcheck `pg_isready` sobre la base prevista. El healthcheck del motor no sustituye una consulta autenticada de la aplicación.
4. Aprovisionar base, roles y privilegios con un proceso explícito. Los scripts de inicialización de la imagen solo actúan sobre un directorio de datos vacío: no usarlos como gestor de migraciones sucesivas.
5. Validar SQL autenticado, versión, recursos efectivos y persistencia tras recrear el contenedor.

Criterio: PostgreSQL healthy, consulta autenticada correcta, datos persistentes y RAM/disco sin presión sostenida. No cambiar todavía el almacenamiento servido por los backends.

### Fase B: persistencia EF Core y primera versión PostgreSQL

1. Agregar `AppDbContext`, configuración de entidades y `PostgresTaskService` manteniendo `ITaskService` y el contrato HTTP inicial.
2. Registrar contexto y servicio con alcance por solicitud. No reutilizar el singleton actual con un `DbContext` compartido entre solicitudes.
3. Crear tabla `tasks` con `id` UUID, `title` texto, `is_completed` boolean, `created_by_node` texto y `created_at` timestamptz. Conservar nombres JSON de la API y fechas UTC. Validar UUID existentes antes de cualquier importación.
4. Crear `001_InitialTasks` mediante EF y revisar el SQL generado. No usar `EnsureCreated` para una base gestionada por migraciones.
5. Mantener operaciones CRUD. Para toggle, implementar una actualización atómica o control de concurrencia para evitar el patrón lectura-modificación-escritura con actualizaciones perdidas entre réplicas.
6. Ante caída de PostgreSQL, devolver indisponibilidad; eliminar fallback silencioso a diccionarios locales en el modo PostgreSQL.
7. Conservar liveness y agregar `/api/ready`: comprobar conexión, tabla esperada y rango de esquema compatible. Una versión anterior compatible puede aceptar migraciones aditivas más nuevas; no exigir igualdad exacta del último ID.

Criterio: misma API inicial, datos compartidos entre los tres backends, persistencia tras reinicios y errores visibles al caer la BD.

### Fase C: transición desde Redis

Si Redis sigue vacío, establecer la primera versión PostgreSQL sin importación. Si existen tareas, pausar temporalmente escrituras, exportar y respaldar Redis, importar preservando IDs y valores, validar conteos/contenido y recién entonces cambiar todas las réplicas a PostgreSQL. La importación debe poder repetirse sin duplicar IDs y debe reportar registros inválidos.

Durante el corte no mezclar réplicas que escriban en Redis con réplicas que escriban en PostgreSQL. Se acepta una ventana breve de mantenimiento para este laboratorio; no se promete transición sin interrupción.

Después del primer dato escrito en PostgreSQL, volver a una imagen Redis no es un rollback transparente. Mantener Redis y su volumen no sincroniza datos posteriores. El primer punto de recuperación normal será una versión estable del backend que ya use PostgreSQL.

Criterio: una sola fuente de verdad, ninguna escritura dividida entre motores y una versión PostgreSQL de referencia identificada.

### Fase D: ejercicio de evolución de esquema

Separar releases reales para que se pueda demostrar la convivencia:

| Release | Esquema y aplicación | Demostración |
| --- | --- | --- |
| P1 | Tabla inicial sin prioridad; backend PostgreSQL estable | CRUD y punto base de rollback |
| P2 | `002_AddPriorityNullable`; agregar `priority` nullable con DEFAULT 2; backend que lee NULL como media y escribe valores 1–3 | Cambio aditivo; P1 omite la columna y recibe el default |
| P3 | `003_BackfillPriority`: completar NULL; `004_RequirePriority`: NOT NULL y CHECK 1–3; conservar DEFAULT 2 | Transformación de datos y reglas de integridad |

Para visualizar el backfill, introducir en una base de prueba una tarea heredada con prioridad NULL antes de P3. Un default solo actúa cuando se omite el campo: no reemplaza un NULL explícito. Revisar si EF optimiza o combina operaciones de una forma que cambie lo que se pretende enseñar.

Agregar un selector simple Baja/Media/Alta al tablero en P2. Mantener rutas y firma del nodo. Probar que P1 funciona contra los esquemas P2/P3: el default permite sus inserciones, pero la compatibilidad completa se verifica ejecutando su imagen.

El caso fallido se ensaya únicamente en una BD descartable: intentar NOT NULL antes del backfill y observar el fallo. No incorporar esa migración fallida al historial definitivo ni modificar migraciones ya aplicadas en entornos compartidos; cualquier corrección posterior se expresa en otra migración.

### Fase E: CI y artefactos

Ampliar `azure-pipelines.yml` a cinco stages. Por decisión del usuario, PostgreSQL tendrá un stage independiente para hacer visible el ciclo de base de datos durante la demostración:

| Stage | Trabajo nuevo |
| --- | --- |
| Versioning | Identificar versión, SHA y migración objetivo |
| Quality Gate | PostgreSQL temporal del mismo major; migración desde cero y desde esquema anterior con datos; CRUD, restricciones y compatibilidad; publicar resultados |
| Packaging | Imágenes frontend/backend/migrador del mismo SHA; bundle EF, SQL de avance y SQL inverso para revisión, manifiesto de compatibilidad |
| PostgreSQL | Preflight, preparar/verificar motor, backup, ejecutar migrador EF y validar esquema; publicar evidencia |
| CD | Comprobar resultado de PostgreSQL, desplegar aplicación, verificar y registrar manifest final |

Flujo previsto: `Versioning → QualityGate → Packaging → PostgreSQL → CD`.

### Stage 4: PostgreSQL

Nombre YAML previsto: `PostgreSQL`. Nombre visible: `4. PostgreSQL: preparación y migraciones EF`.

- Depender de `Versioning` y `Packaging` para obtener versión y artefactos de la misma ejecución. Mantener los enlaces necesarios a Versioning para resolver outputs entre stages.
- Usar un deployment job sobre el recurso VM `ec2-devops` del Environment existente. La ejecución ocurre en EC2, no en el agente hospedado de CI.
- Aplicar las mismas condiciones de rama, tag y parámetro manual `deployDemo` que habilitan el CD actual; excluir Pull Requests. Las pruebas de PR usan exclusivamente PostgreSQL descartable de CI.
- Mostrar pasos separados: validar recursos y compatibilidad; descargar imágenes del release completo; preparar/verificar PostgreSQL; crear backup; ejecutar migrador; validar esquema y datos; publicar resumen.
- Usar la imagen oficial PostgreSQL desde Docker Hub, con versión/digest fijado. El stage no construye ni publica una imagen del motor. Packaging sí publica `dev-ops-migrator` en GHCR, junto al backend/frontend.
- Un éxito requiere consulta autenticada, migración objetivo aplicada, ninguna migración pendiente del release y comprobaciones de integridad correctas. `pg_isready` por sí solo no alcanza.
- Guardar recibo protegido por ejecución en EC2 y publicar resumen sin secretos: BuildId, SHA, tag/digest migrador, esquema anterior y final, referencia del backup, duración y resultado. No publicar dumps de datos como logs.
- Si no hay migraciones pendientes, mostrar explícitamente ese resultado y comprobar el esquema. No recrear volumen ni motor innecesariamente.
- Si falla, el stage queda fallido y CD no se ejecuta. No configurar `continueOnError` ni permitir que un stage omitido habilite el despliegue.

### Stage 5: CD y coordinación entre stages

Nombre visible: `5. CD: Despliegue en EC2`. Agregar dependencia explícita de `PostgreSQL` y conservar dependencias necesarias para consumir versión. Exigir éxito del stage PostgreSQL además de las condiciones de despliegue actuales.

Antes de desplegar, verificar que el recibo corresponde al BuildId/SHA y esquema esperado del release. El CD consume ese resultado, sin ejecutar otra vez la preparación ni las migraciones. Ante fallo posterior, aplicar solamente rollback de aplicación compatible.

La separación introduce una ventana entre migración y despliegue: la aplicación anterior debe funcionar con el esquema nuevo durante esa ventana, incluso si CD nunca llega a ejecutarse. Para el primer cambio Redis → PostgreSQL se conserva el corte coordinado descrito en Fase C.

Serializar el par PostgreSQL + CD entre ejecuciones. Los bloqueos independientes de cada deployment job o un `flock` que se libera al finalizar el stage no protegen toda la entrega. Para el laboratorio, definir un único pipeline escritor y una reserva de release persistente entre stages con BuildId/SHA, adquirida y validada bajo `flock`: otro build no modifica base ni aplicación mientras exista una reserva ajena. Liberarla al finalizar CD y en limpieza de fallos; ante cancelación, registrar reserva pendiente y comprobar estado antes de liberarla manualmente. Validar con dos builds concurrentes que no haya intercalado. El bloqueo de migraciones de EF no sustituye esta coordinación de aplicación y esquema.

Construir bundle para el runtime real: si se ejecuta en Alpine x86_64, usar `linux-musl-x64`; `linux-x64` corresponde a una imagen compatible con glibc. Probar el bundle dentro de su imagen final en CI, no solo compilarlo. Conservar configuración necesaria y no incluir conexiones secretas en artefactos.

El job de integración puede usar un contenedor de servicio y scripts del pipeline; no requiere necesariamente introducir otra biblioteca de pruebas. Usar PostgreSQL real, no EF InMemory o SQLite para validar estas migraciones. El entorno Podman local tiene una falla WSL documentada: CI/Linux permite avanzar sin considerar ese problema resuelto.

### Fase F: ejecución y recuperación en PostgreSQL + CD

Separar responsabilidades en `scripts/prepare-postgresql.sh` (stage PostgreSQL) y `scripts/deploy-ec2.sh` (stage CD), manteniendo este orden global y la coordinación entre stages:

1. Adquirir el bloqueo `flock` existente y descargar todas las imágenes antes de cambiar el release activo.
2. Validar secretos, recursos, compatibilidad de versión origen/destino y configuración de PostgreSQL. Distinguir primera instalación de actualización.
3. Iniciar o verificar solo PostgreSQL y esperar conexión autenticada. Evitar recrear innecesariamente la BD en cada release de aplicación.
4. Crear backup lógico en formato custom y registrar nombre, esquema de origen y resultado. Para instalación nueva, indicar explícitamente que no existe estado previo.
5. Ejecutar migrador temporal con credencial DDL, timeout y código de salida comprobado. Configurar `lock_timeout` y `statement_timeout` adecuados para no esperar indefinidamente.
6. Si falla, conservar la aplicación previa; inspeccionar historial/esquema para detectar migraciones anteriores ya confirmadas. No asumir que varias migraciones forman una única transacción.
7. Si funciona, desplegar backends/frontend, refrescar Nginx y verificar readiness individual de las tres réplicas, CRUD, SQL e integridad de datos anteriores.
8. Registrar versión, SHA, migrador, esquema aplicado, backup y verificación en `deployment.json`, sin secretos.

Modificar el rollback actual: restaurar el Compose anterior con `--remove-orphans` podría detener PostgreSQL si ese Compose aún no lo declara. Mantener infraestructura persistente separada del rollback de aplicación (por ejemplo, un Compose específico de datos y despliegue explícito de servicios de aplicación), con nombres/red/volúmenes estables. Conservar volúmenes no alcanza si la BD queda detenida.

El `.env` actual se reemplaza y copia al historial: separar credenciales de la configuración de release. Restaurar una configuración antigua no debe borrar secretos ni cambiar accidentalmente el destino de la BD.

En un fallo de verificación posterior a la migración, restaurar automáticamente solo una imagen PostgreSQL declarada compatible con el esquema resultante. Si no existe compatibilidad, dejar el despliegue como fallido, bloquear escrituras si corresponde y aplicar el procedimiento de recuperación. No ejecutar `Down` destructivo automáticamente.

## 4. Política de rollback y backups

| Situación | Respuesta |
| --- | --- |
| Aplicación nueva defectuosa, esquema aditivo compatible | Volver a la imagen PostgreSQL anterior; conservar el esquema |
| Fallo de migración | No desplegar nueva aplicación; consultar historial y estado; corregir hacia adelante o reintentar tras resolver la causa |
| Necesidad de quitar prioridad | Usar bundle de la versión que contiene el `Down` o script inverso revisado; coordinar aplicación; exportar prioridades si se necesitan |
| Pérdida/corrupción de datos | Restaurar backup en BD separada, validar y hacer un corte controlado |
| Retorno a backend Redis | Requiere plan de transferencia inversa y consistencia; fuera del rollback automático |

`Down` no recupera valores eliminados. Quitar `priority` y volver a agregarla no reconstruye las prioridades anteriores. Para la clase, demostrarlo con datos descartables.

Usar `pg_dump`/`pg_restore` de una versión compatible con el servidor. Respaldar también el aprovisionamiento de roles/configuración, que un dump de una sola base no cubre completamente. Mantener backups con permisos restringidos y una copia fuera del disco de la VM antes de depender de ellos para recuperación real; el mecanismo y destino se definen al implementar.

Para una recuperación reproducible de la demo, pausar escrituras durante el punto de recuperación y el corte. Un dump consistente no contiene escrituras posteriores: declarar esa ventana de pérdida potencial. Cronometrar restauración; no prometer RPO/RTO hasta medir.

## 5. Verificaciones y casos límite

| Prueba | Criterio de aceptación |
| --- | --- |
| Base vacía → última versión | Esquema e historial completos, aplicación lista |
| P1 con tareas → P3 | Mismos IDs, títulos, estado, fechas y nodo; prioridad válida |
| Segunda ejecución del migrador | Sin migraciones pendientes ni datos duplicados |
| Prioridad NULL / 0 / 9 en esquema final | Rechazo por restricciones; API responde validación para entradas inválidas |
| Fallo NOT NULL antes del backfill | Pipeline falla sin desplegar app nueva; estado comprobado |
| Tres réplicas | Tarea escrita en una, visible en todas; toggle concurrente sin actualización perdida |
| App P1 sobre esquema P3 | Lectura, creación, toggle y borrado correctos |
| Caída y retorno de PostgreSQL | Readiness falla y escritura devuelve indisponibilidad; recuperación de conexiones sin datos locales divergentes |
| Reinicio y recreación de PostgreSQL | Tarea marcador persiste por volumen |
| Dos despliegues simultáneos | El segundo no entra a la sección crítica |
| Bloqueo prolongado durante DDL | Timeout controlado y error visible |
| Rollback de imagen después de migrar | Imagen PostgreSQL compatible funciona y PostgreSQL sigue activo |
| Backup y restore separado | Historial, conteos y contenido coinciden con el punto respaldado |
| Recursos | Sin OOM ni reinicios inesperados; conexiones dentro del presupuesto; margen de RAM/disco registrado |

Actualizar `scripts/verify-deployment.py`: actualmente exige nueve servicios y consulta el hash de Redis. Debe verificar los servicios duraderos esperados (diez si se conserva Redis), sin exigir que el migrador temporal siga activo, y comprobar persistencia en PostgreSQL. Separar pruebas destructivas de resiliencia del smoke test normal. Limpiar solo datos creados por cada prueba.

La disponibilidad de tres backends no proporciona HA de BD. Readiness informa el estado; revisar además cómo Nginx reacciona a errores, ya que agregar un endpoint no configura por sí solo su balanceo.

## 6. Archivos previstos

| Archivo o grupo | Cambio |
| --- | --- |
| `backend/Backend.csproj`, manifiesto dotnet tools | Dependencias EF/Npgsql/herramientas fijadas |
| `backend/Data/AppDbContext.cs`, configuración y factory de diseño | Modelo relacional y generación de migraciones |
| `backend/Migrations/` | Historial EF versionado y transformaciones revisadas |
| `backend/Services/PostgresTaskService.cs`, `backend/Program.cs` | Persistencia, DI scoped, errores y readiness |
| `backend/Models/`, `frontend/src/components/TaskBoard.jsx` | Prioridad en releases posteriores |
| Imagen/Containerfile del migrador | Bundle compatible con la imagen de ejecución |
| `compose.yaml` y posible Compose separado de datos | PostgreSQL, migrador temporal, red, volumen, recursos y secretos |
| `.env.example`, `.gitignore` | Solo nombres/valores de ejemplo; excluir credenciales y dumps |
| `azure-pipelines.yml` | Cinco stages; PostgreSQL independiente antes de CD, pruebas de integración y packaging del migrador |
| `scripts/prepare-postgresql.sh`, `scripts/deploy-ec2.sh`, scripts de backup/restore/verificación | Responsabilidades separadas, reserva entre stages y recuperación compatibles con BD |
| `tests/` | Pruebas significativas de persistencia/migraciones/compatibilidad |
| Documentación y bitácora | Guion, comandos comprobados, evidencia y límites |

## 7. Guion de exposición y cierre

1. Mostrar P1: tres backends comparten tareas en PostgreSQL y el historial contiene la migración inicial.
2. Mostrar SQL/PR y los cinco stages del pipeline P2: abrir PostgreSQL para observar backup, migración y validación; después CD despliega la app. Aparece prioridad sin perder tareas; una imagen P1 sigue operando.
3. Mostrar una tarea NULL y el intento fallido de NOT NULL en una BD descartable.
4. Aplicar backfill y restricciones P3; intentar prioridad 9 y comprobar el rechazo.
5. Ejecutar nuevamente el migrador y verificar que no repite cambios.
6. Volver a la imagen P1 conservando el esquema; explicar por qué funciona.
7. En un entorno descartable, mostrar el límite de `Down` y restaurar un backup separado.
8. Cerrar con evidencia de persistencia, recuperación y consumo de recursos.

Terminado cuando el CI y CD pasan, la demo completa es reproducible, se verificó restauración y se registraron mediciones reales con PostgreSQL. El acceso SSH y la memoria libre comprobados hoy son condiciones iniciales, no sustituyen esas validaciones.

## Referencias verificadas

- [Npgsql: proveedor EF Core 10](https://www.npgsql.org/efcore/release-notes/10.0.html).
- [Microsoft: aplicación de migraciones, bundles, scripts y permisos](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying).
- [PostgreSQL 17: configuración de memoria](https://www.postgresql.org/docs/17/runtime-config-resource.html).
- [PostgreSQL 17: backup lógico y restauración](https://www.postgresql.org/docs/17/backup-dump.html).
