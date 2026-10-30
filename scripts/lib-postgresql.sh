#!/usr/bin/env bash
# Shared by the PostgreSQL and CD stages. Never enable shell tracing here.
set -euo pipefail
umask 077
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deploy_dir="${DEPLOY_DIR:-/opt/devops-lab}"
export SECRETS_DIR="${SECRETS_DIR:-$deploy_dir/secrets}"
export BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/maxivalenzano/dev-ops-backend}"
export FRONTEND_IMAGE="${FRONTEND_IMAGE:-ghcr.io/maxivalenzano/dev-ops-frontend}"
export MIGRATOR_IMAGE="${MIGRATOR_IMAGE:-ghcr.io/maxivalenzano/dev-ops-migrator}"
export BUILD_ID="${BUILD_ID:-${BUILD_BUILDID:-}}"
: "${BUILD_ID:?Set BUILD_ID}"
: "${SOURCE_COMMIT:?Set SOURCE_COMMIT}"
: "${IMAGE_TAG:?Set IMAGE_TAG}"
[[ "$BUILD_ID" =~ ^[a-zA-Z0-9_.-]+$ && "$SOURCE_COMMIT" =~ ^[a-f0-9]{40}$ ]] || exit 2
[[ "$IMAGE_TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || exit 2
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$MIGRATOR_IMAGE"; do
  [[ "$image" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_./-]+$ ]] || exit 2
done
mkdir -p "$deploy_dir/releases" "$deploy_dir/backups"
exec 9>"$deploy_dir/.deploy.lock"
flock -n 9 || { echo 'Another stage is running.' >&2; exit 1; }
reservation="$deploy_dir/.release-reservation.json"
mkdir -p "$deploy_dir/releases/$BUILD_ID"
receipt="$deploy_dir/releases/$BUILD_ID/receipt.json"
export BUILD_ID SOURCE_COMMIT IMAGE_TAG

assert_owner() {
  python3 - "$reservation" <<'PY'
import json, os, pathlib, sys
p = pathlib.Path(sys.argv[1])
if not p.exists(): raise SystemExit('No release reservation; run PostgreSQL stage first.')
x=json.loads(p.read_text())
if (x['build_id'], x['source_commit']) != (os.environ['BUILD_ID'], os.environ['SOURCE_COMMIT']):
    raise SystemExit('Another release owns the reservation; inspect it before retrying.')
PY
}
reserve_release() {
  if [[ -f "$reservation" ]]; then assert_owner; return; fi
  python3 - "$reservation" <<'PY'
import datetime, json, os, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
 'build_id':os.environ['BUILD_ID'], 'source_commit':os.environ['SOURCE_COMMIT'],
 'image_tag':os.environ['IMAGE_TAG'], 'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat()
})+'\n')
PY
}
release_reservation() { assert_owner; rm -- "$reservation"; }
sql() {
  docker exec -i lab-postgres bash -c 'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d devops' <<<"$1"
}
migration_history() {
  local exists
  exists="$(sql "SELECT to_regclass('public.\"__EFMigrationsHistory\"') IS NOT NULL;")" || return
  if [[ "$exists" == t ]]; then
    sql 'SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY "MigrationId";'
  fi
}
schema() {
  local history
  history="$(migration_history)" || return
  if [[ -n "$history" ]]; then printf '%s\n' "$history" | tail -n 1; else printf '0\n'; fi
}
validate_schema() {
  local history
  : "${MIGRATION_MANIFEST:?Set MIGRATION_MANIFEST to the packaged migration manifest}"
  history="$(migration_history)" || return
  APPLIED_MIGRATIONS="$history" python3 - "$MIGRATION_MANIFEST" <<'PY'
import json,os,sys
expected=json.load(open(sys.argv[1]))['migrations']
applied=os.environ['APPLIED_MIGRATIONS'].splitlines()
if not expected or (applied != expected[:len(applied)] and expected != applied[:len(expected)]):
    raise SystemExit('Database and release do not share a complete migration-history prefix.')
PY
}
validate_complete_schema() {
  local history
  history="$(migration_history)" || return
  APPLIED_MIGRATIONS="$history" python3 - "$MIGRATION_MANIFEST" <<'PY'
import json,os,sys
expected=json.load(open(sys.argv[1]))['migrations']
applied=os.environ['APPLIED_MIGRATIONS'].splitlines()
if not expected or len(applied) < len(expected) or applied[:len(expected)] != expected:
    raise SystemExit('Database does not contain this release migration history.')
PY
}
compose_app() {
  env -u IMAGE_TAG -u BACKEND_IMAGE -u FRONTEND_IMAGE -u PORT \
    docker compose -p devops-lab --env-file "$deploy_dir/.env" -f "$deploy_dir/compose.yaml" "$@"
}
cancelled() {
  trap - INT TERM
  echo 'Stage cancelled. Reservation retained; inspect DB and writer state before releasing it.' >&2
  exit 130
}
trap cancelled INT TERM
