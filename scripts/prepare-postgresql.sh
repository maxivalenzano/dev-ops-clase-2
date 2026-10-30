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
: "${MIGRATION_MANIFEST:?Set MIGRATION_MANIFEST to the downloaded migration artifact}"
[[ -f "$MIGRATION_MANIFEST" ]]
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
latest_migration="$(python3 - "$MIGRATION_MANIFEST" <<'PY'
import json,sys
migrations=json.load(open(sys.argv[1]))['migrations']
if not migrations: raise SystemExit('The release contains no EF Core migrations.')
print(migrations[-1])
PY
)"
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
if [[ ! -f "$deploy_dir/deployment.json" ]] || ! python3 - "$deploy_dir/deployment.json" <<'PY'
import json,sys
raise SystemExit(0 if json.load(open(sys.argv[1])).get('storage') == 'postgresql' else 1)
PY
then
  first_cutover=true
fi
# Pause writers while taking the backup and applying the ordered migration bundle.
docker stop lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null 2>&1 || true
writers_paused=true
before_history="$(migration_history)"
backup="$deploy_dir/backups/$BUILD_ID"
bash "$source_dir/scripts/backup-postgresql.sh" "$backup"
if [[ "$before" == 0 || "$before" < "$latest_migration" ]]; then
  migration_started=true
  timeout --signal=TERM --kill-after=15s 180s docker run --rm --name "devops-migrator-$BUILD_ID" \
    --network devops-lab_lab-network --memory 256m \
    --mount "type=bind,src=$SECRETS_DIR/migrator_connection,dst=/run/secrets/db_connection,readonly" \
    -e DATABASE_CONNECTION_FILE=/run/secrets/db_connection "$MIGRATOR_IMAGE:$IMAGE_TAG"
  migration_started=false
else
  echo 'Database already has this release migration history or a newer compatible history; preserving it.'
fi
after="$(schema)"
validate_complete_schema
after_history="$(migration_history)"
sql 'REVOKE INSERT,UPDATE,DELETE ON "__EFMigrationsHistory" FROM devops_app;' >/dev/null
if [[ "$first_cutover" == true ]]; then
  if docker inspect lab-redis >/dev/null 2>&1; then
    docker exec lab-redis redis-cli SAVE >/dev/null
    python3 "$source_dir/scripts/import-redis-tasks.py" "$backup/redis-tasks.json"
  else
    [[ "$(sql 'SELECT count(*) FROM tasks;')" == 0 ]]
  fi
else
  docker start lab-backend-1 lab-backend-2 lab-backend-3 >/dev/null
  writers_paused=false
  python3 - <<'PY'
import json,time,urllib.error,urllib.request
url='http://127.0.0.1/api/ready'
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
deadline=time.monotonic()+90
last=None
while time.monotonic()<deadline:
    try:
        with opener.open(url, timeout=5) as response:
            payload=json.loads(response.read())
            if response.status == 200 and payload.get('status') == 'UP':
                print('Previous application remains ready on the migrated schema.')
                break
            last=f'HTTP {response.status}: {payload}'
    except Exception as error:
        last=str(error)
    time.sleep(2)
else:
    raise SystemExit(f'Previous application is not compatible with the migrated schema: {last}')
PY
fi
# Authenticated SQL using the restricted application role, not only pg_isready.
docker exec lab-postgres bash -c 'export PGPASSWORD="$(cat /run/secrets/app_password)"; psql -X -qAt -v ON_ERROR_STOP=1 -h127.0.0.1 -U devops_app -d devops -c "SELECT count(*) FROM tasks;"' >/dev/null
export SCHEMA_BEFORE="$before" SCHEMA_AFTER="$after" BACKUP_PATH="$backup" FIRST_CUTOVER="$first_cutover"
export MIGRATIONS_BEFORE="$before_history" MIGRATIONS_AFTER="$after_history"
export DURATION_SECONDS="$((SECONDS-started))" TASK_COUNT="$(sql 'SELECT count(*) FROM tasks;')"
export MIGRATOR_DIGEST="$(docker image inspect "$MIGRATOR_IMAGE:$IMAGE_TAG" --format '{{index .RepoDigests 0}}')"
python3 - "$receipt" <<'PY'
import datetime,json,os,pathlib,sys
x={k.lower():os.environ[k] for k in ('BUILD_ID','SOURCE_COMMIT','IMAGE_TAG','SCHEMA_BEFORE','SCHEMA_AFTER','BACKUP_PATH','FIRST_CUTOVER','MIGRATOR_DIGEST')}
x.update(result='passed', duration_seconds=int(os.environ['DURATION_SECONDS']), task_count=int(os.environ['TASK_COUNT']), prepared_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
x.update(migrations_before=os.environ['MIGRATIONS_BEFORE'].splitlines(),
         migrations_after=os.environ['MIGRATIONS_AFTER'].splitlines(),
         migration_count=len(os.environ['MIGRATIONS_AFTER'].splitlines())-len(os.environ['MIGRATIONS_BEFORE'].splitlines()),
         backup_verification=json.load(open(pathlib.Path(os.environ['BACKUP_PATH'])/'verification.json')))
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
