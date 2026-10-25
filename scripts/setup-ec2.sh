#!/usr/bin/env bash
# Ubuntu EC2 provisioning. Run as the same user that will execute deployments.
set -euo pipefail

source /etc/os-release
[[ "$ID" == ubuntu ]] || { echo 'This script requires Ubuntu.' >&2; exit 1; }
deploy_user="$(id -un)"
sudo -n true

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo systemctl enable --now docker
sudo usermod -aG docker "$deploy_user"
sudo install -d -o "$deploy_user" -g "$deploy_user" -m 0755 /opt/devops-lab
sudo docker version --format '{{.Server.Version}}'
sudo docker compose version
sudo docker run --rm hello-world
echo 'Reconnect SSH before running Docker without sudo.'
