#!/usr/bin/env bash
# CD consumes PostgreSQL's receipt. It never applies or reverses migrations.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib-postgresql.sh"
assert_owner
previous=''
staging=''
finished=false
finish() {
  failed_status=$?
  trap - EXIT
  if [[ -n "$staging" && "$staging" == "$deploy_dir"/.release.* ]]; then rm -rf -- "$staging" || true; fi
  if [[ "$failed_status" -ne 0 && "$failed_status" -ne 130 && "$finished" == false ]]; then
    if declare -F rollback >/dev/null; then
      rollback "$failed_status"
    else
      # Preflight did not mutate application files. An existing healthy PG app may continue.
      if [[ -f "$deploy_dir/deployment.json" ]] && python3 - "$deploy_dir/deployment.json" <<'PY'
import json,sys
raise SystemExit(0 if json.load(open(sys.argv[1])).get('storage')=='postgresql' else 1)
PY
      then
        release_reservation || true
        echo 'CD preflight failed; previous PostgreSQL application unchanged.' >&2
      else
        echo 'CD preflight failed during first cutover; writers remain paused and reservation retained.' >&2
      fi
    fi
  fi
  exit "$failed_status"
}
trap finish EXIT
export APP_URL="${APP_URL:-http://18.216.227.211}"
current_schema="$(schema)"
current_number="$(schema_number "$current_schema")"
python3 - "$receipt" "$current_schema" <<'PY'
import json,os,sys
x=json.load(open(sys.argv[1]))
for key in ('BUILD_ID','SOURCE_COMMIT','IMAGE_TAG','MIGRATION_TARGET','RELEASE_PHASE'):
    if x[key.lower()] != os.environ[key]: raise SystemExit('PostgreSQL receipt/release mismatch')
if x['result'] != 'passed' or x['schema_after'] != sys.argv[2]: raise SystemExit('PostgreSQL receipt/schema not valid')
PY
staging="$(mktemp -d "$deploy_dir/.release.XXXXXXXX")"
mkdir -p "$staging/nginx"
cp "$source_dir/compose.yaml" "$staging/compose.yaml"
cp "$source_dir/nginx/nginx.conf" "$staging/nginx/nginx.conf"
printf 'COMPOSE_PROJECT_NAME=devops-lab\nBACKEND_IMAGE=%s\nFRONTEND_IMAGE=%s\nIMAGE_TAG=%s\nSECRETS_DIR=%s\nPORT=80\n' \
  "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$IMAGE_TAG" "$SECRETS_DIR" >"$staging/.env"
docker compose -p devops-lab --env-file "$staging/.env" -f "$staging/compose.yaml" config -q
# Images were downloaded and verified by PostgreSQL stage; never rebuild on the VM.
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE"; do docker image inspect "$image:$IMAGE_TAG" >/dev/null; done
if [[ -f "$deploy_dir/.env" && -f "$deploy_dir/compose.yaml" ]]; then
  previous="$deploy_dir/history/$(date -u +%Y%m%dT%H%M%S)-$BUILD_ID"
  mkdir -p "$previous/nginx"
  cp "$deploy_dir/.env" "$deploy_dir/compose.yaml" "$previous/"
  cp "$deploy_dir/nginx/nginx.conf" "$previous/nginx/nginx.conf"
  if [[ -f "$deploy_dir/deployment.json" ]]; then cp "$deploy_dir/deployment.json" "$previous/"; fi
fi
rollback() {
  failed_status="$1"
  echo 'CD verification failed. Checking compatibility of the previous PostgreSQL application.' >&2
  if [[ -n "$previous" && -f "$previous/deployment.json" ]] && \
    python3 - "$previous/deployment.json" "$current_number" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); n=int(sys.argv[2])
raise SystemExit(0 if x.get('storage')=='postgresql' and x.get('min_schema',99)<=n<=x.get('max_schema',-1) else 1)
PY
  then
    if cp "$previous/.env" "$previous/compose.yaml" "$deploy_dir/" && \
       cat "$previous/nginx/nginx.conf" >"$deploy_dir/nginx/nginx.conf" && \
       cp "$previous/deployment.json" "$deploy_dir/" && \
       compose_app up -d --no-build && compose_app up -d --no-build --force-recreate nginx && \
       DEPLOY_DIR="$deploy_dir" python3 "$source_dir/scripts/verify-deployment.py"; then
      release_reservation
      echo 'Previous compatible PostgreSQL application restored; schema and persistent data retained.' >&2
    else
      docker stop lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null 2>&1 || true
      echo 'Rollback verification failed. Writers stopped and reservation retained for recovery.' >&2
    fi
  else
    docker stop lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null 2>&1 || true
    echo 'No compatible PostgreSQL baseline. Writers stopped; repair forward. Redis rollback is not automatic.' >&2
  fi
}
mkdir -p "$deploy_dir/nginx" "$deploy_dir/scripts"
cp "$staging/compose.yaml" "$staging/.env" "$deploy_dir/"
cat "$staging/nginx/nginx.conf" >"$deploy_dir/nginx/nginx.conf"
cp "$source_dir/scripts/verify-deployment.sh" "$source_dir/scripts/verify-deployment.py" "$deploy_dir/scripts/"
# Explicit application services; persistent PostgreSQL belongs to devops-data.
compose_app up -d --no-build
compose_app up -d --no-build --force-recreate nginx
DEPLOY_DIR="$deploy_dir" python3 "$deploy_dir/scripts/verify-deployment.py"
python3 - "$receipt" "$deploy_dir/deployment.json" "$source_dir/backend/schema-compatibility.json" <<'PY'
import datetime,json,os,pathlib,sys
x=json.load(open(sys.argv[1])); compatibility=json.load(open(sys.argv[3]))[os.environ['RELEASE_PHASE']]
x.update(storage='postgresql', app_url=os.environ['APP_URL'],
 min_schema=compatibility['minSchema'], max_schema=compatibility['maxSchema'],
 deployed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), verification='passed')
pathlib.Path(sys.argv[2]).write_text(json.dumps(x,indent=2)+'\n')
PY
release_reservation
finished=true
echo "Deployed $IMAGE_TAG ($RELEASE_PHASE); schema $current_schema; verification passed."
