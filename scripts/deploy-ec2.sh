#!/usr/bin/env bash
# Run from a checked-out release on the EC2 deployment agent.
set -euo pipefail
umask 077

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deploy_dir="${DEPLOY_DIR:-/opt/devops-lab}"
export COMPOSE_PROJECT_NAME=devops-lab
: "${IMAGE_TAG:?Set IMAGE_TAG to the immutable release tag}"
export BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/maxivalenzano/dev-ops-backend}"
export FRONTEND_IMAGE="${FRONTEND_IMAGE:-ghcr.io/maxivalenzano/dev-ops-frontend}"
export APP_URL="${APP_URL:-http://18.216.227.211}"
[[ "$IMAGE_TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || exit 2
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE"; do
  [[ "$image" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_./-]+$ ]] || exit 2
done

mkdir -p "$deploy_dir"
exec 9>"$deploy_dir/.deploy.lock"
flock -n 9 || { echo 'Another deployment is running.' >&2; exit 1; }
staging="$(mktemp -d "$deploy_dir/.release.XXXXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/nginx" "$staging/scripts"
cp "$source_dir/compose.yaml" "$staging/compose.yaml"
cp "$source_dir/nginx/nginx.conf" "$staging/nginx/nginx.conf"
cp "$source_dir/scripts/verify-deployment.sh" "$staging/scripts/verify-deployment.sh"
cp "$source_dir/scripts/verify-deployment.py" "$staging/scripts/verify-deployment.py"
printf 'COMPOSE_PROJECT_NAME=devops-lab\nBACKEND_IMAGE=%s\nFRONTEND_IMAGE=%s\nIMAGE_TAG=%s\nPORT=80\n' \
  "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$IMAGE_TAG" >"$staging/.env"

# Undefined optional Azure Pipelines variables arrive as a literal $(NAME).
if [[ -n "${GHCR_PULL_TOKEN:-}" && "$GHCR_PULL_TOKEN" != '$('* ]]; then
  export DOCKER_CONFIG="$staging/docker-auth"
  mkdir -p "$DOCKER_CONFIG"
  printf '%s' "$GHCR_PULL_TOKEN" | docker login ghcr.io -u "${GHCR_USERNAME:-maxivalenzano}" --password-stdin
fi
unset GHCR_PULL_TOKEN
docker compose --env-file "$staging/.env" -f "$staging/compose.yaml" config -q
# All downloads must succeed before changing the active release.
docker compose --env-file "$staging/.env" -f "$staging/compose.yaml" pull

previous=''
if [[ -f "$deploy_dir/.env" && -f "$deploy_dir/compose.yaml" ]]; then
  previous="$deploy_dir/history/$(date -u +%Y%m%dT%H%M%S)-$$"
  mkdir -p "$previous"
  cp "$deploy_dir/.env" "$deploy_dir/compose.yaml" "$previous/"
  cp -r "$deploy_dir/nginx" "$previous/nginx"
  if [[ -f "$deploy_dir/deployment.json" ]]; then cp "$deploy_dir/deployment.json" "$previous/"; fi
fi
compose() {
  env -u IMAGE_TAG -u BACKEND_IMAGE -u FRONTEND_IMAGE -u PORT \
    docker compose --env-file "$deploy_dir/.env" -f "$deploy_dir/compose.yaml" "$@"
}
rollback() {
  failed_status=$?
  trap - ERR
  echo 'Deployment failed; inspecting the current services.' >&2
  compose ps >&2 || true
  if [[ -n "$previous" ]]; then
    echo "Restoring configuration from $previous" >&2
    cp "$previous/.env" "$previous/compose.yaml" "$deploy_dir/"
    cat "$previous/nginx/nginx.conf" >"$deploy_dir/nginx/nginx.conf"
    if [[ -f "$previous/deployment.json" ]]; then cp "$previous/deployment.json" "$deploy_dir/"; fi
    compose up -d --no-build --remove-orphans && compose up -d --no-build --force-recreate nginx || true
  fi
  exit "$failed_status"
}
trap rollback ERR
mkdir -p "$deploy_dir/nginx" "$deploy_dir/scripts"
cp "$staging/compose.yaml" "$staging/.env" "$deploy_dir/"
# Keep the inode of the bind-mounted Nginx file; refresh the gateway afterwards.
cat "$staging/nginx/nginx.conf" >"$deploy_dir/nginx/nginx.conf"
cp "$staging/scripts/verify-deployment.sh" "$staging/scripts/verify-deployment.py" "$deploy_dir/scripts/"
compose up -d --no-build --remove-orphans
compose up -d --no-build --force-recreate nginx
DEPLOY_DIR="$deploy_dir" bash "$deploy_dir/scripts/verify-deployment.sh"
export SOURCE_COMMIT="${SOURCE_COMMIT:-unknown}"
export DEPLOYED_IMAGE_TAG="$IMAGE_TAG"
python3 - "$deploy_dir/deployment.json" <<'PY'
import datetime, json, os, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    'image_tag': os.environ['DEPLOYED_IMAGE_TAG'],
    'source_commit': os.environ['SOURCE_COMMIT'],
    'app_url': os.environ['APP_URL'],
    'deployed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'verification': 'passed'
}, indent=2) + '\n')
PY
trap - ERR
echo "Deployed $IMAGE_TAG; application URL: $APP_URL"
if [[ -n "$previous" ]]; then echo "Previous configuration: $previous"; fi
