# 🚀 2026-09-13: Troubleshooting de CD: Caché DNS en Nginx (502 Bad Gateway) y Visibilidad de Versión

**Fecha**: 2026-09-13  
**Hito**: Diagnóstico y resolución de la falla 502 Bad Gateway post-despliegue en el pipeline de CD (código de salida 22 en cURL), identificación del problema de caché DNS en Nginx tras recreación de contenedores y despliegue exitoso de la versión SemVer `2.1.2` con badge visual en el Frontend.

---

## 🎯 Objetivos de la sesión
- Diagnosticar la falla en el Stage 3 (CD) del pipeline de Azure DevOps (`curl: (22) The requested URL returned error: 502`).
- Comprender la causa raíz del error 502 devuelto por el Gateway al acceder a `http://68.211.137.116/`.
- Documentar el comportamiento de resolución DNS estática en Nginx dentro de redes de Docker (`bridge`).
- Implementar la solución definitiva en el pipeline para garantizar sincronización atómica entre el proxy inverso y los servicios upstream.
- Validar la visualización del nuevo tag SemVer (`v2.1.2`) directamente en la interfaz gráfica del Frontend.

---

## ⚠️ Dificultades Encontradas y Soluciones Técnicas (Troubleshooting)

### 1. El Incidente: 502 Bad Gateway y Falla en el Smoke Test (cURL exit code 22)
* **Síntoma**:
  - En Azure DevOps, el Stage 2 (CI) compiló y publicó exitosamente las imágenes `frontend:2.1.2` y `backend:2.1.2` en ACR.
  - El Stage 3 (CD) descargó las nuevas imágenes y recreó los contenedores `lab-frontend` y `lab-backend-1`.
  - Inmediatamente después, el paso de verificación falló con:
    ```
    curl: (22) The requested URL returned error: 502
    ##[error]Bash exited with code '22'.
    ```
  - Al ingresar por navegador a `http://68.211.137.116/`, Nginx devolvía:
    ```json
    {"status":502,"error":"Bad Gateway","instance":"Nginx Gateway","message":"Nginx could not reach any active backend instance (container down or OOM killed)"}
    ```

* **Investigación Forense en la VM**:
  - Al inspeccionar los logs de Nginx (`docker logs lab-nginx`), se observó el siguiente error repetitivo:
    ```text
    connect() failed (111: Connection refused) while connecting to upstream, 
    upstream: "http://172.21.0.3:8081/..."
    ```
  - Nginx estaba intentando conectarse a la IP `172.21.0.3` en el puerto `8081` (puerto del frontend).
  - Al inspeccionar las direcciones IP de los contenedores (`docker inspect`):
    - `lab-frontend`: **`172.21.0.2`** (escuchando en `8081`).
    - `lab-backend-1`: **`172.21.0.3`** (escuchando en `3000`).
    - `lab-nginx`: **`172.21.0.4`** (escuchando en `80`).

* **Causa Raíz Arquitectónica**:
  - En la configuración de Nginx:
    ```nginx
    upstream frontend_server {
        server frontend:8081;
    }
    ```
  - Nginx resuelve el nombre de host `frontend` **una sola vez al iniciar su proceso** y almacena esa dirección IP en memoria caché interna.
  - Como la imagen de Nginx (`nginx:alpine`) no cambió durante el release, Docker Compose recreó `lab-frontend` y `lab-backend-1`, pero **dejó a `lab-nginx` intacto** (`Container lab-nginx Running`).
  - Al recrearse, el demonio de Docker asignó nuevas IPs en la red bridge: `172.21.0.3` (que antes correspondía a frontend) pasó a ser la IP de `backend-1`.
  - Nginx continuó enviando el tráfico de frontend a `172.21.0.3:8081` (el contenedor backend). Como el backend escucha en el puerto 3000 y no en el 8081, el kernel Linux rechazó la conexión (`Connection refused`), y Nginx respondió con `502 Bad Gateway`.

* **Solución Técnica Aplicada**:
  1. **Reinicio inmediato de Nginx**: Al ejecutar `docker restart lab-nginx`, el proceso volvió a consultar el servidor DNS interno de Docker (`127.0.0.11`), actualizó la IP de `frontend` a `172.21.0.2` y tanto el frontend como el backend pasaron a responder **`200 OK`** de inmediato.
  2. **Automatización en el Pipeline (`azure-pipelines.yml`)**:
     Se incorporó un paso explícito en el job de CD para reiniciar el gateway luego de recrear los servicios, garantizando el refresco de DNS:
     ```bash
     docker compose up -d --remove-orphans
     docker compose restart nginx
     sleep 4
     curl -fsS http://localhost/ > /dev/null
     curl -fsS http://localhost/api/info > /dev/null
     ```

---

### 2. Inyección y Visibilidad de Versión en el Frontend (Vite + React)
* **Objetivo**: Garantizar que la versión calculada por SemVer (`v2.1.2`) se muestre explícitamente en la interfaz de usuario.
* **Implementación**:
  - En `frontend/src/App.jsx` se añadió un componente badge en el encabezado que lee `v{import.meta.env.VITE_APP_VERSION || '2.0.0'}`.
  - En `frontend/Containerfile` se agregaron las directivas `ARG VITE_APP_VERSION` y `ENV VITE_APP_VERSION=$VITE_APP_VERSION` en la etapa de compilación.
  - En `azure-pipelines.yml` se configuró `--build-arg VITE_APP_VERSION="$(SEMVER_TAG)"` durante el `docker build`.
  - Se selló el tag `v2.1.2` en el repositorio Git.

---

## 🧪 Pruebas y Resultados

1. **Verificación de Endpoints Locales en VM**:
   ```bash
   curl -i http://localhost/
   # HTTP/1.1 200 OK (sirve el HTML con bundle Vite)

   curl -i http://localhost/api/info
   # HTTP/1.1 200 OK {"instance":"backend-dotnet-1","isHealthy":true...}
   ```
2. **Acceso Externo Validado**:
   - Navegador en `http://68.211.137.116/`: Carga fluida de la aplicación React 18, comunicación activa con el backend de .NET 10 y visualización del badge **`v2.1.2`**.

---

## 💡 Lecciones Aprendidas

1. **Caché DNS en Reverse Proxies dentro de Docker**: Cuando se utilizan nombres de servicio en directivas `upstream` de Nginx, recrear contenedores sin reiniciar Nginx puede provocar desincronización de IPs (`stale DNS records`).
2. **Los Smoke Tests salvan despliegues rotos**: El fallo de `curl: (22) 502` en el pipeline cumplió exactamente su rol pedagógico y operativo: impidió dar por exitoso un release que dejaba el sitio caído para los usuarios.
