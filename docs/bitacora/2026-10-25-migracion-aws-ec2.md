# ☁️ Migración del laboratorio DevOps a AWS EC2 y GHCR

**Fecha:** 2026-10-25  
**Estado:** Migración de nube implementada y validada; Podman local no se validó, DNS/HTTPS personalizados opcionales no se configuraron  
**Objetivo:** Preparar la transición desde Azure VM/ACR a AWS EC2/GHCR con Azure DevOps para CI/CD, para la demostración de clase.

---

## 🎯 Alcance

- Reutilizar la EC2 existente (`18.216.227.211`, región `us-east-2`) como destino de despliegue.
- Mantener Azure Pipelines, las etapas de versionado, Quality Gate, Packaging y CD, y las validaciones actuales.
- Publicar las imágenes `dev-ops-backend` y `dev-ops-frontend` en GHCR; construir en CI y ejecutar en EC2 con Docker Compose, sin compilar allí.
- Mantener .NET 10, React 18, Nginx, Redis 7, Portainer y las tres réplicas de frontend y backend. Conservar Podman Compose para el flujo local.
- Registrar cambios y resultados comprobables. Esta bitácora no considera completada ninguna fase hasta contar con evidencia de ejecución.

El plan de referencia es `PLAN_MIGRACION_AWS_GHCR.md`, un documento local de planificación. El detalle operativo y los criterios de recuperación están allí.

## 🧭 Plan de trabajo

1. Confirmar accesos a GitHub, Azure DevOps y AWS, estado de agentes y tratamiento de los datos existentes en Redis.
2. Preparar EC2: instalar y verificar Docker/Compose, preparar `/opt/devops-lab` y decidir si Portainer requerirá acceso externo.
3. Configurar permisos y secretos de GHCR para publicar y, si los paquetes fueran privados, descargar imágenes.
4. Adaptar Compose y Packaging para GHCR, tags únicos y `linux/amd64`, preservando CI y el flujo local.
5. Registrar EC2 como recurso Linux `ec2-devops` en el Environment `devops-ec2-env` de Azure DevOps.
6. Adaptar CD para desplegar desde una ruta estable, descargar imágenes antes de reemplazar contenedores y validar la salud del stack.
7. Validar servicios, endpoints, distribución y persistencia Redis, recuperación y segunda entrega. Luego actualizar DNS/documentación según el resultado comprobado.

## 📍 Estado inicial y evidencia disponible

Según la inspección de solo lectura documentada en el plan, realizada el 25/10/2026 aproximadamente a las 16:14 de Argentina (19:14 UTC):

- EC2 `i-0a604bd1419b1771a` estaba en estado `running`, con comprobaciones de instancia, sistema y EBS correctas. SSH como `ubuntu` fue comprobado.
- Ubuntu 24.04.5 LTS, arquitectura `x86_64`, 2 CPU lógicas, aproximadamente 1.9 GiB de RAM y volumen raíz EBS `gp3` de 20 GiB. No se observó swap.
- Docker Engine, Compose y Buildx no estaban instalados. Tampoco existía `/opt/devops-lab`; no se encontró un agente Azure Pipelines en las ubicaciones revisadas.
- No había servicio HTTP escuchando en el puerto 80. El Security Group permitía TCP 22, 80 y 443 desde `0.0.0.0/0`; no permitía 9000/9443. UFW figuraba inactivo.
- Se observó salida HTTPS a GHCR, Docker Hub, MCR, Azure DevOps y GitHub. Las respuestas HTTP confirman conectividad básica, no autenticación, permisos, descarga de imágenes ni acceso al proyecto.
- La instancia no tenía Elastic IP asociada; la IPv4 pública puede cambiar al detener e iniciar EC2.

Estas observaciones son el estado inicial consignado en el plan, no evidencia de que se hayan preparado servicios o desplegado la aplicación.

### Actualización de ejecución — 25/10/2026

- Se reconfirmó por SSH el acceso a `18.216.227.211` y, mediante AWS Core, la instancia `i-0a604bd1419b1771a` en `us-east-2`, tipo `t8i.small`; sus comprobaciones de sistema, instancia y EBS estaban `OK`. Se revisó el Security Group (TCP 22, 80 y 443) sin modificar reglas.
- Se ejecutó `scripts/setup-ec2.sh` en EC2. Quedaron instalados Docker Engine 29.9.2, Compose v5.6.1 y Buildx; Docker quedó habilitado e iniciado. `ubuntu` puede ejecutar Docker sin `sudo`, `/opt/devops-lab` es escribible por ese usuario y `docker run --rm hello-world` terminó correctamente.
- Los cambios locales adaptan Compose a GHCR, Redis AOF con healthcheck y Portainer limitado a loopback; el pipeline contempla publicación obligatoria en GHCR y CD a EC2. Se añadieron scripts de preparación, despliegue y verificación. Esto acredita preparación de configuración, no que el pipeline se haya ejecutado ni que la aplicación esté desplegada.
- `dotnet test` en configuración Release finalizó con 42 pruebas aprobadas y 0 fallidas.
- En el chequeo inicial, el token local de `gh` no tenía `packages`; GHCR anónimo y el pull devolvieron 401/`unauthorized`. Este bloqueo se resolvió luego con credenciales protegidas, según la actualización de despliegue siguiente.
- En el chequeo inicial no se encontró sesión local de Azure DevOps; el Environment, agente y autorización se configuraron después, según la actualización siguiente.
- `podman machine start` local falló con `ERROR_LOGON_TYPE_NOT_GRANTED` relacionado con WSL. No se modificaron políticas de Windows y no se validó Compose local con Podman.
- Al momento de este primer chequeo, aún no había contenedores de aplicación en EC2 y la decisión sobre los datos Redis seguía pendiente. La decisión de iniciar vacío y el primer despliegue se registran más adelante.

### Verificaciones adicionales — 25/10/2026

- Compose y scripts de despliegue/verificación se copiaron a `/opt/devops-lab`. En EC2 pasaron `bash -n`, el parseo AST de Python y `docker compose config -q`; la configuración resolvió nueve servicios. Un parser YAML de Node también aceptó `compose.yaml` y `azure-pipelines.yml` (cuatro stages).
- `npm run build` del frontend terminó correctamente.
- Se ejecutó una prueba controlada con `IMAGE_TAG=access-check-20261025 bash deploy-ec2.sh`. El pull falló por `GHCR unauthorized`; se comprobó que el script no creó `.env` ni inició contenedores de la aplicación. Se descargaron y quedaron en caché `nginx:alpine`, `redis:7-alpine` y `portainer/portainer-ce:latest`; no se ejecutaron.
- Se preparó `/opt/azdo-agent` con el agente oficial de Microsoft versión 5.281.1; se verificó el SHA-256 del release (`c9579f76...`) y `bin/Agent.Listener --version` respondió. No existe configuración `.agent`, registro en Azure DevOps ni servicio instalado; el agente no está operativo como recurso de CD.
- Docker permanece habilitado y activo. Se observaron 3.7 GB usados y 15 GB libres en el disco raíz.
- Se añadió `scripts/publish-github-release.py` para publicación opcional de GitHub Releases/Deployments mediante el secreto separado `GITHUB_RELEASE_TOKEN`. No se ejecutó ni se comprobó el token.
- `npm run docs:build` terminó con código de salida 0; VitePress completó el bundle y renderizó todas las páginas en 25.30 s.
- Para Portainer se eligió acceso mediante túnel SSH, manteniendo los puertos 9000/9443 ligados a loopback. No hace falta abrirlos en el Security Group para este método; la API autenticada por loopback pasó también después del reboot.
- En ese momento, el usuario había confirmado Redis vacío para la demo y las credenciales DPAPI estaban en comprobación. La autenticación y el despliegue quedaron validados posteriormente, sin registrar ni reproducir valores secretos.

### Despliegue inicial y CI/CD — 25/10/2026

- La autenticación con credenciales protegidas funcionó para GHCR y Azure DevOps. Los paquetes `dev-ops-backend` y `dev-ops-frontend` son privados y tienen los tags `3.0.0` y `latest`. Se guardaron `GHCR_PUSH_TOKEN`, `GHCR_PULL_TOKEN` y `GITHUB_RELEASE_TOKEN` como variables secretas del pipeline; no se imprimen ni se reproducen sus valores.
- Se creó el Environment `devops-ec2-env` (ID 2), el recurso VM `ec2-devops` (ID 2) y se autorizó el pipeline 1. El agente oficial 5.281.1 quedó configurado en `/opt/azdo-agent`, instalado como servicio de `ubuntu`, habilitado y activo. El journal reportó `Listening for Jobs`.
- La ejecución de `scripts/deploy-ec2.sh` con `IMAGE_TAG=3.0.0` y commit `90ad2b5` terminó correctamente. Los nueve servicios estaban `running`; no se instaló el proyecto con compilación en EC2.
- Respondieron HTTP 200 tanto en EC2 como desde el acceso público por `18.216.227.211` para `/`, `/frontend-info`, `/api/info`, `/api/health` y `/api/tasks`. La aplicación arrancó con Redis vacío, conforme a la decisión del usuario.
- `scripts/verify-deployment.sh --resilience` pasó: una tarea quedó en Redis y fue leída desde los tres backends; persistió al reiniciar Redis y al recrear un backend; Nginx siguió sirviendo mientras se detenían `frontend-1` y `backend-1`; 30 solicitudes mostraron balanceo en los tres nodos y el estado de prueba se restauró/eliminó al finalizar. Los snapshots de memoria de backend se mantuvieron por debajo de 128 MiB y no se observó OOM.
- Build 81 fue una ejecución manual de `codex/aws-ec2-migration` con `deployDemo=true`. Los nuevos triggers automáticos de `main`/`devel` entrarán en vigor al integrar la rama en `devel`; los tags se ejecutan manualmente. El commit publicado es `3bbd09d848338f63efe6900c05a7004fde4281be`; no se tocó el worktree/staging original del usuario.
- Azure Pipelines build 81 terminó el 25/10/2026 a las 19:49:59 UTC con sus cuatro stages en PASS: Versioning, Quality Gate, Packaging y CD. El stage CI ejecutó 42 pruebas aprobadas.
- Detalle del build: [Azure Pipelines build 81](https://dev.azure.com/maxivalenzano/DevOps/_build/results?buildId=81).

### Resultado final del pipeline y verificación de operación — 25/10/2026

- El CD de build 81 desplegó `3.0.0-build.81` en EC2 con commit `3bbd09d848338f63efe6900c05a7004fde4281be`. `deployment.json` registró la versión y `verification: passed`; las imágenes frontend/backend comparten ese SHA en sus labels OCI `revision`.
- Los nueve servicios quedaron `running` y Redis `healthy`. El estado del nodo AWS se reportó `OK`; el Security Group no cambió. En la medición posterior se observaron 1,131 MiB disponibles y 4.2 GB usados/15 GB libres en raíz.
- Se creó GitHub Release [`v3.0.0`](https://github.com/maxivalenzano/dev-ops-clase-2/releases/tag/v3.0.0) y el Deployment `ec2-demo` (ID `7318274504`) terminó exitosamente.
- Portainer 2.45.3 quedó inicializado. La contraseña de administrador es aleatoria y se conserva fuera del repositorio con DPAPI; el token inicial de configuración solo se usó durante la inicialización y no se registró. Se verificó por API autenticada en loopback que el endpoint `ec2-devops` reporta nueve contenedores. El acceso elegido es mediante túnel SSH.
- En la actualización anterior se había iniciado la prueba de rollback y reboot; el resultado final consta a continuación.

### Cierre de validación de nube — 25/10/2026

- El rollback manual `3.0.0` → `3.0.0-build.81` y el retorno fueron aprobados con `scripts/deploy-ec2.sh`. La tarea marcador sobrevivió dos cambios de imagen y un reinicio real de Ubuntu (el `boot_id` cambió de `e60ea…` a `ad2c…`); después del arranque se leyó desde los tres backends.
- Tras validar, se eliminó la tarea marcador y `/api/tasks` quedó en `totalCount: 0`, manteniendo la demo vacía. `verify-deployment.sh` volvió a PASS: nueve servicios, Redis saludable, CRUD HTTP y 30 solicitudes balanceadas. Redis reportó `appendonly yes`.
- La versión validada vigente es `3.0.0-build.81`, commit `3bbd09d848338f63efe6900c05a7004fde4281be`; el manifest final registró `verification: passed` a las 19:52:57 UTC.
- Las configuraciones previas se conservan bajo `/opt/devops-lab/history/<fecha-pid>`; el historial `history20261025T195250-18515` corresponde al despliegue de `3.0.0`, no a `3.0.0-build.81`. Para restaurar la versión válida, autenticar GHCR y ejecutar `IMAGE_TAG=3.0.0-build.81 SOURCE_COMMIT=3bbd09d848338f63efe6900c05a7004fde4281be bash /opt/devops-lab/scripts/deploy-ec2.sh`. Para `3.0.0`, seleccionar explícitamente `IMAGE_TAG=3.0.0` y el commit correspondiente. En ambos casos conservar proyecto Compose y volúmenes; no usar `down -v` ni eliminar datos. Ambos cambios de imagen se probaron con el marcador persistente.
- Después del reinicio, Docker y el servicio del agente estaban activos; el journal volvió a mostrar `Listening for Jobs` a las 19:54:40 UTC. Portainer postboot pasó: API autenticada por loopback, endpoint `ec2-devops` reportó nueve contenedores y la configuración de administrador persistió en su volumen. Redis `HLEN tasks=0`; backend-1/2/3 reportaron `OOMKilled=false` y `RestartCount=0`..
- El estado público por IP continuó respondiendo HTTP 200 en `/`, `/frontend-info`, `/api/info` y `/api/health`. La migración de nube queda implementada y validada. La prueba de Podman Compose en Windows/WSL sigue sin realizarse y queda fuera de este cierre de nube; DNS de dominio y HTTPS personalizados son opcionales y no se configuraron para la demo HTTP por IP.

## ⛔ Dependencias y posibles bloqueos

- La migración de nube está validada: CI/CD, operación, persistencia durante cambios de imagen y reinicio de Ubuntu, y restauración por rollback pasaron.
- Redis comenzará vacío por decisión del usuario; no hay tareas del origen que restaurar. La persistencia de tareas nuevas pasó las pruebas de reinicio, cambios de imagen, rollback y reboot.
- La prueba inicial anónima/pull fallida quedó resuelta con las credenciales protegidas. Los paquetes siguen privados; los pulls autenticados funcionan para el despliegue manual registrado arriba.
- La prueba controlada que se detuvo con `unauthorized` fue anterior a la configuración de credenciales; después, Packaging/CD de build 81 pasaron.
- La configuración local de Podman Compose no quedó validada por el fallo de arranque de Podman Machine/WSL (`ERROR_LOGON_TYPE_NOT_GRANTED`).
- Podman Compose en local no se validó debido al error previo de WSL. Esto queda explícitamente fuera de la validación de nube.
- Portainer 2.45.3 y su configuración de administrador persistieron al reboot; la API autenticada por loopback confirmó nueve contenedores. El acceso administrativo usa túnel SSH/loopback; no se abrieron puertos del Security Group.
- La demo queda documentada en la IP HTTP actual. Dominio estable/Elastic IP, actualización DNS y HTTPS personalizados no se configuraron porque son opcionales para la demo.

## 🛠️ Registro de acciones

### 2026-10-25 — Inicio y preparación inicial

- Se documentó el alcance y se enlazó el plan existente.
- Se trasladó a esta entrada únicamente el estado inicial de solo lectura descrito en el plan.
- La preparación de EC2, los cambios locales de configuración y la prueba unitaria quedan detallados en la actualización de ejecución anterior.
- Al inicio de la bitácora todavía no se había publicado imágenes, registrado el agente, desplegado la aplicación ni realizado validación funcional.

## 📌 Próximos pasos

1. Completar la comprobación post-reinicio de Portainer si se requiere su UI en la demo.
2. Podman Compose local queda sin validar; se necesita un entorno Windows/WSL operativo para probarlo.
3. DNS de dominio, IP estática y HTTPS quedan como mejoras opcionales posteriores a la demo HTTP por IP. Los cambios de pipeline/documentación se propondrán en un PR de `codex/aws-ec2-migration` hacia `devel`; aún no se integraron.

## 📚 Referencias

- Plan de migración Azure VM/ACR → AWS EC2/GHCR: `PLAN_MIGRACION_AWS_GHCR.md` (archivo local, fuera de la documentación publicada).
- [Bitácora de infraestructura Azure y ACR](./2026-09-07-migracion-azure-vm-acr)
- [Bitácora de refactorización del pipeline CI/CD](./2026-09-14-refactor-pipeline-4-stages-devsecops)
