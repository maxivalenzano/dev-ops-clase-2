# PowerShell Script: Launch Lab in a Native Podman Pod
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "🚀 Launching Podman Native Pod: 'dev-lab-pod'" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Clean up existing pod if present
Write-Host "[1/5] Cleaning up any existing pod..." -ForegroundColor Yellow
podman pod stop dev-lab-pod 2>$null
podman pod rm -f dev-lab-pod 2>$null

# 2. Build Container images
Write-Host "[2/5] Building images..." -ForegroundColor Yellow
podman build -t lab-backend:latest ./backend -f ./backend/Containerfile
podman build -t lab-frontend:latest ./frontend -f ./frontend/Containerfile
podman build -t lab-nginx:pod ./nginx -f ./nginx/Containerfile.pod

# 3. Create Podman Pod (Expose port 8080 on Host -> Port 80 on Pod)
Write-Host "[3/5] Creating Podman Pod (port 8080:80)..." -ForegroundColor Yellow
podman pod create --name dev-lab-pod -p 8080:80

# 4. Start Backend Instances (sharing localhost network inside pod)
Write-Host "[4/5] Starting Backend Replicas (Port 3001 & 3002 inside Pod)..." -ForegroundColor Yellow
podman run -d --pod dev-lab-pod --name pod-backend-1 `
  --memory 128m --cpus 0.5 `
  -e PORT=3001 -e INSTANCE_NAME=pod-backend-1 `
  lab-backend:latest

podman run -d --pod dev-lab-pod --name pod-backend-2 `
  --memory 128m --cpus 0.5 `
  -e PORT=3002 -e INSTANCE_NAME=pod-backend-2 `
  lab-backend:latest

# 5. Start Frontend & Nginx Proxy
Write-Host "[5/5] Starting Frontend (Port 8081) & Nginx Proxy (Port 80)..." -ForegroundColor Yellow
# Frontend serves static files on port 8081 inside the pod
podman run -d --pod dev-lab-pod --name pod-frontend `
  lab-frontend:latest

# Nginx reverse proxy routes 80 -> 8081 (front) and 3001/3002 (backends)
podman run -d --pod dev-lab-pod --name pod-nginx `
  lab-nginx:pod

# Get WSL IP for direct access in NAT networking mode
$wslIp = (wsl -d podman-machine-default ip -4 -o addr show eth0 | ForEach-Object { ($_ -split '\s+')[3] -replace '/.*','' })

Write-Host "======================================================" -ForegroundColor Green
Write-Host "✨ Pod is UP and RUNNING!" -ForegroundColor Green
Write-Host "👉 Open Dashboard: http://localhost:8080" -ForegroundColor Green
if ($wslIp) {
    Write-Host "👉 Or via WSL IP:  http://${wslIp}:8080" -ForegroundColor Green
}
Write-Host "👉 View Pod status: podman pod ps" -ForegroundColor Cyan
Write-Host "👉 View Containers: podman ps --pod" -ForegroundColor Cyan
Write-Host "👉 Stop Pod:        podman pod stop dev-lab-pod" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Green
