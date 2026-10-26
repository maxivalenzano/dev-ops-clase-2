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
export RELEASE_PHASE="${RELEASE_PHASE:-P1}"
export BUILD_ID="${BUILD_ID:-${BUILD_BUILDID:-}}"
: "${BUILD_ID:?Set BUILD_ID}"
: "${SOURCE_COMMIT:?Set SOURCE_COMMIT}"
: "${IMAGE_TAG:?Set IMAGE_TAG}"
: "${MIGRATION_TARGET:?Set MIGRATION_TARGET}"
[[ "$BUILD_ID" =~ ^[a-zA-Z0-9_.-]+$ && "$SOURCE_COMMIT" =~ ^[a-f0-9]{40}$ ]] || exit 2
[[ "$IMAGE_TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || exit 2
[[ "$RELEASE_PHASE" =~ ^P[123]$ && "$MIGRATION_TARGET" =~ ^[a-zA-Z0-9_]+$ ]] || exit 2
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$MIGRATOR_IMAGE"; do
  [[ "$image" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_./-]+$ ]] || exit 2
done
mkdir -p "$deploy_dir/releases" "$deploy_dir/backups"
exec 9>"$deploy_dir/.deploy.lock"
flock -n 9 || { echo 'Another stage is running.' >&2; exit 1; }
reservation="$deploy_dir/.release-reservation.json"
mkdir -p "$deploy_dir/releases/$BUILD_ID"
receipt="$deploy_dir/releases/$BUILD_ID/receipt.json"
export BUILD_ID SOURCE_COMMIT IMAGE_TAG MIGRATION_TARGET

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
schema() {
  local exists
  exists="$(sql "SELECT to_regclass('public.\"__EFMigrationsHistory\"') IS NOT NULL;")" || return
  if [[ "$exists" == t ]]; then
    sql 'SELECT COALESCE(max("MigrationId"), '\''0'\'') FROM "__EFMigrationsHistory";'
  else printf '0\n'; fi
}
schema_number() {
  case "$1" in
    0) echo 0 ;;
    20261025000100_001_InitialTasks) echo 1 ;;
    20261025000200_002_AddPriorityNullable) echo 2 ;;
    20261025000300_003_BackfillPriority) echo 3 ;;
    20261025000400_004_RequirePriority) echo 4 ;;
    20261026000100_005_ResetTaskStateForDemo) echo 5 ;;
    *) echo 'Unknown database schema; manual review required.' >&2; return 1 ;;
  esac
}
validate_schema() {
  local final_schema history
  final_schema="$(schema)"
  history="$(sql 'SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY "MigrationId";')"
  python3 - "$history" "$final_schema" <<'PY'
import sys
known=['20261025000100_001_InitialTasks','20261025000200_002_AddPriorityNullable','20261025000300_003_BackfillPriority','20261025000400_004_RequirePriority','20261026000100_005_ResetTaskStateForDemo']
applied=sys.argv[1].splitlines()
if not applied or applied != known[:len(applied)] or applied[-1] != sys.argv[2]:
    raise SystemExit('Migration history is not the complete known prefix.')
PY
  if [[ "$(schema_number "$final_schema")" -ge 2 ]]; then
    [[ "$(sql "SELECT column_default = '2' FROM information_schema.columns WHERE table_schema='public' AND table_name='tasks' AND column_name='priority';")" == t ]]
  fi
  if [[ "$(schema_number "$final_schema")" -ge 4 ]]; then
    [[ "$(sql 'SELECT count(*) FROM tasks WHERE priority IS NULL OR priority NOT BETWEEN 1 AND 3;')" == 0 ]]
    [[ "$(sql "SELECT is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='tasks' AND column_name='priority';")" == NO ]]
    [[ "$(sql "SELECT count(*) FROM pg_constraint WHERE conrelid='tasks'::regclass AND conname='ck_tasks_priority' AND contype='c' AND convalidated AND pg_get_constraintdef(oid) LIKE '%priority%';")" == 1 ]]
  fi
  if [[ "$(schema_number "$final_schema")" -eq 5 ]]; then
    [[ "$(sql "SELECT to_regclass('public.task_state_before_priority_test') IS NOT NULL;")" == t ]]
  fi
}
data_fingerprint() {
  if [[ "$(sql "SELECT to_regclass('public.tasks') IS NOT NULL;")" == t ]]; then
    sql "SELECT count(*) || ':' || md5(COALESCE(string_agg(jsonb_build_array(id,title,is_completed,created_by_node,created_at)::text,',' ORDER BY id),'')) FROM tasks;"
  else printf '0:empty\n'; fi
}
data_identity_fingerprint() {
  if [[ "$(sql "SELECT to_regclass('public.tasks') IS NOT NULL;")" == t ]]; then
    sql "SELECT count(*) || ':' || md5(COALESCE(string_agg(jsonb_build_array(id,title,created_by_node,created_at)::text,',' ORDER BY id),'')) FROM tasks;"
  else printf '0:empty\n'; fi
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
