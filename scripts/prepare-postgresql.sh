#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib-postgresql.sh"
reserve_release
started=$SECONDS
first_cutover=false
writers_paused=false
prepared=false
migration_started=false
finish() {
  result=$?
  trap - EXIT
  migrator_stopped=true
  if [[ "$migration_started" == true ]]; then
    if ! docker info >/dev/null 2>&1; then migrator_stopped=false
    elif docker inspect "devops-migrator-$BUILD_ID" >/dev/null 2>&1; then
      docker rm -f "devops-migrator-$BUILD_ID" >/dev/null 2>&1 || migrator_stopped=false
    fi
  fi
  if [[ "$result" -ne 0 && "$result" -ne 130 && "$prepared" == false ]]; then
    if [[ "$migrator_stopped" == true ]]; then
      # No new application has started; restore the previous writer processes.
      if [[ "$writers_paused" == true ]]; then docker start lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null 2>&1 || true; fi
      release_reservation || true
    else
      echo 'Migrator termination could not be confirmed. Writers and reservation retained for inspection.' >&2
    fi
    echo 'PostgreSQL stage failed; new application was not deployed. Inspect migration history before retrying.' >&2
  fi
  if [[ -n "${auth_dir:-}" && "$auth_dir" == "$deploy_dir"/.auth.* ]]; then rm -rf -- "$auth_dir" || true; fi
  exit "$result"
}
trap finish EXIT
available_kb="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
free_kb="$(df -Pk "$deploy_dir" | awk 'NR==2 {print $4}')"
[[ "$available_kb" -ge 524288 && "$free_kb" -ge 2097152 ]] || { echo 'Insufficient available memory or disk for database/backup.' >&2; false; }
if [[ -n "${GHCR_PULL_TOKEN:-}" && "$GHCR_PULL_TOKEN" != '$('* ]]; then
  auth_dir="$(mktemp -d "$deploy_dir/.auth.XXXXXXXX")"
  export DOCKER_CONFIG="$auth_dir"
  printf '%s' "$GHCR_PULL_TOKEN" | docker login ghcr.io -u "${GHCR_USERNAME:-maxivalenzano}" --password-stdin >/dev/null
fi
unset GHCR_PULL_TOKEN
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$MIGRATOR_IMAGE"; do docker pull "$image:$IMAGE_TAG"; done
for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE" "$MIGRATOR_IMAGE"; do
  [[ "$(docker image inspect "$image:$IMAGE_TAG" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}')" == "$SOURCE_COMMIT" ]]
done
docker image inspect "$BACKEND_IMAGE:$IMAGE_TAG" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -qx "TASK_RELEASE=$RELEASE_PHASE"
python3 - "$source_dir/backend/schema-compatibility.json" <<'PY'
import json,os,sys
x=json.load(open(sys.argv[1]))[os.environ['RELEASE_PHASE']]
if x['targetMigration'] != os.environ['MIGRATION_TARGET']: raise SystemExit('Phase/target mismatch')
PY
if [[ -n "${auth_dir:-}" ]]; then rm -rf -- "$auth_dir"; unset DOCKER_CONFIG; fi
mkdir -p "$SECRETS_DIR" "$deploy_dir/data"
chmod 700 "$SECRETS_DIR"
python3 - "$SECRETS_DIR" <<'PY'
import pathlib, secrets, sys
p=pathlib.Path(sys.argv[1])
for role in ('postgres','migrator','app'):
    path=p/(role+'_password')
    if not path.exists(): path.write_text(secrets.token_hex(32))
    path.chmod(0o444)
for role in ('migrator','app'):
    path=p/(role+'_connection')
    password=(p/(role+'_password')).read_text().strip()
    if path.exists(): path.chmod(0o600)
    path.write_text(f'Host=postgres;Port=5432;Database=devops;Username=devops_{role};Password={password};Maximum Pool Size=5;Timeout=5;Command Timeout=30;Include Error Detail=false;Options=-c lock_timeout=5000 -c statement_timeout=60000')
    path.chmod(0o444)
PY
cp "$source_dir/compose.data.yaml" "$deploy_dir/data/compose.data.yaml"
docker network inspect devops-lab_lab-network >/dev/null 2>&1 || docker network create \
  --label com.docker.compose.network=lab-network --label com.docker.compose.project=devops-lab \
  devops-lab_lab-network >/dev/null
docker compose -p devops-data -f "$deploy_dir/data/compose.data.yaml" pull
docker compose -p devops-data -f "$deploy_dir/data/compose.data.yaml" up -d --wait --wait-timeout 120
bash "$source_dir/scripts/provision-postgresql.sh"
[[ "$(sql 'SELECT current_database();')" == devops ]]
before="$(schema)"
if [[ "$before" != 0 ]]; then validate_schema; fi
before_number="$(schema_number "$before")"
target_number="$(schema_number "$MIGRATION_TARGET")"
effective_number=$((before_number>target_number ? before_number : target_number))
python3 - "$source_dir/backend/schema-compatibility.json" "$deploy_dir/deployment.json" "$effective_number" <<'PY'
import json,os,pathlib,sys
manifest=json.load(open(sys.argv[1]))
number=int(sys.argv[3])
incoming=manifest[os.environ['RELEASE_PHASE']]
if not incoming['minSchema'] <= number <= incoming['maxSchema']: raise SystemExit('Incoming app/schema incompatible')
p=pathlib.Path(sys.argv[2])
previous=json.loads(p.read_text()) if p.exists() else {}
if previous.get('storage') == 'postgresql':
    previous=manifest[previous['release_phase']]
    if not previous['minSchema'] <= number <= previous['maxSchema']: raise SystemExit('Previous app cannot coexist with target schema')
elif os.environ['RELEASE_PHASE'] != 'P1':
    raise SystemExit('The first PostgreSQL release must be P1; deploy P2/P3 separately.')
PY
if [[ ! -f "$deploy_dir/deployment.json" ]] || ! python3 - "$deploy_dir/deployment.json" <<'PY'
import json,sys
raise SystemExit(0 if json.load(open(sys.argv[1])).get('storage') == 'postgresql' else 1)
PY
then
  first_cutover=true
fi
# Brief maintenance makes the demo's backup/restore fingerprint reproducible.
docker stop lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null 2>&1 || true
writers_paused=true
before_data="$(data_fingerprint)"
before_identity="$(data_identity_fingerprint)"
backup="$deploy_dir/backups/$BUILD_ID"
bash "$source_dir/scripts/backup-postgresql.sh" "$backup"
if [[ "$before" == 0 || "$before" < "$MIGRATION_TARGET" ]]; then
  migration_started=true
  timeout --signal=TERM --kill-after=15s 180s docker run --rm --name "devops-migrator-$BUILD_ID" \
    --network devops-lab_lab-network --memory 256m \
    --mount "type=bind,src=$SECRETS_DIR/migrator_connection,dst=/run/secrets/db_connection,readonly" \
    -e DATABASE_CONNECTION_FILE=/run/secrets/db_connection "$MIGRATOR_IMAGE:$IMAGE_TAG" "$MIGRATION_TARGET"
  migration_started=false
else
  echo 'No forward migrations pending for this release; preserving the newer compatible schema.'
fi
after="$(schema)"
[[ "$after" == "$MIGRATION_TARGET" || "$after" > "$MIGRATION_TARGET" ]]
validate_schema
sql 'REVOKE INSERT,UPDATE,DELETE ON "__EFMigrationsHistory" FROM devops_app;' >/dev/null
if [[ "$first_cutover" == true ]]; then
  if docker inspect lab-redis >/dev/null 2>&1; then
    docker exec lab-redis redis-cli SAVE >/dev/null
    python3 "$source_dir/scripts/import-redis-tasks.py" "$backup/redis-tasks.json"
  else
    [[ "$(sql 'SELECT count(*) FROM tasks;')" == 0 ]]
  fi
else
  if [[ "$before" != "$MIGRATION_TARGET" && "$MIGRATION_TARGET" == 20261026000100_005_ResetTaskStateForDemo ]]; then
    [[ "$before_identity" == "$(data_identity_fingerprint)" ]]
    [[ "$(sql 'SELECT count(*) FROM tasks WHERE priority <> 1 OR is_completed;')" == 0 ]]
  else
    [[ "$before_data" == "$(data_fingerprint)" ]]
  fi
fi
if [[ "$first_cutover" == false ]]; then
  docker start lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null
  writers_paused=false
fi
# Authenticated SQL using the restricted application role, not only pg_isready.
docker exec lab-postgres bash -c 'export PGPASSWORD="$(cat /run/secrets/app_password)"; psql -X -qAt -v ON_ERROR_STOP=1 -h127.0.0.1 -U devops_app -d devops -c "SELECT count(*) FROM tasks;"' >/dev/null
export SCHEMA_BEFORE="$before" SCHEMA_AFTER="$after" BACKUP_PATH="$backup" FIRST_CUTOVER="$first_cutover"
export DURATION_SECONDS="$((SECONDS-started))" TASK_COUNT="$(sql 'SELECT count(*) FROM tasks;')"
export MIGRATOR_DIGEST="$(docker image inspect "$MIGRATOR_IMAGE:$IMAGE_TAG" --format '{{index .RepoDigests 0}}')"
python3 - "$receipt" "$source_dir/backend/schema-compatibility.json" <<'PY'
import datetime,json,os,pathlib,sys
x={k.lower():os.environ[k] for k in ('BUILD_ID','SOURCE_COMMIT','IMAGE_TAG','MIGRATION_TARGET','RELEASE_PHASE','SCHEMA_BEFORE','SCHEMA_AFTER','BACKUP_PATH','FIRST_CUTOVER','MIGRATOR_DIGEST')}
x.update(result='passed', duration_seconds=int(os.environ['DURATION_SECONDS']), task_count=int(os.environ['TASK_COUNT']), prepared_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
compat=json.load(open(sys.argv[2]))[os.environ['RELEASE_PHASE']]
x.update(min_schema=compat['minSchema'],max_schema=compat['maxSchema'],backup_verification=json.load(open(pathlib.Path(os.environ['BACKUP_PATH'])/'verification.json')))
pathlib.Path(sys.argv[1]).write_text(json.dumps(x,indent=2)+'\n')
PY
{
  date -u
  free -m
  df -h "$deploy_dir"
  docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'
  sql 'SELECT count(*) AS connections FROM pg_stat_activity;'
} >"$deploy_dir/releases/$BUILD_ID/resources.txt"
if [[ -n "${BACKUP_EXPORT_DIR:-}" ]]; then
  mkdir -p "$BACKUP_EXPORT_DIR"
  cp "$backup/database.dump" "$backup/database.sha256" "$backup/source.fingerprint" "$backup/roles.sql" "$backup/verification.json" "$BACKUP_EXPORT_DIR/"
  cp "$receipt" "$BACKUP_EXPORT_DIR/receipt.json"
  if [[ -f "$backup/redis-tasks.json" ]]; then cp "$backup/redis-tasks.json" "$BACKUP_EXPORT_DIR/"; fi
  chmod 600 "$BACKUP_EXPORT_DIR/"*
fi
prepared=true
echo "PostgreSQL prepared: build $BUILD_ID, schema $before -> $after. Reservation retained until CD."
