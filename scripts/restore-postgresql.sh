#!/usr/bin/env bash
# Restore only to a NEW, separate database. Production cutover is a distinct operation.
set -euo pipefail
umask 077
backup_dir="${1:?Usage: restore-postgresql.sh BACKUP_DIR restore_unique_name}"
restore_db="${2:?Set a new database name beginning restore_}"
[[ "$restore_db" =~ ^restore_[a-z0-9_]{1,48}$ ]] || { echo 'Destination must be a new restore_ database.' >&2; exit 2; }
[[ -f "$backup_dir/database.dump" && -f "$backup_dir/database.sha256" && -f "$backup_dir/source.fingerprint" ]]
(cd "$backup_dir" && sha256sum -c database.sha256)
started=$SECONDS
# createdb fails if destination exists; no --clean, DROP or production overwrite.
docker exec lab-postgres createdb -U postgres "$restore_db"
docker exec -i lab-postgres pg_restore -U postgres -d "$restore_db" --exit-on-error --no-owner --no-privileges <"$backup_dir/database.dump"
verification="$(mktemp)"
trap 'rm -f -- "$verification"' EXIT
docker exec -i lab-postgres psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d "$restore_db" >"$verification" <<'SQL'
SELECT COALESCE(string_agg(tablename,',' ORDER BY tablename),'') FROM pg_tables WHERE schemaname='public';
SELECT format('SELECT %L || count(*) || '':'' || md5(COALESCE(string_agg(row_to_json(t)::text,'','' ORDER BY row_to_json(t)::text),'''')) FROM %I t;', tablename || ':', tablename)
  FROM pg_tables WHERE schemaname='public' ORDER BY tablename \gexec
SQL
cmp "$backup_dir/source.fingerprint" "$verification"
printf 'Verified restore to %s in %ds. Source application/database remain active; inspect before any controlled cutover.\n' "$restore_db" "$((SECONDS-started))"
