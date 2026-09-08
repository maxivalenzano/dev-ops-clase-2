# 🌐 Infraestructura, Nginx y Pods

Configuración del Gateway central, políticas de balanceo y networking sobre Podman.

---

## 🚪 Nginx Gateway & Reverse Proxy

El Gateway actúa como punto único de contacto (Single Point of Entry) para el cliente en el puerto `8080`.

### Configuración del Upstream Cluster

```nginx
upstream backend_cluster {
    server backend-1:3000 max_fails=2 fail_timeout=10s;
    server backend-2:3000 max_fails=2 fail_timeout=10s;
}
```

---

## ⚖️ Balanceo y Resiliencia

### 1. Failover Activo (`proxy_next_upstream`)
Si una de las réplicas devuelve un error 500/502/503/504 o la conexión expira, Nginx redirige automáticamente la petición a la siguiente réplica sin que el usuario final perciba el fallo.

```nginx
location /api/ {
    proxy_pass http://backend_cluster;
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;
}
```

### 2. Timeouts Agresivos para Pruebas
Para evidenciar fallos rápidamente en el laboratorio, se fijó el timeout en 5 segundos:
```nginx
proxy_connect_timeout 5s;
proxy_send_timeout 5s;
proxy_read_timeout 5s;
```

### 3. Respuestas de Error JSON
En lugar de las páginas HTML por defecto de Nginx, se configuran respuestas JSON limpias:
* `502 Bad Gateway`: Cuando ninguna réplica está disponible o viva.
* `504 Gateway Timeout`: Cuando el backend superó los 5 segundos de respuesta.

---

## 🚀 Podman Pods (Localhost Networking)

Cuando se ejecuta mediante el script `run-pod.ps1` (o `.sh`), todos los contenedores entran en un único **Pod**:

```
+-------------------------------------------------------------+
|                         lab-pod                             |
|                                                             |
|   Nginx (Port 80) <---> Frontend SPA (Port 8081)           |
|        ^                                                    |
|        |                                                    |
|        +-------------> Backend-1 (Port 3001)               |
|        |                                                    |
|        +-------------> Backend-2 (Port 3002)               |
|                                                             |
|   (Toda la comunicación interna se realiza por localhost)   |
+-------------------------------------------------------------+
```

### Script de Lanzamiento (`scripts/run-pod.ps1`)
El script ejecuta:
1. `podman pod create --name lab-pod -p 8080:80`
2. Construye y arranca los contenedores de backend asignándoles puertos únicos (`3001` y `3002`).
3. Construye y arranca el frontend en el puerto `8081`.
4. Levanta el contenedor de Nginx usando `nginx-pod.conf` configurado para apuntar a `localhost:3001`, `localhost:3002` y `localhost:8081`.
