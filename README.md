# 🚀 Podman Container & Microservices Lab

[![Production Demo](https://img.shields.io/badge/Demo-Online%20(Azure%20VM)-brightgreen?style=flat&logo=googlechrome&logoColor=white)](http://devops-maxivalenzano.com)
[![Informe TP1](https://img.shields.io/badge/Informe-TP1%20(UTN%20FRRe)-red?style=flat&logo=markdown&logoColor=white)](INFORME_TP1.md)
[![GitHub Release](https://img.shields.io/github/v/release/maxivalenzano/dev-ops-clase-2?color=blue&logo=github)](https://github.com/maxivalenzano/dev-ops-clase-2/releases)
[![Changelog](https://img.shields.io/badge/Changelog-Keep%20a%20Changelog-orange?logo=git&logoColor=white)](CHANGELOG.md)
[![Azure Pipelines Build](https://dev.azure.com/maxivalenzano/DevOps/_apis/build/status/maxivalenzano.dev-ops-clase-2?branchName=devel)](https://dev.azure.com/maxivalenzano/DevOps/_build/latest?definitionId=1&branchName=devel)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=maxivalenzano_DevOps&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=maxivalenzano_DevOps&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=maxivalenzano_DevOps&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=maxivalenzano_DevOps&metric=coverage)](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps)
[![GitHub Packages](https://img.shields.io/badge/GitHub-Packages%20(GHCR)-black?logo=github)](https://github.com/maxivalenzano/dev-ops-clase-2/pkgs/container/dev-ops-backend)
[![.NET 10](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet&logoColor=white)](backend/)
[![React 18](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)](frontend/)
[![Nginx Gateway](https://img.shields.io/badge/Nginx-Reverse%20Proxy-009639?logo=nginx&logoColor=white)](nginx/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](compose.yaml)

A lightweight, hands-on lab designed to master **Podman**, container orchestration, **Nginx** reverse proxying, load balancing, timeouts, resource limits (CPU/OOM), and native **Podman Pods** (`localhost` network sharing). Deployed automatically to Azure VM via Azure DevOps Multi-Stage CI/CD.

👉 **Informe TP 1 (UTN FRRe)**: [INFORME_TP1.md](INFORME_TP1.md)  
👉 **Live Application**: [http://devops-maxivalenzano.com](http://devops-maxivalenzano.com)  
👉 **Container Management (Portainer CE)**: [http://devops-maxivalenzano.com:9000](http://devops-maxivalenzano.com:9000)  

---

## 🏛️ Architecture Overview

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
     |     React 18 Frontend    |  |  Backend Replicas (.NET) |
     |  (Vite + Nginx Static)   |  |  - backend-1 (Port 3001) |
     |  Port 80 (or 8081 in Pod)|  |  - backend-2 (Port 3002) |
     +--------------------------+  +--------------------------+
```

---

## ⚡ Quick Start Options

### Option A: Using Podman Compose (Bridge Network)

This mode runs independent containers connected via a bridge network (`lab-network`):

```bash
# Start all containers in the background with build
podman compose up --build -d

# Check running containers
podman ps

# View live logs
podman compose logs -f

# Stop and tear down
podman compose down
```

---

### Option B: Using Native Podman Pod (Shared `localhost` Network)

In Podman, a **Pod** is a group of containers sharing the same Linux network namespace (just like in Kubernetes). All containers communicate over `localhost` on their distinct ports!

#### On Windows (PowerShell):
```powershell
.\scripts\run-pod.ps1
```

#### On Linux / macOS / WSL (Bash):
```bash
chmod +x ./scripts/run-pod.sh
./scripts/run-pod.sh
```

---

## 🧪 Experiments & Chaos Testing

Open your browser at **`http://localhost:8080`** to access the interactive dashboard.

### 1. ⚖️ Load Balancing Test
- **Concept**: Nginx distributes traffic across multiple backend instances (`backend-1` and `backend-2`).
- **Test**: Set **Requests** to `50` and click **Launch Load Test**.
- **Observe**: Watch the **Upstream Load Distribution** bar chart alternate requests evenly between the instances.

---

### 2. ⏱️ Gateway Timeout Test (`504 Gateway Timeout`)
- **Concept**: Nginx is configured with `proxy_read_timeout 5s`.
- **Test**:
  - Select **3000 ms (3s)** and click **Send Delayed Request** -> Response is `200 OK`.
  - Select **6000 ms (6s)** and click **Send Delayed Request** -> Nginx terminates the connection and returns `504 Gateway Timeout`.

---

### 3. 💾 Out-of-Memory (OOM) Container Kill Test
- **Concept**: Each backend container is strictly capped at `128MB` RAM limit (`--memory 128m`).
- **Test**:
  - Click **Leak 50MB RAM** once or twice -> Memory RSS grows.
  - Keep clicking **Leak 50MB RAM** -> Node process attempts to exceed `128MB`.
  - **Result**: The Linux kernel invokes the **OOM Killer** and instantly kills the container.
  - **Observe**: Nginx catches the failure and returns `502 Bad Gateway` or automatically routes traffic to the remaining healthy replica!
  - Check container exit status:
    ```bash
    podman ps -a
    # You will see Exit Code 137 (OOM Killed)
    ```

---

### 4. 🔥 CPU Saturation Test
- **Concept**: Observe CPU throttling and event-loop lag under computation stress.
- **Test**: Click **Stress CPU (3000ms)** and monitor resource consumption in another terminal:
  ```bash
  podman stats
  ```

---

### 5. 🩺 Health Check & Failover Test
- **Concept**: Nginx uses `proxy_next_upstream` to transparently route around failing instances.
- **Test**:
  - Click **Toggle Health (UP/DOWN)** on the active node.
  - Fire requests: Nginx detects the `500` status and fails over to the healthy replica.

---

## 🛡️ CI/CD Quality Gate & SAST (DevSecOps - 4 Stages)

El pipeline automatizado en Azure DevOps está desacoplado en **4 Stages secuenciales e independientes**:

1. **Stage 1: Semantic Versioning (SemVer)**:
   - Cálculo automático de versión SemVer (`MAJOR.MINOR.PATCH`) mediante Conventional Commits.
2. **Stage 2: Quality Gate & SAST (Validación & Seguridad)**:
   - **Backend Job**: Ejecución de 42 pruebas unitarias (.NET 10 & xUnit), recolección de cobertura dual (Cobertura + OpenCover) y análisis estático con **SonarQube Cloud** (`scannerMode: dotnet`).
   - **Frontend & Security Job**: Validación de compilación SPA (React 18 / Vite) y escaneo de vulnerabilidades en dependencias y Containerfiles con **Trivy Scanner**.
   - Si el Quality Gate falla, el pipeline se detiene inmediatamente (**Fail-Fast**).
3. **Stage 3: Packaging (Build & Push OCI)**:
   - Construcción inmutable de imágenes multi-stage y publicación hacia Azure Container Registry (ACR) y GitHub Packages (GHCR) etiquetadas con `SEMVER_TAG` y `latest`.
4. **Stage 4: CD (Continuous Delivery en Azure VM)**:
   - Despliegue en la VM Ubuntu en Azure mediante Docker Compose, verificación con Smoke Tests, inyección de Changelog dinámico y creación de GitHub Releases.

---

## 🔍 Handy Podman Commands for Learning

| Command | Description |
|---|---|
| `podman ps` | List active containers |
| `podman stats` | Live CPU, Memory, Net I/O stream for all containers |
| `podman pod ps` | List active Podman Pods |
| `podman logs -f <container_name>` | Stream container logs |
| `podman inspect <container_name>` | Deep inspect container metadata, network, IP, limits |
| `podman top <container_name>` | View processes running inside the container |
| `podman exec -it <container_name> sh` | Open an interactive shell inside a container |

---

## 📚 Technical Documentation & Dev Journal

The repository includes a modern, fast documentation site and development log powered by **VitePress**:

```bash
# Start the local docs dev server (with hot reload)
npm run docs:dev

# Build static documentation for production
npm run docs:build

# Preview production build
npm run docs:preview
```

