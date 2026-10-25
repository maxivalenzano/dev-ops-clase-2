#!/usr/bin/env bash
# Custom-format logical backup plus a measured restore to a separate, disposable DB.
set -euo pipefail
umask 077
deploy_dir="${DEPLOY_DIR:-/opt/devops-lab}"
backup_dir="${1:-$deploy_dir/backups/$(date -u +%Y%m%dT%H%M%S)-$$}"
mkdir -p "$backup_dir"
docker exec lab-postgres bash -c 'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec pg_dump -h127.0.0.1 -U postgres -d devops -Fc' >"$backup_dir/database.dump"
docker exec lab-postgres bash -c 'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec pg_dumpall -h127.0.0.1 -U postgres --globals-only --no-role-passwords' >"$backup_dir/roles.sql"
docker exec -i lab-postgres pg_restore --list <"$backup_dir/database.dump" >"$backup_dir/archive.list"
restore_db="restore_check_$(date +%s)_$$"
cleanup() { docker exec lab-postgres dropdb -U postgres --if-exists "$restore_db" >/dev/null; }
started=$SECONDS
docker exec lab-postgres createdb -U postgres "$restore_db"
trap cleanup EXIT
docker exec -i lab-postgres pg_restore -U postgres -d "$restore_db" --exit-on-error --no-owner --no-privileges <"$backup_dir/database.dump"
fingerprint() {
  docker exec -i lab-postgres psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d "$1" <<'SQL'
SELECT COALESCE(string_agg(tablename,',' ORDER BY tablename),'') FROM pg_tables WHERE schemaname='public';
SELECT format('SELECT %L || count(*) || '':'' || md5(COALESCE(string_agg(row_to_json(t)::text,'','' ORDER BY row_to_json(t)::text),'''')) FROM %I t;', tablename || ':', tablename)
  FROM pg_tables WHERE schemaname='public' ORDER BY tablename \gexec
SQL
}
fingerprint devops >"$backup_dir/source.fingerprint"
fingerprint "$restore_db" >"$backup_dir/restored.fingerprint"
cmp "$backup_dir/source.fingerprint" "$backup_dir/restored.fingerprint"
restore_seconds=$((SECONDS-started))
(cd "$backup_dir" && sha256sum database.dump >database.sha256)
printf '{"restore_verified":true,"restore_seconds":%d,"recovery_window":"Backup snapshot only; later writes are not included"}\n' "$restore_seconds" >"$backup_dir/verification.json"
chmod 600 "$backup_dir/"*
echo "Backup and separate restore verified (${restore_seconds}s): $backup_dir"
