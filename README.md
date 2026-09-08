# 🚀 Podman Container & Microservices Lab

A lightweight, hands-on lab designed to master **Podman**, container orchestration, **Nginx** reverse proxying, load balancing, timeouts, resource limits (CPU/OOM), and native **Podman Pods** (`localhost` network sharing).

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

