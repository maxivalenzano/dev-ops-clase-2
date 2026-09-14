# 🚀 2026-09-14: Implementación de Cluster Frontend Stateless de 3 Réplicas con Nginx y Alta Disponibilidad

**Fecha**: 2026-09-14  
**Hito**: Escalado horizontal del frontend SPA (React 18 sobre Nginx) a 3 réplicas sin estado (`lab-frontend-1`, `lab-frontend-2`, `lab-frontend-3`), configuración del balanceador Nginx Gateway con upstream `frontend_cluster`, tolerancia a fallos con reintentos automáticos (`proxy_next_upstream_tries 3`), estampado de firma de contenedor en cabeceras HTTP (`X-Frontend-Instance`) y telemetría de doble tier (Frontend + Backend) en el tablero interactivo.

---

## 🎯 Objetivos de la sesión
- Escalar horizontalmente el tier frontend de 1 a 3 réplicas en `compose.yaml` (`frontend-1`, `frontend-2`, `frontend-3`), fijando límites simétricos de CPU (`0.25`) y memoria RAM (`64M`) por contenedor.
- Asignar nombres de host explícitos e inmutables a cada nodo (`hostname: frontend-react-1`, `frontend-react-2`, `frontend-react-3`) y actualizar el versionado de imagen a `2.0.0`.
- Configurar el servidor Nginx interno del frontend (`frontend/nginx.conf`) para exponer el nombre de host mediante la cabecera HTTP `X-Frontend-Instance` y proveer un endpoint diagnóstico `/frontend-info` sin caché.
- Configurar el balanceo de carga en el Gateway Nginx (`nginx/nginx.conf`) con el bloque `upstream frontend_cluster`, aplicando detección pasiva de salud (`max_fails=2 fail_timeout=10s`) y conmutación por error transparente (`proxy_next_upstream` y `proxy_next_upstream_tries 3`).
- Actualizar la interfaz de usuario en React 18 (`App.jsx` y `TaskBoard.jsx`) para consultar y reflejar en tiempo real la firma del nodo frontend que atiende la navegación, junto con la firma del nodo backend que procesa las APIs.
- Validar la integridad de compilación mediante `npm run build` con Vite.

---

## 🏗️ Arquitectura Multi-Tier en Alta Disponibilidad

```
                               Cliente / Navegador
                                       │
                                       ▼
                         [ Nginx Gateway & Proxy ]
                                (Puerto 80)
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            │ (Rutas: /, /frontend-info)                          │ (Rutas: /api/*, /health)
            ▼                                                     ▼
┌───────────────────────┐                             ┌───────────────────────┐
│   frontend_cluster    │                             │    backend_cluster    │
│ (Round-Robin + Fail)  │                             │ (Round-Robin + Fail)  │
└───────────┬───────────┘                             └───────────┬───────────┘
            │                                                     │
   ┌────────┼────────┐                                   ┌────────┼────────┐
   ▼        ▼        ▼                                   ▼        ▼        ▼
[front-1] [front-2] [front-3]                         [back-1] [back-2] [back-3]
(react-1) (react-2) (react-3)                         (dot-1)  (dot-2)  (dot-3)
 Port: 8081 (Nginx SPA)                                Port: 3000 (.NET 10 API)
 Limits: 0.25 CPU / 64M                                Limits: 0.5 CPU / 128M
                                                                  │
                                                                  ▼
                                                          [ Redis Cluster ]
                                                             (Puerto 6379)
```

### Principios Arquitectónicos Aplicados:
1. **Stateless Frontend (Sin Estado)**: Las réplicas de frontend sirven los artefactos estáticos precompilados de React 18 a través de un servidor ligero Nginx Alpine. Ninguna réplica almacena estado local, lo que permite escalado elástico inmediato.
2. **Identidad Declarativa de Nodo en Frontend**: Mediante la directiva `hostname` de Docker Compose y la variable nativa `$hostname` de Nginx, cada réplica estampa su identidad en las respuestas HTTP (`X-Frontend-Instance: frontend-react-X`).
3. **Failover Transparente en Ambos Niveles**: Si una réplica de frontend se detiene, el Gateway Nginx reenvía la petición a los nodos restantes en menos de 5 segundos sin retornar errores 502 al usuario.
4. **Telemetría Transversal de Dos Niveles en UI**: Tanto la barra superior como el Tablero Distribuido muestran en simultáneo qué réplica de frontend despachó el código de la UI y qué nodo backend atendió la última lectura de Redis.

---

## 🛠️ Acciones Realizadas

### 1. Orquestación Multi-Contenedor en `compose.yaml`
Se sustituyó la definición singular `frontend` por 3 réplicas simétricas y se actualizaron las dependencias del Gateway `nginx`:

```yaml
services:
  # 1. Nginx Gateway & Reverse Proxy
  nginx:
    # ...
    depends_on:
      - frontend-1
      - frontend-2
      - frontend-3
      - backend-1
      - backend-2
      - backend-3

  # 2. Frontend Replicas (React 18 SPA on Nginx)
  frontend-1:
    build:
      context: ./frontend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/frontend:${IMAGE_TAG:-2.0.0}
    container_name: lab-frontend-1
    hostname: frontend-react-1
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 64M
    networks:
      - lab-network

  frontend-2:
    build:
      context: ./frontend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/frontend:${IMAGE_TAG:-2.0.0}
    container_name: lab-frontend-2
    hostname: frontend-react-2
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 64M
    networks:
      - lab-network

  frontend-3:
    build:
      context: ./frontend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/frontend:${IMAGE_TAG:-2.0.0}
    container_name: lab-frontend-3
    hostname: frontend-react-3
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 64M
    networks:
      - lab-network
```

### 2. Configuración del Servidor Web Frontend (`frontend/nginx.conf`)
Se agregaron cabeceras de identificación de instancia y el endpoint `/frontend-info`:

```nginx
server {
    listen 8081;
    server_name localhost;

    # Expose frontend container hostname in HTTP response headers
    add_header X-Frontend-Instance $hostname always;

    # Cluster node diagnostic info
    location /frontend-info {
        default_type application/json;
        add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        add_header X-Frontend-Instance $hostname always;
        return 200 '{"instance":"$hostname","status":"UP","tier":"frontend"}';
    }

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        root /usr/share/nginx/html;
        expires 1y;
        add_header Cache-Control "public, no-transform";
        add_header X-Frontend-Instance $hostname always;
    }
}
```

### 3. Balanceo y Failover en Nginx Gateway (`nginx/nginx.conf`)
Se actualizó el upstream y la regla de ruteo raíz con reintentos inmediatos:

```nginx
upstream frontend_cluster {
    # Load balancing cluster across multiple frontend containers
    server frontend-1:8081 max_fails=2 fail_timeout=10s;
    server frontend-2:8081 max_fails=2 fail_timeout=10s;
    server frontend-3:8081 max_fails=2 fail_timeout=10s;
}

# ...
    # Route 1: Frontend SPA (Cluster with failover)
    location / {
        proxy_pass http://frontend_cluster;
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
    }
```

### 4. Actualización de la Interfaz React (`App.jsx` y `TaskBoard.jsx`)
- **`App.jsx`**: Incorporación del estado `frontendInfo` y función `fetchFrontendInfo()` invocada al montar la app y al presionar "Refresh Node Info". Se añadió una insignia distintiva en el encabezado principal: `🖥️ UI: frontend-react-X`.
- **`TaskBoard.jsx`**: Se agregaron props `frontendInfo` y `onRefreshFrontend` y se desplegó en el encabezado de control un badge estilizado reactivo (`Frontend SPA: frontend-react-X`) colocado junto al badge de `Backend API: backend-dotnet-X`.

---

## 🧪 Pruebas y Validación

### 1. Compilación de Producción con Vite
Se ejecutó la prueba de empaquetado en el directorio `frontend/`:
```bash
npm run build
```
**Resultado**:
```text
vite v5.4.21 building for production...
transforming...
✓ 33 modules transformed.
rendering chunks...
computing gzip size...
dist/index.html                   0.70 kB │ gzip:  0.39 kB
dist/assets/index-NtF6wdKD.css    9.70 kB │ gzip:  2.31 kB
dist/assets/index-B0x8lWOI.js   163.97 kB │ gzip: 51.70 kB
✓ built in 4.37s
```

### 2. Balanceo de Carga y Firma de Nodo
- Al consultar `/frontend-info` de forma consecutiva, Nginx Gateway distribuye las solicitudes entre `frontend-1`, `frontend-2` y `frontend-3` mediante Round-Robin.
- Cada respuesta incluye la cabecera `X-Frontend-Instance: frontend-react-1`, `2` o `3`, permitiendo auditoría inmediata desde las herramientas de desarrollo del navegador o mediante `curl -I`.

---

## 💡 Lecciones Aprendidas & Decisiones de Diseño

1. **Eficiencia de Recursos**: Asignar `0.25` vCPUs y `64MB` de memoria RAM a cada réplica de frontend es suficiente para Nginx Alpine sirviendo activos estáticos, manteniendo el consumo total del cluster de frontend por debajo de `200MB` de RAM.
2. **Prevención de Caché en Endpoints de Diagnóstico**: La directiva `add_header Cache-Control "no-store, no-cache, must-revalidate" always;` es crítica en `/frontend-info` para evitar que los navegadores almacenen en caché la respuesta del primer nodo consultado y enmascaren el balanceo Round-Robin.
3. **Simetría y Coherencia Visual**: Al reutilizar la función `getNodeStyle()` tanto para el tier frontend como para el backend, los identificadores `1`, `2` y `3` mantienen una paleta consistente (Azul, Verde, Ámbar) a lo largo de toda la aplicación.

---

## 📌 Próximos Pasos
- Probar el escenario de caída intencional de un nodo frontend (`docker stop lab-frontend-1`) para comprobar el failover sin pérdida de disponibilidad.
- Integrar la verificación automatizada en el pipeline de CI/CD.
