#!/bin/bash
set -e

echo "======================================================"
echo "🚀 Launching Podman Native Pod: 'dev-lab-pod'"
echo "======================================================"

# 1. Clean up existing pod if present
echo "[1/5] Cleaning up existing pod..."
podman pod stop dev-lab-pod 2>/dev/null || true
podman pod rm -f dev-lab-pod 2>/dev/null || true

# 2. Build Container images
echo "[2/5] Building images..."
podman build -t lab-backend:latest ./backend -f ./backend/Containerfile
podman build -t lab-frontend:latest ./frontend -f ./frontend/Containerfile
podman build -t lab-nginx:pod ./nginx -f ./nginx/Containerfile.pod

# 3. Create Podman Pod (Expose port 8080 on Host -> Port 80 on Pod)
echo "[3/5] Creating Podman Pod (port 8080:80)..."
podman pod create --name dev-lab-pod -p 8080:80

# 4. Start Backend Instances (sharing localhost network inside pod)
echo "[4/5] Starting Backend Replicas (Port 3001 & 3002 inside Pod)..."
podman run -d --pod dev-lab-pod --name pod-backend-1 \
  --memory 128m --cpus 0.5 \
  -e PORT=3001 -e INSTANCE_NAME=pod-backend-1 \
  lab-backend:latest

podman run -d --pod dev-lab-pod --name pod-backend-2 \
  --memory 128m --cpus 0.5 \
  -e PORT=3002 -e INSTANCE_NAME=pod-backend-2 \
  lab-backend:latest

# 5. Start Frontend & Nginx Proxy
echo "[5/5] Starting Frontend (Port 8081) & Nginx Proxy (Port 80)..."
podman run -d --pod dev-lab-pod --name pod-frontend \
  lab-frontend:latest

podman run -d --pod dev-lab-pod --name pod-nginx \
  lab-nginx:pod

echo "======================================================"
echo "✨ Pod is UP and RUNNING!"
echo "👉 Open Dashboard: http://localhost:8080"
echo "👉 View Pod status: podman pod ps"
echo "👉 View Containers: podman ps --pod"
echo "👉 Stop Pod:        podman pod stop dev-lab-pod"
echo "======================================================"
