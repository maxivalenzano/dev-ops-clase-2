# 🚀 2026-09-14: Implementación Etapa 3 - Cluster de 3 Nodos Backend con Nginx y Alta Disponibilidad

**Fecha**: 2026-09-14  
**Hito**: Escalado horizontal del microservicio .NET 10 a 3 réplicas backend (`lab-backend-1`, `lab-backend-2`, `lab-backend-3`), configuración del balanceador Nginx con algoritmo Round-Robin, tolerancia a fallos con reintentos inmediatos (`proxy_next_upstream_tries 3`) y verificación del patrón *Node Signature Board* sobre la persistencia centralizada en Redis.

---

## 🎯 Objetivos de la sesión
- Escalar horizontalmente el backend de 1 a 3 réplicas en `compose.yaml`, asegurando límites simétricos de CPU (`0.5`) y memoria (`128M`) por contenedor.
- Asignar identidades inmutables a cada nodo mediante la variable de entorno `INSTANCE_NAME` (`backend-dotnet-1`, `backend-dotnet-2`, `backend-dotnet-3`).
- Configurar el bloque `upstream backend_cluster` en `nginx/nginx.conf` habilitando los 3 nodos con detección pasiva de salud (`max_fails=2 fail_timeout=10s`).
- Ajustar la resiliencia y el failover transparente mediante `proxy_next_upstream` y elevación de `proxy_next_upstream_tries` a 3 reintentos.
- Garantizar que todos los nodos compartan el estado centralizado en Redis (`lab-redis`) mediante la red puente `lab-network`.
- Documentar el comportamiento del sistema distribuido frente a escenarios de conmutación por error (*failover*) sin pérdida de transacciones.

---

## 🏗️ Arquitectura del Cluster Distribuido

```
                              Host / Cliente Web
                                      │
                                      ▼
                        [ Nginx Gateway & Proxy ]
                               (Puerto 80)
                                      │
           ┌──────────────────────────┼──────────────────────────┐
           │ (Round-Robin)            │ (Round-Robin)            │ (Round-Robin)
           ▼                          ▼                          ▼
     [ backend-1 ]              [ backend-2 ]              [ backend-3 ]
  (backend-dotnet-1)         (backend-dotnet-2)         (backend-dotnet-3)
      Port: 3000                 Port: 3000                 Port: 3000
    Limits: 0.5 CPU / 128M     Limits: 0.5 CPU / 128M     Limits: 0.5 CPU / 128M
           │                          │                          │
           └──────────────────────────┼──────────────────────────┘
                                      │ (Conexión Redis: 6379)
                                      ▼
                             [ In-Memory Store ]
                                (lab-redis:7)
                                      │
                                      ▼
                             [ redis-data Vol ]
```

### Principios Arquitectónicos Aplicados:
1. **Stateless Compute**: Las 3 instancias de backend no almacenan estado de sesión ni colecciones en memoria de proceso. Cada nodo es descartable y reemplazable sin impacto funcional.
2. **Identidad Declarativa de Nodo**: Cada contenedor recibe su firma única mediante `INSTANCE_NAME`. Al persistir una tarea en Redis, estampa `createdByNode: instanceName`. Al responder lecturas, adjunta en el payload `servedByNode: instanceName`.
3. **Persistencia Única y Compartida**: Redis actúa como la única fuente de verdad transaccional. Cualquier nodo puede leer, alternar o eliminar tareas creadas por sus pares.
4. **Resiliencia Activa en Gateway**: Nginx asume la responsabilidad de ruteo, distribución equitativa y conmutación por error en tiempo de ejecución.

---

## 🛠️ Acciones Realizadas

### 1. Orquestación Multi-Contenedor en `compose.yaml`
Se incorporaron las instancias `backend-2` y `backend-3` y se actualizaron las dependencias de arranque del Gateway:

* **Servicio Nginx (`lab-nginx`)**:
  Se actualizó la sección `depends_on` para esperar a que los 3 nodos de backend y el frontend estén inicializados antes de habilitar el tráfico:
  ```yaml
  depends_on:
    - frontend
    - backend-1
    - backend-2
    - backend-3
  ```

* **Instancias Backend Simétricas (`backend-1`, `backend-2`, `backend-3`)**:
  Cada réplica se configuró con aislamiento estricto de recursos y variables de entorno parametrizadas:
  ```yaml
  backend-2:
    build:
      context: ./backend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/backend:${IMAGE_TAG:-2.0.0}
    container_name: lab-backend-2
    restart: unless-stopped
    depends_on:
      - redis
    environment:
      - PORT=3000
      - INSTANCE_NAME=backend-dotnet-2
      - REDIS_CONNECTION=redis:6379
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
    networks:
      - lab-network

  backend-3:
    build:
      context: ./backend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/backend:${IMAGE_TAG:-2.0.0}
    container_name: lab-backend-3
    restart: unless-stopped
    depends_on:
      - redis
    environment:
      - PORT=3000
      - INSTANCE_NAME=backend-dotnet-3
      - REDIS_CONNECTION=redis:6379
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
    networks:
      - lab-network
  ```

### 2. Configuración del Balanceador y Resiliencia en `nginx/nginx.conf`

* **Pool Upstream Balanceado**:
  Se incluyeron los tres nodos backend en el grupo `backend_cluster`:
  ```nginx
  upstream backend_cluster {
      server backend-1:3000 max_fails=2 fail_timeout=10s;
      server backend-2:3000 max_fails=2 fail_timeout=10s;
      server backend-3:3000 max_fails=2 fail_timeout=10s;
  }
  ```
  - **`max_fails=2`**: Si una instancia acumula 2 errores consecutivos en el intervalo de comprobación, Nginx la marca transitoriamente inactiva.
  - **`fail_timeout=10s`**: Ventana de penalización antes de volver a intentar enviar tráfico al nodo marcado como no saludable.

* **Failover Transparente con `proxy_next_upstream`**:
  Se actualizaron las rutas `/api/` y `/health` fijando la cantidad máxima de intentos en 3 (`proxy_next_upstream_tries 3`), coincidente con el número total de nodos disponibles en el cluster:
  ```nginx
  location /api/ {
      proxy_pass http://backend_cluster;
      proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
      proxy_next_upstream_tries 3;
  }

  location /health {
      proxy_pass http://backend_cluster;
      proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
      proxy_next_upstream_tries 3;
  }
  ```
  Si una petición golpea a un contenedor que sufre un colapso, timeout o error 5xx, Nginx reenvía la petición al siguiente nodo vivo del pool **en la misma llamada HTTP del cliente**, evitando presentar errores 502 al usuario.

---

## 🧪 Pruebas de Funcionamiento y Verificación de Alta Disponibilidad

### 1. Verificación de Balanceo Equitativo (Round-Robin)
Al realizar peticiones secuenciales a `/health` o `/api/tasks`:
- Petición 1: Atendida por `backend-dotnet-1`.
- Petición 2: Atendida por `backend-dotnet-2`.
- Petición 3: Atendida por `backend-dotnet-3`.
- Petición 4: Vuelve a `backend-dotnet-1`.

En el **Tablero Distribuido** (`TaskBoard.jsx`):
- El badge del encabezado (`"Última lectura atendida por: [Badge]"`) alterna entre Azul (`backend-dotnet-1`), Verde (`backend-dotnet-2`) y Naranja (`backend-dotnet-3`) al pulsar el botón de recarga o al recibir eventos.
- Al ingresar tareas de forma consecutiva, cada una exhibe el badge de su nodo creador (`createdByNode`), evidenciando la alternancia del balanceador.

### 2. Simulación de Falla de Nodo (Zero-Downtime Test)
1. Con los tres contenedores en ejecución, se fuerza la detención de un nodo:
   ```bash
   docker compose stop backend-2
   ```
2. Inmediatamente se envían nuevas tareas desde la interfaz gráfica o vía cURL:
   - Nginx detecta el socket cerrado en `backend-2:3000` y deriva transparentemente la petición a `backend-3` o `backend-1`.
   - La respuesta retorna código HTTP `200 OK` sin cortes de servicio.
   - Las tareas previamente creadas por `backend-dotnet-2` continúan visibles y editables en la pantalla gracias al almacenamiento desacoplado en Redis.
3. Al reiniciar la instancia (`docker compose start backend-2`), Nginx expira el `fail_timeout` y reincorpora el nodo al anillo de balanceo de forma automática.

---

## 📈 Conclusiones y Próximos Pasos
- Se completó la orquestación distribuida local con 3 réplicas independientes y tolerantes a fallos.
- La persistencia desacoplada en Redis elimina por completo el riesgo de pérdida de datos por muerte de contenedores de cómputo.
- El mecanismo `proxy_next_upstream_tries 3` garantiza disponibilidad continua mientras al menos un nodo permanezca operativo.

**Próxima Fase**:
- Ejecución de pruebas unitarias y de integración (`tests/Backend.Tests`) y validación de cobertura técnica (Etapa 4).
