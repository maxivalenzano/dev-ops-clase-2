# 🦭 Podman vs Docker

Conceptos fundamentales y diferencias operativas entre ambos motores de contenedores.

---

## Diferencias Clave de Arquitectura

| Característica | Docker | Podman |
| :--- | :--- | :--- |
| **Arquitectura** | Cliente - Servidor con Daemon central (`dockerd`) | **Daemonless** (ejecución directa vía fork/exec con `crun`/`runc`) |
| **Permisos** | Requiere root por defecto (o socket con privilegios) | **Rootless nativo** (ejecuta en user space usando user namespaces) |
| **Concepto de Pod** | No nativo (requiere Kubernetes/Compose) | **Nativo** (`podman pod create`) idéntico a Pods de Kubernetes |
| **Compatibilidad** | CLI estándar de la industria | Alias 100% compatible con Docker CLI (`alias docker=podman`) |
| **Definición de Imágenes** | `Dockerfile` | Soporta tanto `Dockerfile` como `Containerfile` |

---

## ¿Por qué Pods en Podman?

En Kubernetes, un **Pod** es la unidad mínima de cómputo y consiste en uno o más contenedores que comparten:
1. **Namespace de Red**: Todos los contenedores ven el mismo `localhost` y comparten interfaces/puertos.
2. **Namespace de IPC**: Comunicación entre procesos por memoria compartida.
3. **Volúmenes de Almacenamiento**: Montajes compartidos.

Podman permite crear Pods locales exactamente con el mismo modelo mental:

```bash
# 1. Crear un Pod mapeando solo el puerto 8080 del host
podman pod create --name lab-pod -p 8080:80

# 2. Agregar contenedores al Pod (se comunican entre sí por localhost)
podman run -d --pod lab-pod --name backend-1 ...
podman run -d --pod lab-pod --name backend-2 ...
podman run -d --pod lab-pod --name nginx ...
```

::: tip VENTAJA CLAVE
No hace falta crear redes virtuales puente (bridge) complejas ni DNS interno cuando dos procesos están estrechamente acoplados (sidecar pattern). Se comunican directamente mediante `localhost:<port>`.
:::
