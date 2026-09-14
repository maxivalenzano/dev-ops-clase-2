# 🎓 Defensa Técnica y Presentación de Arquitectura Cloud & DevOps

> **Laboratorio Integral de Microservicios, IaaS en Azure, CI/CD DevSecOps y Gobernanza de Contenedores**  
> **Autor:** Maxi Valenzano — **Cátedra:** DevOps (UTN FRRe) — **Año:** 2026

---

## 🧭 Accesos Rápidos y Enlaces en Vivo

| Recurso | Enlace / Endpoint | Descripción |
| :--- | :--- | :--- |
| 🌐 **Aplicación Web en Producción** | [devops-maxivalenzano.com](http://devops-maxivalenzano.com) | Clúster de 3 réplicas Frontend + 3 réplicas Backend + Nginx + Redis |
| 🚢 **Portainer CE Dashboard** | [devops-maxivalenzano.com:9000](http://devops-maxivalenzano.com:9000) | Panel de control visual de los 10 contenedores en tiempo real |
| 🛡️ **SonarQube Cloud SAST** | [SonarCloud DevOps Dashboard](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps) | Quality Gate, análisis estático, cobertura y vulnerabilidades |
| ⚙️ **Azure Pipelines CI/CD** | [Azure DevOps Pipeline](https://dev.azure.com/maxivalenzano/DevOps/_build/latest?definitionId=1&branchName=devel) | Pipeline desacoplado en 4 stages automatizados |
| 📦 **GitHub Packages (GHCR)** | [dev-ops-backend](https://github.com/maxivalenzano/dev-ops-clase-2/pkgs/container/dev-ops-backend) / [frontend](https://github.com/maxivalenzano/dev-ops-clase-2/pkgs/container/dev-ops-frontend) | Registro público de imágenes OCI versionadas con SemVer |
| 🏷️ **GitHub Releases & Changelog** | [Releases Oficiales](https://github.com/maxivalenzano/dev-ops-clase-2/releases) | Historial de versiones y notas de despliegue automatizadas |

---

## 🗺️ Mapa Conceptual de Alto Nivel (End-to-End)

El siguiente mapa conceptual ilustra el flujo completo de vida del software: desde el desarrollo local y el versionado con Conventional Commits, pasando por el pipeline de 4 stages en Azure DevOps, hasta el empaquetado OCI dual y el despliegue continuo en la Máquina Virtual de Azure con observabilidad visual vía Portainer.

```
+---------------------------------------------------------------------------------------------------+
|                                  1. DESARROLLO & CONTROL DE CÓDIGO                                 |
+---------------------------------------------------------------------------------------------------+
|  • Desarrollo local con Podman / Podman Pods (red compartida localhost)                           |
|  • Estándar Conventional Commits (feat!, feat, fix) para Versionado Semántico 2.0.0               |
|  • Repositorio Git en GitHub: maxivalenzano/dev-ops-clase-2                                        |
+--------------------------------------------------+------------------------------------------------+
                                                   | Push a main / devel / tags
                                                   v
+---------------------------------------------------------------------------------------------------+
|                          2. AZURE DEVOPS MULTI-STAGE PIPELINE (DevSecOps)                         |
+---------------------------------------------------------------------------------------------------+
|  STAGE 1: Semantic Versioning (SemVer)                                                            |
|  └── Análisis de commits diferenciales -> Cálculo de MAJOR.MINOR.PATCH -> Exporta $(SEMVER_TAG)   |
|                                                  |                                                |
|  STAGE 2: Quality Gate & SAST (Validación & Seguridad)                                            |
|  ├── Job Backend: .NET 10 Build -> 42 Tests Unitarios (xUnit) -> Cobertura Dual -> SonarCloud SAST|
|  └── Job Frontend: React 18 / Vite Build -> Auditoría de Seguridad SAST con Aquasecurity Trivy    |
|                                                  | (Principio Fail-Fast: Si falla, se cancela)     |
|  STAGE 3: Packaging: Build & Push OCI            v                                                |
|  ├── Build multi-stage inmutable de imágenes Backend (.NET 10) y Frontend (React 18 / Nginx)     |
|  ├── Push a Azure Container Registry (ACR): acrdevopsvalenzano.azurecr.io                         |
|  └── Push paralelo a GitHub Packages (GHCR): ghcr.io/maxivalenzano/dev-ops-*                      |
|                                                  |                                                |
|  STAGE 4: Continuous Delivery (CD) en Azure VM   v                                                |
|  ├── Ejecución directa en VM vía Environment de Azure Pipelines (Agente vsts-agent local)         |
|  ├── Pull de imágenes desde ACR -> docker compose up -d -> docker compose restart nginx           |
|  ├── Smoke Tests HTTP automatizados (/ y /api/info)                                               |
|  └── Sincronización con GitHub: Tag Git, Release con Changelog dinámico y GitHub Deployments API   |
+--------------------------------------------------+------------------------------------------------+
                                                   | Despliegue en VM
                                                   v
+---------------------------------------------------------------------------------------------------+
|                      3. INFRAESTRUCTURA IaaS EN AZURE (Chile Central)                              |
+---------------------------------------------------------------------------------------------------+
|  Máquina Virtual: vm-dev-ops (Standard_B2als_v2: 2 vCPU AMD, 4 GB RAM, Ubuntu 24.04 LTS)          |
|  Dominio & DNS: devops-maxivalenzano.com (IONOS DNS -> IP Pública 68.211.137.116)               |
|  Network Security Group (NSG): Puertos 22 (SSH), 80 (HTTP), 443 (HTTPS), 9000 (Portainer)         |
|                                                                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  | Red Interna Docker Bridge (lab-network) - 10 Contenedores en Ejecución:                      |  |
|  |                                                                                             |  |
|  |  [Puerto 80] ---> lab-nginx (Gateway, Reverse Proxy, Load Balancer, Timeouts 5s, Failover)   |  |
|  |                       │                                      │                               |  |
|  |            / (Static SPA)                        /api (REST API)                            |  |
|  |                       ▼                                      ▼                               |  |
|  |     ┌───────────────────────────────────┐  ┌───────────────────────────────────┐             |  |
|  |     │     frontend_cluster (3 Nodos)    │  │     backend_cluster (3 Nodos)     │             |  |
|  |     │  • lab-frontend-1 (React 18 SPA)  │  │  • lab-backend-1 (.NET 10 Minimal)│             |  |
|  |     │  • lab-frontend-2 (React 18 SPA)  │  │  • lab-backend-2 (.NET 10 Minimal)│             |  |
|  |     │  • lab-frontend-3 (React 18 SPA)  │  │  • lab-backend-3 (.NET 10 Minimal)│             |  |
|  |     │  Límite: 0.25 CPU / 64MB RAM c/u  │  │  Límite: 0.5 CPU / 128MB RAM c/u  │             |  |
|  |     └───────────────────────────────────┘  └─────────────────┬─────────────────┘             |  |
|  |                                                              │ Persistencia                  |  |
|  |                                                              ▼                               |  |
|  |                                                    ┌───────────────────┐                     |  |
|  |                                                    │     lab-redis     │                     |  |
|  |                                                    │ (Caché y Tareas)  │                     |  |
|  |                                                    │ Vol: redis-data   │                     |  |
|  |                                                    └───────────────────┘                     |  |
|  |                                                                                             |  |
|  |  [Puerto 9000] -> portainer (Portainer CE 2.45 LTS) <--- Socket /var/run/docker.sock         |  |
|  |                   (Observabilidad visual, métricas, logs en vivo, Chaos Testing)             |  |
|  +---------------------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------------------+
```

---

## 1. Stack Tecnológico Integral

Cada tecnología elegida cumple un propósito pedagógico, arquitectónico y operativo dentro del laboratorio:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     STACK TECNOLÓGICO                                        │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬──────────────┤
│     FRONTEND      │      BACKEND      │    PERSISTENCIA   │   GATEWAY / RED   │  DEVSECOPS   │
├───────────────────┼───────────────────┼───────────────────┼───────────────────┼──────────────┤
│ • React 18 SPA    │ • .NET 10 Minimal │ • Redis 7 Alpine  │ • Nginx 1.25      │ • Azure Pipe.│
│ • Vite Tooling    │ • C# 14           │ • Memoria RAM     │ • Reverse Proxy   │ • SonarCloud │
│ • TypeScript      │ • 42 Tests xUnit  │ • Claves hash     │ • Load Balancer   │ • Trivy SAST │
│ • Nginx Alpine    │ • OpenCover / TRX │ • Persistencia AOF│ • Timeout tuning  │ • SemVer 2.0 │
│ • Clúster 3 Nodos │ • Clúster 3 Nodos │ • Vol. redis-data │ • Next Upstream   │ • ACR + GHCR │
│ • 0.25 CPU / 64MB │ • 0.5 CPU / 128MB │ • Puerto 6379     │ • Failover 502/504│ • Portainer  │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┴──────────────┘
```

### Detalle de Componentes

1. **Frontend (React 18 + Vite SPA)**:
   - Dashboard interactivo para pruebas de carga, latencia, toggling de salud de réplicas y simulación de fugas de memoria.
   - Construcción multi-stage: el código TypeScript se transfigura en bundle estático y se monta sobre un contenedor ligero `nginx:alpine-slim` optimizado para SPA (`try_files $uri /index.html`).
   - Clúster horizontal de **3 réplicas** (`lab-frontend-1`, `lab-frontend-2`, `lab-frontend-3`), cada una limitada estrictamente a **0.25 CPU y 64 MB de RAM**.

2. **Backend (.NET 10 Minimal API)**:
   - Microservicio moderno en C# compilado sobre el SDK oficial de .NET 10.
   - Provee endpoints de negocio, firma criptográfica de nodo de atención y endpoints de simulación de fallas (*Chaos Engineering*):
     - `/api/chaos/cpu`: estrés intensivo de procesador.
     - `/api/chaos/memory`: fuga progresiva de RAM para provocar el **OOM Killer** del kernel Linux.
     - `/api/chaos/delay`: respuestas diferidas para activar timeouts de Nginx.
     - `/api/chaos/toggle-health`: degradación de salud lógica para forzar failovers.
   - Clúster horizontal de **3 réplicas** (`lab-backend-1`, `lab-backend-2`, `lab-backend-3`), limitadas a **0.5 CPU y 128 MB de RAM**.

3. **Persistencia y Estado Distribuido (Redis 7)**:
   - Base de datos en memoria Redis 7 Alpine.
   - Resuelve el problema del estado compartido en un clúster distribuido: almacena tareas, contadores globales y registros de firma de cada nodo.
   - Respaldada por el volumen nombrado Docker `redis-data` para evitar pérdida de datos ante reinicios de contenedores.

4. **Gateway y Reverse Proxy (Nginx 1.25 Alpine)**:
   - Único punto de entrada HTTP expuesto en el puerto 80.
   - Balanceo de carga *Round Robin* hacia los dos clústeres upstream (`frontend_cluster` y `backend_cluster`).
   - Configuración de resiliencia avanzada:
     - `proxy_read_timeout 5s;`: corta peticiones estancadas y devuelve `504 Gateway Timeout`.
     - `proxy_next_upstream error timeout http_500 http_502 http_503 http_504;`: redirige instantáneamente la petición hacia otra réplica sana ante cualquier fallo del nodo primario.
     - Páginas de error personalizadas devolviendo payloads JSON estructurados.

5. **Entorno de Contenedores (Podman vs Docker)**:
   - **Localmente (Podman)**: Ejecución sin privilegios (*rootless*) y uso de **Podman Pods** nativos donde múltiples contenedores comparten el mismo namespace de red sobre `localhost`.
   - **En la Nube (Docker Engine 29.8 + Docker Compose v5.5)**: Runtime robusto y estandarizado en la VM Ubuntu de Azure para orquestar la composición de 10 contenedores.

---

## 2. Máquina Virtual Usada en Azure (IaaS)

### Ficha Técnica de la Infraestructura

| Atributo | Configuración / Valor | Justificación Técnica |
| :--- | :--- | :--- |
| **Nombre del Recurso** | `vm-dev-ops` | Servidor IaaS dedicado para el laboratorio de microservicios |
| **Grupo de Recursos** | `rg-devops-lab` | Agrupa la VM, el disco administrado, la VNet, NSG y la IP pública |
| **Región de Azure** | `Chile Central` (`chilecentral`) | Latencia mínima para Sudamérica (~15-20 ms) vs regiones saturadas en USA |
| **Tamaño / SKU** | **`Standard_B2als_v2`** | **2 vCPUs AMD EPYC™, 4 GB RAM**, arquitectura x86_64 |
| **Sistema Operativo** | Ubuntu 24.04 LTS (Noble Numbat) | Kernel Linux moderno (6.8+) con soporte nativo para cgroups v2 |
| **IP Pública Estática** | `68.211.137.116` | Dirección IPv4 pública directa asignada en Azure |
| **IP Privada (VNet)** | `172.16.0.4` | IP interna dentro de la subred virtual `default` (172.16.0.0/24) |
| **Dominio Personalizado** | `devops-maxivalenzano.com` | DNS gestionado en IONOS con registros tipo A hacia la IP de Azure |
| **Costo Operativo** | **~$0.052 USD/hora** (~$37/mes) | Compatible 100% con los créditos de **Azure for Students** ($100 USD) |

```
                       AZURE REGION: CHILE CENTRAL
┌────────────────────────────────────────────────────────────────────────┐
│ Resource Group: rg-devops-lab                                          │
│                                                                        │
│   Virtual Network (VNet: 172.16.0.0/16)                                │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │ Subnet: default (172.16.0.0/24)                                │   │
│   │                                                                │   │
│   │   Máquina Virtual: vm-dev-ops (Standard_B2als_v2)             │   │
│   │   • IP Privada: 172.16.0.4                                     │   │
│   │   • IP Pública: 68.211.137.116 (devops-maxivalenzano.com)      │   │
│   │   • 2 vCPU AMD EPYC | 4 GB RAM | Ubuntu 24.04 LTS              │   │
│   │   • Docker Engine 29.8 + Docker Compose                        │   │
│   │   • Azure DevOps Agent (vsts-agent daemon systemd)             │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                                                        │
│   Network Security Group (NSG): vm-dev-ops-nsg                         │
│   ├── Puerto 22 TCP   ──> SSH (Acceso administrativo con PEM RSA)      │
│   ├── Puerto 80 TCP   ──> HTTP (Tráfico Web & API vía Nginx)           │
│   ├── Puerto 443 TCP  ──> HTTPS (Tráfico Seguro TLS)                   │
│   └── Puerto 9000 TCP ──> HTTP (Consola Visual Portainer CE)           │
└────────────────────────────────────────────────────────────────────────┘
```

### Reglas del Network Security Group (NSG)

El tráfico entrante está regulado estrictamente en el firewall perimetral de Azure (**`vm-dev-ops-nsg`**):

1. **Puerto 22 (SSH)**: Permite acceso a la consola del servidor exclusivamente mediante clave criptográfica RSA 2048 (`vm-dev-ops_key.pem`) para el usuario `azureuser`. Sin acceso por password.
2. **Puerto 80 (HTTP)**: Acceso público irrestricto hacia el contenedor Gateway `lab-nginx`.
3. **Puerto 443 (HTTPS)**: Reservado para terminación TLS/SSL.
4. **Puerto 9000 (HTTP - Portainer CE)**: Regla añadida específicamente para permitir que evaluadores y docentes accedan directamente al panel gráfico de gestión de contenedores sin requerir túneles SSH.

### ¿Por qué IaaS (Máquina Virtual) en lugar de PaaS (App Service / ACA)?

1. **Visibilidad Pedagógica Real**: En un PaaS (como Azure App Service o Container Apps), la infraestructura subyacente está abstraída. En este laboratorio, se buscaba experimentar con:
   - Límites estrictos de memoria por cgroups y el comportamiento del **OOM Killer del kernel Linux**.
   - Configuración manual de sockets unix (`/var/run/docker.sock`).
   - Funcionamiento a bajo nivel de Nginx L4/L7, resolución DNS interna de Docker y bridge networking.
   - Control del demonio del agente de Azure Pipelines como servicio nativo de `systemd`.
2. **Viabilidad Presupuestaria con Azure for Students**:
   - Azure App Service con soporte de nombres de dominio personalizados y ranuras de despliegue (*deployment slots*) requiere planes como `Standard S1` (~$73 USD/mes), agotando la suscripción académica en cuestión de semanas.
   - La VM `Standard_B2als_v2` con 2 cores y 4 GB de RAM tiene una tarifa de tan solo ~$0.052/hora, permitiendo alojar la totalidad de los 10 contenedores holgadamente dentro del crédito estudiantil.

---

## 3. Modelo de Arquitectura y Red en Azure

### Flujo de Tráfico: De Internet al Clúster de Contenedores

```
             Cliente Web / Docente                     Administrador / Docente
           (http://devops-maxivalenzano.com)      (http://devops-maxivalenzano.com:9000)
                         │                                           │
                         ▼                                           ▼
            Resolución DNS (IONOS DNS)                  Resolución DNS (IONOS DNS)
          Registros A -> 68.211.137.116               Registros A -> 68.211.137.116
                         │                                           │
                         ▼                                           ▼
             +───────────────────────────────────────────────────────────────────+
             |                 Azure Network Security Group (NSG)                |
             |       Filtro Perimetral de Puertos: Permite 80, 9000, 22          |
             +───────────────────────────────────────────────────────────────────+
                         │                                           │
          Puerto 80 HTTP │                            Puerto 9000    │
                         ▼                                           ▼
             +───────────────────────+                   +───────────────────────+
             |       lab-nginx       |                   |       portainer       |
             |  (Reverse Proxy en VM)|                   |  (Portainer CE 2.45)  |
             +───────────────────────+                   +───────────┬───────────+
                         │                                           │
      ┌──────────────────┴──────────────────┐                        │ /var/run/docker.sock
      │                                     │                        ▼
      │ / o estáticos                       │ /api/*         +───────────────────+
      ▼                                     ▼                | Docker Engine Host|
+───────────────────────────+ +───────────────────────────+  |  (Gestión Total)  |
|     frontend_cluster      | |      backend_cluster      |  +───────────────────+
| (3 Réplicas en lab-network) | (3 Réplicas en lab-network)
| • lab-frontend-1 (:80)    | | • lab-backend-1 (:3000)   |
| • lab-frontend-2 (:80)    | | • lab-backend-2 (:3000)   |
| • lab-frontend-3 (:80)    | | • lab-backend-3 (:3000)   |
+───────────────────────────+ +─────────────┬─────────────+
                                            │ Persistencia
                                            ▼
                               +─────────────────────────+
                               |        lab-redis        |
                               | (Almacén de Estado :6379|
                               |  Volumen: redis-data)   |
                               +─────────────────────────+
```

### Aislamiento y Resiliencia en la Red `lab-network`

- Todos los contenedores conviven en una red tipo bridge creada por Docker Compose: **`lab-network`**.
- Solo `lab-nginx` (puerto 80) y `portainer` (puerto 9000) tienen puertos publicados (*published ports*) hacia el host y el exterior.
- Las réplicas de frontend, de backend y la base de datos Redis están **completamente aisladas de internet**: solo son accesibles internamente mediante el DNS integrado de Docker por nombre de servicio (`http://frontend-1`, `http://backend-1`, `redis:6379`).

---

## 4. Conexión del Pipeline en Azure DevOps

El pipeline de CI/CD corre en **Azure DevOps** en la organización y proyecto **`maxivalenzano/DevOps`**, vinculado al repositorio de GitHub **`maxivalenzano/dev-ops-clase-2`**.

```
+──────────────────────────────────────────────────────────────────────────────────────────────┐
│                              TOPOLOGÍA DE CONEXIÓN EN AZURE DEVOPS                           │
├────────────────────────────────┬───────────────────────────────┬─────────────────────────────┤
│      SERVICIO / DESTINO        │     MECANISMO DE CONEXIÓN     │            TIPO             │
├────────────────────────────────┼───────────────────────────────┼─────────────────────────────┤
│ 🐙 Repositorio GitHub          │ GitHub Service Connection     │ OAuth 2.0 / Webhook         │
│ 🏗️ Azure Container Registry   │ Service Connection de Docker  │ `acrdevopsvalenzano-sc`     │
│ 🛡️ SonarQube Cloud SAST       │ SonarCloud Service Connection │ Token API maxivalenzano     │
│ 💻 Máquina Virtual Ubuntu      │ Azure DevOps Environment      │ `devops-vm-env` (Agente)    │
│ 📦 GitHub Packages & Releases  │ Variable Secreta Pipeline     │ `$(GITHUB_PAT)`             │
└────────────────────────────────┴───────────────────────────────┴─────────────────────────────┘
```

### Detalle de las Conexiones de Servicio (Service Connections)

1. **Conexión al Repositorio de GitHub**:
   - Azure DevOps está suscrito mediante webhooks automáticos al repositorio GitHub.
   - Cualquier `git push` a las ramas `main` o `devel`, o la creación de un tag `v*`, dispara la ejecución del pipeline multi-stage.

2. **Conexión a Azure Container Registry (`acrdevopsvalenzano-sc`)**:
   - Service Connection configurada en Azure DevOps con el rol de *AcrPush*.
   - Permite que los agentes en la nube de Microsoft ejecuten `docker login` y `docker push` hacia `acrdevopsvalenzano.azurecr.io` de manera desatendida y sin exponer credenciales en los scripts.

3. **Conexión a SonarQube Cloud (`SonarCloud`)**:
   - Vinculada con el token personal de la organización `maxivalenzano`.
   - Permite al analizador SAST `SonarCloudPrepare@4` y `SonarCloudAnalyze@4` enviar métricas de cobertura y escaneo estático de código C# a SonarQube Cloud, y bloquear el pipeline con `SonarCloudPublish@4` si el Quality Gate no cumple los estándares.

4. **Conexión a la VM de Azure vía Environment (`devops-vm-env`)**:
   - En lugar de usar SSH directo desde la nube hacia la VM (que requeriría exponer credenciales o abrir puertos adicionales), se utilizó la funcionalidad nativa de **Azure Pipelines Environments**.
   - En la VM Ubuntu se instaló y registró el agente de Azure Pipelines (`vsts-agent`) como un demonio `systemd` que corre bajo el usuario `azureuser`.
   - Cuando el Stage 4 (CD) se ejecuta, Azure DevOps delega el trabajo al agente que ya reside dentro de la VM, ejecutando los comandos `docker compose pull` y `up` localmente con máxima seguridad.

5. **Token Secreto de GitHub (`GITHUB_PAT`)**:
   - Se inyectó como variable secreta en Azure DevOps un Personal Access Token de GitHub con permisos de:
     - `write:packages`: publicar imágenes en GitHub Container Registry (GHCR).
     - `repo`: crear tags Git, publicar GitHub Releases oficiales y actualizar descripciones y topics.
     - `workflow`: interactuar con la GitHub Deployments API para reportar estados de producción en tiempo real.

---

## 5. Azure Container Registry (ACR) y Carga a GitHub (GHCR)

El proyecto implementa una **Estrategia Dual de Registro de Contenedores OCI**:

```
                                  Azure DevOps Stage 3: Packaging
                                                 │
                   ┌─────────────────────────────┴─────────────────────────────┐
                   │                                                           │
                   ▼                                                           ▼
     [Azure Container Registry]                                   [GitHub Packages - GHCR]
    acrdevopsvalenzano.azurecr.io                                ghcr.io/maxivalenzano/...
                   │                                                           │
    ┌──────────────┴──────────────┐                             ┌──────────────┴──────────────┐
    ▼                             ▼                             ▼                             ▼
backend:$(SEMVER)           frontend:$(SEMVER)           dev-ops-backend:$(SEMVER)    dev-ops-frontend:$(SEMVER)
backend:latest              frontend:latest              dev-ops-backend:latest       dev-ops-frontend:latest
    │                                                           │
    ▼                                                           ▼
Uso Interno de Producción:                                  Uso Público y Comunitario:
• Descarga ultrarrápida en la VM de Azure                   • Portafolio y visibilidad open-source
• Misma región (Chile Central: sin egress costs)            • Badges dinámicos en el README de GitHub
• Red privada y credenciales administradas                  • Trazabilidad vinculada a commits y PRs
```

### Proceso de Construcción y Publicación Paso a Paso

1. **Construcción Multi-Stage Optimizada**:
   - **Backend**:
     - *Build Stage*: Imagen `mcr.microsoft.com/dotnet/sdk:10.0` para compilar y publicar en modo Release optimizado.
     - *Runtime Stage*: Imagen `mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled` (o alpine), reduciendo la superficie de ataque y el tamaño final a menos de 90 MB.
   - **Frontend**:
     - *Build Stage*: Imagen `node:20-alpine` ejecutando `npm ci && npm run build` inyectando la variable de versión `--build-arg VITE_APP_VERSION="$(SEMVER_TAG)"`.
     - *Runtime Stage*: Imagen `nginx:alpine` sirviendo exclusivamente los archivos estáticos compilados en `/usr/share/nginx/html`.

2. **Publicación en Azure Container Registry (ACR)**:
   - Login desatendido con la tarea oficial `Docker@2` vinculada a `acrdevopsvalenzano-sc`.
   - Se construyen y etiquetan las imágenes con la versión SemVer calculada (`2.0.0`, `2.1.0`, etc.) y con el tag `latest`.
   - Se ejecutan los comandos:
     ```bash
     docker push acrdevopsvalenzano.azurecr.io/backend:$(SEMVER_TAG)
     docker push acrdevopsvalenzano.azurecr.io/backend:latest
     docker push acrdevopsvalenzano.azurecr.io/frontend:$(SEMVER_TAG)
     docker push acrdevopsvalenzano.azurecr.io/frontend:latest
     ```

3. **Publicación en GitHub Packages (GHCR)**:
   - Utilizando la variable secreta `GITHUB_PAT`, el pipeline realiza login dinámico contra `ghcr.io`:
     ```bash
     echo "${GITHUB_PAT}" | docker login ghcr.io -u maxivalenzano --password-stdin
     ```
   - Se re-etiquetan las imágenes compiladas y se suben al registro de GitHub:
     ```bash
     docker tag acrdevopsvalenzano.azurecr.io/backend:$(SEMVER_TAG) ghcr.io/maxivalenzano/dev-ops-backend:$(SEMVER_TAG)
     docker tag acrdevopsvalenzano.azurecr.io/backend:latest ghcr.io/maxivalenzano/dev-ops-backend:latest
     docker push ghcr.io/maxivalenzano/dev-ops-backend:$(SEMVER_TAG)
     docker push ghcr.io/maxivalenzano/dev-ops-backend:latest
     ```
   - El script maneja errores de forma no bloqueante (`|| echo "[Aviso]..."`), asegurando que si la API de GitHub experimenta latencia, el despliegue a producción en Azure continúe sin trabarse.

---

## 6. Los 4 Stages del Pipeline CI/CD (DevSecOps)

El archivo [`azure-pipelines.yml`](https://github.com/maxivalenzano/dev-ops-clase-2/blob/main/azure-pipelines.yml) implementa un flujo desacoplado en **4 Stages secuenciales e independientes**:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                AZURE PIPELINES: 4 STAGES CI/CD                                   │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                 │
                                                 ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ STAGE 1: Semantic Versioning (SemVer)                                                          │
 │ • Agente: Microsoft-hosted ubuntu-latest                                                       │
 │ • Checkout completo de Git (fetchDepth: 0)                                                      │
 │ • Análisis sintáctico de Conventional Commits (feat!, feat, fix)                               │
 │ • Determina MAJOR, MINOR, PATCH incremental (ej: 2.1.0)                                         │
 │ • Exporta variable de salida: SEMVER_TAG y actualiza Build Number visible                      │
 └────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                  │
                                                  ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ STAGE 2: Quality Gate & SAST (Validación & Seguridad)                                          │
 │ ├── Job A: Backend .NET 10 (Tests & SonarCloud)                                                │
 │ │   • SDK .NET 10 oficial                                                                      │
 │ │   • Preparación de SonarQube Cloud (scannerMode: dotnet)                                     │
 │ │   • Validación de compilación Release de Backend                                             │
 │ │   • Ejecución de 42 pruebas unitarias (tests/Backend.Tests) con xUnit                        │
 │ │   • Recolección de Cobertura Dual (Cobertura + OpenCover)                                     │
 │ │   • Publicación de TRX (PublishTestResults@2) y Cobertura (PublishCodeCoverageResults@2)       │
 │ │   • Análisis SAST y evaluación bloqueante del Quality Gate en SonarQube Cloud                │
 │ └── Job B: Frontend React 18 & Auditoría Trivy                                                  │
 │     • Instalación limpia de dependencias: npm ci                                               │
 │     • Build de producción de la SPA (React 18 + Vite)                                          │
 │     • Auditoría de vulnerabilidades con Aquasecurity Trivy (trivy fs --severity HIGH,CRITICAL)  │
 │  * POLÍTICA FAIL-FAST: Si un test falla o SonarCloud rechaza el Quality Gate, se aborta todo. │
 └────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                  │
                                                  ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ STAGE 3: Packaging (Build & Push OCI)                                                          │
 │ • Agente: Microsoft-hosted ubuntu-latest                                                       │
 │ • Consume $(SEMVER_TAG) del Stage 1                                                            │
 │ • Docker Login a ACR mediante Service Connection (acrdevopsvalenzano-sc)                       │
 │ • Construcción inmutable OCI de Backend (.NET 10) inyectando labels OCI                        │
 │ • Construcción inmutable OCI de Frontend inyectando VITE_APP_VERSION                           │
 │ • Push de imágenes a Azure Container Registry (ACR) con tags SemVer y latest                   │
 │ • Login y Push en espejo hacia GitHub Container Registry (GHCR) vía GITHUB_PAT                 │
 └────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                  │
                                                  ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ STAGE 4: Continuous Delivery (CD en Azure VM)                                                  │
 │ • Agente: VM Linux local de Azure mediante Environment: devops-vm-env                           │
 │ • Condición: Ramas main, devel o tags v* (excluye Pull Requests)                               │
 │ • Descarga las imágenes inmutables desde ACR: docker compose pull                              │
 │ • Despliega el clúster sin downtime: docker compose up -d --remove-orphans                     │
 │ • Reinicia Nginx para actualizar resolución DNS de los contenedores                            │
 │ • Smoke Tests HTTP automáticos contra http://localhost/ y http://localhost/api/info            │
 │ • Sincronización completa con GitHub:                                                          │
 │   - Creación y publicación del tag Git oficial vX.Y.Z                                          │
 │   - Generación del GitHub Release oficial con Changelog dinámico por commits vía curl/jq       │
 │   - Actualización de metadatos de portada del repositorio (descripción, homepage, topics)      │
 │   - Notificación oficial a GitHub Deployments API marcando el despliegue como 'success'        │
 └────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Observabilidad y Operaciones con Portainer CE

### ¿Qué es Portainer CE y por qué se implementó?

**Portainer Community Edition (CE)** es una plataforma líder para la gestión visual, monitoreo y operación de entornos de contenedores Docker. Se incorporó a la solución para resolver la necesidad de **visibilidad en tiempo real** de la infraestructura sin depender exclusivamente de sesiones SSH por consola.

```
                  ACCESO A PORTAINER CE
           http://devops-maxivalenzano.com:9000
                            │
                            ▼
          ┌───────────────────────────────────┐
          │     Azure NSG: Regla Puerto 9000  │
          └─────────────────┬─────────────────┘
                            ▼
          ┌───────────────────────────────────┐
          │   Contenedor portainer en la VM   │
          │     (Portainer CE 2.45 LTS)       │
          └─────────────────┬─────────────────┘
                            │ Montaje de socket unix
                            ▼
          ┌───────────────────────────────────┐
          │       /var/run/docker.sock        │
          │ (Comunicación con Docker Daemon)  │
          └─────────────────┬─────────────────┘
                            │
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼
[Métricas CPU/RAM]   [Live Logs Stream]   [Chaos Testing en Vivo]
Monitoreo de los     Inspección de logs   Pausar/Detener réplicas
10 contenedores      en tiempo real       para probar failover
```

### Configuración en `compose.yaml`

El servicio fue formalizado bajo el paradigma GitOps en el archivo de composición:

```yaml
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - lab-network

volumes:
  redis-data:
    driver: local
  portainer_data:
    driver: local
```

### Características Clave de Portainer en el Laboratorio

1. **Monitoreo en Tiempo Real**: Visualización simultánea del estado, uptime y consumo de recursos (CPU, memoria, Network I/O) de los 10 contenedores que forman el clúster.
2. **Inspección de Logs sin SSH**: Capacidad de ver los registros de eventos de cualquier réplica de .NET 10, Nginx o Redis directamente desde el navegador con herramientas de filtrado y búsqueda.
3. **Consola Web Interactiva (`Exec Console`)**: Apertura de sesiones de terminal (`/bin/sh`) dentro de cualquier contenedor en ejecución para tareas de diagnóstico rápido.
4. **Persistencia de Configuración**: El volumen nombrado `portainer_data` resguarda las cuentas de usuario y configuraciones ante reinicios de la máquina o re-despliegues del pipeline.

### Rol Fundamental durante la Defensa del Trabajo Práctico

Portainer CE es la herramienta idónea para **demostrar en vivo ante la cátedra** las capacidades de Resiliencia y Alta Disponibilidad del sistema:

- **Demostración de Chaos Testing**: Durante la presentación, se puede acceder a Portainer, detener deliberadamente una réplica de backend (`lab-backend-1`) o de frontend (`lab-frontend-2`) y mostrar en la pantalla contigua sobre la web pública ([http://devops-maxivalenzano.com](http://devops-maxivalenzano.com)) cómo el tráfico continúa fluyendo a través de Nginx hacia las réplicas sobrevivientes sin ningún error `502 Bad Gateway`.
- **Comprobación de Límites de Memoria (OOM Killer)**: Se puede disparar la fuga de memoria desde el frontend y observar en las gráficas de Portainer cómo la memoria del contenedor backend trepa hasta los 128 MB, momento en el cual el kernel Linux lo elimina (código de salida 137) y Docker lo reinicia automáticamente.

---

## 🎯 Resumen Ejecutivo para la Evaluación

| Criterio Evaluado | Solución Implementada | Evidencia Técnica |
| :--- | :--- | :--- |
| **IaaS Cloud Hosting** | VM `Standard_B2als_v2` en Azure Chile Central | Ubuntu 24.04 LTS, IP `68.211.137.116`, DNS `devops-maxivalenzano.com` |
| **Microservicios y Clúster** | 10 contenedores orquestados con Docker Compose | 3x Frontend (React 18), 3x Backend (.NET 10), Redis 7, Nginx, Portainer |
| **Alta Disponibilidad** | Nginx Gateway con upstream Round Robin y Failover | `proxy_next_upstream`, timeouts 5s, páginas de error JSON estructuradas |
| **Pruebas de Caos (Chaos)** | Endpoints de estrés de CPU, fuga de RAM y health | OOM Killer forzado a 128 MB, timeouts forzados, failover en vivo |
| **CI/CD Automatizado** | Azure DevOps Multi-Stage Pipeline (4 Stages) | Versionado SemVer automático, empaquetado OCI, CD en VM con Smoke Tests |
| **Calidad y Seguridad (SAST)** | SonarQube Cloud + Aquasecurity Trivy + xUnit | 42 tests unitarios, cobertura Cobertura/OpenCover, Quality Gate bloqueante |
| **Gestión de Artefactos** | Registro dual: Azure ACR + GitHub Packages (GHCR) | Etiquetas SemVer inmutables (`SEMVER_TAG`) y `latest` publicadas en paralelo |
| **Gobernanza y Releases** | Automatización completa en GitHub vía API REST | Tags automáticos, GitHub Releases con changelog dinámico, GitHub Deployments |
| **Observabilidad Visual** | Portainer CE en puerto 9000 con regla en Azure NSG | Acceso web directo a métricas, logs y consola de los 10 contenedores |
