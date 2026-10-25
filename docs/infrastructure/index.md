# Infraestructura y red

La topología actual está declarada en [`compose.yaml`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/main/compose.yaml) y usa una red bridge llamada `lab-network`.

| Servicio | Réplicas | Puerto del contenedor | Función |
|---|---:|---:|---|
| Nginx gateway | 1 | 80 | Entrada HTTP; enruta `/` y `/api/` |
| Frontend React servido por Nginx | 3 | 8081 | Aplicación SPA |
| API Minimal de .NET 10 | 3 | 3000 | Tareas, salud e interacción con Redis |
| Redis 7 | 1 | 6379 | Estado compartido de tareas, volumen `redis-data` |
| Portainer CE | 1 | 9000 y 9443 | Panel de administración |

Nginx distribuye solicitudes entre las réplicas y tiene timeouts de 5 segundos. Las directivas `proxy_next_upstream` reintentan ciertos errores; esto ayuda a observar fallos de contenedores, pero no garantiza cero interrupciones ni alta disponibilidad del host.

## Ejecución

- **Local:** Podman Compose: `podman compose up --build -d`. Para consultar y detener: `podman compose ps` y `podman compose down`.
- **Nube:** Docker Compose en Ubuntu EC2. Docker Engine 29.9.2, Compose 5.6.1 y Buildx están instalados; el servicio está habilitado y activo. `hello-world` pasó y el usuario `ubuntu` ejecuta Docker sin `sudo`.

El pipeline de cuatro etapas publica y despliega mediante GHCR y EC2. Los scripts `run-pod.ps1` y `run-pod.sh` son anteriores a la composición actual y no se usan en estos pasos.

## Migración a EC2 (CI/CD validado)

El directorio `/opt/devops-lab` ya está preparado y Compose con sus scripts terminó de copiarse. `scripts/setup-ec2.sh` prepara el host; `scripts/deploy-ec2.sh` despliega las imágenes y `scripts/verify-deployment.sh` verifica el resultado. La configuración usa `BACKEND_IMAGE` y `FRONTEND_IMAGE` para las referencias de GHCR, junto con `IMAGE_TAG` para seleccionar la versión.

Redis conserva su volumen, usa AOF y healthcheck, y no publica el puerto 6379 en el host. Portainer escucha solo en `127.0.0.1:9000` y `127.0.0.1:9443`. Para abrir su interfaz HTTPS, crear el túnel `ssh -L 9443:127.0.0.1:9443` y visitar `https://localhost:9443`.

La aplicación está desplegada como `3.0.0-build.81` en [http://18.216.227.211](http://18.216.227.211); los nueve contenedores están running. El agente `ec2-devops` está activo en `devops-ec2-env`. Los cuatro stages de CI/CD 81 finalizaron correctamente; se publicaron Release `v3.0.0` y Deployment `ec2-demo`. Las imágenes backend y frontend usan el mismo SHA de commit `3bbd09d848338f63efe6900c05a7004fde4281be`.

La validación pasó: HTTP 200 local y público, persistencia Redis tras reiniciar Redis, recrear un backend, rollback manual a `3.0.0`, nueva entrega y reinicio real de Ubuntu. Una tarea marcador sobrevivió rollback, entrega y reinicio; luego se eliminó y el tablero volvió a estar vacío (`totalCount=0`). También pasaron failover frontend/backend, 30 solicitudes entre tres backends y 12 respuestas `frontend-info` de tres frontends. Portainer CE 2.45.3 quedó inicializado; su API autenticada verifica nueve contenedores.

CI/CD 81, las 42 pruebas backend y los builds frontend y documentación pasaron. La demo oficial usa HTTP por IP; dominio y HTTPS de aplicación son opcionales y no se han ejecutado. Podman en WSL no está validado; el historial está en la [bitácora](/bitacora/).

La publicación de GitHub Release/Deployment mediante `scripts/publish-github-release.py` se completó: Release `v3.0.0` y Deployment `ec2-demo` se publicaron correctamente.

Para Portainer HTTPS desde Windows, mantener esta conexión SSH abierta y luego navegar a `https://localhost:9443`:

```powershell
ssh -i "C:\Users\m.valenzano\Downloads\vm-dev-ops-aws.pem" -L 9443:127.0.0.1:9443 ubuntu@18.216.227.211
```

Luego abrir `https://localhost:9443`. El helper de acceso a Portainer está guardado localmente fuera del repositorio; no se enlaza desde la documentación publicada ni se muestran credenciales aquí.
