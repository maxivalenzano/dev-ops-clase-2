# 🏛️ Arquitectura y Flujo del Laboratorio

Este laboratorio está diseñado para experimentar con conceptos fundamentales de **sistemas distribuidos**, **redes de contenedores**, **balanceo de carga** y **estrategias de resiliencia**.

---

## Diagrama de Arquitectura

```
                          Host Browser
                     (http://localhost:8080)
                                |
                                v
               +----------------------------------+
               |        Nginx Reverse Proxy       |
               |        (Port 80 -> 8080)         |
               +----------------------------------+
                     /                      \
            / (Static SPA)             /api (API Cluster)
                   v                          v
     +--------------------------+  +--------------------------+
     |     React 18 Frontend    |  | Backend Replicas (.NET 8)|
     |  (Vite + Nginx Static)   |  |  - backend-1 (Port 3001) |
     |  Port 80 (or 8081 in Pod)|  |  - backend-2 (Port 3002) |
     +--------------------------+  +--------------------------+
```

---

## Componentes del Ecosistema

### 1. Nginx Gateway (`/nginx`)
- **Punto de entrada único**: Expuesto en el puerto host `8080`.
- **Ruteo de tráfico**:
  - `/` y assets estáticos $\rightarrow$ Redirigidos al contenedor del Frontend.
  - `/api/` y `/health` $\rightarrow$ Redirigidos al pool de réplicas de backend.
- **Resiliencia**:
  - `proxy_read_timeout 5s;` para forzar timeouts controlados.
  - `proxy_next_upstream` para failover automático si una réplica falla.

### 2. Microservicio Backend (`/backend`)
- Servidor REST en .NET 8 LTS Minimal API.
- Expone endpoints informativos y de caos controlado:
  - Consumo de CPU intensivo.
  - Asignación de memoria para forzar **OOM (Out Of Memory)**.
  - Toggling dinámico de estado de salud (`isHealthy`).
  - Respuestas demoradas (`delay`) para pruebas de timeout.

### 3. Frontend React (`/frontend`)
- Interfaz gráfica construida con React 18 y Vite.
- Servida estáticamente mediante un contenedor Nginx optimizado.
- Permite monitorizar métricas, enviar ráfagas de tráfico y disparar eventos de estrés.

---

## Modos de Ejecución

El laboratorio soporta dos topologías de despliegue:

| Modo | Red / Networking | Comando de Inicio |
| :--- | :--- | :--- |
| **Podman Compose** | Red Bridge (`lab-network`) entre contenedores aislados | `podman compose up --build -d` |
| **Podman Pod** | Namespace de red compartido (**localhost networking**) | `.\scripts\run-pod.ps1` (Win) / `./scripts/run-pod.sh` (Linux) |
